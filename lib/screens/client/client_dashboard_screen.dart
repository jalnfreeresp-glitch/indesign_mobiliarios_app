import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:indesign_mobiliarios_app/screens/client/client_balance_screen.dart';
import 'package:indesign_mobiliarios_app/screens/client/client_my_projects_screen.dart';
import 'package:indesign_mobiliarios_app/services/auth_service.dart';

class ClientDashboardScreen extends StatelessWidget {
  const ClientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    Future<void> updateProjectStatus(String projectId, String newStatus) async {
      // Diálogo de confirmación
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(newStatus == 'presupuesto_aceptado'
              ? 'Aceptar Presupuesto'
              : 'Rechazar Presupuesto'),
          content:
              const Text('¿Estás seguro de que quieres realizar esta acción?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                  newStatus == 'presupuesto_aceptado' ? 'Aceptar' : 'Rechazar',
                  style: TextStyle(
                      color: newStatus == 'presupuesto_rechazado'
                          ? Colors.red
                          : null)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      try {
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .update({'status': newStatus});

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Presupuesto ${newStatus == 'presupuesto_aceptado' ? 'aceptado' : 'rechazado'} con éxito.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar el presupuesto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Cliente'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'clientMyProjects',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ClientMyProjectsScreen()),
              );
            },
            label: const Text('Mis Proyectos'),
            icon: const Icon(Icons.list_alt),
            backgroundColor: Colors.blue,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'clientMyBalance',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ClientBalanceScreen()),
              );
            },
            label: const Text('Mi Balance'),
            icon: const Icon(Icons.account_balance_wallet),
            backgroundColor: Colors.green,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Presupuestos Pendientes de Aprobación',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('projects')
                  .where('clientId', isEqualTo: currentUserId)
                  .where('status', isEqualTo: 'presupuesto_pendiente')
                  .where('isArchived', isEqualTo: false)
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
                    child: Text('No tienes presupuestos pendientes.'),
                  );
                }
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var project = snapshot.data!.docs[index];
                    var projectName = project['projectName'] ?? 'Sin nombre';
                    var totalAmount = (project['montoTotal'] as num).toDouble();
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10.0, vertical: 5.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              projectName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Monto Total: \$${totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 15),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => updateProjectStatus(
                                      project.id, 'presupuesto_rechazado'),
                                  child: const Text('Rechazar',
                                      style: TextStyle(color: Colors.red)),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: () => updateProjectStatus(
                                      project.id, 'presupuesto_aceptado'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Aceptar'),
                                ),
                              ],
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
        ],
      ),
    );
  }
}
