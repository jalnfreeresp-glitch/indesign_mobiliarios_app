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

  void _showAddMaterialTypeDialog(String categoryName) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Añadir Material a "$categoryName"'),
        content: TextFormField(
          controller: nameController,
          decoration: const InputDecoration(
              labelText: 'Nombre del Material (ej. Melamina)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('material_types')
                    .add({
                  'name': nameController.text,
                  'categoryName': categoryName,
                });
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
                              trailing:
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            VariantsManagementScreen(
                                                materialType: materialType)));
                              },
                            );
                          }),
                          ListTile(
                            leading: const Icon(Icons.add, color: Colors.green),
                            title: const Text('Añadir nuevo material...',
                                style: TextStyle(color: Colors.green)),
                            onTap: () =>
                                _showAddMaterialTypeDialog(categoryName),
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
