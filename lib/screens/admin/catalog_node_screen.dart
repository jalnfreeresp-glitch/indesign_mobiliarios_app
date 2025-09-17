import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

class CatalogNodeScreen extends StatefulWidget {
  final String? parentId;
  final String? parentName;

  const CatalogNodeScreen({
    super.key,
    this.parentId,
    this.parentName,
  });

  @override
  State<CatalogNodeScreen> createState() => _CatalogNodeScreenState();
}

class _CatalogNodeScreenState extends State<CatalogNodeScreen> {
  late String _currentParentId;
  late String _currentTitle;

  @override
  void initState() {
    super.initState();
    _currentParentId = widget.parentId ?? 'root';
    _currentTitle = widget.parentName ?? 'Catálogo Principal';
  }

  // Obtener UID del usuario actual
  String? _getCurrentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  // --- Eliminación en cascada ---
  Future<void> _deleteNodeAndDescendants(String nodeId) async {
    // Primero, obtener todos los descendientes directos
    final childrenSnapshot = await FirebaseFirestore.instance
        .collection('catalog_nodes')
        .where('parentId', isEqualTo: nodeId)
        .get();

    // Recursivamente eliminar cada hijo y sus descendientes
    for (var child in childrenSnapshot.docs) {
      await _deleteNodeAndDescendants(child.id);
    }

    // Finalmente, eliminar el nodo actual
    await FirebaseFirestore.instance
        .collection('catalog_nodes')
        .doc(nodeId)
        .delete();
  }

  // --- Construir ruta de navegación ---
  Future<List<Map<String, String>>> _buildBreadcrumbs() async {
    final breadcrumbs = <Map<String, String>>[];
    var currentId = _currentParentId;
    var currentName = _currentTitle;

    // Si estamos en la raíz, no hay ruta que construir
    if (currentId == 'root') {
      return breadcrumbs;
    }

    // Construir ruta hacia atrás hasta llegar a 'root'
    while (currentId != 'root') {
      breadcrumbs.insert(0, {'id': currentId, 'name': currentName});

      // Obtener el padre del nodo actual
      final nodeSnapshot = await FirebaseFirestore.instance
          .collection('catalog_nodes')
          .doc(currentId)
          .get();

      if (!nodeSnapshot.exists) break;

      final data = nodeSnapshot.data()!;
      currentId = data['parentId'];

      // Si el padre es 'root', terminamos
      if (currentId == 'root') {
        break;
      }

      // Obtener el nombre del padre
      final parentSnapshot = await FirebaseFirestore.instance
          .collection('catalog_nodes')
          .doc(currentId)
          .get();

      if (!parentSnapshot.exists) break;
      currentName = parentSnapshot.data()!['name'];
    }

    return breadcrumbs;
  }

  // --- Construir ruta completa para nombre de producto final ---
  Future<String> _buildFullRoute() async {
    if (_currentParentId == 'root') return 'Catálogo Principal';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('catalog_nodes')
          .doc(_currentParentId)
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

  // Recursiva para obtener ruta desde un ID
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

  void _showAddNodeDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final presentationController = TextEditingController();
    final supplierController = TextEditingController(); // ✅ Nuevo controlador
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
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      if (isFinalProduct) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: priceController,
                          decoration: InputDecoration(
                            labelText: 'Precio (USD)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      String fullName = nameController.text.trim();

                      // ✅ Si es producto final, construir nombre con ruta completa
                      if (isFinalProduct) {
                        final fullRoute = await _buildFullRoute();
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
                          'suggestedSupplier':
                              supplierController.text.trim(), // ✅ Nuevo campo
                        'createdAt': FieldValue.serverTimestamp(),
                        'createdBy': _getCurrentUserId(), // ✅ Historial
                        'updatedAt':
                            FieldValue.serverTimestamp(), // ✅ Historial
                        'updatedBy': _getCurrentUserId(), // ✅ Historial
                      };
                      await FirebaseFirestore.instance
                          .collection('catalog_nodes')
                          .add(data);

                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Elemento creado con éxito'),
                          backgroundColor: Colors.green,
                        ),
                      );
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
    final nameController = TextEditingController(text: data['name']);
    final priceController =
        TextEditingController(text: data['price']?.toString() ?? '');
    final presentationController =
        TextEditingController(text: data['presentation'] ?? '');
    final supplierController = TextEditingController(
        text: data['suggestedSupplier'] ?? ''); // ✅ Nuevo controlador
    bool isFinalProduct = data['isFinalProduct'] ?? false;

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
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),
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
                            const InputDecoration(labelText: 'Precio (USD)'),
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      ),
                      TextFormField(
                        controller: presentationController,
                        decoration:
                            const InputDecoration(labelText: 'Presentación'),
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      ),
                      TextFormField(
                        controller: supplierController,
                        decoration: const InputDecoration(
                            labelText: 'Proveedor sugerido'),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () async {
                    final confirmation = await showDialog<bool>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Confirmar Eliminación'),
                          content: const Text(
                              '¿Estás seguro? Se eliminarán este elemento y todos sus descendientes.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Eliminar',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirmation == true) {
                      try {
                        await _deleteNodeAndDescendants(node.id);
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Elemento y descendientes eliminados'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Eliminar',
                      style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final updatedData = {
                      'name': nameController.text.trim(),
                      'isFinalProduct': isFinalProduct,
                      if (isFinalProduct)
                        'price': double.tryParse(priceController.text) ?? 0.0,
                      if (isFinalProduct)
                        'presentation': presentationController.text.trim(),
                      if (isFinalProduct)
                        'suggestedSupplier': supplierController.text
                            .trim(), // ✅ Actualizar proveedor
                      'updatedAt': FieldValue
                          .serverTimestamp(), // ✅ Actualizar historial
                      'updatedBy':
                          _getCurrentUserId(), // ✅ Actualizar historial
                    };
                    await FirebaseFirestore.instance
                        .collection('catalog_nodes')
                        .doc(node.id)
                        .update(updatedData);
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Elemento actualizado'),
                        backgroundColor: Colors.blue,
                      ),
                    );
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
        title: FutureBuilder<List<Map<String, String>>>(
          future: _buildBreadcrumbs(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text('Cargando...');
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Text(_currentTitle);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ruta:',
                    style: TextStyle(fontSize: 12, color: Colors.white70)),
                Text(
                  [
                    'Catálogo Principal',
                    ...snapshot.data!.map((e) => e['name']!),
                    _currentTitle,
                  ].join(' > '),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          },
        ),
        backgroundColor: Colors.orange,
        leading: _currentParentId != 'root'
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('catalog_nodes')
            .where('parentId', isEqualTo: _currentParentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Esta categoría está vacía',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('Añade tu primer elemento usando el botón "+"'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final node = snapshot.data!.docs[index];
              final data = node.data() as Map<String, dynamic>;
              final bool isFinalProduct = data['isFinalProduct'] ?? false;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (!isFinalProduct) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CatalogNodeScreen(
                            parentId: node.id,
                            parentName: data['name'],
                          ),
                        ),
                      );
                    }
                  },
                  onLongPress: () => _showEditDeleteDialog(node),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        if (isFinalProduct)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shopping_cart,
                                color: Colors.green, size: 20),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.folder,
                                color: Colors.blue, size: 20),
                          ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['name'] ?? 'Sin Nombre',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isFinalProduct
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color:
                                      isFinalProduct ? Colors.green[800] : null,
                                ),
                              ),
                              if (isFinalProduct)
                                Text(
                                  '\$${(data['price'] as num? ?? 0).toStringAsFixed(2)} - ${data['presentation'] ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!isFinalProduct)
                          const Icon(Icons.arrow_forward_ios,
                              size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      // ✅ Speed Dial con dos acciones
      floatingActionButton: SpeedDial(
        icon: Icons.menu,
        activeIcon: Icons.close,
        backgroundColor: Colors.orange,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.add),
            label: 'Añadir Elemento',
            onTap: _showAddNodeDialog,
          ),
          SpeedDialChild(
            child: const Icon(Icons.inventory_2),
            label: 'Ver Materiales',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FinalMaterialsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// --- Pantalla de Materiales Finales ---
class FinalMaterialsScreen extends StatefulWidget {
  const FinalMaterialsScreen({super.key});

  @override
  State<FinalMaterialsScreen> createState() => _FinalMaterialsScreenState();
}

class _FinalMaterialsScreenState extends State<FinalMaterialsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  void _showEditDialog(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final nameController = TextEditingController(text: data['name']);
    final priceController =
        TextEditingController(text: data['price'].toString());
    final presentationController =
        TextEditingController(text: data['presentation']);
    final supplierController =
        TextEditingController(text: data['suggestedSupplier'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Material'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextFormField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Precio (USD)'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: presentationController,
                decoration: const InputDecoration(labelText: 'Presentación'),
              ),
              TextFormField(
                controller: supplierController,
                decoration:
                    const InputDecoration(labelText: 'Proveedor sugerido'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updatedData = {
                  'name': nameController.text.trim(),
                  'price': double.tryParse(priceController.text) ?? 0.0,
                  'presentation': presentationController.text.trim(),
                  'suggestedSupplier': supplierController.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  'updatedBy': FirebaseAuth.instance.currentUser?.uid,
                };
                await FirebaseFirestore.instance
                    .collection('catalog_nodes')
                    .doc(doc.id)
                    .update(updatedData);
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Material actualizado')),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: const Text(
              '¿Estás seguro de que quieres eliminar este material?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('catalog_nodes')
                    .doc(doc.id)
                    .delete();
                if (!context.mounted) return;
                Navigator.of(context).pop();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Material eliminado')),
                );
              },
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Buscar material...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: _onSearchChanged,
        ),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('catalog_nodes')
            .where('isFinalProduct', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No hay materiales creados aún.'),
            );
          }

          final allMaterials = snapshot.data!.docs;
          final filteredMaterials = _searchQuery.isEmpty
              ? allMaterials
              : allMaterials.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] as String?)?.toLowerCase() ?? '';
                  final presentation =
                      (data['presentation'] as String?)?.toLowerCase() ?? '';
                  return name.contains(_searchQuery) ||
                      presentation.contains(_searchQuery);
                }).toList();

          return ListView.builder(
            itemCount: filteredMaterials.length,
            itemBuilder: (context, index) {
              final doc = filteredMaterials[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Sin nombre';
              final price = (data['price'] as num?)?.toDouble() ?? 0.0;
              final presentation = data['presentation'] ?? '';
              final supplier = data['suggestedSupplier'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre del material
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Presentación
                      Text(
                        presentation,
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      // Precio
                      Row(
                        children: [
                          Text(
                            '\$${price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.shopping_cart, color: Colors.green[700]),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Proveedor sugerido
                      if (supplier.isNotEmpty)
                        Text(
                          '🏪 Proveedor: $supplier',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.blueGrey),
                        ),
                      const SizedBox(height: 8),
                      // Historial de cambios
                      if (data['updatedBy'] != null ||
                          data['updatedAt'] != null) ...[
                        const Divider(),
                        const Text(
                          '📝 Última modificación:',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        if (data['updatedBy'] != null)
                          Text(
                            'Por: ${data['updatedBy']}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        if (data['updatedAt'] != null)
                          Text(
                            'Fecha: ${_formatTimestamp(data['updatedAt'])}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                      ],
                      const SizedBox(height: 12),
                      // Botones de acción
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showEditDialog(context, doc),
                            tooltip: 'Editar',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _showDeleteDialog(context, doc),
                            tooltip: 'Eliminar',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Formatear fecha
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Fecha no disponible';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return 'Formato de fecha inválido';
    }

    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
