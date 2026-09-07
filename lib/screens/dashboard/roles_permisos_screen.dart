import 'package:flutter/material.dart';

import '../../services/roles_permisos_api_service.dart';
import '../../services/sesion.dart';

class RolesPermisosScreen extends StatefulWidget {
  const RolesPermisosScreen({super.key});

  @override
  State<RolesPermisosScreen> createState() =>
      _RolesPermisosScreenState();
}

class _RolesPermisosScreenState extends State<RolesPermisosScreen> {
  static const Color _verde = Color(0xFF087A4A);
  static const Color _verdeClaro = Color(0xFFEAF6EF);
  static const Color _fondo = Color(0xFFF6F8FA);
  static const Color _borde = Color(0xFFDCE4E8);

  final TextEditingController _buscarController =
      TextEditingController();

  List<RolApi> _roles = [];
  List<PermisoRolApi> _permisos = [];

  int? _rolId;

  bool _cargando = true;
  bool _cargandoPermisos = false;
  bool _guardando = false;

  String? _error;

  @override
  void initState() {
    super.initState();

    if (!Sesion.esAdministrador) {
      _cargando = false;
      return;
    }

    _buscarController.addListener(_actualizar);
    _cargar();
  }

  @override
  void dispose() {
    _buscarController.removeListener(_actualizar);
    _buscarController.dispose();
    super.dispose();
  }

  void _actualizar() {
    if (mounted) setState(() {});
  }

  Future<void> _cargar() async {
    if (!Sesion.esAdministrador) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final roles = await RolesPermisosApiService.listarRoles();

      if (!mounted) return;

      setState(() {
        _roles = roles;
        _rolId = roles.isEmpty ? null : roles.first.id;
        _cargando = false;
      });

      if (_rolId != null) {
        await _cargarPermisos(_rolId!);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _cargando = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _cargarPermisos(int rolId) async {
    setState(() {
      _cargandoPermisos = true;
      _error = null;
    });

    try {
      final permisos =
          await RolesPermisosApiService.listarPermisos(rolId);

      if (!mounted) return;

      setState(() {
        _permisos = permisos;
        _cargandoPermisos = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _cargandoPermisos = false;
        _error = e.toString();
      });
    }
  }

  Map<String, List<PermisoRolApi>> _agruparModulos() {
    final filtro = _normalizar(_buscarController.text);

    final resultado = <String, List<PermisoRolApi>>{};

    for (final permiso in _permisos) {
      final texto = _normalizar(
        '${permiso.modulo} ${permiso.nombre} ${permiso.codigo}',
      );

      if (filtro.isNotEmpty && !texto.contains(filtro)) {
        continue;
      }

      final modulo = permiso.modulo.trim().isEmpty
          ? 'OTROS'
          : permiso.modulo.trim();

      resultado.putIfAbsent(modulo, () => []).add(permiso);
    }

    return resultado;
  }

  String _normalizar(String texto) {
    var resultado = texto.trim().toLowerCase();

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
      (origen, destino) =>
          resultado = resultado.replaceAll(origen, destino),
    );

    return resultado.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
  }

  RolApi? get _rolSeleccionado {
    for (final rol in _roles) {
      if (rol.id == _rolId) return rol;
    }

    return null;
  }

  int get _cantidadAsignados {
    return _permisos.where((p) => p.tieneAlgunaAccion).length;
  }

  int get _cantidadPermisos {
    return _permisos.length;
  }

  void _marcarModulo(
    List<PermisoRolApi> permisos,
    bool valor,
  ) {
    for (final permiso in permisos) {
      permiso.puedeVer = valor;
      permiso.puedeCrear = valor;
      permiso.puedeEditar = valor;
      permiso.puedeEliminar = valor;
      permiso.puedeImprimir = valor;
    }

    setState(() {});
  }

  void _marcarTodo(bool valor) {
    for (final permiso in _permisos) {
      permiso.puedeVer = valor;
      permiso.puedeCrear = valor;
      permiso.puedeEditar = valor;
      permiso.puedeEliminar = valor;
      permiso.puedeImprimir = valor;
    }

    setState(() {});
  }

  void _cambiarAccion(
    PermisoRolApi permiso,
    String accion,
    bool valor,
  ) {
    setState(() {
      switch (accion) {
        case 'ver':
          permiso.puedeVer = valor;
          break;
        case 'crear':
          permiso.puedeCrear = valor;
          if (valor) permiso.puedeVer = true;
          break;
        case 'editar':
          permiso.puedeEditar = valor;
          if (valor) permiso.puedeVer = true;
          break;
        case 'eliminar':
          permiso.puedeEliminar = valor;
          if (valor) permiso.puedeVer = true;
          break;
        case 'imprimir':
          permiso.puedeImprimir = valor;
          if (valor) permiso.puedeVer = true;
          break;
      }
    });
  }

  Future<void> _guardar() async {
    final rol = _rolSeleccionado;

    if (rol == null || _guardando) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Guardar permisos',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Se guardarán los permisos configurados para el rol '
            '"${rol.nombre}".\n\n'
            'Permisos con alguna acción: $_cantidadAsignados '
            'de $_cantidadPermisos.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('CANCELAR'),
            ),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.save_outlined),
              label: const Text('GUARDAR'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    setState(() => _guardando = true);

    try {
      await RolesPermisosApiService.guardarPermisos(
        rol.id,
        _permisos,
      );

      if (!mounted) return;

      setState(() => _guardando = false);

      _mensaje(
        'Permisos guardados correctamente para ${rol.nombre}.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _guardando = false);

      _mensaje(
        e.toString(),
        error: true,
      );
    }
  }

  Future<void> _nuevoRol() async {
    final datos = await _formRol();

    if (datos == null) return;

    try {
      await RolesPermisosApiService.crearRol(
        datos.$1,
        datos.$2,
      );

      await _cargar();

      if (mounted) {
        _mensaje('Rol creado correctamente.');
      }
    } catch (e) {
      if (mounted) {
        _mensaje(e.toString(), error: true);
      }
    }
  }

  Future<void> _editarRol() async {
    final rol = _rolSeleccionado;

    if (rol == null) return;

    final datos = await _formRol(rol);

    if (datos == null) return;

    try {
      await RolesPermisosApiService.actualizarRol(
        rol.id,
        datos.$1,
        datos.$2,
        rol.activo,
      );

      await _cargar();

      if (mounted) {
        _mensaje('Rol actualizado correctamente.');
      }
    } catch (e) {
      if (mounted) {
        _mensaje(e.toString(), error: true);
      }
    }
  }

  Future<(String, String)?> _formRol([
    RolApi? rol,
  ]) async {
    final nombreController =
        TextEditingController(text: rol?.nombre ?? '');

    final descripcionController =
        TextEditingController(text: rol?.descripcion ?? '');

    final resultado = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            rol == null ? 'Nuevo rol' : 'Editar rol',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del rol',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: descripcionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    prefixIcon: Icon(Icons.notes_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              child: const Text('CANCELAR'),
            ),
            FilledButton.icon(
              onPressed: () {
                final nombre =
                    nombreController.text.trim();

                if (nombre.isEmpty) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  (
                    nombre,
                    descripcionController.text.trim(),
                  ),
                );
              },
              icon: const Icon(Icons.check),
              label: const Text('GUARDAR'),
            ),
          ],
        );
      },
    );

    nombreController.dispose();
    descripcionController.dispose();

    return resultado;
  }

  void _mensaje(
    String texto, {
    bool error = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          texto.replaceFirst('Exception: ', ''),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            error ? Colors.red.shade700 : _verde,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Sesion.esAdministrador) {
      return Scaffold(
        backgroundColor: _fondo,
        appBar: AppBar(
          title: const Text('Roles y Permisos'),
        ),
        body: const Center(
          child: _AccesoDenegado(),
        ),
      );
    }

    if (_cargando) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null && _roles.isEmpty) {
      return Scaffold(
        body: Center(
          child: _ErrorCarga(
            mensaje: _error!,
            onReintentar: _cargar,
          ),
        ),
      );
    }

    final modulos = _agruparModulos();
    final rol = _rolSeleccionado;

    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172B4D),
        title: const Row(
          children: [
            Icon(
              Icons.admin_panel_settings_outlined,
              color: _verde,
            ),
            SizedBox(width: 10),
            Text(
              'Roles y Permisos',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargandoPermisos
                ? null
                : () {
                    if (_rolId != null) {
                      _cargarPermisos(_rolId!);
                    }
                  },
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final ancho = constraints.maxWidth;

          return SingleChildScrollView(
            padding: EdgeInsets.all(
              ancho < 700 ? 12 : 22,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _encabezado(rol),
                const SizedBox(height: 14),
                _selectorRol(rol),
                const SizedBox(height: 14),
                if (_cargandoPermisos)
                  const LinearProgressIndicator(
                    minHeight: 3,
                  ),
                _barraHerramientas(modulos),
                const SizedBox(height: 12),
                if (modulos.isEmpty)
                  _sinPermisos()
                else
                  ...modulos.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: 10,
                      ),
                      child: _moduloCard(
                        entry.key,
                        entry.value,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                _pieGuardar(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _encabezado(RolApi? rol) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF087A4A),
            Color(0xFF0B8F58),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'ADMINISTRACIÓN DE ACCESOS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rol?.nombre ?? 'Sin rol seleccionado',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (rol?.descripcion != null)
                  Padding(
                    padding:
                        const EdgeInsets.only(top: 4),
                    child: Text(
                      rol!.descripcion!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (rol != null)
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  '${rol.usuarios}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'usuario(s)',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _selectorRol(RolApi? rol) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _borde),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compacto = constraints.maxWidth < 650;

            final selector = DropdownButtonFormField<int>(
              initialValue: _rolId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Rol a configurar',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
              items: _roles.map((r) {
                return DropdownMenuItem<int>(
                  value: r.id,
                  child: Text(
                    r.activo
                        ? r.nombre
                        : '${r.nombre} (Inactivo)',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _cargandoPermisos
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        _rolId = value;
                        _permisos = [];
                      });

                      _cargarPermisos(value);
                    },
            );

            final botones = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _nuevoRol,
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo rol'),
                ),
                OutlinedButton.icon(
                  onPressed: rol == null
                      ? null
                      : _editarRol,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar rol'),
                ),
              ],
            );

            if (compacto) {
              return Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  selector,
                  const SizedBox(height: 12),
                  botones,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: selector),
                const SizedBox(width: 14),
                botones,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _barraHerramientas(
    Map<String, List<PermisoRolApi>> modulos,
  ) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _borde),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          crossAxisAlignment:
              WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                controller: _buscarController,
                decoration: InputDecoration(
                  hintText:
                      'Buscar módulo o permiso...',
                  prefixIcon:
                      const Icon(Icons.search),
                  suffixIcon:
                      _buscarController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _buscarController.clear();
                              },
                              icon: const Icon(
                                Icons.clear,
                              ),
                            ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _permisos.isEmpty
                  ? null
                  : () => _marcarTodo(true),
              icon: const Icon(
                Icons.select_all,
              ),
              label: const Text('Todo'),
            ),
            OutlinedButton.icon(
              onPressed: _permisos.isEmpty
                  ? null
                  : () => _marcarTodo(false),
              icon: const Icon(
                Icons.deselect,
              ),
              label: const Text('Quitar todo'),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: _verdeClaro,
                borderRadius:
                    BorderRadius.circular(8),
              ),
              child: Text(
                '$_cantidadAsignados / $_cantidadPermisos '
                'permisos con acceso',
                style: const TextStyle(
                  color: _verde,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moduloCard(
    String modulo,
    List<PermisoRolApi> permisos,
  ) {
    final todos = permisos.isNotEmpty &&
        permisos.every(
          (p) => p.tieneTodasLasAcciones,
        );

    final alguno = permisos.any(
      (p) => p.tieneAlgunaAccion,
    );

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _borde),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _verdeClaro,
              borderRadius:
                  BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.folder_open_outlined,
              color: _verde,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  modulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              if (alguno)
                const Icon(
                  Icons.check_circle,
                  color: _verde,
                  size: 19,
                ),
            ],
          ),
          subtitle: Text(
            '${permisos.length} permiso(s)',
          ),
          children: [
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                10,
                16,
                8,
              ),
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        _marcarModulo(permisos, true),
                    icon: const Icon(
                      Icons.done_all,
                      size: 18,
                    ),
                    label: const Text(
                      'Dar todo el módulo',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _marcarModulo(permisos, false),
                    icon: const Icon(
                      Icons.remove_done,
                      size: 18,
                    ),
                    label: const Text(
                      'Quitar módulo',
                    ),
                  ),
                  if (todos)
                    const Chip(
                      avatar: Icon(
                        Icons.verified,
                        size: 16,
                      ),
                      label: Text('Acceso completo'),
                    ),
                ],
              ),
            ),
            ...permisos.map(
              (permiso) => _permisoRow(permiso),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permisoRow(PermisoRolApi permiso) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Color(0xFFEEF2F4),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compacto =
              constraints.maxWidth < 760;

          final descripcion = Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                permiso.nombre,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                permiso.codigo,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                ),
              ),
            ],
          );

          final acciones = Wrap(
            alignment: WrapAlignment.end,
            spacing: 3,
            runSpacing: 2,
            children: [
              _accion(
                permiso,
                'VER',
                permiso.puedeVer,
                (v) => _cambiarAccion(
                  permiso,
                  'ver',
                  v,
                ),
              ),
              _accion(
                permiso,
                'CREAR',
                permiso.puedeCrear,
                (v) => _cambiarAccion(
                  permiso,
                  'crear',
                  v,
                ),
              ),
              _accion(
                permiso,
                'EDITAR',
                permiso.puedeEditar,
                (v) => _cambiarAccion(
                  permiso,
                  'editar',
                  v,
                ),
              ),
              _accion(
                permiso,
                'ELIMINAR',
                permiso.puedeEliminar,
                (v) => _cambiarAccion(
                  permiso,
                  'eliminar',
                  v,
                ),
              ),
              _accion(
                permiso,
                'IMPRIMIR',
                permiso.puedeImprimir,
                (v) => _cambiarAccion(
                  permiso,
                  'imprimir',
                  v,
                ),
              ),
            ],
          );

          if (compacto) {
            return Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                descripcion,
                const SizedBox(height: 8),
                acciones,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: descripcion),
              const SizedBox(width: 18),
              acciones,
            ],
          );
        },
      ),
    );
  }

  Widget _accion(
    PermisoRolApi permiso,
    String titulo,
    bool valor,
    ValueChanged<bool> onChanged,
  ) {
    final color = valor
        ? _verde
        : Colors.grey.shade500;

    return Tooltip(
      message: titulo,
      child: FilterChip(
        selected: valor,
        showCheckmark: true,
        label: Text(
          titulo,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        selectedColor:
            _verdeClaro,
        checkmarkColor:
            _verde,
        onSelected: onChanged,
      ),
    );
  }

  Widget _sinPermisos() {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _borde),
      ),
      child: const Padding(
        padding: EdgeInsets.all(30),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.lock_outline,
                size: 42,
                color: Colors.grey,
              ),
              SizedBox(height: 10),
              Text(
                'No hay permisos registrados para este rol.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Los permisos deben existir en el catálogo del sistema.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pieGuardar() {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _borde),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline,
              color: Colors.blueGrey,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Los cambios no se aplican hasta presionar '
                '"Guardar permisos".',
                style: TextStyle(
                  color: Colors.black87,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed:
                  _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.save_outlined,
                    ),
              label: Text(
                _guardando
                    ? 'Guardando...'
                    : 'Guardar permisos',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccesoDenegado extends StatelessWidget {
  const _AccesoDenegado();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(24),
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 54,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 14),
            const Text(
              'Acceso restringido',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Solo el Administrador puede configurar '
              'roles y permisos.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCarga extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;

  const _ErrorCarga({
    required this.mensaje,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red,
          ),
          const SizedBox(height: 12),
          Text(
            mensaje.replaceFirst(
              'Exception: ',
              '',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onReintentar,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
