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
  State<EditarUsuarioPage> createState() =>
      _EditarUsuarioPageState();
}

class _EditarUsuarioPageState extends State<EditarUsuarioPage> {
  final UsuarioService servicio = UsuarioService();

  final _formKey = GlobalKey<FormState>();

  late TextEditingController usuarioController;
  late TextEditingController nombreController;
  late TextEditingController correoController;
  late TextEditingController passwordController;
  late TextEditingController vendedorController;

  late String rol;
  late bool activo;

  bool guardando = false;

  @override
  void initState() {
    super.initState();

    usuarioController = TextEditingController(
      text: widget.usuario.usuario,
    );

    nombreController = TextEditingController(
      text: widget.usuario.nombre,
    );

    correoController = TextEditingController(
      text: widget.usuario.correo,
    );

    passwordController = TextEditingController();

    vendedorController = TextEditingController(
      text: widget.usuario.vendedor,
    );

    rol = widget.usuario.rol;
    activo = widget.usuario.activo;
  }

  @override
  void dispose() {
    usuarioController.dispose();
    nombreController.dispose();
    correoController.dispose();
    passwordController.dispose();
    vendedorController.dispose();

    super.dispose();
  }

  // ============================================================
  // DETERMINAR SI EL ROL NECESITA VENDEDOR
  // ============================================================

  bool get necesitaVendedor {
    return rol == "Comercial";
  }

  // ============================================================
  // GUARDAR
  // ============================================================

  Future<void> guardar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      guardando = true;
    });

    try {
      await servicio.actualizarUsuario(
        widget.usuario.id,
        usuario: usuarioController.text.trim(),
        nombre: nombreController.text.trim(),
        correo: correoController.text.trim(),
        password: passwordController.text.trim(),
        rol: rol,
        vendedor: necesitaVendedor
            ? vendedorController.text.trim()
            : "",
        activo: activo,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Usuario actualizado correctamente",
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error al actualizar usuario: $e",
          ),
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

  // ============================================================
  // DECORACIÓN
  // ============================================================

  InputDecoration decoracion(
    String label,
    IconData icono,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icono),
      border: const OutlineInputBorder(),
    );
  }

  // ============================================================
  // INTERFAZ
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("EDITAR USUARIO"),
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
                    // ==================================================
                    // USUARIO
                    // ==================================================

                    TextFormField(
                      controller: usuarioController,
                      decoration: decoracion(
                        "Usuario",
                        Icons.person,
                      ),
                      validator: (v) {
                        if (v == null ||
                            v.trim().isEmpty) {
                          return "Ingrese el usuario";
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 15),

                    // ==================================================
                    // NOMBRE
                    // ==================================================

                    TextFormField(
                      controller: nombreController,
                      decoration: decoracion(
                        "Nombre",
                        Icons.badge,
                      ),
                      validator: (v) {
                        if (v == null ||
                            v.trim().isEmpty) {
                          return "Ingrese el nombre";
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 15),

                    // ==================================================
                    // CORREO
                    // ==================================================

                    TextFormField(
                      controller: correoController,
                      keyboardType:
                          TextInputType.emailAddress,
                      decoration: decoracion(
                        "Correo",
                        Icons.email,
                      ),
                      validator: (v) {
                        if (v == null ||
                            v.trim().isEmpty) {
                          return "Ingrese el correo";
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 15),

                    // ==================================================
                    // CONTRASEÑA
                    // ==================================================

                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: decoracion(
                        "Nueva contraseña (opcional)",
                        Icons.lock,
                      ),
                    ),

                    const SizedBox(height: 15),

                    // ==================================================
                    // ROL
                    // ==================================================

                    DropdownButtonFormField<String>(
                      initialValue: rol,

                      decoration: decoracion(
                        "Rol",
                        Icons.admin_panel_settings,
                      ),

                      items: const [
                        DropdownMenuItem(
                          value: "Administrador",
                          child: Text(
                            "Administrador",
                          ),
                        ),

                        DropdownMenuItem(
                          value: "Gerencia",
                          child: Text(
                            "Gerencia",
                          ),
                        ),

                        DropdownMenuItem(
                          value: "Jefe Lima",
                          child: Text(
                            "Jefe Lima",
                          ),
                        ),

                        DropdownMenuItem(
                          value: "Jefe Provincia",
                          child: Text(
                            "Jefe Provincia",
                          ),
                        ),

                        DropdownMenuItem(
                          value: "Comercial",
                          child: Text(
                            "Comercial",
                          ),
                        ),

                        DropdownMenuItem(
                          value: "Producción",
                          child: Text(
                            "Producción",
                          ),
                        ),

                        DropdownMenuItem(
                          value: "Logística",
                          child: Text(
                            "Logística",
                          ),
                        ),

                        DropdownMenuItem(
                          value: "Compras",
                          child: Text(
                            "Compras",
                          ),
                        ),

                        DropdownMenuItem(
                          value: "Usuario",
                          child: Text(
                            "Usuario",
                          ),
                        ),
                      ],

                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          rol = value;

                          // Si deja de ser Comercial,
                          // eliminamos el vendedor asociado.
                          if (rol != "Comercial") {
                            vendedorController.clear();
                          }
                        });
                      },
                    ),

                    const SizedBox(height: 15),

                    // ==================================================
                    // VENDEDOR
                    // SOLO PARA COMERCIAL
                    // ==================================================

                    if (necesitaVendedor) ...[
                      TextFormField(
                        controller:
                            vendedorController,

                        decoration: decoracion(
                          "Vendedor",
                          Icons.badge_outlined,
                        ),

                        validator: (v) {
                          if (!necesitaVendedor) {
                            return null;
                          }

                          if (v == null ||
                              v.trim().isEmpty) {
                            return "Ingrese el vendedor";
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 15),
                    ],

                    // ==================================================
                    // INFORMACIÓN JEFE LIMA
                    // ==================================================

                    if (rol == "Jefe Lima")
                      Container(
                        padding:
                            const EdgeInsets.all(12),

                        decoration:
                            BoxDecoration(
                          color: Colors.indigo
                              .withValues(
                            alpha: 0.08,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                        ),

                        child: const Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.indigo,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Jefe Lima podrá visualizar únicamente los usuarios que el administrador le asigne.",
                                style: TextStyle(
                                  color: Colors.indigo,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ==================================================
                    // INFORMACIÓN JEFE PROVINCIA
                    // ==================================================

                    if (rol == "Jefe Provincia")
                      Container(
                        padding:
                            const EdgeInsets.all(12),

                        decoration:
                            BoxDecoration(
                          color: Colors.indigo
                              .withValues(
                            alpha: 0.08,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                        ),

                        child: const Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.indigo,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Jefe Provincia podrá visualizar únicamente los usuarios que el administrador le asigne.",
                                style: TextStyle(
                                  color: Colors.indigo,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ==================================================
                    // INFORMACIÓN GERENCIA
                    // ==================================================

                    if (rol == "Gerencia")
                      Container(
                        padding:
                            const EdgeInsets.all(12),

                        decoration:
                            BoxDecoration(
                          color: Colors.green
                              .withValues(
                            alpha: 0.08,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                        ),

                        child: const Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons
                                  .verified_user_outlined,
                              color: Colors.green,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Gerencia tendrá acceso a toda la información.",
                                style: TextStyle(
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 15),

                    // ==================================================
                    // ESTADO
                    // ==================================================

                    SwitchListTile(
                      title: const Text(
                        "Usuario Activo",
                      ),

                      value: activo,

                      onChanged: (value) {
                        setState(() {
                          activo = value;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // GUARDAR
                    // ==================================================

                    SizedBox(
                      height: 50,

                      child: ElevatedButton.icon(
                        onPressed:
                            guardando
                                ? null
                                : guardar,

                        icon: guardando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color:
                                      Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.save,
                              ),

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