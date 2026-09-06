
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../controllers/produccion/produccion_dashboard_controller.dart';
import '../../models/produccion/produccion_model.dart';
import '../../services/sesion.dart';
import '../../services/produccion/produccion_excel_service.dart';
import '../../services/produccion/produccion_import_service.dart';
import '../../services/produccion/produccion_dashboard_pdf_service.dart';
import '../../widgets/produccion/mis_producciones_preview.dart';
import '../../widgets/produccion/produccion_productos_preview.dart';
import '../../services/produccion/produccion_productos_pdf_service.dart';
import '../../widgets/produccion/produccion_clientes_preview.dart';
import '../../services/produccion/produccion_clientes_pdf_service.dart';
import '../../widgets/produccion/produccion_analisis_preview.dart';
import '../stock/stock_page.dart';
import '../dashboard/stock_antiguo_page.dart';
import '../dashboard/stock_antiguo_analisis_gerencial.dart';
import '../perfil/mi_perfil_page.dart';
import '../sync/sync_page.dart';
import '../usuarios/usuarios_page.dart';
import '../login/login_page.dart';

class ProduccionGerencialDashboard extends StatefulWidget {
  const ProduccionGerencialDashboard({super.key});

  @override
  State<ProduccionGerencialDashboard> createState() =>
      _ProduccionGerencialDashboardState();
}

class _ProduccionGerencialDashboardState
    extends State<ProduccionGerencialDashboard> {
  final controller = ProduccionDashboardController();
  final excelService = ProduccionExcelService();
  final importService = ProduccionImportService();
  final moneda = NumberFormat('#,##0.00', 'en_US');
  final numero = NumberFormat('#,##0.00', 'en_US');

  int _tab = 0;

  final TextEditingController _busquedaController =
      TextEditingController();
  String _asesor = 'TODOS';
  String _clase = 'TODAS';
  String _canal = 'TODOS';
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;

  @override
  void initState() {
    super.initState();
    _busquedaController.addListener(_actualizarFiltros);
    controller.addListener(_actualizarFiltros);
    controller.cargar();
  }

  @override
  void dispose() {
    _busquedaController.removeListener(_actualizarFiltros);
    _busquedaController.dispose();
    controller.removeListener(_actualizarFiltros);
    controller.dispose();
    super.dispose();
  }

  void _actualizarFiltros() {
    if (mounted) setState(() {});
  }

  // El dashboard de producción está disponible para todos los usuarios.
  // ProduccionMisOpService controla qué registros puede visualizar cada usuario:
  // Gerencia = todo; Jefaturas = vendedores autorizados; usuario normal = su vendedor.
  bool get _esGerencial => true;

  String _money(double v) => 'US\$ ${moneda.format(v)}';
  String _num(double v) => numero.format(v);

  double _valor(List<ProduccionModel> data) =>
      data.fold(0.0, (s, e) => s + (e.valorNeto ?? 0));

  double _cobre(List<ProduccionModel> data) =>
      data.fold(0.0, (s, e) => s + (e.pesoCobre ?? 0));

  void _abrirAnalisisPreview(
    BuildContext context,
    String titulo,
    List<_Fila> rows,
  ) {
    if (rows.isEmpty) return;
    // La vista previa siempre recibe todos los registros visibles.
    // ProduccionMisOpService ya aplica los permisos por usuario/área:
    // Gerencia/Administrador: todos; Jefe Lima/Provincia: solo su área.
    final ordenadas = [...rows]..sort((a, b) => b.valor.compareTo(a.valor));

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProduccionAnalisisPreview(
          titulo: titulo,
          items: List.generate(
            ordenadas.length,
            (i) {
              final r = ordenadas[i];
              return ProduccionAnalisisPreviewItem(
                posicion: i + 1,
                nombre: r.nombre,
                op: r.op,
                peso: r.cobre,
                valor: r.valor,
              );
            },
          ),
        ),
      ),
    );
  }

  Map<String, _Acum> _agrupar(
    List<ProduccionModel> data,
    String Function(ProduccionModel) key,
  ) {
    final map = <String, _Acum>{};
    for (final e in data) {
      final nombre = key(e).trim().isEmpty ? 'SIN DATO' : key(e).trim();
      final a = map.putIfAbsent(nombre, _Acum.new);
      a.op++;
      a.valor += e.valorNeto ?? 0;
      a.cobre += e.pesoCobre ?? 0;
    }
    return map;
  }

  List<_Fila> _ranking(
    List<ProduccionModel> data,
    String Function(ProduccionModel) key,
  ) {
    final map = _agrupar(data, key);
    final lista = map.entries
        .map((e) => _Fila(e.key, e.value.op, e.value.valor, e.value.cobre))
        .toList();
    lista.sort((a, b) => b.valor.compareTo(a.valor));
    return lista;
  }

  List<ProduccionModel> get _datos => controller.producciones;

  List<String> get _asesoresDisponibles => _opciones(
        (e) => e.representante,
        'TODOS',
      );

  List<String> get _clasesDisponibles => _opciones(
        (e) => e.clase ?? '',
        'TODAS',
      );

  List<String> get _canalesDisponibles => _opciones(
        (e) => e.canal,
        'TODOS',
      );

  List<String> _opciones(
    String Function(ProduccionModel) selector,
    String todos,
  ) {
    final valores = _datos
        .map(selector)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [todos, ...valores];
  }

  List<ProduccionModel> get _datosFiltrados {
    final texto = _busquedaController.text.trim().toLowerCase();

    return _datos.where((e) {
      final coincideTexto = texto.isEmpty ||
          e.numeroProduccion.toLowerCase().contains(texto) ||
          e.cliente.toLowerCase().contains(texto) ||
          (e.articulo ?? '').toLowerCase().contains(texto) ||
          e.representante.toLowerCase().contains(texto);

      final coincideAsesor =
          _asesor == 'TODOS' || e.representante.trim() == _asesor;
      final coincideClase =
          _clase == 'TODAS' || (e.clase ?? '').trim() == _clase;
      final coincideCanal =
          _canal == 'TODOS' || e.canal.trim() == _canal;

      final fecha = e.fechaProduccion;
      final coincideDesde =
          _fechaDesde == null ||
          (fecha != null &&
              !DateTime(fecha.year, fecha.month, fecha.day)
                  .isBefore(DateTime(
                _fechaDesde!.year,
                _fechaDesde!.month,
                _fechaDesde!.day,
              )));
      final coincideHasta =
          _fechaHasta == null ||
          (fecha != null &&
              !DateTime(fecha.year, fecha.month, fecha.day)
                  .isAfter(DateTime(
                _fechaHasta!.year,
                _fechaHasta!.month,
                _fechaHasta!.day,
              )));

      return coincideTexto &&
          coincideAsesor &&
          coincideClase &&
          coincideCanal &&
          coincideDesde &&
          coincideHasta;
    }).toList();
  }


  Future<void> _imprimirDashboard(List<ProduccionModel> data) async {
    if (data.isEmpty) return;

    await ProduccionDashboardPdfService.imprimir(
      context: context,
      data: data,
      titulo: 'PRODUCCIÓN - DASHBOARD',
      filtroAsesor: _asesor,
      filtroClase: _clase,
      filtroCanal: _canal,
      fechaDesde: _fechaDesde,
      fechaHasta: _fechaHasta,
    );
  }


  List<ProduccionProductoResumen> _resumenProductos(
    List<ProduccionModel> data,
  ) {
    final map = <String, ProduccionProductoResumen>{};

    for (final e in data) {
      final nombre = (e.articulo ?? 'SIN ARTÍCULO').trim();
      final key = nombre.isEmpty ? 'SIN ARTÍCULO' : nombre;
      final actual = map[key];

      if (actual == null) {
        map[key] = ProduccionProductoResumen(
          producto: key,
          ordenes: 1,
          pesoCobre: e.pesoCobre ?? 0,
          valorNeto: e.valorNeto ?? 0,
        );
      } else {
        actual.ordenes++;
        actual.pesoCobre += e.pesoCobre ?? 0;
        actual.valorNeto += e.valorNeto ?? 0;
      }
    }

    final resultado = map.values.toList()
      ..sort((a, b) => b.valorNeto.compareTo(a.valorNeto));

    return resultado;
  }

  List<ProduccionClienteResumen> _resumenClientes(
    List<ProduccionModel> data,
  ) {
    final map = <String, ProduccionClienteResumen>{};

    for (final e in data) {
      final nombre = e.cliente.trim().isEmpty ? 'SIN CLIENTE' : e.cliente.trim();
      final actual = map[nombre];

      if (actual == null) {
        map[nombre] = ProduccionClienteResumen(
          cliente: nombre,
          ordenes: 1,
          pesoCobre: e.pesoCobre ?? 0,
          valorNeto: e.valorNeto ?? 0,
        );
      } else {
        actual.ordenes++;
        actual.pesoCobre += e.pesoCobre ?? 0;
        actual.valorNeto += e.valorNeto ?? 0;
      }
    }

    final resultado = map.values.toList()
      ..sort((a, b) => b.valorNeto.compareTo(a.valorNeto));

    return resultado;
  }

  void _abrirTodosLosClientes(BuildContext context) {
    final clientes = _resumenClientes(_datosFiltrados);
    if (clientes.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProduccionClientesPreview(
          clientes: clientes,
        ),
      ),
    );
  }

  Future<void> _imprimirTodosLosClientes() async {
    final clientes = _resumenClientes(_datosFiltrados);
    if (clientes.isEmpty) return;

    await ProduccionClientesPdfService.imprimir(
      context: context,
      clientes: clientes,
      titulo: 'PRODUCCIÓN POR CLIENTE',
    );
  }

  void _abrirTodosLosProductos(BuildContext context) {
    final productos = _resumenProductos(_datosFiltrados);
    if (productos.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProduccionProductosPreview(
          productos: productos,
        ),
      ),
    );
  }

  Future<void> _imprimirTodosLosProductos() async {
    final productos = _resumenProductos(_datosFiltrados);
    if (productos.isEmpty) return;

    await ProduccionProductosPdfService.imprimir(
      context: context,
      productos: productos,
      titulo: 'PRODUCCIÓN POR PRODUCTO',
    );
  }

  void _abrirTodasLasProducciones(BuildContext context, List<ProduccionModel> data) {
    if (data.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MisProduccionesPreview(
          producciones: data,
        ),
      ),
    );
  }

  void _abrirOrden(BuildContext context, List<ProduccionModel> data, String numeroOP) {
    final orden = data
        .where((item) => item.numeroProduccion == numeroOP)
        .toList();

    if (orden.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MisProduccionesPreview(
          producciones: orden,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_esGerencial) {
      return const Scaffold(
        body: Center(child: Text('DASHBOARD GERENCIAL NO DISPONIBLE')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xfff4f8f6),
      drawer: _menuLateral(context),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.cargando) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xff00864a)),
            );
          }
          return _buildDashboard(context);
        },
      ),
    );
  }

  Widget _menuLateral(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.indigo,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/images/logo_mr.png',
                    width: 70,
                    height: 70,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.business,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    Sesion.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    Sesion.rol,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.dashboard),
                    title: const Text('Dashboard'),
                    onTap: () {
                      Navigator.pop(context);
                      if (Navigator.canPop(context)) Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.inventory_2),
                    title: const Text('Control de Stock'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StockPage()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('Stock Antiguo (> 30 días)'),
                    subtitle: Text(
                      Sesion.rol == 'Gerencia' || Sesion.rol == 'Jefe Lima' || Sesion.rol == 'Jefe Provincia'
                          ? 'Análisis gerencial'
                          : 'Control de permanencia',
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      if (Sesion.rol == 'Gerencia' || Sesion.rol == 'Jefe Lima' || Sesion.rol == 'Jefe Provincia') {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const StockAntiguoAnalisisGerencialPage()));
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const StockAntiguoPage()));
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.factory),
                    title: const Text('Producción Pendiente'),
                    subtitle: const Text('Dashboard de Producción'),
                    onTap: () => Navigator.pop(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Mi Perfil'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MiPerfilPage()));
                    },
                  ),
                  if (Sesion.esAdministrador)
                    ListTile(
                      leading: const Icon(Icons.sync),
                      title: const Text('Sincronizar Excel'),
                      onTap: () async {
                        Navigator.pop(context);
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncPage()));
                        if (!mounted) return;
                        await controller.cargar();
                      },
                    ),
                  if (Sesion.esAdministrador)
                    ListTile(
                      leading: const Icon(Icons.people),
                      title: const Text('Usuarios'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const UsuariosPage()));
                      },
                    ),
                  if (Sesion.esAdministrador)
                    ListTile(
                      leading: const Icon(Icons.settings),
                      title: const Text('Configuración'),
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Módulo en desarrollo')));
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                Sesion.cerrarSesion();
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final data = _datosFiltrados;
    final ancho = MediaQuery.sizeOf(context).width;
    final movil = ancho < 900;
    final totalValor = _valor(data);
    final totalCobre = _cobre(data);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(movil ? 12 : 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, movil),
            const SizedBox(height: 14),
            _tabs(movil),
            const SizedBox(height: 14),
            _filtros(context, movil),
            const SizedBox(height: 14),
            _kpis(data, movil),
            const SizedBox(height: 14),
            if (_tab == 0) ...[
              _topCharts(data, totalValor, totalCobre, movil),
              const SizedBox(height: 14),
              _secondRow(data, movil),
              const SizedBox(height: 14),
              _rankings(data, movil),
              const SizedBox(height: 14),
              _ultimasOrdenes(data, movil),
            ] else ...[
              _analisisSeleccionado(data, movil),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _importarExcel() async {
    try {
      final excel = await excelService.seleccionarExcel();

      if (excel == null) return;

      final lista = excelService.leerProduccion(excel);
      final cantidad = await importService.importar(lista);

      await controller.cargar();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            'Se importaron $cantidad registros correctamente.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Error al importar Excel: $e'),
        ),
      );
    }
  }

  Widget _header(BuildContext context, bool movil) {
    final titulo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRODUCCIÓN - DASHBOARD',
          softWrap: true,
          style: TextStyle(
            fontSize: movil ? 22 : 28,
            fontWeight: FontWeight.w800,
            color: const Color(0xff006b3c),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Análisis gerencial por asesor, clase, canal, cliente, peso, valor y tiempo.',
          softWrap: true,
          style: TextStyle(color: Colors.grey.shade700),
        ),
      ],
    );

    final botonImportarExcel = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xff00864a),
      ),
      onPressed: Sesion.esAdministrador ? _importarExcel : null,
      icon: const Icon(Icons.upload_file),
      label: const Text('IMPORTAR EXCEL'),
    );

    final botonImprimir = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xff2457c5),
      ),
      onPressed: _datosFiltrados.isEmpty
          ? null
          : () => _imprimirDashboard(_datosFiltrados),
      icon: const Icon(Icons.print_outlined),
      label: const Text('IMPRIMIR DASHBOARD'),
    );

    if (movil) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffdcebe3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: 'Volver',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Color(0xff2457c5),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xffe5f6ed),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.factory_outlined,
                    color: Color(0xff00864a),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: titulo),
              ],
            ),
            const SizedBox(height: 14),
            if (Sesion.esAdministrador) ...[
              SizedBox(
                width: double.infinity,
                child: botonImportarExcel,
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: botonImprimir,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffdcebe3)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xff2457c5),
              size: 28,
            ),
          ),
          const SizedBox(width: 2),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xffe5f6ed),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.factory_outlined,
              color: Color(0xff00864a),
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: titulo),
          if (Sesion.esAdministrador) ...[
            botonImportarExcel,
            const SizedBox(width: 8),
          ],
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff00864a),
            ),
            onPressed: controller.cargar,
            icon: const Icon(Icons.refresh),
            label: const Text('ACTUALIZAR'),
          ),
          const SizedBox(width: 8),
          botonImprimir,
        ],
      ),
    );
  }

  Widget _filtros(BuildContext context, bool movil) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffdcebe3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt_outlined,
                  color: Color(0xff00864a)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'FILTROS DE PRODUCCIÓN',
                  style: TextStyle(
                    color: Color(0xff006b3c),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _limpiarFiltros,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Limpiar'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final ancho = constraints.maxWidth;
              final columnas = ancho >= 1200 ? 5 : ancho >= 750 ? 3 : 1;
              final itemWidth = columnas == 1
                  ? ancho
                  : (ancho - ((columnas - 1) * 10)) / columnas;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: TextField(
                      controller: _busquedaController,
                      decoration: const InputDecoration(
                        labelText: 'Buscar OP, cliente o artículo',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _dropdown(
                      label: 'Asesor',
                      value: _asesor,
                      items: _asesoresDisponibles,
                      onChanged: (v) => setState(() => _asesor = v!),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _dropdown(
                      label: 'Clase',
                      value: _clase,
                      items: _clasesDisponibles,
                      onChanged: (v) => setState(() => _clase = v!),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _dropdown(
                      label: 'Canal',
                      value: _canal,
                      items: _canalesDisponibles,
                      onChanged: (v) => setState(() => _canal = v!),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => _seleccionarFechas(context),
                      icon: const Icon(Icons.date_range),
                      label: Text(_textoFechas()),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Mostrando ${_datosFiltrados.length} de ${_datos.length} órdenes',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : items.first,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: items
          .map((e) => DropdownMenuItem<String>(
                value: e,
                child: Text(e, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  String _textoFechas() {
    if (_fechaDesde == null && _fechaHasta == null) return 'Todas las fechas';
    final desde = _fechaDesde == null
        ? '--/--/----'
        : DateFormat('dd/MM/yyyy').format(_fechaDesde!);
    final hasta = _fechaHasta == null
        ? '--/--/----'
        : DateFormat('dd/MM/yyyy').format(_fechaHasta!);
    return '$desde → $hasta';
  }

  Future<void> _seleccionarFechas(BuildContext context) async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _fechaDesde != null && _fechaHasta != null
          ? DateTimeRange(start: _fechaDesde!, end: _fechaHasta!)
          : null,
      helpText: 'SELECCIONAR PERÍODO DE PRODUCCIÓN',
      cancelText: 'CANCELAR',
      confirmText: 'APLICAR',
    );

    if (rango == null) return;

    setState(() {
      _fechaDesde = rango.start;
      _fechaHasta = rango.end;
    });
  }

  void _limpiarFiltros() {
    setState(() {
      _busquedaController.clear();
      _asesor = 'TODOS';
      _clase = 'TODAS';
      _canal = 'TODOS';
      _fechaDesde = null;
      _fechaHasta = null;
    });
  }

  Widget _tabs(bool movil) {
    const nombres = [
      ('Resumen General', Icons.dashboard_outlined),
      ('Por Asesor', Icons.person_outline),
      ('Por Clase', Icons.category_outlined),
      ('Por Canal', Icons.account_tree_outlined),
      ('Por Cliente', Icons.groups_outlined),
      ('Tiempo de Producción', Icons.schedule_outlined),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(nombres.length, (i) {
          final activo = _tab == i;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: activo,
              label: Text(nombres[i].$1),
              avatar: Icon(nombres[i].$2, size: 18),
              selectedColor: const Color(0xff00864a),
              labelStyle: TextStyle(
                color: activo ? Colors.white : const Color(0xff184b35),
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => setState(() => _tab = i),
            ),
          );
        }),
      ),
    );
  }

  Widget _kpis(List<ProduccionModel> data, bool movil) {
    final valor = _valor(data);
    final cobre = _cobre(data);
    final clientes = data.map((e) => e.cliente.trim()).where((e) => e.isNotEmpty).toSet().length;
    final asesores = data.map((e) => e.representante.trim()).where((e) => e.isNotEmpty).toSet().length;
    final canales = data.map((e) => e.canal.trim()).where((e) => e.isNotEmpty).toSet().length;

    final cards = [
      _Kpi('ÓRDENES DE PRODUCCIÓN', '${data.length}', 'Total generado', Icons.assignment_outlined),
      _Kpi('VALOR DE PRODUCCIÓN', _money(valor), 'Valor neto total', Icons.attach_money),
      _Kpi('PESO DE COBRE', '${_num(cobre)} kg', 'Peso de cobre', Icons.layers_outlined),
      _Kpi('CLIENTES', '$clientes', 'Clientes atendidos', Icons.groups_outlined),
      _Kpi('ASESORES', '$asesores', 'Representantes', Icons.person_outline),
      _Kpi('CANALES', '$canales', 'Canales registrados', Icons.account_tree_outlined),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: movil ? 2 : 6,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: movil ? 1.35 : 1.35,
      ),
      itemBuilder: (_, i) => _kpiCard(cards[i]),
    );
  }

  Widget _kpiCard(_Kpi k) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffdcebe3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(k.icon, color: const Color(0xff00864a)),
          const SizedBox(height: 8),
          Text(k.titulo, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              k.valor,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xff006b3c),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(k.subtitulo, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _topCharts(
    List<ProduccionModel> data,
    double totalValor,
    double totalCobre,
    bool movil,
  ) {
    // El dashboard principal conserva Top 5.
    // La VISTA PREVIA de Asesor recibe el ranking completo mediante _ranking(data,...).
    final asesores = _ranking(data, (e) => e.representante).take(5).toList();
    final asesoresTodos = _ranking(data, (e) => e.representante).toList();
    final clases = _ranking(data, (e) => e.clase ?? 'SIN CLASE').toList();
    final canales = _ranking(data, (e) => e.canal).toList();

    final cards = [
      _panel(
        'PRODUCCIÓN POR ASESOR',
        'Valor Neto (US\$) + Peso de cobre (kg)',
        _barDual(asesores),
        movil,
        height: 330,
        action: OutlinedButton.icon(
          icon: const Icon(Icons.visibility_outlined, size: 16),
          label: const Text('VISTA PREVIA'),
          onPressed: asesores.isEmpty
              ? null
              : () => _abrirAnalisisPreview(
                    context,
                    'PRODUCCIÓN POR ASESOR',
                    asesoresTodos,
                  ),
        ),
      ),
      _panel(
        'PRODUCCIÓN POR CLASE',
        'Valor Neto (US\$) + Peso de cobre (kg)',
        _barDual(clases),
        movil,
        height: 330,
        action: OutlinedButton.icon(
          icon: const Icon(Icons.visibility_outlined, size: 16),
          label: const Text('VISTA PREVIA'),
          onPressed: clases.isEmpty
              ? null
              : () => _abrirAnalisisPreview(
                    context,
                    'PRODUCCIÓN POR CLASE',
                    clases,
                  ),
        ),
      ),
      _panel(
        'PRODUCCIÓN POR CANAL',
        'Valor Neto (US\$) + Peso de cobre (kg)',
        _barDual(canales),
        movil,
        height: 330,
        action: OutlinedButton.icon(
          icon: const Icon(Icons.visibility_outlined, size: 16),
          label: const Text('VISTA PREVIA'),
          onPressed: canales.isEmpty
              ? null
              : () => _abrirAnalisisPreview(
                    context,
                    'PRODUCCIÓN POR CANAL',
                    canales,
                  ),
        ),
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: movil ? 1 : 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      mainAxisExtent: movil ? 430 : 430,
      children: cards,
    );
  }

  Widget _barDual(List<_Fila> data) {
    if (data.isEmpty) return const Center(child: Text('Sin datos'));

    final maxValor = data.map((e) => e.valor).fold(0.0, (a, b) => a > b ? a : b);
    final maxCobre = data.map((e) => e.cobre).fold(0.0, (a, b) => a > b ? a : b);

    final miles = NumberFormat('#,##0.00', 'en_US');

    return SfCartesianChart(
      primaryXAxis: const CategoryAxis(
        labelRotation: -35,
        majorGridLines: MajorGridLines(width: 0),
      ),
      primaryYAxis: NumericAxis(
        majorGridLines: const MajorGridLines(width: .5),
        numberFormat: NumberFormat('#,##0.00', 'en_US'),
      ),
      legend: const Legend(isVisible: true, position: LegendPosition.bottom),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        builder: (
          dynamic dataPoint,
          dynamic point,
          dynamic series,
          int pointIndex,
          int seriesIndex,
        ) {
          final item = data[pointIndex];
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xff263238),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Valor Neto: US\$ ${miles.format(item.valor)}',
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  'Peso de cobre: ${miles.format(item.cobre)} kg',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        },
      ),
      // Las etiquetas se definen por serie porque DataLabelRenderArgs
      // de Syncfusion 30.2.7 no expone seriesIndex.
      series: <CartesianSeries<_Fila, String>>[
        ColumnSeries<_Fila, String>(
          name: 'Valor Neto (US\$)',
          dataSource: data,
          xValueMapper: (e, _) => e.nombre,
          yValueMapper: (e, _) =>
              maxValor == 0 ? 0 : (e.valor / maxValor) * (maxCobre == 0 ? 1 : maxCobre),
          color: const Color(0xff2457c5),
          dataLabelMapper: (e, _) => 'US\$ ${miles.format(e.valor)}',
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
            textStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
        ColumnSeries<_Fila, String>(
          name: 'Peso de cobre (kg)',
          dataSource: data,
          xValueMapper: (e, _) => e.nombre,
          yValueMapper: (e, _) => maxCobre == 0 ? 0 : e.cobre,
          color: const Color(0xff00864a),
          dataLabelMapper: (e, _) => '${miles.format(e.cobre)} kg',
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
            textStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _secondRow(List<ProduccionModel> data, bool movil) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: movil ? 1 : 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      mainAxisExtent: movil ? 430 : 430,
      children: [
        _panel(
          'DISTRIBUCIÓN POR ESTADO',
          'Órdenes',
          _donut(data, (e) => e.estado),
          movil,
          height: 330,
        ),
        _panel(
          'PRODUCCIÓN POR ZONA',
          'Lima / Provincia',
          _donut(data, (e) => e.canal.toUpperCase().contains('PROV') ? 'PROVINCIA' : 'LIMA'),
          movil,
          height: 330,
        ),
        _panel(
          'TIEMPO DE PRODUCCIÓN',
          'Días entre producción y entrega estimada',
          _tiempo(data),
          movil,
          height: 330,
        ),
      ],
    );
  }

  Widget _donut(List<ProduccionModel> data, String Function(ProduccionModel) key) {
    final map = _agrupar(data, key);
    final values = map.entries.map((e) => _Donut(e.key, e.value.op.toDouble())).toList();
    if (values.isEmpty) return const Center(child: Text('Sin datos'));

    return SfCircularChart(
      legend: const Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CircularSeries<_Donut, String>>[
        DoughnutSeries<_Donut, String>(
          dataSource: values,
          xValueMapper: (e, _) => e.nombre,
          yValueMapper: (e, _) => e.valor,
          innerRadius: '62%',
          dataLabelSettings: const DataLabelSettings(isVisible: true),
        ),
      ],
    );
  }

  Widget _tiempo(List<ProduccionModel> data) {
    final buckets = {'<= 1 día': 0, '2 - 3 días': 0, '4 - 7 días': 0, '8 - 15 días': 0, '> 15 días': 0};
    for (final e in data) {
      final inicio = e.fechaProduccion;
      final fin = e.fechaEntregaEstimada;
      if (inicio == null || fin == null) continue;
      final d = fin.difference(inicio).inDays;
      if (d <= 1) {
        buckets['<= 1 día'] = buckets['<= 1 día']! + 1;
      } else if (d <= 3) {
        buckets['2 - 3 días'] = buckets['2 - 3 días']! + 1;
      } else if (d <= 7) {
        buckets['4 - 7 días'] = buckets['4 - 7 días']! + 1;
      } else if (d <= 15) {
        buckets['8 - 15 días'] = buckets['8 - 15 días']! + 1;
      } else {
        buckets['> 15 días'] = buckets['> 15 días']! + 1;
      }
    }

    final dataChart = buckets.entries.map((e) => _Donut(e.key, e.value.toDouble())).toList();
    return SfCartesianChart(
      primaryXAxis: const CategoryAxis(majorGridLines: MajorGridLines(width: 0)),
      primaryYAxis: const NumericAxis(),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries<_Donut, String>>[
        ColumnSeries<_Donut, String>(
          dataSource: dataChart,
          xValueMapper: (e, _) => e.nombre,
          yValueMapper: (e, _) => e.valor,
          color: const Color(0xff00864a),
          dataLabelSettings: const DataLabelSettings(isVisible: true),
        ),
      ],
    );
  }

  Widget _rankings(List<ProduccionModel> data, bool movil) {
    final productos =
        _ranking(data, (e) => e.articulo ?? 'SIN ARTÍCULO').take(5).toList();
    final clientes = _ranking(data, (e) => e.cliente).take(5).toList();
    final canales = _ranking(data, (e) => e.canal).take(5).toList();

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: movil ? 1 : 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      mainAxisExtent: movil ? 480 : 480,
      children: [
        _rankingPanel('TOP 5 PRODUCTOS', productos, true),
        _rankingPanel('TOP 5 CLIENTES', clientes, false),
        _rankingPanel('TOP 5 CANALES', canales, false),
      ],
    );
  }

  Widget _rankingPanel(String title, List<_Fila> rows, bool producto) {
    final esTopProductos = producto;
    final esTopClientes = !producto && title == 'TOP 5 CLIENTES';

    final lista = ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final r = rows[i];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xffe5f6ed),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: Color(0xff00864a),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Valor Neto ${_money(r.valor)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xff006b3c),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_num(r.cobre)} kg',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    final botones = (esTopProductos || esTopClientes)
        ? Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('VISTA PREVIA'),
                    onPressed: rows.isEmpty
                        ? null
                        : () {
                            if (esTopProductos) {
                              _abrirTodosLosProductos(context);
                            } else {
                              _abrirTodosLosClientes(context);
                            }
                          },
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff00864a),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('IMPRIMIR'),
                    onPressed: rows.isEmpty
                        ? null
                        : (esTopProductos
                            ? _imprimirTodosLosProductos
                            : _imprimirTodosLosClientes),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          )
        : const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffdcebe3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xff006b3c),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Dinero (US\$) • Peso de cobre (kg)',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          botones,
          SizedBox(
            height: esTopProductos || esTopClientes ? 315 : 350,
            width: double.infinity,
            child: SingleChildScrollView(
              child: lista,
            ),
          ),
        ],
      ),
    );
  }

    Widget _ultimasOrdenes(List<ProduccionModel> data, bool movil) {
    final rows = [...data]..sort((a, b) {
      final da = a.fechaProduccion ?? DateTime(1900);
      final db = b.fechaProduccion ?? DateTime(1900);
      return db.compareTo(da);
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffdcebe3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ÚLTIMAS ÓRDENES DE PRODUCCIÓN',
                      style: TextStyle(
                        color: Color(0xff006b3c),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Todas las producciones • desplaza vertical y horizontalmente',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.visibility_outlined, size: 17),
                label: const Text('VISTA PREVIA'),
                onPressed: rows.isEmpty
                    ? null
                    : () => _abrirTodasLasProducciones(context, rows),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 420,
            width: double.infinity,
            child: Scrollbar(
              thumbVisibility: !movil,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    showCheckboxColumn: false,
                    headingRowColor:
                        const WidgetStatePropertyAll(Color(0xffe5f6ed)),
                    columns: const [
                      DataColumn(label: Text('OP')),
                      DataColumn(label: Text('Fecha')),
                      DataColumn(label: Text('Cliente')),
                      DataColumn(label: Text('Artículo')),
                      DataColumn(label: Text('Clase')),
                      DataColumn(label: Text('Asesor')),
                      DataColumn(label: Text('Canal')),
                      DataColumn(label: Text('Cantidad')),
                      DataColumn(label: Text('Peso Cobre (kg)')),
                      DataColumn(label: Text('Valor Neto (US\$)')),
                      DataColumn(label: Text('Estado')),
                    ],
                    rows: rows.map((e) {
                      return DataRow(
                        onSelectChanged: (_) =>
                            _abrirOrden(context, data, e.numeroProduccion),
                        cells: [
                          DataCell(Text(e.numeroProduccion)),
                          DataCell(
                            Text(
                              e.fechaProduccion == null
                                  ? '-'
                                  : DateFormat('dd/MM/yyyy')
                                      .format(e.fechaProduccion!),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 180,
                              child: Text(e.cliente, maxLines: 2),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 260,
                              child: Text(e.articulo ?? '-', maxLines: 2),
                            ),
                          ),
                          DataCell(Text(e.clase ?? '-')),
                          DataCell(Text(e.representante)),
                          DataCell(Text(e.canal)),
                          DataCell(Text(_num(e.cantidadTotal ?? 0))),
                          DataCell(Text(_num(e.pesoCobre ?? 0))),
                          DataCell(Text(_money(e.valorNeto ?? 0))),
                          DataCell(_estadoBadge(e.estado)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _estadoBadge(String estado) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xffe5f6ed),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        estado,
        style: const TextStyle(
          color: Color(0xff006b3c),
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _analisisSeleccionado(List<ProduccionModel> data, bool movil) {
    late String titulo;
    late String Function(ProduccionModel) key;

    switch (_tab) {
      case 1:
        titulo = 'PRODUCCIÓN POR ASESOR';
        key = (e) => e.representante;
        break;
      case 2:
        titulo = 'PRODUCCIÓN POR CLASE';
        key = (e) => e.clase ?? 'SIN CLASE';
        break;
      case 3:
        titulo = 'PRODUCCIÓN POR CANAL';
        key = (e) => e.canal;
        break;
      case 4:
        titulo = 'PRODUCCIÓN POR CLIENTE';
        key = (e) => e.cliente;
        break;
      default:
        titulo = 'TIEMPO DE PRODUCCIÓN';
        key = (e) => e.numeroProduccion;
    }

    if (_tab == 5) {
      return _panel(
        titulo,
        'FechaProd → FechaEntregaEstimada',
        _tiempo(data),
        movil,
      );
    }

    final rows = _ranking(data, key);
    return _panel(
      titulo,
      'Peso de cobre (kg) + Valor (US\$)',
      Scrollbar(
        thumbVisibility: !movil,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
                  const WidgetStatePropertyAll(Color(0xffe5f6ed)),
              columns: const [
                DataColumn(label: Text('N°')),
                DataColumn(label: Text('Nombre')),
                DataColumn(label: Text('OP')),
                DataColumn(label: Text('Peso de cobre (kg)')),
                DataColumn(label: Text('Valor Neto (US\$)')),
              ],
              rows: List.generate(rows.length, (i) {
                final r = rows[i];
                return DataRow(cells: [
                  DataCell(Text('${i + 1}')),
                  DataCell(Text(r.nombre)),
                  DataCell(Text('${r.op}')),
                  DataCell(Text(_num(r.cobre))),
                  DataCell(Text(_money(r.valor))),
                ]);
              }),
            ),
          ),
        ),
      ),
      false,
    );
  }

  Widget _panel(
    String title,
    String subtitle,
    Widget child,
    bool movil, {
    double? height,
    Widget? action,
  }) {
    return Container(
      padding: EdgeInsets.all(movil ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffdcebe3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (action == null)
            Text(
              title,
              style: const TextStyle(
                color: Color(0xff006b3c),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            )
          else if (movil)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xff006b3c),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: action,
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xff006b3c),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                action,
              ],
            ),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          SizedBox(
            height: height ?? (movil ? 360 : 560),
            width: double.infinity,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _Acum {
  int op = 0;
  double valor = 0;
  double cobre = 0;
}

class _Fila {
  final String nombre;
  final int op;
  final double valor;
  final double cobre;

  _Fila(this.nombre, this.op, this.valor, this.cobre);
}

class _Donut {
  final String nombre;
  final double valor;

  _Donut(this.nombre, this.valor);
}

class _Kpi {
  final String titulo;
  final String valor;
  final String subtitulo;
  final IconData icon;

  _Kpi(this.titulo, this.valor, this.subtitulo, this.icon);
}
