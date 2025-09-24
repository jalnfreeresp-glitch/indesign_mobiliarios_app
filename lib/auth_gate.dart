import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:indesign_mobiliarios_app/firebase_messaging_service.dart';
import 'package:indesign_mobiliarios_app/providers/user_provider.dart';
import 'package:indesign_mobiliarios_app/role_based_navigator.dart';
import 'package:indesign_mobiliarios_app/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // User is logged out, clear user data from provider after the build is complete
          SchedulerBinding.instance.addPostFrameCallback((_) {
            Provider.of<UserProvider>(context, listen: false).clearUser();
          });
          return const LoginScreen();
        }

        // User is logged in, fetch user data and then navigate
        return FutureBuilder(
          future: _initServices(context, snapshot.data!.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            // After user data is fetched, navigate to the role-based screen
            return const RoleBasedNavigator();
          },
        );
      },
    );
  }

  Future<void> _initServices(BuildContext context, String uid) async {
    // Fetch user data
    await Provider.of<UserProvider>(context, listen: false).fetchUser(uid);
    // Initialize messaging service
    await FirebaseMessagingService().initialize(uid);
  }
}