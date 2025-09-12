import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminRequirementsScreen extends StatelessWidget {
  const AdminRequirementsScreen({super.key});

  Future<void> completeRequirement(String reqId) async {
    await FirebaseFirestore.instance
        .collection('requirements')
        .doc(reqId)
        .update({
      'status': 'completado',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Requerimientos de Carpinteros'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requirements')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay requerimientos.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var req = snapshot.data!.docs[index];
              bool isCompleted = req['status'] == 'completado';

              return ListTile(
                title: Text(req['description']),
                subtitle: Text('De: ${req['carpenterName']}'),
                trailing: isCompleted
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : ElevatedButton(
                        onPressed: () => completeRequirement(req.id),
                        child: const Text('Completar'),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
