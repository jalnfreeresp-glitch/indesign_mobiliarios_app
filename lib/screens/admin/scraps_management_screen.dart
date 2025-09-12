import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ScrapsManagementScreen extends StatefulWidget {
  const ScrapsManagementScreen({super.key});

  @override
  State<ScrapsManagementScreen> createState() => _ScrapsManagementScreenState();
}

class _ScrapsManagementScreenState extends State<ScrapsManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _materialController = TextEditingController();
  final _thicknessController = TextEditingController();
  final _dimensionsController = TextEditingController();

  void _showAddScrapDialog() {
    _materialController.clear();
    _thicknessController.clear();
    _dimensionsController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Registrar Sobrante de Material'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _materialController,
                    decoration: const InputDecoration(
                        labelText: 'Tipo de Material (ej. Melamina)'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: _thicknessController,
                    decoration:
                        const InputDecoration(labelText: 'Espesor (ej. 18mm)'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: _dimensionsController,
                    decoration: const InputDecoration(
                        labelText: 'Medidas (ej. 50cm x 30cm)'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar')),
            ElevatedButton(onPressed: _addScrap, child: const Text('Guardar')),
          ],
        );
      },
    );
  }

  Future<void> _addScrap() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await FirebaseFirestore.instance.collection('scraps').add({
        'materialType': _materialController.text,
        'thickness': _thicknessController.text,
        'dimensions': _dimensionsController.text,
        'registeredAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // Manejar error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario de Sobrantes'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('scraps')
            .orderBy('registeredAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay sobrantes registrados.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var scrap = snapshot.data!.docs[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title:
                      Text('${scrap['materialType']} - ${scrap['thickness']}'),
                  subtitle: Text('Medidas: ${scrap['dimensions']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('scraps')
                          .doc(scrap.id)
                          .delete();
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddScrapDialog,
        tooltip: 'Añadir Sobrante',
        child: const Icon(Icons.add),
      ),
    );
  }
}
