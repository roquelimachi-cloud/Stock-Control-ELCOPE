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
import '../../../services/sesion.dart';
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
  final _busqueda = TextEditingController();
  String? _clienteSeleccionadoCodigo;

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
  ];

  @override
  void initState() {
    super.initState();
    _indice = widget.indiceInicial.clamp(0, _items.length - 1);
  }

  @override
  void dispose() {
    _busqueda.dispose();
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
        return CrmActividadesPage(
          clienteInicial: _clienteSeleccionadoCodigo,
        );
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
        return const CrmCobranzaPage();
      case 10:
        return const ComisionesProductosPage();
      case 11:
        return const CrmReportesPage();
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
                itemCount: _items.length,
                itemBuilder: (_, i) => _sideItem(i),
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
          const SizedBox(width: 34),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 610),
              child: SizedBox(
                height: 42,
                child: TextField(
                  controller: _busqueda,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Buscar clientes, oportunidades, actividades, facturas, RUC...',
                    hintStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: .12),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.white.withValues(alpha: .22))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.white.withValues(alpha: .22))),
                  ),
                ),
              ),
            ),
          ),
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
