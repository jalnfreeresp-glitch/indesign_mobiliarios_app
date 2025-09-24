import 'package:flutter/material.dart';
import 'package:indesign_mobiliarios_app/providers/project_provider.dart';
import 'package:indesign_mobiliarios_app/screens/admin/edit_project_screen.dart';
import 'package:indesign_mobiliarios_app/screens/admin/project_budget_screen.dart';
import 'package:indesign_mobiliarios_app/screens/projects/project_detail_screen.dart';
import 'package:provider/provider.dart';

class AllProjectsScreen extends StatefulWidget {
  const AllProjectsScreen({super.key});

  @override
  State<AllProjectsScreen> createState() => _AllProjectsScreenState();
}

class _AllProjectsScreenState extends State<AllProjectsScreen> {
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

    if (confirm == true) {
      if (!mounted) return;
      await Provider.of<ProjectProvider>(context, listen: false)
          .archiveProject(projectId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todos los Proyectos'),
        backgroundColor: Colors.orange,
      ),
      body: StreamProvider<List<Project>>.value(
        value: Provider.of<ProjectProvider>(context).projects,
        initialData: const [],
        child: Consumer<List<Project>>(
          builder: (context, projects, child) {
            if (projects.isEmpty) {
              return const Center(child: Text('No hay proyectos activos.'));
            }

            return ListView.builder(
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final project = projects[index];

                return Card(
                  child: ListTile(
                    title: Text(project.projectName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cliente: ${project.clientName}'),
                        FutureBuilder<String>(
                          future: Provider.of<ProjectProvider>(context)
                              .getCarpenterName(project.carpenterId),
                          builder: (context, nameSnapshot) {
                            return Text(
                                'Carpintero: ${nameSnapshot.data ?? 'Cargando...'}');
                          },
                        ),
                        Text('Estado: ${project.status}',
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
                                  projectName: project.projectName,
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
      ),
    );
  }
}
