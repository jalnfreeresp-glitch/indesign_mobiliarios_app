import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:indesign_mobiliarios_app/services/auth_service.dart';
import 'package:indesign_mobiliarios_app/screens/carpenter/carpenter_balance_screen.dart';
import 'package:indesign_mobiliarios_app/screens/carpenter/carpenter_requirements_screen.dart';
import 'package:indesign_mobiliarios_app/screens/carpenter/carpenter_tasks_screen.dart';
import 'package:indesign_mobiliarios_app/screens/carpenter/my_projects_screen.dart';
import 'package:indesign_mobiliarios_app/screens/carpenter/my_workshop_materials_screen.dart';

class CarpenterDashboardScreen extends StatefulWidget {
  const CarpenterDashboardScreen({super.key});

  @override
  State<CarpenterDashboardScreen> createState() =>
      _CarpenterDashboardScreenState();
}

class _CarpenterDashboardScreenState extends State<CarpenterDashboardScreen> {
  Future<void> claimProject(String projectId) async {
    final String currentCarpenterId = FirebaseAuth.instance.currentUser!.uid;
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .update({
        'status': 'reclamado',
        'claimedByCarpenterId': currentCarpenterId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Has tomado el proyecto. Espera la confirmación del administrador.'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al tomar el proyecto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel de Carpintero'),
          backgroundColor: Colors.orange,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar Sesión',
              onPressed: () => AuthService().signOut(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Disponibles'),
              Tab(text: 'Reclamados'),
              Tab(text: 'En Proceso'),
            ],
          ),
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              heroTag: 'myProjects',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const MyProjectsScreen()),
                );
              },
              label: const Text('Mis Proyectos'),
              icon: const Icon(Icons.work_history),
              backgroundColor: Colors.blue,
            ),
            const SizedBox(height: 10),
            FloatingActionButton.extended(
              heroTag: 'myWorkshopMaterials',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const MyWorkshopMaterialsScreen()),
                );
              },
              label: const Text('Mis Materiales'),
              icon: const Icon(Icons.handyman),
              backgroundColor: Colors.brown,
            ),
            const SizedBox(height: 10),
            FloatingActionButton.extended(
              heroTag: 'myBalance',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CarpenterBalanceScreen()),
                );
              },
              label: const Text('Mi Balance'),
              icon: const Icon(Icons.account_balance_wallet),
              backgroundColor: Colors.green,
            ),
            const SizedBox(height: 10),
            FloatingActionButton.extended(
              heroTag: 'myTasks',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CarpenterTasksScreen()),
                );
              },
              label: const Text('Mis Tareas'),
              icon: const Icon(Icons.task_alt),
              backgroundColor: Colors.purple,
            ),
            const SizedBox(height: 10),
            FloatingActionButton.extended(
              heroTag: 'myRequirements',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          const CarpenterRequirementsScreen()),
                );
              },
              label: const Text('Requerimientos'),
              icon: const Icon(Icons.add_comment),
              backgroundColor: Colors.red,
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildProjectsList(
              statuses: ['presupuesto_aceptado'],
              emptyMessage: 'No hay proyectos disponibles en este momento.',
              isAvailable: true,
            ),
            _buildProjectsList(
              statuses: ['reclamado'],
              emptyMessage: 'No hay proyectos reclamados recientemente.',
              isAvailable: false,
            ),
            _buildProjectsList(
              statuses: [
                'asignado',
                'compra_de_materiales',
                'en_corte',
                'en_armado',
                'espera_instalacion',
                'instalando'
              ],
              emptyMessage: 'No hay proyectos en proceso.',
              isAvailable: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectsList(
      {required List<String> statuses,
      required String emptyMessage,
      required bool isAvailable}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .where('isArchived', isEqualTo: false) // No mostrar archivados
          .where('status', whereIn: statuses)
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
          return Center(
            child: Text(emptyMessage),
          );
        }
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var project = snapshot.data!.docs[index];
            var projectName = project['projectName'] ?? 'Sin nombre';
            var clientName = project['clientName'] ?? 'Cliente no especificado';
            var laborCost = (project['costoManoDeObra'] as num).toDouble();
            var status = project['status'] ?? '';

            return Card(
              margin: const EdgeInsets.all(10.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(projectName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Cliente: $clientName',
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                        'Pago por Mano de Obra: \$${laborCost.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 16,
                            color: Colors.green,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: isAvailable
                          ? ElevatedButton(
                              onPressed: () => claimProject(project.id),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white),
                              child: const Text('Tomar Proyecto'),
                            )
                          : Chip(label: Text(status.replaceAll('_', ' '))),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
