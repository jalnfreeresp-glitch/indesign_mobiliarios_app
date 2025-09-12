import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CarpenterBalanceScreen extends StatelessWidget {
  const CarpenterBalanceScreen({super.key});

  Future<Map<String, dynamic>> _fetchCarpenterData() async {
    final carpenterId = FirebaseAuth.instance.currentUser!.uid;

    final projectsSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .where('carpenterId', isEqualTo: carpenterId)
        .get();

    final paymentsSnapshot = await FirebaseFirestore.instance
        .collection('transactions')
        .where('type', isEqualTo: 'pago_carpintero')
        .get();

    double totalManoDeObra = 0;
    for (var doc in projectsSnapshot.docs) {
      totalManoDeObra += (doc.data()['costoManoDeObra'] as num?) ?? 0;
    }

    final projectIds = projectsSnapshot.docs.map((doc) => doc.id).toSet();
    double totalPagado = 0;
    final relevantPayments = paymentsSnapshot.docs
        .where((doc) => projectIds.contains(doc.data()['projectId']))
        .toList();
    for (var doc in relevantPayments) {
      totalPagado += (doc.data()['amount'] as num?) ?? 0;
    }

    return {
      'totalManoDeObra': totalManoDeObra,
      'totalPagado': totalPagado,
      'saldo': totalManoDeObra - totalPagado,
      'payments': relevantPayments,
    };
  }

  // --- FUNCIÓN AÑADIDA PARA BUSCAR EL NOMBRE DEL PROYECTO ---
  Future<String> getProjectName(String? projectId) async {
    if (projectId == null) return 'Proyecto no especificado';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();
      return doc.data()?['projectName'] ?? 'Proyecto sin nombre';
    } catch (e) {
      return 'Error al cargar';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Balance y Pagos'),
        backgroundColor: Colors.orange,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchCarpenterData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No se encontraron datos.'));
          }

          final data = snapshot.data!;
          final payments = data['payments'] as List<QueryDocumentSnapshot>;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text('Balance Total',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const Divider(),
                        ListTile(
                            title: const Text('Total Mano de Obra'),
                            trailing: Text(
                                '\$${(data['totalManoDeObra'] as double).toStringAsFixed(2)}')),
                        ListTile(
                            title: const Text('Total Pagado'),
                            trailing: Text(
                                '\$${(data['totalPagado'] as double).toStringAsFixed(2)}')),
                        ListTile(
                            title: const Text('Saldo Pendiente'),
                            trailing: Text(
                                '\$${(data['saldo'] as double).toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Historial de Pagos',
                    style: Theme.of(context).textTheme.headlineSmall),
                Expanded(
                  child: ListView.builder(
                    itemCount: payments.length,
                    itemBuilder: (context, index) {
                      var payment =
                          payments[index].data() as Map<String, dynamic>;
                      var date = (payment['date'] as Timestamp?)?.toDate();
                      var formattedDate = date != null
                          ? DateFormat('dd/MM/yyyy').format(date)
                          : 'N/A';
                      var projectId = payment['projectId'] as String?;

                      return FutureBuilder<String>(
                          future: getProjectName(projectId),
                          builder: (context, nameSnapshot) {
                            return ListTile(
                              title: Text(
                                  'Pago Recibido - \$${(payment['amount'] as num).toStringAsFixed(2)}'),
                              subtitle: Text(
                                  'Proyecto: ${nameSnapshot.data ?? 'Cargando...'}'),
                              trailing: Text(formattedDate),
                            );
                          });
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
