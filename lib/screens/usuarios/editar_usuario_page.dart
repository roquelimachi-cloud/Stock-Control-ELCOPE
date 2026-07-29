import 'package:flutter/material.dart';

import '../../models/usuario.dart';
import '../../services/supabase/usuario_service.dart';

class EditarUsuarioPage extends StatefulWidget {
  final Usuario usuario;

  const EditarUsuarioPage({
    super.key,
    required this.usuario,
  });

  @override
  State<EditarUsuarioPage> createState() => _EditarUsuarioPageState();
}

class _EditarUsuarioPageState extends State<EditarUsuarioPage> {
  final UsuarioService servicio = UsuarioService();

  final _formKey = GlobalKey<FormState>();

  late TextEditingController usuarioController;
  late TextEditingController nombreController;
  late TextEditingController correoController;
  late TextEditingController passwordController;

  late String rol;
  late bool activo;

  bool guardando = false;

  @override
  void initState() {
    super.initState();

    usuarioController =
        TextEditingController(text: widget.usuario.usuario);

    nombreController =
        TextEditingController(text: widget.usuario.nombre);

    correoController =
        TextEditingController(text: widget.usuario.correo);

    passwordController = TextEditingController();

    rol = widget.usuario.rol;
    activo = widget.usuario.activo;
  }
Future<void> guardar() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    guardando = true;
  });

  try {
    print("Iniciando actualización...");

    await servicio.actualizarUsuario(
      widget.usuario.id,
      usuario: usuarioController.text.trim(),
      nombre: nombreController.text.trim(),
      correo: correoController.text.trim(),
      password: passwordController.text.trim(),
      rol: rol,
      activo: activo,
    );

    print("Actualización correcta");

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Usuario actualizado correctamente"),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context);
  } catch (e) {
    print("ERROR:");
    print(e);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString()),
        backgroundColor: Colors.red,
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editar Usuario"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SizedBox(
          width: 500,
          child: Card(
            margin: const EdgeInsets.all(20),
            elevation: 5,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [

                    TextFormField(
                      controller: usuarioController,
                      decoration: const InputDecoration(
                        labelText: "Usuario",
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v!.isEmpty ? "Ingrese el usuario" : null,
                    ),

                    const SizedBox(height: 15),

                    TextFormField(
                      controller: nombreController,
                      decoration: const InputDecoration(
                        labelText: "Nombre",
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v!.isEmpty ? "Ingrese el nombre" : null,
                    ),

                    const SizedBox(height: 15),

                    TextFormField(
                      controller: correoController,
                      decoration: const InputDecoration(
                        labelText: "Correo",
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v!.isEmpty ? "Ingrese el correo" : null,
                    ),

                    const SizedBox(height: 15),

                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Nueva contraseña (opcional)",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 15),

               DropdownButtonFormField<String>(
  value: rol,
  decoration: const InputDecoration(
    labelText: "Rol",
    border: OutlineInputBorder(),
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
      value: "Usuario",
      child: Text("Usuario"),
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
      value: "Compras",
      child: Text("Compras"),
    ),
  ],
  onChanged: (value) {
    setState(() {
      rol = value!;
    });
  },
),

                    const SizedBox(height: 15),

                    SwitchListTile(
                      title: const Text("Usuario Activo"),
                      value: activo,
                      onChanged: (value) {
                        setState(() {
                          activo = value;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: guardando ? null : guardar,
                        icon: const Icon(Icons.save),
                        label: Text(
                          guardando
                              ? "Guardando..."
                              : "Guardar Cambios",
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}