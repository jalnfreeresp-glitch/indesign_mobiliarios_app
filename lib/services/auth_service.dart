import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // Proceso cancelado
      }

      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: googleUser.email)
          .limit(1)
          .get();

      if (usersQuery.docs.isEmpty) {
        await _googleSignIn.signOut();
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Este correo de Google no está registrado en la aplicación.',
        );
      }

      final userDoc = usersQuery.docs.first;
      final bool isActive = userDoc.data()['isActive'] ?? false;

      if (!isActive) {
        await _googleSignIn.signOut();
        throw FirebaseAuthException(
          code: 'user-disabled',
          message: 'Esta cuenta ha sido desactivada por un administrador.',
        );
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      return null;
    }
  }

  // --- FUNCIÓN PARA CERRAR SESIÓN ---
  Future<void> signOut() async {
    await _googleSignIn.signOut(); // Cierra la sesión de Google
    await _auth.signOut(); // Cierra la sesión de Firebase
  }
}
