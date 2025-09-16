// lib/screens/admin/final_materials_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FinalMaterialsScreen extends StatelessWidget {
  const FinalMaterialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todos los Materiales'),
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

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Sin nombre';
              final price = (data['price'] as num?)?.toDouble() ?? 0.0;
              final presentation = data['presentation'] ?? '';

              // Obtener la ruta completa (opcional, para contexto)
              // Puedes implementar una función recursiva si lo deseas

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shopping_cart, color: Colors.green),
                  ),
                  title: Text(name),
                  subtitle: Text(presentation),
                  trailing: Text(
                    '\$${price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green[800],
                    ),
                  ),
                  onTap: () {
                    // Opcional: Mostrar detalles o permitir edición
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Material: $name - \$${price.toStringAsFixed(2)}')),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
