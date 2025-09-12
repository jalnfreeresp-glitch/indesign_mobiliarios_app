import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MaterialsCatalogScreen extends StatefulWidget {
  const MaterialsCatalogScreen({super.key});

  @override
  State<MaterialsCatalogScreen> createState() => _MaterialsCatalogScreenState();
}

class _MaterialsCatalogScreenState extends State<MaterialsCatalogScreen> {
  final List<String> _categories = const [
    'Laminas',
    'Tornillos',
    'Herrajes',
    'Cantos',
    'Formicas',
    'Consumibles',
  ];

  // --- FUNCIÓN REESTRUCTURADA PARA SER MÁS SEGURA ---
  Future<void> _showAddMaterialDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final supplierController = TextEditingController();
    String? selectedCategory;

    // 1. Mostramos el diálogo y esperamos a que nos devuelva los datos.
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Añadir Nuevo Material'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration:
                        const InputDecoration(labelText: 'Nombre del Material'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: priceController,
                    decoration:
                        const InputDecoration(labelText: 'Precio (USD)'),
                    keyboardType: TextInputType.number,
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
                  TextFormField(
                    controller: supplierController,
                    decoration: const InputDecoration(labelText: 'Proveedor'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  // Cierra el diálogo y devuelve los datos del formulario
                  Navigator.of(dialogContext).pop({
                    'name': nameController.text,
                    'price': double.tryParse(priceController.text) ?? 0.0,
                    'category': selectedCategory,
                    'supplier': supplierController.text,
                  });
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    // 2. Si el diálogo devolvió datos, los guardamos en Firestore.
    // Esto sucede DESPUÉS de que el diálogo se ha cerrado, evitando el error.
    if (result != null) {
      try {
        await FirebaseFirestore.instance.collection('materials').add({
          'name': result['name'],
          'price': result['price'],
          'category': result['category'],
          'lastSupplier': result['supplier'],
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _categories.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Precios de Materiales'),
          backgroundColor: Colors.orange,
          bottom: TabBar(
            isScrollable: true,
            tabs: _categories
                .map((String category) => Tab(text: category))
                .toList(),
          ),
        ),
        body: TabBarView(
          children: _categories.map((String category) {
            return _buildMaterialList(category);
          }).toList(),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddMaterialDialog,
          tooltip: 'Añadir Material',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildMaterialList(String category) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('materials')
          .where('category', isEqualTo: category)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
              child: Text('No hay materiales en la categoría "$category".'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var material = snapshot.data!.docs[index];
            var data = material.data() as Map<String, dynamic>;
            var price = (data['price'] as num?) ?? 0.0;
            var supplier = data['lastSupplier'] as String?;

            return ListTile(
              title: Text(data['name'] ?? 'Sin Nombre'),
              subtitle: supplier != null && supplier.isNotEmpty
                  ? Text('Proveedor: $supplier')
                  : null,
              trailing: Text(
                '\$${price.toStringAsFixed(2)}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            );
          },
        );
      },
    );
  }
}
