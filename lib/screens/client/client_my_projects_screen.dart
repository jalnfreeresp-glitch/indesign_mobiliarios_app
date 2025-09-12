import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:indesign_mobiliarios_app/screens/projects/project_detail_screen.dart';

class ClientMyProjectsScreen extends StatelessWidget {
  const ClientMyProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Proyectos'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .where('clientId', isEqualTo: currentUserId)
            .where('isArchived', isEqualTo: false) // <- Filtro añadido
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
              child: Text('No tienes proyectos asignados.'),
            );
          }
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var project = snapshot.data!.docs[index];
              var projectName = project['projectName'] ?? 'Sin nombre';
              var status = project['status']?.replaceAll('_', ' ') ?? 'N/A';

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text(projectName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Estado: $status'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProjectDetailScreen(
                          projectId: project.id,
                          userRole: 'cliente',
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
