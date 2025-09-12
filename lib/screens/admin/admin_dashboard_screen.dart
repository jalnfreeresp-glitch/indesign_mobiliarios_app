import 'package:flutter/material.dart';
import 'package:indesign_mobiliarios_app/services/auth_service.dart';
import 'package:indesign_mobiliarios_app/screens/admin/admin_requirements_screen.dart';
import 'package:indesign_mobiliarios_app/screens/admin/admin_tasks_screen.dart';
import 'package:indesign_mobiliarios_app/screens/admin/admin_users_screen.dart';
import 'package:indesign_mobiliarios_app/screens/admin/all_projects_screen.dart';
import 'package:indesign_mobiliarios_app/screens/admin/archived_projects_screen.dart';
import 'package:indesign_mobiliarios_app/screens/admin/assign_projects_screen.dart';
import 'package:indesign_mobiliarios_app/screens/admin/balance_screen.dart';
import 'package:indesign_mobiliarios_app/screens/admin/create_project_screen.dart';
import 'package:indesign_mobiliarios_app/screens/admin/credit_sales_list_screen.dart';
import 'package:indesign_mobiliarios_app/screens/admin/inventory_screen.dart';
import 'package:indesign_mobiliarios_app/screens/admin/materials_catalog_screen.dart';
import 'package:indesign_mobiliarios_app/screens/admin/record_payment_screen.dart';
import 'package:indesign_mobiliarios_app/screens/admin/scraps_management_screen.dart';
import 'package:indesign_mobiliarios_app/screens/admin/transaction_history_screen.dart';
import 'package:indesign_mobiliarios_app/screens/admin/upcoming_installments_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> projectItems = [
      {
        'icon': Icons.list_alt,
        'label': 'Proyectos',
        'screen': const AllProjectsScreen()
      },
      {
        'icon': Icons.inventory_2,
        'label': 'Archivados',
        'screen': const ArchivedProjectsScreen()
      },
      {
        'icon': Icons.assignment_ind,
        'label': 'Asignar',
        'screen': const AssignProjectsScreen()
      },
      {
        'icon': Icons.note_add,
        'label': 'Presupuestos',
        'screen': const CreateProjectScreen()
      },
      {
        'iconWidget': const Text('C',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.orange)),
        'label': 'Ventas Cashea',
        'screen': const CreditSalesListScreen()
      },
      {
        'icon': Icons.calendar_today,
        'label': 'Fechas de Pago',
        'screen': const UpcomingInstallmentsScreen()
      },
    ];

    final List<Map<String, dynamic>> staffItems = [
      {
        'icon': Icons.task_alt,
        'label': 'Tareas',
        'screen': const AdminTasksScreen()
      },
      {
        'icon': Icons.rule,
        'label': 'Requerimientos',
        'screen': const AdminRequirementsScreen()
      },
      {
        'icon': Icons.people,
        'label': 'Usuarios',
        'screen': const AdminUsersScreen()
      },
    ];

    final List<Map<String, dynamic>> financeItems = [
      {
        'icon': Icons.account_balance,
        'label': 'Balances',
        'screen': const BalanceScreen()
      },
      {
        'icon': Icons.payment,
        'label': 'Registrar Pago',
        'screen': const RecordPaymentScreen()
      },
      {
        'icon': Icons.history,
        'label': 'Historial',
        'screen': const TransactionHistoryScreen()
      },
    ];

    final List<Map<String, dynamic>> configItems = [
      {
        'icon': Icons.inventory,
        'label': 'Inventario',
        'screen': const InventoryScreen()
      },
      {
        'icon': Icons.sell,
        'label': 'Precios',
        'screen': const MaterialsCatalogScreen()
      },
      {
        'icon': Icons.cut,
        'label': 'Sobrantes',
        'screen': const ScrapsManagementScreen()
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administrador'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        children: [
          _buildSectionHeader(context, 'Gestión de Proyectos', Colors.orange),
          _buildGridView(context, projectItems),
          _buildSectionHeader(context, 'Gestión de Personal', Colors.purple),
          _buildGridView(context, staffItems),
          _buildSectionHeader(context, 'Finanzas', Colors.green),
          _buildGridView(context, financeItems),
          _buildSectionHeader(
              context, 'Inventario y Configuración', Colors.brown),
          _buildGridView(context, configItems),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, Color color) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.only(top: 24.0, bottom: 16.0),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildGridView(
      BuildContext context, List<Map<String, dynamic>> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildDashboardButton(
          context,
          icon: item['icon'],
          iconWidget: item['iconWidget'],
          label: item['label'],
          screen: item['screen'],
        );
      },
    );
  }

  Widget _buildDashboardButton(BuildContext context,
      {IconData? icon,
      Widget? iconWidget,
      required String label,
      required Widget screen}) {
    final Widget displayIcon =
        iconWidget ?? Icon(icon, size: 30, color: Colors.orange.shade800);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => screen),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          displayIcon,
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
