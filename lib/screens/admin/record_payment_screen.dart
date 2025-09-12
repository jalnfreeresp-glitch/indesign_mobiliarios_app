import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RecordPaymentScreen extends StatefulWidget {
  const RecordPaymentScreen({super.key});

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  String? _selectedProjectId;
  Set<String> _transactionTypeSelection = {'abono_cliente'};

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _recordPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) return;

    try {
      await FirebaseFirestore.instance.collection('transactions').add({
        'projectId': _selectedProjectId,
        'amount': amount,
        'type': _transactionTypeSelection.first,
        'date': FieldValue.serverTimestamp(),
        // Añadimos una descripción genérica para que coincida con otros gastos
        'description': _transactionTypeSelection.first == 'abono_cliente'
            ? 'Abono de cliente'
            : 'Pago a carpintero',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Transacción registrada con éxito'),
            backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al registrar la transacción: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Abono o Pago'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('projects')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedProjectId,
                      hint: const Text('Seleccionar Proyecto'),
                      items: snapshot.data!.docs.map((project) {
                        return DropdownMenuItem(
                          value: project.id,
                          child: Text(project['projectName'] as String? ??
                              'Sin Nombre'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProjectId = value;
                        });
                      },
                      validator: (value) => value == null
                          ? 'Por favor, seleccione un proyecto'
                          : null,
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text('Tipo de Transacción:',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment<String>(
                        value: 'abono_cliente',
                        label: Text('Abono Cliente'),
                        icon: Icon(Icons.person_add)),
                    ButtonSegment<String>(
                        value: 'pago_carpintero',
                        label: Text('Pago Carpintero'),
                        icon: Icon(Icons.construction)),
                  ],
                  selected: _transactionTypeSelection,
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _transactionTypeSelection = newSelection;
                    });
                  },
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                      labelText: 'Monto',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese un monto';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _recordPayment,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50)),
                  child: const Text('Guardar Transacción'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
