import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyWorkshopMaterialsScreen extends StatelessWidget {
  const MyWorkshopMaterialsScreen({super.key});

  // Función para obtener el nombre de un proyecto por su ID
  Future<String> _getProjectName(String? projectId) async {
    if (projectId == null || projectId.isEmpty) return 'N/A';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();
      return doc.exists
          ? doc.data()!['projectName'] ?? 'Sin Nombre'
          : 'No Encontrado';
    } catch (e) {
      return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtenemos el ID del carpintero que ha iniciado sesión
    final String currentCarpenterId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Materiales en Taller'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Buscamos en 'workshop_inventory' los documentos donde el 'carpenterId'
        // sea igual al del usuario actual.
        stream: FirebaseFirestore.instance
            .collection('workshop_inventory')
            .where('carpenterId', isEqualTo: currentCarpenterId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No tienes materiales asignados en el taller.'),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var item =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;
              var materialName = item['materialName'] ?? 'Sin nombre';
              var quantity = item['quantity'] ?? 0;
              var projectId = item['projectId'] as String?;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title: Text('$materialName (Cantidad: $quantity)',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: FutureBuilder<String>(
                    future: _getProjectName(projectId),
                    builder: (context, nameSnapshot) {
                      return Text(
                          'Para el Proyecto: ${nameSnapshot.data ?? 'Cargando...'}');
                    },
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
