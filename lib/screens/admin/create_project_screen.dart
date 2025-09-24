// create_project_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:indesign_mobiliarios_app/constants.dart';
import 'package:indesign_mobiliarios_app/providers/catalog_provider.dart';
import 'package:provider/provider.dart';

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
class CreateProjectScreen extends StatelessWidget {
  const CreateProjectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CatalogProvider(),
      child: const _CreateProjectView(),
    );
  }
}

class _CreateProjectView extends StatefulWidget {
  const _CreateProjectView();

  @override
  State<_CreateProjectView> createState() => _CreateProjectViewState();
}

class _CreateProjectViewState extends State<_CreateProjectView> {
  final _formKey = GlobalKey<FormState>();
  final _projectNameController = TextEditingController();
  final _transportController = TextEditingController(text: '0');
  final _laborController = TextEditingController(text: '0');
  final _profitPercentageController = TextEditingController(text: '30');
  String? _selectedClientId;
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

    final projectRef = FirebaseFirestore.instance.collection(projectsCollection).doc();
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
            FirebaseFirestore.instance.collection(shoppingListCollection).doc();
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

  void _showQuantityDialog(DocumentSnapshot materialNode) {
    final quantityController = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Añadir Material'),
          content: TextField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cantidad'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final quantity = int.tryParse(quantityController.text) ?? 0;
                if (quantity > 0) {
                  final data = materialNode.data() as Map<String, dynamic>;
                  final item = BudgetItem(
                    catalogNodeId: materialNode.id,
                    name: data['name'],
                    price: (data['price'] as num).toDouble(),
                    quantity: quantity,
                    presentation: data['presentation'] ?? '',
                  );
                  setState(() {
                    _budgetItems.add(item);
                    _calculateTotals();
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Añadir'),
            ),
          ],
        );
      },
    );
  }

  void _showAddNodeDialog({String parentId = 'root'}) {
    final catalogProvider =
        Provider.of<CatalogProvider>(context, listen: false);
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final presentationController = TextEditingController();
    final supplierController = TextEditingController();
    bool isFinalProduct = false;

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
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Nombre',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.label),
                        ),
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Es un producto final (con precio)'),
                        value: isFinalProduct,
                        onChanged: (value) {
                          setState(() {
                            isFinalProduct = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      if (isFinalProduct) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: priceController,
                          decoration: InputDecoration(
                            labelText: 'Precio (USD)',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.attach_money),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v!.isEmpty) return 'Requerido';
                            if (double.tryParse(v) == null) {
                              return 'Número inválido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: presentationController,
                          decoration: InputDecoration(
                            labelText: 'Presentación (ej. lámina)',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.description),
                          ),
                          validator: (v) => v!.isEmpty ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: supplierController,
                          decoration: InputDecoration(
                            labelText: 'Proveedor sugerido',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.store),
                          ),
                        ),
                      ],
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      String fullName = nameController.text.trim();
                      if (isFinalProduct) {
                        final parentRoute =
                            await catalogProvider.buildFullRouteForId(parentId);
                        fullName = parentRoute.isEmpty
                            ? fullName
                            : '$parentRoute > $fullName';
                      }
                      await catalogProvider.createNode(
                        name: fullName,
                        parentId: parentId,
                        isFinalProduct: isFinalProduct,
                        price: double.tryParse(priceController.text) ?? 0.0,
                        presentation: presentationController.text.trim(),
                        supplier: supplierController.text.trim(),
                      );

                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Elemento creado con éxito'),
                        backgroundColor: Colors.green,
                      ));
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

  void _showEditDeleteDialog(DocumentSnapshot node) {
    final catalogProvider =
        Provider.of<CatalogProvider>(context, listen: false);
    final data = node.data() as Map<String, dynamic>;
    String displayName = data['name'];
    if (data['isFinalProduct'] == true) {
      final parts = displayName.split(' > ');
      if (parts.length > 1) {
        displayName = parts.last;
      }
    }
    final nameController = TextEditingController(text: displayName);
    final priceController =
        TextEditingController(text: data['price']?.toString() ?? '');
    final presentationController =
        TextEditingController(text: data['presentation'] ?? '');
    final supplierController =
        TextEditingController(text: data['suggestedSupplier'] ?? '');
    bool isFinalProduct = data['isFinalProduct'] ?? false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Editar Elemento'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Nombre')),
                    CheckboxListTile(
                      title: const Text('Es un producto final (con precio)'),
                      value: isFinalProduct,
                      onChanged: (value) {
                        setStateDialog(() {
                          isFinalProduct = value ?? false;
                        });
                      },
                    ),
                    if (isFinalProduct) ...[
                      TextFormField(
                          controller: priceController,
                          decoration:
                              const InputDecoration(labelText: 'Precio (USD)')),
                      TextFormField(
                          controller: presentationController,
                          decoration:
                              const InputDecoration(labelText: 'Presentación')),
                      TextFormField(
                          controller: supplierController,
                          decoration: const InputDecoration(
                              labelText: 'Proveedor sugerido')),
                    ],
                  ],
                ),
              ),
              actions: [
                if (!isFinalProduct)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the edit dialog
                      _showAddNodeDialog(
                          parentId: node.id); // Open add dialog for child
                    },
                    child: const Text('Añadir Hijo'),
                  ),
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar')),
                TextButton(
                  onPressed: () async {
                    final confirmation = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Confirmar Eliminación'),
                        content: const Text(
                            '¿Estás seguro? Se eliminarán este elemento y todos sus descendientes.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancelar')),
                          TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Eliminar',
                                  style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirmation == true) {
                      try {
                        await catalogProvider.deleteNodeAndDescendants(node.id);
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text('Eliminado'),
                          backgroundColor: Colors.red,
                        ));
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  child: const Text('Eliminar',
                      style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    String fullName = nameController.text.trim();
                    final parentId = data['parentId'];
                    if (isFinalProduct) {
                      final parentRoute =
                          await catalogProvider.buildFullRouteForId(parentId);
                      fullName = parentRoute.isEmpty
                          ? fullName
                          : '$parentRoute > $fullName';
                    }
                    final updatedData = {
                      'name': fullName,
                      'isFinalProduct': isFinalProduct,
                      if (isFinalProduct)
                        'price': double.tryParse(priceController.text) ?? 0.0,
                      if (isFinalProduct)
                        'presentation': presentationController.text.trim(),
                      if (isFinalProduct)
                        'suggestedSupplier': supplierController.text.trim(),
                    };
                    await catalogProvider.updateNode(node.id, updatedData);

                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Actualizado'),
                      backgroundColor: Colors.blue,
                    ));
                  },
                  child: const Text('Actualizar'),
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
                        .collection(usersCollection)
                        .where('role', isEqualTo: 'cliente')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                            child: Text("Cargando clientes..."));
                      }
                      final clientsList = snapshot.data!.docs.map((doc) {
                        return {
                          'uid': doc.id,
                          'fullName': (doc.get('fullName') ?? '').toString(),
                        };
                      }).toList();

                      return DropdownButtonFormField<String>(
                        initialValue: _selectedClientId,
                        hint: const Text('Seleccionar Cliente'),
                        items: clientsList.map((client) {
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
            ExpansionTile(
              title: const Text(
                'Materiales',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddNodeDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir Categoría Raíz'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(
                  height: 300, // Adjust height as needed
                  child: FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection(catalogNodesCollection)
                        .where('parentId', isEqualTo: 'root')
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final rootNodes = snapshot.data!.docs;
                      return ListView.builder(
                        itemCount: rootNodes.length,
                        itemBuilder: (context, index) {
                          return _TreeNode(
                            nodeId: rootNodes[index].id,
                            level: 0,
                            onMaterialSelected: _showQuantityDialog,
                            onLongPress: _showEditDeleteDialog,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Materiales Seleccionados',
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

class _TreeNode extends StatefulWidget {
  final String nodeId;
  final int level;
  final Function(DocumentSnapshot) onMaterialSelected;
  final Function(DocumentSnapshot) onLongPress;

  const _TreeNode({
    required this.nodeId,
    required this.level,
    required this.onMaterialSelected,
    required this.onLongPress,
  });

  @override
  __TreeNodeState createState() => __TreeNodeState();
}

class __TreeNodeState extends State<_TreeNode> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(catalogNodesCollection)
          .doc(widget.nodeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        final node = snapshot.data!;
        final data = node.data() as Map<String, dynamic>;
        final bool isFinalProduct = data['isFinalProduct'] ?? false;
        String displayName = data['name'] ?? 'Sin Nombre';
        if (isFinalProduct) {
          final parts = displayName.split(' > ');
          if (parts.length > 1) {
            displayName = parts.last;
          }
        }

        Color folderColor = widget.level == 0 ? Colors.orange : Colors.blue;

        final tile = ListTile(
          contentPadding: EdgeInsets.only(left: widget.level * 20.0, right: 8),
          leading: isFinalProduct
              ? const Icon(Icons.inventory_2, color: Colors.green)
              : Icon(_isExpanded ? Icons.folder_open : Icons.folder,
                  color: folderColor),
          title: Text(displayName),
          subtitle: isFinalProduct
              ? Text(
                  '\$${(data['price'] as num? ?? 0).toStringAsFixed(2)} - ${data['presentation'] ?? ''}')
              : null,
          trailing: isFinalProduct
              ? null
              : Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
          onTap: () {
            if (isFinalProduct) {
              widget.onMaterialSelected(node);
            } else {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            }
          },
          onLongPress: () => widget.onLongPress(node),
        );

        if (isFinalProduct) {
          return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: tile);
        }

        return Column(
          children: [
            Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: tile),
            if (_isExpanded)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(catalogNodesCollection)
                    .where('parentId', isEqualTo: widget.nodeId)
                    .snapshots(),
                builder: (context, childSnapshot) {
                  if (!childSnapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.only(left: 40.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final children = childSnapshot.data!.docs;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: children.length,
                    itemBuilder: (context, index) {
                      return _TreeNode(
                        nodeId: children[index].id,
                        level: widget.level + 1,
                        onMaterialSelected: widget.onMaterialSelected,
                        onLongPress: widget.onLongPress,
                      );
                    },
                  );
                },
              ),
          ],
        );
      },
    );
  }
}