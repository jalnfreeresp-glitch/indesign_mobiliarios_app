import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';



// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  // await Firebase.initializeApp(); // Not needed if you don't use other services

  debugPrint("Handling a background message: ${message.messageId}");
}

class FirebaseMessagingService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize(String? uid) async {
    if (uid == null) return; // No user, no token to save

    // Set the background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 1. Pedir permiso al usuario
    await _firebaseMessaging.requestPermission();

    // 2. Obtener y guardar el token inicial
    _saveToken(uid);

    // 3. Escuchar actualizaciones del token
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      _saveToken(uid, token: newToken);
    });
  }

  Future<void> _saveToken(String uid, {String? token}) async {
    final fcmToken = token ?? await _firebaseMessaging.getToken();

    if (fcmToken == null) {
      debugPrint("No se pudo obtener el token FCM.");
      return;
    }

    debugPrint('Token FCM del Dispositivo: $fcmToken');

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'fcmToken': fcmToken},
        SetOptions(merge: true),
      );
      debugPrint("Token FCM guardado/actualizado para el usuario $uid");
    } catch (e) {
      debugPrint("Error al guardar token FCM: $e");
    }
  }
}
