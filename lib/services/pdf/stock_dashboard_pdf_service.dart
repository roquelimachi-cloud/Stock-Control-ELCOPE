import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class StockDashboardPdfItem {
  const StockDashboardPdfItem({
    required this.nombre,
    required this.valor,
    required this.peso,
    required this.stock,
    required this.cantidad,
  });

  final String nombre;
  final double valor;
  final double peso;
  final double stock;
  final int cantidad;
}

class StockDashboardPdfService {
  static const _verde = PdfColor.fromInt(0xFF087A4A);
  static const _verdeBarra = PdfColor.fromInt(0xFF16A66A);
  static const _azul = PdfColor.fromInt(0xFF2468D8);
  static const _verdeClaro = PdfColor.fromInt(0xFFE4F6ED);
  static const _fondo = PdfColor.fromInt(0xFFF5F8F7);
  static const _borde = PdfColor.fromInt(0xFFDDE9E4);

  static String _money(double value) => value
      .toStringAsFixed(2)
      .replaceAllMapped(RegExp(r'(?<=\d)(?=(\d{3})+(?!\d))'), (_) => ',');

  static String _compact(double value) {
    if (value.abs() >= 1000000) return '${(value / 1000000).toStringAsFixed(2)} M';
    if (value.abs() >= 1000) return '${(value / 1000).toStringAsFixed(1)} K';
    return value.toStringAsFixed(2);
  }

  static Future<void> imprimir({
    required BuildContext context,
    required String titulo,
    required List<StockDashboardPdfItem> items,
  }) async {
    try {
      final ordenados = [...items]
        ..sort((a, b) => b.valor.compareTo(a.valor));

      final pdf = pw.Document(
        title: 'Control de Stock - $titulo',
        author: 'ELCOPE',
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          maxPages: 100,
          margin: const pw.EdgeInsets.fromLTRB(18, 16, 18, 18),
          header: (_) => _header(),
          footer: (ctx) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'ELCOPE - $titulo - Página ${ctx.pageNumber}',
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
            ),
          ),
          build: (_) => [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(9),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(color: _borde),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    titulo,
                    style: pw.TextStyle(
                      color: _verde,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Valor de stock (US\$) + Peso de cobre (kg)',
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  ...ordenados.map((e) => _filaGraficoIndividual(e, ordenados)),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      _leyendaItem(_azul, 'Valor Stock (US\$)'),
                      pw.SizedBox(width: 16),
                      _leyendaItem(_verdeBarra, 'Peso de cobre (kg)'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      final bytes = Uint8List.fromList(await pdf.save());
      await Printing.layoutPdf(
        name: 'control_stock_${titulo.toLowerCase().replaceAll(' ', '_')}.pdf',
        format: PdfPageFormat.a4.landscape,
        usePrinterSettings: false,
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('No se pudo imprimir: $e'),
        ),
      );
    }
  }

  static pw.Widget _filaGraficoIndividual(
    StockDashboardPdfItem item,
    List<StockDashboardPdfItem> items,
  ) {
    final maxValor = items.isEmpty
        ? 0.0
        : items.map((e) => e.valor).reduce((a, b) => a > b ? a : b);
    final maxPeso = items.isEmpty
        ? 0.0
        : items.map((e) => e.peso).reduce((a, b) => a > b ? a : b);

    final valorRatio = maxValor <= 0 ? 0.0 : item.valor / maxValor;
    final pesoRatio = maxPeso <= 0 ? 0.0 : item.peso / maxPeso;

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 115,
            child: pw.Text(
              item.nombre,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              style: const pw.TextStyle(fontSize: 6.2),
            ),
          ),
          pw.SizedBox(width: 5),
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Container(
                    height: 5,
                    width: double.infinity,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                    child: pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Container(
                        height: 5,
                        width: 430 * valorRatio.clamp(0, 1),
                        decoration: pw.BoxDecoration(
                          color: _azul,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Container(
                    height: 4,
                    width: double.infinity,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                    child: pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Container(
                        height: 4,
                        width: 430 * pesoRatio.clamp(0, 1),
                        decoration: pw.BoxDecoration(
                          color: _verdeBarra,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 8),
          pw.SizedBox(
            width: 75,
            child: pw.Text(
              'US\$ ${_money(item.valor)}',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                color: _azul,
                fontSize: 6,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.SizedBox(
            width: 65,
            child: pw.Text(
              '${_money(item.peso)} kg',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                color: _verde,
                fontSize: 6,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _leyendaItem(PdfColor color, String texto) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(width: 7, height: 7, color: color),
        pw.SizedBox(width: 3),
        pw.Text(
          texto,
          style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
        ),
      ],
    );
  }

  static Future<void> imprimirDashboard({
    required BuildContext context,
    required List<StockDashboardPdfItem> clases,
    required List<StockDashboardPdfItem> condiciones,
    required List<StockDashboardPdfItem> almacenes,
    required List<StockDashboardPdfItem> clientes,
    required List<StockDashboardPdfItem> vendedores,
    required List<StockDashboardPdfItem> productos,
    required int totalRegistros,
    required double totalStock,
    required double totalValor,
    required double totalPeso,
    String busqueda = 'TODAS',
    String clase = 'TODAS',
    String almacen = 'TODOS',
    String vendedor = 'TODOS',
    String condicion = 'TODAS',
    String fecha = 'Todas las fechas',
  }) async {
    try {
      final logoBytes = await _cargarLogo();
      final logo = logoBytes == null ? null : pw.MemoryImage(logoBytes);

      final grupos = <String, List<StockDashboardPdfItem>>{
        'STOCK POR CLASE': [...clases],
        'STOCK POR CONDICIÓN': [...condiciones],
        'VALOR DE STOCK POR ALMACÉN': [...almacenes],
        'TOP 10 CLIENTES CON MAYOR STOCK': [...clientes.take(10)],
        'TOP 10 PRODUCTOS': [...productos.take(10)],
        'STOCK POR VENDEDOR': [...vendedores.take(10)],
      };

      for (final lista in grupos.values) {
        lista.sort((a, b) => b.valor.compareTo(a.valor));
      }

      final pdf = pw.Document(
        title: 'Control de Stock - Dashboard',
        author: 'ELCOPE',
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.fromLTRB(18, 14, 18, 14),
          build: (_) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _headerDashboard(logo),
                pw.SizedBox(height: 6),
                _filtrosCompactos(
                  busqueda: busqueda,
                  clase: clase,
                  almacen: almacen,
                  vendedor: vendedor,
                  condicion: condicion,
                  fecha: fecha,
                ),
                pw.SizedBox(height: 6),
                _kpis(totalRegistros, totalStock, totalValor, totalPeso),
                pw.SizedBox(height: 7),
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      pw.Expanded(
                        flex: 5,
                        child: _filaGraficos(
                          grupos['STOCK POR CLASE']!,
                          grupos['STOCK POR CONDICIÓN']!,
                          grupos['VALOR DE STOCK POR ALMACÉN']!,
                        ),
                      ),
                      pw.SizedBox(height: 7),
                      pw.Expanded(
                        flex: 5,
                        child: _filaRankings(
                          grupos['TOP 10 CLIENTES CON MAYOR STOCK']!,
                          grupos['TOP 10 PRODUCTOS']!,
                          grupos['STOCK POR VENDEDOR']!,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'ELCOPE - Control de Stock - Dashboard actual',
                    style: const pw.TextStyle(
                      fontSize: 5.5,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      final bytes = Uint8List.fromList(await pdf.save());
      await Printing.layoutPdf(
        name: 'control_stock_dashboard.pdf',
        format: PdfPageFormat.a4.landscape,
        usePrinterSettings: false,
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('No se pudo imprimir el Dashboard: $e'),
        ),
      );
    }
  }

  static Future<Uint8List?> _cargarLogo() async {
    try {
      final data = await rootBundle.load('assets/images/logo_elcope.png');
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _headerDashboard(pw.MemoryImage? logo) {
    return pw.Container(
      height: 54,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _borde),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 39,
            height: 39,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _verdeClaro,
              borderRadius: pw.BorderRadius.circular(7),
            ),
            padding: const pw.EdgeInsets.all(4),
            child: logo == null
                ? pw.Text(
                    'E',
                    style: pw.TextStyle(
                      color: _verde,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  )
                : pw.Image(logo, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(width: 9),
          pw.Expanded(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ELCOPE',
                  style: pw.TextStyle(
                    color: _verde,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'CONTROL DE STOCK',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Análisis general de stock por clase, almacén, cliente, vendedor y producto.',
                  style: const pw.TextStyle(
                    fontSize: 5.8,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
          pw.Text(
            'REPORTE DE DASHBOARD',
            style: pw.TextStyle(
              color: _azul,
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _filtrosCompactos({
    required String busqueda,
    required String clase,
    required String almacen,
    required String vendedor,
    required String condicion,
    required String fecha,
  }) {
    return pw.Container(
      height: 43,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _borde),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 78,
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              'FILTROS DE STOCK',
              style: pw.TextStyle(
                color: _verde,
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          _filtroMini('Buscar', busqueda),
          pw.SizedBox(width: 4),
          _filtroMini('Clase', clase),
          pw.SizedBox(width: 4),
          _filtroMini('Almacén', almacen),
          pw.SizedBox(width: 4),
          _filtroMini('Vendedor', vendedor),
          pw.SizedBox(width: 4),
          _filtroMini('Condición', condicion),
          pw.SizedBox(width: 4),
          _filtroMini('Fecha', fecha),
        ],
      ),
    );
  }

  static pw.Widget _filtroMini(String titulo, String valor) {
    return pw.Expanded(
      child: pw.Container(
        height: 31,
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: pw.BoxDecoration(
          color: _fondo,
          border: pw.Border.all(color: _borde),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              titulo.toUpperCase(),
              style: const pw.TextStyle(fontSize: 4.2, color: PdfColors.grey600),
            ),
            pw.Text(
              valor.isEmpty ? 'TODAS' : valor,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(
                fontSize: 5.8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _header() {
    return pw.Container(
      height: 55,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _borde),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 38,
            height: 38,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _verdeClaro,
              borderRadius: pw.BorderRadius.circular(7),
            ),
            child: pw.Text(
              'E',
              style: pw.TextStyle(
                color: _verde,
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 9),
          pw.Expanded(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ELCOPE',
                  style: pw.TextStyle(
                    color: _verde,
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'CONTROL DE STOCK',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Análisis general de stock por clase, almacén, cliente, vendedor y producto.',
                  style: const pw.TextStyle(
                    fontSize: 6.5,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
          pw.Text(
            'REPORTE DE DASHBOARD',
            style: pw.TextStyle(
              color: _azul,
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _filtros({
    required String busqueda,
    required String clase,
    required String almacen,
    required String vendedor,
    required String condicion,
    required String fecha,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _borde),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                'FILTROS DE STOCK',
                style: pw.TextStyle(
                  color: _verde,
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Spacer(),
              pw.Text(
                'Vista actual del Dashboard',
                style: const pw.TextStyle(
                  fontSize: 6,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            children: [
              _filtro('Buscar', busqueda),
              pw.SizedBox(width: 5),
              _filtro('Clase', clase),
              pw.SizedBox(width: 5),
              _filtro('Almacén', almacen),
              pw.SizedBox(width: 5),
              _filtro('Vendedor', vendedor),
              pw.SizedBox(width: 5),
              _filtro('Condición', condicion),
              pw.SizedBox(width: 5),
              _filtro('Fecha', fecha),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _filtro(String titulo, String valor) {
    return pw.Expanded(
      child: pw.Container(
        height: 30,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: pw.BoxDecoration(
          color: _fondo,
          border: pw.Border.all(color: _borde),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              titulo.toUpperCase(),
              style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey600),
            ),
            pw.Text(
              valor.isEmpty ? 'TODAS' : valor,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(
                fontSize: 6.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _kpis(int registros, double stock, double valor, double peso) {
    return pw.Row(
      children: [
        _kpi('TOTAL PRODUCTOS', '$registros', _azul),
        pw.SizedBox(width: 7),
        _kpi('PESO TOTAL', '${_money(peso)} kg', _verdeBarra),
        pw.SizedBox(width: 7),
        _kpi('VALOR DE STOCK', 'US\$ ${_money(valor)}', _verde),
        pw.SizedBox(width: 7),
        _kpi('STOCK TOTAL', _money(stock), _azul),
      ],
    );
  }

  static pw.Widget _kpi(String titulo, String valor, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        height: 48,
        padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: _borde),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              titulo,
              style: const pw.TextStyle(
                fontSize: 6,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              valor,
              maxLines: 1,
              style: pw.TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _filaGraficos(
    List<StockDashboardPdfItem> clases,
    List<StockDashboardPdfItem> condiciones,
    List<StockDashboardPdfItem> almacenes,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _cardGrafico('STOCK POR CLASE', clases),
        pw.SizedBox(width: 8),
        _cardGrafico('STOCK POR CONDICIÓN', condiciones),
        pw.SizedBox(width: 8),
        _cardGrafico('VALOR DE STOCK POR ALMACÉN', almacenes),
      ],
    );
  }

  static pw.Widget _filaRankings(
    List<StockDashboardPdfItem> clientes,
    List<StockDashboardPdfItem> productos,
    List<StockDashboardPdfItem> vendedores,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _cardRanking('TOP 10 CLIENTES CON MAYOR STOCK', clientes),
        pw.SizedBox(width: 8),
        _cardRanking('TOP 10 PRODUCTOS', productos),
        pw.SizedBox(width: 8),
        _cardRanking('STOCK POR VENDEDOR', vendedores),
      ],
    );
  }

  static pw.Widget _cardGrafico(String titulo, List<StockDashboardPdfItem> data) {
    final visibles = data.take(8).toList();
    return pw.Expanded(
      child: pw.Container(
        height: double.infinity,
        padding: const pw.EdgeInsets.fromLTRB(9, 8, 9, 6),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: _borde),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              titulo,
              maxLines: 2,
              style: pw.TextStyle(
                color: _verde,
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Valor de stock (US\$) + Peso de cobre (kg)',
              style: const pw.TextStyle(
                color: PdfColors.grey600,
                fontSize: 5.8,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Expanded(
              child: visibles.isEmpty
                  ? pw.Center(
                      child: pw.Text(
                        'No hay datos para los filtros seleccionados.',
                        style: const pw.TextStyle(fontSize: 6.5),
                      ),
                    )
                  : _barrasVerticales(visibles),
            ),
            _leyenda(),
          ],
        ),
      ),
    );
  }

  static pw.Widget _barrasVerticales(List<StockDashboardPdfItem> data) {
    final maxValor = data
        .map((e) => e.valor)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final maxPeso = data
        .map((e) => e.peso)
        .fold<double>(0, (a, b) => a > b ? a : b);

    // Cada categoría tiene DOS barras independientes y JUNTAS:
    // azul = valor y verde = peso. Nunca se apilan verticalmente.
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        for (final item in data)
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 1.5),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.SizedBox(
                    height: 7,
                    child: pw.Text(
                      'US\$ ${_compact(item.valor)}',
                      maxLines: 1,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: _azul,
                        fontSize: 4.2,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 1),
                  pw.SizedBox(
                    height: 54,
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 9,
                          height: maxValor <= 0
                              ? 1
                              : 54 * (item.valor / maxValor),
                          decoration: pw.BoxDecoration(
                            color: _azul,
                            borderRadius: const pw.BorderRadius.vertical(
                              top: pw.Radius.circular(2),
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 2),
                        pw.Container(
                          width: 9,
                          height: maxPeso <= 0
                              ? 1
                              : 54 * (item.peso / maxPeso),
                          decoration: pw.BoxDecoration(
                            color: _verdeBarra,
                            borderRadius: const pw.BorderRadius.vertical(
                              top: pw.Radius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 1),
                  pw.SizedBox(
                    height: 7,
                    child: pw.Text(
                      '${_compact(item.peso)} kg',
                      maxLines: 1,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: _verde,
                        fontSize: 4.0,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.SizedBox(
                    height: 18,
                    child: pw.Text(
                      item.nombre,
                      textAlign: pw.TextAlign.center,
                      maxLines: 2,
                      overflow: pw.TextOverflow.clip,
                      style: const pw.TextStyle(fontSize: 4.0),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static pw.Widget _cardRanking(String titulo, List<StockDashboardPdfItem> data) {
    final visibles = data.take(10).toList();
    return pw.Expanded(
      child: pw.Container(
        height: double.infinity,
        padding: const pw.EdgeInsets.fromLTRB(9, 8, 9, 7),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: _borde),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              titulo,
              maxLines: 2,
              style: pw.TextStyle(
                color: PdfColors.grey900,
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Valor de stock (US\$) + Peso de cobre (kg)',
              style: const pw.TextStyle(
                color: PdfColors.grey600,
                fontSize: 5.8,
              ),
            ),
            pw.SizedBox(height: 6),
            if (visibles.isEmpty)
              pw.Expanded(
                child: pw.Center(
                  child: pw.Text(
                    'No hay datos para los filtros seleccionados.',
                    style: const pw.TextStyle(fontSize: 6.5),
                  ),
                ),
              )
            else
              for (int i = 0; i < visibles.length; i++)
                _rankingLinea(i + 1, visibles[i]),
            pw.Spacer(),
            _leyenda(),
          ],
        ),
      ),
    );
  }

  static pw.Widget _rankingLinea(int numero, StockDashboardPdfItem item) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.Container(
            width: 16,
            height: 16,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              '$numero',
              style: pw.TextStyle(
                color: _azul,
                fontSize: 6,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 5),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  item.nombre,
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                  style: pw.TextStyle(fontSize: 6.1, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 2),
                pw.Container(
                  height: 4,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 1,
                        child: pw.Container(
                          decoration: pw.BoxDecoration(
                            color: _azul,
                            borderRadius: pw.BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 5),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'US\$ ${_money(item.valor)}',
                style: pw.TextStyle(
                  color: _verde,
                  fontSize: 5.8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '${_money(item.peso)} kg',
                style: const pw.TextStyle(
                  color: PdfColors.grey600,
                  fontSize: 5.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _leyenda() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        _legend(_azul, 'Valor Stock (US\$)'),
        pw.SizedBox(width: 14),
        _legend(_verdeBarra, 'Peso de cobre (kg)'),
      ],
    );
  }

  static pw.Widget _legend(PdfColor color, String text) {
    return pw.Row(
      children: [
        pw.Container(width: 6, height: 6, color: color),
        pw.SizedBox(width: 3),
        pw.Text(
          text,
          style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey700),
        ),
      ],
    );
  }
}
