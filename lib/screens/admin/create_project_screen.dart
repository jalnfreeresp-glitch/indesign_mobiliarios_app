// create_project_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // Eliminado ya que no se usa directamente aquí
import 'package:flutter/material.dart';

// --- Modelo Auxiliar Actualizado ---
class BudgetItem {
  String catalogNodeId; // ID del documento en catalog_nodes
  String name; // Nombre completo del material con ruta
  double price;
  int quantity;
  String presentation;

  BudgetItem({
    required this.catalogNodeId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.presentation,
  });

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
      builder: (context) => const _AddMaterialFromCatalogDialog(),
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
      builder: (BuildContext context) {
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
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop({
                    'fullName': nameController.text,
                    'email': emailController.text,
                    'password': passwordController.text,
                  });
                }
              },
              // Corrección 4: Añadir 'const' para mejorar el rendimiento
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
          'catalogNodeId': item.catalogNodeId, // ID del nodo en catalog_nodes
          'name': item.name, // Nombre completo del material
          'unitPrice': item.price,
          'quantity': item.quantity,
          'presentation': item.presentation,
          'totalAmount': item.total,
          'status': 'pendiente',
        });
        final shoppingListItemRef =
            FirebaseFirestore.instance.collection('shopping_list').doc();
        batch.set(shoppingListItemRef, {
          'catalogNodeId': item.catalogNodeId, // ID del nodo en catalog_nodes
          'materialName': item.name, // Nombre completo del material
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
                      // Corrección 5: Usar initialValue en lugar de value (para DropdownButtonFormField)
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

// --- Diálogo para Añadir Material del Nuevo Catálogo (Versión con Dropdowns Corregida) ---
class _AddMaterialFromCatalogDialog extends StatefulWidget {
  const _AddMaterialFromCatalogDialog();

  @override
  State<_AddMaterialFromCatalogDialog> createState() =>
      _AddMaterialFromCatalogDialogState();
}

class _AddMaterialFromCatalogDialogState
    extends State<_AddMaterialFromCatalogDialog> {
  String? _selectedCategoryId; // ID de la categoría seleccionada
  String? _selectedSubcategoryId; // ID de la subcategoría seleccionada
  String? _selectedProductId; // ID del producto final seleccionado
  DocumentSnapshot? _selectedProductSnapshot; // Datos del producto seleccionado

  final _quantityController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    // Inicialmente, no cargamos nada hasta que el usuario seleccione una categoría.
    // Las listas se cargarán dinámicamente.
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  // Cargar subcategorías basadas en la categoría seleccionada
  Future<List<DocumentSnapshot>> _loadSubcategories(String categoryId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('catalog_nodes')
        .where('parentId', isEqualTo: categoryId)
        .where('isFinalProduct', isEqualTo: false) // Solo nodos intermedios
        .orderBy('name')
        .get();
    return snapshot.docs;
  }

  // Cargar productos finales basados en cualquier nodo padre (categoría o subcategoría)
  Future<List<DocumentSnapshot>> _loadProducts(String parentId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('catalog_nodes')
        .where('parentId', isEqualTo: parentId)
        .where('isFinalProduct', isEqualTo: true) // Solo productos finales
        .orderBy('name')
        .get();
    return snapshot.docs;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Añadir Material del Catálogo'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Selecciona la ruta del material:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              // Dropdown para Categorías (Raíz)
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('catalog_nodes')
                    .where('parentId', isEqualTo: 'root')
                    .orderBy('name')
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return DropdownButton<String>(
                      hint: const Text('Cargando categorías...'),
                      items: null,
                      onChanged: null,
                    );
                  }
                  if (snapshot.hasError) {
                    return Text(
                        'Error al cargar categorías: ${snapshot.error}');
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text('No hay categorías disponibles.');
                  }

                  final categories = snapshot.data!.docs;
                  return DropdownButtonFormField<String>(
                    hint: const Text('Seleccionar Categoría'),
                    // Corrección 6: Usar initialValue en lugar de value
                    initialValue: _selectedCategoryId,
                    items: categories.map((DocumentSnapshot doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text(data['name'] as String? ?? 'Sin nombre'),
                      );
                    }).toList(),
                    onChanged: (String? newValue) async {
                      if (newValue == null) return;

                      // 1. Actualizar categoría seleccionada
                      setState(() {
                        _selectedCategoryId = newValue;
                        _selectedSubcategoryId = null;
                        _selectedProductId = null;
                        _selectedProductSnapshot = null;
                      });

                      // 2. Cargar subcategorías y productos directos de la categoría
                      // No necesitamos esperar a que terminen para setState,
                      // ya que los Dropdowns se reconstruirán con el nuevo estado.
                      // Pero podemos manejar errores si es necesario.
                      try {
                        // Intentar cargar subcategorías
                        // Corrección 2: Eliminar variables no usadas
                        await _loadSubcategories(newValue);
                        await _loadProducts(newValue);

                        // Si no hay subcategorías, forzar la carga de productos directos
                        // Esto se maneja en la lógica de construcción de widgets
                      } catch (e) {
                        // Corrección 7: Verificar mounted antes de usar context
                        if (!context.mounted) return;
                        {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Error al cargar datos: $e')),
                          );
                        }
                      }
                    },
                    validator: (value) =>
                        value == null ? 'Seleccione una categoría' : null,
                  );
                },
              ),
              const SizedBox(height: 10),

              // Dropdown para Subcategorías (solo si hay)
              // Solo se muestra si hay una categoría seleccionada
              if (_selectedCategoryId != null) ...[
                FutureBuilder<List<DocumentSnapshot>>(
                  future: _selectedCategoryId != null
                      ? _loadSubcategories(_selectedCategoryId!)
                      : Future.value([]),
                  builder: (context, snapshot) {
                    // Si no hay subcategorías, no mostrar este dropdown
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('Buscando subcategorías...'),
                      );
                    }
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      // No hay subcategorías, no mostrar dropdown
                      return const SizedBox.shrink();
                    }

                    final subcategories = snapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          hint: const Text('Seleccionar Subcategoría'),
                          // Corrección 8: Usar initialValue en lugar de value
                          initialValue: _selectedSubcategoryId,
                          items: subcategories.map((DocumentSnapshot doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child:
                                  Text(data['name'] as String? ?? 'Sin nombre'),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedSubcategoryId = newValue;
                              _selectedProductId =
                                  null; // Resetear producto al cambiar subcat
                              _selectedProductSnapshot = null;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    );
                  },
                ),
              ],

              // Dropdown para Productos Finales
              // Se muestra si:
              // 1. Hay una categoría seleccionada
              // 2. O hay una subcategoría seleccionada, o no hay subcategorías (productos directos)
              if (_selectedCategoryId != null) ...[
                FutureBuilder<List<DocumentSnapshot>>(
                  future: () async {
                    // Determinar el parentId para los productos
                    String parentId =
                        _selectedSubcategoryId ?? _selectedCategoryId!;
                    return await _loadProducts(parentId);
                  }(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('Buscando productos...'),
                      );
                    }
                    if (snapshot.hasError) {
                      return Text(
                          'Error al cargar productos: ${snapshot.error}');
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text(
                          'No hay productos finales en esta ruta.');
                    }

                    final products = snapshot.data!;
                    return DropdownButtonFormField<String>(
                      hint: const Text('Seleccionar Producto Final'),
                      // Corrección 9: Usar initialValue en lugar de value
                      initialValue: _selectedProductId,
                      items: products.map((DocumentSnapshot doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        // Mostrar solo el nombre base del producto
                        final fullName =
                            data['name'] as String? ?? 'Sin nombre';
                        final parts = fullName.split(' > ');
                        final displayName =
                            parts.isNotEmpty ? parts.last : fullName;
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(
                            displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedProductId = newValue;
                          // Encontrar y almacenar el snapshot del producto seleccionado
                          if (newValue != null) {
                            final index = products
                                .indexWhere((doc) => doc.id == newValue);
                            _selectedProductSnapshot =
                                index != -1 ? products[index] : null;
                          } else {
                            _selectedProductSnapshot = null;
                          }
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Seleccione un producto' : null,
                    );
                  },
                ),
                const SizedBox(height: 10),
              ],

              // Detalles del producto seleccionado y cantidad
              if (_selectedProductSnapshot != null) ...[
                const Divider(),
                const Text('Producto Seleccionado:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ListTile(
                  title: Text(
                    (_selectedProductSnapshot!.data()
                            as Map<String, dynamic>)['name']
                        .toString(),
                  ),
                  subtitle: Text(
                    'Precio: \$${((_selectedProductSnapshot!.data() as Map<String, dynamic>)['price'] as num? ?? 0).toStringAsFixed(2)}',
                  ),
                ),
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese una cantidad';
                    }
                    final quantity = int.tryParse(value);
                    if (quantity == null || quantity <= 0) {
                      return 'Cantidad inválida';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 10),
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
            // Validación y retorno del item
            if (_selectedProductSnapshot == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Por favor, selecciona un producto final.')),
              );
              return;
            }

            final quantityText = _quantityController.text;
            if (quantityText.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Por favor, ingresa una cantidad.')),
              );
              return;
            }

            final quantity = int.tryParse(quantityText);
            if (quantity == null || quantity <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Por favor, ingresa una cantidad válida.')),
              );
              return;
            }

            final data =
                _selectedProductSnapshot!.data() as Map<String, dynamic>;
            final nodeId = _selectedProductSnapshot!.id;
            final fullName = data['name'] as String? ?? 'Sin nombre';
            final price = (data['price'] as num?)?.toDouble() ?? 0.0;
            final presentation = data['presentation'] as String? ?? '';

            final itemToReturn = BudgetItem(
              catalogNodeId: nodeId,
              name: fullName, // Nombre completo con ruta
              price: price,
              quantity: quantity,
              presentation: presentation,
            );

            Navigator.of(context).pop(itemToReturn);
          },
          // Corrección 10: Añadir 'const' para mejorar el rendimiento
          child: const Text('Añadir al Presupuesto'),
        ),
      ],
    );
  }
}
