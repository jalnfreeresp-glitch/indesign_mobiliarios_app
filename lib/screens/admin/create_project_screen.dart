// create_project_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Importar Firestore
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'material_selection_screen_temp.dart';

// --- Modelo Auxiliar ---
class BudgetItem {
  final String catalogNodeId;
  final String name;
  final double price;
  final int quantity;
  final String presentation;

  BudgetItem({
    required this.catalogNodeId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.presentation,
  });

  double get total => price * quantity;
}

// --- Pantalla Principal: Crear Proyecto ---
class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _projectNameController = TextEditingController();
  final _transportController = TextEditingController(text: '0');
  final _laborController = TextEditingController(text: '0');
  final _profitPercentageController = TextEditingController(text: '30');
  String? _selectedClientId;
  List<Map<String, String>> _clientsList = [];
  final List<BudgetItem> _budgetItems = [];
  double _materialsTotal = 0;
  double _grandTotal = 0;

  @override
  void initState() {
    super.initState();
    _transportController.addListener(_calculateTotals);
    _laborController.addListener(_calculateTotals);
    _profitPercentageController.addListener(_calculateTotals);
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _transportController.dispose();
    _laborController.dispose();
    _profitPercentageController.dispose();
    super.dispose();
  }

  void _calculateTotals() {
    _materialsTotal = _budgetItems.fold(0, (acc, item) => acc + item.total);
    final transportCost = double.tryParse(_transportController.text) ?? 0;
    final laborCost = double.tryParse(_laborController.text) ?? 0;
    final profitPercentage =
        double.tryParse(_profitPercentageController.text) ?? 0;
    final subtotal = _materialsTotal + transportCost + laborCost;
    final profitAmount = subtotal * (profitPercentage / 100);
    setState(() {
      _grandTotal = subtotal + profitAmount;
    });
  }

  Future<void> _showAddMaterialDialog() async {
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (context) => const MaterialSelectionScreenTemp(),
      ),
    );

    if (result != null && result['isFinalProduct'] == true && mounted) {
      final item = BudgetItem(
        catalogNodeId: result['id'],
        name: result['name'],
        price: result['price'],
        quantity: result['quantity'],
        presentation: result['presentation'] ?? '',
      );
      setState(() {
        _budgetItems.add(item);
        _calculateTotals();
      });
    }
  }

  Future<void> _showCreateClientDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Crear Nuevo Cliente'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration:
                        const InputDecoration(labelText: 'Nombre Completo'),
                    validator: (v) => (v?.isEmpty ?? true) ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: emailController,
                    decoration:
                        const InputDecoration(labelText: 'Correo Electrónico'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v?.isEmpty ?? true) ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                        labelText: 'Contraseña Provisional'),
                    obscureText: true,
                    validator: (v) =>
                        (v?.length ?? 0) < 6 ? 'Mínimo 6 caracteres' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop({
                    'fullName': nameController.text.trim(),
                    'email': emailController.text.trim(),
                    'password': passwordController.text,
                  });
                }
              },
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      try {
        final callable = FirebaseFunctions.instance.httpsCallable('createUser');
        await callable.call<Map<String, dynamic>>({
          'fullName': result['fullName'],
          'email': result['email'],
          'password': result['password'],
          'role': 'cliente',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Cliente creado con éxito'),
            backgroundColor: Colors.green,
          ));
        }
      } on FirebaseFunctionsException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message ?? 'Ocurrió un error'),
            backgroundColor: Colors.red,
          ));
        }
      }
    }
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate() || _selectedClientId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Por favor, completa todos los campos requeridos.'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    final projectRef = FirebaseFirestore.instance.collection('projects').doc();
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      batch.set(projectRef, {
        'clientId': _selectedClientId,
        'projectName': _projectNameController.text,
        'costoMateriales': _materialsTotal,
        'costoTransporte': double.tryParse(_transportController.text) ?? 0,
        'costoManoDeObra': double.tryParse(_laborController.text) ?? 0,
        'porcentajeGanancia':
            double.tryParse(_profitPercentageController.text) ?? 0,
        'montoTotal': _grandTotal,
        'status': 'presupuesto_pendiente',
        'isArchived': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      for (final item in _budgetItems) {
        final budgetItemRef = projectRef.collection('budget_items').doc();
        batch.set(budgetItemRef, {
          'catalogNodeId': item.catalogNodeId,
          'name': item.name,
          'unitPrice': item.price,
          'quantity': item.quantity,
          'presentation': item.presentation,
          'totalAmount': item.total,
          'status': 'pendiente',
        });

        final shoppingListItemRef =
            FirebaseFirestore.instance.collection('shopping_list').doc();
        batch.set(shoppingListItemRef, {
          'catalogNodeId': item.catalogNodeId,
          'materialName': item.name,
          'quantity': '${item.quantity} ${item.presentation}',
          'projectName': _projectNameController.text,
          'projectId': projectRef.id,
          'isPurchased': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculadora de Presupuesto'),
        backgroundColor: Colors.orange,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Datos del Cliente',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Object?>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: 'cliente')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                            child: Text("Cargando clientes..."));
                      }
                      _clientsList = snapshot.data!.docs.map((doc) {
                        return {
                          'uid': doc.id,
                          'fullName': (doc.get('fullName') ?? '').toString(),
                        };
                      }).toList();

                      return DropdownButtonFormField<String>(
                        initialValue:
                            _selectedClientId, // ✅ Corregido: 'value' -> 'initialValue'
                        hint: const Text('Seleccionar Cliente'),
                        items: _clientsList.map((client) {
                          return DropdownMenuItem(
                            value: client['uid'],
                            child: Text(client['fullName']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (mounted) {
                            setState(() => _selectedClientId = value);
                          }
                        },
                        validator: (value) =>
                            value == null ? 'Seleccione un cliente' : null,
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  tooltip: 'Crear Cliente Nuevo',
                  onPressed: _showCreateClientDialog,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _projectNameController,
              decoration:
                  const InputDecoration(labelText: 'Nombre del Proyecto'),
              validator: (value) =>
                  (value?.isEmpty ?? true) ? 'Ingrese un nombre' : null,
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Materiales',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Subtotal: \$${_materialsTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            ..._budgetItems.map((item) => ListTile(
                  title: Text('${item.name} (x${item.quantity})'),
                  subtitle: Text(
                      '\$${item.price.toStringAsFixed(2)} c/u (${item.presentation})'),
                  trailing: Text('\$${item.total.toStringAsFixed(2)}'),
                )),
            TextButton.icon(
              onPressed: _showAddMaterialDialog,
              icon: const Icon(Icons.add),
              label: const Text('Añadir Material'),
            ),
            const Divider(height: 20),
            const Text(
              'Costos y Ganancia',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextFormField(
              controller: _transportController,
              decoration:
                  const InputDecoration(labelText: 'Costo de Transporte (USD)'),
            ),
            TextFormField(
              controller: _laborController,
              decoration:
                  const InputDecoration(labelText: 'Monto Mano de Obra (USD)'),
            ),
            TextFormField(
              controller: _profitPercentageController,
              decoration: const InputDecoration(
                  labelText: 'Porcentaje de Ganancia (%)'),
            ),
            const Divider(height: 20),
            Card(
              color: Colors.grey[200],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Resumen Final',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      title: const Text(
                        'TOTAL FINAL PRESUPUESTADO',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      trailing: Text(
                        '\$${_grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveBudget,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Guardar Presupuesto'),
            ),
          ],
        ),
      ),
    );
  }
}
