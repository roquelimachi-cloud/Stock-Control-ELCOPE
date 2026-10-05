import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/supabase/supabase_service.dart';
import '../../../services/sesion.dart';
import '../facturacion/facturacion_importacion_page.dart';
import '../cliente_360/crm_cliente_360_page.dart';
import '../clientes/crm_clientes_page.dart';
import '../actividades/crm_actividades_page.dart';
import '../cobranza/crm_cobranza_page.dart';
import '../comisiones/crm_comisiones_page.dart';
import '../reportes/crm_reportes_page.dart';
import '../seguimientos/crm_seguimientos_page.dart';
import '../oportunidades/crm_oportunidades_page.dart';
import '../tareas/crm_tareas_page.dart';
import '../catalogos/crm_catalogos_page.dart';
import '../visitas/crm_visitas_page.dart';

// Colores compartidos por el dashboard y sus CustomPainter/widgets auxiliares.
const Color _azul = Color(0xFF0B3B63);
const Color _azulClaro = Color(0xFF1468A8);
const Color _verde = Color(0xFF0A9B61);
const Color _fondo = Color(0xFFF4F7FA);

class CrmDashboardPage extends StatefulWidget {
  const CrmDashboardPage({super.key});

  @override
  State<CrmDashboardPage> createState() => _CrmDashboardPageState();
}

class _CrmDashboardPageState extends State<CrmDashboardPage> {
  static const _azul = Color(0xFF0B3B63);
  static const _azulClaro = Color(0xFF1468A8);
  static const _verde = Color(0xFF0A9B61);
  static const _fondo = Color(0xFFF4F7FA);

  final _db = SupabaseService.client;
  final _money = NumberFormat('#,##0.00', 'en_US');
  final _fecha = DateFormat('dd/MM/yyyy');

  bool _cargando = true;
  String? _error;

  List<Map<String, dynamic>> _facturas = [];
  Map<String, dynamic> _dashboard = {};
  String _periodo =
      '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
  String _vendedor = 'TODOS';
  String _busqueda = '';
  int _versionBusqueda = 0;

  final Map<String, bool> _permisosCrm = {};
  bool _cargandoPermisosCrm = true;

  bool _puedeVerCrm(String codigo) {
    final rol = Sesion.rol.trim().toLowerCase();
    if (rol == 'administrador' || Sesion.esAdministrador || _esGerencia) return true;
    if (codigo == 'crm_dashboard') return true;
    return _permisosCrm[codigo] == true;
  }

  Future<void> _cargarPermisosCrm() async {
    if (Sesion.idUsuario <= 0 || Sesion.esAdministrador || _esGerencia) {
      if (mounted) setState(() => _cargandoPermisosCrm = false);
      return;
    }
    try {
      final data = await _db
          .from('accesos_usuario')
          .select('puede_ver, accesos_modulos!inner(codigo)')
          .eq('usuario_id', Sesion.idUsuario);
      final permisos = <String, bool>{};
      for (final item in data as List) {
        final row = Map<String, dynamic>.from(item as Map);
        final modulo = row['accesos_modulos'];
        if (modulo is Map) {
          final codigo = modulo['codigo']?.toString().trim().toLowerCase();
          if (codigo != null && codigo.startsWith('crm_')) {
            permisos[codigo] = row['puede_ver'] == true || row['puede_ver']?.toString() == '1';
          }
        }
      }
      if (!mounted) return;
      setState(() { _permisosCrm..clear()..addAll(permisos); _cargandoPermisosCrm = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _permisosCrm.clear(); _cargandoPermisosCrm = false; });
    }
  }

  String get _rolSesion => Sesion.rol.trim().toLowerCase();

  bool get _esGerencia =>
      _rolSesion == 'gerencia' || _rolSesion == 'gerencia comercial';

  bool get _esJefatura =>
      _rolSesion == 'jefe lima' || _rolSesion == 'jefe provincia';

  String get _alcanceTexto {
    if (_esGerencia) return 'Vista global · Todos los canales';
    if (_rolSesion == 'jefe lima') return 'Equipo de Lima · Canal LIMA';
    if (_rolSesion == 'jefe provincia') {
      return 'Equipo de Provincias · Canal PROVINCIAS';
    }
    return 'Cartera propia · Canal LIMA';
  }

  // Identidad del usuario conectado: no depende del vendedor del filtro.
  String get _nombreUsuario {
    final nombre = Sesion.nombre.trim();
    if (nombre.isNotEmpty) return nombre;
    final vendedor = Sesion.vendedor.trim();
    if (vendedor.isNotEmpty) return vendedor;
    return 'Usuario';
  }

  String get _nombreCorto {
    final partes = _nombreUsuario
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    return partes.isEmpty ? 'Usuario' : partes.first;
  }

  String get _iniciales {
    final partes = _nombreUsuario
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (partes.isEmpty) return 'US';
    if (partes.length == 1) {
      final p = partes.first.toUpperCase();
      return p.substring(0, p.length >= 2 ? 2 : 1);
    }
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _cargarPermisosCrm();
    _cargarDatos();
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(
          v?.toString().replaceAll(',', '').trim() ?? '',
        ) ??
        0;
  }

  String _texto(dynamic v) => v?.toString().trim() ?? '';

  DateTime? _date(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  Future<void> _cargarDatos() async {
    if (!mounted) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final result = await _db.rpc(
        'crm_obtener_dashboard_resumen',
        params: {
          'p_periodo': _periodo,
          'p_vendedor': 'TODOS',
          'p_busqueda': _busqueda,
          'p_usuario_id': Sesion.idUsuario,
        },
      );

      if (!mounted) return;

      setState(() {
        _dashboard = result is Map
            ? Map<String, dynamic>.from(result)
            : <String, dynamic>{};
        _facturas = const <Map<String, dynamic>>[];
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString();
      });
    }
  }

  Map<String, dynamic> get _kpiData =>
      _dashboard['kpis'] is Map
          ? Map<String, dynamic>.from(_dashboard['kpis'])
          : <String, dynamic>{};

  double _dashboardAmount(dynamic value) => _num(value);

  List<Map<String, dynamic>> _jsonList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<Map<String, dynamic>> get _dashboardTopClientes =>
      _jsonList(_dashboard['top_clientes']);

  List<Map<String, dynamic>> get _dashboardVendedores =>
      _jsonList(_dashboard['por_vendedor']);

  List<Map<String, dynamic>> get _dashboardMeses =>
      _jsonList(_dashboard['mensual']);

  List<Map<String, dynamic>> get _dashboardRecientes =>
      _jsonList(_dashboard['recientes']);

  List<Map<String, dynamic>> get _dashboardActividades =>
      _jsonList(_dashboard['actividades_recientes']);

  List<String> get _periodos {
    final set = <String>{};
    for (final r in _facturas) {
      final d = _date(r['fecha_factura']);
      if (d != null) {
        set.add('${d.year}-${d.month.toString().padLeft(2, '0')}');
      }
    }
    final result = set.toList()..sort((a, b) => b.compareTo(a));
    return ['TODOS', ...result];
  }

  List<String> get _vendedores {
    final set = <String>{};
    for (final r in _facturas) {
      final v = _texto(r['vendedor']);
      if (v.isNotEmpty) set.add(v);
    }
    final result = set.toList()..sort();
    return ['TODOS', ...result];
  }

  List<Map<String, dynamic>> get _filtradas {
    final q = _busqueda.trim().toLowerCase();

    return _facturas.where((r) {
      final d = _date(r['fecha_factura']);
      final periodo = d == null
          ? ''
          : '${d.year}-${d.month.toString().padLeft(2, '0')}';

      final coincidePeriodo = _periodo == 'TODOS' || periodo == _periodo;
      final coincideVendedor =
          _vendedor == 'TODOS' || _texto(r['vendedor']) == _vendedor;

      final texto = [
        _texto(r['cliente']),
        _texto(r['codigo_cliente']),
        _texto(r['numero_factura']),
        _texto(r['vendedor']),
      ].join(' ').toLowerCase();

      return coincidePeriodo &&
          coincideVendedor &&
          (q.isEmpty || texto.contains(q));
    }).toList();
  }

  double get _facturacion => _num(_kpiData['facturacion']);

  int get _facturasCount =>
      (_kpiData['facturas'] as num?)?.toInt() ?? 0;

  int get _clientesCount =>
      (_kpiData['clientes'] as num?)?.toInt() ?? 0;

  Map<String, double> get _porCliente {
    final map = <String, double>{};
    for (final r in _dashboardTopClientes) {
      final name =
          _texto(r['cliente']).isEmpty ? 'SIN CLIENTE' : _texto(r['cliente']);
      map[name] = _dashboardAmount(r['monto']);
    }
    return map;
  }

  Map<String, double> get _porVendedor {
    final map = <String, double>{};
    for (final r in _dashboardVendedores) {
      final name =
          _texto(r['vendedor']).isEmpty ? 'SIN VENDEDOR' : _texto(r['vendedor']);
      map[name] = _dashboardAmount(r['monto']);
    }
    return map;
  }

  List<Map<String, dynamic>> get _recientes => _dashboardRecientes;

  List<Map<String, dynamic>> get _meses => _dashboardMeses;

  String _periodoLabel(String p) {
    if (p == 'TODOS') return 'Todos los períodos';
    final partes = p.split('-');
    if (partes.length != 2) return p;

    const meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    final mes = int.tryParse(partes[1]);
    if (mes == null || mes < 1 || mes > 12) return p;
    return '${meses[mes - 1]} ${partes[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      drawer: MediaQuery.sizeOf(context).width < 1100
          ? Drawer(child: _sidebar(context))
          : null,
      appBar: MediaQuery.sizeOf(context).width < 1100
          ? AppBar(
              backgroundColor: _azul,
              foregroundColor: Colors.white,
              title: const Text('CRM Comercial ELCOPE'),
            )
          : null,
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (MediaQuery.sizeOf(context).width >= 1100)
                      _sidebar(context),
                    Expanded(child: _contenido(context)),
                  ],
                ),
    );
  }

  Widget _errorView() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  const Text(
                    'No se pudo cargar la información del CRM',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _cargarDatos,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sidebar(BuildContext context) {
    return Container(
      width: 270,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF063B63), Color(0xFF052C4B)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
              child: Column(
                children: [
                  SizedBox(
                    height: 72,
                    child: Image.asset(
                      'assets/crm/images/logo_elcope.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Row(
                        children: [
                          Icon(Icons.hub_outlined, color: Colors.white, size: 42),
                          SizedBox(width: 12),
                          Text('ELCOPE\nCRM COMERCIAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, height: 1.05)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _navItem(context, Icons.home_outlined, 'Inicio CRM', selected: true),
                  if (_puedeVerCrm('crm_clientes')) _navItem(context, Icons.people_alt_outlined, 'Clientes', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CrmClientesPage()))),
                  if (_puedeVerCrm('crm_cliente_360')) _navItem(context, Icons.person_search_outlined, 'Cliente 360°', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CrmCliente360Page()))),
                  if (_puedeVerCrm('crm_actividades')) _navItem(context, Icons.fact_check_outlined, 'Actividades', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CrmActividadesPage()))),
                  if (_puedeVerCrm('crm_seguimientos')) _navItem(context, Icons.track_changes_outlined, 'Seguimientos', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CrmSeguimientosPage()))),
                  if (_puedeVerCrm('crm_oportunidades')) _navItem(context, Icons.business_center_outlined, 'Oportunidades', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CrmOportunidadesPage()))),
                  if (_puedeVerCrm('crm_tareas')) _navItem(context, Icons.task_alt_outlined, 'Tareas', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CrmTareasPage()))),
                  if (_puedeVerCrm('crm_visitas')) _navItem(context, Icons.calendar_month_outlined, 'Visitas Comerciales', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CrmVisitasPage()))),
                  if (_puedeVerCrm('crm_facturacion')) _navItem(context, Icons.receipt_long_outlined, 'Facturación', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FacturacionImportacionPage()))),
                  if (_puedeVerCrm('crm_cobranza')) _navItem(context, Icons.account_balance_wallet_outlined, 'Cobranza', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CrmCobranzaPage()))),
                  if (_puedeVerCrm('crm_comisiones')) _navItem(context, Icons.percent_outlined, 'Comisiones', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ComisionesProductosPage()))),
                  if (_puedeVerCrm('crm_reportes')) _navItem(context, Icons.bar_chart_outlined, 'Reportes', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CrmReportesPage()))),
                  if (_puedeVerCrm('crm_catalogos')) _navItem(context, Icons.menu_book_outlined, 'Catálogos CRM', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CrmCatalogosPage()))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  const Text('CABLES QUE CONECTAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, fontStyle: FontStyle.italic)),
                  const Text('TU PROGRESO', style: TextStyle(color: Color(0xFF38D88A), fontWeight: FontWeight.w900, fontSize: 16, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 5),
                  Text('Centro de Mando Comercial', style: TextStyle(color: Colors.white.withValues(alpha: .55), fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String label, {bool selected = false, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(color: selected ? const Color(0xFF0877C9) : Colors.transparent, borderRadius: BorderRadius.circular(11)),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        leading: Icon(icon, color: Colors.white, size: 21),
        title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
        onTap: onTap ?? () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label estará disponible en la siguiente etapa.'))),
      ),
    );
  }

  Widget _contenido(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 800;
    return Column(
      children: [
        _topbar(context, mobile),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargarDatos,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(mobile ? 14 : 18, 12, mobile ? 14 : 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _banner(mobile),
                  const SizedBox(height: 14),
                  _kpis(mobile),
                  const SizedBox(height: 14),
                  _filaPrincipal(mobile),
                  const SizedBox(height: 14),
                  _filaAnalitica(mobile),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _topbar(BuildContext context, bool mobile) {
    return Container(
      height: 66,
      padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 18),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE5EAF0)))),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Regresar',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: _azul, size: 27),
          ),
          if (mobile)
            IconButton(onPressed: () => Scaffold.of(context).openDrawer(), icon: const Icon(Icons.menu, color: _azul)),
          const SizedBox(width: 4),
          const Expanded(child: Text('Centro de Mando Comercial', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _azul))),
          if (!mobile)
            SizedBox(
              width: 320,
              child: TextField(
                onChanged: (v) {
                  _busqueda = v;
                  final token = ++_versionBusqueda;
                  Future.delayed(const Duration(milliseconds: 450), () {
                    if (!mounted || token != _versionBusqueda) return;
                    _cargarDatos();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar cliente, RUC, factura...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: _fondo,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          const SizedBox(width: 8),
          IconButton(tooltip: 'Actualizar', onPressed: _cargarDatos, icon: const Icon(Icons.refresh, color: _azul)),
          if (!mobile) ...[
            const SizedBox(width: 4),
            CircleAvatar(
              radius: 17,
              backgroundColor: _azul,
              child: Text(
                _iniciales,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Text(
                    _nombreUsuario,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _azul,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _alcanceTexto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Icon(Icons.keyboard_arrow_down, color: _azul),
          ],
        ],
      ),
    );
  }

  Widget _banner(bool mobile) {
    return Container(
      constraints: const BoxConstraints(minHeight: 210),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [Color(0xFF073B63), Color(0xFF075C91), Color(0xFF0A79B8)]),
      ),
      child: Stack(
        children: [
          Positioned(right: mobile ? -60 : 120, bottom: -25, child: Opacity(opacity: .12, child: Icon(Icons.cable_outlined, size: 260, color: Colors.white))),
          Positioned(right: mobile ? -5 : 28, bottom: 0, child: SizedBox(height: mobile ? 155 : 225, child: Image.asset('assets/crm/images/amperio.png', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()))),
          Padding(
            padding: EdgeInsets.fromLTRB(mobile ? 22 : 38, 25, mobile ? 150 : 330, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: mobile ? 27 : 34,
                      fontWeight: FontWeight.w900,
                    ),
                    children: [
                      const TextSpan(text: 'Bienvenido, '),
                      TextSpan(
                        text: _nombreCorto,
                        style: const TextStyle(color: Color(0xFF2FE28A)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text('Gestiona tus clientes, actividades y oportunidades\nen un solo lugar.', style: TextStyle(color: Colors.white, fontSize: mobile ? 14 : 18, height: 1.25, fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                Text(
                  _alcanceTexto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFBFF3D8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 17),
                Wrap(spacing: 12, runSpacing: 8, children: const [
                  _BannerPill(icon: Icons.bar_chart_rounded, text: 'Más ventas'),
                  _BannerPill(icon: Icons.groups_rounded, text: 'Mejores clientes'),
                  _BannerPill(icon: Icons.track_changes_rounded, text: 'Nuevas oportunidades'),
                ]),
              ],
            ),
          ),
          Positioned(top: 16, right: mobile ? 95 : 235, child: Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9), decoration: BoxDecoration(color: const Color(0xFF0A9D4D), borderRadius: BorderRadius.circular(10)), child: const Text('ELCOPE', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)))),
        ],
      ),
    );
  }

  Widget _kpis(bool mobile) {
    final cards = [
      _kpi(
        'Clientes totales',
        '$_clientesCount',
        Icons.groups_rounded,
        const Color(0xFF1475D1),
        '',
      ),
      _kpi(
        'Actividades hoy',
        '${(_kpiData['actividades_hoy'] as num?)?.toInt() ?? 0}',
        Icons.event_available_rounded,
        const Color(0xFF0A9B61),
        '',
      ),
      _kpi(
        'Oportunidades',
        '${(_kpiData['oportunidades'] as num?)?.toInt() ?? 0}',
        Icons.track_changes_rounded,
        const Color(0xFF7C4DFF),
        '',
      ),
      _kpi(
        'Facturación (Mes)',
        'US\$ ${_money.format(_facturacion)}',
        Icons.receipt_long_rounded,
        const Color(0xFFF28B18),
        '',
      ),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 1250 ? 4 : c.maxWidth >= 700 ? 2 : 1;
      return GridView.count(crossAxisCount: cols, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: mobile ? 2.9 : 2.35, children: cards);
    });
  }

  Widget _kpi(String title, String value, IconData icon, Color color, String trend) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0E7EF))),
      child: Row(children: [
        Container(width: 58, height: 58, decoration: BoxDecoration(color: color.withValues(alpha: .10), shape: BoxShape.circle), child: Icon(icon, color: color, size: 29)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF6E7681), fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _azul, fontSize: 23, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          if (trend.isNotEmpty)
            Text(
              '↗ $trend',
              style: const TextStyle(
                color: Color(0xFF08A64E),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
        ])),
        SizedBox(width: 75, height: 40, child: CustomPaint(painter: _MiniTrendPainter(color))),
      ]),
    );
  }

  Widget _filaPrincipal(bool mobile) {
    if (mobile) return Column(children: [_panelFacturacion(), const SizedBox(height: 12), _panelTopClientes(), const SizedBox(height: 12), _panelActividades()]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 5, child: _panelFacturacion()), const SizedBox(width: 12), Expanded(flex: 3, child: _panelTopClientes()), const SizedBox(width: 12), Expanded(flex: 2, child: _panelActividades())]);
  }

  Widget _filaAnalitica(bool mobile) {
    if (mobile) return Column(children: [_panelOportunidades(), const SizedBox(height: 12), _panelSectores(), const SizedBox(height: 12), _panelDocumentos()]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _panelOportunidades()), const SizedBox(width: 12), Expanded(child: _panelSectores()), const SizedBox(width: 12), Expanded(child: _panelDocumentos())]);
  }

  Widget _panelBase(String title, IconData icon, Widget child, {String? action}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0E7EF))),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: _azulClaro, size: 22), const SizedBox(width: 9), Expanded(child: Text(title, style: const TextStyle(color: _azul, fontSize: 16, fontWeight: FontWeight.w900))), if (action != null) Text(action, style: const TextStyle(color: _azulClaro, fontWeight: FontWeight.w700, fontSize: 12))]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _panelFacturacion() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7EF)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bar_chart_rounded,
                color: _azulClaro,
                size: 22,
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Evolución de facturación',
                  style: TextStyle(
                    color: _azul,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4FD),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFCCE3F7),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _resumenHeaderDato(
                      titulo: 'Monto',
                      valor: 'US\u0024 ${_money.format(_facturacion)}',
                    ),
                    const SizedBox(width: 14),
                    _resumenHeaderDato(
                      titulo: 'Facturas',
                      valor: NumberFormat('#,##0', 'en_US')
                          .format(_facturasCount),
                    ),
                    const SizedBox(width: 14),
                    _resumenHeaderDato(
                      titulo: 'Clientes',
                      valor: NumberFormat('#,##0', 'en_US')
                          .format(_clientesCount),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _periodo == 'TODOS'
                ? 'Facturación acumulada del período seleccionado'
                : 'Facturación de ${_periodoLabel(_periodo)}',
            style: const TextStyle(
              color: Colors.black45,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 245,
            child: _graficoFacturacion(),
          ),
        ],
      ),
    );
  }

  Widget _resumenHeaderDato({
    required String titulo,
    required String valor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: const TextStyle(
            color: _azul,
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _graficoFacturacion() {
    final meses = _meses;
    if (meses.isEmpty) return const Center(child: Text('Sin información de facturación.', style: TextStyle(color: Colors.grey)));
    return CustomPaint(
      painter: _SalesChartPainter(
        meses.map((e) => _num(e['monto'])).toList(),
        _azulClaro,
      ),
      child: const SizedBox.expand(),
    );
  }

  List<MapEntry<String, double>> _top(
    Map<String, double> map, [
    int n = 10,
  ]) {
    final list = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list.take(n).toList();
  }

  Widget _panelTopClientes() {
    final top = _top(_porCliente, 5);
    return _panelBase('Top 5 clientes', Icons.emoji_events_outlined, top.isEmpty ? const SizedBox(height: 210, child: Center(child: Text('Sin información para los filtros actuales.', style: TextStyle(color: Colors.grey)))) : Column(children: [for (int i=0;i<top.length;i++) _rankingRow(i+1, top[i].key, top[i].value, _facturacion)]));
  }

  Widget _rankingRow(int index, String name, double value, double total) {
    final pct = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [Container(width: 25, height: 25, alignment: Alignment.center, decoration: BoxDecoration(color: index == 1 ? _azulClaro : const Color(0xFFE9EEF5), shape: BoxShape.circle), child: Text('$index', style: TextStyle(color: index == 1 ? Colors.white : _azul, fontWeight: FontWeight.w900, fontSize: 11))), const SizedBox(width: 9), Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))), const SizedBox(width: 8), SizedBox(width: 70, child: LinearProgressIndicator(value: pct, minHeight: 7, borderRadius: BorderRadius.circular(8), backgroundColor: const Color(0xFFE9EEF4))), const SizedBox(width: 7), SizedBox(width: 72, child: Text(_money.format(value), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _azul)))]));
  }

  Widget _panelActividades() {
    final recientes = _dashboardActividades.take(5).toList();
    final hoy = (_kpiData['actividades_hoy'] as num?)?.toInt() ?? 0;

    return _panelBase(
      'Actividades próximas',
      Icons.event_note_outlined,
      recientes.isEmpty
          ? SizedBox(
              height: 210,
              child: Center(
                child: Text(
                  hoy > 0
                      ? '$hoy actividad(es) registrada(s) hoy.'
                      : 'No hay actividades registradas.',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            )
          : Column(
              children: [
                for (final r in recientes) _actividadCrmRow(r),
              ],
            ),
      action: 'Ver todas',
    );
  }

  Widget _actividadCrmRow(Map<String, dynamic> r) {
    final d = _date(r['fecha']);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 43,
            child: Text(
              d == null ? '--/--' : DateFormat('dd/MM').format(d),
              style: const TextStyle(
                color: _azul,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F4FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              size: 16,
              color: _azulClaro,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _texto(r['asunto']).isEmpty
                      ? 'Actividad'
                      : _texto(r['asunto']),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _azul,
                  ),
                ),
                Text(
                  _texto(r['tipo']),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelOportunidades() {
    return _panelBase('Oportunidades por etapa', Icons.donut_large_outlined, SizedBox(height: 175, child: Row(children: [Expanded(child: CustomPaint(painter: _DonutPainter(), child: const Center(child: Text('CRM', style: TextStyle(fontWeight: FontWeight.w900, color: _azul))))), const SizedBox(width: 10), const Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [_LegendDot(color: Color(0xFF1686E8), label: 'Prospección', value: '—'), _LegendDot(color: Color(0xFFFFA726), label: 'Cotización', value: '—'), _LegendDot(color: Color(0xFF13B77A), label: 'Negociación', value: '—'), _LegendDot(color: Color(0xFF8E5CF6), label: 'Cierre', value: '—')]))])));
  }

  Widget _panelSectores() {
    final top = _top(_porVendedor, 5);
    return _panelBase('Clientes / venta por vendedor', Icons.domain_outlined, top.isEmpty ? const SizedBox(height: 175, child: Center(child: Text('Sin información.', style: TextStyle(color: Colors.grey)))) : Column(children: [for (final e in top) _barRow(e.key, e.value)]));
  }

  Widget _barRow(String label, double value) {
    final max = _porVendedor.values.fold<double>(0, (a,b) => a>b?a:b);
    final pct = max <= 0 ? 0.0 : value / max;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [SizedBox(width: 95, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))), Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: pct, minHeight: 9, backgroundColor: const Color(0xFFE9EEF4), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF36B5C8))))), const SizedBox(width: 7), SizedBox(width: 65, child: Text(_money.format(value), textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _azul)))]));
  }

  Widget _panelDocumentos() {
    final docs = _recientes.take(3).toList();
    return _panelBase('Documentos recientes', Icons.description_outlined, docs.isEmpty ? const SizedBox(height: 175, child: Center(child: Text('Sin documentos.', style: TextStyle(color: Colors.grey)))) : Column(children: [for (final r in docs) _documentoRow(r)]), action: 'Ver todos');
  }

  Widget _documentoRow(Map<String, dynamic> r) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFFFFEFE8), borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.picture_as_pdf_outlined, color: Colors.redAccent, size: 18)), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${_texto(r['punto_factura'])}-${_texto(r['numero_factura'])}', style: const TextStyle(color: _azul, fontSize: 11, fontWeight: FontWeight.w800)), Text(_texto(r['cliente']).isEmpty ? 'Cliente' : _texto(r['cliente']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 10))])), Text(_fecha.format(_date(r['fecha_factura']) ?? DateTime.now()), style: const TextStyle(color: Colors.grey, fontSize: 10)), const SizedBox(width: 3), const Icon(Icons.more_vert, size: 17, color: Colors.grey)]));
  }
}

class _BannerPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BannerPill({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .16), border: Border.all(color: const Color(0xFF32E68C).withValues(alpha: .55)), borderRadius: BorderRadius.circular(22)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 17, color: const Color(0xFF32E68C)), const SizedBox(width: 6), Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))]));
}

class _LegendDot extends StatelessWidget {
  final Color color; final String label; final String value;
  const _LegendDot({required this.color, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 7), Expanded(child: Text(label, style: const TextStyle(fontSize: 11))), Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _azul))]));
}

class _MiniTrendPainter extends CustomPainter {
  final Color color; _MiniTrendPainter(this.color);
  @override
  void paint(Canvas c, Size s) { final p=Paint()..color=color.withValues(alpha:.18)..style=PaintingStyle.fill; final l=Paint()..color=color..strokeWidth=2..style=PaintingStyle.stroke; final path=Path()..moveTo(0,s.height*.78)..lineTo(s.width*.18,s.height*.62)..lineTo(s.width*.35,s.height*.67)..lineTo(s.width*.53,s.height*.43)..lineTo(s.width*.72,s.height*.5)..lineTo(s.width,s.height*.15)..lineTo(s.width,s.height)..lineTo(0,s.height)..close(); c.drawPath(path,p); final line=Path()..moveTo(0,s.height*.78)..lineTo(s.width*.18,s.height*.62)..lineTo(s.width*.35,s.height*.67)..lineTo(s.width*.53,s.height*.43)..lineTo(s.width*.72,s.height*.5)..lineTo(s.width,s.height*.15); c.drawPath(line,l); }
  @override bool shouldRepaint(covariant _MiniTrendPainter old) => old.color != color;
}

class _SalesChartPainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SalesChartPainter(this.values, this.color);

  String _formatoMonto(double value) {
    if (value.abs() >= 1000000) {
      return 'US\u0024 ${(value / 1000000).toStringAsFixed(2)} M';
    }
    if (value.abs() >= 1000) {
      return 'US\u0024 ${(value / 1000).toStringAsFixed(0)} K';
    }
    return 'US\u0024 ${value.toStringAsFixed(0)}';
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 0 || size.height <= 0) return;

    double maxValue = 0;
    for (final value in values) {
      if (value > maxValue) maxValue = value;
    }
    if (maxValue <= 0) maxValue = 1;

    final gridPaint = Paint()
      ..color = const Color(0xFFE8EEF5)
      ..strokeWidth = 1;

    for (int i = 0; i < 4; i++) {
      final double y = size.height * 0.12 + i * size.height * 0.25;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    final barPaint = Paint()
      ..color = color.withValues(alpha: 0.72);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    final pointPaint = Paint()..color = color;

    final path = Path();
    final linePath = Path();

    final int count = values.length;
    final double baseY = size.height * 0.80;

    // Space on top of each bar for the amount label.
    final labelStyle = TextStyle(
      color: color,
      fontSize: count > 9 ? 8.5 : 9.5,
      fontWeight: FontWeight.w900,
    );

    for (int i = 0; i < count; i++) {
      final double x = count == 1
          ? size.width / 2
          : ((size.width - 25) * i / (count - 1)) + 12;

      final double y = baseY -
          (values[i] / maxValue) * size.height * 0.62;

      final double barWidth = count == 1
          ? 30.0
          : ((size.width - 35) / count) * 0.48;

      final double barHeight =
          (baseY - y).clamp(0.0, size.height).toDouble();

      canvas.drawRect(
        Rect.fromLTWH(
          x - barWidth / 2,
          y,
          barWidth,
          barHeight,
        ),
        barPaint,
      );

      // Amount label above the bar.
      final label = _formatoMonto(values[i]);
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: labelStyle,
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 1,
        ellipsis: '…',
      )..layout(
          minWidth: 0,
          maxWidth: count > 9 ? 70 : 82,
        );

      // Never let the label leave the chart's top boundary.
      final labelY = (y - textPainter.height - 5)
          .clamp(0.0, size.height - textPainter.height)
          .toDouble();

      final labelX =
          (x - textPainter.width / 2)
              .clamp(0.0, size.width - textPainter.width)
              .toDouble();

      textPainter.paint(
        canvas,
        Offset(labelX, labelY),
      );

      if (i == 0) {
        linePath.moveTo(x, y);
        path.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
        path.lineTo(x, y);
      }

      canvas.drawCircle(
        Offset(x, y),
        4.0,
        pointPaint,
      );
    }

    final double lastX = count == 1
        ? size.width / 2
        : ((size.width - 25) * (count - 1) / (count - 1)) + 12;

    final fillPath = Path.from(path)
      ..lineTo(lastX, baseY)
      ..lineTo(12, baseY)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SalesChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color;
  }
}

class _DonutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double radius = (size.shortestSide / 2) - 8;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    const colors = <Color>[
      Color(0xFF1686E8),
      Color(0xFFFFA726),
      Color(0xFF13B77A),
      Color(0xFF8E5CF6),
    ];

    double startAngle = -1.57;
    for (final color in colors) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22;
      canvas.drawArc(rect, startAngle, 1.35, false, paint);
      startAngle += 1.52;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => false;
}
