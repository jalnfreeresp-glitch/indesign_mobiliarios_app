import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;
  final String userRole;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    required this.userRole,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  Future<Map<String, dynamic>> _getProjectDetails() async {
    final projectDocFuture = FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .get();
    final clientTransactionsFuture = FirebaseFirestore.instance
        .collection('transactions')
        .where('projectId', isEqualTo: widget.projectId)
        .where('type', isEqualTo: 'abono_cliente')
        .get();
    final carpenterTransactionsFuture = FirebaseFirestore.instance
        .collection('transactions')
        .where('projectId', isEqualTo: widget.projectId)
        .where('type', isEqualTo: 'pago_carpintero')
        .get();

    final results = await Future.wait([
      projectDocFuture,
      clientTransactionsFuture,
      carpenterTransactionsFuture,
    ]);

    final projectData =
        (results[0] as DocumentSnapshot).data() as Map<String, dynamic>;
    final clientTransactions = (results[1] as QuerySnapshot).docs;
    final carpenterTransactions = (results[2] as QuerySnapshot).docs;

    double totalAbonosCliente = 0;
    for (var doc in clientTransactions) {
      totalAbonosCliente += (doc['amount'] as num?) ?? 0;
    }
    double totalPagosCarpintero = 0;
    for (var doc in carpenterTransactions) {
      totalPagosCarpintero += (doc['amount'] as num?) ?? 0;
    }

    return {
      'projectData': projectData,
      'totalAbonosCliente': totalAbonosCliente,
      'totalPagosCarpintero': totalPagosCarpintero,
    };
  }

  Future<void> _updateProjectStatus(String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({'status': newStatus});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estado del proyecto actualizado a "$newStatus"'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar el estado: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showStatusUpdateDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final List<String> possibleStatus = [
          'compra_de_materiales',
          'en_corte',
          'en_armado',
          'espera_instalacion',
          'instalando',
          'entregada',
        ];
        return AlertDialog(
          title: const Text('Actualizar Estado del Proyecto'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: possibleStatus.length,
              itemBuilder: (context, index) {
                final status = possibleStatus[index];
                final formattedStatus = status
                    .replaceAll('_', ' ')
                    .replaceFirst(status[0], status[0].toUpperCase());
                return ListTile(
                  title: Text(formattedStatus),
                  onTap: () {
                    Navigator.of(context).pop();
                    _updateProjectStatus(status);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  // --- FUNCIÓN PARA AÑADIR ADICIONALES ---
  Future<void> _showAddAdditionDialog() async {
    final formKey = GlobalKey<FormState>();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir Adicional al Proyecto'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Descripción'),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            TextFormField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Precio (USD)'),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop({
                  'description': descriptionController.text,
                  'price': double.tryParse(priceController.text) ?? 0.0,
                });
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result != null) {
      final price = result['price'] as double;
      if (price <= 0) return;

      final projectRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId);

      try {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          // 1. Actualizamos el monto total y el costo de adicionales en el proyecto principal
          transaction.update(projectRef, {
            'montoTotal': FieldValue.increment(price),
            'additionalCosts': FieldValue.increment(price)
          });

          // 2. Creamos el nuevo documento en la subcolección
          transaction.set(projectRef.collection('project_additions').doc(), {
            'description': result['description'],
            'price': price,
            'createdAt': FieldValue.serverTimestamp(),
          });
        });
        setState(
            () {}); // Forzamos un refresco de la pantalla para ver el nuevo total
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al añadir adicional: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Proyecto'),
        backgroundColor: Colors.orange,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getProjectDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(
                child: Text('Proyecto no encontrado o error al cargar.'));
          }

          final projectData =
              snapshot.data!['projectData'] as Map<String, dynamic>;
          final totalAbonosCliente =
              snapshot.data!['totalAbonosCliente'] as double;
          final totalPagosCarpintero =
              snapshot.data!['totalPagosCarpintero'] as double;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Nombre del Proyecto:',
                    projectData['projectName'] ?? 'N/A'),
                _buildDetailRow('Cliente:', projectData['clientName'] ?? 'N/A'),
                _buildDetailRow('Estado:',
                    projectData['status']?.replaceAll('_', ' ') ?? 'N/A'),
                if (projectData['estimatedDeliveryDate'] != null)
                  _buildDetailRow(
                      'Fecha de Entrega:',
                      DateFormat('dd/MM/yyyy').format(
                          (projectData['estimatedDeliveryDate'] as Timestamp)
                              .toDate())),
                const Divider(height: 30),
                const Text('Adicionales',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                _buildAdditionsList(),
                if (widget.userRole == 'administrador')
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir Adicional'),
                      onPressed: _showAddAdditionDialog,
                    ),
                  ),
                const Divider(height: 30),
                _buildFinancialSection(
                  projectData,
                  totalAbonosCliente,
                  totalPagosCarpintero,
                ),
                const SizedBox(height: 30),
                if (widget.userRole == 'administrador')
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _showStatusUpdateDialog,
                      icon: const Icon(Icons.update),
                      label: const Text('Actualizar Estado'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdditionsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('project_additions')
          .orderBy('createdAt')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Padding(
                  padding: EdgeInsets.all(8.0), child: Text("Cargando...")));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('No hay adicionales registrados.'),
          );
        }
        return Column(
          children: snapshot.data!.docs.map((doc) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(doc['description']),
              trailing: Text('+\$${(doc['price'] as num).toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold)),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFinancialSection(
      Map<String, dynamic> projectData, double totalAbonos, double totalPagos) {
    final montoTotal = (projectData['montoTotal'] as num?) ?? 0;
    final costoManoDeObra = (projectData['costoManoDeObra'] as num?) ?? 0;

    final saldoCliente = montoTotal - totalAbonos;
    final saldoCarpintero = costoManoDeObra - totalPagos;

    List<Widget> financialWidgets = [];
    financialWidgets.add(
      const Text('Información Financiera',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
    financialWidgets.add(const SizedBox(height: 8));

    switch (widget.userRole) {
      case 'administrador':
        financialWidgets.addAll([
          _buildDetailRow(
              'Monto Total Presupuesto:', '\$${montoTotal.toStringAsFixed(2)}'),
          _buildDetailRow(
              'Monto Mano de Obra:', '\$${costoManoDeObra.toStringAsFixed(2)}'),
          const Divider(),
          const Text('Balances',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          _buildDetailRow(
              'Total Abonos Cliente:', '\$${totalAbonos.toStringAsFixed(2)}'),
          _buildDetailRow(
              'SALDO CLIENTE:', '\$${saldoCliente.toStringAsFixed(2)}',
              isTotal: true),
          const SizedBox(height: 15),
          _buildDetailRow(
              'Total Pagos Carpintero:', '\$${totalPagos.toStringAsFixed(2)}'),
          _buildDetailRow(
              'SALDO CARPINTERO:', '\$${saldoCarpintero.toStringAsFixed(2)}',
              isTotal: true),
        ]);
        break;
      case 'carpintero':
        financialWidgets.addAll([
          _buildDetailRow('Pago Total Mano de Obra:',
              '\$${costoManoDeObra.toStringAsFixed(2)}'),
          _buildDetailRow(
              'Total Recibido:', '\$${totalPagos.toStringAsFixed(2)}'),
          _buildDetailRow(
              'SALDO PENDIENTE:', '\$${saldoCarpintero.toStringAsFixed(2)}',
              isTotal: true),
        ]);
        break;
      case 'cliente':
        financialWidgets.addAll([
          _buildDetailRow('Monto Total del Proyecto:',
              '\$${montoTotal.toStringAsFixed(2)}'),
          _buildDetailRow(
              'Total Abonado:', '\$${totalAbonos.toStringAsFixed(2)}'),
          _buildDetailRow(
              'SALDO PENDIENTE:', '\$${saldoCliente.toStringAsFixed(2)}',
              isTotal: true),
        ]);
        break;
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: financialWidgets);
  }

  Widget _buildDetailRow(String title, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
