import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BalanceScreen extends StatelessWidget {
  const BalanceScreen({super.key});

  Future<Map<String, double>> _calculateBalances() async {
    // Obtenemos los datos de las colecciones
    final projectsSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .where('isArchived', isEqualTo: false) // Solo proyectos activos
        .get();

    final transactionsSnapshot =
        await FirebaseFirestore.instance.collection('transactions').get();

    final creditSalesSnapshot =
        await FirebaseFirestore.instance.collection('credit_sales').get();

    // Variables para los balances
    double totalFacturadoProyectos = 0;
    double totalManoDeObra = 0;
    double totalVentasCredito = 0;
    double totalCobradoCredito = 0;
    double totalCobradoAbonos = 0;
    double totalPagadoACarpinteros = 0;
    double totalGastos = 0;

    // --- CÁLCULOS ---

    // 1. Proyectos
    for (var doc in projectsSnapshot.docs) {
      var data = doc.data();
      // Sumamos el monto total solo si el proyecto ya fue aceptado
      if (data['status'] != 'presupuesto_pendiente' &&
          data['status'] != 'presupuesto_rechazado') {
        totalFacturadoProyectos += (data['montoTotal'] as num?) ?? 0;
      }
      totalManoDeObra += (data['costoManoDeObra'] as num?) ?? 0;
    }

    // 2. Ventas a Crédito
    for (var doc in creditSalesSnapshot.docs) {
      var data = doc.data();
      totalVentasCredito += (data['totalAmount'] as num?) ?? 0;
      totalCobradoCredito += (data['initialPayment'] as num?) ?? 0;

      final installmentsList = data['installments'] as List? ?? [];
      for (final installment in installmentsList) {
        if (installment['isPaid'] == true) {
          totalCobradoCredito += (installment['amount'] as num?) ?? 0;
        }
      }
    }
    double saldoPendienteCredito = totalVentasCredito - totalCobradoCredito;

    // 3. Transacciones (Pagos y Gastos)
    for (var doc in transactionsSnapshot.docs) {
      var data = doc.data();
      final type = data['type'] as String?;
      final amount = (data['amount'] as num?) ?? 0;

      if (type == 'abono_cliente') {
        totalCobradoAbonos += amount;
      } else if (type == 'pago_carpintero') {
        totalPagadoACarpinteros += amount;
      } else if (type == 'gasto_materiales' || type == 'gasto_varios') {
        totalGastos += amount;
      }
    }

    // 4. Totales Finales
    double saldoPendienteClientes =
        totalFacturadoProyectos - totalCobradoAbonos;
    double saldoPendienteCarpinteros =
        totalManoDeObra - totalPagadoACarpinteros;
    double ingresosTotales = totalCobradoAbonos + totalCobradoCredito;
    double egresosTotales = totalPagadoACarpinteros + totalGastos;
    double gananciaNeta = ingresosTotales - egresosTotales;

    return {
      'totalFacturadoProyectos': totalFacturadoProyectos,
      'totalCobradoAbonos': totalCobradoAbonos,
      'saldoPendienteClientes': saldoPendienteClientes,
      'totalManoDeObra': totalManoDeObra,
      'totalPagadoACarpinteros': totalPagadoACarpinteros,
      'saldoPendienteCarpinteros': saldoPendienteCarpinteros,
      'totalGastos': totalGastos,
      'gananciaNeta': gananciaNeta,
      'ingresosTotales': ingresosTotales,
      'egresosTotales': egresosTotales,
      'totalVentasCredito': totalVentasCredito,
      'totalCobradoCredito': totalCobradoCredito,
      'saldoPendienteCredito': saldoPendienteCredito,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Balance Financiero'),
        backgroundColor: Colors.orange,
      ),
      body: FutureBuilder<Map<String, double>>(
        future: _calculateBalances(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay datos para calcular.'));
          }

          final balances = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBalanceCard(
                    title: 'Balance General (Proyectos)',
                    totalLabel: 'Total Facturado (Aceptados):',
                    totalValue: balances['totalFacturadoProyectos']!,
                    paidLabel: 'Total Cobrado (Abonos):',
                    paidValue: balances['totalCobradoAbonos']!,
                    pendingLabel: 'Saldo Pendiente por Cobrar:',
                    pendingValue: balances['saldoPendienteClientes']!,
                  ),
                  const SizedBox(height: 20),
                  _buildBalanceCard(
                    title: 'Balance de Ventas a Crédito',
                    totalLabel: 'Total Vendido a Crédito:',
                    totalValue: balances['totalVentasCredito']!,
                    paidLabel: 'Total Cobrado (Iniciales + Cuotas):',
                    paidValue: balances['totalCobradoCredito']!,
                    pendingLabel: 'Saldo Pendiente por Cobrar:',
                    pendingValue: balances['saldoPendienteCredito']!,
                    color: Colors.teal,
                  ),
                  const SizedBox(height: 20),
                  _buildBalanceCard(
                    title: 'Balance de Mano de Obra',
                    totalLabel: 'Total a Pagar a Carpinteros:',
                    totalValue: balances['totalManoDeObra']!,
                    paidLabel: 'Total Pagado:',
                    paidValue: balances['totalPagadoACarpinteros']!,
                    pendingLabel: 'Saldo Pendiente por Pagar:',
                    pendingValue: balances['saldoPendienteCarpinteros']!,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 20),
                  _buildBalanceCard(
                    title: 'Resumen de Ganancias',
                    totalLabel: 'Ingresos Totales (Cobrado):',
                    totalValue: balances['ingresosTotales']!,
                    paidLabel: 'Egresos (Pagos + Gastos):',
                    paidValue: balances['egresosTotales']!,
                    pendingLabel: 'Ganancia Neta:',
                    pendingValue: balances['gananciaNeta']!,
                    color: Colors.purple,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard({
    required String title,
    required String totalLabel,
    required double totalValue,
    required String paidLabel,
    required double paidValue,
    required String pendingLabel,
    required double pendingValue,
    Color color = Colors.orange,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
            const Divider(height: 20),
            _buildDetailRow(totalLabel, totalValue),
            _buildDetailRow(paidLabel, paidValue),
            const SizedBox(height: 10),
            _buildDetailRow(pendingLabel, pendingValue, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, double value, {bool isTotal = false}) {
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
            ),
          ),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
