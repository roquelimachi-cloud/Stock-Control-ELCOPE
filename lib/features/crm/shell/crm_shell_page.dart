import 'package:flutter/material.dart';

import '../dashboard/crm_dashboard_page.dart';
import '../clientes/crm_clientes_page.dart';
import '../cliente_360/crm_cliente_360_page.dart';
import '../actividades/crm_actividades_page.dart';
import '../seguimientos/crm_seguimientos_page.dart';
import '../oportunidades/crm_oportunidades_page.dart';
import '../tareas/crm_tareas_page.dart';
import '../visitas/crm_visitas_page.dart';
import '../facturacion/facturacion_importacion_page.dart';
import '../cobranza/crm_cobranza_page.dart';
import '../comisiones/crm_comisiones_page.dart';
import '../reportes/crm_reportes_page.dart';
import '../configuracion/crm_catalogos_page.dart';
import '../../../services/sesion.dart';
import '../../../services/supabase/supabase_service.dart';
import '../../../screens/login/login_page.dart';

class CrmShellPage extends StatefulWidget {
  const CrmShellPage({Key? key, this.indiceInicial = 0}) : super(key: key);

  final int indiceInicial;

  @override
  State<CrmShellPage> createState() => _CrmShellPageState();
}

class _CrmShellPageState extends State<CrmShellPage> {
  static const _azul = Color(0xFF063B63);
  static const _azul2 = Color(0xFF0A5D91);
  static const _azulActivo = Color(0xFF0877C9);
  static const _verde = Color(0xFF28D984);
  static const _fondo = Color(0xFF071F35);

  late int _indice;
  String? _clienteSeleccionadoCodigo;
  bool _cargandoPermisosMenu = true;
  bool _mostrarCobranza = false;
  final Map<String, bool> _permisosVerMenu = {};

  static const Map<int, String> _codigoModuloPorIndice = {
    1: 'crm_clientes',
    2: 'crm_cliente_360',
    3: 'crm_actividades',
    4: 'crm_seguimientos',
    5: 'crm_oportunidades',
    6: 'crm_tareas',
    7: 'crm_visitas',
    8: 'crm_facturacion',
    9: 'crm_cobranza',
    10: 'crm_comisiones',
    11: 'crm_reportes',
  };

  bool get _esAdministrador =>
      Sesion.esAdministrador ||
      Sesion.rol.trim().toLowerCase() == 'administrador';

  // Mantiene los índices originales para que las rutas de los demás módulos
  // no cambien cuando Cobranza se oculta. Mientras se consulta el permiso,
  // Cobranza no se muestra a usuarios no administradores.
  List<int> get _indicesMenuVisibles => List<int>.generate(_items.length, (i) => i)
      .where((i) {
        if (i == 12) return _esAdministrador;
        if (_esAdministrador || i == 0) return true;
        final codigo = _codigoModuloPorIndice[i];
        if (codigo == null) return true;
        // Cobranza se oculta durante la consulta y si no existe autorización.
        if (i == 9 && _cargandoPermisosMenu) return false;
        final permiso = _permisosVerMenu[codigo];
        if (permiso != null) return permiso;
        return i != 9 && !_cargandoPermisosMenu;
      })
      .toList();

  @override
  void initState() {
    super.initState();
    _indice = widget.indiceInicial.clamp(0, _items.length - 1);
    _cargarPermisosMenu();
  }

  Future<void> _cargarPermisosMenu() async {
    if (_esAdministrador) {
      if (mounted) setState(() {
        _mostrarCobranza = true;
        _cargandoPermisosMenu = false;
      });
      return;
    }

    final usuarioId = Sesion.idUsuario;
    try {
      final db = SupabaseService.client;
      final data = await db
          .from('accesos_usuario')
          .select('puede_ver, accesos_modulos!inner(codigo)')
          .eq('usuario_id', usuarioId);

      final permisos = <String, bool>{};
      for (final raw in data as List) {
        final fila = Map<String, dynamic>.from(raw as Map);
        final moduloRaw = fila['accesos_modulos'];
        if (moduloRaw == null) continue;
        final modulo = Map<String, dynamic>.from(moduloRaw as Map);
        final codigo = (modulo['codigo'] ?? '').toString().trim();
        if (codigo.isNotEmpty) permisos[codigo] = fila['puede_ver'] == true;
      }

      if (!mounted) return;
      setState(() {
        _permisosVerMenu
          ..clear()
          ..addAll(permisos);
        _mostrarCobranza = permisos['crm_cobranza'] == true;
        _cargandoPermisosMenu = false;
        if (!_mostrarCobranza && _indice == 9) _indice = 0;
        // Si la pantalla se abrió directamente en un módulo denegado, regresar al inicio.
        final codigoActual = _codigoModuloPorIndice[_indice];
        if (codigoActual != null && permisos.containsKey(codigoActual) && permisos[codigoActual] != true) {
          _indice = 0;
        }
      });
    } catch (_) {
      // No mostrar Cobranza cuando no se puede verificar su permiso.
      if (!mounted) return;
      setState(() {
        _permisosVerMenu['crm_cobranza'] = false;
        _mostrarCobranza = false;
        _cargandoPermisosMenu = false;
        if (_indice == 9) _indice = 0;
      });
    }
  }

  final _items = const [
    _CrmMenuItem(Icons.home_rounded, 'Inicio CRM'),
    _CrmMenuItem(Icons.people_alt_rounded, 'Clientes'),
    _CrmMenuItem(Icons.person_search_rounded, 'Cliente 360°'),
    _CrmMenuItem(Icons.fact_check_rounded, 'Actividades'),
    _CrmMenuItem(Icons.track_changes_rounded, 'Seguimientos'),
    _CrmMenuItem(Icons.business_center_rounded, 'Oportunidades'),
    _CrmMenuItem(Icons.task_alt_rounded, 'Tareas'),
    _CrmMenuItem(Icons.location_on_rounded, 'Visitas'),
    _CrmMenuItem(Icons.receipt_long_rounded, 'Facturación'),
    _CrmMenuItem(Icons.account_balance_wallet_rounded, 'Cobranza'),
    _CrmMenuItem(Icons.percent_rounded, 'Comisiones'),
    _CrmMenuItem(Icons.bar_chart_rounded, 'Reportes'),
    _CrmMenuItem(Icons.tune_rounded, 'Catálogos'),
  ];

  @override
  void dispose() {
    super.dispose();
  }

  void _seleccionar(int index, {String? codigoCliente}) {
    if (_indice == index && codigoCliente == null) return;
    setState(() {
      _indice = index;
      if (codigoCliente != null && codigoCliente.trim().isNotEmpty) {
        _clienteSeleccionadoCodigo = codigoCliente.trim();
      }
    });
  }

  void _abrirActividadesDelCliente(String codigoCliente) {
    _seleccionar(3, codigoCliente: codigoCliente);
  }

  void _volver() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya estás en el inicio del CRM.')),
      );
    }
  }

  void _cerrarSesion() {
    Sesion.cerrarSesion();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Widget _contenido() {
    switch (_indice) {
      case 0:
        return const CrmDashboardPage(embebido: true);
      case 1:
        return const CrmClientesPage();
      case 2:
        return CrmCliente360Page(
          codigoInicial: _clienteSeleccionadoCodigo,
          onAbrirActividades: _abrirActividadesDelCliente,
        );
      case 3:
        // Compatible con la versión de CrmActividadesPage instalada en el proyecto.
        return const CrmActividadesPage();
      case 4:
        return const CrmSeguimientosPage();
      case 5:
        return const CrmOportunidadesPage();
      case 6:
        return const CrmTareasPage();
      case 7:
        return const CrmVisitasPage();
      case 8:
        return const FacturacionImportacionPage();
      case 9:
        return (!_cargandoPermisosMenu && _mostrarCobranza)
            ? const CrmCobranzaPage()
            : const CrmDashboardPage(embebido: true);
      case 10:
        return const ComisionesProductosPage();
      case 11:
        return const CrmReportesPage();
      case 12:
        return _esAdministrador
            ? const CrmCatalogosPage()
            : const CrmDashboardPage(embebido: true);
      default:
        return const CrmDashboardPage(embebido: true);
    }
  }

  String get _nombreUsuario {
    final n = Sesion.nombre.trim();
    if (n.isNotEmpty) return n;
    final v = Sesion.vendedor.trim();
    return v.isEmpty ? 'Usuario' : v;
  }

  String get _rolTexto {
    final r = Sesion.rol.trim();
    return r.isEmpty ? 'Asesor Comercial' : r;
  }

  String get _iniciales {
    final partes = _nombreUsuario.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (partes.isEmpty) return 'US';
    if (partes.length == 1) return partes.first.substring(0, partes.first.length >= 2 ? 2 : 1).toUpperCase();
    return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final compacto = ancho < 1150;

    return Scaffold(
      backgroundColor: _fondo,
      body: Row(
        children: [
          if (!compacto) _sidebar(),
          Expanded(
            child: Column(
              children: [
                _topBar(compacto),
                Expanded(
                  child: _contenido(),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: compacto ? Drawer(child: _sidebar()) : null,
    );
  }

  Widget _sidebar() {
    return Container(
      width: 82,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_azul, Color(0xFF041A2B)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Se retira únicamente el logotipo lateral solicitado.
            const SizedBox(height: 18),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _indicesMenuVisibles.length,
                itemBuilder: (_, i) => _sideItem(_indicesMenuVisibles[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Tooltip(
                message: 'Cerrar sesión',
                child: IconButton(
                  onPressed: _cerrarSesion,
                  icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideItem(int index) {
    final item = _items[index];
    final selected = _indice == index;
    return Tooltip(
      message: item.label,
      waitDuration: const Duration(milliseconds: 350),
      child: InkWell(
        onTap: () => _seleccionar(index),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          height: 48,
          decoration: BoxDecoration(
            color: selected ? _azulActivo : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected ? const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))] : null,
          ),
          child: Icon(item.icon, color: Colors.white, size: 23),
        ),
      ),
    );
  }

  Widget _topBar(bool compacto) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: _azul,
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: .10))),
      ),
      child: Row(
        children: [
          if (compacto)
            Builder(
              builder: (context) => IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
              ),
            ),
          IconButton(
            tooltip: 'Volver',
            onPressed: _volver,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 2),
          const Text('ELCOPE', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
          const SizedBox(width: 12),
          const Text('CRM', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w400)),
          if (_indice == 12) ...[
            const SizedBox(width: 14),
            Container(width: 1, height: 26, color: Colors.white.withValues(alpha: .28)),
            const SizedBox(width: 14),
            const Text('Catálogos', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          ],
          if (_indice == 9) ...[
            const SizedBox(width: 14),
            Container(width: 1, height: 26, color: Colors.white.withValues(alpha: .28)),
            const SizedBox(width: 14),
            const Text('Cobranza', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          ],
          const Spacer(),
          if (!compacto) ...[
            // Campanita con accesos seleccionables a los módulos que contienen eventos.
            PopupMenuButton<int>(
              tooltip: 'Avisos y eventos',
              icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 29),
              onSelected: (index) => _seleccionar(index),
              itemBuilder: (_) => const [
                PopupMenuItem<int>(value: 3, child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.event_note), title: Text('Actividades y eventos')),
                ),
                PopupMenuItem<int>(value: 6, child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.task_alt), title: Text('Tareas pendientes'))),
                PopupMenuItem<int>(value: 4, child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.track_changes), title: Text('Seguimientos'))),
                PopupMenuItem<int>(value: 5, child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.business_center), title: Text('Oportunidades'))),
              ],
            ),
            const SizedBox(width: 12),
            CircleAvatar(radius: 19, backgroundColor: Colors.white, child: Text(_iniciales, style: const TextStyle(color: _azul, fontWeight: FontWeight.w900, fontSize: 11))),
            const SizedBox(width: 8),
            Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_nombreUsuario, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
              Text(_rolTexto, style: const TextStyle(color: Colors.white70, fontSize: 9)),
            ]),
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              tooltip: 'Opciones de sesión',
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
              color: Colors.white,
              onSelected: (value) {
                if (value == 'volver') _volver();
                if (value == 'cerrar') _cerrarSesion();
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(
                  value: 'volver',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.arrow_back_rounded, color: _azul),
                    title: Text('Volver'),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'cerrar',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.logout_rounded, color: Colors.red),
                    title: Text('Cerrar sesión'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CrmMenuItem {
  const _CrmMenuItem(this.icon, this.label);
  final IconData icon;
  final String label;
}
