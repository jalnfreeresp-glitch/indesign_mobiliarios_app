import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:indesign_mobiliarios_app/firebase_messaging_service.dart';
import 'package:indesign_mobiliarios_app/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> signInUser() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (userDoc.exists) {
          final bool isActive = userDoc.data()?['isActive'] ?? false;
          if (isActive) {
            await FirebaseMessagingService().initialize();
          } else {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Esta cuenta ha sido desactivada.'),
                    backgroundColor: Colors.red),
              );
            }
          }
        } else {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Error de datos de usuario.'),
                  backgroundColor: Colors.red),
            );
          }
        }
      }
    } on FirebaseAuthException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Correo o contraseña incorrectos.'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService();
      final userCredential = await authService.signInWithGoogle();

      if (userCredential != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();
        if (userDoc.exists && (userDoc.data()?['isActive'] ?? false)) {
          await FirebaseMessagingService().initialize();
        } else {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Cuenta inactiva o no registrada.'),
                backgroundColor: Colors.red));
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message ?? 'Error de autenticación'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('In Design Mobiliarios')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                  labelText: 'Correo Electrónico',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Contraseña', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: signInUser,
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50)),
                        child: const Text('Iniciar Sesión',
                            style: TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(height: 20),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text("O")),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        // --- RUTA DE LA IMAGEN CORREGIDA ---
                        icon: Image.asset('assets/google_logo/google_logo.png',
                            height: 24.0),
                        label: const Text('Iniciar Sesión con Google'),
                        onPressed: _signInWithGoogle,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.black,
                          backgroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
