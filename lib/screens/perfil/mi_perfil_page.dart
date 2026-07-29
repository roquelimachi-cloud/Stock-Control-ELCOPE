import 'package:flutter/material.dart';

import '../../models/usuario.dart';
import '../../services/sesion.dart';
import '../../services/supabase/usuario_service.dart';

class MiPerfilPage extends StatefulWidget {
  const MiPerfilPage({super.key});

  @override
  State<MiPerfilPage> createState() => _MiPerfilPageState();
}

class _MiPerfilPageState extends State<MiPerfilPage> {
  final UsuarioService servicio = UsuarioService();

  final _formKey = GlobalKey<FormState>();

  late TextEditingController nombreController;
  late TextEditingController correoController;
  late TextEditingController passwordController;
  late TextEditingController confirmarController;

  bool guardando = false;
  bool ocultarPassword = true;
  bool ocultarConfirmar = true;

  @override
  void initState() {
    super.initState();

    nombreController =
        TextEditingController(text: Sesion.usuarioActual!.nombre);

    correoController =
        TextEditingController(text: Sesion.usuarioActual!.correo);

    passwordController = TextEditingController();

    confirmarController = TextEditingController();
  }

  Future<void> guardar() async {
  if (!_formKey.currentState!.validate()) return;

  if (passwordController.text.isEmpty) {
    final continuar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirmación"),
        content: const Text(
          "No ha ingresado una nueva contraseña.\n\n"
          "¿Desea conservar la contraseña actual?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sí"),
          ),
        ],
      ),
    );

    if (continuar != true) return;
  }

  setState(() {
    guardando = true;
  });

  try {
    await servicio.actualizarMiPerfil(
      id: Sesion.idUsuario,
      nombre: nombreController.text.trim(),
      correo: correoController.text.trim(),
      password: passwordController.text.trim(),
    );
Sesion.usuarioActual = Usuario(
  id: Sesion.usuarioActual!.id,
  usuario: Sesion.usuarioActual!.usuario,
  nombre: nombreController.text.trim(),
  correo: correoController.text.trim(),
  rol: Sesion.usuarioActual!.rol,
  vendedor: Sesion.usuarioActual!.vendedor,
  activo: Sesion.usuarioActual!.activo,
);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.green,
        content: Text("Perfil actualizado correctamente."),
      ),
    );

    Navigator.pop(context);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mi Perfil"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SizedBox(
          width: 520,
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
                      initialValue: Sesion.usuario,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: "Usuario",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextFormField(
                      initialValue: Sesion.rol,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: "Rol",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextFormField(
                      controller: nombreController,
                      decoration: const InputDecoration(
                        labelText: "Nombre",
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v!.isEmpty ? "Ingrese su nombre" : null,
                    ),

                    const SizedBox(height: 15),

                    TextFormField(
                      controller: correoController,
                      decoration: const InputDecoration(
                        labelText: "Correo",
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v!.isEmpty ? "Ingrese su correo" : null,
                    ),

                    const SizedBox(height: 15),

                    TextFormField(
                      controller: passwordController,
                      obscureText: ocultarPassword,
                      decoration: InputDecoration(
                        labelText: "Nueva contraseña",
                        border: const OutlineInputBorder(),
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

                    TextFormField(
                      controller: confirmarController,
                      obscureText: ocultarConfirmar,
                      decoration: InputDecoration(
                        labelText: "Confirmar contraseña",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            ocultarConfirmar
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              ocultarConfirmar = !ocultarConfirmar;
                            });
                          },
                        ),
                      ),
                      validator: (v) {
                        if (passwordController.text.isNotEmpty &&
                            v != passwordController.text) {
                          return "Las contraseñas no coinciden";
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 25),

                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: Text(
                          guardando
                              ? "Guardando..."
                              : "Guardar Cambios",
                        ),
                        onPressed: guardando ? null : guardar,
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