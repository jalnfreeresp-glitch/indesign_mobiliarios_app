// lib/providers/project_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:indesign_mobiliarios_app/constants.dart';

class Project {
  final String id;
  final String projectName;
  final String clientName;
  final String status;
  final String? carpenterId;
  final bool isArchived;
  final double montoTotal;
  final double costoManoDeObra;

  Project({
    required this.id,
    required this.projectName,
    required this.clientName,
    required this.status,
    this.carpenterId,
    required this.isArchived,
    required this.montoTotal,
    required this.costoManoDeObra,
  });

  factory Project.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Project(
      id: doc.id,
      projectName: data['projectName'] ?? 'Sin nombre',
      clientName: data['clientName'] ?? 'Sin cliente',
      status: data['status'] ?? 'Desconocido',
      carpenterId: data['carpenterId'] as String?,
      isArchived: data['isArchived'] ?? false,
      montoTotal: (data['montoTotal'] as num?)?.toDouble() ?? 0.0,
      costoManoDeObra: (data['costoManoDeObra'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ProjectProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Project>> get projects {
    return _firestore
        .collection(projectsCollection)
        .where('isArchived', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Project.fromFirestore(doc)).toList());
  }

  Stream<List<Project>> get archivedProjects {
    return _firestore
        .collection(projectsCollection)
        .where('isArchived', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Project.fromFirestore(doc)).toList());
  }

  Future<void> archiveProject(String projectId) async {
    try {
      await _firestore
          .collection(projectsCollection)
          .doc(projectId)
          .update({'isArchived': true});
    } catch (e) {
      if (kDebugMode) {
        print('Error archiving project: $e');
      }
    }
  }

  Future<void> unarchiveProject(String projectId) async {
    try {
      await _firestore
          .collection(projectsCollection)
          .doc(projectId)
          .update({'isArchived': false});
    } catch (e) {
      if (kDebugMode) {
        print('Error unarchiving project: $e');
      }
    }
  }

  Future<void> updateProject(
      String projectId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(projectsCollection).doc(projectId).update(data);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating project: $e');
      }
    }
  }

  Future<String> getCarpenterName(String? uid) async {
    if (uid == null || uid.isEmpty) return 'No asignado';
    try {
      final doc = await _firestore.collection(usersCollection).doc(uid).get();
      return doc.data()?['fullName'] ?? 'Desconocido';
    } catch (e) {
      return 'Error';
    }
  }
}