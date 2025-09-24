import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'final_materials_screen.dart';

class MaterialSelectionScreenTemp extends StatefulWidget {
  final String? parentId;
  final String? parentName;

  const MaterialSelectionScreenTemp({
    super.key,
    this.parentId,
    this.parentName,
  });

  @override
  State<MaterialSelectionScreenTemp> createState() =>
      _MaterialSelectionScreenTempState();
}

class _MaterialSelectionScreenTempState extends State<MaterialSelectionScreenTemp> {
  late String _currentParentId;
  late String _currentTitle;

  @override
  void initState() {
    super.initState();
    _currentParentId = widget.parentId ?? 'root';
    _currentTitle = widget.parentName ?? 'Catálogo de Materiales';
  }

  String? _getCurrentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  Future<void> _deleteNodeAndDescendants(String nodeId) async {
    final childrenSnapshot = await FirebaseFirestore.instance
        .collection('catalog_nodes')
        .where('parentId', isEqualTo: nodeId)
        .get();
    for (var child in childrenSnapshot.docs) {
      await _deleteNodeAndDescendants(child.id);
    }
    await FirebaseFirestore.instance
        .collection('catalog_nodes')
        .doc(nodeId)
        .delete();
  }

  Future<String> _buildFullRoute() async {
    if (_currentParentId == 'root') return 'Catálogo Principal';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('catalog_nodes')
          .doc(_currentParentId)
          .get();
      if (!mounted) return '';
      if (!doc.exists) return '';
      final data = doc.data()!;
      final parentName = data['name'];
      final grandParentId = data['parentId'];
      final parentPath = await _buildFullRouteForId(grandParentId);
      if (!mounted) return '';
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
      if (!mounted) return '';
      if (!doc.exists) return '';
      final data = doc.data()!;
      final parentName = data['name'];
      final grandParentId = data['parentId'];
      final parentPath = await _buildFullRouteForId(grandParentId);
      if (!mounted) return '';
      return parentPath.isEmpty ? parentName : '$parentPath > $parentName';
    } catch (e) {
      return 'Error cargando ruta';
    }
  }

  void _showAddNodeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        final nameController = TextEditingController();
        final priceController = TextEditingController();
        final presentationController = TextEditingController();
        final supplierController = TextEditingController();
        bool isFinalProduct = false;

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
                        final fullRoute = await _buildFullRoute();
                        if (!context.mounted) return;
                        fullName = '$fullRoute > $fullName';
                      }
                      final data = {
                        'name': fullName,
                        'parentId': _currentParentId,
                        'isFinalProduct': isFinalProduct,
                        if (isFinalProduct)
                          'price': double.tryParse(priceController.text) ?? 0.0,
                        if (isFinalProduct)
                          'presentation': presentationController.text.trim(),
                        if (isFinalProduct)
                          'suggestedSupplier': supplierController.text.trim(),
                        'createdAt': FieldValue.serverTimestamp(),
                        'createdBy': _getCurrentUserId(),
                        'updatedAt': FieldValue.serverTimestamp(),
                        'updatedBy': _getCurrentUserId(),
                      };
                      await FirebaseFirestore.instance
                          .collection('catalog_nodes')
                          .add(data);

                      if (!context.mounted) return;
                      Navigator.of(context).pop();

                      if (!context.mounted) return;
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

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                        setState(() {
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
                        await _deleteNodeAndDescendants(node.id);
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        if (!context.mounted) return;
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
                    if (isFinalProduct) {
                      final fullRoute = await _buildFullRoute();
                      if (!context.mounted) return;
                      fullName = '$fullRoute > $fullName';
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
                      'updatedAt': FieldValue.serverTimestamp(),
                      'updatedBy': _getCurrentUserId(),
                    };
                    await FirebaseFirestore.instance
                        .collection('catalog_nodes')
                        .doc(node.id)
                        .update(updatedData);

                    if (!context.mounted) return;
                    Navigator.of(context).pop();

                    if (!context.mounted) return;
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

  Future<List<Map<String, dynamic>>> _fetchNodes() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('catalog_nodes')
        .where('parentId', isEqualTo: _currentParentId)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  void _showQuantityDialog(Map<String, dynamic> node) {
    final quantityController = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Seleccionar Cantidad'),
          content: TextFormField(
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
                final quantity = int.tryParse(quantityController.text) ?? 1;
                final result = {
                  'id': node['id'],
                  'name': node['name'],
                  'price': node['price'],
                  'presentation': node['presentation'] ?? '',
                  'isFinalProduct': true,
                  'quantity': quantity,
                };
                Navigator.of(context).pop(result);
              },
              child: const Text('Añadir'),
            ),
          ],
        );
      },
    ).then((selectedValue) {
      if (selectedValue != null) {
        if (!mounted) return;
        Navigator.of(context).pop(selectedValue);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchNodes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final nodes = snapshot.data ?? [];
        return Scaffold(
          appBar: AppBar(
            title: Text(_currentTitle),
            backgroundColor: Colors.deepPurple,
            leading: _currentParentId != 'root'
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop())
                : null,
          ),
          body: Column(
            children: [
              if (_currentParentId != 'root')
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: FutureBuilder<String>(
                    future: _buildFullRoute(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Text('Cargando ruta...');
                      }
                      return Text(
                        snapshot.data ?? '',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      );
                    },
                  ),
                ),
              Expanded(
                child: nodes.isEmpty
                    ? const Center(
                        child: Text('Esta categoría está vacía'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: nodes.length,
                        itemBuilder: (context, index) {
                          final node = nodes[index];
                          final bool isFinalProduct =
                              node['isFinalProduct'] ?? false;
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                if (isFinalProduct) {
                                  _showQuantityDialog(node);
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => MaterialSelectionScreenTemp(
                                            parentId: node['id'],
                                            parentName: node['name'])),
                                  ).then((selectedValue) {
                                    if (selectedValue != null) {
                                      if (!context.mounted) return;
                                      Navigator.of(context).pop(selectedValue);
                                    }
                                  });
                                }
                              },
                              onLongPress: () async {
                                final docSnap = await FirebaseFirestore.instance
                                    .collection('catalog_nodes')
                                    .doc(node['id'])
                                    .get();
                                if (!context.mounted) return;
                                _showEditDeleteDialog(docSnap);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    if (isFinalProduct)
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                            color: Colors.teal[100],
                                            shape: BoxShape.circle),
                                        child: const Icon(
                                            Icons.add_shopping_cart,
                                            color: Colors.teal, size: 20),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                            color: Colors.purple[100],
                                            shape: BoxShape.circle),
                                        child: const Icon(
                                            Icons.create_new_folder_outlined,
                                            color: Colors.purple, size: 20),
                                      ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            node['name'] ?? 'Sin Nombre',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: isFinalProduct
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                              color: isFinalProduct
                                                  ? Colors.teal[800]
                                                  : Colors.purple[800],
                                            ),
                                          ),
                                          if (isFinalProduct)
                                            Text(
                                              '\$${(node['price'] as num? ?? 0).toStringAsFixed(2)} - ${node['presentation'] ?? ''}',
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (!isFinalProduct)
                                      const Icon(Icons.arrow_forward_ios,
                                          size: 16, color: Colors.grey)
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: SpeedDial(
            icon: Icons.menu,
            activeIcon: Icons.close,
            backgroundColor: Colors.deepPurple,
            children: [
              SpeedDialChild(
                  child: const Icon(Icons.add),
                  label: 'Añadir Elemento',
                  onTap: _showAddNodeDialog),
              SpeedDialChild(
                child: const Icon(Icons.inventory_2),
                label: 'Ver Materiales',
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FinalMaterialsScreen()));
                },
              ),
            ],
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }
}
