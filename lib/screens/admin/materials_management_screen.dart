import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:indesign_mobiliarios_app/screens/admin/variants_management_screen.dart';

class MaterialsManagementScreen extends StatefulWidget {
  const MaterialsManagementScreen({super.key});

  @override
  State<MaterialsManagementScreen> createState() =>
      _MaterialsManagementScreenState();
}

class _MaterialsManagementScreenState extends State<MaterialsManagementScreen> {
  final List<String> _categories = [
    'Laminas',
    'Tornillos',
    'Herrajes',
    'Cantos',
    'Formicas',
    'Consumibles'
  ];

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir Nueva Categoría'),
        content: TextFormField(
          controller: nameController,
          decoration:
              const InputDecoration(labelText: 'Nombre de la Categoría'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('material_categories')
                    .add({'name': nameController.text});
                if (!context.mounted) return;
                Navigator.of(context).pop();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // --- FUNCIÓN PARA AÑADIR/EDITAR UN TIPO DE MATERIAL ---
  void _showMaterialTypeDialog(
      {DocumentSnapshot? materialType, String? categoryName}) {
    final bool isEditing = materialType != null;
    final formKey = GlobalKey<FormState>();
    final nameController =
        TextEditingController(text: isEditing ? materialType['name'] : '');
    String? selectedCategory = isEditing ? materialType['categoryName'] : null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing
              ? 'Editar Tipo de Material'
              : 'Añadir Nuevo Tipo de Material'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: 'Nombre del Tipo (ej. Melamina)'),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                if (isEditing)
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    hint: const Text('Seleccionar Categoría'),
                    items: _categories.map((String category) {
                      return DropdownMenuItem(
                          value: category, child: Text(category));
                    }).toList(),
                    onChanged: (value) {
                      selectedCategory = value;
                    },
                    validator: (v) => v == null ? 'Requerido' : null,
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
                  final data = {
                    'name': nameController.text,
                    'categoryName': isEditing ? selectedCategory : categoryName,
                  };
                  if (isEditing) {
                    await materialType.reference.update(data);
                  } else {
                    await FirebaseFirestore.instance
                        .collection('material_types')
                        .add(data);
                  }
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  // --- FUNCIÓN PARA ELIMINAR UN TIPO DE MATERIAL Y SUS VARIANTES ---
  Future<void> _deleteMaterialType(DocumentSnapshot materialType) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar "${materialType['name']}"'),
        content: const Text(
            '¿Estás seguro? Se eliminarán también todas sus variantes. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    WriteBatch batch = FirebaseFirestore.instance.batch();

    final variantsSnapshot =
        await materialType.reference.collection('variants').get();
    for (final doc in variantsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(materialType.reference);

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Materiales'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('material_categories')
            .snapshots(),
        builder: (context, categorySnapshot) {
          if (categorySnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!categorySnapshot.hasData ||
              categorySnapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay categorías creadas.'));
          }

          return ListView.builder(
            itemCount: categorySnapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var category = categorySnapshot.data!.docs[index];
              String categoryName = category['name'];

              return ExpansionTile(
                title: Text(categoryName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                // --- AQUI SE AÑADE EL COLOR AZUL ---
                backgroundColor: const Color.fromARGB(255, 11, 143, 252)
                    .withAlpha(30), // Fondo azul claro para la cinta
                collapsedBackgroundColor: const Color.fromARGB(255, 46, 1, 250)
                    .withAlpha(30), // Mismo color cuando está cerrada
                // --- FIN DEL CAMBIO DE COLOR ---
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('material_types')
                        .where('categoryName', isEqualTo: categoryName)
                        .snapshots(),
                    builder: (context, materialSnapshot) {
                      if (!materialSnapshot.hasData) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        children: [
                          ...materialSnapshot.data!.docs.map((materialType) {
                            return ListTile(
                              title: Text(materialType['name']),
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            VariantsManagementScreen(
                                                materialType: materialType)));
                              },
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showMaterialTypeDialog(
                                        materialType: materialType);
                                  } else if (value == 'delete') {
                                    _deleteMaterialType(materialType);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                      value: 'edit', child: Text('Editar')),
                                  const PopupMenuItem(
                                      value: 'delete', child: Text('Eliminar')),
                                ],
                              ),
                            );
                          }),
                          ListTile(
                            leading: const Icon(Icons.add, color: Colors.green),
                            title: const Text('Añadir nuevo material...',
                                style: TextStyle(color: Colors.green)),
                            onTap: () => _showMaterialTypeDialog(
                                categoryName:
                                    categoryName), // Llama sin parámetros para crear
                          )
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCategoryDialog,
        tooltip: 'Añadir Nueva Categoría',
        child: const Icon(Icons.create_new_folder_outlined),
      ),
    );
  }
}
