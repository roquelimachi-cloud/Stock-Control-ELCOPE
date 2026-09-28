
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../services/sesion.dart';
import '../../../services/supabase/supabase_service.dart';

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
  List<Map<String, dynamic>> clases = [];
  String? error;

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
    _init();
  }

  Future<void> _init() async {
    await _permisos();
    await _cargar();
  }

  Future<void> _permisos() async {
    if (esGerencia) {
      vendedoresPermitidos = null;
    } else if (esJefatura) {
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
    } else {
      vendedoresPermitidos = Sesion.vendedor.trim().isEmpty
          ? <String>[]
          : <String>[Sesion.vendedor.trim()];
    }

    vendedores = vendedoresPermitidos == null
        ? await _cargarListaVendedores()
        : List<String>.from(vendedoresPermitidos!);

    final rol = Sesion.rol.trim().toLowerCase();

    // Jefe Lima: el alcance geográfico es Canal LIMA y el reporte
    // considera todos los asesores que facturan por ese canal.
    if (rol == 'jefe lima') {
      canal = 'LIMA';
      vendedoresPermitidos = null;
      vendedores = await _cargarListaVendedores();
    } else if (rol == 'jefe provincia') {
      canal = 'PROVINCIAS';
    } else if (!esGerencia) {
      canal = 'LIMA';
    }

    if (vendedoresPermitidos != null &&
        vendedor != 'TODOS' &&
        !vendedores.contains(vendedor)) {
      vendedor = 'TODOS';
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

  Future<void> _cargar() async {
    if (mounted) setState(() => loading = true);

    try {
      final params = {
        'p_vendedores_permitidos': vendedoresPermitidos,
        'p_vendedor': vendedor,
        'p_desde': DateFormat('yyyy-MM-dd').format(desde),
        'p_hasta': DateFormat('yyyy-MM-dd').format(hasta),
        'p_canal': canal,
      };

      final result = await db.rpc(
        'crm_obtener_reportes',
        params: params,
      );

      final clasesResult = await db.rpc(
        'crm_obtener_reportes_clases',
        params: params,
      );

      final clasesCargadas = clasesResult is List
          ? clasesResult
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        data = result is Map
            ? Map<String, dynamic>.from(result)
            : <String, dynamic>{};
        clases = clasesCargadas;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
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
    final v = vendedor == 'TODOS' ? 'Todos los asesores' : vendedor;
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
                                'Canal: ${canal == 'TODOS' ? 'Todos' : canal} · ${vendedor == 'TODOS' ? 'Todos los asesores' : vendedor}',
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
                    _pdfKpi('Facturación', 'US\$ ${money.format(fact)}'),
                    pw.SizedBox(width: 8),
                    _pdfKpi('Peso cobre', '${money.format(peso)} kg'),
                    pw.SizedBox(width: 8),
                    _pdfKpi('Facturas', integer.format(facturas)),
                    pw.SizedBox(width: 8),
                    _pdfKpi('Clientes', integer.format(clientes)),
                  ],
                ),
                pw.SizedBox(height: 15),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: _pdfVendedores(asesores),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: _pdfClientes(clientesTop),
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

  Future<void> _imprimir() async {
    if (loading || data.isEmpty) return;

    final k = Map<String, dynamic>.from(
      data['kpis'] is Map ? data['kpis'] as Map : <String, dynamic>{},
    );
    final ven = _mapList(data['vendedores']);
    final cli = _mapList(data['clientes']);
    final mes = _mapList(data['mensual']);
    final cls = [...clases]
      ..sort((a, b) => _n(b['facturacion']).compareTo(_n(a['facturacion'])));

    try {
      await Printing.layoutPdf(
        onLayout: (format) async {
          final pdf = pw.Document();
          final generated = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

          pdf.addPage(
            pw.MultiPage(
              pageFormat: PdfPageFormat.a4.landscape,
              margin: const pw.EdgeInsets.fromLTRB(26, 24, 26, 24),
              header: (context) => pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 8),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(
                      color: PdfColor.fromHex('#0B4A78'),
                      width: 2,
                    ),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'ELCOPE',
                          style: pw.TextStyle(
                            color: PdfColor.fromHex('#0B4A78'),
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'REPORTE EJECUTIVO CRM',
                          style: pw.TextStyle(
                            color: PdfColor.fromHex('#0B4A78'),
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Generado: $generated',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        pw.Text(
                          _filtroTexto(),
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              footer: (context) => pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Página ${context.pageNumber} / ${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 7,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
              build: (context) => [
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#0B4A78'),
                    borderRadius: pw.BorderRadius.circular(9),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'RESUMEN EJECUTIVO COMERCIAL',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        canal == 'TODOS'
                            ? 'Resultado consolidado'
                            : 'Resultado del canal $canal',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 17,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        _filtroTexto(),
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 8,
                        ),
                      ),
                      pw.SizedBox(height: 9),
                      pw.Row(
                        children: [
                          _pdfKpi('Facturación', 'US\$ ${money.format(_n(k['facturacion']))}'),
                          pw.SizedBox(width: 7),
                          _pdfKpi('Peso cobre', '${money.format(_n(k['peso']))} kg'),
                          pw.SizedBox(width: 7),
                          _pdfKpi('Facturas', integer.format(_n(k['facturas']).round())),
                          pw.SizedBox(width: 7),
                          _pdfKpi('Clientes', integer.format(_n(k['clientes']).round())),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                _pdfSectionTitle('Evolución mensual: Facturación y peso cobre'),
                _pdfMonthlyChart(mes),
                pw.SizedBox(height: 12),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(flex: 3, child: _pdfVendedores(ven)),
                    pw.SizedBox(width: 12),
                    pw.Expanded(flex: 2, child: _pdfClases(cls)),
                  ],
                ),
                pw.SizedBox(height: 12),
                _pdfClientes(cli),
              ]
            ),
          );

          return pdf.save();
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo imprimir: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  pw.Widget _pdfKpi(String title, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(9),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#FFFFFF'),
          border: pw.Border.all(color: PdfColor.fromHex('#DDE5ED')),
          borderRadius: pw.BorderRadius.circular(7),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: const pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#0B4A78'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#0B4A78'),
        ),
      ),
    );
  }


  pw.Widget _pdfMonthlyChart(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return pw.Container(
        height: 190,
        alignment: pw.Alignment.center,
        child: pw.Text('Sin datos mensuales'),
      );
    }

    final maxFact = rows.fold<double>(
      0,
      (m, r) => _n(r['facturacion']) > m ? _n(r['facturacion']) : m,
    );
    final maxPeso = rows.fold<double>(
      0,
      (m, r) => _n(r['peso']) > m ? _n(r['peso']) : m,
    );

    return pw.Container(
      height: 245,
      padding: const pw.EdgeInsets.fromLTRB(10, 6, 10, 5),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColor.fromHex('#DDE5ED')),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(
                width: 9,
                height: 9,
                color: PdfColor.fromHex('#1877D1'),
              ),
              pw.SizedBox(width: 4),
              pw.Text(
                'Facturación (US\$)',
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(width: 18),
              pw.Container(
                width: 9,
                height: 9,
                color: PdfColor.fromHex('#F08A00'),
              ),
              pw.SizedBox(width: 4),
              pw.Text(
                'Peso cobre (kg)',
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: rows.map((r) {
                final fact = _n(r['facturacion']);
                final peso = _n(r['peso']);
                final factH = maxFact == 0 ? 5.0 : fact / maxFact * 135;
                final pesoH = maxPeso == 0 ? 5.0 : peso / maxPeso * 135;

                return pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Expanded(
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Column(
                              mainAxisAlignment: pw.MainAxisAlignment.end,
                              children: [
                                pw.Container(
                                  height: 16,
                                  width: 36,
                                  alignment: pw.Alignment.center,
                                  child: pw.FittedBox(
                                    fit: pw.BoxFit.scaleDown,
                                    child: pw.Text(
                                      _factLabel(fact),
                                      style: pw.TextStyle(
                                        fontSize: 6.2,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColor.fromHex('#1877D1'),
                                      ),
                                    ),
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Container(
                                  width: 16,
                                  height: factH,
                                  decoration: pw.BoxDecoration(
                                    color: PdfColor.fromHex('#1877D1'),
                                    borderRadius: pw.BorderRadius.vertical(
                                      top: pw.Radius.circular(3),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(width: 3),
                            pw.Column(
                              mainAxisAlignment: pw.MainAxisAlignment.end,
                              children: [
                                pw.Container(
                                  height: 16,
                                  width: 36,
                                  alignment: pw.Alignment.center,
                                  child: pw.FittedBox(
                                    fit: pw.BoxFit.scaleDown,
                                    child: pw.Text(
                                      _pesoLabel(peso),
                                      style: pw.TextStyle(
                                        fontSize: 6.2,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColor.fromHex('#F08A00'),
                                      ),
                                    ),
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Container(
                                  width: 16,
                                  height: pesoH,
                                  decoration: pw.BoxDecoration(
                                    color: PdfColor.fromHex('#F08A00'),
                                    borderRadius: pw.BorderRadius.vertical(
                                      top: pw.Radius.circular(3),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        _s(r['periodo']),
                        style: pw.TextStyle(
                          fontSize: 6.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfClases(List<Map<String, dynamic>> rows) {
    final top = rows.take(8).toList();
    final colors = [
      PdfColor.fromHex('#1877D1'),
      PdfColor.fromHex('#F08A00'),
      PdfColor.fromHex('#079B63'),
      PdfColor.fromHex('#5B45C5'),
      PdfColor.fromHex('#64748B'),
    ];

    return pw.Container(
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColor.fromHex('#DDE5ED')),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _pdfSectionTitle('Distribución por clase'),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(
                width: 145,
                height: 145,
                child: pw.Chart(
                  grid: pw.PieGrid(),
                  datasets: [
                    for (var i = 0; i < top.length; i++)
                      pw.PieDataSet(
                        value: _n(top[i]['facturacion']),
                        legend: '',
                        color: colors[i % colors.length],
                        borderColor: PdfColors.white,
                        borderWidth: 1.2,
                        innerRadius: 38,
                        legendStyle: const pw.TextStyle(fontSize: 1),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: top.map((r) {
                    final i = top.indexOf(r);
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 5),
                      child: pw.Row(
                        children: [
                          pw.Container(
                            width: 8,
                            height: 8,
                            decoration: pw.BoxDecoration(
                              color: colors[i % colors.length],
                              shape: pw.BoxShape.circle,
                            ),
                          ),
                          pw.SizedBox(width: 5),
                          pw.Expanded(
                            child: pw.Text(
                              '${_s(r['clase'])}  ${_n(r['porcentaje']).toStringAsFixed(1)}%',
                              style: pw.TextStyle(
                                fontSize: 7,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.Text(
                            'US\$ ${money.format(_n(r['facturacion']))}',
                            style: const pw.TextStyle(fontSize: 6.5),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfMonthly(List<Map<String, dynamic>> rows) {
    return pw.Table.fromTextArray(
      headers: const [
        'Periodo',
        'Facturación',
        'Peso cobre',
        'Facturas',
        'Clientes',
      ],
      data: rows.map((r) {
        return [
          _s(r['periodo']),
          'US\$ ${money.format(_n(r['facturacion']))}',
          '${money.format(_n(r['peso']))} kg',
          integer.format(_n(r['facturas']).round()),
          integer.format(_n(r['clientes']).round()),
        ];
      }).toList(),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
      ),
      headerDecoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#0B4A78'),
      ),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellPadding: const pw.EdgeInsets.all(5),
      border: pw.TableBorder.all(
        color: PdfColor.fromHex('#DDE5ED'),
        width: .5,
      ),
    );
  }

  pw.Widget _pdfVendedores(List<Map<String, dynamic>> rows) {
    final top = rows.take(10).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pdfSectionTitle('Ranking de asesores'),
        pw.Table.fromTextArray(
          headers: const ['#', 'Asesor', 'Facturación', 'Peso', 'Facturas'],
          data: [
            for (var i = 0; i < top.length; i++)
              [
                '${i + 1}',
                _s(top[i]['vendedor']),
                'US\$ ${money.format(_n(top[i]['facturacion']))}',
                '${money.format(_n(top[i]['peso']))} kg',
                integer.format(_n(top[i]['facturas']).round()),
              ],
          ],
          headerStyle: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
          ),
          headerDecoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#1877D1'),
          ),
          cellStyle: const pw.TextStyle(fontSize: 7),
          cellPadding: const pw.EdgeInsets.all(4),
        ),
      ],
    );
  }

  pw.Widget _pdfClientes(List<Map<String, dynamic>> rows) {
    final top = rows.take(10).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pdfSectionTitle('Top clientes'),
        pw.Table.fromTextArray(
          headers: const ['#', 'Cliente', 'RUC', 'Facturación', 'Facturas'],
          data: [
            for (var i = 0; i < top.length; i++)
              [
                '${i + 1}',
                _s(top[i]['cliente']),
                _s(top[i]['codigo_cliente']),
                'US\$ ${money.format(_n(top[i]['facturacion']))}',
                integer.format(_n(top[i]['facturas']).round()),
              ],
          ],
          headerStyle: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
          ),
          headerDecoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#5B45C5'),
          ),
          cellStyle: const pw.TextStyle(fontSize: 7),
          cellPadding: const pw.EdgeInsets.all(4),
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
                      const DropdownMenuItem(
                        value: 'TODOS',
                        child: Text('Todos'),
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
                      setState(() => vendedor = value);
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
    final k = Map<String, dynamic>.from(
      data['kpis'] is Map ? data['kpis'] as Map : <String, dynamic>{},
    );
    final ven = _mapList(data['vendedores']);
    final cli = _mapList(data['clientes']);
    final mes = _mapList(data['mensual']);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _hero(k),
        const SizedBox(height: 14),
        _mensual(mes),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 1100;
            if (stacked) {
              return Column(
                children: [
                  _distribucionClases(clases),
                  const SizedBox(height: 14),
                  _rankingAsesores(ven),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _rankingAsesores(ven)),
                const SizedBox(width: 14),
                Expanded(child: _distribucionClases(clases)),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _rankingClientes(cli),
        const SizedBox(height: 14),
        _conclusiones(k, ven, cli, mes),
      ],
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


  Color _colorClase(String clase) {
    switch (clase.toUpperCase()) {
      case 'CL1':
        return azulClaro;
      case 'CL2':
        return naranja;
      case 'CL5':
        return verde;
      case 'CL6':
        return morado;
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _distribucionClases(List<Map<String, dynamic>> rows) {
    final ordered = [...rows]
      ..sort((a, b) => _n(b['facturacion']).compareTo(_n(a['facturacion'])));

    final total = ordered.fold<double>(
      0,
      (sum, row) => sum + _n(row['facturacion']),
    );

    return _panel(
      title: 'Distribución por clase',
      subtitle: 'Participación de la facturación por clase de cable',
      icon: Icons.donut_large_outlined,
      child: ordered.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No hay información de clases.'),
            )
          : SizedBox(
              height: 330,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 500;
                  final size = compact ? 175.0 : 210.0;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: size,
                        height: size,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: Size(size, size),
                              painter: _DonutPainter(
                                rows: ordered,
                                colors: [
                                  for (final row in ordered)
                                    _colorClase(_s(row['clase'])),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'FACTURACIÓN',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.black45,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'US\$ ${_factLabel(total)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: azul,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 22),
                      Expanded(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: ordered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 9),
                          itemBuilder: (context, index) {
                            final row = ordered[index];
                            final clase = _s(row['clase']).isEmpty
                                ? 'SIN CLASE'
                                : _s(row['clase']);
                            final color = _colorClase(clase);

                            return Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    clase,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_n(row['porcentaje']).toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
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



class _DonutPainter extends CustomPainter {
  final List<Map<String, dynamic>> rows;
  final List<Color> colors;

  _DonutPainter({
    required this.rows,
    required this.colors,
  });

  double _value(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final total = rows.fold<double>(
      0,
      (sum, row) => sum + _value(row['facturacion']),
    );

    if (total <= 0) return;

    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);

    var start = -3.141592653589793 / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * .30;

    for (var i = 0; i < rows.length; i++) {
      final value = _value(rows[i]['facturacion']);
      final sweep = value / total * 2 * 3.141592653589793;

      paint.color = colors[i % colors.length];
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
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
