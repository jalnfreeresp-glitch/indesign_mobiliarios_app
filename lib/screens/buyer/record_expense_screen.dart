import 'package:cloud_firestore/cloud_firestore.dart'; // <- CORREGIDO
import 'package:flutter/material.dart';

class RecordExpenseScreen extends StatefulWidget {
  const RecordExpenseScreen({super.key});

  @override
  State<RecordExpenseScreen> createState() => _RecordExpenseScreenState();
}

class _RecordExpenseScreenState extends State<RecordExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _supplierController = TextEditingController();

  String? _selectedProjectId;
  Set<String> _expenseTypeSelection = {'gasto_materiales'};

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  Future<void> _recordExpense() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) return;

    Map<String, dynamic> dataToSave = {
      'description': _descriptionController.text.trim(),
      'amount': amount,
      'supplier': _supplierController.text.trim(),
      'type': _expenseTypeSelection.first,
      'date': FieldValue.serverTimestamp(),
    };

    if (_expenseTypeSelection.first == 'gasto_materiales') {
      dataToSave['projectId'] = _selectedProjectId;
    }

    try {
      await FirebaseFirestore.instance
          .collection('transactions')
          .add(dataToSave);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Gasto registrado con éxito'),
            backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al registrar el gasto: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Gasto'),
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
                const Text('Tipo de Gasto:',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment<String>(
                        value: 'gasto_materiales',
                        label: Text('Materiales'),
                        icon: Icon(Icons.handyman)),
                    ButtonSegment<String>(
                        value: 'gasto_varios',
                        label: Text('Varios'),
                        icon: Icon(Icons.receipt)),
                  ],
                  selected: _expenseTypeSelection,
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _expenseTypeSelection = newSelection;
                    });
                  },
                ),
                const SizedBox(height: 24),
                if (_expenseTypeSelection.first == 'gasto_materiales')
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('projects')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }
                      return DropdownButtonFormField<String>(
                        initialValue: _selectedProjectId,
                        hint: const Text('Seleccionar Proyecto Asociado'),
                        items: snapshot.data!.docs.map((project) {
                          return DropdownMenuItem(
                            value: project.id,
                            child: Text(project['projectName'] as String? ??
                                'Sin Nombre'),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _selectedProjectId = value),
                        validator: (value) {
                          if (value == null) {
                            return 'Seleccione un proyecto';
                          }
                          return null;
                        },
                      );
                    },
                  ),
                TextFormField(
                  controller: _descriptionController,
                  decoration:
                      const InputDecoration(labelText: 'Descripción del Gasto'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese una descripción';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _supplierController,
                  decoration:
                      const InputDecoration(labelText: 'Proveedor (Opcional)'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: 'Monto'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese un monto';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _recordExpense,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50)),
                  child: const Text('Guardar Gasto'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
