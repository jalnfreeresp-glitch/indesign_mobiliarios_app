import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FirebaseMessagingService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // 1. Pedir permiso al usuario
    await _firebaseMessaging.requestPermission();

    // 2. Obtener el token único del dispositivo
    final fcmToken = await _firebaseMessaging.getToken();

    if (fcmToken == null) {
      debugPrint("No se pudo obtener el token FCM.");
      return;
    }

    debugPrint('Token FCM del Dispositivo: $fcmToken');

    // 3. Guardar el token en el documento del usuario en Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {'fcmToken': fcmToken},
          SetOptions(
              merge: true), // 'merge: true' para no sobreescribir otros datos
        );
        debugPrint("Token FCM guardado para el usuario ${user.uid}");
      } catch (e) {
        debugPrint("Error al guardar token FCM: $e");
      }
    }
  }
}
