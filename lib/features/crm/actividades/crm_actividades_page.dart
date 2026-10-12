import 'dart:io';

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/sesion.dart';
import '../../../services/supabase/supabase_service.dart';

class CrmActividadesPage extends StatefulWidget {
  const CrmActividadesPage({super.key, this.clienteInicial});

  /// Cliente preseleccionado al abrir Actividades desde Cliente 360.
  final String? clienteInicial;

  @override
  State<CrmActividadesPage> createState() => _CrmActividadesPageState();
}

class _CrmActividadesPageState extends State<CrmActividadesPage> {
  static const _azul = Color(0xFF0B3B63);
  static const _azulClaro = Color(0xFF12A8FF);
  static const _verde = Color(0xFF20D6A0);
  static const _fondo = Color(0xFF031F33);

  final _db = SupabaseService.client;
  final _buscarController = TextEditingController();
  final _fecha = DateFormat('dd/MM/yyyy');

  bool _cargando = true;
  String? _error;
  List<Map<String, dynamic>> _actividades = [];
  List<String> _vendedoresPermitidos = [];
  List<Map<String, dynamic>> _clientes = [];

  String _tipo = 'TODOS';
  String _vendedor = 'TODOS';
  String _estado = 'TODOS';
  DateTimeRange? _rango;

  bool get _esGerencia => Sesion.rol.trim().toLowerCase() == 'gerencia';
  bool get _esJefatura {
    final rol = Sesion.rol.trim().toLowerCase();
    return rol == 'jefe lima' || rol == 'jefe provincia';
  }
  String get _vendedorActual =>
      Sesion.vendedor.trim().isNotEmpty ? Sesion.vendedor.trim() : Sesion.nombre.trim();

  @override
  void initState() {
    super.initState();
    final inicial = widget.clienteInicial?.trim() ?? '';
    if (inicial.isNotEmpty) {
      _buscarController.text = inicial;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inicializar();
    });
  }

  @override
  void dispose() {
    _buscarController.dispose();
    super.dispose();
  }

  String _s(dynamic value) => value?.toString().trim() ?? '';

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

    _vendedoresPermitidos = _vendedorActual.isEmpty ? [] : [_vendedorActual];
  }

  Future<void> _cargarClientes() async {
    final vendedores = _vendedoresPermitidos.isEmpty ? null : _vendedoresPermitidos;
    final data = await _db.rpc('crm_obtener_clientes_pagina_v6', params: {
      'p_busqueda': '',
      'p_vendedor': 'TODOS',
      'p_sector': 'TODOS',
      'p_giro': 'TODOS',
      'p_departamento': _esJefatura && Sesion.rol.trim().toLowerCase() == 'jefe lima'
          ? 'LIMA'
          : 'TODOS',
      'p_solo_activos': true,
      'p_limit': 5000,
      'p_offset': 0,
      'p_orden': 'CLIENTE_ASC',
      'p_anio': null,
      'p_vendedores_permitidos': vendedores,
    });
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
      await _cargarActividades();
      if (mounted) setState(() => _cargando = false);
      try {
        await _cargarClientes();
      } catch (e) {
        debugPrint('CRM Actividades - error cargando clientes: $e');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString();
      });
      debugPrint('CRM Actividades - error: $e');
    }
  }

  Future<void> _cargarActividades() async {
    final permitidos = _vendedoresPermitidos.isEmpty ? null : _vendedoresPermitidos;
    final desde = _rango?.start.toIso8601String().substring(0, 10);
    final hasta = _rango?.end.toIso8601String().substring(0, 10);

    final data = await _db.rpc('crm_obtener_actividades', params: {
      'p_vendedores_permitidos': permitidos,
      'p_tipo': _tipo,
      'p_vendedor': _vendedor,
      'p_busqueda': _buscarController.text.trim(),
      'p_desde': desde,
      'p_hasta': hasta,
      'p_limit': 500,
    });

    final todas = List<Map<String, dynamic>>.from(data as List);

    // Estado se calcula en Flutter porque no forma parte de la firma del RPC.
    _actividades = _estado == 'TODOS'
        ? todas
        : todas.where((a) => _estadoActividad(a) == _estado).toList();
  }

  String _estadoActividad(Map<String, dynamic> a) {
    final proxima = DateTime.tryParse(_s(a['fecha_proxima_accion']));
    final resultado = _s(a['resultado']).toLowerCase().trim();

    // Una fecha pasada sin un resultado de cierre es VENCIDA.
    if (proxima != null && proxima.isBefore(DateTime.now())) {
      return 'VENCIDA';
    }

    // Solo consideramos COMPLETADA cuando el resultado expresa cierre.
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
    if (proxima != null) return 'PENDIENTE';
    if (resultado.isNotEmpty) return 'REGISTRADA';
    return 'REGISTRADA';
  }

  int get _hoy => _actividades.where((a) {
        final d = DateTime.tryParse(_s(a['fecha']));
        final now = DateTime.now();
        return d != null && d.year == now.year && d.month == now.month && d.day == now.day;
      }).length;

  int get _vencidas => _actividades.where((a) => _estadoActividad(a) == 'VENCIDA').length;
  int get _pendientes => _actividades.where((a) => _estadoActividad(a) == 'PENDIENTE' || _estadoActividad(a) == 'REGISTRADA').length;
  int get _completadas => _actividades.where((a) => _estadoActividad(a) == 'COMPLETADA').length;

  Future<void> _aplicarFiltros() async {
    setState(() => _cargando = true);
    try {
      await _cargarActividades();
      if (mounted) setState(() => _cargando = false);
    } catch (e) {
      if (mounted) setState(() { _cargando = false; _error = e.toString(); });
    }
  }

  Future<void> _editarActividad(Map<String, dynamic> actividad) async {
    final actualizado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditarActividadDialog(
        db: _db,
        actividad: actividad,
        vendedores: _vendedoresPermitidos,
      ),
    );

    if (actualizado == true) {
      await _aplicarFiltros();
    }
  }

  Future<void> _nuevaActividad() async {
    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _NuevaActividadDialog(
        db: _db,
        clientes: _clientes,
        vendedores: _vendedoresPermitidos,
        vendedorActual: _vendedorActual,
        usuarioId: Sesion.idUsuario,
      ),
    );
    if (resultado == true) await _aplicarFiltros();
  }

  Future<void> _exportarExcel() async {
    if (_actividades.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay actividades para exportar con los filtros actuales.')),
      );
      return;
    }
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Actividades'];
      sheet.appendRow([
        TextCellValue('Fecha'), TextCellValue('Tipo'), TextCellValue('Código cliente'),
        TextCellValue('Cliente'), TextCellValue('Asunto'), TextCellValue('Descripción'),
        TextCellValue('Resultado'), TextCellValue('Próxima acción'),
        TextCellValue('Fecha próxima acción'), TextCellValue('Asesor'), TextCellValue('Estado'),
      ]);
      for (final a in _actividades) {
        final nombre = _s(a['razon_social']).isNotEmpty
            ? _s(a['razon_social'])
            : (_s(a['nombre_cliente']).isNotEmpty ? _s(a['nombre_cliente']) : _s(a['codigo_cliente']));
        sheet.appendRow([
          TextCellValue(_fechaTexto(a['fecha'])),
          TextCellValue(_s(a['tipo'])),
          TextCellValue(_s(a['codigo_cliente'])),
          TextCellValue(nombre),
          TextCellValue(_s(a['asunto'])),
          TextCellValue(_s(a['descripcion'])),
          TextCellValue(_s(a['resultado'])),
          TextCellValue(_s(a['proxima_accion'])),
          TextCellValue(_fechaTexto(a['fecha_proxima_accion'])),
          TextCellValue(_s(a['vendedor'])),
          TextCellValue(_estadoActividad(a)),
        ]);
      }
      final bytes = excel.encode();
      if (bytes == null) throw Exception('No se pudo generar el archivo Excel.');
      final ruta = await FilePicker.platform.saveFile(
        dialogTitle: 'Exportar actividades a Excel',
        fileName: 'actividades_crm_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (ruta == null) return;
      final path = ruta.toLowerCase().endsWith('.xlsx') ? ruta : '$ruta.xlsx';
      await File(path).writeAsBytes(bytes, flush: true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel exportado: ${_actividades.length} actividades.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo exportar Excel: $e')),
      );
    }
  }

  void _verDetalleActividad(Map<String, dynamic> a) {
    final nombre = _s(a['razon_social']).isNotEmpty
        ? _s(a['razon_social'])
        : (_s(a['nombre_cliente']).isNotEmpty ? _s(a['nombre_cliente']) : _s(a['codigo_cliente']));
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF062D49),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF12618A))),
        title: const Text('Detalle de actividad', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              _detalleFila('Cliente', nombre),
              _detalleFila('Código cliente', _s(a['codigo_cliente'])),
              _detalleFila('Fecha', _fechaTexto(a['fecha'])),
              _detalleFila('Tipo', _s(a['tipo'])),
              _detalleFila('Asesor', _s(a['vendedor'])),
              _detalleFila('Asunto', _s(a['asunto'])),
              _detalleFila('Descripción', _s(a['descripcion'])),
              _detalleFila('Resultado', _s(a['resultado'])),
              _detalleFila('Próxima acción', _s(a['proxima_accion'])),
              _detalleFila('Fecha próxima acción', _fechaTexto(a['fecha_proxima_accion'])),
              _detalleFila('Estado', _estadoActividad(a)),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          FilledButton.icon(onPressed: () { Navigator.pop(ctx); _editarActividad(a); }, icon: const Icon(Icons.edit_outlined), label: const Text('Editar')),
        ],
      ),
    );
  }

  Widget _detalleFila(String titulo, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 165, child: Text('$titulo:', style: const TextStyle(color: Color(0xFF8FDFFF), fontWeight: FontWeight.w800))),
      Expanded(child: SelectableText(valor.trim().isEmpty ? '—' : valor, style: const TextStyle(color: Colors.white))),
    ]),
  );

  Future<void> _seleccionarRango() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime(2035),
      initialDateRange: _rango,
      locale: const Locale('es'),
    );
    if (rango != null) {
      setState(() => _rango = rango);
      await _aplicarFiltros();
    }
  }

  String _fechaTexto(dynamic value) {
    final d = DateTime.tryParse(_s(value));
    return d == null ? '-' : _fecha.format(d);
  }

  IconData _icono(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'LLAMADA': return Icons.phone_outlined;
      case 'WHATSAPP': return Icons.chat_outlined;
      case 'CORREO': return Icons.email_outlined;
      case 'VISITA': return Icons.location_on_outlined;
      case 'REUNION': return Icons.groups_outlined;
      case 'COBRANZA': return Icons.payments_outlined;
      case 'SEGUIMIENTO': return Icons.follow_the_signs_outlined;
      default: return Icons.task_alt_outlined;
    }
  }

  Color _colorTipo(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'LLAMADA': return _azulClaro;
      case 'WHATSAPP': return Colors.green;
      case 'CORREO': return Colors.indigo;
      case 'VISITA': return Colors.deepPurple;
      case 'REUNION': return Colors.orange;
      case 'COBRANZA': return Colors.redAccent;
      default: return _verde;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _fondo,
        colorScheme: Theme.of(context).colorScheme.copyWith(
          brightness: Brightness.dark,
          surface: const Color(0xFF062D49),
          onSurface: Colors.white,
          primary: const Color(0xFF12A8FF),
          onPrimary: Colors.white,
          secondary: const Color(0xFF20D6A0),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF062D49),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF12A8FF)),
        dividerColor: const Color(0xFF155578),
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Color(0xFFD0E3F0)),
          hintStyle: TextStyle(color: Color(0xFFB8D1E3)),
        ),
      ),
      child: Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B3B63),
        foregroundColor: Colors.white,
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
          'Actividades',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              tooltip: 'Exportar a Excel',
              onPressed: _cargando ? null : _exportarExcel,
              icon: const Icon(Icons.file_download_outlined, color: Color(0xFF20D6A0)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Actualizar',
              onPressed: _cargando ? null : _aplicarFiltros,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _error != null
            ? _errorView()
            : ListView(
                key: const PageStorageKey<String>('crm_actividades_scroll'),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                children: [
                  _topBar(),
                  const SizedBox(height: 18),
                  _filtros(),
                  const SizedBox(height: 18),
                  _kpis(),
                  const SizedBox(height: 18),
                  if (_cargando)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    _lista(),
                ],
              ),
      ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gestiona y da seguimiento a todas tus actividades comerciales con tus clientes.',
                style: TextStyle(fontSize: 16, color: Color(0xFFD0E3F0)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _cargando ? null : _nuevaActividad,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nueva actividad'),
          style: ButtonStyle(
            backgroundColor: const WidgetStatePropertyAll(Color(0xFF1468A8)),
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_azul, _azulClaro]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        const CircleAvatar(radius: 26, backgroundColor: Colors.white24, child: Icon(Icons.event_note_outlined, color: Colors.white, size: 28)),
        const SizedBox(width: 15),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Actividad Comercial', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
          SizedBox(height: 4),
          Text('Registra y controla cada contacto con tus clientes.', style: TextStyle(color: Colors.white70)),
        ])),
        ElevatedButton.icon(
          onPressed: _nuevaActividad,
          icon: const Icon(Icons.add),
          label: const Text('Nueva actividad'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _azul, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
        ),
      ]),
    );
  }

  Widget _filtros() {
    final vendedores = ['TODOS', ..._vendedoresPermitidos];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF12618A))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(width: 320, child: TextField(
              controller: _buscarController,
              onSubmitted: (_) => _aplicarFiltros(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Color(0xFF8FCDF0)),
                hintText: 'Buscar cliente, código, asunto...',
                hintStyle: const TextStyle(color: Color(0xFFB8D1E3)),
                filled: true,
                fillColor: const Color(0xFF0A3A5A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            )),
            _dropdown('Tipo', _tipo, ['TODOS','LLAMADA','WHATSAPP','CORREO','VISITA','REUNION','SEGUIMIENTO','COBRANZA'], (v) { setState(() => _tipo = v!); _aplicarFiltros(); }),
            _dropdown('Vendedor', _vendedor, vendedores.isEmpty ? ['TODOS'] : vendedores, (v) { setState(() => _vendedor = v!); _aplicarFiltros(); }),
            _dropdown('Estado', _estado, ['TODOS','REGISTRADA','PENDIENTE','COMPLETADA','VENCIDA'], (v) { setState(() => _estado = v!); _aplicarFiltros(); }),
            OutlinedButton.icon(onPressed: _seleccionarRango, icon: const Icon(Icons.date_range), label: Text(_rango == null ? 'Fecha' : '${_fecha.format(_rango!.start)} - ${_fecha.format(_rango!.end)}')),
            TextButton.icon(onPressed: () { setState(() { _tipo='TODOS'; _vendedor='TODOS'; _estado='TODOS'; _rango=null; _buscarController.clear(); }); _aplicarFiltros(); }, icon: const Icon(Icons.filter_alt_off), label: const Text('Limpiar')),
          ],
        ),
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    final safe = items.contains(value) ? value : items.first;
    return SizedBox(width: 190, child: DropdownButtonFormField<String>(
      value: safe,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFF0A3A5A),
        labelStyle: const TextStyle(color: Color(0xFFD0E3F0)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF12618A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF12A8FF), width: 1.5),
        ),
      ),
      dropdownColor: const Color(0xFF062D49),
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      items: items.toSet().map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)))).toList(),
      onChanged: onChanged,
    ));
  }

  Widget _kpis() {
    return LayoutBuilder(builder: (context, constraints) {
      final ancho = (constraints.maxWidth - 42) / 4;
      return Wrap(spacing: 14, runSpacing: 14, children: [
        _kpi(Icons.event_note_outlined, 'Pendientes', '$_pendientes', _azulClaro, width: ancho),
        _kpi(Icons.alarm_on_outlined, 'Vencidas', '$_vencidas', const Color(0xFFFF4D6D), width: ancho),
        _kpi(Icons.today_outlined, 'Para hoy', '$_hoy', const Color(0xFF56C8FF), width: ancho),
        _kpi(Icons.task_alt_rounded, 'Completadas', '$_completadas', _verde, width: ancho),
      ]);
    });
  }

  Widget _kpi(IconData icon, String label, String value, Color color, {double? width}) {
    return Container(width: width?.clamp(190, 360) ?? 220, padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: const Color(0xFF062D49), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF12618A))), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: const Color(0xFFB8D1E3))), Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color))]) ]));
  }

  Widget _lista() {
    final fondoPanel = const Color(0xFF062D49);
    final borde = const Color(0xFF12618A);
    if (_actividades.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(42),
        decoration: BoxDecoration(
          color: fondoPanel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borde),
        ),
        child: Column(
          children: [
            const Icon(Icons.event_busy_outlined, size: 48, color: Color(0xFF12A8FF)),
            const SizedBox(height: 12),
            const Text('No hay actividades registradas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 5),
            const Text('Registra una nueva actividad para comenzar el seguimiento.', style: TextStyle(color: Color(0xFFB8D1E3))),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _nuevaActividad, icon: const Icon(Icons.add_rounded), label: const Text('Nueva actividad')),
          ],
        ),
      );
    }

    Widget header(String text, {double width = 130}) => SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Text(text.toUpperCase(), style: const TextStyle(color: Color(0xFFD0E3F0), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .35)),
      ),
    );

    return Container(
      decoration: BoxDecoration(color: fondoPanel, borderRadius: BorderRadius.circular(16), border: Border.all(color: borde)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 15, 18, 12),
            child: Row(children: [
              const Icon(Icons.view_list_rounded, color: _azulClaro, size: 22),
              const SizedBox(width: 9),
              const Expanded(child: Text('Listado de actividades', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: const Color(0xFF0A3A5A), borderRadius: BorderRadius.circular(20)), child: Text('${_actividades.length} registros', style: const TextStyle(color: Color(0xFFB8D1E3), fontSize: 12, fontWeight: FontWeight.w700))),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFF12618A)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1250),
              child: Column(children: [
                Container(
                  color: const Color(0xFF0D4968),
                  child: Row(children: [
                    header('Fecha', width: 112),
                    header('Tipo', width: 145),
                    header('Cliente / asunto', width: 280),
                    header('Próxima acción', width: 220),
                    header('Asesor', width: 180),
                    header('Estado', width: 135),
                    header('Acciones', width: 145),
                  ]),
                ),
                ..._actividades.asMap().entries.map((entry) {
                  final i = entry.key;
                  final a = entry.value;
                  final tipo = _s(a['tipo']).isEmpty ? 'ACTIVIDAD' : _s(a['tipo']);
                  final estado = _estadoActividad(a);
                  final estadoColor = estado == 'VENCIDA' ? const Color(0xFFFF4D6D) : estado == 'COMPLETADA' ? _verde : estado == 'PENDIENTE' ? const Color(0xFFFFB800) : _azulClaro;
                  final nombre = _s(a['razon_social']).isNotEmpty ? _s(a['razon_social']) : (_s(a['nombre_cliente']).isNotEmpty ? _s(a['nombre_cliente']) : _s(a['codigo_cliente']));
                  final asunto = _s(a['asunto']).isEmpty ? 'Seguimiento comercial' : _s(a['asunto']);
                  final proxima = _s(a['proxima_accion']).isNotEmpty ? _s(a['proxima_accion']) : (_s(a['fecha_proxima_accion']).isNotEmpty ? 'Próxima acción: ${_fechaTexto(a['fecha_proxima_accion'])}' : 'Sin próxima acción definida');
                  final vendedor = _s(a['vendedor']).isEmpty ? _vendedorActual : _s(a['vendedor']);
                  final tipoColor = _colorTipo(tipo);
                  return Material(
                    color: i.isEven ? const Color(0xFF062D49) : const Color(0xFF082F4A),
                    child: InkWell(
                      onTap: () => _verDetalleActividad(a),
                      child: Container(
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF12618A), width: .7))),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      SizedBox(width: 112, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), child: Row(children: [
                        Text(_dia(a['fecha']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(width: 7),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_mesCorto(a['fecha']), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFB8D1E3))), Text(_anio(a['fecha']), style: const TextStyle(fontSize: 10, color: Color(0xFFB8D1E3)))]),
                      ]))),
                      SizedBox(width: 145, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7), decoration: BoxDecoration(color: tipoColor.withValues(alpha: .13), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(_icono(tipo), color: tipoColor, size: 16), const SizedBox(width: 6), Flexible(child: Text(tipo, overflow: TextOverflow.ellipsis, style: TextStyle(color: tipoColor, fontWeight: FontWeight.w900, fontSize: 10)))])))),
                      SizedBox(width: 280, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(nombre.isEmpty ? 'Cliente ${_s(a['codigo_cliente'])}' : nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 12)), const SizedBox(height: 4), Text(asunto, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFB8D1E3), fontSize: 11))]))),
                      SizedBox(width: 220, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), child: Text(proxima, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFD0E3F0), fontSize: 11)))),
                      SizedBox(width: 180, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(vendedor, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)), Text(Sesion.rol, style: const TextStyle(color: Color(0xFFB8D1E3), fontSize: 10))]))),
                      SizedBox(width: 135, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), child: Container(alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7), decoration: BoxDecoration(color: estadoColor.withValues(alpha: .18), borderRadius: BorderRadius.circular(20), border: Border.all(color: estadoColor.withValues(alpha: .45))), child: Text(estado, style: TextStyle(color: estadoColor, fontSize: 10, fontWeight: FontWeight.w900))))),
                      SizedBox(width: 145, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _accionIcono(Icons.visibility_outlined, 'Ver detalle', () => _verDetalleActividad(a)),
                        _accionIcono(Icons.edit_outlined, 'Editar actividad', () => _editarActividad(a)),
                        _accionIcono(Icons.more_vert_rounded, 'Más opciones', () => _editarActividad(a)),
                      ]))),
                        ]),
                      ),
                    ),
                  );
                }),
              ]),
            ),
          ),
          const Padding(padding: EdgeInsets.fromLTRB(18, 10, 18, 12), child: Row(children: [Icon(Icons.keyboard_arrow_down_rounded, color: _azulClaro), SizedBox(width: 7), Text('Detalle de actividad · Gestiones · Próxima acción', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))])),
        ],
      ),
    );
  }

  Widget _accionIcono(IconData icono, String tooltip, VoidCallback accion) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Tooltip(message: tooltip, child: InkWell(onTap: accion, borderRadius: BorderRadius.circular(9), child: Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFF0A3A5A), borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xFF12618A))), child: Icon(icono, size: 17, color: const Color(0xFF8FDFFF))))),
    );
  }

  Widget _infoBloque(IconData icon, String label, String value) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 145, maxWidth: 260),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: _azulClaro),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: const Color(0xFFB8D1E3)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _mesCorto(dynamic value) {
    final d = DateTime.tryParse(_s(value));
    if (d == null) return '-';
    const meses = ['ENE','FEB','MAR','ABR','MAY','JUN','JUL','AGO','SEP','OCT','NOV','DIC'];
    return meses[d.month - 1];
  }

  String _dia(dynamic value) {
    final d = DateTime.tryParse(_s(value));
    return d == null ? '-' : d.day.toString();
  }

  String _anio(dynamic value) {
    final d = DateTime.tryParse(_s(value));
    return d == null ? '-' : d.year.toString();
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
                'No se pudo cargar Actividades',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(_error ?? ''),
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

class _EditarActividadDialog extends StatefulWidget {
  final dynamic db;
  final Map<String, dynamic> actividad;
  final List<String> vendedores;

  const _EditarActividadDialog({
    required this.db,
    required this.actividad,
    required this.vendedores,
  });

  @override
  State<_EditarActividadDialog> createState() => _EditarActividadDialogState();
}

class _EditarActividadDialogState extends State<_EditarActividadDialog> {
  static const _azul = Color(0xFF0B3B63);
  final _asunto = TextEditingController();
  final _descripcion = TextEditingController();
  final _resultado = TextEditingController();
  final _proxima = TextEditingController();
  String _tipo = 'LLAMADA';
  String _vendedor = '';
  DateTime? _fechaProxima;
  bool _guardando = false;

  String _s(dynamic v) => v?.toString().trim() ?? '';

  @override
  void initState() {
    super.initState();
    final a = widget.actividad;
    _tipo = _s(a['tipo']).isEmpty ? 'LLAMADA' : _s(a['tipo']);
    _asunto.text = _s(a['asunto']);
    _descripcion.text = _s(a['descripcion']);
    _resultado.text = _s(a['resultado']);
    _proxima.text = _s(a['proxima_accion']);
    _vendedor = _s(a['vendedor']);
    final f = _s(a['fecha_proxima_accion']);
    if (f.isNotEmpty) _fechaProxima = DateTime.tryParse(f);
  }

  @override
  void dispose() {
    _asunto.dispose();
    _descripcion.dispose();
    _resultado.dispose();
    _proxima.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_asunto.text.trim().isEmpty || _vendedor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa vendedor y asunto.')),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      await widget.db.rpc('crm_actualizar_actividad', params: {
        'p_id': widget.actividad['id'],
        'p_tipo': _tipo,
        'p_asunto': _asunto.text.trim(),
        'p_descripcion': _descripcion.text.trim().isEmpty ? null : _descripcion.text.trim(),
        'p_resultado': _resultado.text.trim().isEmpty ? null : _resultado.text.trim(),
        'p_proxima_accion': _proxima.text.trim().isEmpty ? null : _proxima.text.trim(),
        'p_fecha_proxima_accion': _fechaProxima?.toIso8601String().substring(0, 10),
        'p_vendedor': _vendedor,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $e')),
      );
    }
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime(2035),
      initialDate: _fechaProxima ?? DateTime.now(),
    );
    if (fecha != null) setState(() => _fechaProxima = fecha);
  }

  @override
  Widget build(BuildContext context) {
    const panel = Color(0xFF0A3A5A);
    const accent = Color(0xFF12A8FF);
    const muted = Color(0xFFB8D1E3);

    InputDecoration fieldDecoration(String label, {IconData? icon}) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: muted, fontWeight: FontWeight.w500),
        prefixIcon: icon == null ? null : Icon(icon, color: accent, size: 20),
        filled: true,
        fillColor: panel,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF12618A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF12618A)),
        ),
      );
    }

    final vendedores = widget.vendedores.toSet().toList();
    if (_vendedor.isNotEmpty && !vendedores.contains(_vendedor)) vendedores.add(_vendedor);

    return AlertDialog(
      backgroundColor: const Color(0xFF062D49),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF12618A)),
      ),
      title: const Text('Editar actividad', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _tipo,
                dropdownColor: panel,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                decoration: fieldDecoration('Tipo de actividad', icon: Icons.category_outlined),
                items: const ['LLAMADA','WHATSAPP','CORREO','VISITA','REUNION','SEGUIMIENTO','COBRANZA']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: _guardando ? null : (v) => setState(() => _tipo = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: vendedores.contains(_vendedor) ? _vendedor : null,
                dropdownColor: panel,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                decoration: fieldDecoration('Vendedor asignado', icon: Icons.person_outline_rounded),
                items: vendedores.where((e) => e.isNotEmpty).map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: _guardando ? null : (v) => setState(() => _vendedor = v ?? ''),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _asunto,
                enabled: !_guardando,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                decoration: fieldDecoration('Asunto', icon: Icons.short_text_rounded),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descripcion,
                enabled: !_guardando,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: fieldDecoration('Descripción', icon: Icons.notes_rounded),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _resultado,
                enabled: !_guardando,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: fieldDecoration('Resultado', icon: Icons.check_circle_outline_rounded),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _proxima,
                enabled: !_guardando,
                style: const TextStyle(color: Colors.white),
                decoration: fieldDecoration('Próxima acción', icon: Icons.next_plan_outlined),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text(_fechaProxima == null ? 'Sin fecha de próxima acción' : 'Próxima fecha: ${_fechaProxima!.day.toString().padLeft(2, '0')}/${_fechaProxima!.month.toString().padLeft(2, '0')}/${_fechaProxima!.year}')),
                  OutlinedButton.icon(onPressed: _guardando ? null : _seleccionarFecha, icon: const Icon(Icons.calendar_month_outlined), label: const Text('Fecha')),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _guardando ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton.icon(onPressed: _guardando ? null : _guardar, icon: _guardando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: const Text('Guardar cambios')),
      ],
    );
  }
}

class _NuevaActividadDialog extends StatefulWidget {
  final dynamic db;
  final List<Map<String, dynamic>> clientes;
  final List<String> vendedores;
  final String vendedorActual;
  final int usuarioId;

  const _NuevaActividadDialog({required this.db, required this.clientes, required this.vendedores, required this.vendedorActual, required this.usuarioId});

  @override
  State<_NuevaActividadDialog> createState() => _NuevaActividadDialogState();
}

class _NuevaActividadDialogState extends State<_NuevaActividadDialog> {
  static const _azul = Color(0xFF0B3B63);
  final _asunto = TextEditingController();
  final _descripcion = TextEditingController();
  final _resultado = TextEditingController();
  final _proxima = TextEditingController();

  String _tipo = 'LLAMADA';
  String _cliente = '';
  String _vendedor = '';
  String? _asuntoElegido;
  String? _descripcionElegida;
  String? _resultadoElegido;
  String? _proximaElegida;
  DateTime? _fechaProxima;
  bool _guardando = false;
  bool _cargandoCatalogos = true;
  List<String> _catalogoTipos = ['LLAMADA','WHATSAPP','CORREO','VISITA','REUNION','SEGUIMIENTO','COBRANZA'];
  List<String> _catalogoAsuntos = ['Presentación de ELCOPE','Seguimiento de cotización','Consulta técnica de cables','Solicitud de precios','Coordinación de despacho','Seguimiento de factura','Cobranza pendiente','Visita comercial','Reunión con cliente','Renovación de requerimiento','Otro'];
  List<String> _catalogoDescripciones = ['Cliente solicita información comercial','Se envió cotización al cliente','Se revisaron especificaciones técnicas','Se coordinó visita o reunión','Cliente solicita actualización de precios','Se coordinó entrega o despacho','Se revisó estado de pago','Cliente no respondió; requiere seguimiento','Otro'];
  List<String> _catalogoResultados = ['Contacto efectivo','Cotización enviada','Pendiente de respuesta','Requiere información técnica','Reunión coordinada','Pedido confirmado','No contestó','Reprogramar contacto','Sin avance'];
  List<String> _catalogoProximas = ['Llamar para confirmar recepción','Enviar cotización','Enviar ficha técnica','Coordinar visita comercial','Solicitar orden de compra','Confirmar stock y plazo','Realizar seguimiento de pago','Volver a contactar al cliente','No requiere próxima acción'];

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
    _vendedor = widget.vendedorActual.isNotEmpty
        ? widget.vendedorActual
        : (widget.vendedores.isNotEmpty ? widget.vendedores.first : '');
    // Valores iniciales para que el usuario solo tenga que elegir el cliente
    // y ajustar los datos que realmente cambien en esta gestión.
    _asuntoElegido = 'Seguimiento de cotización';
    _descripcionElegida = 'Se envió cotización al cliente';
    _resultadoElegido = 'Pendiente de respuesta';
    _proximaElegida = 'Volver a contactar al cliente';
    _asunto.text = _asuntoElegido!;
    _descripcion.text = _descripcionElegida!;
    _resultado.text = _resultadoElegido!;
    _proxima.text = _proximaElegida!;
    _fechaProxima = DateTime.now().add(const Duration(days: 3));
  }

  Future<void> _cargarCatalogos() async {
    try {
      // Catálogo administrable en Supabase: categoria, valor, activo, orden.
      final data = await widget.db.from('crm_catalogos_actividades')
          .select('categoria,valor,activo,orden')
          .eq('activo', true)
          .order('orden');
      final mapa = <String, List<String>>{};
      for (final row in (data as List)) {
        final categoria = _s(row['categoria']).toUpperCase();
        final valor = _s(row['valor']);
        if (categoria.isNotEmpty && valor.isNotEmpty) {
          (mapa[categoria] ??= <String>[]).add(valor);
        }
      }
      if (mounted) setState(() {
        if ((mapa['TIPO'] ?? []).isNotEmpty) _catalogoTipos = mapa['TIPO']!;
        if ((mapa['ASUNTO'] ?? []).isNotEmpty) _catalogoAsuntos = mapa['ASUNTO']!;
        if ((mapa['DESCRIPCION'] ?? []).isNotEmpty) _catalogoDescripciones = mapa['DESCRIPCION']!;
        if ((mapa['RESULTADO'] ?? []).isNotEmpty) _catalogoResultados = mapa['RESULTADO']!;
        if ((mapa['PROXIMA_ACCION'] ?? []).isNotEmpty) _catalogoProximas = mapa['PROXIMA_ACCION']!;
        _cargandoCatalogos = false;
        if (!_catalogoTipos.contains(_tipo)) _tipo = _catalogoTipos.first;
        if (!_catalogoAsuntos.contains(_asuntoElegido)) _asuntoElegido = _catalogoAsuntos.first;
        if (!_catalogoDescripciones.contains(_descripcionElegida)) _descripcionElegida = _catalogoDescripciones.first;
        if (!_catalogoResultados.contains(_resultadoElegido)) _resultadoElegido = _catalogoResultados.first;
        if (!_catalogoProximas.contains(_proximaElegida)) _proximaElegida = _catalogoProximas.first;
        _asunto.text = _asuntoElegido ?? '';
        _descripcion.text = _descripcionElegida ?? '';
        _resultado.text = _resultadoElegido ?? '';
        _proxima.text = _proximaElegida ?? '';
      });
    } catch (e) {
      // Mantiene el catálogo predeterminado si aún no se creó la tabla en Supabase.
      debugPrint('CRM Actividades - catálogo no disponible: $e');
      if (mounted) setState(() => _cargandoCatalogos = false);
    }
  }

  @override
  void dispose() {
    _asunto.dispose();
    _descripcion.dispose();
    _resultado.dispose();
    _proxima.dispose();
    super.dispose();
  }

  String _s(dynamic v) => v?.toString().trim() ?? '';

  String _codigoCliente(Map<String, dynamic> c) {
    if (_s(c['codigo']).isNotEmpty) return _s(c['codigo']);
    if (_s(c['codigo_cliente']).isNotEmpty) return _s(c['codigo_cliente']);
    if (_s(c['ruc']).isNotEmpty) return _s(c['ruc']);
    return '';
  }

  String _nombreCliente(Map<String, dynamic> c) {
    if (_s(c['razon_social']).isNotEmpty) return _s(c['razon_social']);
    if (_s(c['nombre']).isNotEmpty) return _s(c['nombre']);
    if (_s(c['cliente']).isNotEmpty) return _s(c['cliente']);
    return 'Cliente sin nombre';
  }

  String _nombreClienteSeleccionado() {
    for (final c in widget.clientes) {
      if (_codigoCliente(c) == _cliente) return _nombreCliente(c);
    }
    return _cliente;
  }

  Future<void> _seleccionarCliente() async {
    final seleccionado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => _SelectorClienteDialog(
        db: widget.db,
        clientes: widget.clientes,
        clienteActual: _cliente,
        vendedorActual: widget.vendedorActual,
      ),
    );

    if (seleccionado != null && mounted) {
      final codigo = _codigoCliente(seleccionado);
      if (codigo.isNotEmpty) {
        final vendedorCliente = _s(seleccionado['vendedor']);
        final vendedorDisponible = widget.vendedores.firstWhere(
          (v) => v.trim().toLowerCase() == vendedorCliente.toLowerCase(),
          orElse: () => '',
        );
        setState(() {
          _cliente = codigo;
          if (vendedorDisponible.isNotEmpty) {
            _vendedor = vendedorDisponible;
          }
        });
      }
    }
  }

  String _textoCliente(Map<String, dynamic> c) {
    final nombre = _nombreCliente(c);
    final codigo = _codigoCliente(c);
    return codigo.isEmpty ? nombre : '$nombre · $codigo';
  }

  bool _coincideCliente(Map<String, dynamic> c, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    final nombre = _nombreCliente(c).toLowerCase();
    final codigo = _codigoCliente(c).toLowerCase();

    return nombre.contains(q) || codigo.contains(q);
  }

  Future<void> _guardar() async {
    if (_cliente.isEmpty || _asunto.text.trim().isEmpty || _vendedor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa cliente, vendedor y asunto.')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      await widget.db.rpc('crm_registrar_actividad', params: {
        'p_codigo_cliente': _cliente,
        'p_tipo': _tipo,
        'p_asunto': _asunto.text.trim(),
        'p_descripcion': _descripcion.text.trim().isEmpty
            ? null
            : _descripcion.text.trim(),
        'p_resultado': _resultado.text.trim().isEmpty
            ? null
            : _resultado.text.trim(),
        'p_proxima_accion': _proxima.text.trim().isEmpty
            ? null
            : _proxima.text.trim(),
        'p_fecha_proxima_accion':
            _fechaProxima?.toIso8601String().substring(0, 10),
        'p_usuario_id': widget.usuarioId,
        'p_vendedor': _vendedor,
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar: $e')),
      );
    }
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
      initialDate: _fechaProxima ?? DateTime.now(),
    );

    if (fecha != null && mounted) {
      setState(() => _fechaProxima = fecha);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendedores = widget.vendedores.isEmpty
        ? <String>[_vendedor]
        : widget.vendedores.toSet().toList();

    const navy = Color(0xFF062D49);
    const panel = Color(0xFF0A3A5A);
    const accent = Color(0xFF12A8FF);
    const muted = Color(0xFFB8D1E3);

    InputDecoration fieldDecoration(String label, {IconData? icon}) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: muted, fontWeight: FontWeight.w500),
        prefixIcon: icon == null ? null : Icon(icon, color: accent, size: 20),
        filled: true,
        fillColor: panel,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF12618A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF12618A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      );
    }

    return AlertDialog(
      backgroundColor: navy,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFF12618A)),
      ),
      titlePadding: const EdgeInsets.fromLTRB(26, 24, 26, 12),
      contentPadding: const EdgeInsets.fromLTRB(26, 8, 26, 12),
      actionsPadding: const EdgeInsets.fromLTRB(26, 8, 26, 22),
      title: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.event_available_rounded, color: accent, size: 27),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nueva actividad',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 23,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Registra el seguimiento comercial del cliente',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'DATOS DE LA ACTIVIDAD',
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _tipo,
                dropdownColor: panel,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                decoration: fieldDecoration('Tipo de actividad', icon: Icons.category_outlined),
                items: _catalogoTipos.toSet().toList().map((e) => e)
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, style: const TextStyle(color: Colors.white)),
                      ),
                    )
                    .toList(),
                onChanged:
                    _guardando ? null : (v) => setState(() => _tipo = v!),
              ),
              const SizedBox(height: 14),

              // Cliente dinámico: se selecciona desde un buscador, nunca se escribe manualmente.
              InkWell(
                onTap: _guardando ? null : _seleccionarCliente,
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: fieldDecoration('Cliente *', icon: Icons.business_outlined).copyWith(
                    suffixIcon: _cliente.isEmpty
                        ? const Icon(Icons.search_rounded, color: accent)
                        : IconButton(
                            tooltip: 'Cambiar cliente',
                            icon: const Icon(Icons.edit_outlined, color: accent),
                            onPressed: _guardando ? null : _seleccionarCliente,
                          ),
                    helperText: _cliente.isEmpty
                        ? 'Toca para buscar y escoger un cliente'
                        : '✓ Cliente seleccionado',
                    helperStyle: TextStyle(
                      color: _cliente.isEmpty ? muted : const Color(0xFF20D6A0),
                      fontWeight: _cliente.isEmpty ? FontWeight.normal : FontWeight.w700,
                    ),
                  ),
                  child: Text(
                    _cliente.isEmpty
                        ? 'Buscar y seleccionar cliente'
                        : _nombreClienteSeleccionado(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _cliente.isEmpty ? muted : Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                value: vendedores.contains(_vendedor) ? _vendedor : null,
                dropdownColor: panel,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                decoration: fieldDecoration('Vendedor asignado', icon: Icons.person_outline_rounded),
                items: vendedores
                    .where((e) => e.isNotEmpty)
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, style: const TextStyle(color: Colors.white)),
                      ),
                    )
                    .toList(),
                onChanged:
                    _guardando ? null : (v) => setState(() => _vendedor = v ?? ''),
              ),
              const SizedBox(height: 18),
              const Divider(color: Color(0xFF12618A)),
              const SizedBox(height: 14),
              const Text(
                'DETALLE Y SEGUIMIENTO',
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _asuntoElegido,
                dropdownColor: panel,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                decoration: fieldDecoration('Asunto * · seleccionar evento', icon: Icons.touch_app_outlined),
                items: _catalogoAsuntos.map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(color: Colors.white)),
                )).toList(),
                onChanged: _guardando ? null : (v) => setState(() {
                  _asuntoElegido = v;
                  _asunto.text = v ?? '';
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _descripcionElegida,
                dropdownColor: panel,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                decoration: fieldDecoration('Descripción · seleccionar motivo', icon: Icons.notes_rounded),
                items: _catalogoDescripciones.map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(color: Colors.white)),
                )).toList(),
                onChanged: _guardando ? null : (v) => setState(() {
                  _descripcionElegida = v;
                  _descripcion.text = v ?? '';
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _resultadoElegido,
                dropdownColor: panel,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                decoration: fieldDecoration('Resultado · seleccionar estado', icon: Icons.check_circle_outline_rounded),
                items: _catalogoResultados.map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(color: Colors.white)),
                )).toList(),
                onChanged: _guardando ? null : (v) => setState(() {
                  _resultadoElegido = v;
                  _resultado.text = v ?? '';
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _proximaElegida,
                dropdownColor: panel,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                decoration: fieldDecoration('Próxima acción · seleccionar tarea', icon: Icons.next_plan_outlined),
                items: _catalogoProximas.map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(color: Colors.white)),
                )).toList(),
                onChanged: _guardando ? null : (v) => setState(() {
                  _proximaElegida = v;
                  _proxima.text = v ?? '';
                }),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF12618A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _fechaProxima == null
                            ? 'Sin fecha de próxima acción'
                            : 'Próxima acción: ${DateFormat('dd/MM/yyyy').format(_fechaProxima!)}',
                        style: const TextStyle(color: muted),
                      ),
                    ),
                    TextButton(
                      onPressed: _guardando ? null : _seleccionarFecha,
                      child: const Text('Elegir fecha'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          style: OutlinedButton.styleFrom(
            foregroundColor: muted,
            side: const BorderSide(color: Color(0xFF39718F)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          child: const Text('Cancelar'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(_guardando ? 'Guardando...' : 'Guardar actividad'),
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF39718F),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
        ),
      ],
    );
  }
}


class _SelectorClienteDialog extends StatefulWidget {
  final dynamic db;
  final List<Map<String, dynamic>> clientes;
  final String clienteActual;
  final String vendedorActual;

  const _SelectorClienteDialog({
    required this.db,
    required this.clientes,
    required this.clienteActual,
    required this.vendedorActual,
  });

  @override
  State<_SelectorClienteDialog> createState() => _SelectorClienteDialogState();
}

class _SelectorClienteDialogState extends State<_SelectorClienteDialog> {
  final _buscar = TextEditingController();
  List<Map<String, dynamic>> _resultados = [];
  bool _buscando = false;
  bool _busquedaRealizada = false;
  String? _errorBusqueda;

  String _s(dynamic value) => value?.toString().trim() ?? '';

  Future<void> _buscarClientes(String valor) async {
    final q = valor.trim();
    if (q.isEmpty) {
      if (mounted) setState(() {
        _resultados = [];
        _buscando = false;
        _busquedaRealizada = false;
        _errorBusqueda = null;
      });
      return;
    }
    setState(() {
      _buscando = true;
      _busquedaRealizada = true;
      _errorBusqueda = null;
    });
    try {
      // Consultar Supabase al escribir, sin depender de la lista limitada/cargada
      // previamente por la pantalla de Actividades.
      final data = await widget.db
          .from('clientes')
          .select('id,codigo,nombre,razon_social,ruc,vendedor,codigo_vendedor,direccion,localidad,departamento,giro,sector,activo,estado_comercial')
          .or('razon_social.ilike.%$q%,nombre.ilike.%$q%,ruc.ilike.%$q%,codigo.ilike.%$q%')
          .order('razon_social')
          .limit(80);
      if (!mounted || _buscar.text.trim() != q) return;
      setState(() {
        _resultados = List<Map<String, dynamic>>.from(data as List);
        _buscando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _buscando = false;
        _errorBusqueda = 'No se pudo consultar clientes: $e';
        // Fallback local por si la consulta remota falla.
        _resultados = widget.clientes.where((c) =>
          _nombre(c).toLowerCase().contains(q.toLowerCase()) ||
          _codigo(c).toLowerCase().contains(q.toLowerCase())
        ).take(80).toList();
      });
    }
  }

  Future<void> _registrarNuevoCliente() async {
    final creado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _NuevoClienteActividadDialog(
        db: widget.db,
        busquedaInicial: _buscar.text.trim(),
        vendedor: widget.vendedorActual,
      ),
    );
    if (creado != null && mounted) Navigator.pop(context, creado);
  }

  String _codigo(Map<String, dynamic> c) {
    for (final key in ['codigo', 'codigo_cliente', 'ruc']) {
      final v = _s(c[key]);
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  String _nombre(Map<String, dynamic> c) {
    for (final key in ['razon_social', 'nombre', 'cliente']) {
      final v = _s(c[key]);
      if (v.isNotEmpty) return v;
    }
    return 'Cliente sin nombre';
  }

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lista = _resultados;

    return AlertDialog(
      backgroundColor: const Color(0xFF062A43),
      surfaceTintColor: Colors.transparent,
      title: const Text(
        'Seleccionar cliente',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: Color(0xFF0B3B63),
        ),
      ),
      content: SizedBox(
        width: 650,
        height: 520,
        child: Column(
          children: [
            TextField(
              controller: _buscar,
              autofocus: true,
              onChanged: (valor) => _buscarClientes(valor),
              style: const TextStyle(color: Color(0xFF0B3B63), fontSize: 16),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF5F8FC),
                labelStyle: const TextStyle(color: Color(0xFF526579)),
                hintStyle: const TextStyle(color: Color(0xFF718096)),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _buscar.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _buscar.clear();
                          setState(() {});
                        },
                      ),
                hintText: 'Buscar por nombre, razón social, RUC o código...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _buscando ? 'Buscando clientes...' : '${lista.length} clientes encontrados',
                style: const TextStyle(
                  color: Color(0xFFB8D1E3),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: lista.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _buscando ? Icons.search_rounded : Icons.person_search_outlined,
                              size: 42,
                              color: const Color(0xFF12A8FF),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _buscando
                                  ? 'Buscando en la base de clientes…'
                                  : (_busquedaRealizada
                                      ? 'No se encontró ese cliente.'
                                      : 'Escribe un nombre, RUC o código para buscar.'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFDBE8F2), fontSize: 15),
                            ),
                            if (!_buscando && _busquedaRealizada) ...[
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _registrarNuevoCliente,
                                icon: const Icon(Icons.person_add_alt_1_rounded),
                                label: const Text('Registrar nuevo cliente'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF12A8FF),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: lista.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final c = lista[index];
                        final codigo = _codigo(c);
                        final seleccionado = codigo == widget.clienteActual;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF0A3A5A),
                            child: Icon(
                              Icons.business_outlined,
                              color: seleccionado
                                  ? const Color(0xFF0A9B61)
                                  : const Color(0xFF1468A8),
                            ),
                          ),
                          title: Text(
                            _nombre(c),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          subtitle: Text(
                            codigo.isEmpty ? 'Sin código' : 'RUC / Código: $codigo',
                            style: const TextStyle(color: Color(0xFFB8D1E3)),
                          ),
                          trailing: seleccionado
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF0A9B61),
                                )
                              : const Icon(Icons.chevron_right, color: Color(0xFF12A8FF)),
                          onTap: () => Navigator.pop(context, c),
                          tileColor: const Color(0xFF0B3B63),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Color(0xFFB8D1E3))),
        ),
      ],
    );
  }
}

class _NuevoClienteActividadDialog extends StatefulWidget {
  final dynamic db;
  final String busquedaInicial;
  final String vendedor;

  const _NuevoClienteActividadDialog({
    required this.db,
    required this.busquedaInicial,
    required this.vendedor,
  });

  @override
  State<_NuevoClienteActividadDialog> createState() => _NuevoClienteActividadDialogState();
}

class _NuevoClienteActividadDialogState extends State<_NuevoClienteActividadDialog> {
  final _nombre = TextEditingController();
  final _ruc = TextEditingController();
  final _direccion = TextEditingController();
  final _localidad = TextEditingController();
  final _sector = TextEditingController();
  final _giro = TextEditingController();
  bool _guardando = false;
  String _departamento = 'LIMA';

  @override
  void initState() {
    super.initState();
    _nombre.text = widget.busquedaInicial;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _ruc.dispose();
    _direccion.dispose();
    _localidad.dispose();
    _sector.dispose();
    _giro.dispose();
    super.dispose();
  }

  InputDecoration _decoracion(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: const Color(0xFF12A8FF)),
    filled: true,
    fillColor: const Color(0xFF0B3B63),
    labelStyle: const TextStyle(color: Color(0xFFB8D1E3)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF12618A)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF12A8FF), width: 1.5),
    ),
  );

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    final ruc = _ruc.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa la razón social del cliente.')),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      final data = await widget.db.rpc('crm_registrar_cliente_desde_visita', params: {
        'p_nombre': nombre,
        'p_ruc': ruc.isEmpty ? null : ruc,
        'p_direccion': _direccion.text.trim().isEmpty ? null : _direccion.text.trim(),
        'p_departamento': _departamento,
        'p_localidad': _localidad.text.trim().isEmpty ? null : _localidad.text.trim(),
        'p_giro': _giro.text.trim().isEmpty ? null : _giro.text.trim(),
        'p_sector': _sector.text.trim().isEmpty ? null : _sector.text.trim(),
        'p_estado_comercial': 'PROSPECTO',
        'p_vendedor': widget.vendedor.isEmpty ? null : widget.vendedor,
        'p_codigo_vendedor': null,
      });
      final rows = List<Map<String, dynamic>>.from(data as List);
      if (rows.isEmpty) throw Exception('Supabase no devolvió el cliente creado.');
      final row = rows.first;
      final cliente = <String, dynamic>{
        ...row,
        'cliente': row['razon_social'] ?? row['nombre'] ?? nombre,
        'codigo': row['codigo'] ?? '',
        'vendedor': row['vendedor'] ?? widget.vendedor,
      };
      if (mounted) Navigator.pop(context, cliente);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar el cliente: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF062A43),
      title: const Text('Registrar nuevo cliente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text('El cliente se guardará en Supabase como PROSPECTO.', style: TextStyle(color: Color(0xFFB8D1E3))),
                ),
              ),
              TextField(controller: _nombre, enabled: !_guardando, style: const TextStyle(color: Colors.white), decoration: _decoracion('Razón social *', Icons.business_outlined)),
              const SizedBox(height: 10),
              TextField(controller: _ruc, enabled: !_guardando, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _decoracion('RUC (opcional)', Icons.badge_outlined)),
              const SizedBox(height: 10),
              TextField(controller: _direccion, enabled: !_guardando, style: const TextStyle(color: Colors.white), decoration: _decoracion('Dirección', Icons.location_on_outlined)),
              const SizedBox(height: 10),
              TextField(controller: _localidad, enabled: !_guardando, style: const TextStyle(color: Colors.white), decoration: _decoracion('Localidad / distrito', Icons.map_outlined)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _departamento,
                dropdownColor: const Color(0xFF0B3B63),
                style: const TextStyle(color: Colors.white),
                decoration: _decoracion('Departamento', Icons.public_outlined),
                items: const ['LIMA','AREQUIPA','CUSCO','LA LIBERTAD','PIURA','CALLAO','OTRO']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white))))
                    .toList(),
                onChanged: _guardando ? null : (v) => setState(() => _departamento = v ?? 'LIMA'),
              ),
              const SizedBox(height: 10),
              TextField(controller: _sector, enabled: !_guardando, style: const TextStyle(color: Colors.white), decoration: _decoracion('Sector', Icons.category_outlined)),
              const SizedBox(height: 10),
              TextField(controller: _giro, enabled: !_guardando, style: const TextStyle(color: Colors.white), decoration: _decoracion('Giro de negocio', Icons.work_outline)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _guardando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: _guardando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
          label: Text(_guardando ? 'Guardando...' : 'Guardar cliente'),
        ),
      ],
    );
  }
}

