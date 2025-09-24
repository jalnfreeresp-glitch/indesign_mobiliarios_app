// main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/catalog_provider.dart'; // Asegúrate de tener este provider
import 'screens/admin/admin_dashboard_screen.dart'; // Tu pantalla principal

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ✅ Obligatorio para Firebase
  await Firebase.initializeApp(); // ✅ Inicializa Firebase

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
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
      home: const AdminDashboardScreen(), // O tu pantalla inicial
    );
  }
}
