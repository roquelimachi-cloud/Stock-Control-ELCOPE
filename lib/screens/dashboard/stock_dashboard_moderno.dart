
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/sesion.dart';
import 'stock_antiguo_page.dart';
import 'stock_antiguo_analisis_gerencial.dart';
import '../login/login_page.dart';
import '../perfil/mi_perfil_page.dart';
import '../stock/stock_page.dart';
import '../sync/sync_page.dart';
import '../usuarios/usuarios_page.dart';
import '../../services/supabase/supabase_service.dart';
import '../../services/pdf/stock_dashboard_pdf_service.dart';
import '../produccion/produccion_gerencial_dashboard.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const _verde = Color(0xFF087A4A);
  static const _azul = Color(0xFF2468D8);
  static const _verdeBarra = Color(0xFF16A66A);
  static const _fondo = Color(0xFFF5F8F7);

  final SupabaseClient _db = SupabaseService.client;
  final TextEditingController _buscar = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _menuVisible = true;

  List<Map<String, dynamic>> _todos = [];
  List<Map<String, dynamic>> _filtrados = [];

  String _clase = 'TODAS';
  String _almacen = 'TODOS';
  String _vendedor = 'TODOS';
  String _condicion = 'TODAS';
  DateTimeRange? _rangoFecha;

  bool _cargando = true;
  String? _error;

  final _money = NumberFormat('#,##0.00', 'en_US');
  final _number = NumberFormat('#,##0', 'en_US');
  final _date = DateFormat('dd/MM/yyyy');

  bool get _esAdministrador =>
      Sesion.esAdministrador ||
      Sesion.rol.trim().toLowerCase() == 'administrador';

  @override
  void initState() {
    super.initState();
    // Solo un usuario individual queda prefiltrado a su vendedor.
    // Gerencia y Jefaturas conservan TODAS las opciones permitidas
    // para poder analizar su ámbito desde los filtros.
    if (!_esGerencia && !_esAdministrador && !_esJefatura &&
        _vendedorActual.isNotEmpty) {
      _vendedor = _vendedorActual;
    }
    _buscar.addListener(_aplicarFiltros);
    _cargar();
  }

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  double _d(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(
          value.toString().replaceAll(',', '').trim(),
        ) ??
        0;
  }

  String _s(dynamic value) => value?.toString().trim() ?? '';

  String _normalizarNombre(String value) {
    var texto = value.trim().toLowerCase();
    const reemplazos = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u',
      'ñ': 'n',
    };
    reemplazos.forEach((a, b) => texto = texto.replaceAll(a, b));
    return texto.replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _campo(Map<String, dynamic> row, List<String> nombres,
      {String defecto = ''}) {
    for (final nombre in nombres) {
      if (row.containsKey(nombre) && _s(row[nombre]).isNotEmpty) {
        return _s(row[nombre]);
      }
    }
    return defecto;
  }

  DateTime? _fecha(Map<String, dynamic> row) {
    final raw = _campo(row, [
      'fecha_ingreso',
      'fechaIngreso',
      'fecha',
      'created_at',
    ]);
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  bool get _esGerencia => Sesion.rol.trim().toLowerCase() == 'gerencia';

  bool get _esJefatura {
    final rol = Sesion.rol.trim().toLowerCase();
    return rol == 'jefe lima' || rol == 'jefe provincia';
  }

  bool get _esUsuarioRestringido => !_esGerencia && !_esAdministrador && !_esJefatura;

  String get _vendedorActual {
    final vendedor = Sesion.vendedor.trim();
    if (vendedor.isNotEmpty) return vendedor;
    return Sesion.nombre.trim();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final List<Map<String, dynamic>> rows = [];

      for (int from = 0;; from += 1000) {
        final data = await _db
            .from('stock')
            .select()
            .range(from, from + 999);

        final pagina = List<Map<String, dynamic>>.from(data);
        rows.addAll(pagina);

        if (pagina.length < 1000) break;
      }

      // =======================================================
    // SEGURIDAD POR ROL
    // Gerencia / Administrador = todo.
    // Jefatura = vendedores autorizados en usuario_permisos.
    // Usuario individual = solamente su vendedor.
    // =======================================================
    final List<Map<String, dynamic>> visibles;

    // Gerencia puede ver todo el stock.
    // Un Administrador que además tiene vendedor asignado NO es un
    // administrador global para el stock: ve únicamente su vendedor.
    // Solo un Administrador sin vendedor asignado conserva vista global.
    final vendedorAdmin = _normalizarNombre(_vendedorActual);

    if (_esGerencia) {
      visibles = rows;
    } else if (_esAdministrador && vendedorAdmin.isEmpty) {
      visibles = rows;
    } else if (_esJefatura) {
      final respuesta = await _db
          .from('usuario_permisos')
          .select('vendedor, ver_produccion')
          .eq('usuario_jefe_id', Sesion.idUsuario)
          .eq('ver_produccion', true);

      final permitidos = (respuesta as List)
          .map((e) => _normalizarNombre(e['vendedor']?.toString() ?? ''))
          .where((e) => e.isNotEmpty)
          .toSet();

      // El propio vendedor de la jefatura también queda visible si está
      // registrado en la sesión.
      final propio = _normalizarNombre(Sesion.vendedor.trim());
      if (propio.isNotEmpty) permitidos.add(propio);

      visibles = rows.where((r) {
        final vendedor = _normalizarNombre(
          _campo(r, ['vendedor', 'asesor', 'representante']),
        );
        return permitidos.contains(vendedor);
      }).toList();
    } else {
      final vendedorSesion = _normalizarNombre(_vendedorActual);
      visibles = vendedorSesion.isEmpty
          ? <Map<String, dynamic>>[]
          : rows.where((r) {
              final vendedor = _normalizarNombre(
                _campo(r, ['vendedor', 'asesor', 'representante']),
              );
              return vendedor == vendedorSesion;
            }).toList();
    }

      setState(() {
        _todos = visibles;
        _filtrados = List<Map<String, dynamic>>.from(visibles);
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _cargando = false;
        _error = e.toString();
      });
    }
  }

  void _aplicarFiltros() {
    final texto = _buscar.text.trim().toUpperCase();

    final result = _todos.where((r) {
      final descripcion = _campo(r, ['descripcion', 'articulo']);
      final codigo = _campo(r, ['codigo_articulo', 'codigoArticulo', 'codigo']);
      final cliente = _campo(r, ['cliente']);
      final documento =
          _campo(r, ['documento', 'nro_documento', 'numero_documento']);

      final clase = _campo(r, [
        'clase',
        'clase_producto',
        'claseProducto',
        'familia',
        'categoria',
      ], defecto: 'SIN CLASE');

      final almacen = _campo(r, [
        'almacen',
        'almacén',
        'almacen_nombre',
        'almacenNombre',
        'ubicacion',
      ], defecto: 'SIN ALMACÉN');

      final vendedor = _campo(r, [
        'vendedor',
        'asesor',
        'representante',
      ], defecto: 'SIN VENDEDOR');

      final condicion = _campo(r, [
        'condicion',
        'condición',
        'estado_stock',
        'situacion',
        'situación',
        'estado',
      ], defecto: 'DISPONIBLE');

      final fecha = _fecha(r);

      final coincideTexto = texto.isEmpty ||
          '$descripcion $codigo $cliente $documento'
              .toUpperCase()
              .contains(texto);

      final coincideClase = _clase == 'TODAS' || clase == _clase;
      final coincideAlmacen = _almacen == 'TODOS' || almacen == _almacen;
      final coincideVendedor = _vendedor == 'TODOS' || vendedor == _vendedor;
      final coincideCondicion =
          _condicion == 'TODAS' || condicion == _condicion;

      final coincideFecha = _rangoFecha == null ||
          (fecha != null &&
              !fecha.isBefore(
                DateTime(
                  _rangoFecha!.start.year,
                  _rangoFecha!.start.month,
                  _rangoFecha!.start.day,
                ),
              ) &&
              !fecha.isAfter(
                DateTime(
                  _rangoFecha!.end.year,
                  _rangoFecha!.end.month,
                  _rangoFecha!.end.day,
                  23,
                  59,
                  59,
                ),
              ));

      return coincideTexto &&
          coincideClase &&
          coincideAlmacen &&
          coincideVendedor &&
          coincideCondicion &&
          coincideFecha;
    }).toList();

    setState(() => _filtrados = result);
  }

  void _limpiar() {
    _buscar.clear();
    setState(() {
      _clase = 'TODAS';
      _almacen = 'TODOS';
      _vendedor = _esUsuarioRestringido && _vendedorActual.isNotEmpty
          ? _vendedorActual
          : 'TODOS';
      _condicion = 'TODAS';
      _rangoFecha = null;
      _filtrados = List<Map<String, dynamic>>.from(_todos);
    });
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _rangoFecha,
    );

    if (picked == null) return;

    setState(() => _rangoFecha = picked);
    _aplicarFiltros();
  }

  String _claseDe(Map<String, dynamic> r) => _campo(r, [
        'clase',
        'clase_producto',
        'claseProducto',
        'familia',
        'categoria',
      ], defecto: 'SIN CLASE');

  String _almacenDe(Map<String, dynamic> r) => _campo(r, [
        'almacen',
        'almacén',
        'almacen_nombre',
        'almacenNombre',
        'ubicacion',
      ], defecto: 'SIN ALMACÉN');

  String _vendedorDe(Map<String, dynamic> r) => _campo(r, [
        'vendedor',
        'asesor',
        'representante',
      ], defecto: 'SIN VENDEDOR');

  String _condicionDe(Map<String, dynamic> r) => _campo(r, [
        'condicion',
        'condición',
        'estado_stock',
        'situacion',
        'situación',
        'estado',
      ], defecto: 'DISPONIBLE');

  double _valor(Map<String, dynamic> r) =>
      _d(r['valor_lista_precio_dolar'] ?? r['valorStock'] ?? r['valor']);

  double _peso(Map<String, dynamic> r) =>
      _d(r['peso'] ?? r['peso_cobre'] ?? r['pesoCobre']);

  double _stock(Map<String, dynamic> r) => _d(r['stock']);

  List<String> _opciones(String Function(Map<String, dynamic>) selector) {
    final set = <String>{};
    for (final r in _todos) {
      final value = selector(r).trim();
      if (value.isNotEmpty) set.add(value);
    }
    final list = set.toList()..sort();
    return list;
  }

  Map<String, _ResumenGrupo> _agrupar(String Function(Map<String, dynamic>) selector) {
    final map = <String, _ResumenGrupo>{};

    for (final r in _filtrados) {
      final key = selector(r);
      final actual = map[key] ?? _ResumenGrupo(nombre: key);
      actual.valor += _valor(r);
      actual.peso += _peso(r);
      actual.stock += _stock(r);
      actual.cantidad++;
      map[key] = actual;
    }

    return map;
  }

  List<_ResumenGrupo> _ordenar(
    String Function(Map<String, dynamic>) selector,
  ) {
    final data = _agrupar(selector).values.toList();
    data.sort((a, b) => b.valor.compareTo(a.valor));
    return data;
  }

  Map<String, _ResumenGrupo> _productosAgrupados() {
    final map = <String, _ResumenGrupo>{};

    for (final r in _filtrados) {
      final key = _campo(r, ['descripcion', 'articulo'],
          defecto: 'SIN DESCRIPCIÓN');
      final actual = map[key] ?? _ResumenGrupo(nombre: key);
      actual.valor += _valor(r);
      actual.peso += _peso(r);
      actual.stock += _stock(r);
      actual.cantidad++;
      map[key] = actual;
    }

    return map;
  }

  StockDashboardPdfItem _aPdfItem(_ResumenGrupo e) {
    return StockDashboardPdfItem(
      nombre: e.nombre,
      valor: e.valor,
      peso: e.peso,
      stock: e.stock,
      cantidad: e.cantidad,
    );
  }

  int get _productosUnicos => _productosAgrupados().length;

  int get _clientes => _filtrados
      .map((r) => _campo(r, ['cliente']))
      .where((e) => e.isNotEmpty)
      .toSet()
      .length;

  double get _valorTotal =>
      _filtrados.fold(0, (sum, r) => sum + _valor(r));

  double get _pesoTotal =>
      _filtrados.fold(0, (sum, r) => sum + _peso(r));

  double get _stockTotal =>
      _filtrados.fold(0, (sum, r) => sum + _stock(r));

  Future<void> _actualizar() async {
    await _cargar();
    if (!mounted) return;
    _aplicarFiltros();
  }

  void _abrirVistaPrevia(
    String titulo,
    List<_ResumenGrupo> datos,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _StockDashboardPreviewPage(
          titulo: titulo,
          datos: datos,
        ),
      ),
    );
  }

  Widget _filtroTexto() {
    return SizedBox(
      width: 330,
      child: TextField(
        controller: _buscar,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: 'Buscar producto, cliente o documento',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
  }) {
    final items = <String>[value, ...values.where((e) => e != value)];
    return SizedBox(
      width: 235,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
        items: items
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(e, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _kpi({
    required String titulo,
    required String valor,
    required String subtitulo,
    required IconData icono,
    required Color color,
  }) {
    return Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2ECE8)),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      valor,
                      style: TextStyle(
                        fontSize: 22,
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _panelTitulo({
    required String titulo,
    required String subtitulo,
    required List<_ResumenGrupo> datos,
    required IconData icono,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2ECE8)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icono, color: _verde),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _verde,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed:
                    datos.isEmpty ? null : () => _abrirVistaPrevia(titulo, datos),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('VISTA PREVIA'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _azul,
                  side: BorderSide(
                    color: _azul.withValues(alpha: .55),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              subtitulo,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          _barras(datos),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _Leyenda(color: _azul, texto: 'Valor Stock (US\$)'),
              SizedBox(width: 20),
              _Leyenda(color: _verdeBarra, texto: 'Peso de cobre (kg)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _barras(List<_ResumenGrupo> datos) {
    if (datos.isEmpty) {
      return const SizedBox(
        height: 285,
        child: Center(child: Text('No hay datos para los filtros seleccionados.')),
      );
    }

    final visible = datos.take(8).toList();
    final maxValor = visible.fold<double>(0, (m, e) => e.valor > m ? e.valor : m);
    final maxPeso = visible.fold<double>(0, (m, e) => e.peso > m ? e.peso : m);

    return SizedBox(
      height: 285,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, c) {
          final available = c.maxWidth.isFinite ? c.maxWidth : 900.0;
          final ancho = ((available - ((visible.length - 1) * 8)) /
                  (visible.isEmpty ? 1 : visible.length))
              .clamp(76.0, 155.0)
              .toDouble();

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: visible.map((e) {
                final valorFactor = maxValor == 0
                    ? 0.0
                    : (e.valor / maxValor).clamp(0.0, 1.0).toDouble();
                final pesoFactor = maxPeso == 0
                    ? 0.0
                    : (e.peso / maxPeso).clamp(0.0, 1.0).toDouble();
                final barWidth = (ancho * .34).clamp(22.0, 52.0).toDouble();

                return SizedBox(
                  width: ancho,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          height: 34,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: barWidth,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'US\$ ${_money.format(e.valor)}',
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: _azul,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              SizedBox(
                                width: barWidth,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${_money.format(e.peso)} kg',
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: _verdeBarra,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 185,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              SizedBox(
                                width: barWidth,
                                height: 185,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: barWidth,
                                    height: 185 * valorFactor,
                                    decoration: const BoxDecoration(
                                      color: _azul,
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(6),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              SizedBox(
                                width: barWidth,
                                height: 185,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: barWidth,
                                    height: 185 * pesoFactor,
                                    decoration: const BoxDecoration(
                                      color: _verdeBarra,
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(6),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 30,
                          child: Text(
                            e.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _rankingPanel({
    required String titulo,
    required String subtitulo,
    required List<_ResumenGrupo> datos,
    required IconData icono,
  }) {
    final top = datos.take(10).toList();
    final max = top.isEmpty ? 0.0 : top.first.valor;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2ECE8)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icono, color: _azul),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed:
                    top.isEmpty ? null : () => _abrirVistaPrevia(titulo, datos),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('VISTA PREVIA'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _azul,
                  side: BorderSide(
                    color: _azul.withValues(alpha: .55),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              subtitulo,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          ...top.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final e = entry.value;
            final factor =
                max == 0 ? 0.0 : (e.valor / max).clamp(0.0, 1.0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _azul.withValues(alpha: .45),
                          ),
                          color: const Color(0xFFF1F6FF),
                        ),
                        child: Text(
                          '$index',
                          style: const TextStyle(
                            color: _azul,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          e.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'US\$ ${_money.format(e.valor)}',
                            style: const TextStyle(
                              color: _verde,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${_money.format(e.peso)} kg',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: factor,
                      backgroundColor: const Color(0xFFE9EEF3),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(_azul),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (top.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Text('No hay datos para mostrar.'),
            ),
        ],
      ),
    );
  }

  Widget _menuContenido(BuildContext context, {bool lateral = false}) {
    return Material(
      color: Colors.white,
      child: Container(
        color: Colors.white,
        child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: _azul,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.inventory_2, color: Colors.white, size: 46),
                  const SizedBox(height: 10),
                  Text(
                    Sesion.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Sesion.rol,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    selected: true,
                    selectedTileColor: const Color(0xFFEFF5FF),
                    leading: const Icon(Icons.dashboard, color: _azul),
                    title: const Text('Dashboard'),
                    onTap: lateral ? null : () => Navigator.pop(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: const Text('Control de Stock'),
                    onTap: () {
                      if (!lateral) Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StockPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('Stock Antiguo (> 30 días)'),
                    subtitle: Text(
                      _esGerencia || _esJefatura
                          ? 'Análisis gerencial'
                          : 'Control de permanencia',
                    ),
                    onTap: () {
                      if (!lateral) Navigator.pop(context);
                      if (_esGerencia || _esJefatura) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StockAntiguoAnalisisGerencialPage(),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const StockAntiguoPage()),
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Producción'),
                    subtitle: const Text('Dashboard de Producción'),
                    onTap: () {
                      if (!lateral) Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProduccionGerencialDashboard(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Mi Perfil'),
                    onTap: () {
                      if (!lateral) Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MiPerfilPage()),
                      );
                    },
                  ),
                  if (_esAdministrador)
                    ListTile(
                      leading: const Icon(Icons.sync),
                      title: const Text('Sincronizar Excel'),
                      onTap: () async {
                        if (!lateral) Navigator.pop(context);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SyncPage()),
                        );
                        if (!mounted) return;
                        await _actualizar();
                      },
                    ),
                  if (_esAdministrador)
                    ListTile(
                      leading: const Icon(Icons.people),
                      title: const Text('Usuarios'),
                      onTap: () {
                        if (!lateral) Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UsuariosPage()),
                        );
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Cerrar Sesión',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Sesion.cerrarSesion();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _menu(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width < 600
          ? MediaQuery.sizeOf(context).width * .86
          : 304,
      child: Material(
        color: Colors.white,
        child: _menuContenido(context),
      ),
    );
  }

  Widget _menuLateral(BuildContext context) {
    return SizedBox(
      width: 286,
      height: MediaQuery.sizeOf(context).height,
      child: Material(
        color: Colors.white,
        elevation: 0,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Color(0xFFDDE9E4))),
          ),
          child: _menuContenido(context, lateral: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clases = _ordenar(_claseDe);
    final condiciones = _ordenar(_condicionDe);
    final almacenes = _ordenar(_almacenDe);
    final clientes = _ordenar((r) => _campo(r, ['cliente'],
        defecto: 'SIN CLIENTE'));
    final vendedores = _ordenar(_vendedorDe);
    final productos = _productosAgrupados().values.toList()
      ..sort((a, b) => b.valor.compareTo(a.valor));

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1200;

        final contenido = Scaffold(
          key: desktop ? null : _scaffoldKey,
          backgroundColor: _fondo,
          drawer: desktop ? null : _menu(context),
          body: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Error al cargar el stock:\n$_error',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : SafeArea(
                      child: Column(
                        children: [
                          _header(context),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _filtros(context),
                                  const SizedBox(height: 14),
                                  _kpis(context),
                                  const SizedBox(height: 16),
                                  LayoutBuilder(
                                    builder: (context, c) {
                                      final mobile = c.maxWidth < 1000;
                                      final children = [
                                        _panelTitulo(
                                          titulo: 'STOCK POR CLASE',
                                          subtitulo: 'Valor de stock (US\$) + Peso de cobre (kg)',
                                          datos: clases,
                                          icono: Icons.category_outlined,
                                        ),
                                        _panelTitulo(
                                          titulo: 'STOCK POR CONDICIÓN',
                                          subtitulo: 'Valor de stock (US\$) + Peso de cobre (kg)',
                                          datos: condiciones,
                                          icono: Icons.inventory_2_outlined,
                                        ),
                                        _panelTitulo(
                                          titulo: 'VALOR DE STOCK POR ALMACÉN',
                                          subtitulo: 'Valor de stock (US\$) + Peso de cobre (kg)',
                                          datos: almacenes,
                                          icono: Icons.warehouse_outlined,
                                        ),
                                      ];
                                      final width = c.maxWidth.isFinite
                                          ? c.maxWidth
                                          : MediaQuery.sizeOf(context).width;
                                      const gap = 14.0;
                                      final cardWidth = mobile
                                          ? width
                                          : (width - (gap * 2)) / 3;
                                      return Wrap(
                                        spacing: gap,
                                        runSpacing: gap,
                                        children: children
                                            .map((e) => SizedBox(width: cardWidth, child: e))
                                            .toList(),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  LayoutBuilder(
                                    builder: (context, c) {
                                      final mobile = c.maxWidth < 1000;
                                      final cards = [
                                        _rankingPanel(
                                          titulo: 'TOP 10 CLIENTES CON MAYOR STOCK',
                                          subtitulo: 'Valor de stock (US\$) + Peso de cobre (kg)',
                                          datos: clientes,
                                          icono: Icons.people_alt_outlined,
                                        ),
                                        _rankingPanel(
                                          titulo: 'TOP 10 PRODUCTOS',
                                          subtitulo: 'Valor de stock (US\$) + Peso de cobre (kg)',
                                          datos: productos,
                                          icono: Icons.inventory_outlined,
                                        ),
                                        _rankingPanel(
                                          titulo: 'STOCK POR VENDEDOR',
                                          subtitulo: 'Valor de stock (US\$) + Peso de cobre (kg)',
                                          datos: vendedores,
                                          icono: Icons.badge_outlined,
                                        ),
                                      ];
                                      final width = c.maxWidth.isFinite
                                          ? c.maxWidth
                                          : MediaQuery.sizeOf(context).width;
                                      const gap = 14.0;
                                      final columns = mobile ? 1 : 3;
                                      final cardWidth = mobile
                                          ? width
                                          : (width - (gap * (columns - 1))) / columns;
                                      return Wrap(
                                        spacing: gap,
                                        runSpacing: gap,
                                        children: cards
                                            .map((e) => SizedBox(width: cardWidth, child: e))
                                            .toList(),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  _resumenInferior(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
        );

        if (!desktop) return contenido;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_menuVisible) _menuLateral(context),
            Expanded(child: contenido),
          ],
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final movil = ancho < 700;
    final compacto = ancho < 420;

    final botonImportar = OutlinedButton.icon(
      onPressed: Sesion.esAdministrador
          ? () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncPage()),
              );
              if (!mounted) return;
              await _actualizar();
            }
          : null,
      icon: const Icon(Icons.upload_outlined, size: 18),
      label: Text(compacto ? 'IMPORTAR' : 'IMPORTAR EXCEL'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _azul,
        side: const BorderSide(color: _azul),
        padding: EdgeInsets.symmetric(
          horizontal: compacto ? 10 : 16,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );

    final botonImprimir = OutlinedButton.icon(
      onPressed: _filtrados.isEmpty
          ? null
          : () async {
              try {
                await StockDashboardPdfService.imprimirDashboard(
                  context: context,
                  clases: _ordenar(_claseDe).map(_aPdfItem).toList(),
                  condiciones:
                      _ordenar(_condicionDe).map(_aPdfItem).toList(),
                  almacenes: _ordenar(_almacenDe).map(_aPdfItem).toList(),
                  clientes: _ordenar(
                    (r) => _campo(
                      r,
                      ['cliente'],
                      defecto: 'SIN CLIENTE',
                    ),
                  ).map(_aPdfItem).toList(),
                  vendedores: _ordenar(_vendedorDe).map(_aPdfItem).toList(),
                  productos: (_productosAgrupados().values.toList()
                        ..sort((a, b) => b.valor.compareTo(a.valor)))
                      .map(_aPdfItem)
                      .toList(),
                  totalRegistros: _filtrados.length,
                  totalStock: _stockTotal,
                  totalValor: _valorTotal,
                  totalPeso: _pesoTotal,
                  busqueda: _buscar.text.trim().isEmpty
                      ? 'TODAS'
                      : _buscar.text.trim(),
                  clase: _clase,
                  almacen: _almacen,
                  vendedor: _vendedor,
                  condicion: _condicion,
                  fecha: _rangoFecha == null
                      ? 'Todas las fechas'
                      : '${_date.format(_rangoFecha!.start)} - ${_date.format(_rangoFecha!.end)}',
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('No se pudo imprimir: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
      icon: const Icon(Icons.print_outlined, size: 18),
      label: Text(compacto ? 'IMPRIMIR' : 'IMPRIMIR DASHBOARD'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _azul,
        side: const BorderSide(color: _azul),
        padding: EdgeInsets.symmetric(
          horizontal: compacto ? 10 : 16,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );

    final botonActualizar = OutlinedButton.icon(
      onPressed: _actualizar,
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('ACTUALIZAR'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _verde,
        side: const BorderSide(color: _verde),
        padding: EdgeInsets.symmetric(
          horizontal: compacto ? 10 : 16,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      padding: EdgeInsets.fromLTRB(
        movil ? 8 : 10,
        movil ? 8 : 10,
        movil ? 8 : 12,
        movil ? 12 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE9E4)),
      ),
      child: movil
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Menú',
                      onPressed: () =>
                          _scaffoldKey.currentState?.openDrawer(),
                      icon: const Icon(Icons.menu),
                      color: _azul,
                    ),
                    IconButton(
                      tooltip: 'Atrás',
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.arrow_back),
                      color: Colors.blueGrey,
                    ),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4F6ED),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: _verde,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'CONTROL DE STOCK',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF173B30),
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 108, right: 8),
                  child: Text(
                    'Análisis general de stock por clase, almacén, cliente, vendedor y producto.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (Sesion.esAdministrador) botonImportar,
                    botonImprimir,
                    botonActualizar,
                  ],
                ),
              ],
            )
          : Row(
              children: [
                IconButton(
                  tooltip: 'Menú',
                  onPressed: () {
                    final desktop = MediaQuery.sizeOf(context).width >= 1200;
                    if (desktop) {
                      setState(() => _menuVisible = !_menuVisible);
                    } else {
                      _scaffoldKey.currentState?.openDrawer();
                    }
                  },
                  icon: const Icon(Icons.menu),
                  color: _azul,
                ),
                IconButton(
                  tooltip: 'Atrás',
                  onPressed: () {
                    if (Navigator.canPop(context)) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back),
                  color: Colors.blueGrey,
                ),
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4F6ED),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: _verde,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CONTROL DE STOCK',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF173B30),
                        ),
                      ),
                      Text(
                        'Análisis general de stock por clase, almacén, cliente, vendedor y producto.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    if (Sesion.esAdministrador) botonImportar,
                    botonImprimir,
                    botonActualizar,
                  ],
                ),
              ],
            ),
    );
  }

  Widget _filtros(BuildContext context) {
    final clases = _opciones(_claseDe);
    final almacenes = _opciones(_almacenDe);
    final vendedores = _opciones(_vendedorDe);
    final condiciones = _opciones(_condicionDe);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE9E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt_outlined, color: _verde),
              const SizedBox(width: 8),
              const Text(
                'FILTROS DE STOCK',
                style: TextStyle(
                  color: _verde,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _limpiar,
                icon: const Icon(Icons.clear_all),
                label: const Text('Limpiar'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              final mobile = c.maxWidth < 1050;
              final widgets = [
                _filtroTexto(),
                _dropdown(
                  label: 'Clase',
                  value: _clase,
                  values: ['TODAS', ...clases],
                  onChanged: (v) {
                    setState(() => _clase = v ?? 'TODAS');
                    _aplicarFiltros();
                  },
                ),
                _dropdown(
                  label: 'Almacén',
                  value: _almacen,
                  values: ['TODOS', ...almacenes],
                  onChanged: (v) {
                    setState(() => _almacen = v ?? 'TODOS');
                    _aplicarFiltros();
                  },
                ),
                _dropdown(
                  label: 'Vendedor',
                  value: _esUsuarioRestringido && _vendedorActual.isNotEmpty
                      ? _vendedorActual
                      : _vendedor,
                  values: _esUsuarioRestringido && _vendedorActual.isNotEmpty
                      ? [_vendedorActual]
                      : ['TODOS', ...vendedores],
                  onChanged: _esUsuarioRestringido
                      ? (_) {}
                      : (v) {
                          setState(() => _vendedor = v ?? 'TODOS');
                          _aplicarFiltros();
                        },
                ),
                _dropdown(
                  label: 'Condición',
                  value: _condicion,
                  values: ['TODAS', ...condiciones],
                  onChanged: (v) {
                    setState(() => _condicion = v ?? 'TODAS');
                    _aplicarFiltros();
                  },
                ),
                SizedBox(
                  height: 58,
                  child: OutlinedButton.icon(
                    onPressed: _seleccionarFecha,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      _rangoFecha == null
                          ? 'Todas las fechas'
                          : '${_date.format(_rangoFecha!.start)} - ${_date.format(_rangoFecha!.end)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ];

              if (mobile) {
                return Column(
                  children: [
                    for (final w in widgets) ...[
                      w,
                      const SizedBox(height: 9),
                    ],
                  ],
                );
              }

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: widgets,
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Mostrando ${_number.format(_filtrados.length)} registros de ${_number.format(_todos.length)}',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpis(BuildContext context) {
    final children = [
      _kpi(titulo: 'TOTAL PRODUCTOS', valor: _number.format(_productosUnicos), subtitulo: 'Productos registrados', icono: Icons.inventory_2_outlined, color: _azul),
      _kpi(titulo: 'PESO TOTAL', valor: '${_money.format(_pesoTotal)} Kg', subtitulo: 'Peso de cobre en stock', icono: Icons.layers_outlined, color: _verdeBarra),
      _kpi(titulo: 'VALOR DE STOCK', valor: 'US\$ ${_money.format(_valorTotal)}', subtitulo: 'Valor neto total', icono: Icons.attach_money, color: _verde),
      _kpi(titulo: 'CLIENTES CON STOCK', valor: _number.format(_clientes), subtitulo: 'Clientes registrados', icono: Icons.groups_outlined, color: const Color(0xFF8A35C7)),
      _kpi(titulo: 'VENDEDORES', valor: _number.format(_filtrados.map(_vendedorDe).where((e) => e.isNotEmpty).toSet().length), subtitulo: 'Representantes', icono: Icons.person_outline, color: const Color(0xFFF08A00)),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth.isFinite ? c.maxWidth : MediaQuery.sizeOf(context).width;
        final mobile = width < 600;
        final columns = mobile ? 1 : (width < 1100 ? 2 : 5);
        final gap = 12.0;
        final cardWidth = columns == 1
            ? width
            : (width - ((columns - 1) * gap)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: children
              .map((e) => SizedBox(width: cardWidth, child: e))
              .toList(),
        );
      },
    );
  }

  Widget _resumenInferior() {
    final oldest = [..._filtrados]
      ..sort((a, b) {
        final da = _fecha(a) ?? DateTime.now();
        final db = _fecha(b) ?? DateTime.now();
        return da.compareTo(db);
      });

    final items = oldest.take(8).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE9E4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.table_chart_outlined, color: _azul),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'RESUMEN DE STOCK',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'Stock total: ${_money.format(_stockTotal)}',
                style: const TextStyle(
                  color: _verde,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
                  const WidgetStatePropertyAll(Color(0xFFF0F5F3)),
              columns: const [
                DataColumn(label: Text('Código')),
                DataColumn(label: Text('Descripción')),
                DataColumn(label: Text('Cliente')),
                DataColumn(label: Text('Almacén')),
                DataColumn(label: Text('Stock')),
                DataColumn(label: Text('Valor US\$')),
                DataColumn(label: Text('Peso kg')),
                DataColumn(label: Text('Ingreso')),
              ],
              rows: items.map((r) {
                final fecha = _fecha(r);
                return DataRow(
                  cells: [
                    DataCell(Text(_campo(
                      r,
                      ['codigo_articulo', 'codigoArticulo', 'codigo'],
                    ))),
                    DataCell(
                      SizedBox(
                        width: 330,
                        child: Text(
                          _campo(r, ['descripcion', 'articulo'],
                              defecto: 'SIN DESCRIPCIÓN'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text(_campo(r, ['cliente'],
                        defecto: 'SIN CLIENTE'))),
                    DataCell(Text(_almacenDe(r))),
                    DataCell(Text(_money.format(_stock(r)))),
                    DataCell(Text(_money.format(_valor(r)))),
                    DataCell(Text(_money.format(_peso(r)))),
                    DataCell(
                      Text(fecha == null ? '-' : _date.format(fecha)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumenGrupo {
  _ResumenGrupo({required this.nombre});

  final String nombre;
  double valor = 0;
  double peso = 0;
  double stock = 0;
  int cantidad = 0;
}

class _Leyenda extends StatelessWidget {
  const _Leyenda({
    required this.color,
    required this.texto,
  });

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          texto,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StockDashboardPreviewPage extends StatelessWidget {
  const _StockDashboardPreviewPage({
    required this.titulo,
    required this.datos,
  });

  final String titulo;
  final List<_ResumenGrupo> datos;

  static const verde = Color(0xFF087A4A);
  static const azul = Color(0xFF2468D8);

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat('#,##0.00', 'en_US');
    final ordenados = [...datos]
      ..sort((a, b) => b.valor.compareTo(a.valor));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'VISTA PREVIA — $titulo',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: verde,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: ordenados.isEmpty
                  ? null
                  : () async {
                      try {
                        // Dejamos terminar el frame actual antes de abrir
                        // el diálogo de impresión del navegador.
                        await Future<void>.delayed(
                          const Duration(milliseconds: 80),
                        );
                        if (!context.mounted) return;

                        await StockDashboardPdfService.imprimir(
                          context: context,
                          titulo: titulo,
                          items: ordenados
                              .map(
                                (e) => StockDashboardPdfItem(
                                  nombre: e.nombre,
                                  valor: e.valor,
                                  peso: e.peso,
                                  stock: e.stock,
                                  cantidad: e.cantidad,
                                ),
                              )
                              .toList(),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('No se pudo imprimir: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.print_outlined),
              label: const Text('IMPRIMIR'),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final maxValor =
              ordenados.isEmpty ? 0.0 : ordenados.first.valor;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border:
                            Border.all(color: const Color(0xFFDDE9E4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE4F6ED),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.bar_chart,
                              color: verde,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  titulo,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Vista previa del análisis de stock.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFDDE9E4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GRÁFICO',
                            style: TextStyle(
                              color: verde,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Valor de stock (US\$) + Peso de cobre (kg)',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (ordenados.isEmpty)
                            const SizedBox(
                              height: 260,
                              child: Center(
                                child: Text(
                                  'No hay datos para mostrar.',
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 330,
                              width: double.infinity,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: ordenados.map((e) {
                                    final valorFactor = maxValor == 0
                                        ? 0.0
                                        : (e.valor / maxValor)
                                            .clamp(0.0, 1.0)
                                            .toDouble();
                                    final pesoMax = ordenados.fold<double>(
                                      0,
                                      (m, x) =>
                                          x.peso > m ? x.peso : m,
                                    );
                                    final pesoFactor = pesoMax == 0
                                        ? 0.0
                                        : (e.peso / pesoMax)
                                            .clamp(0.0, 1.0)
                                            .toDouble();

                                    return SizedBox(
                                      width: 150,
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            SizedBox(
                                              height: 40,
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  'US\$ ${money.format(e.valor)}',
                                                  style:
                                                      const TextStyle(
                                                    color: azul,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            SizedBox(
                                              height: 210,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Container(
                                                    width: 42,
                                                    height:
                                                        210 * valorFactor,
                                                    decoration:
                                                        const BoxDecoration(
                                                      color: azul,
                                                      borderRadius:
                                                          BorderRadius.vertical(
                                                        top:
                                                            Radius.circular(6),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    width: 42,
                                                    height:
                                                        210 * pesoFactor,
                                                    decoration:
                                                        const BoxDecoration(
                                                      color:
                                                          Color(0xFF16A66A),
                                                      borderRadius:
                                                          BorderRadius.vertical(
                                                        top:
                                                            Radius.circular(6),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              e.nombre,
                                              maxLines: 2,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight:
                                                    FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                '${money.format(e.peso)} kg',
                                                style: const TextStyle(
                                                  color:
                                                      Color(0xFF16A66A),
                                                  fontSize: 10,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 22,
                            runSpacing: 8,
                            children: const [
                              _Leyenda(
                                color: azul,
                                texto: 'Valor Stock (US\$)',
                              ),
                              _Leyenda(
                                color: Color(0xFF16A66A),
                                texto: 'Peso de cobre (kg)',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border:
                            Border.all(color: const Color(0xFFDDE9E4)),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'N°',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              Expanded(
                                flex: 5,
                                child: Text(
                                  'NOMBRE',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'VALOR NETO (US\$)',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'PESO (kg)',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                          ...ordenados.asMap().entries.map(
                            (entry) {
                              final i = entry.key + 1;
                              final e = entry.value;
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 9),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '$i',
                                        style: const TextStyle(
                                          color: azul,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 5,
                                      child: Text(
                                        e.nombre,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'US\$ ${money.format(e.valor)}',
                                        style: const TextStyle(
                                          color: verde,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '${money.format(e.peso)} kg',
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
