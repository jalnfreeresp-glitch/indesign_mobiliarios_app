import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:indesign_mobiliarios_app/screens/admin/create_user_screen.dart';
import 'package:indesign_mobiliarios_app/screens/admin/user_detail_screen.dart';

// Definimos constantes para las colecciones y campos
class FirestoreConstants {
  static const String usersCollection = 'users';
  static const String fullNameField = 'fullName';
  static const String roleField = 'role';
  static const String isActiveField = 'isActive';
}

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Usuarios'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(FirestoreConstants.usersCollection)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Nuevo: Manejo de errores
          if (snapshot.hasError) {
            return const Center(
                child: Text('Ocurrió un error al cargar los usuarios.'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay usuarios registrados.'));
          }

          // Separamos el ListView en un método para mejor legibilidad
          return _buildUserListView(snapshot.data!.docs);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateUserScreen()),
          );
        },
        backgroundColor: Colors.orange,
        tooltip: 'Añadir Usuario',
        child: const Icon(Icons.add),
      ),
    );
  }

  // Nuevo método para construir la lista de usuarios
  Widget _buildUserListView(List<DocumentSnapshot> userDocs) {
    return ListView.builder(
      itemCount: userDocs.length,
      itemBuilder: (context, index) {
        final user = userDocs[index];
        final userData =
            user.data() as Map<String, dynamic>?; // Hacemos el mapa nullable

        // Manejamos el caso en que userData sea nulo
        if (userData == null) {
          return const SizedBox.shrink(); // Widget vacío si los datos son nulos
        }

        final isActive =
            userData[FirestoreConstants.isActiveField] as bool? ?? false;
        final fullName =
            userData[FirestoreConstants.fullNameField] as String? ??
                'Sin Nombre';
        final role =
            userData[FirestoreConstants.roleField] as String? ?? 'Sin Rol';

        return ListTile(
          leading: Icon(
            Icons.circle,
            color: isActive ? Colors.green : Colors.red,
            size: 14,
          ),
          title: Text(fullName),
          subtitle: Text(role),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserDetailScreen(userId: user.id),
              ),
            );
          },
        );
      },
    );
  }
}
