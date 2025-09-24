// main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:indesign_mobiliarios_app/providers/user_provider.dart';
import 'package:provider/provider.dart';

import 'package:indesign_mobiliarios_app/auth_gate.dart';

import 'providers/catalog_provider.dart'; // Asegúrate de tener este provider

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ✅ Obligatorio para Firebase
  await Firebase.initializeApp(); // ✅ Inicializa Firebase

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InDesign Mobiliarios',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const AuthGate(), // O tu pantalla inicial
    );
  }
}
