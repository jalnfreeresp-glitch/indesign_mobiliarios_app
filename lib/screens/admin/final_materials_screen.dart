import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // ✅ ¡ESTE ES EL IMPORT QUE FALTABA!

class FinalMaterialsScreen extends StatelessWidget {
  const FinalMaterialsScreen({super.key});

  // Formatear fecha
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Fecha no disponible';

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

  // Obtener ruta completa
  Future<String> _getFullPath(String? parentId) async {
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

      final parentPath = await _getFullPath(grandParentId);
      return parentPath.isEmpty ? parentName : '$parentPath > $parentName';
    } catch (e) {
      return 'Error cargando ruta';
    }
  }

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
              final presentation = data['presentation'] ?? 'Sin presentación';
              final parentId = data['parentId'];
              final createdAt = data['createdAt'];

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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Precio y presentación
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
                          Text(
                            '/ $presentation',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Ruta completa
                      FutureBuilder<String>(
                        future: _getFullPath(parentId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Text('Cargando ruta...',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12));
                          }
                          return Text(
                            '📍 ${snapshot.data ?? 'Ruta no disponible'}',
                            style: const TextStyle(
                                color: Colors.blueGrey, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      // Fecha de creación
                      if (createdAt != null)
                        Text(
                          '📅 Creado: ${_formatTimestamp(createdAt)}',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
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
}
