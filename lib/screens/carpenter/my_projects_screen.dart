import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:indesign_mobiliarios_app/screens/projects/project_detail_screen.dart';

class MyProjectsScreen extends StatelessWidget {
  const MyProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentCarpenterId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Proyectos Asignados'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // --- CONSULTA ACTUALIZADA Y SIMPLIFICADA ---
        stream: FirebaseFirestore.instance
            .collection('projects')
            .where('carpenterId', isEqualTo: currentCarpenterId)
            .where('isArchived', isEqualTo: false) // Solo proyectos activos
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text(
                    'Error: ${snapshot.error}. Revisa los índices de Firestore.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No tienes proyectos asignados actualmente.'),
            );
          }
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var project = snapshot.data!.docs[index];
              var data = project.data() as Map<String, dynamic>;
              var projectName = data['projectName'] ?? 'Sin nombre';
              var clientName = data['clientName'] ?? 'Sin cliente';
              var status =
                  data['status']?.replaceAll('_', ' ') ?? 'Desconocido';

              return Card(
                margin: const EdgeInsets.all(10.0),
                child: ListTile(
                  title: Text(projectName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Cliente: $clientName\nEstado: $status'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProjectDetailScreen(
                          projectId: project.id,
                          userRole: 'carpintero',
                        ),
                      ),
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
