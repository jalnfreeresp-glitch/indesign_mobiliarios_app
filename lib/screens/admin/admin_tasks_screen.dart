import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminTasksScreen extends StatefulWidget {
  const AdminTasksScreen({super.key});

  @override
  State<AdminTasksScreen> createState() => _AdminTasksScreenState();
}

class _AdminTasksScreenState extends State<AdminTasksScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  Map<String, String>? _selectedCarpenter;

  void _showAddTaskDialog() {
    _titleController.clear();
    _selectedCarpenter = null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Asignar Nueva Tarea'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                      labelText: 'Descripción de la Tarea'),
                  validator: (value) =>
                      value!.isEmpty ? 'Ingrese una descripción' : null,
                ),
                const SizedBox(height: 20),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('role', isEqualTo: 'carpintero')
                      .snapshots(),
                  builder: (context, snapshot) {
                    // --- CORREGIDO: Se añadieron llaves {} ---
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }

                    var carpenters = snapshot.data!.docs.map((doc) {
                      return {
                        'uid': doc.id,
                        'fullName': doc['fullName'] as String
                      };
                    }).toList();

                    return DropdownButtonFormField<Map<String, String>>(
                      hint: const Text('Asignar a Carpintero'),
                      items: carpenters.map((carpenter) {
                        return DropdownMenuItem(
                          value: carpenter,
                          child: Text(carpenter['fullName']!),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedCarpenter = value),
                      validator: (value) =>
                          value == null ? 'Seleccione un carpintero' : null,
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar')),
            ElevatedButton(onPressed: _addTask, child: const Text('Asignar')),
          ],
        );
      },
    );
  }

  Future<void> _addTask() async {
    // --- CORREGIDO: Se añadieron llaves {} ---
    if (!_formKey.currentState!.validate() || _selectedCarpenter == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('tasks').add({
        'title': _titleController.text,
        'carpenterId': _selectedCarpenter!['uid'],
        'carpenterName': _selectedCarpenter!['fullName'],
        'status': 'pendiente',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // Manejar error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Tareas'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay tareas asignadas.'));
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
                subtitle: Text('Asignada a: ${task['carpenterName']}'),
                trailing: Chip(
                  label: Text(task['status']),
                  backgroundColor:
                      isCompleted ? Colors.green[100] : Colors.orange[100],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add_task),
      ),
    );
  }
}
