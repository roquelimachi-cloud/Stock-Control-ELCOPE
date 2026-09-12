import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/sesion.dart';
import '../../services/supabase/supabase_service.dart';
import '../dashboard/stock_dashboard_moderno.dart';

class UsuariosAccesosScreen extends StatefulWidget {
  const UsuariosAccesosScreen({super.key});

  @override
  State<UsuariosAccesosScreen> createState() =>
      _UsuariosAccesosScreenState();
}

class _UsuariosAccesosScreenState extends State<UsuariosAccesosScreen> {
  static const Color _verde = Color(0xFF087A4A);
  static const Color _verdeClaro = Color(0xFFEAF6EF);
  static const Color _azul = Color(0xFF2563EB);
  static const Color _fondo = Color(0xFFF6F8FA);
  static const Color _borde = Color(0xFFDCE4E8);

  static const List<Map<String, dynamic>> _modulosBase = [
    {'id': 1, 'codigo': 'dashboard', 'nombre': 'Dashboard', 'activo': true},
    {'id': 2, 'codigo': 'stock', 'nombre': 'Stock', 'activo': true},
    {'id': 3, 'codigo': 'produccion', 'nombre': 'Producción', 'activo': true},
    {'id': 4, 'codigo': 'mis_producciones', 'nombre': 'Mis Producciones', 'activo': true},
    {'id': 5, 'codigo': 'cotizaciones', 'nombre': 'Cotizaciones', 'activo': true},
    {'id': 6, 'codigo': 'clientes', 'nombre': 'Clientes', 'activo': true},
    {'id': 7, 'codigo': 'productos', 'nombre': 'Productos', 'activo': true},
    {'id': 8, 'codigo': 'vendedores', 'nombre': 'Vendedores', 'activo': true},
    {'id': 9, 'codigo': 'almacenes', 'nombre': 'Almacenes', 'activo': true},
    {'id': 10, 'codigo': 'reportes', 'nombre': 'Reportes', 'activo': true},
    {'id': 11, 'codigo': 'usuarios', 'nombre': 'Usuarios', 'activo': true},
    {'id': 12, 'codigo': 'usuarios_accesos', 'nombre': 'Usuarios y Accesos', 'activo': true},
    {'id': 13, 'codigo': 'configuracion', 'nombre': 'Configuración', 'activo': true},
    {'id': 14, 'codigo': 'auditoria', 'nombre': 'Auditoría', 'activo': true},
  ];

  final SupabaseClient _db = SupabaseService.client;

  final TextEditingController _buscarController =
      TextEditingController();

  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _modulos = [];

  int? _usuarioId;

  bool _cargando = true;
  bool _cargandoPermisos = false;
  bool _guardando = false;

  String? _error;

  // ============================================================
  // ADMINISTRADOR
  // ============================================================

  bool get _esAdministrador {
    final rol = Sesion.rol.trim().toLowerCase();

    return Sesion.esAdministrador ||
        rol == 'administrador';
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _buscarController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    _cargarTodo();
  }

  @override
  void dispose() {
    _buscarController.dispose();
    super.dispose();
  }

  // ============================================================
  // CARGAR TODO
  // ============================================================

  Future<void> _cargarTodo() async {
    if (!_esAdministrador) {
      setState(() {
        _cargando = false;
        _error =
            'Solo un Administrador puede administrar los accesos.';
      });

      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      // --------------------------------------------------------
      // USUARIOS
      // --------------------------------------------------------

      final usuariosData = await _db
          .from('usuarios')
          .select()
          .order('nombre');

      // --------------------------------------------------------
      // MÓDULOS
      //
      // IMPORTANTE:
      // La tabla tiene:
      // id
      // codigo
      // nombre
      // activo
      //
      // No usamos columna "orden".
      // --------------------------------------------------------

      final modulosData = await _db
          .from('accesos_modulos')
          .select()
          .order('id');

      final usuarios = (usuariosData as List)
          .whereType<Map>()
          .map(
            (e) => Map<String, dynamic>.from(e),
          )
          .toList();

      final modulos = (modulosData as List)
          .whereType<Map>()
          .map(
            (e) => Map<String, dynamic>.from(e),
          )
          .toList();

      // Solo módulos activos para el menú de configuración.
      final modulosActivos = modulos
          .where((m) => _esActivoModulo(m))
          .toList();

      // Si Supabase devuelve 0 por RLS/política de lectura, no dejamos
      // la pantalla inutilizable: mostramos los 14 módulos configurados.
      // Al guardar, Supabase seguirá siendo la fuente de persistencia.
      final modulosFinales = modulosActivos.isEmpty
          ? _modulosBase
              .map((m) => Map<String, dynamic>.from(m))
              .toList()
          : modulosActivos;

      if (!mounted) return;

      setState(() {
        _usuarios = usuarios;
        _modulos = modulosFinales;
        _cargando = false;

        if (_usuarios.isNotEmpty) {
          _usuarioId = _idUsuario(_usuarios.first);
        } else {
          _usuarioId = null;
        }
      });

      if (_usuarioId != null) {
        await _cargarPermisos(_usuarioId!);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _cargando = false;
        _error = _mensajeError(e);
      });
    }
  }

  // ============================================================
  // CARGAR PERMISOS DEL USUARIO
  // ============================================================

  Future<void> _cargarPermisos(
    int usuarioId,
  ) async {
    setState(() {
      _cargandoPermisos = true;
    });

    try {
      final data = await _db
          .from('accesos_usuario')
          .select()
          .eq('usuario_id', usuarioId);

      final permisos =
          <int, _PermisoModulo>{};

      for (final item in data as List) {
        final fila =
            Map<String, dynamic>.from(item);

        final moduloId =
            _toInt(fila['modulo_id']);

        if (moduloId == null) continue;

        permisos[moduloId] =
            _PermisoModulo(
          ver: _bool(
            fila['puede_ver'],
          ),
          crear: _bool(
            fila['puede_crear'],
          ),
          editar: _bool(
            fila['puede_editar'],
          ),
          eliminar: _bool(
            fila['puede_eliminar'],
          ),
          imprimir: _bool(
            fila['puede_imprimir'],
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        for (final modulo in _modulos) {
          final id = _toInt(modulo['id']);

          if (id == null) continue;

          _permisos[id] =
              permisos[id] ??
                  _PermisoModulo();
        }

        _cargandoPermisos = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _cargandoPermisos = false;
      });

      _mensaje(
        _mensajeError(e),
        error: true,
      );
    }
  }

  // ============================================================
  // PERMISOS EN MEMORIA
  // ============================================================

  final Map<int, _PermisoModulo> _permisos = {};

  _PermisoModulo _permiso(
    int moduloId,
  ) {
    return _permisos.putIfAbsent(
      moduloId,
      () => _PermisoModulo(),
    );
  }

  // ============================================================
  // GUARDAR PERMISOS
  // ============================================================

  Future<void> _guardarPermisos() async {
    final usuarioId = _usuarioId;

    if (usuarioId == null) {
      _mensaje(
        'Selecciona un usuario.',
        error: true,
      );
      return;
    }

    if (_guardando) return;

    final confirmar =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Guardar permisos',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            '¿Deseas guardar la configuración de accesos de este usuario?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'CANCELAR',
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon: const Icon(
                Icons.save,
              ),
              label: const Text(
                'GUARDAR',
              ),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    setState(() {
      _guardando = true;
    });

    try {
      final registros =
          <Map<String, dynamic>>[];

      for (final modulo in _modulos) {
        final moduloId =
            _toInt(modulo['id']);

        if (moduloId == null) continue;

        final permiso =
            _permiso(moduloId);

        registros.add({
          'usuario_id': usuarioId,
          'modulo_id': moduloId,
          'puede_ver': permiso.ver,
          'puede_crear': permiso.crear,
          'puede_editar': permiso.editar,
          'puede_eliminar': permiso.eliminar,
          'puede_imprimir': permiso.imprimir,
        });
      }

      if (registros.isNotEmpty) {
        await _db
            .from('accesos_usuario')
            .upsert(
              registros,
              onConflict:
                  'usuario_id,modulo_id',
            );
      }

      if (!mounted) return;

      _mensaje(
        'Permisos guardados correctamente.',
      );
    } catch (e) {
      if (!mounted) return;

      _mensaje(
        _mensajeError(e),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  // ============================================================
  // SELECCIONAR USUARIO
  // ============================================================

  Future<void> _seleccionarUsuario(
    Map<String, dynamic> usuario,
  ) async {
    final id = _idUsuario(usuario);

    if (id == null) {
      _mensaje(
        'No se pudo determinar el ID del usuario.',
        error: true,
      );
      return;
    }

    setState(() {
      _usuarioId = id;
      _permisos.clear();
    });

    await _cargarPermisos(id);
  }

  // ============================================================
  // ACCIONES
  // ============================================================

  void _cambiarPermiso(
    int moduloId,
    String accion,
    bool valor,
  ) {
    final permiso =
        _permiso(moduloId);

    setState(() {
      switch (accion) {
        case 'ver':
          permiso.ver = valor;

          if (!valor) {
            permiso.crear = false;
            permiso.editar = false;
            permiso.eliminar = false;
            permiso.imprimir = false;
          }

          break;

        case 'crear':
          permiso.crear = valor;

          if (valor) {
            permiso.ver = true;
          }

          break;

        case 'editar':
          permiso.editar = valor;

          if (valor) {
            permiso.ver = true;
          }

          break;

        case 'eliminar':
          permiso.eliminar = valor;

          if (valor) {
            permiso.ver = true;
          }

          break;

        case 'imprimir':
          permiso.imprimir = valor;

          if (valor) {
            permiso.ver = true;
          }

          break;
      }
    });
  }

  // ============================================================
  // TODO
  // ============================================================

  void _darTodo() {
    setState(() {
      for (final modulo in _modulos) {
        final id =
            _toInt(modulo['id']);

        if (id == null) continue;

        final permiso =
            _permiso(id);

        permiso.ver = true;
        permiso.crear = true;
        permiso.editar = true;
        permiso.eliminar = true;
        permiso.imprimir = true;
      }
    });
  }

  // ============================================================
  // SOLO LECTURA
  // ============================================================

  void _soloLectura() {
    setState(() {
      for (final modulo in _modulos) {
        final id =
            _toInt(modulo['id']);

        if (id == null) continue;

        final permiso =
            _permiso(id);

        permiso.ver = true;
        permiso.crear = false;
        permiso.editar = false;
        permiso.eliminar = false;
        permiso.imprimir = false;
      }
    });
  }

  // ============================================================
  // QUITAR TODO
  // ============================================================

  void _quitarTodo() {
    setState(() {
      for (final modulo in _modulos) {
        final id =
            _toInt(modulo['id']);

        if (id == null) continue;

        final permiso =
            _permiso(id);

        permiso.ver = false;
        permiso.crear = false;
        permiso.editar = false;
        permiso.eliminar = false;
        permiso.imprimir = false;
      }
    });
  }

  // ============================================================
  // TODO MÓDULO
  // ============================================================

  void _darTodoModulo(
    int moduloId,
  ) {
    final permiso =
        _permiso(moduloId);

    setState(() {
      permiso.ver = true;
      permiso.crear = true;
      permiso.editar = true;
      permiso.eliminar = true;
      permiso.imprimir = true;
    });
  }

  // ============================================================
  // SOLO LECTURA MÓDULO
  // ============================================================

  void _soloLecturaModulo(
    int moduloId,
  ) {
    final permiso =
        _permiso(moduloId);

    setState(() {
      permiso.ver = true;
      permiso.crear = false;
      permiso.editar = false;
      permiso.eliminar = false;
      permiso.imprimir = false;
    });
  }

  // ============================================================
  // QUITAR MÓDULO
  // ============================================================

  void _quitarModulo(
    int moduloId,
  ) {
    final permiso =
        _permiso(moduloId);

    setState(() {
      permiso.ver = false;
      permiso.crear = false;
      permiso.editar = false;
      permiso.eliminar = false;
      permiso.imprimir = false;
    });
  }

  // ============================================================
  // FILTRO USUARIOS
  // ============================================================

  List<Map<String, dynamic>>
      get _usuariosFiltrados {
    final filtro =
        _normalizar(
      _buscarController.text,
    );

    if (filtro.isEmpty) {
      return _usuarios;
    }

    return _usuarios.where(
      (usuario) {
        final texto = _normalizar(
          [
            _nombreUsuario(usuario),
            _usuarioLogin(usuario),
            _correo(usuario),
            _rol(usuario),
            _vendedor(usuario),
          ].join(' '),
        );

        return texto.contains(filtro);
      },
    ).toList();
  }

  // ============================================================
  // USUARIO SELECCIONADO
  // ============================================================

  Map<String, dynamic>?
      get _usuarioSeleccionado {
    for (final usuario in _usuarios) {
      if (_idUsuario(usuario) ==
          _usuarioId) {
        return usuario;
      }
    }

    return null;
  }

  // ============================================================
  // DATOS USUARIO
  // ============================================================

  int? _idUsuario(
    Map<String, dynamic> usuario,
  ) {
    final valor =
        usuario['id'] ??
            usuario['usuario_id'] ??
            usuario['usuarioId'];

    return _toInt(valor);
  }

  String _nombreUsuario(
    Map<String, dynamic> usuario,
  ) {
    final valor =
        usuario['nombre'] ??
            usuario['nombre_completo'] ??
            usuario['nombreCompleto'];

    if (valor != null &&
        valor.toString().trim().isNotEmpty) {
      return valor.toString().trim();
    }

    return _usuarioLogin(usuario);
  }

  String _usuarioLogin(
    Map<String, dynamic> usuario,
  ) {
    return (
      usuario['usuario'] ??
          usuario['nombre_usuario'] ??
          usuario['nombreUsuario'] ??
          usuario['username'] ??
          ''
    )
        .toString()
        .trim();
  }

  String _correo(
    Map<String, dynamic> usuario,
  ) {
    return (
      usuario['correo'] ??
          usuario['email'] ??
          ''
    )
        .toString()
        .trim();
  }

  String _rol(
    Map<String, dynamic> usuario,
  ) {
    return (
      usuario['rol'] ??
          usuario['rol_nombre'] ??
          usuario['rolNombre'] ??
          ''
    )
        .toString()
        .trim();
  }

  String _vendedor(
    Map<String, dynamic> usuario,
  ) {
    return (
      usuario['vendedor'] ??
          usuario['nombre_vendedor'] ??
          ''
    )
        .toString()
        .trim();
  }

  bool _esActivoUsuario(
    Map<String, dynamic> usuario,
  ) {
    final valor =
        usuario['activo'];

    if (valor is bool) {
      return valor;
    }

    if (valor is num) {
      return valor != 0;
    }

    return valor
            ?.toString()
            .toLowerCase() !=
        'false';
  }

  bool _esActivoModulo(
    Map<String, dynamic> modulo,
  ) {
    final valor =
        modulo['activo'];

    if (valor is bool) {
      return valor;
    }

    if (valor is num) {
      return valor != 0;
    }

    return valor
            ?.toString()
            .toLowerCase() ==
        'true';
  }

  int? _toInt(
    dynamic valor,
  ) {
    if (valor is int) {
      return valor;
    }

    if (valor is num) {
      return valor.toInt();
    }

    return int.tryParse(
      valor?.toString() ?? '',
    );
  }

  bool _bool(
    dynamic valor,
  ) {
    if (valor is bool) {
      return valor;
    }

    if (valor is num) {
      return valor != 0;
    }

    return valor
            ?.toString()
            .toLowerCase() ==
        'true';
  }

  String _normalizar(
    String texto,
  ) {
    var resultado =
        texto.trim().toLowerCase();

    const reemplazos = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };

    reemplazos.forEach(
      (origen, destino) {
        resultado =
            resultado.replaceAll(
          origen,
          destino,
        );
      },
    );

    return resultado.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
  }

  // ============================================================
  // MENSAJE
  // ============================================================

  String _mensajeError(
    Object error,
  ) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        );
  }

  void _mensaje(
    String texto, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(texto),
        behavior:
            SnackBarBehavior.floating,
        backgroundColor: error
            ? Colors.red.shade700
            : _verde,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (!_esAdministrador) {
      return Scaffold(
        backgroundColor: _fondo,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Regresar al Dashboard',
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
          title: const Text(
            'USUARIOS Y ACCESOS',
          ),
        ),
        body: const Center(
          child: _MensajePanel(
            icono:
                Icons.lock_outline,
            titulo:
                'Acceso restringido',
            mensaje:
                'Solo un Administrador puede administrar usuarios y accesos.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _fondo,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            Colors.white,
        foregroundColor:
            Colors.black87,

        leading: IconButton(
          tooltip:
              'Regresar al Dashboard',
          icon: const Icon(
            Icons.arrow_back,
          ),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const DashboardPage(),
              ),
            );
          },
        ),

        title: const Text(
          'USUARIOS Y ACCESOS',
          style: TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),

        actions: [
          IconButton(
            tooltip:
                'Actualizar',
            onPressed:
                _cargando
                    ? null
                    : _cargarTodo,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
        ],
      ),

      body: _cargando
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _error != null
              ? _vistaError()
              : _contenido(),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _vistaError() {
    return Center(
      child: _MensajePanel(
        icono:
            Icons.error_outline,
        titulo:
            'No se pudo cargar',
        mensaje:
            _error ??
                'Ocurrió un error.',
        accion:
            ElevatedButton.icon(
          onPressed:
              _cargarTodo,
          icon: const Icon(
            Icons.refresh,
          ),
          label: const Text(
            'REINTENTAR',
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CONTENIDO
  // ============================================================

  Widget _contenido() {
    final activos =
        _usuarios.where(
      _esActivoUsuario,
    ).length;

    final inactivos =
        _usuarios.length -
            activos;

    return Padding(
      padding:
          const EdgeInsets.all(18),
      child: Column(
        children: [
          // ======================================================
          // KPIs
          // ======================================================

          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  icono:
                      Icons.people,
                  titulo:
                      'USUARIOS',
                  valor:
                      '${_usuarios.length}',
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: _KpiCard(
                  icono:
                      Icons.check_circle,
                  titulo:
                      'ACTIVOS',
                  valor:
                      '$activos',
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: _KpiCard(
                  icono:
                      Icons.block,
                  titulo:
                      'INACTIVOS',
                  valor:
                      '$inactivos',
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: _KpiCard(
                  icono:
                      Icons.apps,
                  titulo:
                      'MÓDULOS',
                  valor:
                      '${_modulos.length}',
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 16,
          ),

          // ======================================================
          // BUSCADOR
          // ======================================================

          Container(
            padding:
                const EdgeInsets.all(12),
            decoration:
                BoxDecoration(
              color:
                  Colors.white,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              border: Border.all(
                color: _borde,
              ),
            ),
            child: TextField(
              controller:
                  _buscarController,
              decoration:
                  InputDecoration(
                hintText:
                    'Buscar usuario, nombre, correo, rol o vendedor...',
                prefixIcon:
                    const Icon(
                  Icons.search,
                ),
                suffixIcon:
                    _buscarController
                            .text
                            .isEmpty
                        ? null
                        : IconButton(
                            onPressed:
                                () {
                              _buscarController
                                  .clear();
                            },
                            icon:
                                const Icon(
                              Icons.clear,
                            ),
                          ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          // ======================================================
          // PRINCIPAL
          // ======================================================

          Expanded(
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
              children: [
                SizedBox(
                  width: 390,
                  child:
                      _panelUsuarios(),
                ),
                const SizedBox(
                  width: 16,
                ),
                Expanded(
                  child:
                      _panelPermisos(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PANEL USUARIOS
  // ============================================================

  Widget _panelUsuarios() {
    return Container(
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color: _borde,
        ),
      ),
      child: Column(
        children: [
          Container(
            width:
                double.infinity,
            padding:
                const EdgeInsets.all(
              16,
            ),
            decoration:
                const BoxDecoration(
              color:
                  _verdeClaro,
              borderRadius:
                  BorderRadius.vertical(
                top:
                    Radius.circular(
                  14,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.people,
                  color: _verde,
                ),
                const SizedBox(
                  width: 10,
                ),
                const Expanded(
                  child: Text(
                    'USUARIOS',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight
                              .w900,
                    ),
                  ),
                ),
                Text(
                  '${_usuariosFiltrados.length}',
                  style:
                      const TextStyle(
                    color: _verde,
                    fontWeight:
                        FontWeight
                            .w900,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child:
                _usuariosFiltrados
                        .isEmpty
                    ? const _MensajePanel(
                        icono:
                            Icons
                                .person_search,
                        titulo:
                            'Sin resultados',
                        mensaje:
                            'No se encontraron usuarios.',
                      )
                    : ListView.separated(
                        padding:
                            const EdgeInsets
                                .all(
                          10,
                        ),
                        itemCount:
                            _usuariosFiltrados
                                .length,
                        separatorBuilder:
                            (_, __) =>
                                const SizedBox(
                          height: 7,
                        ),
                        itemBuilder:
                            (
                          context,
                          index,
                        ) {
                          final usuario =
                              _usuariosFiltrados[
                                  index];

                          return _UsuarioCard(
                            usuario:
                                usuario,
                            seleccionado:
                                _idUsuario(
                                      usuario,
                                    ) ==
                                    _usuarioId,
                            nombre:
                                _nombreUsuario(
                              usuario,
                            ),
                            login:
                                _usuarioLogin(
                              usuario,
                            ),
                            rol:
                                _rol(
                              usuario,
                            ),
                            activo:
                                _esActivoUsuario(
                              usuario,
                            ),
                            onTap:
                                () =>
                                    _seleccionarUsuario(
                              usuario,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PANEL PERMISOS
  // ============================================================

  Widget _panelPermisos() {
    final usuario =
        _usuarioSeleccionado;

    return Container(
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color: _borde,
        ),
      ),
      child: Column(
        children: [
          // ======================================================
          // ENCABEZADO
          // ======================================================

          Container(
            padding:
                const EdgeInsets.all(
              18,
            ),
            decoration:
                const BoxDecoration(
              color:
                  _verdeClaro,
              borderRadius:
                  BorderRadius.vertical(
                top:
                    Radius.circular(
                  14,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons
                      .admin_panel_settings,
                  color:
                      _verde,
                  size: 30,
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      const Text(
                        'PERMISOS DE ACCESO',
                        style:
                            TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        usuario == null
                            ? 'Selecciona un usuario'
                            : '${_nombreUsuario(usuario)}  •  ${_usuarioLogin(usuario)}',
                        style:
                            const TextStyle(
                          color: Colors
                              .black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ======================================================
          // ACCIONES RÁPIDAS
          // ======================================================

          Padding(
            padding:
                const EdgeInsets.all(
              12,
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      usuario == null
                          ? null
                          : _soloLectura,
                  icon:
                      const Icon(
                    Icons.visibility,
                  ),
                  label:
                      const Text(
                    'SOLO LECTURA',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed:
                      usuario == null
                          ? null
                          : _darTodo,
                  icon:
                      const Icon(
                    Icons.done_all,
                  ),
                  label:
                      const Text(
                    'TODO',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed:
                      usuario == null
                          ? null
                          : _quitarTodo,
                  icon:
                      const Icon(
                    Icons.remove_done,
                  ),
                  label:
                      const Text(
                    'QUITAR TODO',
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                FilledButton.icon(
                  onPressed:
                      usuario == null ||
                              _guardando
                          ? null
                          : _guardarPermisos,
                  icon: _guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                          ),
                        )
                      : const Icon(
                          Icons.save,
                        ),
                  label: Text(
                    _guardando
                        ? 'GUARDANDO...'
                        : 'GUARDAR PERMISOS',
                  ),
                ),
              ],
            ),
          ),

          const Divider(
            height: 1,
          ),

          // ======================================================
          // CABECERA DE TABLA
          // ======================================================

          Container(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 18,
              vertical: 12,
            ),
            color:
                const Color(
              0xFFF1F7F4,
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 4,
                  child: Text(
                    'MÓDULO',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight
                              .w900,
                    ),
                  ),
                ),
                _TituloAccion(
                  'VER',
                ),
                _TituloAccion(
                  'CREAR',
                ),
                _TituloAccion(
                  'EDITAR',
                ),
                _TituloAccion(
                  'ELIMINAR',
                ),
                _TituloAccion(
                  'IMPRIMIR',
                ),
                SizedBox(
                  width: 130,
                  child: Text(
                    'RÁPIDO',
                    textAlign:
                        TextAlign
                            .center,
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight
                              .w900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ======================================================
          // LISTA MÓDULOS
          // ======================================================

          Expanded(
            child:
                _cargandoPermisos
                    ? const Center(
                        child:
                            CircularProgressIndicator(),
                      )
                    : _modulos.isEmpty
                        ? const _MensajePanel(
                            icono:
                                Icons.apps,
                            titulo:
                                'No hay módulos',
                            mensaje:
                                'No se encontraron módulos activos.',
                          )
                        : ListView.separated(
                            padding:
                                const EdgeInsets
                                    .all(
                              10,
                            ),
                            itemCount:
                                _modulos
                                    .length,
                            separatorBuilder:
                                (
                              _,
                              __,
                            ) =>
                                    const Divider(
                              height: 1,
                            ),
                            itemBuilder:
                                (
                              context,
                              index,
                            ) {
                              final modulo =
                                  _modulos[
                                      index];

                              final id =
                                  _toInt(
                                modulo[
                                    'id'],
                              );

                              if (id ==
                                  null) {
                                return const SizedBox();
                              }

                              return _FilaModulo(
                                codigo:
                                    modulo[
                                            'codigo']
                                        ?.toString() ??
                                        '',
                                nombre:
                                    modulo[
                                            'nombre']
                                        ?.toString() ??
                                        '',
                                permiso:
                                    _permiso(
                                  id,
                                ),
                                onCambio:
                                    (
                                  accion,
                                  valor,
                                ) {
                                  _cambiarPermiso(
                                    id,
                                    accion,
                                    valor,
                                  );
                                },
                                onTodo:
                                    () =>
                                        _darTodoModulo(
                                  id,
                                ),
                                onLectura:
                                    () =>
                                        _soloLecturaModulo(
                                  id,
                                ),
                                onQuitar:
                                    () =>
                                        _quitarModulo(
                                  id,
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// MODELO PERMISO
// ================================================================

class _PermisoModulo {
  bool ver;
  bool crear;
  bool editar;
  bool eliminar;
  bool imprimir;

  _PermisoModulo({
    this.ver = false,
    this.crear = false,
    this.editar = false,
    this.eliminar = false,
    this.imprimir = false,
  });
}

// ================================================================
// KPI
// ================================================================

class _KpiCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;

  const _KpiCard({
    required this.icono,
    required this.titulo,
    required this.valor,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color:
              const Color(
            0xFFDCE4E8,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFEAF6EF,
              ),
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child: Icon(
              icono,
              color:
                  const Color(
                0xFF087A4A,
              ),
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  titulo,
                  style:
                      const TextStyle(
                    fontSize: 11,
                    color:
                        Colors.black54,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  valor,
                  style:
                      const TextStyle(
                    fontSize: 23,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// USUARIO CARD
// ================================================================

class _UsuarioCard
    extends StatelessWidget {
  final Map<String, dynamic> usuario;
  final bool seleccionado;
  final String nombre;
  final String login;
  final String rol;
  final bool activo;
  final VoidCallback onTap;

  const _UsuarioCard({
    required this.usuario,
    required this.seleccionado,
    required this.nombre,
    required this.login,
    required this.rol,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final invitado =
        rol.trim().toLowerCase() ==
            'invitado';

    return InkWell(
      borderRadius:
          BorderRadius.circular(
        12,
      ),
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.all(
          12,
        ),
        decoration:
            BoxDecoration(
          color: seleccionado
              ? const Color(
                  0xFFEAF6EF,
                )
              : Colors.white,
          borderRadius:
              BorderRadius.circular(
            12,
          ),
          border: Border.all(
            color: seleccionado
                ? const Color(
                    0xFF087A4A,
                  )
                : const Color(
                    0xFFDCE4E8,
                  ),
            width:
                seleccionado
                    ? 1.5
                    : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  invitado
                      ? Colors
                          .orange
                          .shade50
                      : Colors
                          .blue
                          .shade50,
              child: Icon(
                invitado
                    ? Icons
                        .visibility
                    : Icons
                        .person,
                color: invitado
                    ? Colors.orange
                        .shade800
                    : const Color(
                        0xFF2563EB,
                      ),
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    nombre.isEmpty
                        ? login
                        : nombre,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  if (login.isNotEmpty)
                    Text(
                      '@$login',
                      style:
                          const TextStyle(
                        fontSize: 12,
                        color:
                            Colors.black54,
                      ),
                    ),
                  const SizedBox(
                    height: 4,
                  ),
                  Wrap(
                    spacing: 5,
                    children: [
                      if (rol.isNotEmpty)
                        Chip(
                          visualDensity:
                              VisualDensity
                                  .compact,
                          label:
                              Text(
                            rol,
                          ),
                        ),
                      if (!activo)
                        const Chip(
                          visualDensity:
                              VisualDensity
                                  .compact,
                          label:
                              Text(
                            'INACTIVO',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              seleccionado
                  ? Icons
                      .radio_button_checked
                  : Icons
                      .radio_button_off,
              color: seleccionado
                  ? const Color(
                      0xFF087A4A,
                    )
                  : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// TITULO ACCIÓN
// ================================================================

class _TituloAccion
    extends StatelessWidget {
  final String texto;

  const _TituloAccion(
    this.texto,
  );

  @override
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      width: 75,
      child: Text(
        texto,
        textAlign:
            TextAlign.center,
        style:
            const TextStyle(
          fontWeight:
              FontWeight.w900,
        ),
      ),
    );
  }
}

// ================================================================
// FILA MÓDULO
// ================================================================

class _FilaModulo
    extends StatelessWidget {
  final String codigo;
  final String nombre;
  final _PermisoModulo permiso;

  final void Function(
    String accion,
    bool valor,
  ) onCambio;

  final VoidCallback onTodo;
  final VoidCallback onLectura;
  final VoidCallback onQuitar;

  const _FilaModulo({
    required this.codigo,
    required this.nombre,
    required this.permiso,
    required this.onCambio,
    required this.onTodo,
    required this.onLectura,
    required this.onQuitar,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 8,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFFEAF6EF,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      9,
                    ),
                  ),
                  child:
                      const Icon(
                    Icons.apps,
                    color:
                        Color(
                      0xFF087A4A,
                    ),
                    size: 20,
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        nombre,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),
                      if (codigo.isNotEmpty)
                        Text(
                          codigo,
                          style:
                              const TextStyle(
                            fontSize: 11,
                            color:
                                Colors.black45,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          _Check(
            value:
                permiso.ver,
            onChanged:
                (valor) =>
                    onCambio(
              'ver',
              valor,
            ),
          ),

          _Check(
            value:
                permiso.crear,
            onChanged:
                (valor) =>
                    onCambio(
              'crear',
              valor,
            ),
          ),

          _Check(
            value:
                permiso.editar,
            onChanged:
                (valor) =>
                    onCambio(
              'editar',
              valor,
            ),
          ),

          _Check(
            value:
                permiso.eliminar,
            onChanged:
                (valor) =>
                    onCambio(
              'eliminar',
              valor,
            ),
          ),

          _Check(
            value:
                permiso.imprimir,
            onChanged:
                (valor) =>
                    onCambio(
              'imprimir',
              valor,
            ),
          ),

          SizedBox(
            width: 130,
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .center,
              children: [
                IconButton(
                  tooltip:
                      'Todo',
                  onPressed:
                      onTodo,
                  icon:
                      const Icon(
                    Icons
                        .done_all,
                    size: 19,
                  ),
                ),
                IconButton(
                  tooltip:
                      'Solo lectura',
                  onPressed:
                      onLectura,
                  icon:
                      const Icon(
                    Icons
                        .visibility,
                    size: 19,
                  ),
                ),
                IconButton(
                  tooltip:
                      'Quitar',
                  onPressed:
                      onQuitar,
                  icon:
                      const Icon(
                    Icons
                        .remove_done,
                    size: 19,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// CHECKBOX
// ================================================================

class _Check extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>
      onChanged;

  const _Check({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      width: 75,
      child: Center(
        child: Checkbox(
          value: value,
          onChanged:
              (valor) {
            onChanged(
              valor ?? false,
            );
          },
        ),
      ),
    );
  }
}

// ================================================================
// MENSAJE PANEL
// ================================================================

class _MensajePanel
    extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String mensaje;
  final Widget? accion;

  const _MensajePanel({
    required this.icono,
    required this.titulo,
    required this.mensaje,
    this.accion,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 52,
              color:
                  Colors.black38,
            ),
            const SizedBox(
              height: 12,
            ),
            Text(
              titulo,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              mensaje,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    Colors.black54,
              ),
            ),
            if (accion != null) ...[
              const SizedBox(
                height: 16,
              ),
              accion!,
            ],
          ],
        ),
      ),
    );
  }
}