// lib/providers/catalog_provider.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CatalogProvider with ChangeNotifier {
  List<DocumentSnapshot> _nodes = [];
  List<DocumentSnapshot> get nodes => _nodes;

  // Cargar nodos por parentId
  Future<void> loadNodes(String parentId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('catalog_nodes')
          .where('parentId', isEqualTo: parentId)
          .orderBy('name')
          .get();
      _nodes = snapshot.docs;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error cargando nodos: $e');
    }
  }

  // Construir ruta completa
  Future<String> buildFullRoute(String nodeId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('catalog_nodes')
          .doc(nodeId)
          .get();
      if (!doc.exists) return '';
      final data = doc.data()!;
      final parentName = data['name'];
      final grandParentId = data['parentId'];
      final parentPath = await buildFullRouteForId(grandParentId);
      return parentPath.isEmpty ? parentName : '$parentPath > $parentName';
    } catch (e) {
      return 'Error ruta';
    }
  }

  Future<String> buildFullRouteForId(String? parentId) async {
    if (parentId == null || parentId == 'root') return '';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('catalog_nodes')
          .doc(parentId)
          .get();
      if (!doc.exists) return '';
      final data = doc.data()!;
      final parentName = data['name'];
      final grandParentId = data['parentId'];
      final parentPath = await buildFullRouteForId(grandParentId);
      return parentPath.isEmpty ? parentName : '$parentPath > $parentName';
    } catch (e) {
      return 'Error ruta';
    }
  }

  // Crear nuevo nodo
  Future<String?> createNode({
    required String name,
    required String parentId,
    bool isFinalProduct = false,
    double price = 0.0,
    String presentation = '',
    String supplier = '',
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final data = {
        'name': name,
        'parentId': parentId,
        'isFinalProduct': isFinalProduct,
        if (isFinalProduct) 'price': price,
        if (isFinalProduct) 'presentation': presentation,
        if (isFinalProduct) 'suggestedSupplier': supplier,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user?.uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user?.uid,
      };

      final docRef = await FirebaseFirestore.instance
          .collection('catalog_nodes')
          .add(data);
      return docRef.id;
    } catch (e) {
      return null;
    }
  }

  // Eliminar nodo + descendientes
  Future<void> deleteNodeAndDescendants(String nodeId) async {
    final childrenSnapshot = await FirebaseFirestore.instance
        .collection('catalog_nodes')
        .where('parentId', isEqualTo: nodeId)
        .get();
    for (var child in childrenSnapshot.docs) {
      await deleteNodeAndDescendants(child.id);
    }
    await FirebaseFirestore.instance
        .collection('catalog_nodes')
        .doc(nodeId)
        .delete();
  }
}
