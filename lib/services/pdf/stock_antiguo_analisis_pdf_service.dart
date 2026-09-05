import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class StockAntiguoAnalisisPdfItem {
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

  const StockAntiguoAnalisisPdfItem({
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

class StockAntiguoAnalisisPdfService {
  static const verde = PdfColor.fromInt(0xFF08783B);
  static const azul = PdfColor.fromInt(0xFF1565D8);
  static const verdeSuave = PdfColor.fromInt(0xFFEAF5EE);
  static const grisFondo = PdfColor.fromInt(0xFFF7F9FA);
  static const grisLinea = PdfColor.fromInt(0xFFDCE4DF);
  static const grisTexto = PdfColor.fromInt(0xFF455A64);
  static const rojo = PdfColor.fromInt(0xFFEF4444);
  static const naranja = PdfColor.fromInt(0xFFF59E0B);

  static Future<void> imprimir({
    required BuildContext context,
    required List<StockAntiguoAnalisisPdfItem> items,
  }) async {
    if (items.isEmpty) return;

    final data = [...items]..sort((a, b) => b.dias.compareTo(a.dias));
    final moneda = NumberFormat('#,##0.00', 'en_US');
    final cantidad = NumberFormat('#,##0.##', 'en_US');
    final fecha = DateFormat('dd/MM/yyyy');
    final ahora = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final totalValor = data.fold<double>(0, (s, e) => s + e.valorTotal);
    final totalPeso = data.fold<double>(0, (s, e) => s + e.peso);
    final promedio = data.fold<int>(0, (s, e) => s + e.dias) / data.length;

    final pdf = pw.Document(title: 'Análisis Stock Antiguo - ELCOPE');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        maxPages: 100,
        margin: const pw.EdgeInsets.fromLTRB(20, 18, 20, 24),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ELCOPE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: verde)),
                    pw.SizedBox(height: 2),
                    pw.Text('ANÁLISIS GERENCIAL — STOCK ANTIGUO', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Stock con permanencia desde 30 días', style: const pw.TextStyle(fontSize: 8, color: grisTexto)),
                  ],
                ),
                pw.Text(ahora, style: const pw.TextStyle(fontSize: 8, color: grisTexto)),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Container(height: 2, color: verde),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Reporte generado desde Stock Antiguo', style: const pw.TextStyle(fontSize: 7, color: grisTexto)),
            pw.Text('Página ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: grisTexto)),
          ],
        ),
        build: (_) => [
          pw.Row(
            children: [
              _kpi('ARTÍCULOS', data.length.toString(), verde),
              pw.SizedBox(width: 8),
              _kpi('VALOR TOTAL', 'US\$ ${moneda.format(totalValor)}', azul),
              pw.SizedBox(width: 8),
              _kpi('PESO COBRE', '${moneda.format(totalPeso)} t', naranja),
              pw.SizedBox(width: 8),
              _kpi('PROMEDIO', '${promedio.round()} días', verde),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text('DETALLE DEL STOCK ANTIGUO', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: verde)),
          pw.SizedBox(height: 5),
          pw.TableHelper.fromTextArray(
            headers: const ['N°', 'Código', 'Descripción', 'Cliente', 'Asesor', 'Clase', 'Almacén', 'Ingreso', 'Días', 'Stock', 'Precio US\$', 'Valor Total', 'Peso'],
            data: [
              for (var i = 0; i < data.length; i++)
                [
                  '${i + 1}',
                  data[i].codigo,
                  data[i].descripcion,
                  data[i].cliente,
                  data[i].asesor,
                  data[i].clase,
                  data[i].almacen,
                  fecha.format(data[i].fechaIngreso),
                  '${data[i].dias}',
                  cantidad.format(data[i].stock),
                  moneda.format(data[i].precio),
                  moneda.format(data[i].valorTotal),
                  moneda.format(data[i].peso),
                ],
            ],
            headerStyle: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: verde),
            cellStyle: const pw.TextStyle(fontSize: 6.2),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            border: pw.TableBorder.all(color: grisLinea, width: .4),
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: const pw.BoxDecoration(color: grisFondo),
            columnWidths: {
              0: const pw.FixedColumnWidth(20),
              1: const pw.FixedColumnWidth(45),
              2: const pw.FlexColumnWidth(2.7),
              3: const pw.FlexColumnWidth(1.8),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(1.1),
              6: const pw.FlexColumnWidth(1.0),
              7: const pw.FixedColumnWidth(48),
              8: const pw.FixedColumnWidth(28),
              9: const pw.FixedColumnWidth(42),
              10: const pw.FixedColumnWidth(48),
              11: const pw.FixedColumnWidth(55),
              12: const pw.FixedColumnWidth(42),
            },
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: const pw.BoxDecoration(color: verdeSuave),
            child: pw.Text(
              'Criterio: se consideran artículos con 30 días o más desde la fecha de ingreso. El orden principal del reporte es por mayor permanencia.',
              style: const pw.TextStyle(fontSize: 7.5, color: grisTexto),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'stock_antiguo_analisis_gerencial.pdf',
    );
  }

  static pw.Widget _kpi(String titulo, String valor, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: grisLinea),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(titulo, style: const pw.TextStyle(fontSize: 6.5, color: grisTexto)),
            pw.SizedBox(height: 3),
            pw.Text(valor, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
