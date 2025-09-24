import 'package:flutter/material.dart';

import 'package:indesign_mobiliarios_app/providers/user_provider.dart';
import 'package:indesign_mobiliarios_app/screens/admin/admin_dashboard_screen.dart';
import 'package:indesign_mobiliarios_app/screens/auth/login_screen.dart';
import 'package:indesign_mobiliarios_app/screens/buyer/buyer_dashboard_screen.dart';
import 'package:indesign_mobiliarios_app/screens/carpenter/carpenter_dashboard_screen.dart';
import 'package:indesign_mobiliarios_app/screens/client/client_dashboard_screen.dart';
import 'package:provider/provider.dart';

class RoleBasedNavigator extends StatelessWidget {
  const RoleBasedNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    if (user == null) {
      // This should technically not be reached if AuthGate is working correctly,
      // but as a fallback, we show a loading indicator or login screen.
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Navigate based on the role from the provider
    switch (user.role) {
      case 'administrador':
        return const AdminDashboardScreen();
      case 'cliente':
        return const ClientDashboardScreen();
      case 'carpintero':
        return const CarpenterDashboardScreen();
      case 'comprador':
        return const BuyerDashboardScreen();
      default:
        // Fallback to login screen if role is unknown or not set
        return const LoginScreen();
    }
  }
}