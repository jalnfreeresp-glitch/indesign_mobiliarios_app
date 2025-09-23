// lib/components/hierarchical_material_selector.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Importar Firestore
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
  DocumentSnapshot<Object?>? _selectedNodeSnapshot; // ✅ Tipo correcto
  bool isFinalProduct = false;

  final TextEditingController _quantityController =
      TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _currentParentId = widget.initialParentId;
    _loadNodes();
  }

  void _loadNodes() {
    final provider = context.read<CatalogProvider>();
    provider.loadNodes(_currentParentId);
  }

  void _showCreateDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    bool isFinal = false; // ✅ Definido aquí

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Añadir Nuevo Elemento'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) => (v?.isEmpty ?? true) ? 'Requerido' : null,
                ),
                CheckboxListTile(
                  title: const Text('Es producto final'),
                  value: isFinal,
                  onChanged: (v) => setState(() => isFinal = v ?? false),
                ),
                if (isFinal)
                  Column(
                    children: [
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Precio'),
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
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final provider = context.read<CatalogProvider>();
                  String fullName = nameController.text.trim();

                  if (isFinal) {
                    final fullRoute =
                        await provider.buildFullRoute(_currentParentId);
                    fullName = '$fullRoute > $fullName';
                  }

                  final newId = await provider.createNode(
                    name: fullName,
                    parentId: _currentParentId,
                    isFinalProduct: isFinal, // ✅ Parámetro corregido
                    price: 0.0,
                    presentation: '',
                    supplier: '',
                  );

                  if (newId != null && mounted) {
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    setState(() {
                      _currentParentId = newId;
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
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ruta completa
              if (_currentParentId != 'root')
                FutureBuilder<String>(
                  future: provider.buildFullRoute(_currentParentId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Text('Cargando ruta...');
                    }
                    return Text('📍 ${snapshot.data ?? 'Ubicación'}',
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey));
                  },
                ),

              const SizedBox(height: 16),

              // Lista de hijos
              if (nodes.isEmpty)
                const Text('No hay elementos aquí.')
              else
                Column(
                  children: [
                    DropdownButtonFormField<DocumentSnapshot<Object?>>(
                      hint: const Text('Selecciona un elemento'),
                      items: nodes.map((doc) {
                        final data = doc.data()
                            as Map<String, dynamic>; // ✅ Cast explícito
                        final isFinal = data['isFinalProduct'] ?? false;
                        return DropdownMenuItem(
                          value: doc,
                          child: Row(
                            children: [
                              Icon(isFinal ? Icons.shopping_cart : Icons.folder,
                                  size: 18,
                                  color: isFinal ? Colors.green : Colors.blue),
                              const SizedBox(width: 8),
                              Text(data['name']),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (doc) {
                        final data = doc!.data() as Map<String, dynamic>;
                        if (data['isFinalProduct'] == true) {
                          setState(() {
                            _selectedNodeSnapshot = doc;
                            isFinalProduct = true;
                          });
                        } else {
                          setState(() {
                            _currentParentId = doc.id;
                            _selectedNodeSnapshot = null;
                            isFinalProduct = false;
                          });
                          _loadNodes();
                        }
                      },
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
                            decoration:
                                const InputDecoration(labelText: 'Cantidad'),
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
            child: const Text('Cancelar')),
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
