import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CreateCreditSaleScreen extends StatefulWidget {
  const CreateCreditSaleScreen({super.key});

  @override
  State<CreateCreditSaleScreen> createState() => _CreateCreditSaleScreenState();
}

class _CreateCreditSaleScreenState extends State<CreateCreditSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _levelController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _initialPaymentController = TextEditingController();

  String _initialPaymentMethod = 'efectivo_usd';
  int _numberOfInstallments = 3;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _levelController.dispose();
    _totalAmountController.dispose();
    _initialPaymentController.dispose();
    super.dispose();
  }

  Future<void> _saveCreditSale() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final totalAmount = double.tryParse(_totalAmountController.text) ?? 0;
    final initialPayment = double.tryParse(_initialPaymentController.text) ?? 0;
    final remainingDebt = totalAmount - initialPayment;
    final installmentAmount = remainingDebt / _numberOfInstallments;

    List<Map<String, dynamic>> installments = [];
    DateTime nextDueDate = DateTime.now().add(const Duration(days: 15));
    for (int i = 0; i < _numberOfInstallments; i++) {
      installments.add({
        'dueDate': Timestamp.fromDate(nextDueDate),
        'amount': installmentAmount,
        'isPaid': false,
        'paymentDate': null,
      });
      nextDueDate = nextDueDate.add(const Duration(days: 15));
    }

    try {
      await FirebaseFirestore.instance.collection('credit_sales').add({
        'customerName': _nameController.text,
        'customerPhone': _phoneController.text,
        'customerLevel': int.tryParse(_levelController.text) ?? 1,
        'totalAmount': totalAmount,
        'initialPayment': initialPayment,
        'initialPaymentMethod': _initialPaymentMethod,
        'remainingDebt': remainingDebt,
        'numberOfInstallments': _numberOfInstallments,
        'installmentAmount': installmentAmount,
        'installments': installments,
        'saleDate': FieldValue.serverTimestamp(),
        'isFullyPaid': false,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Venta a crédito registrada')));
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
        title: const Text('Registrar Venta a Crédito'),
        backgroundColor: Colors.orange,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
                controller: _nameController,
                decoration:
                    const InputDecoration(labelText: 'Nombre del Cliente'),
                validator: (v) => v!.isEmpty ? 'Requerido' : null),
            const SizedBox(height: 16),
            TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                    labelText: 'Teléfono del Cliente (para identificar pagos)'),
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Requerido' : null),
            const SizedBox(height: 16),
            TextFormField(
                controller: _levelController,
                decoration:
                    const InputDecoration(labelText: 'Nivel Cashea (1-6)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => v!.isEmpty ? 'Requerido' : null),
            const SizedBox(height: 16),
            TextFormField(
                controller: _totalAmountController,
                decoration: const InputDecoration(
                    labelText: 'Monto Total de la Venta (USD)'),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Requerido' : null),
            const SizedBox(height: 16),
            TextFormField(
                controller: _initialPaymentController,
                decoration:
                    const InputDecoration(labelText: 'Pago Inicial (USD)'),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Requerido' : null),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              // --- CORREGIDO ---
              initialValue: _initialPaymentMethod,
              items: const [
                DropdownMenuItem(
                    value: 'efectivo_usd', child: Text('Dólares en Efectivo')),
                DropdownMenuItem(
                    value: 'transferencia_bs',
                    child: Text('Transferencia (Bs)')),
                DropdownMenuItem(
                    value: 'pagomovil_bs', child: Text('Pago Móvil (Bs)')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _initialPaymentMethod = value);
                }
              },
              decoration:
                  const InputDecoration(labelText: 'Método de Pago Inicial'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              // --- CORREGIDO ---
              initialValue: _numberOfInstallments,
              items: const [
                DropdownMenuItem(value: 3, child: Text('3 Cuotas')),
                DropdownMenuItem(value: 6, child: Text('6 Cuotas')),
                DropdownMenuItem(value: 9, child: Text('9 Cuotas')),
                DropdownMenuItem(value: 12, child: Text('12 Cuotas')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _numberOfInstallments = value);
                }
              },
              decoration: const InputDecoration(labelText: 'Plan de Pagos'),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveCreditSale,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Guardar Venta'),
            ),
          ],
        ),
      ),
    );
  }
}
