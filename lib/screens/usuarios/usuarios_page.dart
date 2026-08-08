import 'package:flutter/material.dart';

import '../../models/usuario.dart';
import '../../services/sesion.dart';
import '../../services/supabase/usuario_service.dart';
import '../../services/supabase/vendedor_service.dart';
import 'editar_usuario_page.dart';
import 'nuevo_usuario_page.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  final UsuarioService servicio = UsuarioService();
  final VendedorService vendedorService = VendedorService();

  final TextEditingController buscarController =
      TextEditingController();

  List<Usuario> usuarios = [];
  List<Usuario> filtro = [];

  bool cargando = true;

  // ============================================================
  // INICIO
  // ============================================================

  @override
  void initState() {
    super.initState();

    if (!Sesion.esAdministrador) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "No tiene permisos para acceder a este módulo.",
            ),
          ),
        );

        Navigator.pop(context);
      });

      return;
    }

    cargarUsuarios();
  }

  // ============================================================
  // CARGAR USUARIOS
  // ============================================================

  Future<void> cargarUsuarios() async {
    if (mounted) {
      setState(() {
        cargando = true;
      });
    }

    try {
      final resultado = await servicio.obtenerUsuarios();

      if (!mounted) return;

      setState(() {
        usuarios = resultado;
        filtro = resultado;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        cargando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Error al cargar usuarios: $e",
          ),
        ),
      );
    }
  }

  // ============================================================
  // BUSCAR
  // ============================================================

  void buscar(String texto) {
    final busqueda = texto.toLowerCase().trim();

    setState(() {
      filtro = usuarios.where((u) {
        return u.nombre.toLowerCase().contains(busqueda) ||
            u.usuario.toLowerCase().contains(busqueda) ||
            u.correo.toLowerCase().contains(busqueda) ||
            u.rol.toLowerCase().contains(busqueda);
      }).toList();
    });
  }

  // ============================================================
  // ¿PUEDE CONFIGURAR ACCESO?
  // ============================================================

  bool puedeConfigurarAcceso(Usuario usuario) {
    return usuario.rol == "Jefe Lima" ||
        usuario.rol == "Jefe Provincia";
  }

  // ============================================================
  // CONFIGURAR ACCESO POR VENDEDOR
  // ============================================================

  Future<void> configurarAcceso(
    Usuario usuarioJefe,
  ) async {
    // ----------------------------------------------------------
    // 1. CARGAR VENDEDORES REALES
    // ----------------------------------------------------------

    List<String> vendedores = [];

    try {
      vendedores = await vendedorService.obtenerVendedores();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Error al obtener vendedores: $e",
          ),
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // 2. CARGAR PERMISOS ACTUALES
    // ----------------------------------------------------------

    List<String> permisosActuales = [];

    try {
      permisosActuales =
          await servicio.obtenerVendedoresPermitidos(
        usuarioJefe.id,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Error al obtener permisos: $e",
          ),
        ),
      );

      return;
    }

    if (!mounted) return;

    // ----------------------------------------------------------
    // 3. SELECCIONADOS
    // ----------------------------------------------------------

    final Set<String> seleccionados =
        permisosActuales.toSet();

    // ----------------------------------------------------------
    // 4. MOSTRAR VENTANA
    // ----------------------------------------------------------

    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.indigo,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Configurar acceso",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              content: SizedBox(
                width: 500,
                height: 550,

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    // ==================================================
                    // INFORMACIÓN DEL JEFE
                    // ==================================================

                    Container(
                      width: double.infinity,

                      padding:
                          const EdgeInsets.all(12),

                      decoration:
                          BoxDecoration(
                        color: Colors.indigo.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          Text(
                            usuarioJefe.nombre,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            "Usuario: ${usuarioJefe.usuario}",
                          ),

                          Text(
                            "Rol: ${usuarioJefe.rol}",
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==================================================
                    // TÍTULO
                    // ==================================================

                    const Text(
                      "Vendedores que puede visualizar:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ==================================================
                    // BOTONES SELECCIONAR TODO / QUITAR TODO
                    // ==================================================

                    Row(
                      children: [
                        TextButton.icon(
                          icon: const Icon(
                            Icons.select_all,
                            size: 18,
                          ),
                          label: const Text(
                            "Seleccionar todos",
                          ),
                          onPressed: () {
                            setDialogState(() {
                              seleccionados
                                ..clear()
                                ..addAll(vendedores);
                            });
                          },
                        ),

                        const SizedBox(width: 5),

                        TextButton.icon(
                          icon: const Icon(
                            Icons.deselect,
                            size: 18,
                          ),
                          label: const Text(
                            "Quitar todos",
                          ),
                          onPressed: () {
                            setDialogState(() {
                              seleccionados.clear();
                            });
                          },
                        ),
                      ],
                    ),

                    const Divider(),

                    // ==================================================
                    // LISTA DE VENDEDORES
                    // ==================================================

                    Expanded(
                      child: vendedores.isEmpty
                          ? const Center(
                              child: Text(
                                "No existen vendedores registrados.",
                              ),
                            )
                          : ListView.builder(
                              itemCount:
                                  vendedores.length,

                              itemBuilder:
                                  (
                                context,
                                index,
                              ) {
                                final vendedor =
                                    vendedores[index];

                                final seleccionado =
                                    seleccionados
                                        .contains(
                                  vendedor,
                                );

                                return CheckboxListTile(
                                  dense: true,

                                  value:
                                      seleccionado,

                                  onChanged:
                                      (valor) {
                                    setDialogState(
                                      () {
                                        if (valor ==
                                            true) {
                                          seleccionados
                                              .add(
                                            vendedor,
                                          );
                                        } else {
                                          seleccionados
                                              .remove(
                                            vendedor,
                                          );
                                        }
                                      },
                                    );
                                  },

                                  secondary:
                                      CircleAvatar(
                                    backgroundColor:
                                        Colors.indigo,
                                    radius: 18,
                                    child: Text(
                                      vendedor
                                          .isNotEmpty
                                          ? vendedor
                                              .substring(
                                                0,
                                                1,
                                              )
                                              .toUpperCase()
                                          : "?",
                                      style:
                                          const TextStyle(
                                        color:
                                            Colors.white,
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                                  ),

                                  title: Text(
                                    vendedor,
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    const SizedBox(height: 8),

                    // ==================================================
                    // CONTADOR
                    // ==================================================

                    Container(
                      width: double.infinity,

                      padding:
                          const EdgeInsets.all(10),

                      decoration:
                          BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius:
                            BorderRadius.circular(8),
                      ),

                      child: Text(
                        "${seleccionados.length} vendedor(es) seleccionado(s)",
                        style: const TextStyle(
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ========================================================
              // BOTONES
              // ========================================================

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      false,
                    );
                  },
                  child: const Text(
                    "CANCELAR",
                  ),
                ),

                ElevatedButton.icon(
                  icon: const Icon(
                    Icons.save,
                  ),

                  label: const Text(
                    "GUARDAR ACCESOS",
                  ),

                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      true,
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );

    // ----------------------------------------------------------
    // 5. SI CANCELÓ
    // ----------------------------------------------------------

    if (resultado != true) {
      return;
    }

    // ----------------------------------------------------------
    // 6. GUARDAR EN SUPABASE
    // ----------------------------------------------------------

    try {
      await servicio.guardarPermisosVendedores(
        usuarioJefeId: usuarioJefe.id,
        vendedores: seleccionados.toList(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            "Accesos guardados correctamente.",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Error al guardar accesos: $e",
          ),
        ),
      );
    }
  }

  // ============================================================
  // LIBERAR RECURSOS
  // ============================================================

  @override
  void dispose() {
    buscarController.dispose();
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
          "ADMINISTRACIÓN DE USUARIOS",
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),

      // ==========================================================
      // NUEVO USUARIO
      // ==========================================================

      floatingActionButton:
          Sesion.esAdministrador
              ? FloatingActionButton.extended(
                  icon: const Icon(
                    Icons.person_add,
                  ),
                  label: const Text(
                    "Nuevo Usuario",
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const NuevoUsuarioPage(),
                      ),
                    );

                    if (!mounted) return;

                    await cargarUsuarios();
                  },
                )
              : null,

      // ==========================================================
      // CUERPO
      // ==========================================================

      body: Padding(
        padding: const EdgeInsets.all(15),

        child: Column(
          children: [
            // ======================================================
            // BUSCADOR
            // ======================================================

            TextField(
              controller: buscarController,

              decoration: InputDecoration(
                hintText:
                    "Buscar usuario...",

                prefixIcon:
                    const Icon(
                  Icons.search,
                ),

                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
              ),

              onChanged: buscar,
            ),

            const SizedBox(height: 20),

            // ======================================================
            // LISTA
            // ======================================================

            Expanded(
              child: cargando
                  ? const Center(
                      child:
                          CircularProgressIndicator(),
                    )
                  : filtro.isEmpty
                      ? const Center(
                          child: Text(
                            "No existen usuarios registrados",
                            style:
                                TextStyle(
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount:
                              filtro.length,

                          itemBuilder:
                              (
                            context,
                            index,
                          ) {
                            final usuario =
                                filtro[index];

                            return Card(
                              elevation: 3,

                              margin:
                                  const EdgeInsets
                                      .only(
                                bottom: 10,
                              ),

                              child: ListTile(
                                // ==================================
                                // AVATAR
                                // ==================================

                                leading:
                                    CircleAvatar(
                                  backgroundColor:
                                      usuario.activo
                                          ? Colors
                                              .green
                                          : Colors
                                              .red,

                                  child: Text(
                                    usuario
                                            .nombre
                                            .isNotEmpty
                                        ? usuario
                                            .nombre
                                            .substring(
                                              0,
                                              1,
                                            )
                                            .toUpperCase()
                                        : "?",

                                    style:
                                        const TextStyle(
                                      color:
                                          Colors
                                              .white,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                                ),

                                // ==================================
                                // INFORMACIÓN
                                // ==================================

                                title: Text(
                                  usuario.nombre,
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),

                                subtitle:
                                    Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,

                                  children: [
                                    Text(
                                      "Usuario: ${usuario.usuario}",
                                    ),

                                    Text(
                                      "Correo: ${usuario.correo}",
                                    ),

                                    Text(
                                      "Rol: ${usuario.rol}",
                                    ),

                                    if (usuario
                                            .vendedor
                                            .trim()
                                            .isNotEmpty)
                                      Text(
                                        "Vendedor: ${usuario.vendedor}",
                                      ),
                                  ],
                                ),

                                // ==================================
                                // ACCIONES
                                // ==================================

                                trailing:
                                    Row(
                                  mainAxisSize:
                                      MainAxisSize
                                          .min,

                                  children: [
                                    // ------------------------------
                                    // ESTADO
                                    // ------------------------------

                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment
                                              .center,

                                      children: [
                                        Icon(
                                          usuario
                                                  .activo
                                              ? Icons
                                                  .check_circle
                                              : Icons
                                                  .cancel,

                                          color: usuario
                                                  .activo
                                              ? Colors
                                                  .green
                                              : Colors
                                                  .red,
                                        ),

                                        const SizedBox(
                                          height: 4,
                                        ),

                                        Text(
                                          usuario
                                                  .activo
                                              ? "Activo"
                                              : "Inactivo",

                                          style:
                                              TextStyle(
                                            color: usuario
                                                    .activo
                                                ? Colors
                                                    .green
                                                : Colors
                                                    .red,
                                            fontSize:
                                                12,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(
                                      width: 10,
                                    ),

                                    // ------------------------------
                                    // CONFIGURAR ACCESO
                                    // ------------------------------

                                    if (Sesion
                                            .esAdministrador &&
                                        puedeConfigurarAcceso(
                                          usuario,
                                        ))
                                      IconButton(
                                        tooltip:
                                            "Configurar acceso",

                                        icon:
                                            const Icon(
                                          Icons
                                              .admin_panel_settings,
                                          color: Colors
                                              .deepPurple,
                                          size: 28,
                                        ),

                                        onPressed:
                                            () {
                                          configurarAcceso(
                                            usuario,
                                          );
                                        },
                                      ),

                                    // ------------------------------
                                    // EDITAR
                                    // ------------------------------

                                    if (Sesion
                                        .esAdministrador)
                                      IconButton(
                                        tooltip:
                                            "Editar",

                                        icon:
                                            const Icon(
                                          Icons.edit,
                                          color: Colors
                                              .blue,
                                        ),

                                        onPressed:
                                            () async {
                                          await Navigator
                                              .push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) =>
                                                      EditarUsuarioPage(
                                                usuario:
                                                    usuario,
                                              ),
                                            ),
                                          );

                                          if (!mounted) {
                                            return;
                                          }

                                          await cargarUsuarios();
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}