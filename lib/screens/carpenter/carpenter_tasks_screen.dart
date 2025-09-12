import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CarpenterTasksScreen extends StatelessWidget {
  const CarpenterTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final carpenterId = FirebaseAuth.instance.currentUser!.uid;

    Future<void> completeTask(String taskId) async {
      await FirebaseFirestore.instance.collection('tasks').doc(taskId).update({
        'status': 'completada',
        'completedAt': FieldValue.serverTimestamp(),
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Tareas'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .where('carpenterId', isEqualTo: carpenterId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No tienes tareas asignadas.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var task = snapshot.data!.docs[index];
              bool isCompleted = task['status'] == 'completada';

              return ListTile(
                title: Text(
                  task['title'],
                  style: TextStyle(
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted ? Colors.grey : null),
                ),
                // Botón para marcar como completada
                trailing: isCompleted
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : IconButton(
                        icon: const Icon(Icons.check_circle_outline,
                            color: Colors.grey),
                        onPressed: () => completeTask(task.id),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
