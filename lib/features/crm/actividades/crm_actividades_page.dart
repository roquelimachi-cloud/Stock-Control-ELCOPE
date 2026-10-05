import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/sesion.dart';
import '../../../services/supabase/supabase_service.dart';

class CrmActividadesPage extends StatefulWidget {
  const CrmActividadesPage({super.key});

  @override
  State<CrmActividadesPage> createState() => _CrmActividadesPageState();
}

class _CrmActividadesPageState extends State<CrmActividadesPage> {
  static const _azul = Color(0xFF0B3B63);
  static const _azulClaro = Color(0xFF1468A8);
  static const _verde = Color(0xFF0A9B61);
  static const _fondo = Color(0xFFF4F7FA);

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
      try {
        await _cargarClientes();
      } catch (e) {
        debugPrint('CRM Actividades - error cargando clientes: $e');
      }
      if (mounted) setState(() => _cargando = false);
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
          'Actividades',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26),
        ),
        actions: [
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
                style: TextStyle(fontSize: 16, color: Color(0xFF52657A)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE0E6EC))),
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
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Buscar cliente, código, asunto...', filled: true, fillColor: const Color(0xFFF4F7FA), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
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
      decoration: InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFFF4F7FA), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
      items: items.toSet().map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    ));
  }

  Widget _kpis() {
    return Wrap(spacing: 14, runSpacing: 14, children: [
      _kpi(Icons.event_note_outlined, 'Actividades', '${_actividades.length}', _azulClaro),
      _kpi(Icons.today_outlined, 'Hoy', '$_hoy', _verde),
      _kpi(Icons.warning_amber_outlined, 'Vencidas', '$_vencidas', Colors.redAccent),
      _kpi(Icons.people_alt_outlined, 'Clientes', '${_actividades.map((e) => _s(e['codigo_cliente'])).where((e) => e.isNotEmpty).toSet().length}', Colors.orange),
    ]);
  }

  Widget _kpi(IconData icon, String label, String value, Color color) {
    return Container(width: 220, padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0E6EC))), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.grey)), Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color))]) ]));
  }

  Widget _lista() {
    if (_actividades.isEmpty) {
      return Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE0E6EC))),
        child: const Padding(
          padding: EdgeInsets.all(55),
          child: Column(
            children: [
              Icon(Icons.event_busy_outlined, size: 55, color: Colors.grey),
              SizedBox(height: 12),
              Text('No hay actividades registradas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              SizedBox(height: 5),
              Text('Registra la primera actividad desde “Nueva actividad”.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E6EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.view_list_rounded, color: _azulClaro, size: 25),
              const SizedBox(width: 10),
              const Text('Listado de actividades', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _azul)),
              const Spacer(),
              Text('${_actividades.length} registros', style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 14),
          ..._actividades.map(_tarjetaActividad),
        ],
      ),
    );
  }

  String _nombreClientePorCodigo(String codigo) {
    final codigoNormalizado = codigo.trim();
    if (codigoNormalizado.isEmpty) return '-';

    for (final c in _clientes) {
      final codigoCliente = _s(c['codigo']).isNotEmpty
          ? _s(c['codigo'])
          : _s(c['codigo_cliente']).isNotEmpty
              ? _s(c['codigo_cliente'])
              : _s(c['ruc']);
      if (codigoCliente == codigoNormalizado) {
        final nombre = _s(c['razon_social']).isNotEmpty
            ? _s(c['razon_social'])
            : _s(c['nombre']).isNotEmpty
                ? _s(c['nombre'])
                : _s(c['cliente']);
        if (nombre.isNotEmpty) return nombre;
      }
    }

    return codigoNormalizado;
  }

  Widget _tarjetaActividad(Map<String, dynamic> a) {
    final tipo = _s(a['tipo']).isEmpty ? 'ACTIVIDAD' : _s(a['tipo']);
    final estado = _estadoActividad(a);
    final tipoColor = _colorTipo(tipo);
    final estadoColor = estado == 'VENCIDA'
        ? Colors.redAccent
        : estado == 'COMPLETADA'
            ? _verde
            : _azulClaro;
    final resultado = _s(a['resultado']);
    final proxima = _s(a['fecha_proxima_accion']);
    final vendedor = _s(a['vendedor']);
    final codigoCliente = _s(a['codigo_cliente']);
    final cliente = _nombreClientePorCodigo(codigoCliente);
    final asunto = _s(a['asunto']).isEmpty ? '(Sin asunto)' : _s(a['asunto']);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E9EF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compacto = constraints.maxWidth < 900;

          final fecha = Container(
            width: 78,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F7FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _mesCorto(a['fecha']),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _azul,
                  ),
                ),
                Text(
                  _dia(a['fecha']),
                  style: const TextStyle(
                    fontSize: 27,
                    height: 1.0,
                    fontWeight: FontWeight.w900,
                    color: _azul,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _anio(a['fecha']),
                  style: const TextStyle(fontSize: 12, color: _azul),
                ),
              ],
            ),
          );

          final asuntoBloque = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 7,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(_icono(tipo), size: 19, color: tipoColor),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: tipoColor.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tipo,
                      style: TextStyle(
                        color: tipoColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                asunto,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: _azul,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Cliente: ${cliente.isEmpty ? '-' : cliente}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF52657A),
                  fontSize: 13,
                ),
              ),
            ],
          );

          final vendedorBloque = _infoBloque(
            Icons.person_outline_rounded,
            'Vendedor',
            vendedor.isEmpty ? '-' : vendedor,
          );

          final resultadoBloque = _infoBloque(
            Icons.chat_bubble_outline_rounded,
            'Resultado',
            resultado.isEmpty ? '-' : resultado,
          );

          final proximaBloque = _infoBloque(
            Icons.calendar_month_outlined,
            'Próxima acción',
            proxima.isEmpty ? '-' : _fechaTexto(proxima),
          );

          final estadoBloque = Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: estadoColor.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              estado,
              style: TextStyle(
                color: estadoColor,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          );

          final editar = OutlinedButton.icon(
            onPressed: () => _editarActividad(a),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Editar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _azulClaro,
              side: const BorderSide(color: Color(0xFFD5E1EC)),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

          if (compacto) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    fecha,
                    const SizedBox(width: 14),
                    Expanded(child: asuntoBloque),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 22,
                  runSpacing: 14,
                  children: [
                    vendedorBloque,
                    resultadoBloque,
                    proximaBloque,
                    estadoBloque,
                    editar,
                  ],
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              fecha,
              const SizedBox(width: 18),
              Expanded(flex: 3, child: asuntoBloque),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: vendedorBloque),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: resultadoBloque),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: proximaBloque),
              const SizedBox(width: 18),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  estadoBloque,
                  const SizedBox(height: 9),
                  editar,
                ],
              ),
            ],
          );
        },
      ),
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
                style: const TextStyle(fontSize: 12, color: Colors.grey),
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
              color: _azul,
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
  final _clienteBusqueda = TextEditingController();
  List<Map<String, dynamic>> _clientesFiltrados = [];
  bool _buscandoClientes = false;
  String _tipo = 'LLAMADA';
  String _vendedor = '';
  DateTime? _fechaProxima;
  bool _guardando = false;
  List<Map<String, dynamic>> _tiposGestion = [];

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
    final vendedores = widget.vendedores.toSet().toList();
    if (_vendedor.isNotEmpty && !vendedores.contains(_vendedor)) vendedores.add(_vendedor);

    return AlertDialog(
      title: const Text('Editar actividad', style: TextStyle(fontWeight: FontWeight.w900, color: _azul)),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const ['LLAMADA','WHATSAPP','CORREO','VISITA','REUNION','SEGUIMIENTO','COBRANZA']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: _guardando ? null : (v) => setState(() => _tipo = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: vendedores.contains(_vendedor) ? _vendedor : null,
                decoration: const InputDecoration(labelText: 'Vendedor'),
                items: vendedores.where((e) => e.isNotEmpty).map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: _guardando ? null : (v) => setState(() => _vendedor = v ?? ''),
              ),
              const SizedBox(height: 12),
              TextField(controller: _asunto, enabled: !_guardando, decoration: const InputDecoration(labelText: 'Asunto')),
              const SizedBox(height: 12),
              TextField(controller: _descripcion, enabled: !_guardando, maxLines: 3, decoration: const InputDecoration(labelText: 'Descripción')),
              const SizedBox(height: 12),
              TextField(controller: _resultado, enabled: !_guardando, maxLines: 2, decoration: const InputDecoration(labelText: 'Resultado')),
              const SizedBox(height: 12),
              TextField(controller: _proxima, enabled: !_guardando, decoration: const InputDecoration(labelText: 'Próxima acción')),
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
  DateTime? _fechaProxima;
  bool _guardando = false;
  List<Map<String, dynamic>> _tiposGestion = [];

  @override
  void initState() {
    super.initState();
    _vendedor = widget.vendedorActual.isNotEmpty
        ? widget.vendedorActual
        : (widget.vendedores.isNotEmpty ? widget.vendedores.first : '');
    _cargarTiposGestion();
  }

  Future<void> _cargarTiposGestion() async {
    try {
      final data = await widget.db
          .from('crm_catalogos')
          .select('id,nombre,descripcion,activo,orden')
          .eq('categoria', 'tipos_gestion')
          .eq('activo', true)
          .order('orden')
          .order('nombre');
      final tipos = List<Map<String, dynamic>>.from(data);
      if (!mounted) return;
      setState(() {
        _tiposGestion = tipos;
        if (_tipo.isEmpty || !tipos.any((e) => _s(e['nombre']).toUpperCase() == _tipo.toUpperCase())) {
          _tipo = tipos.isNotEmpty ? _s(tipos.first['nombre']) : 'LLAMADA';
        }
      });
    } catch (_) {
      // Mantiene el comportamiento anterior si el catálogo no está disponible.
    }
  }

  IconData _iconoTipoGestion(String tipo) {
    switch (tipo.trim().toUpperCase()) {
      case 'LLAMADA': return Icons.phone_outlined;
      case 'WHATSAPP': return Icons.chat_outlined;
      case 'CORREO': return Icons.email_outlined;
      case 'VISITA': return Icons.location_on_outlined;
      case 'REUNION':
      case 'REUNIÓN': return Icons.groups_outlined;
      case 'SEGUIMIENTO': return Icons.follow_the_signs_outlined;
      case 'COBRANZA': return Icons.payments_outlined;
      case 'VIDEOLLAMADA':
      case 'VIDEO LLAMADA':
      case 'VIDEOLLAMADA ': return Icons.video_call_outlined;
      default: return Icons.task_alt_outlined;
    }
  }

  Widget _tiposGestionWidget() {
    final tipos = _tiposGestion.isEmpty
        ? const [
            {'nombre': 'LLAMADA'},
            {'nombre': 'WHATSAPP'},
            {'nombre': 'CORREO'},
            {'nombre': 'VISITA'},
            {'nombre': 'REUNION'},
            {'nombre': 'SEGUIMIENTO'},
          ]
        : _tiposGestion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tipo de gestión', style: TextStyle(fontWeight: FontWeight.w800, color: _azul)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: tipos.map((tipo) {
            final nombre = _s(tipo['nombre']);
            final seleccionado = nombre.toUpperCase() == _tipo.toUpperCase();
            return ChoiceChip(
              selected: seleccionado,
              onSelected: _guardando ? null : (_) => setState(() => _tipo = nombre),
              avatar: Icon(_iconoTipoGestion(nombre), size: 18, color: seleccionado ? Colors.white : _azul),
              label: Text(nombre.toUpperCase()),
              selectedColor: _azul,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(color: seleccionado ? Colors.white : _azul, fontWeight: FontWeight.w800),
              side: BorderSide(color: seleccionado ? _azul : const Color(0xFFD6E1EA)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            );
          }).toList(),
        ),
      ],
    );
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

    return AlertDialog(
      title: const Text(
        'Nueva actividad',
        style: TextStyle(fontWeight: FontWeight.w900, color: _azul),
      ),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tiposGestionWidget(),
              const SizedBox(height: 16),

              // Búsqueda directa por nombre o RUC.
              Autocomplete<Map<String, dynamic>>(
                displayStringForOption: _textoCliente,
                optionsBuilder: (textEditingValue) {
                  final query = textEditingValue.text;
                  if (query.trim().isEmpty) {
                    return const Iterable<Map<String, dynamic>>.empty();
                  }

                  return widget.clientes
                      .where((cliente) => _coincideCliente(cliente, query))
                      .take(80);
                },
                onSelected: (cliente) {
                  setState(() {
                    _cliente = _codigoCliente(cliente);
                  });
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                  if (_cliente.isNotEmpty && controller.text.isEmpty) {
                    final clienteSeleccionado = widget.clientes.where(
                      (c) => _codigoCliente(c) == _cliente,
                    );
                    if (clienteSeleccionado.isNotEmpty) {
                      controller.text = _textoCliente(clienteSeleccionado.first);
                      controller.selection = TextSelection.collapsed(
                        offset: controller.text.length,
                      );
                    }
                  }

                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: !_guardando,
                    onChanged: (_) {
                      // Al modificar la búsqueda, obligamos a volver a elegir
                      // un cliente para evitar guardar un RUC anterior.
                      if (_cliente.isNotEmpty) {
                        setState(() => _cliente = '');
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Cliente *',
                      hintText: 'Escribe nombre o RUC',
                      prefixIcon: const Icon(Icons.business_outlined),
                      suffixIcon: IconButton(
                        tooltip: 'Limpiar cliente',
                        icon: const Icon(Icons.clear),
                        onPressed: _guardando
                            ? null
                            : () {
                                controller.clear();
                                setState(() => _cliente = '');
                                focusNode.requestFocus();
                              },
                      ),
                      helperText: _cliente.isEmpty
                          ? 'Busca por razón social, nombre o RUC'
                          : 'Cliente seleccionado: $_cliente',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  final lista = options.toList();

                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 680,
                          maxHeight: 360,
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shrinkWrap: true,
                          itemCount: lista.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final cliente = lista[index];
                            final codigo = _codigoCliente(cliente);
                            final nombre = _nombreCliente(cliente);

                            return ListTile(
                              dense: true,
                              leading: const CircleAvatar(
                                child: Icon(Icons.business_outlined),
                              ),
                              title: Text(
                                nombre,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text('RUC / Código: $codigo'),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                              ),
                              onTap: () => onSelected(cliente),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: vendedores.contains(_vendedor) ? _vendedor : null,
                decoration: const InputDecoration(labelText: 'Vendedor'),
                items: vendedores
                    .where((e) => e.isNotEmpty)
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e),
                      ),
                    )
                    .toList(),
                onChanged:
                    _guardando ? null : (v) => setState(() => _vendedor = v ?? ''),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _asunto,
                enabled: !_guardando,
                decoration: const InputDecoration(labelText: 'Asunto *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descripcion,
                enabled: !_guardando,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _resultado,
                enabled: !_guardando,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Resultado'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _proxima,
                enabled: !_guardando,
                decoration: const InputDecoration(labelText: 'Próxima acción'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _fechaProxima == null
                          ? 'Sin fecha de próxima acción'
                          : 'Próxima: ${DateFormat('dd/MM/yyyy').format(_fechaProxima!)}',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _guardando ? null : _seleccionarFecha,
                    icon: const Icon(Icons.calendar_today),
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
          onPressed:
              _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}
