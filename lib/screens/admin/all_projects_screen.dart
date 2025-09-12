import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:indesign_mobiliarios_app/screens/admin/edit_project_screen.dart';
import 'package:indesign_mobiliarios_app/screens/admin/project_budget_screen.dart';
import 'package:indesign_mobiliarios_app/screens/projects/project_detail_screen.dart';

class AllProjectsScreen extends StatefulWidget {
  const AllProjectsScreen({super.key});

  @override
  State<AllProjectsScreen> createState() => _AllProjectsScreenState();
}

class _AllProjectsScreenState extends State<AllProjectsScreen> {
  Future<String> getCarpenterName(String? uid) async {
    if (uid == null || uid.isEmpty) return 'No asignado';
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return doc.data()?['fullName'] ?? 'Desconocido';
    } catch (e) {
      return 'Error';
    }
  }

  // --- FUNCIÓN CON DIÁLOGO DE CONFIRMACIÓN ---
  Future<void> _archiveProject(String projectId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archivar Proyecto'),
        content: const Text(
            '¿Estás seguro? El proyecto se ocultará de las listas activas.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Archivar')),
        ],
      ),
    );

    // Solo actualizamos si el usuario presionó "Archivar"
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .update({'isArchived': true});
    }
  }
  // ------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todos los Proyectos'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .where('isArchived', isEqualTo: false)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay proyectos activos.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var project = snapshot.data!.docs[index];
              var data = project.data() as Map<String, dynamic>;
              var projectName = data['projectName'] ?? 'Sin nombre';
              var clientName = data['clientName'] ?? 'Sin cliente';
              var status = data['status'] ?? 'Desconocido';
              var carpenterId = data['carpenterId'] as String?;

              return Card(
                child: ListTile(
                  title: Text(projectName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cliente: $clientName'),
                      FutureBuilder<String>(
                        future: getCarpenterName(carpenterId),
                        builder: (context, nameSnapshot) {
                          return Text(
                              'Carpintero: ${nameSnapshot.data ?? 'Cargando...'}');
                        },
                      ),
                      Text('Estado: $status',
                          style: const TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  ),
                  isThreeLine: true,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ProjectDetailScreen(
                              projectId: project.id,
                              userRole: 'administrador'))),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.calculate_outlined),
                        color: Colors.teal,
                        tooltip: 'Presupuesto',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProjectBudgetScreen(
                                projectId: project.id,
                                projectName: projectName,
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        color: Colors.blue,
                        tooltip: 'Editar',
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      EditProjectScreen(project: project)));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.archive_outlined),
                        color: Colors.red,
                        tooltip: 'Archivar',
                        onPressed: () => _archiveProject(project.id),
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
