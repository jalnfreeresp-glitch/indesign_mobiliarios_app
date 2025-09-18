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
  String? _selectedCategory; // Para el filtro por categoría
  List<String> _availableCategories = []; // Lista de categorías encontradas

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Cargar las categorías disponibles desde los datos
  Future<void> _loadCategories() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('catalog_nodes')
        .where('isFinalProduct', isEqualTo: true)
        .get();

    final categories = <String>{'Todas'}; // Incluir opción "Todas"
    for (var doc in snapshot.docs) {
      final data = doc.data();
      // Corregido: Evitar cast innecesario
      final fullName = data['name'] is String ? data['name'] : '';
      // Extraer la primera categoría de la ruta
      final parts = fullName.split(' > ');
      if (parts.isNotEmpty) {
        categories.add(parts[0]); // La primera parte es la categoría principal
      }
    }
    // Asegurarse de que el widget aún esté montado antes de setState
    if (mounted) {
      setState(() {
        _availableCategories = categories.toList()..sort();
      });
    }
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

  // Función para obtener un color distintivo basado en el nombre de la categoría
  Color _getCategoryColor(String categoryName) {
    // Generar un hashCode del nombre de la categoría para obtener un color consistente
    final int hashCode = categoryName.hashCode;
    // Usar el hashCode para generar valores de color HSL
    // Hue: basado en el hashCode para variedad
    final double hue = (hashCode & 0xFF) * 360 / 255;
    // Saturation y Lightness fijos para coherencia
    const double saturation = 0.7;
    const double lightness = 0.4;

    // Convertir HSL a Color
    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }

  void _showMaterialDetailDialog(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // Corregido: Evitar cast innecesario
    final fullName = data['name'] is String ? data['name'] : 'Sin nombre';
    final price = (data['price'] as num?)?.toDouble() ?? 0.0;
    final presentation = data['presentation'] ?? '';
    // supplier ya no se usa aquí, por lo que se elimina

    // Extraer el nombre final del producto
    final parts = fullName.split(' > ');
    final displayName = parts.isNotEmpty ? parts.last : fullName;
    // Mostrar la ruta completa como categoría
    final displayPath = parts.length > 1
        ? parts.sublist(0, parts.length - 1).join(' - ') // Usar guion aquí
        : 'Sin categoría';

    // Obtener color de categoría para usarlo en el diálogo también
    final categoryName = parts.isNotEmpty ? parts[0] : 'Sin categoría';
    final categoryColor = _getCategoryColor(categoryName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(displayName), // Solo el nombre final
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Categoría/Ruta con color de categoría
                Text(
                  '📂 $displayPath', // Mostrar ruta con guiones
                  style: TextStyle(fontSize: 14, color: categoryColor),
                ),
                const SizedBox(height: 8),
                // Presentación
                if (presentation.isNotEmpty)
                  Text(
                    '📝 $presentation',
                    style: const TextStyle(fontSize: 16),
                  ),
                const SizedBox(height: 8),

                // Precio con indicador de color de CATEGORÍA
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: categoryColor, // Usar color de categoría
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

                // Proveedor sugerido
                if (data['suggestedSupplier'] != null &&
                    data['suggestedSupplier'] != '')
                  Text(
                    '🏪 Proveedor: ${data['suggestedSupplier']}',
                    style: const TextStyle(fontSize: 14),
                  ),
                const SizedBox(height: 16),

                // Historial de cambios
                const Text(
                  '📝 Historial de Cambios:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Mostrar nombre del usuario en lugar del ID
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
                        // Corregido: Evitar cast innecesario
                        final fullName = userData['fullName'] is String
                            ? userData['fullName']
                            : 'Usuario desconocido';
                        return Text('👤 Última modificación por: $fullName');
                      }

                      // Fallback si no se encuentra el usuario
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
                Navigator.of(context).pop(); // Cerrar detalles
                // Verificar si el contexto aún es válido antes de usarlo
                if (!context.mounted) return;
                _showEditDialog(context, doc); // Abrir edición
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
    // Corregido: Evitar cast innecesario
    final fullName = data['name'] is String ? data['name'] : '';
    // Extraer el nombre final del producto para editar
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
                  'name': fullName, // Mantener el nombre completo con ruta
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
                // Verificar si el contexto aún es válido después de la operación async
                if (!context.mounted) return;
                Navigator.of(context).pop(); // Cerrar editar
                // Verificar nuevamente antes de usar ScaffoldMessenger
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
                // Verificar si el contexto aún es válido después de la operación async
                if (!context.mounted) return;
                Navigator.of(context).pop();
                // Verificar nuevamente antes de usar ScaffoldMessenger
                if (!context.mounted) return;
                // Recargar categorías después de eliminar
                await _loadCategories();
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

  // Función para obtener el ícono según el precio (mantenida como estaba)
  IconData _getPriceIcon(double price) {
    if (price <= 50) {
      return Icons.attach_money; // $
    } else if (price <= 200) {
      return Icons.monetization_on; // $$
    } else if (price <= 500) {
      return Icons.money; // $$$
    } else {
      return Icons.account_balance_wallet; // $$$$
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
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                // Campo de búsqueda
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Buscar material...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                    ),
                    style: const TextStyle(fontSize: 14),
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: 10),
                // Dropdown de categorías
                Expanded(
                  flex: 1,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text('Categoría'),
                      value: _selectedCategory,
                      items: _availableCategories.map((String category) {
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
          ),
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

          // Filtrar por categoría y búsqueda
          List<DocumentSnapshot> filteredMaterials = allMaterials;

          // 1. Filtrar por categoría seleccionada
          if (_selectedCategory != null) {
            filteredMaterials = filteredMaterials.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              // Corregido: Evitar cast innecesario
              final fullName = data['name'] is String ? data['name'] : '';
              final parts = fullName.split(' > ');
              return parts.isNotEmpty && parts[0] == _selectedCategory;
            }).toList();
          }

          // 2. Filtrar por búsqueda
          if (_searchQuery.isNotEmpty) {
            filteredMaterials = filteredMaterials.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              // Corregido: Evitar cast innecesario
              final fullName = data['name'] is String ? data['name'] : '';
              // Para búsqueda, buscamos en el nombre completo
              return fullName.toLowerCase().contains(_searchQuery);
            }).toList();
          }

          return ListView.builder(
            itemCount: filteredMaterials.length,
            itemBuilder: (context, index) {
              final doc = filteredMaterials[index];
              final data = doc.data() as Map<String, dynamic>;
              // Corregido: Evitar cast innecesario
              final fullName =
                  data['name'] is String ? data['name'] : 'Sin nombre';
              final price = (data['price'] as num?)?.toDouble() ?? 0.0;
              final presentation = data['presentation'] ?? '';
              // supplier ya no se usa en este itemBuilder, por lo que se elimina

              // Extraer información para mostrar
              final parts = fullName.split(' > ');
              // Cambio solicitado: Mostrar la ruta COMPLETA como nombre principal
              final displayPath =
                  parts.join(' - '); // Ruta completa con guiones
              final categoryName =
                  parts.isNotEmpty ? parts[0] : 'Sin categoría';

              // Obtener color e ícono según la CATEGORÍA
              // Cambio solicitado: Color basado en la primera parte (categoría)
              final categoryColor = _getCategoryColor(categoryName);
              final priceIcon = _getPriceIcon(price); // Icono basado en precio

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(
                          alpha: 0.2), // Color de categoría con transparencia
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      priceIcon, // Icono basado en precio
                      color: categoryColor, // Color basado en categoría
                    ),
                  ),
                  // Cambio solicitado: Mostrar la ruta completa como título
                  title: Text(
                    displayPath, // Ruta completa con guiones
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: categoryColor, // Color basado en categoría
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mostrar el nombre final del producto en gris
                      if (parts.length > 1)
                        Text(
                          parts.last, // Solo el nombre final del producto
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      Text(
                        presentation,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Indicador de precio con color de CATEGORÍA
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: categoryColor, // Color basado en categoría
                          borderRadius: BorderRadius.circular(12),
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
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (String result) {
                      switch (result) {
                        case 'view':
                          _showMaterialDetailDialog(context, doc);
                          break;
                        case 'edit':
                          // Verificar si el contexto aún es válido antes de usarlo
                          if (!context.mounted) return;
                          _showEditDialog(context, doc);
                          break;
                        case 'delete':
                          // Verificar si el contexto aún es válido antes de usarlo
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
                  onTap: () => _showMaterialDetailDialog(context, doc),
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
