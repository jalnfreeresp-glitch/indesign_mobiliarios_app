import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AssignProjectsScreen extends StatelessWidget {
  const AssignProjectsScreen({super.key});

  Future<void> handleAssignment(BuildContext context, String projectId,
      String carpenterId, bool confirm) async {
    try {
      if (confirm) {
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .update({
          'status': 'asignado',
          'carpenterId': carpenterId,
        });

        // --- AÑADE LA COMPROBACIÓN AQUÍ ---
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Proyecto asignado con éxito.'),
              backgroundColor: Colors.green),
        );
      } else {
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .update({
          'status': 'presupuesto_aceptado',
          'claimedByCarpenterId': FieldValue.delete(),
        });

        // --- Y AQUÍ ---
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Asignación rechazada.'),
              backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      // --- Y FINALMENTE AQUÍ ---
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<String> getCarpenterName(String uid) async {
    if (uid.isEmpty) return 'Desconocido';
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return doc.data()?['fullName'] ?? 'Nombre no encontrado';
    } catch (e) {
      return 'Error al cargar nombre';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asignar Proyectos Reclamados'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .where('status', isEqualTo: 'reclamado')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No hay proyectos pendientes de asignación.'),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var project = snapshot.data!.docs[index];
              var projectName = project['projectName'] ?? 'Sin nombre';
              var carpenterId = project['claimedByCarpenterId'] ?? '';

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
                      const SizedBox(height: 10),
                      FutureBuilder<String>(
                        future: getCarpenterName(carpenterId),
                        builder: (context, nameSnapshot) {
                          if (nameSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Text('Reclamado por: Cargando...',
                                style: TextStyle(fontSize: 16));
                          }
                          return Text(
                              'Reclamado por: ${nameSnapshot.data ?? ''}',
                              style: const TextStyle(
                                  fontSize: 16, fontStyle: FontStyle.italic));
                        },
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => handleAssignment(
                                context, project.id, carpenterId, false),
                            child: const Text('Rechazar',
                                style: TextStyle(color: Colors.red)),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () => handleAssignment(
                                context, project.id, carpenterId, true),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white),
                            child: const Text('Confirmar'),
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
    );
  }
}
