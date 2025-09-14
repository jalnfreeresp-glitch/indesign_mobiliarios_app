import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

// --- Modelo Auxiliar ---
class BudgetItem {
  String name;
  String category;
  double price;
  int quantity;
  String presentation;
  BudgetItem(
      {required this.name,
      required this.category,
      required this.price,
      required this.quantity,
      required this.presentation});

  double get total => price * quantity;
}

// --- Pantalla Principal ---
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
    _materialsTotal = _budgetItems.fold(
        0, (previousValue, item) => previousValue + item.total);
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
    final BudgetItem? newItem = await showDialog<BudgetItem>(
      context: context,
      builder: (context) => const _AddMaterialDialog(),
    );

    if (newItem != null) {
      setState(() {
        _budgetItems.add(newItem);
        _calculateTotals();
      });
    }
  }

  Future<void> _showCreateClientDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
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
                      validator: (v) => v!.isEmpty ? 'Requerido' : null),
                  TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                          labelText: 'Correo Electrónico'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v!.isEmpty ? 'Requerido' : null),
                  TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                          labelText: 'Contraseña Provisional'),
                      obscureText: true,
                      validator: (v) =>
                          v!.length < 6 ? 'Mínimo 6 caracteres' : null),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop({
                    'fullName': nameController.text,
                    'email': emailController.text,
                    'password': passwordController.text,
                  });
                }
              },
              child: const Text('Crear'),
            )
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
              backgroundColor: Colors.green));
        }
      } on FirebaseFunctionsException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(e.message ?? 'Ocurrió un error'),
              backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate() || _selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Por favor, completa todos los campos requeridos.'),
          backgroundColor: Colors.red));
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
          'materialName': item.name,
          'quantity': '${item.quantity} ${item.presentation}',
          'projectName': _projectNameController.text,
          'projectId': projectRef.id,
          'isPurchased': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) Navigator.pop(context);
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
          backgroundColor: Colors.orange),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Datos del Cliente',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
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
                          'fullName': doc['fullName'] as String
                        };
                      }).toList();
                      return DropdownButtonFormField<String>(
                        initialValue: _selectedClientId,
                        hint: const Text('Seleccionar Cliente'),
                        items: _clientsList
                            .map((client) => DropdownMenuItem(
                                value: client['uid'],
                                child: Text(client['fullName']!)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedClientId = value),
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
                )
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _projectNameController,
              decoration:
                  const InputDecoration(labelText: 'Nombre del Proyecto'),
              validator: (value) => value!.isEmpty ? 'Ingrese un nombre' : null,
            ),
            const Divider(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Materiales',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Subtotal: \$${_materialsTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16)),
            ]),
            ..._budgetItems.map((item) => ListTile(
                  title: Text('${item.name} (x${item.quantity})'),
                  subtitle: Text(
                      '${item.presentation} a \$${item.price.toStringAsFixed(2)} c/u'),
                  trailing: Text('\$${item.total.toStringAsFixed(2)}'),
                )),
            TextButton.icon(
                onPressed: _showAddMaterialDialog,
                icon: const Icon(Icons.add),
                label: const Text('Añadir Material')),
            const Divider(height: 20),
            const Text('Costos y Ganancia',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextFormField(
                controller: _transportController,
                decoration: const InputDecoration(
                    labelText: 'Costo de Transporte (USD)')),
            TextFormField(
                controller: _laborController,
                decoration: const InputDecoration(
                    labelText: 'Monto Mano de Obra (USD)')),
            TextFormField(
                controller: _profitPercentageController,
                decoration: const InputDecoration(
                    labelText: 'Porcentaje de Ganancia (%)')),
            const Divider(height: 20),
            Card(
              color: Colors.grey[200],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Resumen Final',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ListTile(
                      title: const Text('TOTAL FINAL PRESUPUESTADO',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      trailing: Text('\$${_grandTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: _saveBudget,
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50)),
                child: const Text('Guardar Presupuesto')),
          ],
        ),
      ),
    );
  }
}

enum MaterialInputType { existente, nuevo }

class _AddMaterialDialog extends StatefulWidget {
  const _AddMaterialDialog();
  @override
  State<_AddMaterialDialog> createState() => _AddMaterialDialogState();
}

class _AddMaterialDialogState extends State<_AddMaterialDialog> {
  MaterialInputType _selection = MaterialInputType.existente;

  List<String> _categories = [];
  String? _selectedCategoryName;
  String? _selectedMaterialTypeId;
  String? _selectedVariantId;

  DocumentSnapshot? _selectedMaterialTypeSnapshot;
  DocumentSnapshot? _selectedVariantSnapshot;

  final _newMaterialNameController = TextEditingController();
  final _newMaterialPriceController = TextEditingController();
  final _newMaterialPresentationController = TextEditingController();
  final _quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('material_categories')
        .orderBy('name')
        .get();
    if (mounted) {
      setState(() {
        _categories =
            snapshot.docs.map((doc) => doc['name'] as String).toList();
      });
    }
  }

  Future<void> _addNewCategory() async {
    final categoryController = TextEditingController();
    final newCategory = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Añadir Nueva Categoría'),
              content: TextFormField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                      labelText: 'Nombre de la categoría')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar')),
                ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(categoryController.text),
                    child: const Text('Añadir')),
              ],
            ));

    if (newCategory != null && newCategory.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('material_categories')
          .add({'name': newCategory});
      setState(() {
        _selectedCategoryName = newCategory;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Añadir Material al Presupuesto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<MaterialInputType>(
              segments: const <ButtonSegment<MaterialInputType>>[
                ButtonSegment<MaterialInputType>(
                    value: MaterialInputType.existente,
                    label: Text('Existente')),
                ButtonSegment<MaterialInputType>(
                    value: MaterialInputType.nuevo, label: Text('Nuevo')),
              ],
              selected: {_selection},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _selection = newSelection.first;
                });
              },
            ),
            const Divider(height: 20),
            if (_selection == MaterialInputType.existente) ...[
              DropdownButtonFormField<String>(
                hint: const Text('Seleccionar Categoría'),
                value: _selectedCategoryName,
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) => setState(() {
                  _selectedCategoryName = value;
                  _selectedMaterialTypeId = null;
                  _selectedVariantId = null;
                }),
              ),
              if (_selectedCategoryName != null)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('material_types')
                      .where('categoryName', isEqualTo: _selectedCategoryName)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    return DropdownButtonFormField<String>(
                      hint: const Text('Seleccionar Material'),
                      value: _selectedMaterialTypeId,
                      items: snapshot.data!.docs
                          .map((doc) => DropdownMenuItem(
                              value: doc.id, child: Text(doc['name'])))
                          .toList(),
                      onChanged: (value) => setState(() {
                        _selectedMaterialTypeId = value;
                        _selectedVariantId = null;
                        _selectedMaterialTypeSnapshot = value != null
                            ? snapshot.data!.docs
                                .firstWhere((doc) => doc.id == value)
                            : null;
                      }),
                    );
                  },
                ),
              if (_selectedMaterialTypeId != null)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('material_types')
                      .doc(_selectedMaterialTypeId)
                      .collection('variants')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    return DropdownButtonFormField<String>(
                      hint: const Text('Seleccionar Variante'),
                      value: _selectedVariantId,
                      items: snapshot.data!.docs.map((doc) {
                        final attributes =
                            doc['attributes'] as Map<String, dynamic>;
                        final description = attributes.values.join(' - ');
                        return DropdownMenuItem(
                            value: doc.id, child: Text(description));
                      }).toList(),
                      onChanged: (value) => setState(() {
                        _selectedVariantId = value;
                        _selectedVariantSnapshot = value != null
                            ? snapshot.data!.docs
                                .firstWhere((doc) => doc.id == value)
                            : null;
                      }),
                    );
                  },
                ),
            ],
            if (_selection == MaterialInputType.nuevo) ...[
              DropdownButtonFormField<String>(
                hint: const Text('Seleccionar Categoría'),
                value: _selectedCategoryName,
                items: [
                  ..._categories.map((c) =>
                      DropdownMenuItem<String>(value: c, child: Text(c))),
                  const DropdownMenuItem<String>(
                      value: 'ADD_NEW',
                      child: Text('Añadir categoría nueva...',
                          style: TextStyle(fontStyle: FontStyle.italic))),
                ],
                onChanged: (value) {
                  if (value == 'ADD_NEW') {
                    _addNewCategory();
                  } else {
                    setState(() => _selectedCategoryName = value);
                  }
                },
              ),
              TextFormField(
                  controller: _newMaterialNameController,
                  decoration: const InputDecoration(
                      labelText: 'Nombre del Nuevo Material (Tipo)')),
              TextFormField(
                  controller: _newMaterialPresentationController,
                  decoration: const InputDecoration(
                      labelText: 'Presentación (ej. lámina, caja)')),
              const Divider(height: 20, thickness: 1),
              const Text('Primera Variante:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                  controller: _newMaterialPriceController,
                  decoration: const InputDecoration(
                      labelText: 'Precio de la Variante (USD)'),
                  keyboardType: TextInputType.number),
            ],
            const SizedBox(height: 10),
            TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'Cantidad'),
                keyboardType: TextInputType.number),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () async {
            final quantity = int.tryParse(_quantityController.text) ?? 0;
            if (quantity <= 0) return;

            BudgetItem? itemToReturn;
            if (_selection == MaterialInputType.nuevo) {
              final materialTypeRef = await FirebaseFirestore.instance
                  .collection('material_types')
                  .add({
                'name': _newMaterialNameController.text,
                'categoryName': _selectedCategoryName ?? 'Varios',
              });

              final variantData = {
                'attributes': {
                  'descripcion': 'Estándar'
                }, // Variante por defecto
                'price':
                    double.tryParse(_newMaterialPriceController.text) ?? 0.0,
                'presentation': _newMaterialPresentationController.text,
              };
              await materialTypeRef.collection('variants').add(variantData);

              itemToReturn = BudgetItem(
                name: '${_newMaterialNameController.text} (Estándar)',
                category: _selectedCategoryName ?? 'Varios',
                price: variantData['price'] as double,
                quantity: quantity,
                presentation: variantData['presentation'] as String,
              );
            } else if (_selectedVariantSnapshot != null) {
              final materialName = _selectedMaterialTypeSnapshot!['name'];
              final categoryName = _selectedCategoryName!;
              final variantData =
                  _selectedVariantSnapshot!.data() as Map<String, dynamic>;
              final attributes =
                  variantData['attributes'] as Map<String, dynamic>;
              final description = attributes.values.join(' - ');

              itemToReturn = BudgetItem(
                name: '$materialName ($description)',
                category: categoryName,
                price: (variantData['price'] as num).toDouble(),
                quantity: quantity,
                presentation: variantData['presentation'],
              );
            }
            if (mounted) Navigator.of(context).pop(itemToReturn);
          },
          child: const Text('Añadir al Presupuesto'),
        ),
      ],
    );
  }
}
