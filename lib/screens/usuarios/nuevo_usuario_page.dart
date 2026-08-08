import 'package:flutter/material.dart';

import '../../services/supabase/usuario_service.dart';
import '../../services/supabase/vendedor_service.dart';

class NuevoUsuarioPage extends StatefulWidget {
  const NuevoUsuarioPage({super.key});

  @override
  State<NuevoUsuarioPage> createState() =>
      _NuevoUsuarioPageState();
}

class _NuevoUsuarioPageState
    extends State<NuevoUsuarioPage> {
  final UsuarioService servicio = UsuarioService();

  final VendedorService vendedorService =
      VendedorService();

  final usuarioController =
      TextEditingController();

  final nombreController =
      TextEditingController();

  final correoController =
      TextEditingController();

  final passwordController =
      TextEditingController();

  List<String> vendedores = [];

  String? vendedorSeleccionado;

  String rol = "Comercial";

  bool guardando = false;

  bool ocultarPassword = true;

  // ============================================================
  // ROLES QUE NO NECESITAN VENDEDOR
  // ============================================================

  bool get esRolSupervisor {
    return rol == "Administrador" ||
        rol == "Gerencia" ||
        rol == "Jefe Lima" ||
        rol == "Jefe Provincia";
  }

  // ============================================================
  // INICIO
  // ============================================================

  @override
  void initState() {
    super.initState();

    cargarVendedores();
  }

  // ============================================================
  // CARGAR VENDEDORES
  // ============================================================

  Future<void> cargarVendedores() async {
    final resultado =
        await vendedorService.obtenerVendedores();

    vendedores = resultado
        .map((e) => e.toString())
        .toList();

    if (!esRolSupervisor &&
        vendedores.isNotEmpty) {
      vendedorSeleccionado =
          vendedores.first;
    }

    if (!mounted) return;

    setState(() {});
  }

  // ============================================================
  // CAMBIAR ROL
  // ============================================================

  void cambiarRol(String nuevoRol) {
    setState(() {
      rol = nuevoRol;

      // Los supervisores no necesitan vendedor.
      if (esRolSupervisor) {
        vendedorSeleccionado = null;
      } else {
        // Si volvemos a un rol comercial,
        // seleccionamos el primer vendedor disponible.
        if (vendedorSeleccionado == null &&
            vendedores.isNotEmpty) {
          vendedorSeleccionado =
              vendedores.first;
        }
      }
    });
  }

  // ============================================================
  // GUARDAR USUARIO
  // ============================================================

  Future<void> guardarUsuario() async {
    final usuario =
        usuarioController.text.trim();

    final nombre =
        nombreController.text.trim();

    final correo =
        correoController.text.trim();

    final password =
        passwordController.text.trim();

    // ----------------------------------------------------------
    // VALIDACIÓN GENERAL
    // ----------------------------------------------------------

    if (usuario.isEmpty ||
        nombre.isEmpty ||
        correo.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Complete todos los campos obligatorios.",
          ),
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // VALIDACIÓN DEL VENDEDOR
    // ----------------------------------------------------------

    if (!esRolSupervisor &&
        vendedorSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Seleccione un vendedor.",
          ),
        ),
      );

      return;
    }

    try {
      setState(() {
        guardando = true;
      });

      await servicio.insertarUsuario(
        usuario: usuario,
        nombre: nombre,
        correo: correo,
        password: password,
        rol: rol,

        // Para Administrador, Gerencia,
        // Jefe Lima y Jefe Provincia
        // guardamos vendedor vacío.
        vendedor:
            vendedorSeleccionado ?? "",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            "Usuario registrado correctamente.",
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Error al registrar usuario: $e",
          ),
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

  InputDecoration deco(
    String texto,
    IconData icono,
  ) {
    return InputDecoration(
      labelText: texto,
      border: const OutlineInputBorder(),
      prefixIcon: Icon(icono),
    );
  }

  // ============================================================
  // LIBERAR CONTROLADORES
  // ============================================================

  @override
  void dispose() {
    usuarioController.dispose();
    nombreController.dispose();
    correoController.dispose();
    passwordController.dispose();

    super.dispose();
  }

  // ============================================================
  // INTERFAZ
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "NUEVO USUARIO",
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: ListView(
          children: [
            // ==================================================
            // USUARIO
            // ==================================================

            TextField(
              controller: usuarioController,
              decoration: deco(
                "Usuario",
                Icons.person,
              ),
            ),

            const SizedBox(height: 15),

            // ==================================================
            // NOMBRE
            // ==================================================

            TextField(
              controller: nombreController,
              decoration: deco(
                "Nombre Completo",
                Icons.badge,
              ),
            ),

            const SizedBox(height: 15),

            // ==================================================
            // CORREO
            // ==================================================

            TextField(
              controller: correoController,
              keyboardType:
                  TextInputType.emailAddress,
              decoration: deco(
                "Correo",
                Icons.email,
              ),
            ),

            const SizedBox(height: 15),

            // ==================================================
            // CONTRASEÑA
            // ==================================================

            TextField(
              controller: passwordController,
              obscureText: ocultarPassword,

              decoration:
                  deco(
                "Contraseña",
                Icons.lock,
              ).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    ocultarPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),

                  onPressed: () {
                    setState(() {
                      ocultarPassword =
                          !ocultarPassword;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 15),

            // ==================================================
            // ROL
            // ==================================================

            DropdownButtonFormField<String>(
              initialValue: rol,

              decoration: deco(
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
              ],

              onChanged: (valor) {
                if (valor == null) return;

                cambiarRol(valor);
              },
            ),

            const SizedBox(height: 15),

            // ==================================================
            // VENDEDOR
            // ==================================================

            if (!esRolSupervisor) ...[
              DropdownButtonFormField<String>(
                initialValue:
                    vendedorSeleccionado,

                decoration: deco(
                  "Vendedor",
                  Icons.badge_outlined,
                ),

                items: vendedores
                    .map(
                      (vendedor) =>
                          DropdownMenuItem<String>(
                        value: vendedor,
                        child: Text(
                          vendedor,
                        ),
                      ),
                    )
                    .toList(),

                onChanged: (valor) {
                  setState(() {
                    vendedorSeleccionado =
                        valor;
                  });
                },
              ),
            ],

            // ==================================================
            // INFORMACIÓN DEL ROL SUPERVISOR
            // ==================================================

            if (esRolSupervisor) ...[
              Container(
                margin:
                    const EdgeInsets.only(
                  top: 5,
                ),

                padding:
                    const EdgeInsets.all(15),

                decoration: BoxDecoration(
                  color: Colors.indigo
                      .withValues(
                    alpha: 0.08,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),

                  border: Border.all(
                    color: Colors.indigo
                        .withValues(
                      alpha: 0.25,
                    ),
                  ),
                ),

                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.indigo,
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        rol == "Administrador"
                            ? "El administrador tendrá acceso completo al sistema."
                            : rol == "Gerencia"
                                ? "Gerencia podrá visualizar la información que corresponda a los usuarios autorizados."
                                : rol == "Jefe Lima"
                                    ? "Jefe Lima podrá visualizar únicamente los usuarios que el administrador le asigne."
                                    : "Jefe Provincia podrá visualizar únicamente los usuarios que el administrador le asigne.",
                        style:
                            const TextStyle(
                          color: Colors.indigo,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 30),

            // ==================================================
            // GUARDAR
            // ==================================================

            SizedBox(
              height: 50,

              child: ElevatedButton.icon(
                onPressed:
                    guardando
                        ? null
                        : guardarUsuario,

                icon: guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.save,
                      ),

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