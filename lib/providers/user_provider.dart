// lib/providers/user_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:indesign_mobiliarios_app/constants.dart';

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String role;
  final bool isActive;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      role: data['role'] ?? 'cliente', // Default to 'cliente'
      isActive: data['isActive'] ?? false,
    );
  }
}

class UserProvider with ChangeNotifier {
  UserModel? _user;
  UserModel? get user => _user;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<UserModel>> get users {
    return _firestore.collection(usersCollection).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList());
  }

  Future<void> fetchUser(String uid) async {
    try {
      final doc = await _firestore.collection(usersCollection).doc(uid).get();
      if (doc.exists) {
        _user = UserModel.fromFirestore(doc);
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching user: $e');
      }
    }
  }

  void clearUser() {
    _user = null;
    notifyListeners();
  }
}
