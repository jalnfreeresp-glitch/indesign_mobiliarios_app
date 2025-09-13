import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Pequeña extensión para poner en mayúscula la primera letra
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class VariantsManagementScreen extends StatefulWidget {
  final DocumentSnapshot materialType;
  const VariantsManagementScreen({super.key, required this.materialType});

  @override
  State<VariantsManagementScreen> createState() =>
      _VariantsManagementScreenState();
}

class _VariantsManagementScreenState extends State<VariantsManagementScreen> {
  // --- DIÁLOGO INTELIGENTE PARA AÑADIR/EDITAR VARIANTE ---
  void _showVariantDialog({DocumentSnapshot? existingVariant}) {
    final bool isEditing = existingVariant != null;
    final formKey = GlobalKey<FormState>();
    final priceController = TextEditingController(
        text: isEditing ? (existingVariant['price'] as num).toString() : '');
    final presentationController = TextEditingController(
        text: isEditing ? existingVariant['presentation'] : '');

    // Mapa para guardar los valores de los atributos de esta variante
    Map<String, String> attributeValues = isEditing
        ? Map<String, String>.from(existingVariant['attributes'])
        : {};

    showDialog(
      context: context,
      builder: (context) {
        // Usamos un StatefulWidget para el diálogo para que pueda manejar su propio estado
        return _VariantDialog(
          materialType: widget.materialType,
          formKey: formKey,
          priceController: priceController,
          presentationController: presentationController,
          initialAttributeValues: attributeValues,
          onSave: (attributes, price, presentation) async {
            if (isEditing) {
              await existingVariant.reference.update({
                'attributes': attributes,
                'price': price,
                'presentation': presentation,
              });
            } else {
              await widget.materialType.reference.collection('variants').add({
                'attributes': attributes,
                'price': price,
                'presentation': presentation,
              });
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Variantes de ${widget.materialType['name']}"),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            widget.materialType.reference.collection('variants').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('No hay variantes para este material.'));
          }
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var variant = snapshot.data!.docs[index];
              var data = variant.data() as Map<String, dynamic>;
              var price = (data['price'] as num?) ?? 0.0;
              var attributes =
                  data['attributes'] as Map<String, dynamic>? ?? {};
              var description = attributes.values.join(' - ');

              return ListTile(
                title: Text(description,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle:
                    Text('Presentación: ${data['presentation'] ?? 'N/A'}'),
                trailing: Text('\$${price.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => _showVariantDialog(existingVariant: variant),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showVariantDialog(),
        tooltip: 'Añadir Variante',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- WIDGET DEL DIÁLOGO INTELIGENTE ---
class _VariantDialog extends StatefulWidget {
  final DocumentSnapshot materialType;
  final GlobalKey<FormState> formKey;
  final TextEditingController priceController;
  final TextEditingController presentationController;
  final Map<String, String> initialAttributeValues;
  final Function(Map<String, String>, double, String) onSave;

  const _VariantDialog({
    required this.materialType,
    required this.formKey,
    required this.priceController,
    required this.presentationController,
    required this.initialAttributeValues,
    required this.onSave,
  });

  @override
  State<_VariantDialog> createState() => _VariantDialogState();
}

class _VariantDialogState extends State<_VariantDialog> {
  late Map<String, String> attributeValues;
  List<DocumentSnapshot> availableAttributes = [];

  @override
  void initState() {
    super.initState();
    attributeValues = widget.initialAttributeValues;
  }

  // Diálogo para crear una nueva DEFINICIÓN de atributo (ej. "Acabado")
  Future<void> _showAddAttributeDefinitionDialog() async {
    final nameController = TextEditingController();
    final newAttribute = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Añadir Nuevo Atributo'),
              content: TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: 'Nombre (ej. Acabado, Veta)')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isNotEmpty) {
                      // Creamos la nueva definición de atributo
                      await FirebaseFirestore.instance
                          .collection('attribute_definitions')
                          .add({
                        'name': nameController.text.capitalize(),
                        'appliesToCategories': [
                          widget.materialType['categoryName']
                        ],
                      });
                      if (!context.mounted) return;
                      Navigator.of(context)
                          .pop(nameController.text.capitalize());
                    }
                  },
                  child: const Text('Añadir'),
                )
              ],
            ));
    if (newAttribute != null) {
      setState(() {
        attributeValues[newAttribute] = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Añadir Variante a "${widget.materialType['name']}"'),
      content: Form(
        key: widget.formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Atributos',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              // Buscamos los atributos que aplican a esta categoría
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('attribute_definitions')
                    .where('appliesToCategories',
                        arrayContains: widget.materialType['categoryName'])
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  availableAttributes = snapshot.data!.docs;
                  return Column(
                    children: availableAttributes.map((attrDoc) {
                      final attrName = attrDoc['name'] as String;
                      return TextFormField(
                        initialValue: attributeValues[attrName],
                        decoration: InputDecoration(labelText: attrName),
                        onChanged: (value) => attributeValues[attrName] = value,
                      );
                    }).toList(),
                  );
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Añadir tipo de atributo'),
                onPressed: _showAddAttributeDefinitionDialog,
              ),
              const Divider(height: 20),
              TextFormField(
                  controller: widget.priceController,
                  decoration: const InputDecoration(labelText: 'Precio (USD)'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Requerido' : null),
              TextFormField(
                  controller: widget.presentationController,
                  decoration:
                      const InputDecoration(labelText: 'Presentación de Venta'),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            if (widget.formKey.currentState!.validate()) {
              widget.onSave(
                attributeValues,
                double.tryParse(widget.priceController.text) ?? 0.0,
                widget.presentationController.text,
              );
              Navigator.of(context).pop();
            }
          },
          child: const Text('Guardar Variante'),
        ),
      ],
    );
  }
}
