import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MaterialsManagementScreen extends StatefulWidget {
  const MaterialsManagementScreen({super.key});

  @override
  State<MaterialsManagementScreen> createState() =>
      _MaterialsManagementScreenState();
}

class _MaterialsManagementScreenState extends State<MaterialsManagementScreen> {
  final List<String> _categories = const [
    'Laminas',
    'Tornillos',
    'Herrajes',
    'Cantos',
    'Formicas',
    'Consumibles',
  ];

  // Diálogo para añadir un nuevo TIPO de material (ej. "Melamina", "Tiradores")
  void _showAddMaterialTypeDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    String? selectedCategory;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Añadir Nuevo Tipo de Material'),
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
                DropdownButtonFormField<String>(
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
                  await FirebaseFirestore.instance
                      .collection('material_types')
                      .add({
                    'name': nameController.text,
                    'category': selectedCategory,
                  });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Materiales'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Leemos la nueva colección 'material_types'
        stream: FirebaseFirestore.instance
            .collection('material_types')
            .orderBy('category')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('No hay tipos de materiales en el catálogo.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var materialType = snapshot.data!.docs[index];
              var data = materialType.data() as Map<String, dynamic>;

              return ListTile(
                title: Text(data['name'] ?? 'Sin Nombre',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Categoría: ${data['category'] ?? 'N/A'}'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // En el siguiente paso, esto nos llevará a la pantalla
                  // para gestionar las variantes de este material.
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMaterialTypeDialog,
        tooltip: 'Añadir Tipo de Material',
        child: const Icon(Icons.add),
      ),
    );
  }
}
