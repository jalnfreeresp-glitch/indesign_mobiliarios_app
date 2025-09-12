import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PurchaseHistoryScreen extends StatelessWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Compras'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shopping_list')
            .where('isPurchased', isEqualTo: true) // Solo los comprados
            .orderBy('purchasedAt',
                descending: true) // Ordenados por fecha de compra
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('No hay compras registradas en el historial.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var item = snapshot.data!.docs[index];
              var data = item.data() as Map<String, dynamic>;
              var date = (data['purchasedAt'] as Timestamp?)?.toDate();
              var formattedDate = date != null
                  ? DateFormat('dd/MM/yyyy').format(date)
                  : 'Sin fecha';

              return ListTile(
                leading: const Icon(Icons.shopping_bag, color: Colors.green),
                title: Text(data['materialName'] ?? 'Sin nombre'),
                subtitle: Text('Proyecto: ${data['projectName'] ?? ''}'),
                trailing: Text(formattedDate),
              );
            },
          );
        },
      ),
    );
  }
}
