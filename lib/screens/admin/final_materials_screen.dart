import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
                if (!context.mounted) return;
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
    if (timestamp == null) {
      return 'Fecha no disponible'; // ✅ Corregido: sin 'const Text().data'
    }

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
