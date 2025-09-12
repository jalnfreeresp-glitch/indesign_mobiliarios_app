import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  Future<String> _getProjectName(String? projectId) async {
    if (projectId == null || projectId.isEmpty) return 'N/A';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();
      return doc.exists
          ? doc.data()!['projectName'] ?? 'Sin Nombre'
          : 'No Encontrado';
    } catch (e) {
      return 'Error';
    }
  }

  Future<String> _getCarpenterName(String? carpenterId) async {
    if (carpenterId == null || carpenterId.isEmpty) return 'N/A';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(carpenterId)
          .get();
      return doc.exists
          ? doc.data()!['fullName'] ?? 'Sin Nombre'
          : 'No Encontrado';
    } catch (e) {
      return 'Error';
    }
  }

  Future<void> _showMoveToWorkshopDialog(
      String materialName, num currentStock) async {
    final formKey = GlobalKey<FormState>();
    final quantityController = TextEditingController();
    String? selectedProjectId;
    String? selectedCarpenterId;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Mover "$materialName" a Taller'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Stock actual en almacén: $currentStock'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration:
                        const InputDecoration(labelText: 'Cantidad a mover'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Requerido';
                      }
                      final quantity = int.tryParse(value);
                      if (quantity == null || quantity <= 0) {
                        return 'Cantidad inválida';
                      }
                      if (quantity > currentStock) {
                        return 'No hay suficiente stock';
                      }
                      return null;
                    },
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('projects')
                        .where('status', isNotEqualTo: 'finalizado')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Text('Cargando proyectos...');
                      }
                      return DropdownButtonFormField<String>(
                        hint: const Text('Asignar a Proyecto'),
                        items: snapshot.data!.docs.map((doc) {
                          return DropdownMenuItem(
                              value: doc.id, child: Text(doc['projectName']));
                        }).toList(),
                        onChanged: (value) => selectedProjectId = value,
                        validator: (value) {
                          if (value == null) {
                            return 'Seleccione un proyecto';
                          }
                          return null;
                        },
                      );
                    },
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: 'carpintero')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Text('Cargando carpinteros...');
                      }
                      return DropdownButtonFormField<String>(
                        hint: const Text('Responsable'),
                        items: snapshot.data!.docs.map((doc) {
                          return DropdownMenuItem(
                              value: doc.id, child: Text(doc['fullName']));
                        }).toList(),
                        onChanged: (value) => selectedCarpenterId = value,
                        validator: (value) {
                          if (value == null) {
                            return 'Seleccione un carpintero';
                          }
                          return null;
                        },
                      );
                    },
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
                    'quantity': int.parse(quantityController.text),
                    'projectId': selectedProjectId,
                    'carpenterId': selectedCarpenterId,
                  });
                }
              },
              child: const Text('Mover'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      final quantityToMove = result['quantity'] as int;
      final inventoryRef =
          FirebaseFirestore.instance.collection('inventory').doc(materialName);
      final workshopRef =
          FirebaseFirestore.instance.collection('workshop_inventory').doc();

      try {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          transaction.update(inventoryRef,
              {'stockAlmacen': FieldValue.increment(-quantityToMove)});
          transaction.set(workshopRef, {
            'materialName': materialName,
            'quantity': quantityToMove,
            'projectId': result['projectId'],
            'carpenterId': result['carpenterId'],
            'assignedAt': FieldValue.serverTimestamp(),
          });
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Material movido a taller'),
              backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error al mover material: $e'),
              backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestión de Inventario'),
          backgroundColor: Colors.orange,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.warehouse), text: 'Almacén'),
              Tab(icon: Icon(Icons.construction), text: 'Taller'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // PESTAÑA DE ALMACÉN
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('inventory')
                  .orderBy(FieldPath.documentId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('El inventario del almacén está vacío.'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var item = snapshot.data!.docs[index];
                    return ListTile(
                      title: Text(item.id,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Stock Actual: ${item['stockAlmacen']}'),
                      trailing: ElevatedButton(
                        child: const Text('Mover'),
                        onPressed: () => _showMoveToWorkshopDialog(
                            item.id, item['stockAlmacen']),
                      ),
                    );
                  },
                );
              },
            ),
            // PESTAÑA DE TALLER (ACTUALIZADA)
            StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('workshop_inventory')
                    .orderBy('assignedAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child:
                            Text('No hay materiales asignados en el taller.'));
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var item = snapshot.data!.docs[index].data()
                          as Map<String, dynamic>;
                      return ListTile(
                        title: Text(
                            '${item['materialName']} (Cantidad: ${item['quantity']})'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FutureBuilder<String>(
                              future: _getProjectName(item['projectId']),
                              builder: (context, nameSnapshot) => Text(
                                  'Proyecto: ${nameSnapshot.data ?? 'Cargando...'}'),
                            ),
                            FutureBuilder<String>(
                              future: _getCarpenterName(item['carpenterId']),
                              builder: (context, nameSnapshot) => Text(
                                  'Para: ${nameSnapshot.data ?? 'Cargando...'}'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }),
          ],
        ),
      ),
    );
  }
}
