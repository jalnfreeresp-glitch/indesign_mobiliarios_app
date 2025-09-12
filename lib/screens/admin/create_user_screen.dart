import 'package:cloud_functions/cloud_functions.dart'; // Importa el paquete de Cloud Functions
import 'package:flutter/material.dart';

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedRole;
  bool _isLoading = false; // Variable para mostrar un indicador de carga

  final List<String> _roles = [
    'cliente',
    'carpintero',
    'comprador',
    'administrador'
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- FUNCIÓN ACTUALIZADA PARA LLAMAR A LA CLOUD FUNCTION ---
  Future<void> _createUser() async {
    // Si el formulario no es válido, no hacemos nada.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Mostramos el indicador de carga
    setState(() {
      _isLoading = true;
    });

    try {
      // Obtenemos una instancia de la función que desplegamos en Firebase
      final callable = FirebaseFunctions.instance.httpsCallable('createUser');

      // La llamamos pasándole los datos del formulario
      final result = await callable.call<Map<String, dynamic>>({
        'fullName': _fullNameController.text,
        'email': _emailController.text,
        'password': _passwordController.text,
        'role': _selectedRole,
      });

      // Si el widget todavía está en pantalla, mostramos el mensaje de éxito
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result.data['message']),
            backgroundColor: Colors.green),
      );
      // Y volvemos al panel de administrador
      Navigator.pop(context);
    } on FirebaseFunctionsException catch (e) {
      // Si la función devuelve un error, lo mostramos
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.message ?? 'Ocurrió un error desconocido'),
            backgroundColor: Colors.red),
      );
    } finally {
      // Ocultamos el indicador de carga, tanto si hubo éxito como si hubo error
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Nuevo Usuario'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Nombre Completo'),
                validator: (value) =>
                    value!.isEmpty ? 'Por favor, ingrese un nombre' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration:
                    const InputDecoration(labelText: 'Correo Electrónico'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                    value!.isEmpty ? 'Por favor, ingrese un correo' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
                validator: (value) => (value?.length ?? 0) < 6
                    ? 'La contraseña debe tener al menos 6 caracteres'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                hint: const Text('Seleccionar Rol'),
                items: _roles.map((String role) {
                  return DropdownMenuItem<String>(
                    value: role,
                    child: Text(role[0].toUpperCase() + role.substring(1)),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedRole = newValue;
                  });
                },
                validator: (value) =>
                    value == null ? 'Por favor, seleccione un rol' : null,
              ),
              const SizedBox(height: 32),
              // Mostramos el botón o el indicador de carga según el estado de _isLoading
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _createUser,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50)),
                      child: const Text('Crear Usuario'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
