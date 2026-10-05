
import 'dart:io';

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' as services;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../services/sesion.dart';
import '../../../services/supabase/supabase_service.dart';

enum _CategoriaCartera {
  nuevos,
  crecieron,
  disminuyeron,
  sinCompra,
}

class CrmReportesPage extends StatefulWidget {
  const CrmReportesPage({super.key});

  @override
  State<CrmReportesPage> createState() => _CrmReportesPageState();
}

class _CrmReportesPageState extends State<CrmReportesPage> {
  static const azul = Color(0xFF0B4A78);
  static const azulClaro = Color(0xFF1877D1);
  static const verde = Color(0xFF079B63);
  static const naranja = Color(0xFFF08A00);
  static const morado = Color(0xFF5B45C5);
  static const Color rojo = Color(0xFFD93838);
  static const fondo = Color(0xFFF4F7FA);
  static const borde = Color(0xFFE2E8F0);

  final db = SupabaseService.client;
  final money = NumberFormat('#,##0.00', 'en_US');
  final integer = NumberFormat('#,##0', 'en_US');
  final date = DateFormat('dd/MM/yyyy');

  bool loading = true;
  String vendedor = 'TODOS';
  String canal = 'TODOS';
  List<String>? vendedoresPermitidos;
  List<String> vendedores = [];

  final List<String> canales = const [
    'TODOS',
    'LIMA',
    'PROVINCIAS',
    'CADENAS',
    'CORPORATIVO',
    'EXPORTACIONES',
    'LICITACION',
    'OFICINA',
    '--',
  ];

  DateTime desde = DateTime(DateTime.now().year, 1, 1);
  DateTime hasta = DateTime.now();

  Map<String, dynamic> data = {};
  Map<String, dynamic> dataAnterior = {};
  int anioActual = DateTime.now().year;
  int anioComparacion = DateTime.now().year - 1;
  String? error;

  // Comparación independiente de asesores (VS).
  bool loadingComparacion = false;
  String? vendedorComparacionA;
  String? vendedorComparacionB;
  Map<String, dynamic> dataComparacionA = {};
  Map<String, dynamic> dataComparacionAAnterior = {};
  Map<String, dynamic> dataComparacionB = {};
  Map<String, dynamic> dataComparacionBAnterior = {};

  List<Map<String, dynamic>> sectoresComparacionA = [];
  List<Map<String, dynamic>> sectoresComparacionB = [];

  bool get esGerencia => Sesion.rol.trim().toLowerCase() == 'gerencia';

  bool get esJefatura {
    final r = Sesion.rol.trim().toLowerCase();
    return r == 'jefe lima' || r == 'jefe provincia';
  }

  List<String> get canalesDisponibles {
    if (esGerencia) return canales;
    final rol = Sesion.rol.trim().toLowerCase();
    if (rol == 'jefe lima') return const ['LIMA'];
    if (rol == 'jefe provincia') return const ['PROVINCIAS'];
    return const ['LIMA'];
  }

  String _s(dynamic value) => value?.toString().trim() ?? '';

  double _n(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(_s(value).replaceAll(',', '')) ?? 0;
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    anioActual = desde.year;
    anioComparacion = anioActual - 1;
    _init();
  }

  Future<void> _init() async {
    await _permisos();
    _inicializarComparacionVendedores();
    await _cargar();
  }

  void _inicializarComparacionVendedores() {
    if (vendedores.isEmpty) {
      vendedorComparacionA = null;
      vendedorComparacionB = null;
      return;
    }

    vendedorComparacionA ??= vendedores.first;

    if (vendedores.length > 1) {
      vendedorComparacionB ??= vendedores[1];
    } else {
      vendedorComparacionB ??= vendedores.first;
    }
  }

  Future<void> _permisos() async {
    final rol = Sesion.rol.trim().toLowerCase();

    if (esGerencia) {
      vendedoresPermitidos = null;
      vendedores = await _cargarListaVendedores();
    } else if (rol == 'jefe lima' || rol == 'jefe provincia') {
      // La jefatura NO se queda solamente con su propio usuario.
      // Su lista se toma de usuario_permisos para que "Todos" sea
      // realmente TODO SU EQUIPO y también permita escoger un asesor.
      try {
        final result = await db
            .from('usuario_permisos')
            .select('vendedor,ver_produccion')
            .eq('usuario_jefe_id', Sesion.idUsuario)
            .eq('ver_produccion', true);

        final set = <String>{};
        for (final row in result as List) {
          final nombre = _s(row['vendedor']);
          if (nombre.isNotEmpty) set.add(nombre);
        }

        if (Sesion.vendedor.trim().isNotEmpty) {
          set.add(Sesion.vendedor.trim());
        }

        vendedoresPermitidos = set.toList()..sort();
      } catch (_) {
        vendedoresPermitidos = Sesion.vendedor.trim().isEmpty
            ? <String>[]
            : <String>[Sesion.vendedor.trim()];
      }

      vendedores = List<String>.from(vendedoresPermitidos ?? const <String>[]);
      canal = rol == 'jefe provincia' ? 'PROVINCIAS' : 'LIMA';
    } else {
      // RFIGUEROA: puede consultar TODOS los asesores de LIMA.
      // El canal se mantiene restringido a LIMA y la lista de asesores
      // se obtiene por codigo_vendedor:
      // 001-099 = LIMA; 401 y 601 = LIMA.
      final esRichardFigueroa = Sesion.vendedor.trim().toUpperCase() == 'RFIGUEROA' ||
          Sesion.vendedor.trim().toUpperCase() == 'RICHARD FIGUEROA';

      if (esRichardFigueroa) {
        canal = 'LIMA';
        vendedoresPermitidos = null;
        vendedores = await _cargarListaVendedoresLima();
        vendedor = 'TODOS';
      } else {
        vendedoresPermitidos = Sesion.vendedor.trim().isEmpty
            ? <String>[]
            : <String>[Sesion.vendedor.trim()];
        vendedores = List<String>.from(vendedoresPermitidos!);
        canal = 'LIMA';
      }
    }

    if (vendedor != 'TODOS' && !vendedores.contains(vendedor)) {
      vendedor = 'TODOS';
    }
  }

  Future<List<String>> _cargarListaVendedoresLima() async {
    try {
      final result = await db
          .from('crm_facturas')
          .select('vendedor,codigo_vendedor')
          .not('vendedor', 'is', null)
          .not('codigo_vendedor', 'is', null)
          .limit(10000);

      final set = <String>{};
      for (final row in result as List) {
        final nombre = _s(row['vendedor']);
        final codigo = int.tryParse(_s(row['codigo_vendedor']));
        if (nombre.isEmpty || codigo == null) continue;

        final esLima = (codigo >= 1 && codigo <= 99) ||
            codigo == 401 ||
            codigo == 601;

        if (esLima) set.add(nombre);
      }

      return set.toList()..sort();
    } catch (e) {
      debugPrint('Error cargando vendedores Lima: $e');
      return <String>[];
    }
  }

  Future<List<String>> _cargarListaVendedores() async {
    try {
      final result = await db
          .from('crm_facturas')
          .select('vendedor')
          .not('vendedor', 'is', null)
          .limit(5000);

      final set = <String>{};
      for (final row in result as List) {
        final nombre = _s(row['vendedor']);
        if (nombre.isNotEmpty) set.add(nombre);
      }
      return set.toList()..sort();
    } catch (_) {
      return <String>[];
    }
  }

  DateTime _fechaAnio(DateTime fecha, int anio) {
    final ultimoDia = DateTime(anio, fecha.month + 1, 0).day;
    final dia = fecha.day > ultimoDia ? ultimoDia : fecha.day;
    return DateTime(anio, fecha.month, dia);
  }

  Future<Map<String, dynamic>> _reporteParaVendedor(
    String nombreVendedor,
    DateTime fechaDesde,
    DateTime fechaHasta,
  ) async {
    final esRichardFigueroa = (
      Sesion.vendedor.trim().toUpperCase().contains('RFIGUEROA') ||
      Sesion.nombre.trim().toUpperCase().contains('RFIGUEROA') ||
      Sesion.nombre.trim().toUpperCase().contains('RICHARD FIGUEROA')
    );

    final result = await db.rpc(
      'crm_obtener_reportes',
      params: {
        'p_vendedores_permitidos':
            esRichardFigueroa ? null : vendedoresPermitidos,
        'p_vendedor': nombreVendedor,
        'p_desde': DateFormat('yyyy-MM-dd').format(fechaDesde),
        'p_hasta': DateFormat('yyyy-MM-dd').format(fechaHasta),
        'p_canal': canal,
      },
    );

    return result is Map
        ? Map<String, dynamic>.from(result)
        : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> _sectoresParaVendedor(
    String nombreVendedor,
    DateTime fechaDesde,
    DateTime fechaHasta,
  ) async {
    try {
      final result = await db.rpc(
        'crm_obtener_sectores_comparacion',
        params: {
          'p_vendedores_permitidos': vendedoresPermitidos,
          'p_vendedor': nombreVendedor,
          'p_desde': DateFormat('yyyy-MM-dd').format(fechaDesde),
          'p_hasta': DateFormat('yyyy-MM-dd').format(fechaHasta),
          'p_canal': canal,
        },
      );

      return _mapList(result);
    } catch (e) {
      debugPrint('Error sectores $nombreVendedor: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _cargarComparacionVendedores() async {
    _inicializarComparacionVendedores();

    final a = vendedorComparacionA;
    final b = vendedorComparacionB;

    if (a == null || b == null || a.isEmpty || b.isEmpty) {
      return;
    }

    if (mounted) {
      setState(() => loadingComparacion = true);
    }

    try {
      final desdeAnterior = _fechaAnio(desde, anioComparacion);
      final hastaAnterior = _fechaAnio(hasta, anioComparacion);

      final resultados = await Future.wait([
        _reporteParaVendedor(a, desde, hasta),
        _reporteParaVendedor(a, desdeAnterior, hastaAnterior),
        _reporteParaVendedor(b, desde, hasta),
        _reporteParaVendedor(b, desdeAnterior, hastaAnterior),
        _sectoresParaVendedor(a, desde, hasta),
        _sectoresParaVendedor(b, desde, hasta),
      ]);

      if (!mounted) return;

      setState(() {
        dataComparacionA = resultados[0] as Map<String, dynamic>;
        dataComparacionAAnterior = resultados[1] as Map<String, dynamic>;
        dataComparacionB = resultados[2] as Map<String, dynamic>;
        dataComparacionBAnterior = resultados[3] as Map<String, dynamic>;
        sectoresComparacionA =
            resultados[4] as List<Map<String, dynamic>>;
        sectoresComparacionB =
            resultados[5] as List<Map<String, dynamic>>;
        loadingComparacion = false;
      });
    } catch (e) {
      debugPrint('Error en comparación de asesores: $e');

      if (!mounted) return;

      setState(() {
        loadingComparacion = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cargar la comparación de asesores: $e'),
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _reporte(
    DateTime fechaDesde,
    DateTime fechaHasta,
  ) async {
    final esRichardFigueroa = (
      Sesion.vendedor.trim().toUpperCase().contains('RFIGUEROA') ||
      Sesion.nombre.trim().toUpperCase().contains('RFIGUEROA') ||
      Sesion.nombre.trim().toUpperCase().contains('RICHARD FIGUEROA')
    );

    final result = await db.rpc(
      'crm_obtener_reportes',
      params: {
        'p_vendedores_permitidos':
            esRichardFigueroa ? null : vendedoresPermitidos,
        'p_vendedor': vendedor,
        'p_desde': DateFormat('yyyy-MM-dd').format(fechaDesde),
        'p_hasta': DateFormat('yyyy-MM-dd').format(fechaHasta),
        'p_canal': canal,
      },
    );

    return result is Map
        ? Map<String, dynamic>.from(result)
        : <String, dynamic>{};
  }

  Future<void> _cargar() async {
    if (mounted) setState(() => loading = true);

    try {
      final desdeAnterior = _fechaAnio(desde, anioComparacion);
      final hastaAnterior = _fechaAnio(hasta, anioComparacion);

      final resultados = await Future.wait([
        _reporte(desde, hasta),
        _reporte(desdeAnterior, hastaAnterior),
      ]);

      if (!mounted) return;

      setState(() {
        data = resultados[0];
        dataAnterior = resultados[1];
        anioActual = desde.year;
        loading = false;
        error = null;
      });

      _inicializarComparacionVendedores();
      await _cargarComparacionVendedores();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _seleccionarAnio(bool actual) async {
    final elegido = await showDialog<int>(
      context: context,
      builder: (context) {
        int valor = actual ? anioActual : anioComparacion;

        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(
                actual
                    ? 'Seleccionar año actual'
                    : 'Seleccionar año de comparación',
              ),
              content: DropdownButtonFormField<int>(
                initialValue: valor,
                decoration: const InputDecoration(
                  labelText: 'Año',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(
                  9,
                  (i) => 2022 + i,
                ).map(
                  (year) => DropdownMenuItem(
                    value: year,
                    child: Text('$year'),
                  ),
                ).toList(),
                onChanged: (v) {
                  if (v != null) setLocal(() => valor = v);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, valor),
                  child: const Text('Aceptar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (elegido == null) return;

    setState(() {
      if (actual) {
        final days = hasta.difference(desde).inDays;
        anioActual = elegido;
        desde = _fechaAnio(desde, elegido);
        hasta = desde.add(Duration(days: days));
      } else {
        anioComparacion = elegido;
      }
    });

    await _cargar();
  }

  Future<void> _fecha(bool inicio) async {
    final actual = inicio ? desde : hasta;

    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: actual,
      helpText: inicio ? 'Seleccionar fecha inicial' : 'Seleccionar fecha final',
    );

    if (picked == null) return;

    setState(() {
      if (inicio) {
        desde = picked.isAfter(hasta) ? hasta : picked;
      } else {
        hasta = picked.isBefore(desde) ? desde : picked;
      }
    });

    await _cargar();
  }

  String _filtroTexto() {
    final v = vendedor == 'TODOS'
        ? (esJefatura ? 'Todos los asesores' : 'Todos')
        : vendedor;
    final c = canal == 'TODOS' ? 'Todos los canales' : canal;
    return '$v · $c · ${date.format(desde)} al ${date.format(hasta)}';
  }

  Future<void> _mostrarMes(Map<String, dynamic> row) async {
    final periodo = _s(row['periodo']);
    final fact = _n(row['facturacion']);
    final peso = _n(row['peso']);
    final facturas = _n(row['facturas']).round();
    final clientes = _n(row['clientes']).round();

    final asesores = _mapList(data['vendedores'])
      ..sort(
        (a, b) => _n(b['facturacion']).compareTo(_n(a['facturacion'])),
      );
    final topAsesores = asesores.take(10).toList();

    final clientesData = _mapList(data['clientes'])
      ..sort(
        (a, b) => _n(b['facturacion']).compareTo(_n(a['facturacion'])),
      );
    final topClientes = clientesData.take(10).toList();

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final width = MediaQuery.sizeOf(context).width;
        final height = MediaQuery.sizeOf(context).height;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1120,
              maxHeight: height * .90,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFD),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 25,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 14, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F1FA),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.analytics_outlined,
                            color: azul,
                            size: 25,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vista previa comercial — $periodo',
                                style: const TextStyle(
                                  color: azul,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Canal: ${canal == 'TODOS' ? 'Todos' : canal} · ${_etiquetaVendedorReporte()}',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                      child: Column(
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final one = constraints.maxWidth < 760;
                              final gap = 10.0;
                              final w = one
                                  ? constraints.maxWidth
                                  : (constraints.maxWidth - gap * 3) / 4;

                              final cards = [
                                _previewKpi(
                                  'Facturación',
                                  'US\$ ${money.format(fact)}',
                                  azulClaro,
                                  Icons.bar_chart_outlined,
                                ),
                                _previewKpi(
                                  'Peso cobre',
                                  '${money.format(peso)} kg',
                                  naranja,
                                  Icons.scale_outlined,
                                ),
                                _previewKpi(
                                  'Facturas',
                                  integer.format(facturas),
                                  verde,
                                  Icons.description_outlined,
                                ),
                                _previewKpi(
                                  'Clientes',
                                  integer.format(clientes),
                                  morado,
                                  Icons.groups_outlined,
                                ),
                              ];

                              return Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: cards
                                    .map(
                                      (c) => SizedBox(width: w, child: c),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final stacked = constraints.maxWidth < 900;
                              if (stacked) {
                                return Column(
                                  children: [
                                    _previewAsesores(topAsesores),
                                    const SizedBox(height: 12),
                                    _previewClientes(topClientes),
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _previewAsesores(topAsesores),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _previewClientes(topClientes),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cerrar'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: () => _imprimirMes(
                            periodo: periodo,
                            fact: fact,
                            peso: peso,
                            facturas: facturas,
                            clientes: clientes,
                            asesores: topAsesores,
                            clientesTop: topClientes,
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: azulClaro,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 13,
                            ),
                          ),
                          icon: const Icon(Icons.print_outlined, size: 19),
                          label: const Text(
                            'Imprimir vista previa',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
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
    );
  }

  Widget _previewKpi(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .16)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewAsesores(List<Map<String, dynamic>> rows) {
    return _previewTableCard(
      title: 'Detalle por asesor',
      icon: Icons.groups_outlined,
      color: azul,
      headers: const [
        '#',
        'Asesor',
        'Facturación (US\$)',
        'Peso cobre (kg)',
        'Facturas',
        'Clientes',
      ],
      rows: [
        for (var i = 0; i < rows.length; i++)
          [
            '${i + 1}',
            _s(rows[i]['vendedor']),
            'US\$ ${money.format(_n(rows[i]['facturacion']))}',
            money.format(_n(rows[i]['peso'])),
            integer.format(_n(rows[i]['facturas']).round()),
            integer.format(_n(rows[i]['clientes']).round()),
          ],
      ],
    );
  }

  Widget _previewClientes(List<Map<String, dynamic>> rows) {
    return _previewTableCard(
      title: 'Top clientes del mes',
      icon: Icons.business_outlined,
      color: morado,
      headers: const [
        '#',
        'Cliente',
        'Facturación (US\$)',
        'Peso cobre (kg)',
        'Facturas',
      ],
      rows: [
        for (var i = 0; i < rows.length; i++)
          [
            '${i + 1}',
            _s(rows[i]['cliente']),
            'US\$ ${money.format(_n(rows[i]['facturacion']))}',
            money.format(_n(rows[i]['peso'])),
            integer.format(_n(rows[i]['facturas']).round()),
          ],
      ],
    );
  }

  Widget _previewTableCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              headingRowHeight: 35,
              dataRowMinHeight: 34,
              dataRowMaxHeight: 42,
              headingRowColor: WidgetStateProperty.all(
                const Color(0xFFF0F5FA),
              ),
              columns: headers
                  .map(
                    (h) => DataColumn(
                      label: Text(
                        h,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              rows: rows
                  .map(
                    (r) => DataRow(
                      cells: r
                          .map(
                            (v) => DataCell(
                              Text(
                                v,
                                style: const TextStyle(fontSize: 9),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _imprimirMes({
    required String periodo,
    required double fact,
    required double peso,
    required int facturas,
    required int clientes,
    required List<Map<String, dynamic>> asesores,
    required List<Map<String, dynamic>> clientesTop,
  }) async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) async {
          final pdf = pw.Document();

          pdf.addPage(
            pw.MultiPage(
              pageFormat: PdfPageFormat.a4.landscape,
              margin: const pw.EdgeInsets.all(24),
              build: (context) => [
                pw.Text(
                  'ELCOPE — VISTA PREVIA COMERCIAL $periodo',
                  style: pw.TextStyle(
                    color: PdfColor.fromHex('#0B4A78'),
                    fontSize: 17,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Canal: ${canal == 'TODOS' ? 'Todos' : canal} · ${vendedor == 'TODOS' ? 'Todos los asesores' : vendedor}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  children: [
                    _pdfKpiCompact('Facturación', 'US\$ ${money.format(fact)}'),
                    pw.SizedBox(width: 8),
                    _pdfKpiCompact('Peso cobre', '${money.format(peso)} kg'),
                    pw.SizedBox(width: 8),
                    _pdfKpiCompact('Facturas', integer.format(facturas)),
                    pw.SizedBox(width: 8),
                    _pdfKpiCompact('Clientes', integer.format(clientes)),
                  ],
                ),
                pw.SizedBox(height: 15),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: _pdfVendedoresCompact(asesores),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: _pdfClientesCompact(clientesTop),
                    ),
                  ],
                ),
              ],
            ),
          );

          return pdf.save();
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo imprimir: $e')),
      );
    }
  }

  Widget _dialogKpi(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  String _etiquetaVendedorReporte() {
    if (vendedor != 'TODOS') return vendedor;

    final rol = Sesion.rol.trim().toLowerCase();
    if (rol == 'gerencia') return 'Gerencia - Todos los asesores';
    if (rol == 'jefe lima') return 'Jefatura - Todos Lima';
    if (rol == 'jefe provincia') return 'Jefatura - Todos Provincias';
    return 'Todos los asesores';
  }

  Future<void> _imprimir() async {
    if (loading || data.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El reporte todavía no tiene datos para imprimir.')),
        );
      }
      return;
    }

    final kActual = Map<String, dynamic>.from(
      data['kpis'] is Map ? data['kpis'] as Map : <String, dynamic>{},
    );
    final kAnterior = Map<String, dynamic>.from(
      dataAnterior['kpis'] is Map
          ? dataAnterior['kpis'] as Map
          : <String, dynamic>{},
    );
    final venActual = _mapList(data['vendedores'])
      ..sort((a, b) => _n(b['facturacion']).compareTo(_n(a['facturacion'])));
    final venAnterior = _mapList(dataAnterior['vendedores']);
    final cliActual = _mapList(data['clientes'])
      ..sort((a, b) => _n(b['facturacion']).compareTo(_n(a['facturacion'])));
    final cliAnterior = _mapList(dataAnterior['clientes']);
    final clasesActual = _mapList(data['asesores_clase']);
    final clasesAnterior = _mapList(dataAnterior['asesores_clase']);
    final mensual = _compararMensual();
    final vendedorReporte = _etiquetaVendedorReporte();

    int nuevos = 0;
    int crecieron = 0;
    int disminuyeron = 0;
    int sinCompra = 0;
    final mapA = {for (final r in cliActual) _s(r['cliente']): r};
    final mapB = {for (final r in cliAnterior) _s(r['cliente']): r};
    final nombres = <String>{...mapA.keys, ...mapB.keys}
        .where((x) => x.isNotEmpty)
        .toList();
    for (final nombre in nombres) {
      final va = _n(mapA[nombre]?['facturacion']);
      final vb = _n(mapB[nombre]?['facturacion']);
      if (vb == 0 && va > 0) {
        nuevos++;
      } else if (vb > 0 && va > vb) {
        crecieron++;
      } else if (va > 0 && va < vb) {
        disminuyeron++;
      } else if (va == 0 && vb > 0) {
        sinCompra++;
      }
    }

    final factActual = _n(kActual['facturacion']);
    final factAnterior = _n(kAnterior['facturacion']);
    final promedioMensual = mensual.isEmpty ? 0.0 : factActual / mensual.length;
    final mejorMes = mensual.isEmpty
        ? null
        : mensual.reduce(
            (a, b) => _n(a['facturacion']) >= _n(b['facturacion']) ? a : b,
          );
    final crecimiento = factAnterior == 0
        ? 0.0
        : ((factActual - factAnterior) / factAnterior) * 100;
    final ticket = _n(kActual['facturas']) == 0
        ? 0.0
        : factActual / _n(kActual['facturas']);
    final kgMil = factActual == 0 ? 0.0 : _n(kActual['peso']) / (factActual / 1000);

    try {
      final logoData = await services.rootBundle.load(
        'assets/crm/images/logo_elcope.png',
      );
      final logo = pw.MemoryImage(logoData.buffer.asUint8List());

      await Printing.layoutPdf(
        name: 'ELCOPE_Reporte_Ejecutivo_${anioActual}_vs_$anioComparacion',
        format: PdfPageFormat.a4.landscape,
        onLayout: (format) async {
          final pdf = pw.Document();
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4.landscape,
              margin: const pw.EdgeInsets.fromLTRB(12, 8, 12, 7),
              build: (context) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // ENCABEZADO
                    pw.SizedBox(
                      height: 46,
                      child: pw.Row(
                        children: [
                          pw.SizedBox(
                            width: 135,
                            child: pw.Image(logo, width: 112, height: 38, fit: pw.BoxFit.contain),
                          ),
                          pw.Expanded(
                            child: pw.Column(
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.Text(
                                  'REPORTE EJECUTIVO CRM',
                                  style: pw.TextStyle(
                                    color: PdfColor.fromHex('#0B4A78'),
                                    fontSize: 16,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.SizedBox(height: 1),
                                pw.Text(
                                  'FACTURACIÓN COMERCIAL - COMPARATIVO $anioActual vs $anioComparacion',
                                  style: pw.TextStyle(
                                    color: PdfColor.fromHex('#0B4A78'),
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  'Vendedor: $vendedorReporte',
                                  style: pw.TextStyle(
                                    color: PdfColor.fromHex('#1877D1'),
                                    fontSize: 6.5,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(
                            width: 175,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                _pdfMetaLine('Canal:', canal == 'TODOS' ? 'Todos' : canal),
                                _pdfMetaLine('Vendedor:', vendedorReporte),
                                _pdfMetaLine('Periodo:', '${date.format(desde)} - ${date.format(hasta)}'),
                                _pdfMetaLine('Comparar con:', '$anioComparacion'),
                                _pdfMetaLine('Fecha de emisión:', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Container(height: 1.5, color: PdfColor.fromHex('#0B4A78')),
                    pw.SizedBox(height: 4),

                    // KPIs
                    pw.SizedBox(
                      height: 45,
                      child: pw.Row(
                        children: [
                          _pdfKpiComparativo('Facturación', _n(kActual['facturacion']), _n(kAnterior['facturacion']), prefix: 'US\$ ', suffix: '', compact: true),
                          pw.SizedBox(width: 4),
                          _pdfKpiComparativo('Peso cobre', _n(kActual['peso']), _n(kAnterior['peso']), prefix: '', suffix: ' kg', compact: true),
                          pw.SizedBox(width: 4),
                          _pdfKpiComparativo('Facturas', _n(kActual['facturas']), _n(kAnterior['facturas']), prefix: '', suffix: '', integerValue: true),
                          pw.SizedBox(width: 4),
                          _pdfKpiComparativo('Clientes', _n(kActual['clientes']), _n(kAnterior['clientes']), prefix: '', suffix: '', integerValue: true),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 4),

                    // GRÁFICOS
                    pw.SizedBox(
                      height: 145,
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          pw.Expanded(
                            child: _pdfMonthlyBars(
                              mensual,
                              field: 'facturacion',
                              title: 'Evolución mensual de facturación (US\$)',
                              subtitle: 'Comparativo $anioActual vs $anioComparacion',
                              compactType: 'money',
                            ),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Expanded(
                            child: _pdfMonthlyBars(
                              mensual,
                              field: 'peso',
                              title: 'Evolución mensual de peso cobre (kg)',
                              subtitle: 'Comparativo $anioActual vs $anioComparacion',
                              compactType: 'kg',
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 4),

                    // RANKING + CLASE + TOP 10
                    pw.SizedBox(
                      height: 151,
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          pw.SizedBox(width: 202, child: _pdfVendedoresComparativo(venActual, venAnterior)),
                          pw.SizedBox(width: 6),
                          pw.SizedBox(width: 385, child: _pdfAsesorClase(clasesActual, clasesAnterior)),
                          pw.SizedBox(width: 6),
                          pw.Expanded(child: _pdfClientesCompactoCompleto(cliActual, cliAnterior)),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 4),

                    // CARTERA + INDICADORES EJECUTIVOS
                    pw.SizedBox(
                      height: 74,
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          pw.Expanded(
                            child: _pdfCarteraCompacta(nuevos, crecieron, disminuyeron, sinCompra),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Expanded(
                            child: _pdfIndicadoresCompactos(
                              promedioMensual: promedioMensual,
                              mejorMes: mejorMes,
                              crecimiento: crecimiento,
                              ticket: ticket,
                              kgMil: kgMil,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.SizedBox(
                      height: 12,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('ELCOPE  |  Más de 35 años conectando el desarrollo del Perú', style: const pw.TextStyle(fontSize: 5.3, color: PdfColors.grey700)),
                          pw.Text('Reporte generado el ${DateFormat('dd/MM/yyyy - HH:mm').format(DateTime.now())}   |   Página 1 de 1', style: const pw.TextStyle(fontSize: 5.3, color: PdfColors.grey700)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
          return pdf.save();
        },
      );
    } catch (e, st) {
      debugPrint('ERROR AL GENERAR REPORTE PDF: $e');
      debugPrint('$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo imprimir el reporte: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }

  pw.Widget _pdfClientesCompactoCompleto(
    List<Map<String, dynamic>> actualRows,
    List<Map<String, dynamic>> anteriorRows,
  ) {
    final mapA = {for (final r in actualRows) _s(r['cliente']): r};
    final mapB = {for (final r in anteriorRows) _s(r['cliente']): r};
    final names = <String>{...mapA.keys, ...mapB.keys}
        .where((x) => x.isNotEmpty)
        .toList()
      ..sort((a, b) => _n(mapA[b]?['facturacion']).compareTo(_n(mapA[a]?['facturacion'])));
    final top = names.take(10).toList();

    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(5, 4, 5, 3),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColor.fromHex('#D6E0E8'), width: .6),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text('Top 10 clientes - Facturación comparativa', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0B4A78'))),
          pw.Text('Clientes con mayor facturación acumulada', style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey600)),
          pw.SizedBox(height: 2),
          pw.Row(children: [
            pw.SizedBox(width: 12, child: pw.Text('#', style: pw.TextStyle(fontSize: 4.8, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(flex: 5, child: pw.Text('Cliente', style: pw.TextStyle(fontSize: 4.8, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(flex: 2, child: pw.Text('$anioActual', style: pw.TextStyle(fontSize: 4.8, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(flex: 2, child: pw.Text('$anioComparacion', style: pw.TextStyle(fontSize: 4.8, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(width: 30, child: pw.Text('Var.', style: pw.TextStyle(fontSize: 4.8, fontWeight: pw.FontWeight.bold))),
          ]),
          pw.Container(height: .4, color: PdfColor.fromHex('#CBD5E1')),
          for (var i = 0; i < top.length; i++)
            pw.Container(
              height: 11.5,
              padding: const pw.EdgeInsets.symmetric(vertical: 1),
              child: pw.Row(children: [
                pw.SizedBox(width: 12, child: pw.Text('${i + 1}', style: const pw.TextStyle(fontSize: 4.6))),
                pw.Expanded(flex: 5, child: pw.Text(_s(top[i]), maxLines: 1, overflow: pw.TextOverflow.clip, style: const pw.TextStyle(fontSize: 4.5))),
                pw.Expanded(flex: 2, child: pw.Text(_compactPdf(_n(mapA[top[i]]?['facturacion'])), style: const pw.TextStyle(fontSize: 4.5))),
                pw.Expanded(flex: 2, child: pw.Text(_compactPdf(_n(mapB[top[i]]?['facturacion'])), style: const pw.TextStyle(fontSize: 4.5))),
                pw.SizedBox(width: 30, child: pw.Text(_variationText(_n(mapA[top[i]]?['facturacion']), _n(mapB[top[i]]?['facturacion'])), style: const pw.TextStyle(fontSize: 4.2))),
              ]),
            ),
        ],
      ),
    );
  }

  pw.Widget _pdfCarteraCompacta(int nuevos, int crecieron, int disminuyeron, int sinCompra) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 3),
      decoration: pw.BoxDecoration(color: PdfColors.white, border: pw.Border.all(color: PdfColor.fromHex('#D6E0E8'), width: .6), borderRadius: pw.BorderRadius.circular(5)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Text('Comportamiento de cartera', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0B4A78'))),
        pw.Text('Comparativo $anioActual vs $anioComparacion', style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey600)),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          _pdfCarteraMini('Nuevos', nuevos, '#08A66A'),
          pw.SizedBox(width: 4),
          _pdfCarteraMini('Crecieron', crecieron, '#1877D1'),
          pw.SizedBox(width: 4),
          _pdfCarteraMini('Disminuyeron', disminuyeron, '#F59E0B'),
          pw.SizedBox(width: 4),
          _pdfCarteraMini('Sin compra', sinCompra, '#E53935'),
        ]),
      ]),
    );
  }

  pw.Widget _pdfCarteraMini(String label, int value, String hex) {
    return pw.Expanded(
      child: pw.Container(
        height: 38,
        padding: const pw.EdgeInsets.all(4),
        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F8FAFC'), border: pw.Border.all(color: PdfColor.fromHex(hex), width: .45), borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 4.4, color: PdfColors.grey700)),
          pw.Text('$value', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex(hex))),
        ]),
      ),
    );
  }

  pw.Widget _pdfIndicadoresCompactos({
    required double promedioMensual,
    required Map<String, dynamic>? mejorMes,
    required double crecimiento,
    required double ticket,
    required double kgMil,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 3),
      decoration: pw.BoxDecoration(color: PdfColors.white, border: pw.Border.all(color: PdfColor.fromHex('#D6E0E8'), width: .6), borderRadius: pw.BorderRadius.circular(5)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Text('Indicadores ejecutivos-Promedio', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0B4A78'))),
        pw.Text('Lectura rápida para gestión comercial', style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey600)),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.Expanded(child: _pdfIndicatorMini('Promedio mensual', 'US\$ ${money.format(promedioMensual)}')),
          pw.SizedBox(width: 4),
          pw.Expanded(child: _pdfIndicatorMini('Mejor mes', mejorMes == null ? '-' : '${_s(mejorMes['periodo'])} · US\$ ${money.format(_n(mejorMes['facturacion']))}')),
        ]),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.Expanded(child: _pdfIndicatorMini('Crecimiento acumulado', '${crecimiento >= 0 ? '+' : ''}${crecimiento.toStringAsFixed(1)}%')),
          pw.SizedBox(width: 4),
          pw.Expanded(child: _pdfIndicatorMini('Ticket promedio', 'US\$ ${money.format(ticket)}')),
        ]),
        pw.SizedBox(height: 2),
        pw.Text('Kg / US\$ 1,000: ${kgMil.toStringAsFixed(2)} kg', style: const pw.TextStyle(fontSize: 4.8, color: PdfColors.grey700)),
      ]),
    );
  }

  pw.Widget _pdfIndicatorMini(String title, String value) {
    return pw.Container(
      height: 20,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F4F8FC'), border: pw.Border.all(color: PdfColor.fromHex('#D7E5F1'), width: .4), borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, mainAxisAlignment: pw.MainAxisAlignment.center, children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 4, color: PdfColors.grey600)),
        pw.Text(value, maxLines: 1, overflow: pw.TextOverflow.clip, style: pw.TextStyle(fontSize: 5.2, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1877D1'))),
      ]),
    );
  }

  pw.Widget _pdfMetaLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.2),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label ',
              style: pw.TextStyle(
                fontSize: 6,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#334155'),
              ),
            ),
            pw.TextSpan(
              text: value,
              style: pw.TextStyle(
                fontSize: 6,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#0B4A78'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfKpiComparativo(
    String title,
    double actual,
    double anterior, {
    required String prefix,
    required String suffix,
    bool integerValue = false,
    bool compact = true,
  }) {
    final variacion =
        anterior == 0 ? 0.0 : ((actual - anterior) / anterior) * 100;
    final positivo = variacion >= 0;
    final color = positivo
        ? PdfColor.fromHex('#079B63')
        : PdfColor.fromHex('#D93838');

    String value(double v) {
      if (integerValue) return integer.format(v.round());
      if (compact) {
        return prefix +
            (suffix.isEmpty ? _compactPdf(v) : _compactPdf(v)) +
            suffix;
      }
      return prefix + money.format(v) + suffix;
    }

    return pw.Expanded(
      child: pw.Container(
        height: 53,
        padding: const pw.EdgeInsets.fromLTRB(9, 6, 9, 5),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#F3F8FC'),
          border: pw.Border.all(
            color: PdfColor.fromHex('#B7D1E3'),
            width: .7,
          ),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 6.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#0B4A78'),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '$anioActual',
                        style: const pw.TextStyle(
                          fontSize: 5.5,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.Text(
                        value(actual),
                        style: pw.TextStyle(
                          fontSize: 8.2,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0B4A78'),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  width: .5,
                  height: 22,
                  color: PdfColor.fromHex('#CBD5E1'),
                ),
                pw.SizedBox(width: 7),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '$anioComparacion',
                        style: const pw.TextStyle(
                          fontSize: 5.5,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.Text(
                        value(anterior),
                        style: const pw.TextStyle(
                          fontSize: 7.8,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              '${positivo ? '▲' : '▼'} ${variacion >= 0 ? '+' : ''}${variacion.toStringAsFixed(1)}% vs $anioComparacion',
              style: pw.TextStyle(
                fontSize: 5.8,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfMonthlyBars(
    List<Map<String, dynamic>> rows, {
    required String field,
    required String title,
    required String subtitle,
    required String compactType,
  }) {
    // IMPORTANTE: el PDF no puede reutilizar el gráfico Flutter del dashboard.
    // Aquí dibujamos las barras directamente con widgets de pdf.
    // Se usan anchos/alturas fijos para evitar que Expanded/Flex deje el
    // gráfico vacío al imprimir en Windows.
    double maxValue = 0;
    for (final row in rows) {
      final a = _n(row['a']?[field]);
      final b = _n(row['b']?[field]);
      if (a > maxValue) maxValue = a;
      if (b > maxValue) maxValue = b;
    }
    if (maxValue <= 0) maxValue = 1;

    String label(double value) {
      // En impresión evitamos K/M: ocupan poco espacio y se leen mal.
      // Para facturación mostramos US$ en una línea y el monto completo debajo.
      if (compactType == 'kg') {
        return '${money.format(value)} kg';
      }
      return 'US\$\n${money.format(value)}';
    }

    final visibleRows = rows.take(12).toList();
    final monthWidth = visibleRows.length <= 9 ? 44.0 : 34.0;

    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(6, 5, 6, 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(
          color: PdfColor.fromHex('#D6E0E8'),
          width: .7,
        ),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#0B4A78'),
            ),
          ),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(
              fontSize: 5.5,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 7,
                height: 7,
                color: PdfColor.fromHex('#1877D1'),
              ),
              pw.SizedBox(width: 2),
              pw.Text('$anioActual', style: const pw.TextStyle(fontSize: 5.2)),
              pw.SizedBox(width: 8),
              pw.Container(
                width: 7,
                height: 7,
                color: PdfColor.fromHex('#F08A00'),
              ),
              pw.SizedBox(width: 2),
              pw.Text('$anioComparacion', style: const pw.TextStyle(fontSize: 5.2)),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.SizedBox(
            height: 103,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                for (final row in visibleRows)
                  pw.SizedBox(
                    width: monthWidth,
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.SizedBox(
                          height: 75,
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              _pdfBarFixed(
                                value: _n(row['a']?[field]),
                                maxValue: maxValue,
                                color: PdfColor.fromHex('#1877D1'),
                                label: label(_n(row['a']?[field])),
                              ),
                              pw.SizedBox(width: 1.5),
                              _pdfBarFixed(
                                value: _n(row['b']?[field]),
                                maxValue: maxValue,
                                color: PdfColor.fromHex('#F08A00'),
                                label: label(_n(row['b']?[field])),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Container(
                          width: monthWidth - 2,
                          alignment: pw.Alignment.center,
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#F1F5F9'),
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                          child: pw.Text(
                            _s(row['label']),
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: 5.2,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#0F172A'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfBarFixed({
    required double value,
    required double maxValue,
    required PdfColor color,
    required String label,
  }) {
    final ratio = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0).toDouble();
    final barHeight = value <= 0 ? 1.0 : 48.0 * ratio.clamp(0.06, 1.0).toDouble();

    return pw.SizedBox(
      width: 15,
      height: 75,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(
            height: 23,
            width: 34,
            child: pw.Text(
              label,
              maxLines: 2,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 5.0,
                lineSpacing: 0.4,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ),
          pw.Container(
            width: 8,
            height: barHeight,
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(2),
                topRight: pw.Radius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfBar({
    required double value,
    required double maxValue,
    required PdfColor color,
    required String label,
  }) {
    final h = value <= 0 ? 1.0 : 72.0 * (value / maxValue).clamp(0.04, 1.0).toDouble();

    return pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.SizedBox(
          height: 17,
          child: pw.Text(
            label,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 4.1,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ),
        pw.Container(
          width: 9,
          height: h,
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.only(
              topLeft: pw.Radius.circular(2),
              topRight: pw.Radius.circular(2),
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfAsesorClase(
    List<Map<String, dynamic>> actualRows,
    List<Map<String, dynamic>> anteriorRows,
  ) {
    final mapA = <String, Map<String, double>>{};
    final mapB = <String, Map<String, double>>{};
    final totalA = <String, double>{};
    final totalB = <String, double>{};

    void load(
      List<Map<String, dynamic>> rows,
      Map<String, Map<String, double>> map,
      Map<String, double> totals,
    ) {
      for (final r in rows) {
        final asesor =
            _s(r['vendedor']).isEmpty ? 'SIN ASESOR' : _s(r['vendedor']);
        final clase = _s(r['clase']).isEmpty
            ? 'SIN CLASE'
            : _s(r['clase']).toUpperCase();
        final monto = _n(r['facturacion']);
        map.putIfAbsent(asesor, () => <String, double>{});
        map[asesor]![clase] = (map[asesor]![clase] ?? 0) + monto;
        totals[asesor] = (totals[asesor] ?? 0) + monto;
      }
    }

    load(actualRows, mapA, totalA);
    load(anteriorRows, mapB, totalB);

    final asesores = <String>{...mapA.keys, ...mapB.keys}.toList()
      ..sort(
        (a, b) => (totalA[b] ?? 0).compareTo(totalA[a] ?? 0),
      );

    const prioridad = <String>[
      'CL5',
      'CL2',
      'CL1',
      'SIN CLASE',
      'CL6',
    ];

    final clases = <String>{
      ...mapA.values.expand((m) => m.keys),
      ...mapB.values.expand((m) => m.keys),
    };
    final clasesOrdenadas = <String>[];
    for (final clase in prioridad) {
      if (clases.remove(clase)) clasesOrdenadas.add(clase);
    }
    final restantes = clases.toList()..sort();
    clasesOrdenadas.addAll(restantes);

    double pct(
      Map<String, Map<String, double>> source,
      Map<String, double> totals,
      String asesor,
      String clase,
    ) {
      final total = totals[asesor] ?? 0;
      if (total <= 0) return 0;
      return ((source[asesor]?[clase] ?? 0) / total) * 100;
    }

    final headers = <pw.Widget>[
      pw.Text(
        'Asesor',
        style: pw.TextStyle(
          fontSize: 5.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#0B4A78'),
        ),
      ),
      for (final clase in clasesOrdenadas.take(6))
        pw.Center(
          child: pw.Text(
            clase,
            style: pw.TextStyle(
              fontSize: 5.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#0B4A78'),
            ),
          ),
        ),
      pw.Center(
        child: pw.Text(
          'Total fact.',
          style: pw.TextStyle(
            fontSize: 5.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#0B4A78'),
          ),
        ),
      ),
    ];

    final table = pw.Table(
      border: pw.TableBorder.all(
        color: PdfColor.fromHex('#DCE5ED'),
        width: .35,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.7),
        for (var i = 1; i <= clasesOrdenadas.take(6).length; i++)
          i: const pw.FlexColumnWidth(1),
        clasesOrdenadas.take(6).length + 1: const pw.FlexColumnWidth(1.35),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F2F6FA'),
          ),
          children: headers
              .map(
                (w) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 3,
                  ),
                  child: w,
                ),
              )
              .toList(),
        ),
        for (final asesor in asesores.take(8))
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 3,
                  vertical: 2,
                ),
                child: pw.Text(
                  asesor,
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                  style: const pw.TextStyle(fontSize: 5.2),
                ),
              ),
              for (final clase in clasesOrdenadas.take(6))
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 1,
                    vertical: 1,
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        '${pct(mapA, totalA, asesor, clase).toStringAsFixed(1)}%',
                        style: pw.TextStyle(
                          fontSize: 5.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#1877D1'),
                        ),
                      ),
                      pw.Text(
                        '${pct(mapB, totalB, asesor, clase).toStringAsFixed(1)}%',
                        style: const pw.TextStyle(
                          fontSize: 4.8,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.Text(
                        _ppText(
                          pct(mapA, totalA, asesor, clase) -
                              pct(mapB, totalB, asesor, clase),
                        ),
                        style: pw.TextStyle(
                          fontSize: 4.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex(
                            pct(mapA, totalA, asesor, clase) -
                                        pct(mapB, totalB, asesor, clase) >=
                                    0
                                ? '#079B63'
                                : '#D93838',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 2,
                  vertical: 2,
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'US\$ ${_compactPdf(totalA[asesor] ?? 0)}',
                      style: pw.TextStyle(
                        fontSize: 5.2,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#1877D1'),
                      ),
                    ),
                    pw.Text(
                      'US\$ ${_compactPdf(totalB[asesor] ?? 0)}',
                      style: const pw.TextStyle(
                        fontSize: 4.6,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );

    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(6, 5, 6, 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(
          color: PdfColor.fromHex('#D6E0E8'),
          width: .7,
        ),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            'Facturación por asesor y clase - Comparativo',
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#0B4A78'),
            ),
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            '$anioActual / $anioComparacion / variación en puntos porcentuales de la mezcla de cada asesor',
            style: const pw.TextStyle(
              fontSize: 5.2,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            children: [
              pw.Container(
                width: 7,
                height: 7,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: PdfColor.fromHex('#1877D1'),
                ),
              ),
              pw.SizedBox(width: 2),
              pw.Text('$anioActual', style: const pw.TextStyle(fontSize: 5)),
              pw.SizedBox(width: 7),
              pw.Container(
                width: 7,
                height: 7,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(width: 2),
              pw.Text('$anioComparacion', style: const pw.TextStyle(fontSize: 5)),
              pw.SizedBox(width: 7),
              pw.Text(
                'pp = variación de participación',
                style: const pw.TextStyle(
                  fontSize: 4.8,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Expanded(child: table),
        ],
      ),
    );
  }

  String _ppText(double value) {
    return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)} pp';
  }

  pw.Widget _pdfVendedoresComparativo(
    List<Map<String, dynamic>> actualRows,
    List<Map<String, dynamic>> anteriorRows,
  ) {
    final mapA = {for (final r in actualRows) _s(r['vendedor']): r};
    final mapB = {for (final r in anteriorRows) _s(r['vendedor']): r};
    final names = <String>{...mapA.keys, ...mapB.keys}
        .where((x) => x.isNotEmpty)
        .toList()
      ..sort(
        (a, b) => _n(mapA[b]?['facturacion'])
            .compareTo(_n(mapA[a]?['facturacion'])),
      );

    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(6, 5, 6, 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(
          color: PdfColor.fromHex('#D6E0E8'),
          width: .7,
        ),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            'Ranking de asesores - Facturación comparativa',
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#0B4A78'),
            ),
          ),
          pw.Text(
            'Facturación acumulada y variación',
            style: const pw.TextStyle(
              fontSize: 5.2,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            children: [
              pw.Expanded(
                flex: 1,
                child: pw.Text(
                  '#',
                  style: pw.TextStyle(
                    fontSize: 5.2,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#0B4A78'),
                  ),
                ),
              ),
              pw.Expanded(
                flex: 4,
                child: pw.Text(
                  'Asesor',
                  style: pw.TextStyle(
                    fontSize: 5.2,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#0B4A78'),
                  ),
                ),
              ),
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  '$anioActual',
                  style: pw.TextStyle(
                    fontSize: 5.2,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#0B4A78'),
                  ),
                ),
              ),
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  '$anioComparacion',
                  style: const pw.TextStyle(
                    fontSize: 5.2,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Text(
                  'Variación',
                  style: pw.TextStyle(
                    fontSize: 5.2,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#0B4A78'),
                  ),
                ),
              ),
            ],
          ),
          pw.Divider(
            color: PdfColor.fromHex('#DCE5ED'),
            height: 3,
          ),
          for (var i = 0; i < names.take(8).length; i++)
            _pdfRankingRow(
              mapA[names[i]] ?? <String, dynamic>{'vendedor': names[i]},
              mapB[names[i]] ?? <String, dynamic>{},
              i + 1,
            ),
        ],
      ),
    );
  }

  pw.Widget _pdfRankingRow(
    Map<String, dynamic> rowActual,
    Map<String, dynamic> rowAnterior,
    int index,
  ) {
    final current = _n(rowActual['facturacion']);
    final previous = _n(rowAnterior['facturacion']);
    final variation = previous == 0
        ? 0.0
        : ((current - previous) / previous) * 100;
    final color = variation >= 0
        ? PdfColor.fromHex('#079B63')
        : PdfColor.fromHex('#D93838');

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 1,
            child: pw.Text(
              '$index',
              style: const pw.TextStyle(fontSize: 5.2),
            ),
          ),
          pw.Expanded(
            flex: 4,
            child: pw.Text(
              _s(rowActual['vendedor']).isEmpty
                  ? _s(rowAnterior['vendedor'])
                  : _s(rowActual['vendedor']),
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              style: const pw.TextStyle(fontSize: 5.2),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              'US\$ ${money.format(current)}',
              style: pw.TextStyle(
                fontSize: 5.1,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#1877D1'),
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              'US\$ ${money.format(previous)}',
              style: const pw.TextStyle(
                fontSize: 4.9,
                color: PdfColors.grey600,
              ),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              '${variation >= 0 ? '▲ +' : '▼ '}${variation.toStringAsFixed(1)}%',
              style: pw.TextStyle(
                fontSize: 4.9,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfClientesComparativo(
    List<Map<String, dynamic>> actualRows,
    List<Map<String, dynamic>> anteriorRows,
  ) {
    final mapA = {for (final r in actualRows) _s(r['cliente']): r};
    final mapB = {for (final r in anteriorRows) _s(r['cliente']): r};
    final names = <String>{...mapA.keys, ...mapB.keys}
        .where((x) => x.isNotEmpty)
        .toList()
      ..sort(
        (a, b) => _n(mapA[b]?['facturacion'])
            .compareTo(_n(mapA[a]?['facturacion'])),
      );

    final top = names.take(10).toList();

    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(6, 5, 6, 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(
          color: PdfColor.fromHex('#D6E0E8'),
          width: .7,
        ),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            'Top 10 clientes - Facturación comparativa',
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#0B4A78'),
            ),
          ),
          pw.Text(
            'Clientes con mayor facturación acumulada',
            style: const pw.TextStyle(
              fontSize: 5.2,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Table.fromTextArray(
            headers: ['#', 'Cliente', '$anioActual', '$anioComparacion', 'Var.'],
            data: [
              for (var i = 0; i < top.length; i++)
                [
                  '${i + 1}',
                  top[i],
                  'US\$ ${_compactPdf(_n(mapA[top[i]]?['facturacion']))}',
                  'US\$ ${_compactPdf(_n(mapB[top[i]]?['facturacion']))}',
                  _variationText(
                    _n(mapA[top[i]]?['facturacion']),
                    _n(mapB[top[i]]?['facturacion']),
                  ),
                ],
            ],
            headerStyle: pw.TextStyle(
              color: PdfColor.fromHex('#0B4A78'),
              fontSize: 4.8,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F2F6FA'),
            ),
            cellStyle: const pw.TextStyle(fontSize: 4.5),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 1.5,
              vertical: 1.8,
            ),
            border: pw.TableBorder.all(
              color: PdfColor.fromHex('#DDE5ED'),
              width: .3,
            ),
          ),
        ],
      ),
    );
  }

  String _variationText(double actual, double previous) {
    if (previous == 0) return '▲ +0.0%';
    final v = ((actual - previous) / previous) * 100;
    return '${v >= 0 ? '▲ +' : '▼ '}${v.toStringAsFixed(1)}%';
  }

  String _compactPdf(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)} M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)} K';
    return money.format(value);
  }


  // -------------------------------------------------------------------------
  // Compatibilidad con la vista previa/impresión mensual existente.
  // -------------------------------------------------------------------------
  pw.Widget _pdfKpiCompact(String title, String value) {
    return pw.Expanded(
      child: pw.Container(
        height: 38,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#F4F7FA'),
          border: pw.Border.all(color: PdfColor.fromHex('#C9D7E3')),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              title,
              style: const pw.TextStyle(
                fontSize: 6.5,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#0B4A78'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfSectionTitleCompact(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#0B4A78'),
        ),
      ),
    );
  }

  pw.Widget _pdfMonthlyCompact(List<Map<String, dynamic>> rows) {
    final dataRows = rows.map((r) {
      return [
        _s(r['periodo']),
        'US\$ ${money.format(_n(r['facturacion']))}',
        '${money.format(_n(r['peso']))} kg',
        integer.format(_n(r['facturas']).round()),
        integer.format(_n(r['clientes']).round()),
      ];
    }).toList();

    return pw.Table.fromTextArray(
      headers: const [
        'Periodo',
        'Facturación',
        'Peso cobre',
        'Facturas',
        'Clientes',
      ],
      data: dataRows,
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontSize: 6.5,
        fontWeight: pw.FontWeight.bold,
      ),
      headerDecoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#0B4A78'),
      ),
      cellStyle: const pw.TextStyle(fontSize: 6.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      border: pw.TableBorder.all(
        color: PdfColor.fromHex('#DDE5ED'),
        width: .4,
      ),
    );
  }

  pw.Widget _pdfVendedoresCompact(List<Map<String, dynamic>> rows) {
    final top = rows.take(8).toList();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pdfSectionTitleCompact('RANKING ASESORES'),
        pw.Table.fromTextArray(
          headers: const ['#', 'Asesor', 'Facturación'],
          data: [
            for (var i = 0; i < top.length; i++)
              [
                '${i + 1}',
                _s(top[i]['vendedor']),
                'US\$ ${_compactPdf(_n(top[i]['facturacion']))}',
              ],
          ],
          headerStyle: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 5.8,
            fontWeight: pw.FontWeight.bold,
          ),
          headerDecoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#1877D1'),
          ),
          cellStyle: const pw.TextStyle(fontSize: 5.8),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        ),
      ],
    );
  }

  pw.Widget _pdfClientesCompact(List<Map<String, dynamic>> rows) {
    final top = rows.take(8).toList();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pdfSectionTitleCompact('TOP 10 CLIENTES'),
        pw.Table.fromTextArray(
          headers: const ['#', 'Cliente', 'Facturación'],
          data: [
            for (var i = 0; i < top.length; i++)
              [
                '${i + 1}',
                _s(top[i]['cliente']),
                'US\$ ${_compactPdf(_n(top[i]['facturacion']))}',
              ],
          ],
          headerStyle: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 5.8,
            fontWeight: pw.FontWeight.bold,
          ),
          headerDecoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#5B45C5'),
          ),
          cellStyle: const pw.TextStyle(fontSize: 5.8),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 850;

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: azul,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Reporte Ejecutivo CRM',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: loading ? null : _cargar,
            icon: const Icon(Icons.refresh),
          ),
          if (!mobile)
            Padding(
              padding: const EdgeInsets.only(
                right: 12,
                top: 8,
                bottom: 8,
                left: 6,
              ),
              child: FilledButton.icon(
                onPressed: loading || data.isEmpty ? null : _imprimir,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF08A66A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.print_outlined, size: 20),
                label: const Text(
                  'Imprimir reporte',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Imprimir reporte',
              onPressed: loading || data.isEmpty ? null : _imprimir,
              icon: const Icon(Icons.print_outlined),
            ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          mobile ? 10 : 20,
          14,
          mobile ? 10 : 20,
          16,
        ),
        child: Column(
          children: [
            _toolbar(mobile),
            const SizedBox(height: 14),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Error al cargar el reporte:\n$error',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _contenido(mobile),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(bool mobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        final oneColumn = width < 700;
        final twoColumns = width >= 700 && width < 1050;
        const gap = 10.0;

        double fieldWidth(double desktopWidth) {
          if (oneColumn) return width;
          if (twoColumns) return (width - gap) / 2;
          return desktopWidth;
        }

        return Card(
          elevation: 1,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: gap,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: fieldWidth(225),
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        vendedores.contains(vendedor) || vendedor == 'TODOS'
                            ? vendedor
                            : 'TODOS',
                    isExpanded: true,
                    decoration: _filtroDecoration(
                      'Vendedor',
                      Icons.person_outline,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'TODOS',
                        child: Text(
                          esGerencia
                              ? 'Todos los asesores · ${canal == 'TODOS' ? 'Todos los canales' : canal}'
                              : esJefatura
                                  ? 'Todos los asesores · ${canal == 'PROVINCIAS' ? 'Provincias' : 'Lima'}'
                                  : 'Todos',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...vendedores.map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(
                            v,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;

                      setState(() {
                        vendedor = value;
                        if (esJefatura) {
                          canal = Sesion.rol.trim().toLowerCase() ==
                                  'jefe provincia'
                              ? 'PROVINCIAS'
                              : 'LIMA';
                        }
                      });

                      await _cargar();
                    },
                  ),
                ),
                SizedBox(
                  width: fieldWidth(175),
                  child: DropdownButtonFormField<String>(
                    initialValue: canalesDisponibles.contains(canal)
                        ? canal
                        : canalesDisponibles.first,
                    isExpanded: true,
                    decoration: _filtroDecoration(
                      esGerencia ? 'Canal' : 'Canal (restringido)',
                      Icons.storefront_outlined,
                    ),
                    items: canalesDisponibles
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              c == 'TODOS' ? 'Todos' : c,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: esGerencia
                        ? (value) async {
                            if (value == null) return;
                            setState(() => canal = value);
                            await _cargar();
                          }
                        : null,
                  ),
                ),
                SizedBox(
                  width: fieldWidth(145),
                  child: OutlinedButton.icon(
                    onPressed: () => _seleccionarAnio(true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4F5D95),
                      side: const BorderSide(color: Color(0xFFB9B8C8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text(
                      'Año actual $anioActual',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                SizedBox(
                  width: fieldWidth(160),
                  child: OutlinedButton.icon(
                    onPressed: () => _seleccionarAnio(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4F5D95),
                      side: const BorderSide(color: Color(0xFFB9B8C8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    icon: const Icon(Icons.compare_arrows_outlined, size: 18),
                    label: Text(
                      'Comparar $anioComparacion',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                SizedBox(
                  width: fieldWidth(185),
                  child: _dateButton(
                    'Desde',
                    desde,
                    () => _fecha(true),
                  ),
                ),
                SizedBox(
                  width: fieldWidth(185),
                  child: _dateButton(
                    'Hasta',
                    hasta,
                    () => _fecha(false),
                  ),
                ),
                SizedBox(
                  width: fieldWidth(145),
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _cargar,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF5161A0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    icon: const Icon(Icons.analytics_outlined, size: 19),
                    label: const Text(
                      'Actualizar',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _filtroDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: const Color(0xFFFAF9FE),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: borde),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: borde),
      ),
    );
  }

  Widget _dateButton(
    String label,
    DateTime value,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF4F5D95),
          side: const BorderSide(color: Color(0xFFB9B8C8)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        icon: const Icon(Icons.calendar_month_outlined, size: 19),
        label: Text(
          '$label ${date.format(value)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _contenido(bool mobile) {
    final venA = _mapList(data['vendedores']);
    final venB = _mapList(dataAnterior['vendedores']);
    final cliA = _mapList(data['clientes']);
    final cliB = _mapList(dataAnterior['clientes']);

    venA.sort((a, b) => _n(b['facturacion']).compareTo(_n(a['facturacion'])));
    venB.sort((a, b) => _n(b['facturacion']).compareTo(_n(a['facturacion'])));
    cliA.sort((a, b) => _n(b['facturacion']).compareTo(_n(a['facturacion'])));
    cliB.sort((a, b) => _n(b['facturacion']).compareTo(_n(a['facturacion'])));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _heroComparativo(),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 1000) {
              return Column(
                children: [
                  _graficoComparativoFacturacion(),
                  const SizedBox(height: 14),
                  _graficoComparativoPeso(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _graficoComparativoFacturacion()),
                const SizedBox(width: 12),
                Expanded(child: _graficoComparativoPeso()),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 1200) {
              return Column(
                children: [
                  _rankingComparativo(venA, venB),
                  const SizedBox(height: 14),
                  _distribucionClases(),
                  const SizedBox(height: 14),
                  _clientesComparativo(cliA, cliB),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _rankingComparativo(venA, venB)),
                const SizedBox(width: 12),
                Expanded(flex: 6, child: _distribucionClases()),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: _clientesComparativo(cliA, cliB)),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return Column(
                children: [
                  _carteraComparativa(cliA, cliB),
                  const SizedBox(height: 14),
                  _indicadoresComparativos(venA, cliA),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _carteraComparativa(cliA, cliB)),
                const SizedBox(width: 12),
                Expanded(child: _indicadoresComparativos(venA, cliA)),
              ],
            );
          },
        ),

        // ================================================================
        // VS DE ASESORES — SECCIÓN INDEPENDIENTE
        // No modifica ni reemplaza el dashboard ejecutivo anterior.
        // ================================================================
        const SizedBox(height: 18),
        _comparacionAsesoresIndependiente(),
      ],
    );
  }

  Widget _comparacionAsesoresIndependiente() {
    final kA = Map<String, dynamic>.from(
      dataComparacionA['kpis'] is Map
          ? dataComparacionA['kpis'] as Map
          : <String, dynamic>{},
    );
    final kB = Map<String, dynamic>.from(
      dataComparacionB['kpis'] is Map
          ? dataComparacionB['kpis'] as Map
          : <String, dynamic>{},
    );
    final kaA = Map<String, dynamic>.from(
      dataComparacionAAnterior['kpis'] is Map
          ? dataComparacionAAnterior['kpis'] as Map
          : <String, dynamic>{},
    );
    final kaB = Map<String, dynamic>.from(
      dataComparacionBAnterior['kpis'] is Map
          ? dataComparacionBAnterior['kpis'] as Map
          : <String, dynamic>{},
    );

    final factA = _n(kA['facturacion']);
    final factB = _n(kB['facturacion']);
    final factAA = _n(kaA['facturacion']);
    final factBB = _n(kaB['facturacion']);

    final mensualA = _mapList(dataComparacionA['mensual']);
    final mensualB = _mapList(dataComparacionB['mensual']);

    final promedioA =
        mensualA.isEmpty ? 0.0 : factA / mensualA.length.toDouble();
    final promedioB =
        mensualB.isEmpty ? 0.0 : factB / mensualB.length.toDouble();

    final crecimientoA =
        factAA == 0.0 ? 0.0 : ((factA - factAA) / factAA) * 100;
    final crecimientoB =
        factBB == 0.0 ? 0.0 : ((factB - factBB) / factBB) * 100;

    final facturasA = _n(kA['facturas']);
    final facturasB = _n(kB['facturas']);

    final ticketA = facturasA == 0.0 ? 0.0 : factA / facturasA;
    final ticketB = facturasB == 0.0 ? 0.0 : factB / facturasB;

    final pesoA = _n(kA['peso']);
    final pesoB = _n(kB['peso']);

    final kgMilA = factA == 0.0 ? 0.0 : pesoA / (factA / 1000.0);
    final kgMilB = factB == 0.0 ? 0.0 : pesoB / (factB / 1000.0);

    return _panel(
      title: 'Comparación dinámica de asesores',
      subtitle:
          'VS independiente del reporte ejecutivo · compara facturación, crecimiento, ticket y peso.',
      icon: Icons.compare_arrows_outlined,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 850;

                final selectorA = DropdownButtonFormField<String>(
                  initialValue: vendedores.contains(vendedorComparacionA)
                      ? vendedorComparacionA
                      : null,
                  isExpanded: true,
                  decoration: _filtroDecoration(
                    'Asesor A',
                    Icons.person_outline,
                  ),
                  items: vendedores
                      .map(
                        (v) => DropdownMenuItem<String>(
                          value: v,
                          child: Text(
                            v,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: loadingComparacion
                      ? null
                      : (value) async {
                          if (value == null) return;
                          setState(() => vendedorComparacionA = value);
                          await _cargarComparacionVendedores();
                        },
                );

                final selectorB = DropdownButtonFormField<String>(
                  initialValue: vendedores.contains(vendedorComparacionB)
                      ? vendedorComparacionB
                      : null,
                  isExpanded: true,
                  decoration: _filtroDecoration(
                    'Asesor B',
                    Icons.person_outline,
                  ),
                  items: vendedores
                      .map(
                        (v) => DropdownMenuItem<String>(
                          value: v,
                          child: Text(
                            v,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: loadingComparacion
                      ? null
                      : (value) async {
                          if (value == null) return;
                          setState(() => vendedorComparacionB = value);
                          await _cargarComparacionVendedores();
                        },
                );

                if (stacked) {
                  return Column(
                    children: [
                      selectorA,
                      const SizedBox(height: 10),
                      const Text(
                        'VS',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: azul,
                        ),
                      ),
                      const SizedBox(height: 10),
                      selectorB,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: selectorA),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'VS',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: azul,
                        ),
                      ),
                    ),
                    Expanded(child: selectorB),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            if (loadingComparacion)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: LinearProgressIndicator(minHeight: 3),
              )
            else if (vendedorComparacionA == null ||
                vendedorComparacionB == null)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No hay asesores disponibles para realizar la comparación.',
                ),
              )
            else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth < 900 ? 2 : 5;
                  const gap = 10.0;
                  final width = (constraints.maxWidth -
                          gap * (columns - 1)) /
                      columns;

                  final cards = [
                    _comparacionMiniCard(
                      'Promedio mensual',
                      promedioA,
                      promedioB,
                      (v) => 'US\$ ${money.format(v)}',
                      Icons.show_chart,
                      azulClaro,
                    ),
                    _comparacionMiniCard(
                      'Facturación acumulada',
                      factA,
                      factB,
                      (v) => 'US\$ ${money.format(v)}',
                      Icons.bar_chart_outlined,
                      verde,
                    ),
                    _comparacionMiniCard(
                      'Crecimiento',
                      crecimientoA,
                      crecimientoB,
                      (v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}%',
                      Icons.percent_outlined,
                      morado,
                    ),
                    _comparacionMiniCard(
                      'Ticket promedio',
                      ticketA,
                      ticketB,
                      (v) => 'US\$ ${money.format(v)}',
                      Icons.shopping_cart_outlined,
                      naranja,
                    ),
                    _comparacionMiniCard(
                      'Kg / US\$ 1,000',
                      kgMilA,
                      kgMilB,
                      (v) => '${money.format(v)} kg',
                      Icons.scale_outlined,
                      rojo,
                    ),
                  ];

                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: cards
                        .map(
                          (card) => SizedBox(
                            width: width,
                            child: card,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 12),
              _graficoMensualAsesoresComparados(
                mensualA,
                mensualB,
              ),
              const SizedBox(height: 14),
              _desgloseCarteraVS(),
              const SizedBox(height: 14),
              _desgloseSectoresVS(),
            ],
          ],
        ),
      ),
    );
  }


  Widget _desgloseCarteraVS() {
    final actualA = _mapList(dataComparacionA['clientes']);
    final anteriorA = _mapList(dataComparacionAAnterior['clientes']);
    final actualB = _mapList(dataComparacionB['clientes']);
    final anteriorB = _mapList(dataComparacionBAnterior['clientes']);

    final categorias = [
      (
        titulo: 'Clientes nuevos',
        color: verde,
        icon: Icons.group_add_outlined,
        categoria: _CategoriaCartera.nuevos,
      ),
      (
        titulo: 'Clientes que crecieron',
        color: azulClaro,
        icon: Icons.trending_up_outlined,
        categoria: _CategoriaCartera.crecieron,
      ),
      (
        titulo: 'Clientes que disminuyeron',
        color: naranja,
        icon: Icons.trending_down_outlined,
        categoria: _CategoriaCartera.disminuyeron,
      ),
      (
        titulo: 'Clientes sin compra',
        color: rojo,
        icon: Icons.person_off_outlined,
        categoria: _CategoriaCartera.sinCompra,
      ),
    ];

    int contar(
      List<Map<String, dynamic>> actual,
      List<Map<String, dynamic>> anterior,
      _CategoriaCartera categoria,
    ) {
      final mapA = {
        for (final r in actual) _s(r['cliente']): r,
      };
      final mapB = {
        for (final r in anterior) _s(r['cliente']): r,
      };
      final nombres = <String>{...mapA.keys, ...mapB.keys}
          .where((x) => x.isNotEmpty);

      var total = 0;
      for (final nombre in nombres) {
        final factA = _n(mapA[nombre]?['facturacion']);
        final factB = _n(mapB[nombre]?['facturacion']);

        switch (categoria) {
          case _CategoriaCartera.nuevos:
            if (factB == 0 && factA > 0) total++;
            break;
          case _CategoriaCartera.crecieron:
            if (factB > 0 && factA > factB) total++;
            break;
          case _CategoriaCartera.disminuyeron:
            if (factA > 0 && factA < factB) total++;
            break;
          case _CategoriaCartera.sinCompra:
            if (factA == 0 && factB > 0) total++;
            break;
        }
      }
      return total;
    }

    return _panel(
      title: 'Comportamiento de cartera — VS',
      subtitle:
          'Clientes comparados entre $anioActual y $anioComparacion por cada asesor',
      icon: Icons.groups_outlined,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 850 ? 2 : 4;
            const gap = 10.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final item in categorias)
                  SizedBox(
                    width: width,
                    child: _carteraVSCard(
                      titulo: item.titulo,
                      color: item.color,
                      icon: item.icon,
                      valorA: contar(actualA, anteriorA, item.categoria),
                      valorB: contar(actualB, anteriorB, item.categoria),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _carteraVSCard({
    required String titulo,
    required Color color,
    required IconData icon,
    required int valorA,
    required int valorB,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _carteraVSDato(
                  vendedorComparacionA ?? 'Asesor A',
                  valorA,
                  azulClaro,
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: borde,
              ),
              Expanded(
                child: _carteraVSDato(
                  vendedorComparacionB ?? 'Asesor B',
                  valorB,
                  naranja,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _carteraVSDato(String nombre, int valor, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          nombre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 8.5,
            color: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          integer.format(valor),
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _desgloseSectoresVS() {
    final mapA = <String, Map<String, dynamic>>{
      for (final row in sectoresComparacionA)
        _s(row['sector']).isEmpty ? 'SIN SECTOR' : _s(row['sector']): row,
    };
    final mapB = <String, Map<String, dynamic>>{
      for (final row in sectoresComparacionB)
        _s(row['sector']).isEmpty ? 'SIN SECTOR' : _s(row['sector']): row,
    };

    final sectores = <String>{...mapA.keys, ...mapB.keys}.toList()
      ..sort((a, b) {
        final totalB = _n(mapA[b]?['facturacion']) +
            _n(mapB[b]?['facturacion']);
        final totalA = _n(mapA[a]?['facturacion']) +
            _n(mapB[a]?['facturacion']);
        final cmp = totalA.compareTo(totalB);
        return cmp != 0 ? -cmp : a.compareTo(b);
      });

    if (sectores.isEmpty) {
      return _panel(
        title: 'Sectores — VS',
        subtitle: 'Facturación por sector de cada asesor',
        icon: Icons.business_center_outlined,
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'No se encontraron sectores para el periodo seleccionado.',
            style: TextStyle(color: Colors.black54, fontSize: 11),
          ),
        ),
      );
    }

    final totalA = sectores.fold<double>(
      0,
      (sum, sector) => sum + _n(mapA[sector]?['facturacion']),
    );
    final totalB = sectores.fold<double>(
      0,
      (sum, sector) => sum + _n(mapB[sector]?['facturacion']),
    );

    return _panel(
      title: 'Sectores — VS',
      subtitle:
          'Facturación, clientes y peso cobre por sector · periodo $anioActual',
      icon: Icons.business_center_outlined,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Sector',
                      style: TextStyle(
                        color: azul,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 125,
                    child: Text(
                      vendedorComparacionA ?? 'Asesor A',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: azulClaro,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 125,
                    child: Text(
                      vendedorComparacionB ?? 'Asesor B',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: naranja,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            for (final sector in sectores)
              _filaSectorVS(
                sector: sector,
                a: mapA[sector],
                b: mapB[sector],
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'TOTAL',
                      style: TextStyle(
                        color: azul,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 125,
                    child: Text(
                      'US\$ ${money.format(totalA)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: azulClaro,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 125,
                    child: Text(
                      'US\$ ${money.format(totalB)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: naranja,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaSectorVS({
    required String sector,
    required Map<String, dynamic>? a,
    required Map<String, dynamic>? b,
  }) {
    final factA = _n(a?['facturacion']);
    final factB = _n(b?['facturacion']);
    final clientesA = _n(a?['clientes']).round();
    final clientesB = _n(b?['clientes']).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: borde),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              sector,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            width: 125,
            child: _sectorDatoVS(
              facturacion: factA,
              clientes: clientesA,
              color: azulClaro,
            ),
          ),
          SizedBox(
            width: 125,
            child: _sectorDatoVS(
              facturacion: factB,
              clientes: clientesB,
              color: naranja,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectorDatoVS({
    required double facturacion,
    required int clientes,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'US\$ ${_formatoCompacto(facturacion)}',
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          '$clientes clientes',
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 8.5,
          ),
        ),
      ],
    );
  }

  Widget _comparacionMiniCard(
    String title,
    double valueA,
    double valueB,
    String Function(double) formatter,
    IconData icon,
    Color color,
  ) {
    final nombreA = vendedorComparacionA ?? 'Asesor A';
    final nombreB = vendedorComparacionB ?? 'Asesor B';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$nombreA: ${formatter(valueA)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: azul,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$nombreB: ${formatter(valueB)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: naranja,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _mensualAsesoresComparados(
    List<Map<String, dynamic>> actualA,
    List<Map<String, dynamic>> actualB,
  ) {
    final ma = <int, Map<String, dynamic>>{};
    final mb = <int, Map<String, dynamic>>{};

    for (final row in actualA) {
      final match =
          RegExp(r'\d{4}[-/](\d{1,2})').firstMatch(_s(row['periodo']));
      if (match != null) {
        ma[int.parse(match.group(1)!)] = row;
      }
    }

    for (final row in actualB) {
      final match =
          RegExp(r'\d{4}[-/](\d{1,2})').firstMatch(_s(row['periodo']));
      if (match != null) {
        mb[int.parse(match.group(1)!)] = row;
      }
    }

    final result = <Map<String, dynamic>>[];

    for (var month = desde.month; month <= hasta.month; month++) {
      result.add({
        'label': _nombreMes(month),
        'a': _n(ma[month]?['facturacion']),
        'b': _n(mb[month]?['facturacion']),
      });
    }

    return result;
  }

  Widget _graficoMensualAsesoresComparados(
    List<Map<String, dynamic>> mensualA,
    List<Map<String, dynamic>> mensualB,
  ) {
    final rows = _mensualAsesoresComparados(mensualA, mensualB);

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    double maxValue = 0.0;
    for (final row in rows) {
      maxValue = [
        maxValue,
        _n(row['a']),
        _n(row['b']),
      ].reduce((x, y) => x > y ? x : y);
    }
    if (maxValue <= 0.0) maxValue = 1.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.show_chart,
                color: azul,
                size: 19,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Facturación mensual de los asesores',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              _LegendDot(
                color: azulClaro,
                label: vendedorComparacionA ?? 'Asesor A',
              ),
              const SizedBox(width: 12),
              _LegendDot(
                color: naranja,
                label: vendedorComparacionB ?? 'Asesor B',
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 250,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final groupWidth =
                    constraints.maxWidth / rows.length;
                final barWidth = (groupWidth * .27).clamp(9.0, 24.0);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: rows.map((row) {
                    final a = _n(row['a']);
                    final b = _n(row['b']);

                    final hA = a <= 0.0
                        ? 2.0
                        : 145.0 * (a / maxValue).clamp(0.05, 1.0);
                    final hB = b <= 0.0
                        ? 2.0
                        : 145.0 * (b / maxValue).clamp(0.05, 1.0);

                    return SizedBox(
                      width: groupWidth,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            height: 185,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _barraAsesorVS(
                                  value: a,
                                  height: hA.toDouble(),
                                  width: barWidth.toDouble(),
                                  color: azulClaro,
                                ),
                                const SizedBox(width: 3),
                                _barraAsesorVS(
                                  value: b,
                                  height: hB.toDouble(),
                                  width: barWidth.toDouble(),
                                  color: naranja,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            width: groupWidth - 4,
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _s(row['label']),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _barraAsesorVS({
    required double value,
    required double height,
    required double width,
    required Color color,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: 27,
          width: 54,
          child: Text(
            value <= 0.0
                ? 'US\$ 0'
                : 'US\$ ${_formatoCompacto(value)}',
            maxLines: 1,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(3),
            ),
          ),
        ),
      ],
    );
  }

  String _formatoCompacto(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)} M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)} K';
    }
    return money.format(value);
  }


  Widget _heroComparativo() {
    final a = Map<String, dynamic>.from(
      data['kpis'] is Map ? data['kpis'] as Map : <String, dynamic>{},
    );
    final b = Map<String, dynamic>.from(
      dataAnterior['kpis'] is Map
          ? dataAnterior['kpis'] as Map
          : <String, dynamic>{},
    );

    final cards = [
      _comparativeKpi(
        'Facturación',
        _n(a['facturacion']),
        _n(b['facturacion']),
        (v) => 'US\$ ${money.format(v)}',
        Icons.bar_chart_outlined,
      ),
      _comparativeKpi(
        'Peso cobre',
        _n(a['peso']),
        _n(b['peso']),
        (v) => '${money.format(v)} kg',
        Icons.scale_outlined,
      ),
      _comparativeKpi(
        'Facturas',
        _n(a['facturas']),
        _n(b['facturas']),
        (v) => integer.format(v.round()),
        Icons.description_outlined,
      ),
      _comparativeKpi(
        'Clientes',
        _n(a['clientes']),
        _n(b['clientes']),
        (v) => integer.format(v.round()),
        Icons.groups_outlined,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B4A78), Color(0xFF1673A8)],
        ),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RESUMEN EJECUTIVO COMERCIAL',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Comparativo $anioActual vs $anioComparacion',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_filtroTexto()} · mismo periodo del año anterior',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 700 ? 1 : 4;
              const gap = 10.0;
              final width = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - gap * 3) / 4;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: cards
                    .map((c) => SizedBox(width: width, child: c))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _comparativeKpi(
    String title,
    double current,
    double previous,
    String Function(double) formatter,
    IconData icon,
  ) {
    final pct = previous == 0
        ? 0.0
        : ((current - previous) / previous) * 100;
    final positive = pct >= 0;
    final color = positive ? verde : rojo;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _yearValue('$anioActual', formatter(current)),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.white24,
                    ),
                    Expanded(
                      child: _yearValue(
                        '$anioComparacion',
                        formatter(previous),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${positive ? '▲' : '▼'} ${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%  vs $anioComparacion',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _yearValue(String year, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            year,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _compararMensual() {
    final a = _mapList(data['mensual']);
    final b = _mapList(dataAnterior['mensual']);

    final ma = <int, Map<String, dynamic>>{};
    final mb = <int, Map<String, dynamic>>{};

    for (final row in a) {
      final raw = _s(row['periodo']);
      final match = RegExp(r'\d{4}[-/](\d{1,2})').firstMatch(raw);
      if (match != null) {
        ma[int.parse(match.group(1)!)] = row;
      }
    }

    for (final row in b) {
      final raw = _s(row['periodo']);
      final match = RegExp(r'\d{4}[-/](\d{1,2})').firstMatch(raw);
      if (match != null) {
        mb[int.parse(match.group(1)!)] = row;
      }
    }

    // Siempre construimos el mismo rango mensual del filtro.
    // Esto evita que septiembre desaparezca cuando una de las dos
    // series no trae una fila explícita para ese mes.
    final inicioMes = desde.month;
    final finMes = hasta.month;

    final result = <Map<String, dynamic>>[];

    if (finMes >= inicioMes) {
      for (int month = inicioMes; month <= finMes; month++) {
        result.add({
          'month': month,
          'label': _nombreMes(month),
          'a': ma[month] ?? <String, dynamic>{},
          'b': mb[month] ?? <String, dynamic>{},
        });
      }
    }

    return result;
  }

  String _nombreMes(int month) {
    const nombres = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return month >= 1 && month <= 12 ? nombres[month - 1] : '';
  }

  String _compactMoney(double value) {
    if (value >= 1000000) {
      return 'US\$ ${(value / 1000000).toStringAsFixed(2)} M';
    }
    if (value >= 1000) {
      return 'US\$ ${(value / 1000).toStringAsFixed(0)} K';
    }
    return 'US\$ ${money.format(value)}';
  }

  String _compactKg(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(2)} K';
    }
    return money.format(value);
  }

  Widget _graficoComparativoFacturacion() {
    final rows = _compararMensual();

    double maxValue = 0;
    for (final row in rows) {
      final va = _n(row['a']['facturacion']);
      final vb = _n(row['b']['facturacion']);
      if (va > maxValue) maxValue = va;
      if (vb > maxValue) maxValue = vb;
    }

    return _panel(
      title: 'Evolución mensual de facturación (US\$)',
      subtitle: 'Comparativo $anioActual vs $anioComparacion (mismo periodo)',
      icon: Icons.bar_chart_outlined,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _LegendDot(
                  color: azulClaro,
                  label: '$anioActual',
                ),
                const SizedBox(width: 18),
                _LegendDot(
                  color: naranja,
                  label: '$anioComparacion',
                ),
              ],
            ),
          ),
          SizedBox(
            height: 315,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (rows.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay información mensual para el periodo seleccionado.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  );
                }

                final monthWidth = constraints.maxWidth / rows.length;
                final barWidth = (monthWidth * .25).clamp(13.0, 28.0);
                final gap = (monthWidth * .035).clamp(2.0, 6.0);

                return Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: rows.map((row) {
                      final va = _n(row['a']['facturacion']);
                      final vb = _n(row['b']['facturacion']);

                      return Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _mostrarComparativoMes(row),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  height: 235,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _barComparativoCompact(
                                        va,
                                        maxValue,
                                        azulClaro,
                                        _compactMoney(va),
                                        barWidth,
                                        fontSize: 11.5,
                                      ),
                                      SizedBox(width: gap),
                                      _barComparativoCompact(
                                        vb,
                                        maxValue,
                                        naranja,
                                        _compactMoney(vb),
                                        barWidth,
                                        fontSize: 11.5,
                                        labelOffsetY: 9,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  constraints: BoxConstraints(
                                    minWidth: monthWidth - 8,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    _s(row['label']),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _barComparativoCompact(
    double value,
    double max,
    Color color,
    String label,
    double width, {
    double fontSize = 10,
    double labelOffsetY = 0,
  }) {
    final height = max <= 0 ? 8.0 : (value / max) * 195;

    return SizedBox(
      width: width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 30,
            child: OverflowBox(
              minWidth: 78,
              maxWidth: 78,
              alignment: Alignment.center,
              child: Transform.translate(
                offset: Offset(0, labelOffsetY),
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: width,
            height: height.clamp(8.0, 195.0),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _graficoComparativoPeso() {
    final rows = _compararMensual();

    double maxValue = 0;
    for (final row in rows) {
      final va = _n(row['a']['peso']);
      final vb = _n(row['b']['peso']);
      if (va > maxValue) maxValue = va;
      if (vb > maxValue) maxValue = vb;
    }

    return _panel(
      title: 'Evolución mensual de peso cobre (kg)',
      subtitle: 'Comparativo $anioActual vs $anioComparacion',
      icon: Icons.scale_outlined,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _LegendDot(
                  color: azulClaro,
                  label: '$anioActual',
                ),
                const SizedBox(width: 18),
                _LegendDot(
                  color: naranja,
                  label: '$anioComparacion',
                ),
              ],
            ),
          ),
          SizedBox(
            height: 315,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (rows.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay información mensual para el periodo seleccionado.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  );
                }

                final monthWidth = constraints.maxWidth / rows.length;
                final barWidth = (monthWidth * .25).clamp(13.0, 28.0);
                final gap = (monthWidth * .035).clamp(2.0, 6.0);

                return Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: rows.map((row) {
                      final va = _n(row['a']['peso']);
                      final vb = _n(row['b']['peso']);

                      return Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _mostrarComparativoMes(row),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  height: 235,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _barComparativoCompact(
                                        va,
                                        maxValue,
                                        azulClaro,
                                        _compactKg(va),
                                        barWidth,
                                      ),
                                      SizedBox(width: gap),
                                      _barComparativoCompact(
                                        vb,
                                        maxValue,
                                        naranja,
                                        _compactKg(vb),
                                        barWidth,
                                        labelOffsetY: 9,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  constraints: BoxConstraints(
                                    minWidth: monthWidth - 8,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    _s(row['label']),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _rankingComparativo(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    final mapA = {for (final r in a) _s(r['vendedor']): r};
    final mapB = {for (final r in b) _s(r['vendedor']): r};

    final names = <String>{...mapA.keys, ...mapB.keys}
        .where((x) => x.isNotEmpty)
        .toList();

    names.sort(
      (x, y) => _n(mapA[y]?['facturacion'])
          .compareTo(_n(mapA[x]?['facturacion'])),
    );

    return _panel(
      title: 'Ranking de asesores - Facturación comparativa',
      subtitle: 'Facturación acumulada y variación',
      icon: Icons.groups_outlined,
      child: Column(
        children: [
          _cabeceraComparativa('Asesor'),
          const Divider(height: 1),
          for (var i = 0; i < names.take(10).length; i++)
            _filaComparativa(
              i + 1,
              names[i],
              _n(mapA[names[i]]?['facturacion']),
              _n(mapB[names[i]]?['facturacion']),
              azulClaro,
            ),
        ],
      ),
    );
  }

  Widget _cabeceraComparativa(String titulo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          const SizedBox(width: 32),
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(
                color: azul,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(
            width: 105,
            child: Text(
              '$anioActual',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: azul,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(
            width: 105,
            child: Text(
              '$anioComparacion',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(
            width: 70,
            child: Text(
              'Variación',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaComparativa(
    int index,
    String nombre,
    double actualValue,
    double previousValue,
    Color color,
  ) {
    final pct = previousValue == 0
        ? 0.0
        : ((actualValue - previousValue) / previousValue) * 100;

    final positive = pct >= 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xFFEAF3FB),
            child: Text(
              '$index',
              style: const TextStyle(
                color: azulClaro,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            width: 105,
            child: Text(
              'US\$ ${money.format(actualValue)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(
            width: 105,
            child: Text(
              'US\$ ${money.format(previousValue)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 10,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              '${positive ? '▲' : '▼'} ${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: positive ? verde : rojo,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientesComparativo(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    final mapA = {for (final r in a) _s(r['cliente']): r};
    final mapB = {for (final r in b) _s(r['cliente']): r};

    final names = <String>{...mapA.keys, ...mapB.keys}
        .where((x) => x.isNotEmpty)
        .toList();

    names.sort(
      (x, y) => _n(mapA[y]?['facturacion'])
          .compareTo(_n(mapA[x]?['facturacion'])),
    );

    return _panel(
      title: 'Top 10 clientes - Facturación comparativa',
      subtitle: 'Clientes con mayor facturación acumulada',
      icon: Icons.business_outlined,
      child: Column(
        children: [
          _cabeceraComparativa('Cliente'),
          const Divider(height: 1),
          for (var i = 0; i < names.take(10).length; i++)
            _filaComparativa(
              i + 1,
              names[i],
              _n(mapA[names[i]]?['facturacion']),
              _n(mapB[names[i]]?['facturacion']),
              morado,
            ),
        ],
      ),
    );
  }

  Widget _distribucionClases() {
    final a = _mapList(data['asesores_clase']);
    final b = _mapList(dataAnterior['asesores_clase']);

    if (a.isEmpty && b.isEmpty) {
      return _panel(
        title: 'Facturación por asesor y clase - Comparativo',
        subtitle: 'Participación de cada clase dentro de la facturación del asesor',
        icon: Icons.groups_outlined,
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'La RPC no devolvió el detalle asesor-clase para el periodo seleccionado.',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 11,
            ),
          ),
        ),
      );
    }

    final mapA = <String, Map<String, double>>{};
    final mapB = <String, Map<String, double>>{};
    final totalA = <String, double>{};
    final totalB = <String, double>{};

    for (final row in a) {
      final asesor = _s(row['vendedor']).isEmpty ? 'SIN ASESOR' : _s(row['vendedor']);
      final clase = _s(row['clase']).isEmpty ? 'SIN CLASE' : _s(row['clase']).toUpperCase();
      final monto = _n(row['facturacion']);
      mapA.putIfAbsent(asesor, () => <String, double>{});
      mapA[asesor]![clase] = (mapA[asesor]![clase] ?? 0) + monto;
      totalA[asesor] = (totalA[asesor] ?? 0) + monto;
    }

    for (final row in b) {
      final asesor = _s(row['vendedor']).isEmpty ? 'SIN ASESOR' : _s(row['vendedor']);
      final clase = _s(row['clase']).isEmpty ? 'SIN CLASE' : _s(row['clase']).toUpperCase();
      final monto = _n(row['facturacion']);
      mapB.putIfAbsent(asesor, () => <String, double>{});
      mapB[asesor]![clase] = (mapB[asesor]![clase] ?? 0) + monto;
      totalB[asesor] = (totalB[asesor] ?? 0) + monto;
    }

    final asesores = <String>{...mapA.keys, ...mapB.keys}.toList();
    asesores.sort((x, y) {
      final c = (totalA[y] ?? 0).compareTo(totalA[x] ?? 0);
      return c != 0 ? c : x.compareTo(y);
    });

    const prioridad = <String>[
      'CL5',
      'CL2',
      'CL1',
      'SIN CLASE',
      'CL6',
    ];

    final clases = <String>{
      ...mapA.values.expand((m) => m.keys),
      ...mapB.values.expand((m) => m.keys),
    };
    final clasesOrdenadas = <String>[];
    for (final clase in prioridad) {
      if (clases.remove(clase)) clasesOrdenadas.add(clase);
    }
    final restantes = clases.toList()..sort();
    clasesOrdenadas.addAll(restantes);

    double porcentaje(
      Map<String, Map<String, double>> source,
      Map<String, double> totals,
      String asesor,
      String clase,
    ) {
      final total = totals[asesor] ?? 0;
      if (total <= 0) return 0;
      return ((source[asesor]?[clase] ?? 0) / total) * 100;
    }

    Widget celdaClase(String asesor, String clase) {
      final pa = porcentaje(mapA, totalA, asesor, clase);
      final pb = porcentaje(mapB, totalB, asesor, clase);
      final diff = pa - pb;
      final colorDiff = diff >= 0 ? verde : rojo;

      return Container(
        width: 105,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: borde.withValues(alpha: .7)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${pa.toStringAsFixed(1)}%',
              style: const TextStyle(
                color: azulClaro,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '${pb.toStringAsFixed(1)}%',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)} pp',
              style: TextStyle(
                color: colorDiff,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    Widget encabezadoClase(String clase) {
      return Container(
        width: 105,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
        decoration: const BoxDecoration(
          color: Color(0xFFF5F8FC),
          border: Border(
            left: BorderSide(color: borde),
          ),
        ),
        child: Text(
          clase,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: azul,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    Widget filaAsesor(String asesor) {
      final actual = totalA[asesor] ?? 0;
      final anterior = totalB[asesor] ?? 0;

      return Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: borde),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 155,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Text(
                  asesor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            for (final clase in clasesOrdenadas) celdaClase(asesor, clase),
            Container(
              width: 120,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: borde.withValues(alpha: .7))),
              ),
              child: Column(
                children: [
                  Text(
                    _compactMoney(actual),
                    style: const TextStyle(
                      color: azulClaro,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _compactMoney(anterior),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _panel(
      title: 'Facturación por asesor y clase - Comparativo',
      subtitle: '2026 / 2025 / variación en puntos porcentuales de la mezcla de cada asesor',
      icon: Icons.groups_outlined,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 9, height: 9, decoration: const BoxDecoration(color: azulClaro, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                const Text('2026', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: azulClaro)),
                const SizedBox(width: 12),
                Container(width: 9, height: 9, decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                const Text('2025', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.black54)),
                const SizedBox(width: 12),
                const Text('pp = variación de participación', style: TextStyle(fontSize: 9, color: Colors.black45)),
              ],
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 145,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          child: Text(
                            'Asesor',
                            style: TextStyle(
                              color: azul,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      for (final clase in clasesOrdenadas) encabezadoClase(clase),
                      const SizedBox(
                        width: 110,
                        child: Center(
                          child: Text(
                            'Total facturación',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: azul,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  for (final asesor in asesores.take(12)) filaAsesor(asesor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _donut(
    String year,
    double total,
    Map<String, double> values,
  ) {
    return Column(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: CustomPaint(
            painter: _DonutPainter(values: values),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    year,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    _compactMoney(total),
                    style: const TextStyle(
                      color: azul,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _claseFila(
    String name,
    double a,
    double totalA,
    double b,
    double totalB,
  ) {
    final pa = totalA == 0 ? 0.0 : a / totalA * 100;
    final pb = totalB == 0 ? 0.0 : b / totalB * 100;
    final diff = pa - pb;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: _colorClase(name),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 62,
            child: Text(
              '${pa.toStringAsFixed(2)}%',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: azulClaro,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            width: 62,
            child: Text(
              '${pb.toStringAsFixed(2)}%',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 10,
              ),
            ),
          ),
          SizedBox(
            width: 65,
            child: Text(
              '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(2)} pp',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: diff >= 0 ? verde : rojo,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorClase(String name) {
    switch (name.toUpperCase()) {
      case 'CL5':
        return verde;
      case 'CL2':
        return naranja;
      case 'CL1':
        return azulClaro;
      case 'CL6':
        return morado;
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _carteraComparativa(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    final mapA = {for (final r in a) _s(r['cliente']): r};
    final mapB = {for (final r in b) _s(r['cliente']): r};

    final names = <String>{...mapA.keys, ...mapB.keys}
        .where((x) => x.isNotEmpty)
        .toList();

    int nuevos = 0;
    int crecieron = 0;
    int disminuyeron = 0;
    int sinCompra = 0;

    for (final name in names) {
      final va = _n(mapA[name]?['facturacion']);
      final vb = _n(mapB[name]?['facturacion']);

      if (vb == 0 && va > 0) {
        nuevos++;
      } else if (vb > 0 && va > vb) {
        crecieron++;
      } else if (va > 0 && va < vb) {
        disminuyeron++;
      } else if (va == 0 && vb > 0) {
        sinCompra++;
      }
    }

    return _panel(
      title: 'Comportamiento de cartera',
      subtitle: 'Comparativo $anioActual vs $anioComparacion',
      icon: Icons.groups_outlined,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 700 ? 2 : 4;
            const gap = 10.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) /
                    columns;

            final cards = [
              _carteraCard(
                'Clientes nuevos',
                nuevos,
                verde,
                Icons.group_add_outlined,
                onTap: () => _mostrarDetalleCartera(
                  titulo: 'Clientes nuevos',
                  categoria: _CategoriaCartera.nuevos,
                  actual: a,
                  anterior: b,
                  color: verde,
                ),
              ),
              _carteraCard(
                'Clientes que crecieron',
                crecieron,
                azulClaro,
                Icons.trending_up_outlined,
                onTap: () => _mostrarDetalleCartera(
                  titulo: 'Clientes que crecieron',
                  categoria: _CategoriaCartera.crecieron,
                  actual: a,
                  anterior: b,
                  color: azulClaro,
                ),
              ),
              _carteraCard(
                'Clientes que disminuyeron',
                disminuyeron,
                naranja,
                Icons.trending_down_outlined,
                onTap: () => _mostrarDetalleCartera(
                  titulo: 'Clientes que disminuyeron',
                  categoria: _CategoriaCartera.disminuyeron,
                  actual: a,
                  anterior: b,
                  color: naranja,
                ),
              ),
              _carteraCard(
                'Clientes sin compra',
                sinCompra,
                rojo,
                Icons.person_off_outlined,
                onTap: () => _mostrarDetalleCartera(
                  titulo: 'Clientes sin compra',
                  categoria: _CategoriaCartera.sinCompra,
                  actual: a,
                  anterior: b,
                  color: rojo,
                ),
              ),
            ];

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: cards
                  .map(
                    (c) => SizedBox(
                      width: width,
                      child: c,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }

  Widget _carteraCard(
    String title,
    int value,
    Color color,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: color.withValues(alpha: .15),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  integer.format(value),
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.open_in_new_rounded,
              color: color.withValues(alpha: .65),
              size: 16,
            ),
        ],
      ),
    );

    if (onTap == null) return card;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: card,
      ),
    );
  }

  Future<Map<String, String>> _cargarVendedorPorCliente(
    Iterable<String> clientes,
  ) async {
    // IMPORTANTE:
    // No consultamos crm_facturas directamente desde Flutter para obtener
    // el vendedor porque esa tabla puede estar protegida por RLS.
    // El RPC crm_obtener_vendedor_clientes es SECURITY DEFINER y devuelve
    // el asesor real aun cuando el usuario solo tenga acceso al reporte.
    final objetivo = clientes
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    if (objetivo.isEmpty) return <String, String>{};

    final salida = <String, String>{};

    Future<void> leerPeriodo(DateTime ini, DateTime fin) async {
      final result = await db.rpc(
        'crm_obtener_vendedor_clientes',
        params: {
          'p_clientes': objetivo.toList(),
          'p_desde': DateFormat('yyyy-MM-dd').format(ini),
          'p_hasta': DateFormat('yyyy-MM-dd').format(fin),
          'p_vendedores_permitidos': vendedoresPermitidos,
          'p_vendedor': vendedor,
          'p_canal': canal,
        },
      );

      if (result is! List) return;

      for (final raw in result) {
        if (raw is! Map) continue;

        final cliente = _s(raw['cliente']).trim().toUpperCase();
        final asesor = _s(raw['vendedor']).trim();

        if (cliente.isEmpty || asesor.isEmpty) continue;
        if (!objetivo.map((e) => e.toUpperCase()).contains(cliente)) continue;

        // El periodo actual tiene prioridad. Para clientes sin compra en
        // el año actual, el segundo periodo (comparativo) completa el dato.
        salida[cliente] = asesor;
      }
    }

    try {
      // Primero el año actual.
      await leerPeriodo(
        desde,
        hasta,
      );

      // Después el año comparativo. Solo completa los que todavía no tienen
      // vendedor del año actual.
      final actual = Map<String, String>.from(salida);
      final anterior = <String, String>{};

      final result = await db.rpc(
        'crm_obtener_vendedor_clientes',
        params: {
          'p_clientes': objetivo.toList(),
          'p_desde': DateFormat('yyyy-MM-dd').format(
            _fechaAnio(desde, anioComparacion),
          ),
          'p_hasta': DateFormat('yyyy-MM-dd').format(
            _fechaAnio(hasta, anioComparacion),
          ),
          'p_vendedores_permitidos': vendedoresPermitidos,
          'p_vendedor': vendedor,
          'p_canal': canal,
        },
      );

      if (result is List) {
        for (final raw in result) {
          if (raw is! Map) continue;
          final cliente = _s(raw['cliente']).trim().toUpperCase();
          final asesor = _s(raw['vendedor']).trim();
          if (cliente.isEmpty || asesor.isEmpty) continue;
          anterior[cliente] = asesor;
        }
      }

      for (final cliente in objetivo) {
        final key = cliente.toUpperCase();
        if (!actual.containsKey(key) && anterior.containsKey(key)) {
          salida[key] = anterior[key]!;
        }
      }
    } catch (e) {
      // No dejamos que un fallo del mapeo del vendedor rompa la vista.
      debugPrint('crm_obtener_vendedor_clientes: $e');
    }

    return salida;
  }

  Future<void> _exportarDetalleCarteraExcel({
    required String titulo,
    required List<Map<String, dynamic>> rows,
  }) async {
    if (rows.isEmpty) return;

    try {
      final vendedorPorCliente = await _cargarVendedorPorCliente(
        rows.map((r) => _s(r['cliente'])),
      );

      final excel = Excel.createExcel();
      final sheetName = titulo.length > 25
          ? titulo.substring(0, 25)
          : titulo;
      final sheet = excel[sheetName];

      sheet.appendRow([
        TextCellValue('Cliente'),
        TextCellValue('Vendedor'),
        TextCellValue('$anioActual Fact.'),
        TextCellValue('$anioComparacion Fact.'),
        TextCellValue('Var. monto'),
        TextCellValue('$anioActual Peso'),
        TextCellValue('$anioComparacion Peso'),
        TextCellValue('Var. peso'),
      ]);

      for (final row in rows) {
        final cliente = _s(row['cliente']);
        final vm = row['varMonto'] as double?;
        final vp = row['varPeso'] as double?;
        sheet.appendRow([
          TextCellValue(cliente),
          TextCellValue(vendedorPorCliente[cliente.trim().toUpperCase()] ??
              (vendedor == 'TODOS' ? 'No identificado' : vendedor)),
          DoubleCellValue(_n(row['factA'])),
          DoubleCellValue(_n(row['factB'])),
          vm == null ? TextCellValue('—') : DoubleCellValue(vm),
          DoubleCellValue(_n(row['pesoA'])),
          DoubleCellValue(_n(row['pesoB'])),
          vp == null ? TextCellValue('—') : DoubleCellValue(vp),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('No se pudo generar el archivo Excel.');

      final safeTitle = titulo
          .replaceAll(RegExp(r'[^a-zA-Z0-9áéíóúÁÉÍÓÚñÑ _-]'), '')
          .replaceAll(' ', '_');
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar detalle de cartera en Excel',
        fileName: 'ELCOPE_${safeTitle}_${anioActual}_vs_$anioComparacion.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (path == null || path.isEmpty) return;

      await File(path).writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel generado correctamente: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo exportar a Excel: $e')),
      );
    }
  }

  Future<void> _mostrarDetalleCartera({
    required String titulo,
    required _CategoriaCartera categoria,
    required List<Map<String, dynamic>> actual,
    required List<Map<String, dynamic>> anterior,
    required Color color,
  }) async {
    final mapA = <String, Map<String, dynamic>>{
      for (final r in actual)
        if (_s(r['cliente']).isNotEmpty) _s(r['cliente']): r,
    };
    final mapB = <String, Map<String, dynamic>>{
      for (final r in anterior)
        if (_s(r['cliente']).isNotEmpty) _s(r['cliente']): r,
    };

    final nombres = <String>{...mapA.keys, ...mapB.keys};

    final rows = <Map<String, dynamic>>[];

    for (final nombre in nombres) {
      final a = mapA[nombre];
      final b = mapB[nombre];

      final factA = _n(a?['facturacion']);
      final factB = _n(b?['facturacion']);
      final pesoA = _n(a?['peso']);
      final pesoB = _n(b?['peso']);

      bool incluir = false;

      switch (categoria) {
        case _CategoriaCartera.nuevos:
          incluir = factB == 0 && factA > 0;
          break;
        case _CategoriaCartera.crecieron:
          // No incluye clientes nuevos: esos tienen su propia categoría.
          incluir = factB > 0 && factA > factB;
          break;
        case _CategoriaCartera.disminuyeron:
          incluir = factA > 0 && factA < factB;
          break;
        case _CategoriaCartera.sinCompra:
          incluir = factA == 0 && factB > 0;
          break;
      }

      if (!incluir) continue;

      final variacionMonto = factB == 0
          ? null
          : ((factA - factB) / factB) * 100;

      final variacionPeso = pesoB == 0
          ? null
          : ((pesoA - pesoB) / pesoB) * 100;

      rows.add({
        'cliente': nombre,
        'factA': factA,
        'factB': factB,
        'pesoA': pesoA,
        'pesoB': pesoB,
        'varMonto': variacionMonto,
        'varPeso': variacionPeso,
      });
    }

    rows.sort(
      (x, y) => _n(y['factA']).compareTo(_n(x['factA'])),
    );

    if (!mounted) return;

    final vendedorPorCliente = await _cargarVendedorPorCliente(
      rows.map((r) => _s(r['cliente'])),
    );

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final ancho = MediaQuery.of(dialogContext).size.width;
        final alto = MediaQuery.of(dialogContext).size.height;

        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          titlePadding: const EdgeInsets.fromLTRB(22, 18, 18, 8),
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Icon(Icons.groups_outlined, color: color, size: 25),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    color: azul,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${rows.length} clientes',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: ancho > 1200 ? 1100 : ancho * .90,
            height: alto > 800 ? 570 : alto * .70,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: fondo,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: borde),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comparación $anioActual vs $anioComparacion  •  '
                        'Facturación y peso de cobre por cliente',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 15,
                            color: azul,
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Vendedor:',
                            style: TextStyle(
                              color: azul,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _etiquetaVendedorReporte(),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.storefront_outlined,
                            size: 14,
                            color: azul,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Canal: ${canal == 'TODOS' ? 'Todos' : canal}',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: rows.isEmpty
                      ? Center(
                          child: Text(
                            'No hay clientes en esta categoría para el periodo seleccionado.',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: borde),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: SingleChildScrollView(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowHeight: 42,
                                  dataRowMinHeight: 48,
                                  dataRowMaxHeight: 58,
                                  columnSpacing: 22,
                                  headingRowColor:
                                      WidgetStatePropertyAll(
                                    fondo,
                                  ),
                                  columns: [
                                    const DataColumn(
                                      label: Text(
                                        'Cliente',
                                        style: TextStyle(
                                          color: azul,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const DataColumn(
                                      label: Text(
                                        'Vendedor',
                                        style: TextStyle(
                                          color: azul,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      numeric: true,
                                      label: Text(
                                        '$anioActual Fact.',
                                        style: const TextStyle(
                                          color: azul,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      numeric: true,
                                      label: Text(
                                        '$anioComparacion Fact.',
                                        style: const TextStyle(
                                          color: azul,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const DataColumn(
                                      numeric: true,
                                      label: Text(
                                        'Var. monto',
                                        style: TextStyle(
                                          color: azul,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      numeric: true,
                                      label: Text(
                                        '$anioActual Peso',
                                        style: const TextStyle(
                                          color: azul,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      numeric: true,
                                      label: Text(
                                        '$anioComparacion Peso',
                                        style: const TextStyle(
                                          color: azul,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const DataColumn(
                                      numeric: true,
                                      label: Text(
                                        'Var. peso',
                                        style: TextStyle(
                                          color: azul,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: [
                                    for (final row in rows)
                                      DataRow(
                                        cells: [
                                          DataCell(
                                            SizedBox(
                                              width: 270,
                                              child: Text(
                                                _s(row['cliente']),
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: 150,
                                              child: Text(
                                                vendedorPorCliente[_s(row['cliente']).trim().toUpperCase()] ??
                                                    (vendedor == 'TODOS' ? 'No identificado' : vendedor),
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              'US\$ ${money.format(_n(row['factA']))}',
                                              style: const TextStyle(
                                                color: azulClaro,
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              'US\$ ${money.format(_n(row['factB']))}',
                                              style: const TextStyle(
                                                color: Colors.black54,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            _variacionCell(
                                              row['varMonto'] as double?,
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '${money.format(_n(row['pesoA']))} kg',
                                              style: const TextStyle(
                                                color: azulClaro,
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '${money.format(_n(row['pesoB']))} kg',
                                              style: const TextStyle(
                                                color: Colors.black54,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            _variacionCell(
                                              row['varPeso'] as double?,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            OutlinedButton.icon(
              onPressed: rows.isEmpty
                  ? null
                  : () => _exportarDetalleCarteraExcel(
                        titulo: titulo,
                        rows: rows,
                      ),
              icon: const Icon(Icons.table_view_outlined, size: 18),
              label: const Text(
                'Exportar Excel',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton.icon(
              onPressed: rows.isEmpty
                  ? null
                  : () => _imprimirDetalleCartera(
                        titulo: titulo,
                        categoria: categoria,
                        rows: rows,
                        color: color,
                      ),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text(
                'Imprimir detalle',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close),
              label: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _imprimirDetalleCartera({
    required String titulo,
    required _CategoriaCartera categoria,
    required List<Map<String, dynamic>> rows,
    required Color color,
  }) async {
    if (rows.isEmpty) return;

    final vendedorPorCliente = await _cargarVendedorPorCliente(
      rows.map((r) => _s(r['cliente'])),
    );

    try {
      final logoData = await services.rootBundle.load(
        'assets/crm/images/logo_elcope.png',
      );
      final logo = pw.MemoryImage(logoData.buffer.asUint8List());

      final pdfColor = PdfColor.fromHex(
        '#${color.value.toRadixString(16).substring(2)}',
      );

      await Printing.layoutPdf(
        name: 'ELCOPE_${titulo.replaceAll(' ', '_')}_${anioActual}_vs_$anioComparacion',
        format: PdfPageFormat.a4.landscape,
        onLayout: (format) async {
          final pdf = pw.Document();

          pdf.addPage(
            pw.MultiPage(
              pageFormat: PdfPageFormat.a4.landscape,
              margin: const pw.EdgeInsets.fromLTRB(24, 18, 24, 18),
              header: (context) => pw.Column(
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 125,
                        height: 40,
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Image(logo, fit: pw.BoxFit.contain),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              'DETALLE DE CARTERA',
                              style: pw.TextStyle(
                                color: PdfColor.fromHex('#0B4A78'),
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              titulo.toUpperCase(),
                              style: pw.TextStyle(
                                color: pdfColor,
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.Container(
                        width: 180,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _pdfMetaLine('Canal:', canal == 'TODOS' ? 'Todos' : canal),
                            _pdfMetaLine('Vendedor:', _etiquetaVendedorReporte()),
                            _pdfMetaLine('Periodo:', '${date.format(desde)} - ${date.format(hasta)}'),
                            _pdfMetaLine('Comparar con:', '$anioComparacion'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 5),
                  pw.Container(height: 2, color: PdfColor.fromHex('#0B4A78')),
                  pw.SizedBox(height: 5),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F4F7FA'),
                      border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Comparación $anioActual vs $anioComparacion · Facturación y peso de cobre por cliente',
                                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'Vendedor: ${_etiquetaVendedorReporte()}   ·   Canal: ${canal == 'TODOS' ? 'Todos' : canal}',
                                style: pw.TextStyle(
                                  fontSize: 7.2,
                                  color: PdfColor.fromHex('#0B4A78'),
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.Text(
                          '${rows.length} clientes',
                          style: pw.TextStyle(fontSize: 7.5, color: pdfColor, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 7),
                ],
              ),
              footer: (context) => pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'ELCOPE · Reporte de cartera',
                    style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Página ${context.pageNumber} de ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
                  ),
                ],
              ),
              build: (context) => [
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(
                    color: PdfColor.fromHex('#D9E1E8'),
                    width: .5,
                  ),
                  headerDecoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#EAF1F7'),
                  ),
                  headerStyle: pw.TextStyle(
                    color: PdfColor.fromHex('#0B4A78'),
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 6.5),
                  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.7),
                    1: const pw.FlexColumnWidth(1.8),
                    2: const pw.FlexColumnWidth(1.25),
                    3: const pw.FlexColumnWidth(1.25),
                    4: const pw.FlexColumnWidth(1.1),
                    5: const pw.FlexColumnWidth(1.2),
                    6: const pw.FlexColumnWidth(1.2),
                    7: const pw.FlexColumnWidth(1.1),
                  },
                  headers: [
                    'Cliente',
                    'Vendedor',
                    '$anioActual Fact.',
                    '$anioComparacion Fact.',
                    'Var. monto',
                    '$anioActual Peso',
                    '$anioComparacion Peso',
                    'Var. peso',
                  ],
                  data: [
                    for (final row in rows)
                      [
                        _s(row['cliente']),
                        vendedorPorCliente[_s(row['cliente']).trim().toUpperCase()] ??
                            (vendedor == 'TODOS' ? 'No identificado' : vendedor),
                        'US\$ ${money.format(_n(row['factA']))}',
                        'US\$ ${money.format(_n(row['factB']))}',
                        _pdfVariationText(row['varMonto'] as double?),
                        '${money.format(_n(row['pesoA']))} kg',
                        '${money.format(_n(row['pesoB']))} kg',
                        _pdfVariationText(row['varPeso'] as double?),
                      ],
                  ],
                ),
              ],
            ),
          );

          return pdf.save();
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo imprimir el detalle: $e')),
      );
    }
  }

  String _pdfVariationText(double? value) {
    if (value == null || value.isNaN || value.isInfinite) return '—';
    return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}%';
  }

  Widget _variacionCell(double? value) {
    if (value == null || value.isNaN || value.isInfinite) {
      return const Text(
        '—',
        style: TextStyle(
          color: Colors.black45,
          fontSize: 11,
        ),
      );
    }

    final positivo = value >= 0;

    return Text(
      '${positivo ? '+' : ''}${value.toStringAsFixed(1)}%',
      style: TextStyle(
        color: positivo ? verde : rojo,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _indicadoresComparativos(
    List<Map<String, dynamic>> vendedoresActuales,
    List<Map<String, dynamic>> clientesActuales,
  ) {
    final k = Map<String, dynamic>.from(
      data['kpis'] is Map ? data['kpis'] as Map : <String, dynamic>{},
    );
    final ka = Map<String, dynamic>.from(
      dataAnterior['kpis'] is Map
          ? dataAnterior['kpis'] as Map
          : <String, dynamic>{},
    );

    final mensual = _mapList(data['mensual']);
    final fact = _n(k['facturacion']);
    final factAnterior = _n(ka['facturacion']);

    final promedio = mensual.isEmpty ? 0.0 : fact / mensual.length;

    Map<String, dynamic>? mejor;
    if (mensual.isNotEmpty) {
      mejor = mensual.reduce(
        (x, y) => _n(x['facturacion']) >= _n(y['facturacion'])
            ? x
            : y,
      );
    }

    final crecimiento = factAnterior == 0
        ? 0.0
        : ((fact - factAnterior) / factAnterior) * 100;

    final ticket = _n(k['facturas']) == 0
        ? 0.0
        : fact / _n(k['facturas']);

    final peso = _n(k['peso']);
    final kgMil = fact == 0 ? 0.0 : peso / (fact / 1000);

    return _panel(
      title: 'Indicadores ejecutivos',
      subtitle: 'Lectura rápida para gestión comercial',
      icon: Icons.insights_outlined,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 800 ? 2 : 5;
            const gap = 10.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) /
                    columns;

            final cards = [
              _indicatorCard(
                'Promedio mensual',
                'US\$ ${money.format(promedio)}',
                Icons.show_chart,
                azulClaro,
              ),
              _indicatorCard(
                'Mejor mes',
                mejor == null
                    ? '-'
                    : '${_s(mejor['periodo'])} · US\$ ${money.format(_n(mejor['facturacion']))}',
                Icons.calendar_today_outlined,
                verde,
              ),
              _indicatorCard(
                'Crecimiento acumulado',
                '${crecimiento >= 0 ? '+' : ''}${crecimiento.toStringAsFixed(1)}%',
                Icons.percent_outlined,
                azulClaro,
              ),
              _indicatorCard(
                'Ticket promedio',
                'US\$ ${money.format(ticket)}',
                Icons.shopping_cart_outlined,
                naranja,
              ),
              _indicatorCard(
                'Kg / US\$ 1,000',
                '${money.format(kgMil)} kg',
                Icons.scale_outlined,
                rojo,
              ),
            ];

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: cards
                  .map(
                    (c) => SizedBox(
                      width: width,
                      child: c,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }

  Widget _indicatorCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: color.withValues(alpha: .15),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarComparativoMes(
    Map<String, dynamic> row,
  ) async {
    final label = _s(row['label']);
    final a = Map<String, dynamic>.from(
      row['a'] is Map ? row['a'] as Map : <String, dynamic>{},
    );
    final b = Map<String, dynamic>.from(
      row['b'] is Map ? row['b'] as Map : <String, dynamic>{},
    );

    final factA = _n(a['facturacion']);
    final factB = _n(b['facturacion']);
    final pesoA = _n(a['peso']);
    final pesoB = _n(b['peso']);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Comparativo comercial — $label',
            style: const TextStyle(
              color: azul,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: SizedBox(
            width: 680,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _dialogMetric(
                        '$anioActual',
                        'US\$ ${money.format(factA)}',
                        azulClaro,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dialogMetric(
                        '$anioComparacion',
                        'US\$ ${money.format(factB)}',
                        naranja,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _dialogMetric(
                        'Peso $anioActual',
                        '${money.format(pesoA)} kg',
                        azulClaro,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dialogMetric(
                        'Peso $anioComparacion',
                        '${money.format(pesoB)} kg',
                        naranja,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Variación facturación: ${factB == 0 ? '0.0' : ((factA - factB) / factB * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: factA >= factB ? verde : rojo,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Variación peso: ${pesoB == 0 ? '0.0' : ((pesoA - pesoB) / pesoB * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: pesoA >= pesoB ? verde : rojo,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _dialogMetric(
    String title,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: .16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(Map<String, dynamic> k) {
    final fact = _n(k['facturacion']);
    final peso = _n(k['peso']);
    final facturas = _n(k['facturas']).round();
    final clientes = _n(k['clientes']).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0B4A78),
            Color(0xFF12689E),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RESUMEN EJECUTIVO COMERCIAL',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            canal == 'TODOS'
                ? 'Resultado consolidado'
                : 'Resultado del canal $canal',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _filtroTexto(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width < 650 ? 1 : 4;
              const gap = 10.0;
              final cardWidth = columns == 1
                  ? width
                  : (width - gap * (columns - 1)) / columns;

              final cards = [
                _heroKpi(
                  'Facturación',
                  'US\$ ${money.format(fact)}',
                  Icons.bar_chart_outlined,
                  Colors.white,
                ),
                _heroKpi(
                  'Peso cobre',
                  '${money.format(peso)} kg',
                  Icons.scale_outlined,
                  Colors.white,
                ),
                _heroKpi(
                  'Facturas',
                  integer.format(facturas),
                  Icons.description_outlined,
                  Colors.white,
                ),
                _heroKpi(
                  'Clientes',
                  integer.format(clientes),
                  Icons.groups_outlined,
                  Colors.white,
                ),
              ];

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: cards
                    .map(
                      (card) => SizedBox(
                        width: cardWidth,
                        child: card,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _heroKpi(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: .18),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _factLabel(double value) {
    if (value >= 1000000) return 'US\$ ${(value / 1000000).toStringAsFixed(2)} M';
    if (value >= 1000) return 'US\$ ${(value / 1000).toStringAsFixed(0)} K';
    return 'US\$ ${money.format(value)}';
  }

  String _pesoLabel(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(2)} K kg';
    return '${money.format(value)} kg';
  }

  Widget _mensual(List<Map<String, dynamic>> rows) {
    final maxFact = rows.fold<double>(
      0,
      (m, r) => _n(r['facturacion']) > m ? _n(r['facturacion']) : m,
    );
    final maxPeso = rows.fold<double>(
      0,
      (m, r) => _n(r['peso']) > m ? _n(r['peso']) : m,
    );

    return _panel(
      title: 'Evolución mensual: Facturación y peso cobre',
      subtitle: 'Haz clic en cualquier barra para abrir la vista previa comercial',
      icon: Icons.bar_chart_outlined,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(14, 2, 14, 8),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFD),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borde),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: azulClaro, label: 'Facturación (US\$)'),
                SizedBox(width: 28),
                _LegendDot(color: naranja, label: 'Peso cobre (kg)'),
              ],
            ),
          ),
          SizedBox(
            height: 345,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final groupWidth = rows.length <= 6 ? 150.0 : 145.0;
                final chartWidth =
                    rows.length * groupWidth < constraints.maxWidth
                        ? constraints.maxWidth
                        : rows.length * groupWidth;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: chartWidth,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: rows.map((r) {
                          final fact = _n(r['facturacion']);
                          final peso = _n(r['peso']);
                          final periodo = _s(r['periodo']);

                          final factH = maxFact == 0
                              ? 10.0
                              : (fact / maxFact) * 205.0;
                          final pesoH = maxPeso == 0
                              ? 10.0
                              : (peso / maxPeso) * 205.0;

                          return SizedBox(
                            width: groupWidth,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _mostrarMes(r),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    SizedBox(
                                      height: 245,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          _chartBar(
                                            value: fact,
                                            height: factH,
                                            color: azulClaro,
                                            label: _factLabel(fact),
                                          ),
                                          const SizedBox(width: 8),
                                          _chartBar(
                                            value: peso,
                                            height: pesoH,
                                            color: naranja,
                                            label: _pesoLabel(peso),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        periodo,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(
              'Haz clic en una barra o en el mes para abrir la Vista previa comercial.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.black45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartBar({
    required double value,
    required double height,
    required Color color,
    required String label,
  }) {
    return SizedBox(
      width: 47,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 30,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 38,
            height: height.clamp(10.0, 205.0),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: .16),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankingAsesores(List<Map<String, dynamic>> rows) {
    final top = rows.take(10).toList();
    final max = top.isEmpty ? 0.0 : _n(top.first['facturacion']);

    return _panel(
      title: 'Ranking de asesores',
      subtitle: 'Facturación y peso acumulado',
      icon: Icons.groups_outlined,
      child: top.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Sin asesores en el periodo.'),
            )
          : Column(
              children: [
                for (var i = 0; i < top.length; i++)
                  _rankingRow(
                    position: i + 1,
                    name: _s(top[i]['vendedor']),
                    amount: _n(top[i]['facturacion']),
                    weight: _n(top[i]['peso']),
                    max: max,
                    color: azulClaro,
                  ),
              ],
            ),
    );
  }

  Widget _rankingClientes(List<Map<String, dynamic>> rows) {
    final top = rows.take(10).toList();
    final max = top.isEmpty ? 0.0 : _n(top.first['facturacion']);

    return _panel(
      title: 'Top clientes',
      subtitle: 'Clientes con mayor facturación',
      icon: Icons.business_outlined,
      child: top.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Sin clientes en el periodo.'),
            )
          : Column(
              children: [
                for (var i = 0; i < top.length; i++)
                  _rankingRow(
                    position: i + 1,
                    name: _s(top[i]['cliente']),
                    amount: _n(top[i]['facturacion']),
                    weight: _n(top[i]['peso']),
                    max: max,
                    color: morado,
                  ),
              ],
            ),
    );
  }

  Widget _rankingRow({
    required int position,
    required String name,
    required double amount,
    required double weight,
    required double max,
    required Color color,
  }) {
    final progress = max <= 0 ? 0.0 : (amount / max).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: CircleAvatar(
              radius: 13,
              backgroundColor: position <= 3
                  ? color.withValues(alpha: .15)
                  : const Color(0xFFF1F5F9),
              child: Text(
                '$position',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: position <= 3 ? color : Colors.black54,
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'SIN NOMBRE' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: const Color(0xFFEFF3F6),
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'US\$ ${money.format(amount)}',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${money.format(weight)} kg',
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _conclusiones(
    Map<String, dynamic> k,
    List<Map<String, dynamic>> ven,
    List<Map<String, dynamic>> cli,
    List<Map<String, dynamic>> mes,
  ) {
    final topVen = ven.isEmpty ? null : ven.first;
    final topCli = cli.isEmpty ? null : cli.first;
    final topMes = mes.isEmpty
        ? null
        : mes.reduce(
            (a, b) => _n(a['facturacion']) >= _n(b['facturacion']) ? a : b,
          );

    final avg = mes.isEmpty
        ? 0.0
        : _n(k['facturacion']) / mes.length;

    return _panel(
      title: 'Indicadores ejecutivos',
      subtitle: 'Lectura rápida para gestión comercial',
      icon: Icons.insights_outlined,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _insight(
              'Promedio mensual',
              'US\$ ${money.format(avg)}',
              Icons.show_chart,
              azulClaro,
            ),
            _insight(
              'Mejor mes',
              topMes == null
                  ? '-'
                  : '${_s(topMes['periodo'])} · US\$ ${money.format(_n(topMes['facturacion']))}',
              Icons.calendar_today_outlined,
              verde,
            ),
            _insight(
              'Asesor líder',
              topVen == null ? '-' : _s(topVen['vendedor']),
              Icons.person_outline,
              naranja,
            ),
            _insight(
              'Cliente líder',
              topCli == null ? '-' : _s(topCli['cliente']),
              Icons.business_outlined,
              morado,
            ),
          ],
        ),
      ),
    );
  }

  Widget _insight(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borde),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 7,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 10),
            child: Row(
              children: [
                Icon(icon, color: azul, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: azul,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}


class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}


class _DonutPainter extends CustomPainter {
  final Map<String, double> values;

  const _DonutPainter({
    required this.values,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final entries = values.entries
        .where((entry) => entry.value > 0)
        .toList();

    final total = entries.fold<double>(
      0,
      (sum, entry) => sum + entry.value,
    );

    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius = size.shortestSide / 2 - 7;

    final colors = <Color>[
      const Color(0xFF079B63),
      const Color(0xFFF08A00),
      const Color(0xFF1877D1),
      const Color(0xFF64748B),
      const Color(0xFF5B45C5),
      const Color(0xFF0F766E),
    ];

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 25
      ..strokeCap = StrokeCap.butt;

    if (total <= 0) {
      paint.color = const Color(0xFFE5E7EB);
      canvas.drawCircle(center, radius, paint);
      return;
    }

    double start = -3.141592653589793 / 2;

    for (var i = 0; i < entries.length; i++) {
      final value = entries[i].value;
      final sweep =
          value / total * 3.141592653589793 * 2;

      paint.color = colors[i % colors.length];

      canvas.drawArc(
        Rect.fromCircle(
          center: center,
          radius: radius,
        ),
        start,
        sweep,
        false,
        paint,
      );

      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    if (oldDelegate.values.length != values.length) {
      return true;
    }

    for (final entry in values.entries) {
      if (oldDelegate.values[entry.key] != entry.value) {
        return true;
      }
    }

    return false;
  }
}
