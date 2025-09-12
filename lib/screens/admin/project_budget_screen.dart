import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProjectBudgetScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const ProjectBudgetScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ProjectBudgetScreen> createState() => _ProjectBudgetScreenState();
}

class _ProjectBudgetScreenState extends State<ProjectBudgetScreen> {
  Future<void> _showBudgetItemDialog({DocumentSnapshot? existingItem}) async {
    final bool isEditing = existingItem != null;
    final formKey = GlobalKey<FormState>();

    final nameController =
        TextEditingController(text: isEditing ? existingItem['name'] : '');
    final unitPriceController = TextEditingController(
        text: isEditing ? existingItem['unitPrice'].toString() : '');
    final presentationController = TextEditingController(
        text: isEditing ? existingItem['presentation'] : '');
    final quantityController = TextEditingController(
        text: isEditing ? existingItem['quantity'].toString() : '');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEditing ? 'Editar Item' : 'Añadir Item al Presupuesto'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration:
                        const InputDecoration(labelText: 'Nombre del Item'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: unitPriceController,
                    decoration:
                        const InputDecoration(labelText: 'Precio Unitario'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: presentationController,
                    decoration: const InputDecoration(
                        labelText: 'Presentación (ej. caja, lámina)'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: quantityController,
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop({
                    'name': nameController.text,
                    'unitPrice':
                        double.tryParse(unitPriceController.text) ?? 0.0,
                    'presentation': presentationController.text,
                    'quantity': int.tryParse(quantityController.text) ?? 0,
                  });
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      final unitPrice = result['unitPrice'] as double;
      final quantity = result['quantity'] as int;
      final name = result['name'] as String;
      final presentation = result['presentation'] as String;

      final dataToSave = {
        'name': name,
        'unitPrice': unitPrice,
        'presentation': presentation,
        'quantity': quantity,
        'totalAmount': unitPrice * quantity,
        'status': isEditing ? existingItem['status'] : 'pendiente',
      };

      try {
        final collectionRef = FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('budget_items');
        if (isEditing) {
          await collectionRef.doc(existingItem.id).update(dataToSave);
          // Opcional: Podríamos actualizar también la shopping_list,
          // pero por ahora la mantenemos simple.
        } else {
          // 1. Añadir a la lista detallada del presupuesto
          await collectionRef.add(dataToSave);

          // 2. Añadir a la lista de compras central para el comprador
          await FirebaseFirestore.instance.collection('shopping_list').add({
            'materialName': name,
            'quantity': '$quantity $presentation',
            'projectName': widget.projectName,
            'projectId': widget.projectId,
            'isPurchased': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error al guardar: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deleteBudgetItem(String itemId, String materialName) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Estás seguro de que quieres eliminar este item?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sí, Eliminar')),
        ],
      ),
    );

    if (confirmDelete == true) {
      // 1. Eliminar de la lista detallada
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('budget_items')
          .doc(itemId)
          .delete();

      // 2. Eliminar de la lista de compras central
      final shoppingListQuery = await FirebaseFirestore.instance
          .collection('shopping_list')
          .where('projectId', isEqualTo: widget.projectId)
          .where('materialName', isEqualTo: materialName)
          .limit(1)
          .get();

      if (shoppingListQuery.docs.isNotEmpty) {
        await shoppingListQuery.docs.first.reference.delete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Presupuesto: ${widget.projectName}'),
        backgroundColor: Colors.orange,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .get(),
        builder: (context, projectSnapshot) {
          if (!projectSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final projectData =
              projectSnapshot.data!.data() as Map<String, dynamic>;
          final totalPresupuestado = (projectData['montoTotal'] as num?) ?? 0;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('transactions')
                .where('projectId', isEqualTo: widget.projectId)
                .where('type', whereIn: [
              'gasto_materiales',
              'gasto_varios',
              'pago_carpintero'
            ]).snapshots(),
            builder: (context, expenseSnapshot) {
              if (expenseSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final expenses = expenseSnapshot.data?.docs ?? [];
              double totalGastado = 0;
              for (var expense in expenses) {
                totalGastado += (expense['amount'] as num?) ?? 0;
              }
              final diferencia = totalPresupuestado - totalGastado;

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('Resumen del Presupuesto',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const Divider(),
                          ListTile(
                              title: const Text('Monto Total Presupuestado'),
                              trailing: Text(
                                  '\$${totalPresupuestado.toStringAsFixed(2)}')),
                          ListTile(
                              title:
                                  const Text('Total Egresos (Gastos + Pagos)'),
                              trailing:
                                  Text('\$${totalGastado.toStringAsFixed(2)}')),
                          ListTile(
                            title: const Text('Diferencia',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            trailing: Text(
                              '\$${diferencia.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    diferencia >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Items Presupuestados',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  _buildBudgetItemsList(),
                  const Divider(height: 30),
                  const Text('Egresos Registrados',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  _buildExpensesList(expenses),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBudgetItemDialog(),
        tooltip: 'Añadir Item al Presupuesto',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBudgetItemsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('budget_items')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        if (snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('No hay items en este presupuesto.'),
          );
        }
        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pendiente';
            final isPurchased = status == 'comprado';
            final quantity = (data['quantity'] as num?) ?? 0;
            final unitPrice = (data['unitPrice'] as num?) ?? 0;
            final totalAmount = (data['totalAmount'] as num?) ?? 0;

            return ListTile(
              title: Text(data['name'] ?? 'Sin Nombre'),
              subtitle: Text(
                  '$quantity ${data['presentation']} x \$${unitPrice.toStringAsFixed(2)} c/u'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Chip(
                        label: Text(
                          isPurchased ? 'Comprado' : 'Pendiente',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10),
                        ),
                        backgroundColor:
                            isPurchased ? Colors.green : Colors.orange,
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showBudgetItemDialog(existingItem: doc);
                      } else if (value == 'delete') {
                        _deleteBudgetItem(doc.id, data['name']);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('Editar'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Eliminar'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildExpensesList(List<QueryDocumentSnapshot> expenses) {
    if (expenses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('No hay egresos registrados para este proyecto.'),
      );
    }
    return Column(
      children: expenses.map((expense) {
        final data = expense.data() as Map<String, dynamic>;
        final isPayment = data['type'] == 'pago_carpintero';
        return ListTile(
          leading: Icon(isPayment ? Icons.construction : Icons.shopping_cart,
              color: isPayment ? Colors.blue : Colors.brown),
          title: Text(data['description'] ?? 'Sin descripción'),
          trailing: Text('-\$${(expense['amount'] as num).toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.red)),
        );
      }).toList(),
    );
  }
}
