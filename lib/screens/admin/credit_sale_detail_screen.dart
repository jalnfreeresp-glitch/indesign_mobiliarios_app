import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreditSaleDetailScreen extends StatefulWidget {
  final DocumentSnapshot sale;
  const CreditSaleDetailScreen({super.key, required this.sale});

  @override
  State<CreditSaleDetailScreen> createState() => _CreditSaleDetailScreenState();
}

class _CreditSaleDetailScreenState extends State<CreditSaleDetailScreen> {
  // --- FUNCIÓN ACTUALIZADA CON DIÁLOGO DE CONFIRMACIÓN ---
  Future<void> _markAsPaid(int installmentIndex, double amount) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Pago'),
        content: const Text(
            '¿Estás seguro de que quieres marcar esta cuota como pagada?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, Confirmar'),
          ),
        ],
      ),
    );

    // Si el usuario no confirma (presiona cancelar o fuera del diálogo), no hacemos nada.
    if (confirm != true) return;

    final saleRef = widget.sale.reference;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final saleDoc = await transaction.get(saleRef);
        if (!saleDoc.exists) return;

        var saleData = saleDoc.data()! as Map<String, dynamic>;
        List installments = saleData['installments'];

        if (installments[installmentIndex]['isPaid'] == true) return;

        installments[installmentIndex]['isPaid'] = true;
        installments[installmentIndex]['paymentDate'] = Timestamp.now();

        final newRemainingDebt = (saleData['remainingDebt'] as num) - amount;
        final bool isFullyPaid = newRemainingDebt <= 0.01;

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
    return StreamBuilder<DocumentSnapshot>(
      stream: widget.sale.reference.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final installments =
            (data['installments'] as List).cast<Map<String, dynamic>>();

        return Scaffold(
          appBar: AppBar(
            title: Text('Detalle de Venta - ${data['customerName']}'),
            backgroundColor: Colors.orange,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildDetailCard(data),
              const SizedBox(height: 20),
              const Text('Plan de Cuotas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              ...installments.map((inst) {
                final int currentIndex = installments.indexOf(inst);
                final dueDate = (inst['dueDate'] as Timestamp).toDate();
                final isPaid = inst['isPaid'] as bool;

                return CheckboxListTile(
                  title: Text(
                      'Cuota de \$${(inst['amount'] as num).toStringAsFixed(2)}'),
                  subtitle: Text(
                      'Vence: ${DateFormat('dd/MM/yyyy').format(dueDate)}'),
                  value: isPaid,
                  onChanged: isPaid
                      ? null
                      : (bool? value) {
                          if (value == true) {
                            _markAsPaid(currentIndex,
                                (inst['amount'] as num).toDouble());
                          }
                        },
                  secondary: isPaid
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.hourglass_empty, color: Colors.orange),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailCard(Map<String, dynamic> data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Cliente:', data['customerName'] ?? 'N/A'),
            _buildDetailRow('Teléfono:', data['customerPhone'] ?? 'N/A'),
            _buildDetailRow('Monto Total:',
                '\$${(data['totalAmount'] as num).toStringAsFixed(2)}'),
            _buildDetailRow('Pago Inicial:',
                '\$${(data['initialPayment'] as num).toStringAsFixed(2)}'),
            _buildDetailRow('Deuda Restante:',
                '\$${(data['remainingDebt'] as num).toStringAsFixed(2)}',
                isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
