import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:indesign_mobiliarios_app/screens/admin/admin_dashboard_screen.dart';
import 'package:indesign_mobiliarios_app/screens/auth/login_screen.dart';
import 'package:indesign_mobiliarios_app/screens/client/client_dashboard_screen.dart';
import 'package:indesign_mobiliarios_app/screens/carpenter/carpenter_dashboard_screen.dart';
// --- 1. IMPORTAMOS LA PANTALLA REAL DEL COMPRADOR ---
import 'package:indesign_mobiliarios_app/screens/buyer/buyer_dashboard_screen.dart';

// --- 2. YA NO NECESITAMOS NINGÚN MARCADOR DE POSICIÓN AQUÍ ---

class RoleBasedNavigator extends StatelessWidget {
  const RoleBasedNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const LoginScreen();
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const LoginScreen();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String userRole = data['role'] ?? 'cliente';

        switch (userRole) {
          case 'administrador':
            return const AdminDashboardScreen();
          case 'cliente':
            return const ClientDashboardScreen();
          case 'carpintero':
            return const CarpenterDashboardScreen();
          case 'comprador':
            // Esta línea ahora usa la pantalla real que importamos
            return const BuyerDashboardScreen();
          default:
            return const LoginScreen();
        }
      },
    );
  }
}
