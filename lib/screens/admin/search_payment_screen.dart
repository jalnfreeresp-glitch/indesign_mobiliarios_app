import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:indesign_mobiliarios_app/screens/admin/credit_sale_detail_screen.dart';

class SearchPaymentScreen extends StatefulWidget {
  const SearchPaymentScreen({super.key});
  @override
  State<SearchPaymentScreen> createState() => _SearchPaymentScreenState();
}

class _SearchPaymentScreenState extends State<SearchPaymentScreen> {
  String _searchText = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Venta por Teléfono'),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchText = value;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Buscar por número de teléfono',
                suffixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // La consulta se actualiza en tiempo real mientras escribes
              stream: _searchText.isEmpty
                  ? null // No muestra nada si la búsqueda está vacía
                  : FirebaseFirestore.instance
                      .collection('credit_sales')
                      .where('customerPhone',
                          isGreaterThanOrEqualTo: _searchText)
                      .where('customerPhone',
                          isLessThanOrEqualTo: '$_searchText\uf8ff')
                      .snapshots(),
              builder: (context, snapshot) {
                if (_searchText.isEmpty) {
                  return const Center(
                      child: Text('Ingrese un número para buscar.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('No se encontraron ventas para ese número.'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var sale = snapshot.data!.docs[index];
                    return ListTile(
                      title: Text(sale['customerName']),
                      subtitle: Text(sale['customerPhone']),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  CreditSaleDetailScreen(sale: sale)),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
