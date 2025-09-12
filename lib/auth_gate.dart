import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:indesign_mobiliarios_app/role_based_navigator.dart';
import 'package:indesign_mobiliarios_app/screens/auth/login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // --- LÍNEA CORREGIDA ---
        // Simplemente mostramos el navegador; él se encargará del resto.
        return const RoleBasedNavigator();
      },
    );
  }
}
