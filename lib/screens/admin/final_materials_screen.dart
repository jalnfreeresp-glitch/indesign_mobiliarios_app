// final_materials_screen.dart
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
  String? _selectedCategory;

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

  void _onCategoryChanged(String? category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  Color _getCategoryColor(String categoryName) {
    final int hashCode = categoryName.hashCode;
    final double hue = (hashCode & 0xFF) * 360 / 255;
    const double saturation = 0.7;
    const double lightness = 0.4;
    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }

  void _showMaterialDetailDialog(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final fullName = data['name'] is String ? data['name'] : 'Sin nombre';
    final price = (data['price'] as num?)?.toDouble() ?? 0.0;
    final presentation = data['presentation'] ?? '';

    final parts = fullName.split(' > ');
    final displayName = parts.isNotEmpty ? parts.last : fullName;
    final displayPath = parts.length > 1
        ? parts.sublist(0, parts.length - 1).join(' - ')
        : 'Sin categoría';

    final categoryName = parts.isNotEmpty ? parts[0] : 'Sin categoría';
    final categoryColor = _getCategoryColor(categoryName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(displayName),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📂 $displayPath',
                  style: TextStyle(fontSize: 14, color: categoryColor),
                ),
                const SizedBox(height: 8),
                if (presentation.isNotEmpty)
                  Text(
                    '📝 $presentation',
                    style: const TextStyle(fontSize: 16),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '💰 \$${price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (data['suggestedSupplier'] != null &&
                    data['suggestedSupplier'] != '')
                  Text(
                    '🏪 Proveedor: ${data['suggestedSupplier']}',
                    style: const TextStyle(fontSize: 14),
                  ),
                const SizedBox(height: 16),
                const Text(
                  '📝 Historial de Cambios:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (data['updatedBy'] != null)
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(data['updatedBy'].toString())
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Text('Cargando usuario...');
                      }
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final userData =
                            snapshot.data!.data() as Map<String, dynamic>;
                        final fullName = userData['fullName'] is String
                            ? userData['fullName']
                            : 'Usuario desconocido';
                        return Text('👤 Última modificación por: $fullName');
                      }
                      return const Text(
                          '👤 Última modificación por: Usuario no encontrado');
                    },
                  ),
                const SizedBox(height: 4),
                if (data['updatedAt'] != null)
                  Text(
                    '📅 Fecha: ${_formatTimestamp(data['updatedAt'])}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (!context.mounted) return;
                _showEditDialog(context, doc);
              },
              child: const Text('Editar'),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final fullName = data['name'] is String ? data['name'] : '';
    final parts = fullName.split(' > ');
    final displayName = parts.isNotEmpty ? parts.last : fullName;

    final nameController = TextEditingController(text: displayName);
    final priceController =
        TextEditingController(text: data['price']?.toString() ?? '');
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
                  'name': fullName,
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

  IconData _getPriceIcon(double price) {
    if (price <= 50) {
      return Icons.attach_money;
    } else if (price <= 200) {
      return Icons.monetization_on;
    } else if (price <= 500) {
      return Icons.money;
    } else {
      return Icons.account_balance_wallet;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Materiales Finales'),
        backgroundColor: Colors.orange,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('catalog_nodes')
                  .where('parentId', isEqualTo: 'root')
                  .where('isFinalProduct', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox();
                }
                final categoryNodes = snapshot.data!.docs;
                final categories = <String>{'Todas'};
                for (var doc in categoryNodes) {
                  final data = doc.data() as Map<String, dynamic>;
                  final categoryName = data['name'] as String?;
                  if (categoryName != null) {
                    categories.add(categoryName);
                  }
                }
                final availableCategories = categories.toList()..sort();

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Buscar material...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 12.0),
                          ),
                          style: const TextStyle(fontSize: 14),
                          onChanged: _onSearchChanged,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: const Text('Categoría'),
                            value: _selectedCategory,
                            items: availableCategories.map((String category) {
                              return DropdownMenuItem<String>(
                                value: category == 'Todas' ? null : category,
                                child: Text(
                                  category,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              _onCategoryChanged(newValue);
                            },
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                            iconSize: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
        ),
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

          List<DocumentSnapshot> filteredMaterials = allMaterials;

          if (_selectedCategory != null) {
            filteredMaterials = filteredMaterials.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final fullName = data['name'] is String ? data['name'] : '';
              final parts = fullName.split(' > ');
              return parts.isNotEmpty && parts[0] == _selectedCategory;
            }).toList();
          }

          if (_searchQuery.isNotEmpty) {
            filteredMaterials = filteredMaterials.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final fullName = data['name'] is String ? data['name'] : '';
              return fullName.toLowerCase().contains(_searchQuery);
            }).toList();
          }

          return ListView.builder(
            itemCount: filteredMaterials.length,
            itemBuilder: (context, index) {
              final doc = filteredMaterials[index];
              final data = doc.data() as Map<String, dynamic>;
              final fullName =
                  data['name'] is String ? data['name'] : 'Sin nombre';
              final price = (data['price'] as num?)?.toDouble() ?? 0.0;
              final presentation = data['presentation'] ?? '';

              final parts = fullName.split(' > ');
              final displayPath = parts.join(' - ');
              final categoryName =
                  parts.isNotEmpty ? parts[0] : 'Sin categoría';

              final categoryColor = _getCategoryColor(categoryName);
              final priceIcon = _getPriceIcon(price);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: categoryColor.withAlpha(51),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      priceIcon,
                      color: categoryColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    displayPath,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (parts.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            parts.last,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        presentation,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: categoryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '\$${price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onSelected: (String result) {
                          switch (result) {
                            case 'view':
                              _showMaterialDetailDialog(context, doc);
                              break;
                            case 'edit':
                              if (!context.mounted) return;
                              _showEditDialog(context, doc);
                              break;
                            case 'delete':
                              if (!context.mounted) return;
                              _showDeleteDialog(context, doc);
                              break;
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'view',
                            child: Text('Ver detalles'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('Editar'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Eliminar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => _showMaterialDetailDialog(context, doc),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) {
      return 'Fecha no disponible';
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
