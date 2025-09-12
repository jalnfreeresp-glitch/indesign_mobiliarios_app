import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Modelo auxiliar para manejar las cuotas más fácilmente
class Installment {
  final String saleId;
  final String customerName;
  final DateTime dueDate;
  final double amount;
  final int installmentIndex;

  Installment({
    required this.saleId,
    required this.customerName,
    required this.dueDate,
    required this.amount,
    required this.installmentIndex,
  });
}

class UpcomingInstallmentsScreen extends StatefulWidget {
  const UpcomingInstallmentsScreen({super.key});

  @override
  State<UpcomingInstallmentsScreen> createState() =>
      _UpcomingInstallmentsScreenState();
}

class _UpcomingInstallmentsScreenState
    extends State<UpcomingInstallmentsScreen> {
  Future<void> _markAsPaid(Installment installment) async {
    final saleRef = FirebaseFirestore.instance
        .collection('credit_sales')
        .doc(installment.saleId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final saleDoc = await transaction.get(saleRef);
        if (!saleDoc.exists) return;

        var saleData = saleDoc.data()!;
        List installments = saleData['installments'];

        installments[installment.installmentIndex]['isPaid'] = true;
        installments[installment.installmentIndex]['paymentDate'] =
            Timestamp.now();

        final newRemainingDebt =
            (saleData['remainingDebt'] as num) - installment.amount;

        final bool isFullyPaid = newRemainingDebt <= 0;

        transaction.update(saleRef, {
          'installments': installments,
          'remainingDebt': newRemainingDebt,
          'isFullyPaid': isFullyPaid,
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuota marcada como pagada.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cronograma de Pagos'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('credit_sales')
            .where('isFullyPaid', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay cuotas pendientes.'));
          }

          List<Installment> upcomingInstallments = [];
          for (var doc in snapshot.data!.docs) {
            var saleData = doc.data() as Map<String, dynamic>;
            var installmentsList = saleData['installments'] as List;

            for (int i = 0; i < installmentsList.length; i++) {
              var inst = installmentsList[i];
              final dueDateValue = inst['dueDate']; // Obtenemos el valor

              // --- CORRECCIÓN AQUÍ ---
              // Verificamos que la cuota no esté pagada Y que la fecha sea válida
              if (inst['isPaid'] == false && dueDateValue is Timestamp) {
                upcomingInstallments.add(
                  Installment(
                    saleId: doc.id,
                    customerName: saleData['customerName'],
                    dueDate: dueDateValue.toDate(), // Ahora esto es seguro
                    amount: (inst['amount'] as num).toDouble(),
                    installmentIndex: i,
                  ),
                );
              }
            }
          }

          upcomingInstallments.sort((a, b) => a.dueDate.compareTo(b.dueDate));

          if (upcomingInstallments.isEmpty) {
            return const Center(child: Text('Todas las cuotas están al día.'));
          }

          return ListView.builder(
            itemCount: upcomingInstallments.length,
            itemBuilder: (context, index) {
              final installment = upcomingInstallments[index];
              final formattedDate =
                  DateFormat('dd/MM/yyyy').format(installment.dueDate);
              final isOverdue = installment.dueDate.isBefore(DateTime.now());

              return Card(
                color: isOverdue ? Colors.red[50] : Colors.white,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title: Text(installment.customerName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Vence: $formattedDate'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\$${installment.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isOverdue ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline),
                        color: Colors.green,
                        tooltip: 'Marcar como Pagada',
                        onPressed: () => _markAsPaid(installment),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
