import 'package:flutter/material.dart';
import 'package:indesign_mobiliarios_app/providers/user_provider.dart';
import 'package:indesign_mobiliarios_app/screens/admin/create_user_screen.dart';
import 'package:indesign_mobiliarios_app/screens/admin/user_detail_screen.dart';
import 'package:provider/provider.dart';

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Usuarios'),
        backgroundColor: Colors.orange,
      ),
      body: StreamProvider<List<UserModel>>.value(
        value: Provider.of<UserProvider>(context).users,
        initialData: const [],
        child: Consumer<List<UserModel>>(
          builder: (context, users, child) {
            if (users.isEmpty) {
              return const Center(child: Text('No hay usuarios registrados.'));
            }

            return _buildUserListView(users);
          },
        ),
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

  Widget _buildUserListView(List<UserModel> users) {
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];

        return ListTile(
          leading: Icon(
            Icons.circle,
            color: user.isActive ? Colors.green : Colors.red,
            size: 14,
          ),
          title: Text(user.fullName),
          subtitle: Text(user.role),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserDetailScreen(userId: user.uid),
              ),
            );
          },
        );
      },
    );
  }
}