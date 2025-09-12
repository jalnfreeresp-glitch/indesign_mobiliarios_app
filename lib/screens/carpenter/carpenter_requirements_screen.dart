import 'package:cloud_firestore/cloud_firestore.dart'; // <- CORREGIDO
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CarpenterRequirementsScreen extends StatefulWidget {
  const CarpenterRequirementsScreen({super.key});

  @override
  State<CarpenterRequirementsScreen> createState() =>
      _CarpenterRequirementsScreenState();
}

class _CarpenterRequirementsScreenState
    extends State<CarpenterRequirementsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  void _showAddRequirementDialog() {
    _descriptionController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nuevo Requerimiento'),
          content: Form(
            key: _formKey,
            child: TextFormField(
              controller: _descriptionController,
              decoration:
                  const InputDecoration(labelText: 'Describe lo que necesitas'),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'La descripción no puede estar vacía';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: _addRequirement,
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addRequirement() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final carpenterName = userDoc.data()?['fullName'] ?? 'Nombre desconocido';

      await FirebaseFirestore.instance.collection('requirements').add({
        'description': _descriptionController.text.trim(),
        'carpenterId': user.uid,
        'carpenterName': carpenterName,
        'status': 'pendiente',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al crear requerimiento: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final carpenterId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Requerimientos'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requirements')
            .where('carpenterId', isEqualTo: carpenterId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text('Error al cargar los requerimientos.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No has hecho requerimientos.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var req = snapshot.data!.docs[index];
              bool isCompleted = req['status'] == 'completado';
              return ListTile(
                title: Text(req['description']),
                trailing: Chip(
                  label: Text(req['status']),
                  backgroundColor:
                      isCompleted ? Colors.green[100] : Colors.orange[100],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRequirementDialog,
        backgroundColor: Colors.orange,
        tooltip: 'Nuevo Requerimiento',
        child: const Icon(Icons.add_comment),
      ),
    );
  }
}
