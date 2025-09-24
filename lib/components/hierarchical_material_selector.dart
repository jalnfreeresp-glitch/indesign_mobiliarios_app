// lib/components/hierarchical_material_selector.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/catalog_provider.dart';

class HierarchicalMaterialSelector extends StatefulWidget {
  final String initialParentId;
  final void Function(Map<String, dynamic> result)? onSelected;
  final bool allowCreate;

  const HierarchicalMaterialSelector({
    super.key,
    this.initialParentId = 'root',
    this.onSelected,
    this.allowCreate = true,
  });

  @override
  State<HierarchicalMaterialSelector> createState() =>
      _HierarchicalMaterialSelectorState();
}

class _HierarchicalMaterialSelectorState
    extends State<HierarchicalMaterialSelector> {
  late String _currentParentId;
  String? _selectedNodeId; // ✅ Solo el ID del nodo seleccionado
  DocumentSnapshot<Object?>? _selectedNodeSnapshot;
  bool isFinalProduct = false;

  final TextEditingController _quantityController =
      TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _currentParentId = widget.initialParentId;
    _loadNodes();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _loadNodes() {
    final provider = context.read<CatalogProvider>();
    provider.loadNodes(_currentParentId);
  }

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

  void _showCreateDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    bool isFinal = false;

    showDialog(
      context: context,
      builder: (context) {
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
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (v) => (v?.isEmpty ?? true) ? 'Requerido' : null,
                  ),
                  CheckboxListTile(
                    title: const Text('Es un producto final (con precio)'),
                    value: isFinal,
                    onChanged: (v) => setState(() => isFinal = v ?? false),
                  ),
                  if (isFinal)
                    Column(
                      children: [
                        TextFormField(
                          decoration:
                              const InputDecoration(labelText: 'Precio'),
                          keyboardType: TextInputType.number,
                        ),
                        TextFormField(
                          decoration:
                              const InputDecoration(labelText: 'Presentación'),
                        ),
                        TextFormField(
                          decoration:
                              const InputDecoration(labelText: 'Proveedor'),
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
                  final provider = context.read<CatalogProvider>();
                  String fullName = nameController.text.trim();

                  if (isFinal) {
                    final fullRoute = await _buildFullRoute();
                    fullName = '$fullRoute > $fullName';
                  }

                  final newId = await provider.createNode(
                    name: fullName,
                    parentId: _currentParentId,
                    isFinalProduct: isFinal,
                    price: 0.0,
                    presentation: '',
                    supplier: '',
                  );

                  if (newId != null && mounted) {
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    setState(() {
                      _currentParentId = newId;
                      _selectedNodeId = null;
                      _selectedNodeSnapshot = null;
                      isFinalProduct = isFinal;
                    });
                    _loadNodes();
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CatalogProvider>();
    final nodes = provider.nodes;

    return AlertDialog(
      title: const Text('Seleccionar Material'),
      // ✅ Recomendación adicional: Limitar el ancho total del diálogo
      content: SizedBox(
        width: 400, // Ancho máximo razonable
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ruta completa
              if (_currentParentId != 'root')
                FutureBuilder<String>(
                  future: _buildFullRoute(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Text('Cargando ruta...');
                    }
                    return Text(
                      '📍 ${snapshot.data ?? 'Ubicación'}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    );
                  },
                ),

              const SizedBox(height: 16),

              // Lista de hijos
              if (nodes.isEmpty)
                const Text('No hay elementos aquí.')
              else
                Column(
                  children: [
                    // ✅ Contenedor con ancho fijo para el dropdown
                    SizedBox(
                      width: 350, // Menor que el ancho del diálogo
                      child: DropdownButtonFormField<String?>(
                        initialValue: _selectedNodeId,
                        hint: const Text('Selecciona un elemento'),
                        isExpanded:
                            true, // Permite que el menú use todo el ancho
                        items: nodes.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final isFinal = data['isFinalProduct'] ?? false;
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isFinal ? Icons.shopping_cart : Icons.folder,
                                  size: 18,
                                  color: isFinal ? Colors.green : Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                // ✅ Flexible para manejar nombres largos
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: Text(
                                    data['name'],
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (String? id) async {
                          if (id == null) return;
                          final doc = await FirebaseFirestore.instance
                              .collection('catalog_nodes')
                              .doc(id)
                              .get();
                          final data = doc.data() as Map<String, dynamic>;
                          if (data['isFinalProduct'] == true) {
                            setState(() {
                              _selectedNodeId = id;
                              _selectedNodeSnapshot = doc;
                              isFinalProduct = true;
                            });
                          } else {
                            setState(() {
                              _currentParentId = id;
                              _selectedNodeId = null;
                              _selectedNodeSnapshot = null;
                              isFinalProduct = false;
                            });
                            _loadNodes();
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Si es producto final → mostrar detalles + cantidad
                    if (isFinalProduct && _selectedNodeSnapshot != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            title: Text(
                                (_selectedNodeSnapshot!.data() as Map)['name']),
                            subtitle: Text(
                                '\$${((_selectedNodeSnapshot!.data() as Map)['price'] ?? 0).toStringAsFixed(2)}'),
                          ),
                          TextFormField(
                            controller: _quantityController,
                            decoration: const InputDecoration(
                              labelText: 'Cantidad',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),

                    if (widget.allowCreate)
                      ElevatedButton.icon(
                        onPressed: _showCreateDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Crear'),
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
          onPressed: () {
            if (isFinalProduct && _selectedNodeSnapshot != null) {
              final data =
                  _selectedNodeSnapshot!.data() as Map<String, dynamic>;
              final quantity = int.tryParse(_quantityController.text) ?? 1;
              widget.onSelected?.call({
                'id': _selectedNodeSnapshot!.id,
                'name': data['name'],
                'price': data['price'],
                'presentation': data['presentation'] ?? '',
                'isFinalProduct': true,
                'quantity': quantity,
              });
              Navigator.of(context).pop();
            }
          },
          child: const Text('Seleccionar'),
        ),
      ],
    );
  }
}
