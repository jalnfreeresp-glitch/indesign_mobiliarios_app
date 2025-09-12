import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:indesign_mobiliarios_app/screens/admin/create_credit_sale_screen.dart';
import 'package:indesign_mobiliarios_app/screens/admin/credit_sale_detail_screen.dart';
import 'package:indesign_mobiliarios_app/screens/admin/search_payment_screen.dart';

class CreditSalesListScreen extends StatelessWidget {
  const CreditSalesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas a Crédito (Cashea)'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('credit_sales')
            .orderBy('saleDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('No hay ventas a crédito registradas.'));
          }
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var sale = snapshot.data!.docs[index];
              return ListTile(
                title: Text(sale['customerName']),
                subtitle: Text(
                    'Deuda restante: \$${(sale['remainingDebt'] as num).toStringAsFixed(2)}'),
                trailing: Chip(
                  label: Text(sale['isFullyPaid'] ? 'Pagado' : 'Pendiente'),
                  backgroundColor: sale['isFullyPaid']
                      ? Colors.green[100]
                      : Colors.orange[100],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreditSaleDetailScreen(sale: sale),
                    ),
                  );
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
          FloatingActionButton(
            heroTag: 'searchPayment',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SearchPaymentScreen()),
              );
            },
            tooltip: 'Buscar Pago por Teléfono',
            backgroundColor: Colors.blue,
            child: const Icon(Icons.search),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'addSale',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CreateCreditSaleScreen()),
              );
            },
            tooltip: 'Registrar Venta a Crédito',
            backgroundColor: Colors.teal,
            child: const Icon(Icons.add_card),
          ),
        ],
      ),
    );
  }
}
