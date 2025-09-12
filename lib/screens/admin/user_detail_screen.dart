import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserDetailScreen extends StatefulWidget {
  final String userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  Future<void> _toggleUserStatus(bool currentStatus) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .update({'isActive': !currentStatus});
    setState(() {});
  }

  Future<void> _sendPasswordResetEmail(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Correo de restablecimiento enviado a $email'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al enviar correo: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _editField(String field, String currentValue) async {
    final controller = TextEditingController(text: currentValue);

    final String? newValue = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text('Editar ${field == 'fullName' ? 'Nombre' : 'Rol'}'),
            content: TextFormField(
              controller: controller,
              autofocus: true,
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(controller.text.trim());
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        });

    if (newValue != null && newValue.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({field: newValue});
      setState(() {});
    }
  }

  // --- FUNCIÓN PARA ELIMINAR USUARIO ---
  Future<void> _deleteUser() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text(
            '¿Estás seguro de que quieres eliminar este usuario permanentemente? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('deleteUser');
      await callable.call({'userIdToDelete': widget.userId});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Usuario eliminado con éxito'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.message ?? 'Error al eliminar'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Usuario'),
        backgroundColor: Colors.orange,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('Este usuario ya no existe.'));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;
          String userRole = userData['role'] ?? '';
          bool isActive = userData['isActive'] ?? false;
          String email = userData['email'] ?? '';
          String fullName = userData['fullName'] ?? '';

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              ListTile(
                title: Text(fullName,
                    style: Theme.of(context).textTheme.headlineSmall),
                subtitle: Text(email),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editField('fullName', fullName),
                ),
              ),
              ListTile(
                title: const Text('Rol'),
                subtitle: Text(userRole),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editField('role', userRole),
                ),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Cuenta Activa'),
                value: isActive,
                onChanged: (newValue) => _toggleUserStatus(isActive),
                activeTrackColor: Colors.green.shade200,
                activeThumbColor: Colors.green,
              ),
              ListTile(
                title: const Text('Restablecer Contraseña'),
                subtitle: const Text('Enviar correo al usuario'),
                trailing: IconButton(
                  icon: const Icon(Icons.email),
                  onPressed: () => _sendPasswordResetEmail(email),
                ),
              ),
              const Divider(height: 30),
              if (userRole == 'cliente' || userRole == 'carpintero')
                Text('Resumen de Proyectos',
                    style: Theme.of(context).textTheme.titleLarge),
              if (userRole == 'cliente') _buildProjectsList(isClient: true),
              if (userRole == 'carpintero') _buildProjectsList(isClient: false),

              const Divider(height: 30),
              // --- BOTÓN DE ELIMINAR AÑADIDO ---
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Eliminar Usuario'),
                  onPressed: _deleteUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProjectsList({required bool isClient}) {
    String fieldToFilter = isClient ? 'clientId' : 'carpinterId';
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .where(fieldToFilter, isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text('Cargando proyectos...');
        if (snapshot.data!.docs.isEmpty) {
          return const ListTile(title: Text('No tiene proyectos asociados.'));
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            return ListTile(
              title: Text(doc['projectName']),
              subtitle: Text("Estado: ${doc['status']}"),
            );
          }).toList(),
        );
      },
    );
  }
}
