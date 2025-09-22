// create_project_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => const _HierarchicalMaterialSelectorDialog(),
    );

    if (result != null && result['isFinalProduct'] == true && mounted) {
      final item = BudgetItem(
        catalogNodeId: result['id'],
        name: result['name'],
        price: result['price'],
        quantity: result['quantity'], // ✅ Usamos la cantidad ingresada
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
                          'fullName': (doc.get('fullName') ?? '').toString(),
                        };
                      }).toList();

                      return DropdownButtonFormField<String>(
                        initialValue: _selectedClientId,
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

// ───────────────────────────────────────────────
// 🔧 DIALOGO MEJORADO: _HierarchicalMaterialSelectorDialog
// - Muestra ruta completa
// - Permite ingresar cantidad
// - Reabre en nodo recién creado
// ───────────────────────────────────────────────
class _HierarchicalMaterialSelectorDialog extends StatefulWidget {
  const _HierarchicalMaterialSelectorDialog();

  @override
  State<_HierarchicalMaterialSelectorDialog> createState() =>
      _HierarchicalMaterialSelectorDialogState();
}

class _HierarchicalMaterialSelectorDialogState
    extends State<_HierarchicalMaterialSelectorDialog> {
  String? _currentParentId = 'root'; // ID del nodo actual
  DocumentSnapshot<Object?>? _selectedNodeSnapshot;
  bool isFinalProduct = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _presentationController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _quantityController.text = '1'; // Inicializa con 1
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _presentationController.dispose();
    _supplierController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  // Construir ruta completa desde el padre
  Future<String> _buildFullRoute() async {
    if (_currentParentId == 'root') return 'Catálogo Principal';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('catalog_nodes')
          .doc(_currentParentId!)
          .get();
      if (!doc.exists) return '';
      final data = doc.data() as Map<String, dynamic>;
      final parentName = data['name'];
      final grandParentId = data['parentId'];
      final parentPath = await _buildFullRouteForId(grandParentId);
      return parentPath.isEmpty ? parentName : '$parentPath > $parentName';
    } catch (e) {
      return 'Error cargando ruta';
    }
  }

  Future<String> _buildFullRouteForId(String? parentId) async {
    if (parentId == null || parentId == 'root') return '';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('catalog_nodes')
          .doc(parentId)
          .get();
      if (!doc.exists) return '';
      final data = doc.data() as Map<String, dynamic>;
      final parentName = data['name'];
      final grandParentId = data['parentId'];
      final parentPath = await _buildFullRouteForId(grandParentId);
      return parentPath.isEmpty ? parentName : '$parentPath > $parentName';
    } catch (e) {
      return 'Error cargando ruta';
    }
  }

  // Cargar hijos directos
  Future<List<DocumentSnapshot<Object?>>> _loadChildren() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('catalog_nodes')
        .where('parentId', isEqualTo: _currentParentId)
        .orderBy('name')
        .get();
    return snapshot.docs;
  }

  // Crear nuevo nodo
  Future<String?> _createNode({
    required String name,
    required String parentId,
    bool isFinal = false,
    double price = 0.0,
    String presentation = '',
    String supplier = '',
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final data = {
        'name': name,
        'parentId': parentId,
        'isFinalProduct': isFinal,
        if (isFinal) 'price': price,
        if (isFinal) 'presentation': presentation,
        if (isFinal) 'suggestedSupplier': supplier,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user?.uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user?.uid,
      };

      final docRef = await FirebaseFirestore.instance
          .collection('catalog_nodes')
          .add(data);
      return docRef.id;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creando: $e')),
        );
      }
      return null;
    }
  }

  // Diálogo para crear nuevo elemento
  void _showCreateDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    bool isFinal = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Añadir Nuevo Elemento'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                        validator: (v) =>
                            (v?.isEmpty ?? true) ? 'Requerido' : null,
                      ),
                      CheckboxListTile(
                        title: const Text('Es un producto final (con precio)'),
                        value: isFinal,
                        onChanged: (value) =>
                            setState(() => isFinal = value ?? false),
                      ),
                      if (isFinal)
                        Column(
                          children: [
                            TextFormField(
                              controller: _priceController,
                              decoration:
                                  const InputDecoration(labelText: 'Precio'),
                              keyboardType: TextInputType.number,
                            ),
                            TextFormField(
                              controller: _presentationController,
                              decoration: const InputDecoration(
                                  labelText: 'Presentación'),
                            ),
                            TextFormField(
                              controller: _supplierController,
                              decoration: const InputDecoration(
                                  labelText: 'Proveedor sugerido'),
                            ),
                          ],
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
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      String fullName = nameCtrl.text.trim();
                      if (isFinal) {
                        final fullRoute = await _buildFullRoute();
                        fullName = '$fullRoute > $fullName';
                      }

                      final newId = await _createNode(
                        name: fullName,
                        parentId: _currentParentId!,
                        isFinal: isFinal,
                        price: double.tryParse(_priceController.text) ?? 0.0,
                        presentation: _presentationController.text,
                        supplier: _supplierController.text,
                      );

                      if (newId != null) {
                        if (!context.mounted) return;
                        Navigator.of(context)
                            .pop(); // Cierra el diálogo de creación

                        // 🔁 REABRIR EN EL NUEVO NODO SI NO ES PRODUCTO FINAL
                        if (!isFinal) {
                          setState(() {
                            _currentParentId = newId;
                            _selectedNodeSnapshot = null;
                            isFinalProduct = false;
                          });
                        } else {
                          final newDoc = await FirebaseFirestore.instance
                              .collection('catalog_nodes')
                              .doc(newId)
                              .get();
                          setState(() {
                            _selectedNodeSnapshot = newDoc;
                            isFinalProduct = true;
                          });
                        }
                      }
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar Material'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 📍 Mostrar ruta completa
              FutureBuilder<String>(
                future: _buildFullRoute(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text('Cargando ruta...');
                  }
                  final route = snapshot.data ?? 'Ubicación desconocida';
                  return Text(
                    '📍 Ruta: $route',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Lista de hijos
              FutureBuilder<List<DocumentSnapshot<Object?>>>(
                future: _loadChildren(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data ?? [];

                  if (docs.isEmpty) {
                    return Column(
                      children: [
                        const Text('No hay elementos en este nivel.'),
                        ElevatedButton.icon(
                          onPressed: _showCreateDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Crear uno nuevo'),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      DropdownButtonFormField<DocumentSnapshot<Object?>>(
                        hint: const Text('Selecciona un elemento'),
                        items: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final isFinal = data['isFinalProduct'] ?? false;
                          return DropdownMenuItem(
                            value: doc,
                            child: Row(
                              children: [
                                Icon(
                                  isFinal ? Icons.shopping_cart : Icons.folder,
                                  size: 18,
                                  color: isFinal ? Colors.green : Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                Text(data['name']),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (doc) async {
                          final data = doc!.data() as Map<String, dynamic>;
                          if (data['isFinalProduct'] == true) {
                            if (mounted) {
                              setState(() {
                                _selectedNodeSnapshot = doc;
                                isFinalProduct = true;
                              });
                            }
                          } else {
                            if (mounted) {
                              setState(() {
                                _currentParentId = doc.id;
                                _selectedNodeSnapshot = null;
                                isFinalProduct = false;
                              });
                            }
                          }
                        },
                      ),

                      const SizedBox(height: 16),

                      // ✅ Campo de cantidad si es producto final
                      if (isFinalProduct && _selectedNodeSnapshot != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Detalles del producto:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            ListTile(
                              title: Text((_selectedNodeSnapshot!.data()
                                  as Map)['name']),
                              subtitle: Text(
                                  '\$${((_selectedNodeSnapshot!.data() as Map)['price'] as num? ?? 0).toStringAsFixed(2)}'),
                            ),
                            TextFormField(
                              controller: _quantityController,
                              decoration: const InputDecoration(
                                labelText: 'Cantidad',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                final q = int.tryParse(v ?? '');
                                return (q == null || q <= 0)
                                    ? 'Inválida'
                                    : null;
                              },
                            ),
                          ],
                        ),

                      // Botón para crear nuevo
                      ElevatedButton.icon(
                        onPressed: _showCreateDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Crear Nuevo Elemento'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (isFinalProduct && _selectedNodeSnapshot != null) {
              final data =
                  _selectedNodeSnapshot!.data() as Map<String, dynamic>;
              final quantity = int.tryParse(_quantityController.text) ?? 1;

              Navigator.of(context).pop({
                'id': _selectedNodeSnapshot!.id,
                'name': data['name'],
                'price': data['price'],
                'presentation': data['presentation'] ?? '',
                'isFinalProduct': true,
                'quantity': quantity,
              });
            } else {
              Navigator.of(context).pop(null);
            }
          },
          child: const Text('Seleccionar'),
        ),
      ],
    );
  }
}
