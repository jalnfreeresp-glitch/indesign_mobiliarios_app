import 'package:flutter/material.dart';
import 'package:indesign_mobiliarios_app/providers/project_provider.dart';
import 'package:provider/provider.dart';

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
      if (!mounted) return;
      await Provider.of<ProjectProvider>(context, listen: false)
          .unarchiveProject(projectId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proyectos Archivados'),
        backgroundColor: Colors.orange,
      ),
      body: StreamProvider<List<Project>>.value(
        value: Provider.of<ProjectProvider>(context).archivedProjects,
        initialData: const [],
        child: Consumer<List<Project>>(
          builder: (context, projects, child) {
            if (projects.isEmpty) {
              return const Center(child: Text('No hay proyectos archivados.'));
            }

            return ListView.builder(
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final project = projects[index];

                return Card(
                  color: Colors.grey[200],
                  child: ListTile(
                    title: Text(project.projectName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Cliente: ${project.clientName}'),
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
      ),
    );
  }
}
