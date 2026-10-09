import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/supabase/supabase_service.dart';
import '../../../services/sesion.dart';
import '../clientes/crm_clientes_page.dart';
import '../cliente_360/crm_cliente_360_page.dart';
import '../visitas/crm_visitas_page.dart';
import '../seguimientos/crm_seguimientos_page.dart';
import '../facturacion/facturacion_importacion_page.dart';
import '../oportunidades/crm_oportunidades_page.dart';

class CrmDashboardPage extends StatefulWidget {
  const CrmDashboardPage({Key? key, this.embebido = false}) : super(key: key);

  final bool embebido;

  @override
  State<CrmDashboardPage> createState() => _CrmDashboardPageState();
}

class _CrmDashboardPageState extends State<CrmDashboardPage> {
  static const _azul = Color(0xFF063B63);
  static const _azulClaro = Color(0xFF0D6EAA);
  static const _azulFondo = Color(0xFF071F35);
  static const _verde = Color(0xFF19C979);
  static const _borde = Color(0xFF234764);
  final _db = SupabaseService.client;
  final _money = NumberFormat('#,##0.00', 'en_US');
  final _fecha = DateFormat('dd/MM/yyyy');

  bool _cargando = true;
  String? _error;
  Map<String, dynamic> _dashboard = {};
  List<Map<String, dynamic>> _oportunidades = [];
  List<Map<String, dynamic>> _agenda = [];
  List<Map<String, dynamic>> _seguimientos = [];
  List<Map<String, dynamic>> _clientesRecientes = [];
  Map<String, dynamic> _cartera = {};

  String get _nombreUsuario {
    final n = Sesion.nombre.trim();
    if (n.isNotEmpty) return n;
    final v = Sesion.vendedor.trim();
    return v.isEmpty ? 'Usuario' : v;
  }

  String get _nombreCorto => _nombreUsuario.split(RegExp(r'\s+')).first;

  String get _saludo {
    final hora = DateTime.now().hour;
    if (hora >= 5 && hora < 12) return 'Buenos días';
    if (hora >= 12 && hora < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String get _periodoActualLabel {
    final ahora = DateTime.now();
    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return '${meses[ahora.month - 1]} ${ahora.year}';
  }

  String get _vendedorDashboard {
    final vendedor = Sesion.vendedor.trim();
    final rol = Sesion.rol.trim().toLowerCase();

    // Un usuario que además es vendedor debe entrar al dashboard
    // con su cartera comercial. Las jefaturas y Gerencia mantienen
    // su alcance especial.
    if (rol == 'jefe lima' ||
        rol == 'jefe provincia' ||
        rol == 'gerencia' ||
        rol == 'gerencia comercial') {
      return 'TODOS';
    }

    return vendedor.isEmpty ? 'TODOS' : vendedor;
  }

  String get _alcanceFacturacionLabel {
    final rol = (_s(_dashboard['rol']).toLowerCase());
    if (Sesion.vendedor.trim().toLowerCase() == 'michael roque') {
      return 'Michael Roque · Asesor Comercial';
    }
    final canal = _s(_dashboard['canal']).toUpperCase();
    if (rol == 'administrador' || rol == 'administrator' || rol == 'gerencia' || rol == 'gerencia comercial') {
      return 'Total empresa';
    }
    if (rol == 'jefe lima') {
      final n = (_dashboard['vendedores_permitidos'] is List) ? (_dashboard['vendedores_permitidos'] as List).length : 0;
      return 'LIMA · ${n == 1 ? '1 vendedor' : '$n vendedores'}';
    }
    if (rol == 'jefe provincia') {
      final n = (_dashboard['vendedores_permitidos'] is List) ? (_dashboard['vendedores_permitidos'] as List).length : 0;
      return 'PROVINCIAS · ${n == 1 ? '1 vendedor' : '$n vendedores'}';
    }
    if (canal.isNotEmpty && canal != 'TODOS') return canal;
    return _nombreUsuario;
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString().replaceAll(',', '').trim() ?? '') ?? 0;
  }

  String _s(dynamic v) => v?.toString().trim() ?? '';

  DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() { _cargando = true; _error = null; });

    Object? ultimoError;

    // Alcance comercial:
    // Michael Roque es Administrador a nivel de sistema, pero también es
    // Asesor Comercial. Su dashboard debe mostrar únicamente su vendedor.
    // El dashboard hace varias agregaciones en Supabase. Si la conexión
    // tiene un timeout transitorio, reintentamos silenciosamente antes de
    // mostrar el aviso al usuario. La función SQL también está optimizada
    // para evitar el 57014 que aparecía al abrir el CRM.
    for (int intento = 1; intento <= 2; intento++) {
      try {
        final result = await _db.rpc('crm_obtener_dashboard_resumen', params: {
          'p_periodo': '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
          'p_vendedor': _vendedorDashboard,
          'p_busqueda': '',
          'p_usuario_id': Sesion.idUsuario,
        });

        final data = result is Map
            ? Map<String, dynamic>.from(result)
            : <String, dynamic>{};

        if (!mounted) return;
        setState(() {
          _dashboard = data;
          _oportunidades = _lista(data['oportunidades']);
          _agenda = _lista(data['agenda']);
          _seguimientos = _lista(data['seguimientos']);
          _clientesRecientes = _lista(data['clientes_recientes']);
          _cartera = data['cartera'] is Map
              ? Map<String, dynamic>.from(data['cartera'])
              : <String, dynamic>{};
          _cargando = false;
          _error = null;
        });
        return;
      } catch (e) {
        ultimoError = e;
        if (intento < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _cargando = false;
      _error = ultimoError?.toString() ?? 'No se pudo cargar la información.';
    });
  }

  List<Map<String, dynamic>> _lista(dynamic value) {
    if (value is! List) return [];
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Map<String, dynamic> get _kpi => _dashboard['kpis'] is Map ? Map<String, dynamic>.from(_dashboard['kpis']) : {};
  List<Map<String, dynamic>> get _facturas => _lista(_dashboard['recientes']);
  List<Map<String, dynamic>> get _facturacionMensual => _lista(_dashboard['mensual']);

  List<Map<String, dynamic>> get _facturacionEsteAnio {
    final anio = DateTime.now().year;
    final porMes = <int, double>{for (int i = 1; i <= 12; i++) i: 0};
    for (final row in _facturacionMensual) {
      final periodo = _s(row['periodo']);
      final partes = periodo.split('-');
      if (partes.length != 2 || int.tryParse(partes[0]) != anio) continue;
      final mes = int.tryParse(partes[1]);
      if (mes != null && mes >= 1 && mes <= 12) {
        porMes[mes] = _num(row['monto']);
      }
    }
    return [
      for (int mes = 1; mes <= 12; mes++)
        {'mes': mes, 'monto': porMes[mes] ?? 0.0},
    ];
  }
  double get _facturacion => _num(_kpi['facturacion']);
  int _carteraInt(String key) => (_cartera[key] as num?)?.toInt() ?? 0;
  int get _carteraTotal => _carteraInt('total');
  int get _sinContacto => _carteraInt('sin_contacto');
  int get _conContacto => (_carteraTotal - _sinContacto).clamp(0, _carteraTotal);
  int get _conOportunidad => _carteraInt('con_oportunidad');

  String _hora(String value) {
    if (value.isEmpty) return '--:--';
    return value.length >= 5 ? value.substring(0, 5) : value;
  }
  int get _clientes => (_kpi['clientes'] as num?)?.toInt() ?? 0;
  int get _oportunidadesCount => (_kpi['oportunidades'] as num?)?.toInt() ?? _oportunidades.length;
  int get _facturasCount => (_kpi['facturas'] as num?)?.toInt() ?? _facturas.length;
  int get _actividadesHoy => (_kpi['actividades_hoy'] as num?)?.toInt() ?? 0;

  void _abrir(Widget pagina) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => pagina));
  }

  void _abrirClientes() => _abrir(const CrmClientesPage());
  void _abrirVisitas() => _abrir(const CrmVisitasPage());
  void _abrirSeguimientos() => _abrir(const CrmSeguimientosPage());
  void _abrirFacturacion() => _abrir(const FacturacionImportacionPage());

  void _abrirFacturaEnCliente360(Map<String, dynamic> f) {
    final codigoCliente = _s(f['codigo_cliente']).trim();
    final numeroFactura = _s(f['numero_factura']).trim();

    if (codigoCliente.isEmpty || numeroFactura.isEmpty) {
      _abrirFacturacion();
      return;
    }

    _abrir(
      CrmCliente360FacturaPage(
        codigoCliente: codigoCliente,
        numeroFactura: numeroFactura,
        nombreCliente: _s(f['cliente']),
      ),
    );
  }
  void _abrirOportunidades() => _abrir(const CrmOportunidadesPage());

  @override
  Widget build(BuildContext context) {
    final body = _cargando
        ? const Center(child: CircularProgressIndicator(color: _verde))
        : _error != null
            ? _errorView()
            : _contenido();
    if (widget.embebido) return ColoredBox(color: _azulFondo, child: body);
    return Scaffold(backgroundColor: _azulFondo, body: body);
  }

  Widget _errorView() => Center(child: Container(margin: const EdgeInsets.all(30), padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, color: Colors.red, size: 45), const SizedBox(height: 10), const Text('No se pudo cargar el dashboard CRM', style: TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 14), FilledButton.icon(onPressed: _cargar, icon: const Icon(Icons.refresh), label: const Text('Reintentar'))])));

  Widget _contenido() {
    final w = MediaQuery.sizeOf(context).width;
    final mobile = w < 900;
    return RefreshIndicator(
      onRefresh: _cargar,
      color: _verde,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(mobile ? 14 : 18, 16, mobile ? 14 : 18, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _bienvenida(mobile),
          const SizedBox(height: 14),
          _kpis(mobile),
          const SizedBox(height: 14),
          _panelFacturacionAnual(mobile),
          const SizedBox(height: 14),
          _principal(mobile),
          const SizedBox(height: 14),
          _inferior(mobile),
        ]),
      ),
    );
  }

  Widget _bienvenida(bool mobile) {
    return Container(
      height: mobile ? 155 : 170,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: const LinearGradient(colors: [Color(0xFF07365B), Color(0xFF0A6799), Color(0xFF063B63)])),
      child: Stack(children: [
        Positioned(right: -15, bottom: -55, child: Icon(Icons.landscape_rounded, size: 280, color: Colors.white.withValues(alpha: .10))),
        Positioned(right: 25, top: 25, child: Icon(Icons.wb_sunny_outlined, size: 90, color: Colors.white.withValues(alpha: .10))),
        Padding(padding: const EdgeInsets.fromLTRB(28, 25, 300, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$_saludo, $_nombreCorto', style: TextStyle(color: Colors.white, fontSize: mobile ? 27 : 32, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const Text('Aquí tienes el resumen de tu actividad comercial de hoy.', style: TextStyle(color: Colors.white, fontSize: 15)),
          const SizedBox(height: 14),
          Row(children: [
            _pill(Icons.trending_up_rounded, 'Más ventas'),
            const SizedBox(width: 8),
            _pill(Icons.groups_rounded, 'Mejores clientes'),
            const SizedBox(width: 8),
            _pill(Icons.track_changes_rounded, 'Nuevas oportunidades'),
          ]),
        ])),
        Positioned(right: 24, top: 20, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: _verde, borderRadius: BorderRadius.circular(10)), child: const Text('ELCOPE', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)))),
      ]),
    );
  }

  Widget _pill(IconData icon, String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .14), border: Border.all(color: _verde.withValues(alpha: .55)), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: _verde, size: 15), const SizedBox(width: 5), Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))]));

  Widget _kpis(bool mobile) {
    final data = [
      ['Facturación $_alcanceFacturacionLabel / $_periodoActualLabel', 'US\$ ${_money.format(_facturacion)}', Icons.bar_chart_rounded, const Color(0xFF1475D1)],
      ['Clientes activos', '$_clientes', Icons.groups_rounded, const Color(0xFF198CE0)],
      ['Oportunidades', '$_oportunidadesCount', Icons.track_changes_rounded, const Color(0xFFF5A623)],
      ['Cotizaciones', '${_kpi['cotizaciones'] ?? 0}', Icons.description_rounded, const Color(0xFF8758E9)],
      ['Facturas emitidas', '$_facturasCount', Icons.receipt_long_rounded, const Color(0xFF19B879)],
    ];
    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth >= 1250 ? 5 : c.maxWidth >= 800 ? 3 : 1;
      return GridView.count(crossAxisCount: cols, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: mobile ? 3.8 : 2.15, children: [for (final x in data) _kpiCard(x[0] as String, x[1] as String, x[2] as IconData, x[3] as Color)]);
    });
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF0C2B46), border: Border.all(color: _borde), borderRadius: BorderRadius.circular(12)), child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 25)), const SizedBox(width: 10), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)), const SizedBox(height: 2), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))]))]));

  Widget _panelFacturacionAnual(bool mobile) {
    final datos = _facturacionEsteAnio;
    final total = datos.fold<double>(0, (sum, e) => sum + _num(e['monto']));
    final mesesConFacturacion = datos.where((e) => _num(e['monto']) > 0).length;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0A2943),
        border: Border.all(color: _borde),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.bar_chart_rounded, color: _verde, size: 22),
          const SizedBox(width: 8),
          const Expanded(child: Text('Facturación por mes', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .08),
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _miniDato('Año', '${DateTime.now().year}'),
              const SizedBox(width: 14),
              _miniDato('Total', 'US\$ ${_money.format(total)}'),
              const SizedBox(width: 14),
              _miniDato('Meses', '$mesesConFacturacion'),
            ]),
          ),
        ]),
        const SizedBox(height: 4),
        const Text('Facturación acumulada por mes del año actual', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          height: mobile ? 285 : 275,
          child: CustomPaint(
            painter: _FacturacionAnualPainter(
              values: [for (final e in datos) _num(e['monto'])],
              labels: [for (final e in datos) _mesCorto(_num(e['mes']).toInt())],
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ]),
    );
  }

  Widget _miniDato(String titulo, String valor) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(titulo, style: const TextStyle(color: Colors.white54, fontSize: 8)),
      const SizedBox(height: 1),
      Text(valor, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)),
    ],
  );

  String _mesCorto(int mes) {
    const nombres = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
    return mes >= 1 && mes <= 12 ? nombres[mes - 1] : '';
  }

  Widget _principal(bool mobile) {
    if (mobile) return Column(children: [_pipeline(), const SizedBox(height: 12), _agendaPanel(), const SizedBox(height: 12), _seguimientosPanel()]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 7, child: _pipeline()), const SizedBox(width: 12), Expanded(flex: 3, child: Column(children: [_agendaPanel(), const SizedBox(height: 12), _seguimientosPanel()]))]);
  }

  Widget _panel(String title, IconData icon, Widget child, {String? action, VoidCallback? onAction}) => Container(decoration: BoxDecoration(color: const Color(0xFF0A2943), border: Border.all(color: _borde), borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.fromLTRB(14, 13, 14, 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: Colors.white, size: 21), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))), if (action != null) InkWell(onTap: onAction, borderRadius: BorderRadius.circular(6), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3), child: Text(action, style: const TextStyle(color: _verde, fontSize: 11, fontWeight: FontWeight.w800))))]), const SizedBox(height: 11), child]));

  Widget _pipeline() {
    final etapas = ['NUEVA', 'COTIZACIÓN', 'NEGOCIACIÓN', 'FACTURA'];
    final colores = [const Color(0xFF69A8FF), const Color(0xFF72B7F2), const Color(0xFFFFC94D), const Color(0xFF42D89A)];
    return _panel('Pipeline de oportunidades', Icons.track_changes_rounded, SizedBox(height: 360, child: LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth >= 850 ? 4 : 2;
      return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 7, mainAxisSpacing: 7, childAspectRatio: cols == 4 ? .70 : 1.1), itemCount: etapas.length, itemBuilder: (_, i) => _pipelineCol(etapas[i], colores[i]));
    })), action: 'Ver oportunidades', onAction: _abrirOportunidades);
  }

  Widget _pipelineCol(String etapa, Color color) {
    // FACTURA se alimenta directamente de las facturas reales del mes.
    // Las demás columnas se alimentan de crm_oportunidades.
    if (etapa == 'FACTURA') {
      final facturas = _facturas.take(4).toList();
      return Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          border: Border.all(color: color.withValues(alpha: .40)),
          borderRadius: BorderRadius.circular(9),
        ),
        padding: const EdgeInsets.all(7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etapa, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            if (facturas.isEmpty)
              const Expanded(child: Center(child: Text('Sin facturas del mes', style: TextStyle(color: Colors.white54, fontSize: 10))))
            else
              Expanded(child: ListView(children: [for (final f in facturas) _facturaPipelineCard(f, color)])),
          ],
        ),
      );
    }

    final lista = _oportunidades.where((o) => _etapaPipeline(o['etapa']) == etapa).take(4).toList();
    return Container(
      decoration: BoxDecoration(color: color.withValues(alpha: .12), border: Border.all(color: color.withValues(alpha: .40)), borderRadius: BorderRadius.circular(9)),
      padding: const EdgeInsets.all(7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(etapa, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        if (lista.isEmpty)
          const Expanded(child: Center(child: Text('Sin oportunidades', style: TextStyle(color: Colors.white54, fontSize: 10))))
        else
          Expanded(child: ListView(children: [for (final o in lista) _oppCard(o, color)])),
      ]),
    );
  }

  Widget _facturaPipelineCard(Map<String, dynamic> f, Color color) {
    final fecha = _date(f['fecha_factura']);
    final cliente = _s(f['cliente']).isEmpty ? _s(f['codigo_cliente']) : _s(f['cliente']);
    final numero = _s(f['numero_factura']).isEmpty ? 'Factura emitida' : _s(f['numero_factura']);
    final monto = _num(f['monto']);
    return InkWell(
      onTap: () => _abrirFacturaEnCliente360(f),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(cliente.isEmpty ? 'Cliente' : cliente, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _azul, fontSize: 10, fontWeight: FontWeight.w900))),
            const Icon(Icons.receipt_long_rounded, color: _verde, size: 13),
          ]),
          const SizedBox(height: 2),
          Text(numero, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 9)),
          const SizedBox(height: 3),
          Text('US\$ ${_money.format(monto)}', style: const TextStyle(color: _azul, fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Row(children: [
            Expanded(child: Text(fecha == null ? _nombreUsuario : _fecha.format(fecha), style: const TextStyle(color: Colors.black54, fontSize: 8))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(5)), child: const Text('FACTURADA', style: TextStyle(color: _verde, fontSize: 7.5, fontWeight: FontWeight.w900))),
          ]),
        ]),
      ),
    );
  }

  String _etapaPipeline(dynamic value) {
    final etapa = _s(value).toUpperCase();
    if (etapa.contains('FACTURA') || etapa.contains('GANAD')) return 'FACTURA';
    if (etapa.contains('NEGOCI')) return 'NEGOCIACIÓN';
    if (etapa.contains('COTIZ') || etapa.contains('PROPUESTA')) return 'COTIZACIÓN';
    return 'NUEVA';
  }

  Widget _oppCard(Map<String, dynamic> o, Color color) {
    final monto = _num(o['monto_estimado']);
    final cliente = _s(o['cliente']).isEmpty ? (_s(o['codigo_cliente']).isEmpty ? 'Cliente' : _s(o['codigo_cliente'])) : _s(o['cliente']);
    return InkWell(
      onTap: _abrirOportunidades,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(_s(o['titulo']).isEmpty ? 'Oportunidad' : _s(o['titulo']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _azul, fontSize: 10, fontWeight: FontWeight.w900))),
            const Icon(Icons.open_in_new_rounded, color: _azul, size: 13),
          ]),
          Text(cliente, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 9)),
          const SizedBox(height: 3),
          Text('US\$ ${_money.format(monto)}', style: TextStyle(color: _azul, fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Row(children: [
            Expanded(child: Text(_s(o['vendedor']).isEmpty ? _nombreUsuario : _s(o['vendedor']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 8))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(5)), child: Text('${_num(o['probabilidad']).toInt()}%', style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)))
          ]),
        ]),
      ),
    );
  }

  Widget _agendaPanel() {
    final hoy = DateTime.now();
    final lista = _agenda.where((v) { final d = _date(v['fecha_visita']); return d == null || (d.year == hoy.year && d.month == hoy.month && d.day == hoy.day); }).take(5).toList();
    return _panel('Mi agenda de hoy', Icons.calendar_month_rounded, lista.isEmpty ? const SizedBox(height: 130, child: Center(child: Text('No hay visitas programadas para hoy.', style: TextStyle(color: Colors.white54, fontSize: 11)))) : Column(children: [for (final v in lista) _agendaRow(v)]), action: 'Ver calendario', onAction: _abrirVisitas);
  }

  Widget _agendaRow(Map<String, dynamic> v) => Container(margin: const EdgeInsets.only(bottom: 7), padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [SizedBox(width: 43, child: Text(_s(v['hora_programada']).isEmpty ? '--:--' : _hora(_s(v['hora_programada'])), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900))), const Icon(Icons.circle, color: _verde, size: 8), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_s(v['cliente_nombre']).isEmpty ? _s(v['codigo_cliente']) : _s(v['cliente_nombre']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)), Text(_s(v['motivo']).isEmpty ? 'Visita comercial' : _s(v['motivo']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 9))]))]));

  Widget _seguimientosPanel() {
    final lista = _seguimientos.take(5).toList();
    return _panel('Seguimientos pendientes', Icons.notifications_active_outlined, lista.isEmpty ? const SizedBox(height: 100, child: Center(child: Text('Sin seguimientos pendientes.', style: TextStyle(color: Colors.white54, fontSize: 11)))) : Column(children: [for (final a in lista) _seguimientoRow(a)]), action: 'Ver todos', onAction: _abrirSeguimientos);
  }

  Widget _seguimientoRow(Map<String, dynamic> a) { final d = _date(a['fecha_proxima_accion']); final vencido = d != null && DateTime(d.year, d.month, d.day).isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)); return Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .05), borderRadius: BorderRadius.circular(8)), child: Row(children: [CircleAvatar(radius: 15, backgroundColor: vencido ? Colors.red.withValues(alpha: .18) : _azulClaro.withValues(alpha: .25), child: Icon(vencido ? Icons.warning_amber_rounded : Icons.notifications_none_rounded, color: vencido ? Colors.redAccent : Colors.white, size: 16)), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_s(a['asunto']).isEmpty ? 'Seguimiento' : _s(a['asunto']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)), Text(_s(a['proxima_accion']).isEmpty ? _s(a['codigo_cliente']) : _s(a['proxima_accion']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 9))])), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: vencido ? Colors.red.withValues(alpha: .20) : Colors.amber.withValues(alpha: .18), borderRadius: BorderRadius.circular(5)), child: Text(vencido ? 'Vencido' : (d == null ? 'Pendiente' : _fecha.format(d)), style: TextStyle(color: vencido ? Colors.redAccent : Colors.amberAccent, fontSize: 8, fontWeight: FontWeight.w900))) ])); }

  Widget _inferior(bool mobile) {
    if (mobile) return Column(children: [_clientesPanel(), const SizedBox(height: 12), _facturasPanel(), const SizedBox(height: 12), _carteraPanel()]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 4, child: _clientesPanel()), const SizedBox(width: 12), Expanded(flex: 4, child: _facturasPanel()), const SizedBox(width: 12), Expanded(flex: 2, child: _carteraPanel())]);
  }

  Widget _clientesPanel() => _panel('Clientes recientes', Icons.groups_rounded, _clientesRecientes.isEmpty ? const SizedBox(height: 150, child: Center(child: Text('Sin clientes recientes.', style: TextStyle(color: Colors.white54)))) : Column(children: [for (final c in _clientesRecientes.take(5)) _clienteRow(c)]), action: 'Ver todos', onAction: _abrirClientes);

  Widget _clienteRow(Map<String, dynamic> c) => Container(padding: const EdgeInsets.symmetric(vertical: 7), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _borde))), child: Row(children: [const Icon(Icons.business_rounded, color: _verde, size: 18), const SizedBox(width: 8), Expanded(child: Text(_s(c['cliente']).isEmpty ? _s(c['codigo_cliente']) : _s(c['cliente']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))), Text(_s(c['codigo_cliente']), style: const TextStyle(color: Colors.white54, fontSize: 8))]));

  Widget _facturasPanel() => _panel('Últimas facturas', Icons.receipt_long_rounded, _facturas.isEmpty ? const SizedBox(height: 150, child: Center(child: Text('Sin facturas recientes.', style: TextStyle(color: Colors.white54)))) : Column(children: [for (final f in _facturas.take(5)) _facturaRow(f)]), action: 'Ver todas', onAction: _abrirFacturacion);

  Widget _facturaRow(Map<String, dynamic> f) { final monto = _num(f['monto'] ?? f['importe'] ?? f['total']); return Container(padding: const EdgeInsets.symmetric(vertical: 7), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _borde))), child: Row(children: [SizedBox(width: 70, child: Text(_date(f['fecha_factura'] ?? f['fecha']) == null ? '-' : _fecha.format(_date(f['fecha_factura'] ?? f['fecha'])!), style: const TextStyle(color: Colors.white70, fontSize: 8))), Expanded(child: Text(_s(f['cliente']).isEmpty ? _s(f['codigo_cliente']) : _s(f['cliente']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))), Text('US\$ ${_money.format(monto)}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)), const SizedBox(width: 5), const Icon(Icons.check_circle, color: _verde, size: 14)])); }

  Widget _carteraPanel() {
    final total = _carteraTotal == 0 ? _clientes : _carteraTotal;
    final sin = _sinContacto.clamp(0, total);
    final opp = _conOportunidad.clamp(0, total);
    final contacto = (total - sin - opp).clamp(0, total);
    return _panel(
      'Estado de tu cartera',
      Icons.pie_chart_rounded,
      SizedBox(
        height: 220,
        child: Column(
          children: [
            const SizedBox(height: 2),
            SizedBox(
              width: 145,
              height: 145,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(size: const Size(145, 145), painter: _CarteraDonutPainter(sin: sin.toDouble(), contacto: contacto.toDouble(), oportunidad: opp.toDouble(), total: total.toDouble())),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('$total', style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
                    const Text('Clientes', style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 5, children: [
              _legend('Sin contacto', sin, const Color(0xFFFF5B6E)),
              _legend('Con contacto', contacto, const Color(0xFF2D9CFF)),
              _legend('Oportunidad', opp, const Color(0xFFFFC94D)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _legend(String label, int value, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 4), Text('$label: $value', style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w700))]);
}


class _FacturacionAnualPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;

  const _FacturacionAnualPainter({required this.values, required this.labels});

  String _monto(double value) {
    if (value.abs() >= 1000000) return 'US\$ ${(value / 1000000).toStringAsFixed(2)} M';
    if (value.abs() >= 1000) return 'US\$ ${(value / 1000).toStringAsFixed(2)} K';
    return 'US\$ ${value.toStringAsFixed(0)}';
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 0 || size.height <= 0) return;

    const left = 10.0;
    const right = 10.0;
    const top = 28.0;
    const bottom = 35.0;
    final chartW = size.width - left - right;
    final chartH = size.height - top - bottom;
    final baseY = top + chartH;

    double maxValue = values.fold<double>(0, (m, v) => v > m ? v : m);
    if (maxValue <= 0) maxValue = 1;

    final grid = Paint()..color = Colors.white.withValues(alpha: .13)..strokeWidth = 1;
    for (int i = 0; i < 4; i++) {
      final y = top + chartH * i / 3;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), grid);
    }

    final count = values.length;
    final slot = chartW / count;
    final barWidth = (slot * .52).clamp(12.0, 54.0).toDouble();
    final barPaint = Paint()..color = const Color(0xFF4EA3D8);
    final topPaint = Paint()..color = const Color(0xFF63B7EA);
    final linePaint = Paint()..color = const Color(0xFF39D98A)..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final pointPaint = Paint()..color = const Color(0xFF39D98A);
    final line = Path();

    for (int i = 0; i < count; i++) {
      final value = values[i];
      final x = left + slot * i + slot / 2;
      final barH = chartH * (value / maxValue);
      final y = baseY - barH;

      if (value > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x - barWidth / 2, y, barWidth, barH),
            topLeft: const Radius.circular(5),
            topRight: const Radius.circular(5),
          ),
          barPaint,
        );
        canvas.drawRect(Rect.fromLTWH(x - barWidth / 2, y, barWidth, 3), topPaint);
      }

      final label = _monto(value);
      final tp = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900)),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: slot + 18);
      tp.paint(canvas, Offset((x - tp.width / 2).clamp(left, size.width - right - tp.width), (y - tp.height - 5).clamp(0.0, baseY - tp.height - 4)));

      if (value > 0) {
        if (i == 0) {
          line.moveTo(x, y);
        } else {
          line.lineTo(x, y);
        }
        canvas.drawCircle(Offset(x, y), 3.5, pointPaint);
      }

      final month = labels.length > i ? labels[i] : '';
      final mt = TextPainter(
        text: TextSpan(text: month, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      mt.paint(canvas, Offset(x - mt.width / 2, baseY + 10));
    }

    canvas.drawPath(line, linePaint);
  }

  @override
  bool shouldRepaint(covariant _FacturacionAnualPainter oldDelegate) => oldDelegate.values != values || oldDelegate.labels != labels;
}

class _CarteraDonutPainter extends CustomPainter {
  final double sin;
  final double contacto;
  final double oportunidad;
  final double total;
  const _CarteraDonutPainter({required this.sin, required this.contacto, required this.oportunidad, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 9;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final base = Paint()..style = PaintingStyle.stroke..strokeWidth = 18..strokeCap = StrokeCap.round..color = Colors.white12;
    canvas.drawArc(rect, 0, 2 * 3.141592653589793, false, base);
    if (total <= 0) return;
    final colors = [const Color(0xFFFF5B6E), const Color(0xFF2D9CFF), const Color(0xFFFFC94D)];
    final values = [sin, contacto, oportunidad];
    double start = -3.141592653589793 / 2;
    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final sweep = (values[i] / total) * 2 * 3.141592653589793;
      final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 18..strokeCap = StrokeCap.round..color = colors[i];
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _CarteraDonutPainter oldDelegate) => oldDelegate.sin != sin || oldDelegate.contacto != contacto || oldDelegate.oportunidad != oportunidad || oldDelegate.total != total;
}


/// Cliente 360° enfocado exclusivamente en una factura seleccionada.
class CrmCliente360FacturaPage extends StatefulWidget {
  const CrmCliente360FacturaPage({
    super.key,
    required this.codigoCliente,
    required this.numeroFactura,
    this.nombreCliente = '',
  });

  final String codigoCliente;
  final String numeroFactura;
  final String nombreCliente;

  @override
  State<CrmCliente360FacturaPage> createState() => _CrmCliente360FacturaPageState();
}

class _CrmCliente360FacturaPageState extends State<CrmCliente360FacturaPage> {
  static const _azul = Color(0xFF063B63);
  static const _azulClaro = Color(0xFF0D6EAA);
  static const _verde = Color(0xFF19C979);
  static const _fondo = Color(0xFFF4F7FA);
  static const _borde = Color(0xFFDCE5EC);

  final _db = SupabaseService.client;
  final _money = NumberFormat('#,##0.00', 'en_US');
  final _fecha = DateFormat('dd/MM/yyyy');

  bool _cargando = true;
  String? _error;
  Map<String, dynamic>? _factura;
  Map<String, dynamic>? _cliente;
  List<Map<String, dynamic>> _productosFactura = [];

  String _s(dynamic value) => value?.toString().trim() ?? '';

  double _n(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(_s(value).replaceAll(',', '')) ?? 0;
  }

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String get _nombreCliente {
    final directo = _s(_factura?['cliente']);
    if (directo.isNotEmpty) return directo;
    final razon = _s(_cliente?['razon_social']);
    if (razon.isNotEmpty) return razon;
    final nombre = _s(_cliente?['nombre']);
    if (nombre.isNotEmpty) return nombre;
    return widget.codigoCliente;
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() { _cargando = true; _error = null; });
    try {
      // No consultamos crm_facturas directamente: esa tabla está protegida
      // por RLS. El RPC de Cliente 360 ya aplica los permisos comerciales.
      final rpcResult = await _db.rpc(
        'crm_obtener_cliente_360_facturas',
        params: {
          'p_codigo_cliente': widget.codigoCliente,
          'p_vendedores_permitidos': null,
          'p_departamento': 'TODOS',
          'p_anio': DateTime.now().year,
        },
      );

      final facturas = rpcResult is List
          ? rpcResult.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];

      Map<String, dynamic>? fila;
      for (final f in facturas) {
        if (_s(f['numero_factura']) == widget.numeroFactura) {
          fila = f;
          break;
        }
      }

      if (fila == null) {
        throw Exception(
          'No se encontró la factura ${widget.numeroFactura} para el cliente ${widget.codigoCliente}.',
        );
      }

      final facturaId = fila['id'];
      final fechaFactura = _s(fila['fecha_factura']);
      final vendedorFactura = _s(fila['vendedor']);

      // No consultamos crm_factura_detalles directamente porque está protegido
      // por RLS. Reutilizamos el RPC existente de comisiones, que ya expone
      // el detalle de artículos asociado al ID exacto de la factura.
      final detalleRpc = await _db.rpc(
        'crm_obtener_comisiones_detalle',
        params: {
          'p_vendedores_permitidos': null,
          'p_vendedor': vendedorFactura.isEmpty ? 'TODOS' : vendedorFactura,
          'p_desde': fechaFactura,
          'p_hasta': fechaFactura,
          'p_limit': 1000,
        },
      );

      final detalleData = detalleRpc is List
          ? detalleRpc
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where((e) => _s(e['factura_id']) == _s(facturaId))
              .toList()
          : <Map<String, dynamic>>[];

      final factura = <String, dynamic>{
        'id': fila['id'],
        'numero_factura': fila['numero_factura'],
        'fecha_factura': fila['fecha_factura'],
        'codigo_cliente': widget.codigoCliente,
        'cliente': widget.nombreCliente,
        'monto_factura': fila['monto_calculado'],
        'vendedor': fila['vendedor'],
        'estado': fila['estado'],
        'departamento_cliente': fila['departamento_cliente'],
        'peso_calculado': fila['peso_calculado'],
      };

      if (!mounted) return;
      setState(() {
        _factura = factura;
        _cliente = null;
        _productosFactura = detalleData.map((e) {
          return <String, dynamic>{
            ...e,
            'cantidad': e['cantidad'] ?? 1,
            'cantidad_metros': e['cantidad_metros'] ?? null,
            'unidad_medida': e['unidad_medida'] ?? '',
            'monto_factura': e['monto_factura'] ?? e['base_comision'],
          };
        }).toList();
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _cargando = false; _error = e.toString(); });
    }
  }

  @override
  void initState() { super.initState(); _cargar(); }

  Widget _dato(String label, String value) => SizedBox(
    width: 190,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value.isEmpty ? '-' : value, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _azul, fontWeight: FontWeight.w800)),
      ]),
    ),
  );

  Widget _encabezado() {
    final f = _factura!;
    final fecha = _date(f['fecha_factura']);
    final monto = _n(f['monto_factura']);
    final estado = _s(f['estado']).isEmpty ? 'FACTURADA' : _s(f['estado']);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_azul, _azulClaro]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.person_search_outlined, color: Colors.white, size: 28),
          const SizedBox(width: 10),
          const Expanded(child: Text('Cliente 360° · Factura seleccionada', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: _verde.withValues(alpha: .20), borderRadius: BorderRadius.circular(20)), child: Text(estado, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 16),
        Text(_nombreCliente, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('RUC/Código: ${_s(_cliente?['ruc']).isNotEmpty ? _s(_cliente?['ruc']) : widget.codigoCliente}', style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 14),
        Wrap(spacing: 28, runSpacing: 8, children: [
          Text('Factura ${widget.numeroFactura}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          Text(fecha == null ? '-' : _fecha.format(fecha), style: const TextStyle(color: Colors.white)),
          Text('US\$ ${_money.format(monto)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
        ]),
      ]),
    );
  }

  Widget _historial() {
    final f = _factura!;
    final fecha = _date(f['fecha_factura']);
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: _borde)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.history_rounded, color: _azul), SizedBox(width: 8), Text('Historial de esta factura', style: TextStyle(color: _azul, fontSize: 17, fontWeight: FontWeight.w900))]),
          const SizedBox(height: 15),
          Wrap(spacing: 18, runSpacing: 8, children: [
            _dato('Factura', _s(f['numero_factura'])),
            _dato('Fecha', fecha == null ? '-' : _fecha.format(fecha)),
            _dato('Cliente', _nombreCliente),
            _dato('Vendedor', _s(f['vendedor'])),
            _dato('Orden de compra', _s(f['numero_orden_compra'])),
            _dato('Forma de pago', _s(f['forma_pago'])),
            _dato('Canal', _s(f['canal'])),
            _dato('Sector', _s(f['sector'])),
            _dato('Giro', _s(f['giro'])),
            _dato('Código cliente', _s(f['codigo_cliente'])),
          ]),
        ]),
      ),
    );
  }

  Widget _productos() {
    final totalMetros = _productosFactura.fold<double>(0, (sum, p) => sum + _n(p['cantidad_metros']));
    final totalPeso = _productosFactura.fold<double>(0, (sum, p) => sum + _n(p['peso_kg_cobre']));
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: _borde)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 10), child: Row(children: [
          const Icon(Icons.inventory_2_outlined, color: _verde),
          const SizedBox(width: 8),
          const Expanded(child: Text('Productos de esta factura', style: TextStyle(color: _azul, fontSize: 17, fontWeight: FontWeight.w900))),
          Text('${_productosFactura.length} ítems', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
        ])),
        const Divider(height: 1),
        if (_productosFactura.isEmpty)
          const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('Esta factura no tiene productos registrados.')))
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: const WidgetStatePropertyAll(Color(0xFFF2F6FA)),
              columns: const [
                DataColumn(label: Text('#')), DataColumn(label: Text('Código')), DataColumn(label: Text('Producto')),
                DataColumn(label: Text('Familia')), DataColumn(label: Text('Calibre')), DataColumn(label: Text('Clase')),
                DataColumn(label: Text('Cantidad')), DataColumn(label: Text('Metros')), DataColumn(label: Text('Unidad')),
                DataColumn(label: Text('Importe')),
              ],
              rows: _productosFactura.map((p) => DataRow(cells: [
                DataCell(Text(_s(p['numero_item']))),
                DataCell(Text(_s(p['codigo_articulo']))),
                DataCell(SizedBox(width: 340, child: Text(_s(p['articulo']), maxLines: 2, overflow: TextOverflow.ellipsis))),
                DataCell(Text(_s(p['familia']))),
                DataCell(Text(_s(p['calibre']))),
                DataCell(Text(_s(p['clase']))),
                DataCell(Text(_money.format(_n(p['cantidad'])))),
                DataCell(Text(_money.format(_n(p['cantidad_metros'])))),
                DataCell(Text(_s(p['unidad_medida']))),
                DataCell(Text('US\$ ${_money.format(_n(p['monto_factura']))}', style: const TextStyle(fontWeight: FontWeight.w800))),
              ])).toList(),
            ),
          ),
        Container(width: double.infinity, padding: const EdgeInsets.all(14), color: const Color(0xFFF7FAFC), child: Wrap(spacing: 28, runSpacing: 8, children: [
          Text('Metros: ${_money.format(totalMetros)}', style: const TextStyle(fontWeight: FontWeight.w800, color: _azul)),
          Text('Peso cobre: ${_money.format(totalPeso)} kg', style: const TextStyle(fontWeight: FontWeight.w800, color: _azul)),
          Text('Total factura: US\$ ${_money.format(_n(_factura?['monto_factura']))}', style: const TextStyle(fontWeight: FontWeight.w900, color: _verde)),
        ])),
      ]),
    );
  }

  Widget _errorView() => Center(child: Card(margin: const EdgeInsets.all(30), child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline, color: Colors.red, size: 44), const SizedBox(height: 10),
    const Text('No se pudo cargar la factura', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), const SizedBox(height: 8),
    Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 14),
    FilledButton.icon(onPressed: _cargar, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
  ]))));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _fondo,
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: _azul,
      elevation: 0,
      title: const Text('Cliente 360° · Factura', style: TextStyle(fontWeight: FontWeight.w900)),
      actions: [IconButton(tooltip: 'Actualizar', onPressed: _cargando ? null : _cargar, icon: const Icon(Icons.refresh))],
    ),
    body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? _errorView()
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _encabezado(), const SizedBox(height: 14), _historial(), const SizedBox(height: 14), _productos(),
                ]),
              ),
  );
}
