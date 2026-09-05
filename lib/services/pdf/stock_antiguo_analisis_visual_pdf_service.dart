import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class StockAntiguoAnalisisVisualPdfItem {
  final String codigo;
  final String descripcion;
  final String cliente;
  final String asesor;
  final String clase;
  final String almacen;
  final DateTime fechaIngreso;
  final int dias;
  final double stock;
  final double precio;
  final double valorTotal;
  final double peso;

  const StockAntiguoAnalisisVisualPdfItem({
    required this.codigo,
    required this.descripcion,
    required this.cliente,
    required this.asesor,
    required this.clase,
    required this.almacen,
    required this.fechaIngreso,
    required this.dias,
    required this.stock,
    required this.precio,
    required this.valorTotal,
    required this.peso,
  });
}

class StockAntiguoAnalisisVisualPdfService {
  static const verde = PdfColor.fromInt(0xFF08783B);
  static const verdeSuave = PdfColor.fromInt(0xFFEAF5EE);
  static const azul = PdfColor.fromInt(0xFF1565D8);
  static const naranja = PdfColor.fromInt(0xFFF59E0B);
  static const rojo = PdfColor.fromInt(0xFFEF4444);
  static const amarillo = PdfColor.fromInt(0xFFF4C430);
  static const grisFondo = PdfColor.fromInt(0xFFF5F7F8);
  static const grisLinea = PdfColor.fromInt(0xFFDCE4DF);
  static const grisTexto = PdfColor.fromInt(0xFF52606D);

  static Future<void> imprimir({
    required BuildContext context,
    required String titulo,
    required String vista,
    required String filtroBusqueda,
    required String cliente,
    required String asesor,
    required String clase,
    required String almacen,
    required int diasMinimos,
    required String estado,
    required List<StockAntiguoAnalisisVisualPdfItem> items,
  }) async {
    if (items.isEmpty) return;

    final pdf = pw.Document(title: 'Stock Antiguo - Análisis Gerencial', author: 'ELCOPE');
    pw.MemoryImage? logo;
    try {
      final data = await rootBundle.load('assets/images/logo_elcope.png');
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {}

    final moneda = NumberFormat('#,##0.00', 'en_US');
    final cantidad = NumberFormat('#,##0.##', 'en_US');
    final fecha = DateFormat('dd/MM/yyyy');
    final fechaHora = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final valor = items.fold<double>(0, (s, e) => s + e.valorTotal);
    final peso = items.fold<double>(0, (s, e) => s + e.peso);
    final promedio = items.fold<int>(0, (s, e) => s + e.dias) / items.length;

    final gruposAsesor = _agrupar(items, (e) => e.asesor);
    final gruposCliente = _agrupar(items, (e) => e.cliente);
    final gruposClase = _agrupar(items, (e) => e.clase);
    final gruposAlmacen = _agrupar(items, (e) => e.almacen);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        maxPages: 100,
        margin: const pw.EdgeInsets.fromLTRB(18, 16, 18, 18),
        header: (ctx) => _header(logo, titulo, vista, fechaHora),
        footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('ELCOPE · STOCK ANTIGUO', style: pw.TextStyle(fontSize: 7, color: grisTexto)), pw.Text('Página ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: grisTexto))]),
        build: (ctx) => [
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _kpi('ARTÍCULOS', NumberFormat('#,##0', 'en_US').format(items.length), 'con más de 30 días', verde),
            pw.SizedBox(width: 8),
            _kpi('VALOR TOTAL', 'US\$ ${moneda.format(valor)}', 'en stock antiguo', azul),
            pw.SizedBox(width: 8),
            _kpi('PESO COBRE', '${cantidad.format(peso)} t', 'en stock antiguo', naranja),
            pw.SizedBox(width: 8),
            _kpi('DÍAS PROMEDIO', '${promedio.round()} días', 'de permanencia', azul),
          ]),
          pw.SizedBox(height: 8),
          _filterBox(vista, items.length, filtroBusqueda, cliente, asesor, clase, almacen, diasMinimos, estado),
          pw.SizedBox(height: 8),
          if (vista == 'RESUMEN GENERAL') ...[
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _panel('STOCK ANTIGUO POR ASESOR', gruposAsesor, 4),
              pw.SizedBox(width: 8),
              _panel('STOCK ANTIGUO POR CLASE', gruposClase, 4),
              pw.SizedBox(width: 8),
              _rangos(items),
              pw.SizedBox(width: 8),
              _panel('TOP 5 CLIENTES CON STOCK ANTIGUO', gruposCliente, 5),
            ]),
          ] else if (vista == 'POR ASESOR (VENDEDOR)')
            _panel('STOCK ANTIGUO POR ASESOR', gruposAsesor, 12)
          else if (vista == 'POR CLIENTE')
            _panel('STOCK ANTIGUO POR CLIENTE', gruposCliente, 12)
          else if (vista == 'POR CLASE DE PRODUCTO')
            _panel('STOCK ANTIGUO POR CLASE DE PRODUCTO', gruposClase, 12)
          else if (vista == 'POR ALMACÉN')
            _panel('STOCK ANTIGUO POR ALMACÉN', gruposAlmacen, 12)
          else
            _rangos(items),
          pw.SizedBox(height: 8),
          _tabla(items, fecha, moneda, cantidad),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  static pw.Widget _header(pw.MemoryImage? logo, String titulo, String vista, String fechaHora) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: grisLinea, width: .7))),
      child: pw.Row(children: [
        if (logo != null) pw.Container(width: 42, height: 32, margin: const pw.EdgeInsets.only(right: 8), child: pw.Image(logo, fit: pw.BoxFit.contain)),
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('STOCK ANTIGUO - ANÁLISIS GERENCIAL', style: pw.TextStyle(color: verde, fontSize: 16, fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 2), pw.Text(titulo, style: pw.TextStyle(color: grisTexto, fontSize: 8, fontWeight: pw.FontWeight.bold)), pw.Text('Vista: $vista', style: const pw.TextStyle(color: grisTexto, fontSize: 7))])),
        pw.Text(fechaHora, style: const pw.TextStyle(color: grisTexto, fontSize: 7)),
      ]),
    );
  }

  static pw.Widget _kpi(String titulo, String valor, String sub, PdfColor color) {
    return pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(color: PdfColors.white, border: pw.Border.all(color: grisLinea), borderRadius: pw.BorderRadius.circular(6)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text(titulo, style: pw.TextStyle(color: grisTexto, fontSize: 6, fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 3), pw.Text(valor, style: pw.TextStyle(color: color, fontSize: 12, fontWeight: pw.FontWeight.bold)), pw.Text(sub, style: const pw.TextStyle(color: grisTexto, fontSize: 6))])));
  }

  static pw.Widget _filterBox(String vista, int total, String busqueda, String cliente, String asesor, String clase, String almacen, int diasMinimos, String estado) {
    final filtros = <String>[
      if (busqueda.trim().isNotEmpty) 'Buscar: ${busqueda.trim()}',
      'Cliente: $cliente',
      'Asesor: $asesor',
      'Clase: $clase',
      'Almacén: $almacen',
      'Días: $diasMinimos',
      'Estado: $estado',
    ];
    return pw.Container(
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(color: grisFondo, border: pw.Border.all(color: grisLinea), borderRadius: pw.BorderRadius.circular(5)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(children: [
          pw.Text('VISTA ACTUAL', style: pw.TextStyle(color: verde, fontSize: 6, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(width: 8),
          pw.Text(vista, style: const pw.TextStyle(color: grisTexto, fontSize: 7)),
          pw.Spacer(),
          pw.Text('Registros: $total', style: pw.TextStyle(color: grisTexto, fontSize: 7, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.SizedBox(height: 3),
        pw.Text(filtros.join('  •  '), style: const pw.TextStyle(color: grisTexto, fontSize: 5.5)),
      ]),
    );
  }

  static pw.Widget _panel(String titulo, Map<String, _Grupo> grupos, int limite) {
    final lista = grupos.entries.toList()..sort((a, b) => b.value.valor.compareTo(a.value.valor));
    final visibles = lista.take(limite).toList();
    final maximo = visibles.isEmpty ? 1.0 : visibles.first.value.valor;
    return pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.all(7), decoration: pw.BoxDecoration(color: PdfColors.white, border: pw.Border.all(color: grisLinea), borderRadius: pw.BorderRadius.circular(6)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text(titulo, style: pw.TextStyle(color: verde, fontSize: 7, fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 5), ...visibles.map((e) { final p = e.value.valor / maximo; return pw.Padding(padding: const pw.EdgeInsets.only(bottom: 5), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Row(children: [pw.Expanded(child: pw.Text(e.key, maxLines: 1, overflow: pw.TextOverflow.clip, style: const pw.TextStyle(fontSize: 6))), pw.Text('US\$ ${NumberFormat('#,##0.00', 'en_US').format(e.value.valor)}', style: pw.TextStyle(fontSize: 6, color: verde, fontWeight: pw.FontWeight.bold))]), pw.SizedBox(height: 2), pw.Container(height: 4, width: 170 * p, decoration: pw.BoxDecoration(color: azul, borderRadius: pw.BorderRadius.circular(2))), pw.Text('${e.value.articulos} artículos · ${NumberFormat('#,##0.##', 'en_US').format(e.value.peso)} t', style: const pw.TextStyle(fontSize: 5, color: grisTexto))])); })])));
  }

  static pw.Widget _rangos(List<StockAntiguoAnalisisVisualPdfItem> items) {
    int a = 0, b = 0, c = 0, d = 0;
    for (final e in items) { if (e.dias > 90) a++; else if (e.dias >= 61) b++; else if (e.dias >= 31) c++; else d++; }
    final datos = [('>90', a, rojo), ('61-90', b, PdfColor.fromInt(0xFFFF5B18)), ('31-60', c, amarillo), ('30', d, verde)];
    final maximo = datos.map((e) => e.$2).fold<int>(1, (x, y) => x > y ? x : y);
    return pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.all(7), decoration: pw.BoxDecoration(color: PdfColors.white, border: pw.Border.all(color: grisLinea), borderRadius: pw.BorderRadius.circular(6)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('DISTRIBUCIÓN POR RANGO DE DÍAS', style: pw.TextStyle(color: verde, fontSize: 7, fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 5), pw.SizedBox(height: 75, child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: datos.map((e) => pw.Expanded(child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.end, children: [pw.Text('${e.$2}', style: const pw.TextStyle(fontSize: 6)), pw.SizedBox(height: 2), pw.Container(height: 55 * e.$2 / maximo, decoration: pw.BoxDecoration(color: e.$3, borderRadius: pw.BorderRadius.circular(2))), pw.SizedBox(height: 2), pw.Text(e.$1, style: const pw.TextStyle(fontSize: 5, color: grisTexto))]))).toList()))])));
  }

  static pw.Widget _tabla(List<StockAntiguoAnalisisVisualPdfItem> items, DateFormat fecha, NumberFormat moneda, NumberFormat cantidad) {
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: grisLinea, width: .4),
      headerDecoration: const pw.BoxDecoration(color: verde),
      headerStyle: pw.TextStyle(color: PdfColors.white, fontSize: 6, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 5.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      headers: const ['N°', 'Código', 'Descripción', 'Cliente', 'Asesor', 'Clase', 'Almacén', 'Ingreso', 'Días', 'Stock', 'Precio US\$', 'Valor Total', 'Peso Cobre'],
      data: items.asMap().entries.map((e) => [e.key + 1, e.value.codigo, e.value.descripcion, e.value.cliente, e.value.asesor, e.value.clase, e.value.almacen, fecha.format(e.value.fechaIngreso), e.value.dias, cantidad.format(e.value.stock), moneda.format(e.value.precio), 'US\$ ${moneda.format(e.value.valorTotal)}', '${cantidad.format(e.value.peso)} t']).toList(),
      columnWidths: const {0: pw.FixedColumnWidth(20), 1: pw.FixedColumnWidth(45), 2: pw.FixedColumnWidth(150), 3: pw.FixedColumnWidth(95), 4: pw.FixedColumnWidth(65), 5: pw.FixedColumnWidth(50), 6: pw.FixedColumnWidth(55), 7: pw.FixedColumnWidth(48), 8: pw.FixedColumnWidth(25), 9: pw.FixedColumnWidth(45), 10: pw.FixedColumnWidth(50), 11: pw.FixedColumnWidth(65), 12: pw.FixedColumnWidth(48)},
    );
  }

  static Map<String, _Grupo> _agrupar(List<StockAntiguoAnalisisVisualPdfItem> items, String Function(StockAntiguoAnalisisVisualPdfItem) key) {
    final mapa = <String, _Grupo>{};
    for (final item in items) { final nombre = key(item).trim().isEmpty ? 'SIN DATO' : key(item).trim(); final g = mapa.putIfAbsent(nombre, _Grupo.new); g.articulos++; g.valor += item.valorTotal; g.peso += item.peso; g.dias += item.dias; }
    return mapa;
  }
}

class _Grupo {
  int articulos = 0;
  double valor = 0;
  double peso = 0;
  int dias = 0;
}
