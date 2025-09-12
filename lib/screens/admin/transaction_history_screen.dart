import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Transacciones'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('No hay transacciones registradas.'));
          }

          final clientPayments = snapshot.data!.docs
              .where((doc) => doc['type'] == 'abono_cliente')
              .toList();
          final carpenterPayments = snapshot.data!.docs
              .where((doc) => doc['type'] == 'pago_carpintero')
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildSectionTitle('Abonos de Clientes'),
              clientPayments.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('No hay abonos de clientes.'),
                    )
                  : _buildTransactionList(clientPayments),
              const SizedBox(height: 24),
              _buildSectionTitle('Pagos a Carpinteros'),
              carpenterPayments.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('No hay pagos a carpinteros.'),
                    )
                  : _buildTransactionList(carpenterPayments),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  // --- WIDGET ACTUALIZADO PARA MOSTRAR NOMBRE DEL PROYECTO ---
  Widget _buildTransactionList(List<QueryDocumentSnapshot> transactions) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        var transaction = transactions[index].data() as Map<String, dynamic>;
        var amount = (transaction['amount'] as num).toDouble();
        var date = (transaction['date'] as Timestamp?)?.toDate();
        var formattedDate = date != null
            ? DateFormat('dd/MM/yyyy, hh:mm a').format(date)
            : 'Sin fecha';
        var projectId = transaction['projectId'] as String?;

        return FutureBuilder<DocumentSnapshot>(
          // Buscamos el documento del proyecto usando el projectId
          future: projectId != null
              ? FirebaseFirestore.instance
                  .collection('projects')
                  .doc(projectId)
                  .get()
              : null,
          builder: (context, projectSnapshot) {
            String projectName = 'Cargando...';
            if (projectSnapshot.connectionState == ConnectionState.done) {
              if (projectSnapshot.hasData && projectSnapshot.data!.exists) {
                var projectData =
                    projectSnapshot.data!.data() as Map<String, dynamic>;
                projectName =
                    projectData['projectName'] ?? 'Proyecto sin nombre';
              } else {
                projectName = 'Proyecto no encontrado';
              }
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text('Proyecto: $projectName'), // Mostramos el nombre
                subtitle: Text('Fecha: $formattedDate'),
                trailing: Text(
                  '\$${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
