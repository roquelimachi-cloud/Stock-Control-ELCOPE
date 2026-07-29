import 'package:flutter/material.dart';

import '../../services/supabase/usuario_service.dart';

class NuevoUsuarioPage extends StatefulWidget {
  const NuevoUsuarioPage({super.key});

  @override
  State<NuevoUsuarioPage> createState() => _NuevoUsuarioPageState();
}

class _NuevoUsuarioPageState extends State<NuevoUsuarioPage> {
  final UsuarioService servicio = UsuarioService();

  final usuarioController = TextEditingController();
  final nombreController = TextEditingController();
  final correoController = TextEditingController();
  final passwordController = TextEditingController();

  String rol = "Comercial";

  bool guardando = false;
  bool ocultarPassword = true;

  Future<void> guardarUsuario() async {
    if (usuarioController.text.trim().isEmpty ||
        nombreController.text.trim().isEmpty ||
        correoController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Complete todos los campos."),
        ),
      );
      return;
    }

    try {
      setState(() {
        guardando = true;
      });

      await servicio.insertarUsuario(
        usuario: usuarioController.text.trim(),
        nombre: nombreController.text.trim(),
        correo: correoController.text.trim(),
        password: passwordController.text.trim(),
        rol: rol,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Usuario registrado correctamente."),
        ),
      );

      Navigator.pop(context);
    } catch (e, stackTrace) {
  debugPrint("ERROR AL GUARDAR USUARIO:");
  debugPrint(e.toString());
  debugPrint(stackTrace.toString());

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(e.toString()),
    ),
  );
    } finally {
      if (mounted) {
        setState(() {
          guardando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    usuarioController.dispose();
    nombreController.dispose();
    correoController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("NUEVO USUARIO"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(
              controller: usuarioController,
              decoration: const InputDecoration(
                labelText: "Usuario",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: nombreController,
              decoration: const InputDecoration(
                labelText: "Nombre Completo",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: correoController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Correo",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: passwordController,
              obscureText: ocultarPassword,
              decoration: InputDecoration(
                labelText: "Contraseña",
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    ocultarPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      ocultarPassword = !ocultarPassword;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              value: rol,
              decoration: const InputDecoration(
                labelText: "Rol",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.admin_panel_settings),
              ),
              items: const [
                DropdownMenuItem(
                  value: "Administrador",
                  child: Text("Administrador"),
                ),
                DropdownMenuItem(
                  value: "Comercial",
                  child: Text("Comercial"),
                ),
                DropdownMenuItem(
                  value: "Producción",
                  child: Text("Producción"),
                ),
                DropdownMenuItem(
                  value: "Logística",
                  child: Text("Logística"),
                ),
                DropdownMenuItem(
                  value: "Gerencia",
                  child: Text("Gerencia"),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  rol = value;
                });
              },
            ),

            const SizedBox(height: 30),

            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: guardando ? null : guardarUsuario,
                icon: guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  guardando
                      ? "Guardando..."
                      : "GUARDAR USUARIO",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}