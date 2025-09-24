// catalog_node_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'final_materials_screen.dart';

class CatalogNodeScreen extends StatefulWidget {
  const CatalogNodeScreen({super.key});

  @override
  State<CatalogNodeScreen> createState() => _CatalogNodeScreenState();
}

class _CatalogNodeScreenState extends State<CatalogNodeScreen> {
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

  Future<String> _buildFullRouteForId(String? parentId) async {
    if (parentId == null || parentId == 'root') return '';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('catalog_nodes')
          .doc(parentId)
          .get();
      if (!doc.exists) return '';
      final data = doc.data()!;
      final parentName = data['name'];
      final grandParentId = data['parentId'];
      final parentPath = await _buildFullRouteForId(grandParentId);
      return parentPath.isEmpty ? parentName : '$parentPath > $parentName';
    } catch (e) {
      return 'Error cargando ruta';
    }
  }

  void _showAddNodeDialog({String parentId = 'root'}) {
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
                        final parentRoute = await _buildFullRouteForId(parentId);
                        fullName = parentRoute.isEmpty
                            ? fullName
                            : '$parentRoute > $fullName';
                      }
                      final data = {
                        'name': fullName,
                        'parentId': parentId,
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Elemento creado con éxito'),
                        backgroundColor: Colors.green,
                      ));
                      // Refresh the view by rebuilding the screen
                      setState(() {});
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
                      _showAddNodeDialog(parentId: node.id); // Open add dialog for child
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
                        await _deleteNodeAndDescendants(node.id);
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text('Eliminado'),
                          backgroundColor: Colors.red,
                        ));
                        setState((){});
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
                       final parentRoute = await _buildFullRouteForId(parentId);
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
                      'updatedAt': FieldValue.serverTimestamp(),
                      'updatedBy': _getCurrentUserId(),
                    };
                    await FirebaseFirestore.instance
                        .collection('catalog_nodes')
                        .doc(node.id)
                        .update(updatedData);

                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Actualizado'),
                      backgroundColor: Colors.blue,
                    ));
                     setState((){});
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

  Future<List<DocumentSnapshot>> _fetchRootNodes() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('catalog_nodes')
        .where('parentId', isEqualTo: 'root')
        .get();
    return snapshot.docs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Materiales'),
        backgroundColor: Colors.orange,
      ),
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: _fetchRootNodes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text('El catálogo está vacío. Añade un elemento.'));
          }
          final rootNodes = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: rootNodes.length,
            itemBuilder: (context, index) {
              return _TreeNode(
                nodeId: rootNodes[index].id,
                level: 0,
                onLongPress: _showEditDeleteDialog,
                onNodeUpdated: () => setState(() {}),
              );
            },
          );
        },
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.menu,
        activeIcon: Icons.close,
        backgroundColor: Colors.orange,
        children: [
          SpeedDialChild(
              child: const Icon(Icons.add),
              label: 'Añadir Elemento Raíz',
              onTap: () => _showAddNodeDialog()),
          SpeedDialChild(
            child: const Icon(Icons.inventory_2),
            label: 'Ver Materiales Finales',
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const FinalMaterialsScreen()));
            },
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _TreeNode extends StatefulWidget {
  final String nodeId;
  final int level;
  final Function(DocumentSnapshot) onLongPress;
  final VoidCallback onNodeUpdated;

  const _TreeNode({
    required this.nodeId,
    required this.level,
    required this.onLongPress,
    required this.onNodeUpdated,
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
          .collection('catalog_nodes')
          .doc(widget.nodeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink(); // Don't show anything while loading
        }
        final node = snapshot.data!;
        if (!node.exists) {
          return const SizedBox.shrink(); // Or some placeholder for a deleted node
        }
        final data = node.data() as Map<String, dynamic>;
        final bool isFinalProduct = data['isFinalProduct'] ?? false;
        String displayName = data['name'] ?? 'Sin Nombre';
        if(isFinalProduct) {
          final parts = displayName.split(' > ');
          if (parts.length > 1) {
            displayName = parts.last;
          }
        }


        final tile = ListTile(
          contentPadding: EdgeInsets.only(left: widget.level * 20.0, right: 8),
          leading: isFinalProduct
              ? const Icon(Icons.inventory_2, color: Colors.green)
              : Icon(_isExpanded ? Icons.folder_open : Icons.folder, color: Colors.blue),
          title: Text(displayName),
          subtitle: isFinalProduct
              ? Text(
                  '\$${(data['price'] as num? ?? 0).toStringAsFixed(2)} - ${data['presentation'] ?? ''}')
              : null,
          trailing: isFinalProduct ? null : Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
          onTap: () {
            if (!isFinalProduct) {
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
            child: tile
            );
        }

        return Column(
          children: [
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: tile
            ),
            if (_isExpanded)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('catalog_nodes')
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
                        onLongPress: widget.onLongPress,
                        onNodeUpdated: widget.onNodeUpdated,
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