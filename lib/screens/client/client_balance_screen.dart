import 'package:cloud_firestore/cloud_firestore.dart'; // <- CORREGIDO
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'; // <- CORREGIDO
import 'package:intl/intl.dart';

class ClientBalanceScreen extends StatelessWidget {
  const ClientBalanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final clientId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Pagos y Balances'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .where('clientId', isEqualTo: clientId)
            .where('status', isNotEqualTo: 'presupuesto_rechazado')
            .snapshots(),
        builder: (context, projectSnapshot) {
          if (projectSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!projectSnapshot.hasData || projectSnapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No tienes proyectos.'));
          }

          final projects = projectSnapshot.data!.docs;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('transactions')
                .where('type', isEqualTo: 'abono_cliente')
                .snapshots(),
            builder: (context, transactionSnapshot) {
              if (transactionSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final transactions = transactionSnapshot.data?.docs ?? [];

              return ListView.builder(
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  final project = projects[index];
                  final projectId = project.id;
                  final projectData = project.data() as Map<String, dynamic>;
                  final montoTotal = (projectData['montoTotal'] as num?) ?? 0;

                  final projectTransactions = transactions
                      .where((t) => t['projectId'] == projectId)
                      .toList();
                  double totalAbonado = 0;
                  for (var t in projectTransactions) {
                    totalAbonado += (t['amount'] as num?) ?? 0;
                  }

                  final saldo = montoTotal - totalAbonado;

                  return Card(
                    margin: const EdgeInsets.all(10),
                    child: ExpansionTile(
                      title: Text(projectData['projectName'] ?? 'Sin Nombre',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Saldo: \$${saldo.toStringAsFixed(2)}'),
                      children: [
                        ListTile(
                            title: const Text('Monto Total'),
                            trailing:
                                Text('\$${montoTotal.toStringAsFixed(2)}')),
                        ListTile(
                            title: const Text('Total Abonado'),
                            trailing:
                                Text('\$${totalAbonado.toStringAsFixed(2)}')),
                        const Divider(),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('Historial de Abonos',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ...projectTransactions.map((t) {
                          var date = (t['date'] as Timestamp?)?.toDate();
                          var formattedDate = date != null
                              ? DateFormat('dd/MM/yyyy').format(date)
                              : 'N/A';
                          return ListTile(
                            leading: const Icon(Icons.payment),
                            title: const Text('Abono Realizado'),
                            subtitle: Text(formattedDate),
                            trailing: Text(
                                '-\$${(t['amount'] as num).toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.red)),
                          );
                        }),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
