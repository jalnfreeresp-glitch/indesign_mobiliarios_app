import 'package:cloud_firestore/cloud_firestore.dart'; // <- CORREGIDO
import 'package:flutter/material.dart';

class ArchivedProjectsScreen extends StatefulWidget {
  const ArchivedProjectsScreen({super.key});

  @override
  State<ArchivedProjectsScreen> createState() => _ArchivedProjectsScreenState();
}

class _ArchivedProjectsScreenState extends State<ArchivedProjectsScreen> {
  Future<void> _unarchiveProject(String projectId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar Proyecto'),
        content: const Text(
            '¿Estás seguro de que quieres restaurar este proyecto a la lista de activos?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Restaurar')),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .update({'isArchived': false});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proyectos Archivados'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .where('isArchived', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay proyectos archivados.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var project = snapshot.data!.docs[index];
              var data = project.data() as Map<String, dynamic>;
              var projectName = data['projectName'] ?? 'Sin nombre';
              var clientName = data['clientName'] ?? 'Sin cliente';

              return Card(
                color: Colors.grey[200],
                child: ListTile(
                  title: Text(projectName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Cliente: $clientName'),
                  trailing: ElevatedButton.icon(
                    icon: const Icon(Icons.unarchive, size: 18),
                    label: const Text('Restaurar'),
                    onPressed: () => _unarchiveProject(project.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                    ),
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
