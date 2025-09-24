import 'package:flutter/material.dart';
import 'package:indesign_mobiliarios_app/providers/project_provider.dart';
import 'package:provider/provider.dart';

class EditProjectScreen extends StatefulWidget {
  final Project project;
  const EditProjectScreen({super.key, required this.project});

  @override
  State<EditProjectScreen> createState() => _EditProjectScreenState();
}

class _EditProjectScreenState extends State<EditProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _projectNameController;
  late TextEditingController _montoTotalController;
  late TextEditingController _manoDeObraController;

  @override
  void initState() {
    super.initState();
    _projectNameController = TextEditingController(text: widget.project.projectName);
    _montoTotalController =
        TextEditingController(text: widget.project.montoTotal.toString());
    _manoDeObraController =
        TextEditingController(text: widget.project.costoManoDeObra.toString());
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _montoTotalController.dispose();
    _manoDeObraController.dispose();
    super.dispose();
  }

  Future<void> _updateProject() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await Provider.of<ProjectProvider>(context, listen: false).updateProject(
        widget.project.id,
        {
          'projectName': _projectNameController.text.trim(),
          'montoTotal': double.tryParse(_montoTotalController.text.trim()) ?? 0.0,
          'costoManoDeObra':
              double.tryParse(_manoDeObraController.text.trim()) ?? 0.0,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Proyecto actualizado con éxito'),
            backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al actualizar el proyecto: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Proyecto'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _projectNameController,
                decoration:
                    const InputDecoration(labelText: 'Nombre del Proyecto'),
                validator: (value) =>
                    value!.isEmpty ? 'Ingrese un nombre' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _montoTotalController,
                decoration: const InputDecoration(
                    labelText: 'Monto Total del Presupuesto'),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value!.isEmpty ? 'Ingrese un monto' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _manoDeObraController,
                decoration:
                    const InputDecoration(labelText: 'Monto Mano de Obra'),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value!.isEmpty ? 'Ingrese un monto' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _updateProject,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Guardar Cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
