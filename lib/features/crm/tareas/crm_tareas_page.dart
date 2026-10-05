import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../catalogos/crm_catalogos_service.dart';

import '../../../services/sesion.dart';
import '../../../services/supabase/supabase_service.dart';

/// Módulo Tareas del CRM.
///
/// Las tareas comerciales se apoyan en las actividades existentes:
/// una actividad con "fecha_proxima_accion" representa una tarea pendiente.
/// De esta forma no se introduce una tabla/RPC nuevo que no exista en el
/// proyecto actual y se conserva la lógica CRM ya implementada.
class CrmTareasPage extends StatefulWidget {
  const CrmTareasPage({super.key});

  @override
  State<CrmTareasPage> createState() => _CrmTareasPageState();
}

class _CrmTareasPageState extends State<CrmTareasPage> {
  static const _azul = Color(0xFF0B3B63);
  static const _azulClaro = Color(0xFF1468A8);
  static const _verde = Color(0xFF0A9B61);
  static const _fondo = Color(0xFFF4F7FA);

  final _db = SupabaseService.client;
  final _buscar = TextEditingController();
  final _fecha = DateFormat('dd/MM/yyyy');

  bool _cargando = true;
  String? _error;

  List<Map<String, dynamic>> _tareas = [];
  List<Map<String, dynamic>> _clientes = [];
  List<String> _vendedoresPermitidos = [];

  String _vendedor = 'TODOS';
  String _estado = 'TODOS';
  DateTimeRange? _rango;
  String _vista = 'TABLERO';

  bool get _esGerencia => Sesion.rol.trim().toLowerCase() == 'gerencia';

  bool get _esJefatura {
    final rol = Sesion.rol.trim().toLowerCase();
    return rol == 'jefe lima' || rol == 'jefe provincia';
  }

  String get _vendedorActual =>
      Sesion.vendedor.trim().isNotEmpty
          ? Sesion.vendedor.trim()
          : Sesion.nombre.trim();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inicializar();
    });
  }

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  String _s(dynamic v) => v?.toString().trim() ?? '';

  DateTime? _date(dynamic v) {
    final s = _s(v);
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  Future<void> _cargarPermisos() async {
    if (_esGerencia) {
      _vendedoresPermitidos = [];
      return;
    }

    if (_esJefatura) {
      final data = await _db
          .from('usuario_permisos')
          .select('vendedor, ver_produccion')
          .eq('usuario_jefe_id', Sesion.idUsuario)
          .eq('ver_produccion', true);

      final nombres = <String>{};
      for (final row in (data as List)) {
        final nombre = _s(row['vendedor']);
        if (nombre.isNotEmpty) nombres.add(nombre);
      }

      if (_vendedorActual.isNotEmpty) nombres.add(_vendedorActual);
      _vendedoresPermitidos = nombres.toList()..sort();
      return;
    }

    _vendedoresPermitidos =
        _vendedorActual.isEmpty ? [] : [_vendedorActual];
  }

  Future<void> _cargarClientes() async {
    final permitidos =
        _vendedoresPermitidos.isEmpty ? null : _vendedoresPermitidos;

    final data = await _db.rpc(
      'crm_obtener_clientes_pagina_v6',
      params: {
        'p_busqueda': '',
        'p_vendedor': 'TODOS',
        'p_sector': 'TODOS',
        'p_giro': 'TODOS',
        'p_departamento':
            _esJefatura &&
                    Sesion.rol.trim().toLowerCase() == 'jefe lima'
                ? 'LIMA'
                : 'TODOS',
        'p_solo_activos': true,
        'p_limit': 5000,
        'p_offset': 0,
        'p_orden': 'CLIENTE_ASC',
        'p_anio': null,
        'p_vendedores_permitidos': permitidos,
      },
    );

    _clientes = List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> _inicializar() async {
    if (!mounted) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await _cargarPermisos();
      await _cargarTareas();

      if (mounted) setState(() => _cargando = false);

      try {
        await _cargarClientes();
      } catch (e) {
        debugPrint('CRM Tareas - error cargando clientes: $e');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString();
      });
      debugPrint('CRM Tareas - error: $e');
    }
  }

  Future<void> _cargarTareas() async {
    final permitidos =
        _vendedoresPermitidos.isEmpty ? null : _vendedoresPermitidos;

    final desde = _rango?.start.toIso8601String().substring(0, 10);
    final hasta = _rango?.end.toIso8601String().substring(0, 10);

    final data = await _db.rpc(
      'crm_obtener_actividades',
      params: {
        'p_vendedores_permitidos': permitidos,
        'p_tipo': 'TODOS',
        'p_vendedor': _vendedor,
        'p_busqueda': _buscar.text.trim(),
        'p_desde': desde,
        'p_hasta': hasta,
        'p_limit': 1000,
      },
    );

    final actividades = List<Map<String, dynamic>>.from(data as List);

    // Una tarea es una actividad que tiene una próxima acción.
    // También conservamos actividades con resultado abierto para que no
    // desaparezcan del tablero mientras se completa su seguimiento.
    final tareas = actividades.where((a) {
      final proxima = _s(a['fecha_proxima_accion']);
      final resultado = _s(a['resultado']).toLowerCase();

      return proxima.isNotEmpty ||
          resultado.isEmpty ||
          resultado.contains('pendiente') ||
          resultado.contains('en curso');
    }).toList();

    _tareas = _estado == 'TODOS'
        ? tareas
        : tareas.where((t) => _estadoTarea(t) == _estado).toList();
  }

  String _estadoTarea(Map<String, dynamic> t) {
    final resultado = _s(t['resultado']).toLowerCase().trim();
    final fecha = _date(t['fecha_proxima_accion']);

    const cierres = {
      'completada',
      'completado',
      'realizada',
      'realizado',
      'cerrada',
      'cerrado',
      'finalizada',
      'finalizado',
      'cliente confirmó',
      'cliente confirmo',
      'compra confirmada',
      'venta confirmada',
    };

    if (cierres.contains(resultado)) return 'COMPLETADA';

    if (fecha != null) {
      final hoy = DateTime.now();
      final dia = DateTime(hoy.year, hoy.month, hoy.day);
      final limite = DateTime(fecha.year, fecha.month, fecha.day);

      if (limite.isBefore(dia)) return 'VENCIDA';
      if (resultado.contains('en curso')) return 'EN CURSO';
      return 'PENDIENTE';
    }

    if (resultado.contains('en curso')) return 'EN CURSO';
    return 'PENDIENTE';
  }

  int get _pendientes =>
      _tareas.where((t) => _estadoTarea(t) == 'PENDIENTE').length;

  int get _enCurso =>
      _tareas.where((t) => _estadoTarea(t) == 'EN CURSO').length;

  int get _vencidas =>
      _tareas.where((t) => _estadoTarea(t) == 'VENCIDA').length;

  int get _completadas =>
      _tareas.where((t) => _estadoTarea(t) == 'COMPLETADA').length;

  int get _hoy {
    final now = DateTime.now();
    return _tareas.where((t) {
      final d = _date(t['fecha_proxima_accion']);
      return d != null &&
          d.year == now.year &&
          d.month == now.month &&
          d.day == now.day &&
          _estadoTarea(t) != 'COMPLETADA';
    }).length;
  }

  Future<void> _recargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await _cargarTareas();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }

    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _seleccionarRango() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime(2035),
      initialDateRange: _rango,
      locale: const Locale('es'),
    );

    if (rango == null) return;

    setState(() => _rango = rango);
    await _recargar();
  }

  Future<void> _nuevaTarea() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _NuevaTareaDialog(
        db: _db,
        clientes: _clientes,
        vendedores: _vendedoresPermitidos,
        vendedorActual: _vendedorActual,
        usuarioId: Sesion.idUsuario,
      ),
    );

    if (ok == true) await _recargar();
  }

  Future<void> _editarTarea(Map<String, dynamic> tarea) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditarTareaDialog(
        db: _db,
        tarea: tarea,
        vendedores: _vendedoresPermitidos,
      ),
    );

    if (ok == true) await _recargar();
  }

  Future<void> _completarTarea(Map<String, dynamic> tarea) async {
    final id = tarea['id'];
    if (id == null) return;

    try {
      await _db.rpc(
        'crm_actualizar_actividad',
        params: {
          'p_id': id,
          'p_tipo': _s(tarea['tipo']).isEmpty ? 'SEGUIMIENTO' : _s(tarea['tipo']),
          'p_asunto': _s(tarea['asunto']).isEmpty
              ? 'Tarea comercial'
              : _s(tarea['asunto']),
          'p_descripcion': _s(tarea['descripcion']).isEmpty
              ? null
              : _s(tarea['descripcion']),
          'p_resultado': 'COMPLETADA',
          'p_proxima_accion': null,
          'p_fecha_proxima_accion': null,
          'p_vendedor': _s(tarea['vendedor']),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarea marcada como completada.')),
        );
      }
      await _recargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo completar la tarea: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _azul,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Regresar al CRM',
          icon: const Icon(Icons.arrow_back_rounded, size: 30),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        titleSpacing: 4,
        title: const Text(
          'Tareas',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargando ? null : _recargar,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _error != null
            ? _errorView()
            : LayoutBuilder(
                builder: (context, c) {
                  final mobile = c.maxWidth < 900;

                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      mobile ? 14 : 24,
                      20,
                      mobile ? 14 : 24,
                      40,
                    ),
                    children: [
                      _cabecera(mobile),
                      const SizedBox(height: 18),
                      _filtros(mobile),
                      const SizedBox(height: 18),
                      _kpis(),
                      const SizedBox(height: 18),
                      _selectorVista(),
                      const SizedBox(height: 14),
                      if (_cargando)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 80),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_vista == 'TABLERO')
                        _tablero(mobile)
                      else if (_vista == 'LISTA')
                        _lista()
                      else
                        _calendario(),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _cabecera(bool mobile) {
    return Container(
      padding: EdgeInsets.all(mobile ? 20 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_azul, _azulClaro],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _iconoCabecera(),
                const SizedBox(height: 14),
                _textoCabecera(),
                const SizedBox(height: 16),
                _botonNuevaTarea(),
              ],
            )
          : Row(
              children: [
                _iconoCabecera(),
                const SizedBox(width: 15),
                Expanded(child: _textoCabecera()),
                _botonNuevaTarea(),
              ],
            ),
    );
  }

  Widget _iconoCabecera() {
    return Container(
      width: 54,
      height: 54,
      decoration: const BoxDecoration(
        color: Colors.white24,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.task_alt_outlined,
        color: Colors.white,
        size: 29,
      ),
    );
  }

  Widget _textoCabecera() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tareas comerciales',
          style: TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Organiza seguimientos, compromisos y fechas de cumplimiento con tus clientes.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  Widget _botonNuevaTarea() {
    return FilledButton.icon(
      onPressed: _cargando ? null : _nuevaTarea,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Nueva tarea'),
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        foregroundColor: const WidgetStatePropertyAll(_azul),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
      ),
    );
  }

  Widget _filtros(bool mobile) {
    final vendedores = ['TODOS', ..._vendedoresPermitidos];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E6EC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: mobile ? double.infinity : 330,
              child: TextField(
                controller: _buscar,
                onSubmitted: (_) => _recargar(),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Buscar cliente, código, tarea...',
                  filled: true,
                  fillColor: _fondo,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            _dropdown(
              'Asesor',
              _vendedor,
              vendedores.isEmpty ? ['TODOS'] : vendedores,
              (v) {
                setState(() => _vendedor = v ?? 'TODOS');
                _recargar();
              },
            ),
            _dropdown(
              'Estado',
              _estado,
              ['TODOS', 'PENDIENTE', 'EN CURSO', 'VENCIDA', 'COMPLETADA'],
              (v) {
                setState(() => _estado = v ?? 'TODOS');
                _recargar();
              },
            ),
            OutlinedButton.icon(
              onPressed: _seleccionarRango,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(
                _rango == null
                    ? 'Fecha'
                    : '${_fecha.format(_rango!.start)} - ${_fecha.format(_rango!.end)}',
              ),
            ),
            TextButton.icon(
              onPressed: () {
                _buscar.clear();
                setState(() {
                  _vendedor = 'TODOS';
                  _estado = 'TODOS';
                  _rango = null;
                });
                _recargar();
              },
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Limpiar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    final safe = items.contains(value) ? value : items.first;

    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<String>(
        value: safe,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: _fondo,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        items: items.toSet().map(
          (e) => DropdownMenuItem(
            value: e,
            child: Text(e, overflow: TextOverflow.ellipsis),
          ),
        ).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _kpis() {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _kpi(
          Icons.pending_actions_outlined,
          'Pendientes',
          '$_pendientes',
          _azulClaro,
        ),
        _kpi(
          Icons.play_circle_outline,
          'En curso',
          '$_enCurso',
          Colors.orange,
        ),
        _kpi(
          Icons.today_outlined,
          'Para hoy',
          '$_hoy',
          Colors.deepOrange,
        ),
        _kpi(
          Icons.warning_amber_outlined,
          'Vencidas',
          '$_vencidas',
          Colors.redAccent,
        ),
        _kpi(
          Icons.check_circle_outline,
          'Completadas',
          '$_completadas',
          _verde,
        ),
      ],
    );
  }

  Widget _kpi(IconData icon, String label, String value, Color color) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE0E6EC)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey)),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _selectorVista() {
    return Row(
      children: [
        const Icon(Icons.dashboard_customize_outlined, color: _azulClaro),
        const SizedBox(width: 8),
        const Text(
          'Vista',
          style: TextStyle(fontWeight: FontWeight.w900, color: _azul),
        ),
        const SizedBox(width: 12),
        _vistaButton('LISTA', Icons.view_list_outlined, 'Lista'),
        const SizedBox(width: 7),
        _vistaButton('TABLERO', Icons.view_kanban_outlined, 'Tablero'),
        const SizedBox(width: 7),
        _vistaButton('CALENDARIO', Icons.calendar_month_outlined, 'Calendario'),
      ],
    );
  }

  Widget _vistaButton(String value, IconData icon, String label) {
    final selected = _vista == value;

    return OutlinedButton.icon(
      onPressed: () => setState(() => _vista = value),
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? Colors.white : _azul,
        backgroundColor: selected ? _azulClaro : Colors.white,
        side: BorderSide(
          color: selected ? _azulClaro : const Color(0xFFD6E0E8),
        ),
      ),
    );
  }

  Widget _tablero(bool mobile) {
    final columnas = <String, List<Map<String, dynamic>>>{
      'PENDIENTE':
          _tareas.where((t) => _estadoTarea(t) == 'PENDIENTE').toList(),
      'EN CURSO':
          _tareas.where((t) => _estadoTarea(t) == 'EN CURSO').toList(),
      'VENCIDA':
          _tareas.where((t) => _estadoTarea(t) == 'VENCIDA').toList(),
      'COMPLETADA':
          _tareas.where((t) => _estadoTarea(t) == 'COMPLETADA').toList(),
    };

    if (mobile) {
      return Column(
        children: [
          for (final entry in columnas.entries) ...[
            _columnaTablero(entry.key, entry.value),
            const SizedBox(height: 14),
          ],
        ],
      );
    }

    return SizedBox(
      height: 540,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < columnas.entries.length; i++) ...[
            Expanded(
              child: _columnaTablero(
                columnas.entries.elementAt(i).key,
                columnas.entries.elementAt(i).value,
              ),
            ),
            if (i < columnas.length - 1) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }

  Widget _columnaTablero(
    String estado,
    List<Map<String, dynamic>> tareas,
  ) {
    final color = _colorEstado(estado);

    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E6EC)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _nombreEstado(estado),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                CircleAvatar(
                  radius: 13,
                  backgroundColor: color.withValues(alpha: .13),
                  child: Text(
                    '${tareas.length}',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: tareas.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Sin tareas',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: tareas.length,
                    itemBuilder: (_, index) =>
                        _tarjetaTarea(tareas[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaTarea(Map<String, dynamic> t) {
    final estado = _estadoTarea(t);
    final color = _colorEstado(estado);
    final fecha = _date(t['fecha_proxima_accion']);
    final asunto =
        _s(t['proxima_accion']).isNotEmpty
            ? _s(t['proxima_accion'])
            : (_s(t['asunto']).isEmpty ? 'Tarea comercial' : _s(t['asunto']));
    final cliente = _s(t['codigo_cliente']);
    final vendedor = _s(t['vendedor']);

    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () => _editarTarea(t),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFE2E8EE)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 7,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    asunto,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _azul,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  tooltip: 'Acciones',
                  onSelected: (value) {
                    if (value == 'editar') _editarTarea(t);
                    if (value == 'completar') _completarTarea(t);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'editar',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Editar'),
                      ),
                    ),
                    if (estado != 'COMPLETADA')
                      const PopupMenuItem(
                        value: 'completar',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.check_circle_outline),
                          title: Text('Completar'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 9),
            if (cliente.isNotEmpty)
              _miniDato(Icons.business_outlined, cliente),
            if (vendedor.isNotEmpty) ...[
              const SizedBox(height: 5),
              _miniDato(Icons.person_outline, vendedor),
            ],
            if (fecha != null) ...[
              const SizedBox(height: 7),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 15, color: color),
                  const SizedBox(width: 5),
                  Text(
                    _fecha.format(fecha),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _nombreEstado(estado),
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _s(t['tipo']).isEmpty ? 'SEGUIMIENTO' : _s(t['tipo']),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniDato(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _azulClaro),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF52657A),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _lista() {
    if (_tareas.isEmpty) {
      return _vacio();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE0E6EC)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.view_list_rounded, color: _azulClaro),
              const SizedBox(width: 9),
              const Text(
                'Listado de tareas',
                style: TextStyle(
                  color: _azul,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${_tareas.length} registros',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._tareas.map(_filaLista),
        ],
      ),
    );
  }

  Widget _filaLista(Map<String, dynamic> t) {
    final estado = _estadoTarea(t);
    final color = _colorEstado(estado);
    final fecha = _date(t['fecha_proxima_accion']);

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5EBF0)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              _s(t['proxima_accion']).isEmpty
                  ? _s(t['asunto']).isEmpty
                      ? 'Tarea comercial'
                      : _s(t['asunto'])
                  : _s(t['proxima_accion']),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _azul,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            flex: 2,
            child: Text(
              _s(t['codigo_cliente']).isEmpty
                  ? '-'
                  : _s(t['codigo_cliente']),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF52657A)),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            flex: 2,
            child: Text(
              _s(t['vendedor']).isEmpty ? '-' : _s(t['vendedor']),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF52657A)),
            ),
          ),
          const SizedBox(width: 15),
          SizedBox(
            width: 95,
            child: Text(
              fecha == null ? '-' : _fecha.format(fecha),
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Editar',
            onPressed: () => _editarTarea(t),
            icon: const Icon(Icons.edit_outlined),
            color: _azulClaro,
          ),
        ],
      ),
    );
  }

  Widget _calendario() {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final t in _tareas) {
      final d = _date(t['fecha_proxima_accion']);
      if (d == null) continue;
      final key = DateFormat('yyyy-MM-dd').format(d);
      grouped.putIfAbsent(key, () => []).add(t);
    }

    if (grouped.isEmpty) return _vacio();

    final fechas = grouped.keys.toList()..sort();

    return Column(
      children: [
        for (final key in fechas) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E6EC)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined, color: _azulClaro),
                const SizedBox(width: 9),
                Text(
                  _fecha.format(DateTime.parse(key)),
                  style: const TextStyle(
                    color: _azul,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Text(
                  '${grouped[key]!.length} tarea(s)',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          for (final t in grouped[key]!) _filaLista(t),
          const SizedBox(height: 7),
        ],
      ],
    );
  }

  Widget _vacio() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(55),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E6EC)),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, size: 56, color: Color(0xFF9AA8B5)),
          SizedBox(height: 12),
          Text(
            'No hay tareas para mostrar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _azul,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Crea una nueva tarea o cambia los filtros.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'COMPLETADA':
        return _verde;
      case 'VENCIDA':
        return Colors.redAccent;
      case 'EN CURSO':
        return Colors.orange;
      default:
        return _azulClaro;
    }
  }

  String _nombreEstado(String estado) {
    switch (estado) {
      case 'COMPLETADA':
        return 'Completada';
      case 'VENCIDA':
        return 'Vencida';
      case 'EN CURSO':
        return 'En curso';
      default:
        return 'Pendiente';
    }
  }

  Widget _errorView() {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 45),
              const SizedBox(height: 10),
              const Text(
                'No se pudo cargar Tareas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 650,
                child: Text(
                  _error ?? '',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _inicializar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NuevaTareaDialog extends StatefulWidget {
  final dynamic db;
  final List<Map<String, dynamic>> clientes;
  final List<String> vendedores;
  final String vendedorActual;
  final int usuarioId;

  const _NuevaTareaDialog({
    required this.db,
    required this.clientes,
    required this.vendedores,
    required this.vendedorActual,
    required this.usuarioId,
  });

  @override
  State<_NuevaTareaDialog> createState() => _NuevaTareaDialogState();
}

class _NuevaTareaDialogState extends State<_NuevaTareaDialog> {
  static const _azul = Color(0xFF0B3B63);
  final _asunto = TextEditingController();
  final _descripcion = TextEditingController();
  final _proxima = TextEditingController();
  String _cliente = '';
  String _tipo = 'SEGUIMIENTO';
  List<String> _tiposTarea = const ['SEGUIMIENTO'];
  String _vendedor = '';
  DateTime? _fecha;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _vendedor = widget.vendedorActual.isNotEmpty
        ? widget.vendedorActual
        : (widget.vendedores.isNotEmpty ? widget.vendedores.first : '');
    _cargarTiposTarea();
  }

  Future<void> _cargarTiposTarea() async {
    try {
      final tipos = await CrmCatalogosService.obtenerNombres('tipos_tarea');
      if (!mounted || tipos.isEmpty) return;
      setState(() {
        _tiposTarea = tipos;
        if (!_tiposTarea.contains(_tipo)) _tipo = _tiposTarea.first;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _asunto.dispose();
    _descripcion.dispose();
    _proxima.dispose();
    super.dispose();
  }

  String _s(dynamic v) => v?.toString().trim() ?? '';
  String _codigo(Map<String, dynamic> c) {
    for (final key in ['codigo', 'codigo_cliente', 'ruc']) {
      final value = _s(c[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }
  String _nombre(Map<String, dynamic> c) {
    for (final key in ['razon_social', 'nombre', 'cliente']) {
      final value = _s(c[key]);
      if (value.isNotEmpty) return value;
    }
    return 'Cliente sin nombre';
  }
  String _texto(Map<String, dynamic> c) {
    final n = _nombre(c);
    final code = _codigo(c);
    return code.isEmpty ? n : '$n · $code';
  }

  InputDecoration _campo({required String label, required String hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, color: _azul),
      filled: true,
      fillColor: const Color(0xFFF9FBFD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD6E1EC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD6E1EC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _azul, width: 1.5),
      ),
    );
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
      initialDate: _fecha ?? DateTime.now(),
    );
    if (fecha != null && mounted) setState(() => _fecha = fecha);
  }

  Future<void> _guardar() async {
    if (_cliente.isEmpty || _asunto.text.trim().isEmpty || _vendedor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa cliente, asesor y tarea.')),
      );
      return;
    }
    if (_fecha == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la fecha de cumplimiento.')),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      await widget.db.rpc('crm_registrar_actividad', params: {
        'p_codigo_cliente': _cliente,
        'p_tipo': _tipo,
        'p_asunto': _asunto.text.trim(),
        'p_descripcion': _descripcion.text.trim().isEmpty ? null : _descripcion.text.trim(),
        'p_resultado': null,
        'p_proxima_accion': _proxima.text.trim().isEmpty ? _asunto.text.trim() : _proxima.text.trim(),
        'p_fecha_proxima_accion': _fecha!.toIso8601String().substring(0, 10),
        'p_usuario_id': widget.usuarioId,
        'p_vendedor': _vendedor,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar la tarea: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendedores = widget.vendedores.isEmpty
        ? <String>[_vendedor]
        : widget.vendedores.toSet().toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 930, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 18, 18, 18),
              decoration: const BoxDecoration(
                color: _azul,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(13)),
                    child: const Icon(Icons.task_alt_outlined, color: Colors.white, size: 25),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Nueva tarea', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                      SizedBox(height: 3),
                      Text('Define un compromiso comercial y su fecha de cumplimiento.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                  ),
                  IconButton(onPressed: _guardando ? null : () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  children: [
                    Autocomplete<Map<String, dynamic>>(
                      displayStringForOption: _texto,
                      optionsBuilder: (value) {
                        final q = value.text.trim().toLowerCase();
                        if (q.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
                        return widget.clientes.where((c) =>
                          _nombre(c).toLowerCase().contains(q) ||
                          _codigo(c).toLowerCase().contains(q)).take(20);
                      },
                      onSelected: (c) => setState(() => _cliente = _codigo(c)),
                      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          enabled: !_guardando,
                          onChanged: (_) { if (_cliente.isNotEmpty) setState(() => _cliente = ''); },
                          decoration: _campo(label: 'Cliente *', hint: 'Escribe nombre, RUC o código', icon: Icons.business_outlined).copyWith(
                            suffixIcon: const Icon(Icons.search, color: Color(0xFF6C8299)),
                            helperText: _cliente.isEmpty ? 'Busca y selecciona un cliente' : 'Cliente seleccionado',
                            helperStyle: TextStyle(color: _cliente.isEmpty ? const Color(0xFF71869A) : Colors.green),
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        final lista = options.toList();
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 10,
                            borderRadius: BorderRadius.circular(14),
                            clipBehavior: Clip.antiAlias,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 880, maxHeight: 300),
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                shrinkWrap: true,
                                itemCount: lista.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final c = lista[i];
                                  return ListTile(
                                    leading: const CircleAvatar(backgroundColor: Color(0xFFEAF3FA), child: Icon(Icons.business_outlined, color: _azul)),
                                    title: Text(_nombre(c), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                                    subtitle: Text('RUC / Código: ${_codigo(c)}'),
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                                    onTap: () => onSelected(c),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _tiposTarea.contains(_tipo) ? _tipo : (_tiposTarea.isEmpty ? null : _tiposTarea.first),
                      isExpanded: true,
                      decoration: _campo(label: 'Tipo de tarea', hint: 'Selecciona tipo', icon: Icons.task_alt_outlined),
                      items: _tiposTarea.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: _guardando ? null : (v) { if (v != null) setState(() => _tipo = v); },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: vendedores.contains(_vendedor) ? _vendedor : null,
                            isExpanded: true,
                            decoration: _campo(label: 'Asesor *', hint: 'Selecciona asesor', icon: Icons.person_outline),
                            items: vendedores.where((e) => e.isNotEmpty).map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: _guardando ? null : (v) => setState(() => _vendedor = v ?? ''),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: _asunto, enabled: !_guardando, decoration: _campo(label: 'Tarea *', hint: 'Ej. Seguimiento de cotización', icon: Icons.task_outlined))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _proxima, enabled: !_guardando, decoration: _campo(label: 'Acción / compromiso', hint: 'Ej. Enviar propuesta', icon: Icons.next_plan_outlined))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _guardando ? null : _seleccionarFecha,
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: _campo(label: 'Fecha de cumplimiento', hint: '', icon: Icons.calendar_today_outlined),
                              child: Text(_fecha == null ? 'Seleccionar fecha' : DateFormat('dd/MM/yyyy').format(_fecha!),
                                style: TextStyle(color: _fecha == null ? const Color(0xFF71869A) : _azul, fontWeight: _fecha == null ? FontWeight.w400 : FontWeight.w800)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _descripcion, enabled: !_guardando, maxLines: 3, decoration: _campo(label: 'Descripción', hint: 'Detalle del compromiso', icon: Icons.notes_outlined)),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              decoration: const BoxDecoration(color: Color(0xFFF7F9FC), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: _guardando ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                    label: const Text('Guardar tarea'),
                    style: FilledButton.styleFrom(backgroundColor: _azul, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditarTareaDialog extends StatefulWidget {
  final dynamic db;
  final Map<String, dynamic> tarea;
  final List<String> vendedores;

  const _EditarTareaDialog({
    required this.db,
    required this.tarea,
    required this.vendedores,
  });

  @override
  State<_EditarTareaDialog> createState() => _EditarTareaDialogState();
}

class _EditarTareaDialogState extends State<_EditarTareaDialog> {

  InputDecoration _campo({required String label, required String hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
  static const _azul = Color(0xFF0B3B63);

  final _asunto = TextEditingController();
  final _descripcion = TextEditingController();
  final _proxima = TextEditingController();

  String _vendedor = '';
  String _tipo = 'SEGUIMIENTO';
  List<String> _tiposTarea = const ['SEGUIMIENTO'];
  DateTime? _fecha;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();

    final t = widget.tarea;
    _asunto.text = t['asunto']?.toString() ?? '';
    _descripcion.text = t['descripcion']?.toString() ?? '';
    _proxima.text = t['proxima_accion']?.toString() ?? '';
    _vendedor = t['vendedor']?.toString() ?? '';
    _tipo = t['tipo']?.toString().trim().isNotEmpty == true
        ? t['tipo'].toString().trim()
        : 'SEGUIMIENTO';
    _cargarTiposTarea();

    final f = t['fecha_proxima_accion']?.toString() ?? '';
    if (f.isNotEmpty) _fecha = DateTime.tryParse(f);
  }

  Future<void> _cargarTiposTarea() async {
    try {
      final tipos = await CrmCatalogosService.obtenerNombres('tipos_tarea');
      if (!mounted || tipos.isEmpty) return;
      setState(() {
        _tiposTarea = tipos;
        if (!_tiposTarea.contains(_tipo)) _tipo = _tiposTarea.first;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _asunto.dispose();
    _descripcion.dispose();
    _proxima.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vendedores = widget.vendedores.toSet().toList();
    if (_vendedor.isNotEmpty && !vendedores.contains(_vendedor)) {
      vendedores.add(_vendedor);
    }

    return AlertDialog(
      title: const Text(
        'Editar tarea',
        style: TextStyle(fontWeight: FontWeight.w900, color: _azul),
      ),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _tiposTarea.contains(_tipo) ? _tipo : (_tiposTarea.isEmpty ? null : _tiposTarea.first),
                isExpanded: true,
                decoration: _campo(label: 'Tipo de tarea', hint: 'Selecciona tipo', icon: Icons.task_alt_outlined),
                items: _tiposTarea.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: _guardando ? null : (v) { if (v != null) setState(() => _tipo = v); },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: vendedores.contains(_vendedor) ? _vendedor : null,
                decoration: const InputDecoration(labelText: 'Asesor'),
                items: vendedores.map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, overflow: TextOverflow.ellipsis),
                  ),
                ).toList(),
                onChanged:
                    _guardando ? null : (v) => setState(() => _vendedor = v ?? ''),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _asunto,
                enabled: !_guardando,
                decoration: const InputDecoration(labelText: 'Tarea'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _proxima,
                enabled: !_guardando,
                decoration: const InputDecoration(
                  labelText: 'Acción / compromiso',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descripcion,
                enabled: !_guardando,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _fecha == null
                          ? 'Sin fecha'
                          : 'Fecha: ${DateFormat('dd/MM/yyyy').format(_fecha!)}',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _guardando ? null : _seleccionarFecha,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Fecha'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Guardar cambios'),
        ),
      ],
    );
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
      initialDate: _fecha ?? DateTime.now(),
    );

    if (fecha != null && mounted) {
      setState(() => _fecha = fecha);
    }
  }

  Future<void> _guardar() async {
    if (_asunto.text.trim().isEmpty || _vendedor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa asesor y tarea.')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      await widget.db.rpc(
        'crm_actualizar_actividad',
        params: {
          'p_id': widget.tarea['id'],
          'p_tipo': _tipo,
          'p_asunto': _asunto.text.trim(),
          'p_descripcion': _descripcion.text.trim().isEmpty
              ? null
              : _descripcion.text.trim(),
          'p_resultado': null,
          'p_proxima_accion': _proxima.text.trim().isEmpty
              ? _asunto.text.trim()
              : _proxima.text.trim(),
          'p_fecha_proxima_accion':
              _fecha?.toIso8601String().substring(0, 10),
          'p_vendedor': _vendedor,
        },
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $e')),
      );
    }
  }

  String _sTipo(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? 'SEGUIMIENTO' : s;
  }
}