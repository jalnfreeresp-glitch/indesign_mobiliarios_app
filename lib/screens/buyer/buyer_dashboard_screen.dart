import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:indesign_mobiliarios_app/screens/buyer/purchase_history_screen.dart';
import 'package:indesign_mobiliarios_app/screens/buyer/record_expense_screen.dart';
import 'package:indesign_mobiliarios_app/services/auth_service.dart';

class BuyerDashboardScreen extends StatefulWidget {
  const BuyerDashboardScreen({super.key});

  @override
  State<BuyerDashboardScreen> createState() => _BuyerDashboardScreenState();
}

class _BuyerDashboardScreenState extends State<BuyerDashboardScreen> {
  Future<void> _markMaterialAsPurchased(
      String shoppingItemId, String materialName, String projectId) async {
    final costController = TextEditingController();
    final quantityController = TextEditingController();
    final supplierController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Compra'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Cantidad Comprada')),
              TextField(
                  controller: costController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Costo Total de la Compra')),
              TextField(
                  controller: supplierController,
                  decoration:
                      const InputDecoration(labelText: 'Proveedor (Opcional)')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (quantityController.text.isNotEmpty &&
                  costController.text.isNotEmpty) {
                Navigator.of(context).pop({
                  'quantity': double.tryParse(quantityController.text) ?? 0.0,
                  'cost': double.tryParse(costController.text) ?? 0.0,
                  'supplier': supplierController.text,
                });
              }
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );

    if (result == null) return;
    final actualCost = result['cost'] as double;
    final quantityPurchased = result['quantity'] as double;
    final supplier = result['supplier'] as String;

    if (actualCost <= 0 || quantityPurchased <= 0) return;

    try {
      // 1. Marcar como comprado en la lista de compras
      await FirebaseFirestore.instance
          .collection('shopping_list')
          .doc(shoppingItemId)
          .update({
        'isPurchased': true,
        'purchasedAt': FieldValue.serverTimestamp()
      });

      // 2. Crear la transacción de gasto
      await FirebaseFirestore.instance.collection('transactions').add({
        'projectId': projectId,
        'amount': actualCost,
        'type': 'gasto_materiales',
        'description': 'Compra: $materialName',
        'supplier': supplier,
        'date': FieldValue.serverTimestamp(),
      });

      // 3. Actualizar o crear en el Catálogo de Materiales
      final materialCatalogRef =
          FirebaseFirestore.instance.collection('materials').doc(materialName);

      await materialCatalogRef.set({
        'name': materialName,
        'price': actualCost / quantityPurchased,
        'lastSupplier': supplier,
        'lastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 4. Actualizar el inventario de almacén
      final inventoryRef =
          FirebaseFirestore.instance.collection('inventory').doc(materialName);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(inventoryRef);
        if (!snapshot.exists) {
          transaction.set(inventoryRef, {'stockAlmacen': quantityPurchased});
        } else {
          final newStock =
              (snapshot.data()!['stockAlmacen'] as num) + quantityPurchased;
          transaction.update(inventoryRef, {'stockAlmacen': newStock});
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Compra registrada, catálogo e inventario actualizados'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al registrar compra: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Lista de Compras'),
          backgroundColor: Colors.orange,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar Sesión',
              onPressed: () => AuthService().signOut(),
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('shopping_list')
              .orderBy(
                  'isPurchased') // Ordena para mostrar los pendientes primero
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                  child: Text('No hay materiales en la lista de compras.'));
            }

            return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var item = snapshot.data!.docs[index];
                var data = item.data() as Map<String, dynamic>;
                bool isPurchased = data['isPurchased'] ?? false;

                return CheckboxListTile(
                  title: Text(
                    data['materialName'] ?? 'Sin nombre',
                    style: TextStyle(
                        decoration:
                            isPurchased ? TextDecoration.lineThrough : null,
                        color: isPurchased ? Colors.grey : null),
                  ),
                  subtitle: Text(
                      'Proyecto: ${data['projectName'] ?? ''} | Cantidad: ${data['quantity'] ?? ''}'),
                  value: isPurchased,
                  onChanged: isPurchased
                      ? null
                      : (bool? value) {
                          if (value == true) {
                            _markMaterialAsPurchased(item.id,
                                data['materialName'], data['projectId']);
                          }
                        },
                );
              },
            );
          },
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              heroTag: 'purchaseHistory',
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const PurchaseHistoryScreen()));
              },
              label: const Text('Historial'),
              icon: const Icon(Icons.history),
              backgroundColor: Colors.blue,
            ),
            const SizedBox(height: 10),
            FloatingActionButton.extended(
              heroTag: 'otherExpense',
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const RecordExpenseScreen()));
              },
              label: const Text('Registrar Gasto Vario'),
              icon: const Icon(Icons.receipt_long),
            ),
          ],
        ));
  }
}
