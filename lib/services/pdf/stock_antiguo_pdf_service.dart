import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../services/pdf/stock_antiguo_pdf_service.dart';
class StockAntiguoPdfItem {
  final String codigo;
  final String descripcion;
  final String cliente;
  final DateTime fechaIngreso;
  final int dias;
  final double stock;
  final double precio;
  final double valorTotal;
  final double peso;

  const StockAntiguoPdfItem({
    required this.codigo,
    required this.descripcion,
    required this.cliente,
    required this.fechaIngreso,
    required this.dias,
    required this.stock,
    required this.precio,
    required this.valorTotal,
    required this.peso,
  });
}

class StockAntiguoPdfService {
  static const PdfColor verde = PdfColor.fromInt(0xFF08783B);
  static const PdfColor verdeOscuro = PdfColor.fromInt(0xFF075C36);
  static const PdfColor verdeSuave = PdfColor.fromInt(0xFFEAF5EE);
  static const PdfColor azul = PdfColor.fromInt(0xFF1565D8);
  static const PdfColor naranja = PdfColor.fromInt(0xFFF59E0B);
  static const PdfColor rojo = PdfColor.fromInt(0xFFEF4444);
  static const PdfColor amarillo = PdfColor.fromInt(0xFFF4C430);
  static const PdfColor grisLinea = PdfColor.fromInt(0xFFDCE4DF);
  static const PdfColor grisFondo = PdfColor.fromInt(0xFFF7F9FA);

  static Future<void> imprimir({
    required BuildContext context,
    required List<StockAntiguoPdfItem> items,
  }) async {
    if (items.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No existen artículos para imprimir.'),
        ),
      );
      return;
    }

    try {
      final normal = await PdfGoogleFonts.notoSansRegular();
      final negrita = await PdfGoogleFonts.notoSansBold();

      pw.MemoryImage? logo;
      try {
        final ByteData data =
            await rootBundle.load('assets/images/logo_elcope.png');
        logo = pw.MemoryImage(data.buffer.asUint8List());
      } catch (_) {
        logo = null;
      }

      final data = [...items]
        ..sort((a, b) => b.dias.compareTo(a.dias));

      final totalValor =
          data.fold<double>(0, (suma, item) => suma + item.valorTotal);
      final totalPeso =
          data.fold<double>(0, (suma, item) => suma + item.peso);
      final promedioDias = data.isEmpty
          ? 0.0
          : data.fold<int>(0, (suma, item) => suma + item.dias) /
              data.length;

      final moneda = NumberFormat('#,##0.00', 'en_US');
      final cantidad = NumberFormat('#,##0.##', 'en_US');
      final fecha = DateFormat('dd/MM/yyyy');
      final fechaHora =
          DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      final pdf = pw.Document(
        title: 'Stock Antiguo - ELCOPE',
        author: 'ELCOPE',
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          maxPages: 100,
          margin: const pw.EdgeInsets.fromLTRB(22, 18, 22, 24),
          theme: pw.ThemeData.withFont(
            base: normal,
            bold: negrita,
          ),
          header: (_) => _header(
            logo: logo,
            normal: normal,
            negrita: negrita,
            fechaHora: fechaHora,
          ),
          footer: (ctx) => pw.Container(
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: grisLinea, width: .5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'ELCOPE - Reporte de Stock Antiguo',
                  style: pw.TextStyle(
                    font: normal,
                    fontSize: 6.5,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Text(
                  'Página ${ctx.pageNumber}',
                  style: pw.TextStyle(
                    font: normal,
                    fontSize: 6.5,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
          build: (_) => [
            _kpis(
              cantidad: data.length,
              valor: totalValor,
              peso: totalPeso,
              promedio: promedioDias,
              moneda: moneda,
              normal: normal,
              negrita: negrita,
            ),
            pw.SizedBox(height: 12),
            _sectionTitle(
              'ARTÍCULOS CON MÁS DE 30 DÍAS',
              normal,
              negrita,
            ),
            pw.SizedBox(height: 6),
            _table(
              items: data,
              fecha: fecha,
              cantidad: cantidad,
              moneda: moneda,
              normal: normal,
              negrita: negrita,
            ),
            pw.SizedBox(height: 12),
            _rangos(
              items: data,
              normal: normal,
              negrita: negrita,
            ),
          ],
        ),
      );

      final bytes = await pdf.save();

      await Printing.layoutPdf(
        name: 'Stock_Antiguo_ELCOPE.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Error al generar el PDF: $e'),
        ),
      );
    }
  }

  static pw.Widget _header({
    required pw.MemoryImage? logo,
    required pw.Font normal,
    required pw.Font negrita,
    required String fechaHora,
  }) {
    return pw.Column(
      children: [
        pw.SizedBox(
          height: 55,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(
                width: 145,
                height: 50,
                child: logo != null
                    ? pw.Image(logo, fit: pw.BoxFit.contain)
                    : pw.Text(
                        'ELCOPE',
                        style: pw.TextStyle(
                          font: negrita,
                          fontSize: 23,
                          color: verde,
                        ),
                      ),
              ),
              pw.Expanded(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      'REPORTE DE STOCK',
                      style: pw.TextStyle(
                        font: negrita,
                        fontSize: 18,
                        color: verdeOscuro,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'STOCK ANTIGUO (> 30 DÍAS)',
                      style: pw.TextStyle(
                        font: normal,
                        fontSize: 10,
                        color: verde,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(
                width: 150,
                child: pw.Text(
                  fechaHora,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    font: normal,
                    fontSize: 7.5,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.Row(
          children: [
            pw.Container(width: 45, height: 4, color: naranja),
            pw.Expanded(
              child: pw.Container(height: 4, color: verde),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _kpis({
    required int cantidad,
    required double valor,
    required double peso,
    required double promedio,
    required NumberFormat moneda,
    required pw.Font normal,
    required pw.Font negrita,
  }) {
    return pw.Row(
      children: [
        _kpi(
          'ARTÍCULOS',
          '$cantidad',
          'con más de 30 días',
          verde,
          normal,
          negrita,
        ),
        pw.SizedBox(width: 8),
        _kpi(
          'VALOR TOTAL',
          'US\$ ${moneda.format(valor)}',
          'en stock antiguo',
          azul,
          normal,
          negrita,
        ),
        pw.SizedBox(width: 8),
        _kpi(
          'PESO COBRE',
          '${moneda.format(peso)} t',
          'en stock antiguo',
          naranja,
          normal,
          negrita,
        ),
        pw.SizedBox(width: 8),
        _kpi(
          'DÍAS PROMEDIO',
          '${promedio.round()} días',
          'de permanencia',
          azul,
          normal,
          negrita,
        ),
      ],
    );
  }

  static pw.Widget _kpi(
    String titulo,
    String valor,
    String subtitulo,
    PdfColor color,
    pw.Font normal,
    pw.Font negrita,
  ) {
    return pw.Expanded(
      child: pw.Container(
        height: 49,
        padding: const pw.EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 6,
        ),
        decoration: pw.BoxDecoration(
          color: grisFondo,
          border: pw.Border.all(color: grisLinea, width: .7),
          borderRadius: pw.BorderRadius.circular(7),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              titulo,
              style: pw.TextStyle(
                font: negrita,
                fontSize: 6.5,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              valor,
              style: pw.TextStyle(
                font: negrita,
                fontSize: 11,
                color: color,
              ),
            ),
            pw.Text(
              subtitulo,
              style: pw.TextStyle(
                font: normal,
                fontSize: 6,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _sectionTitle(
    String titulo,
    pw.Font normal,
    pw.Font negrita,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      color: verdeSuave,
      child: pw.Row(
        children: [
          pw.Text(
            titulo,
            style: pw.TextStyle(
              font: negrita,
              fontSize: 9,
              color: verdeOscuro,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _table({
    required List<StockAntiguoPdfItem> items,
    required DateFormat fecha,
    required NumberFormat cantidad,
    required NumberFormat moneda,
    required pw.Font normal,
    required pw.Font negrita,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(
        color: grisLinea,
        width: .5,
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(25),
        1: pw.FixedColumnWidth(58),
        2: pw.FlexColumnWidth(2.2),
        3: pw.FlexColumnWidth(2.4),
        4: pw.FixedColumnWidth(65),
        5: pw.FixedColumnWidth(38),
        6: pw.FixedColumnWidth(55),
        7: pw.FixedColumnWidth(55),
        8: pw.FixedColumnWidth(72),
        9: pw.FixedColumnWidth(58),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: verde),
          children: [
            _cell('N°', negrita, true),
            _cell('Código', negrita, true),
            _cell('Descripción', negrita, true),
            _cell('Cliente', negrita, true),
            _cell('Fecha ingreso', negrita, true),
            _cell('Días', negrita, true),
            _cell('Stock', negrita, true),
            _cell('Precio US\$', negrita, true),
            _cell('Valor Total', negrita, true),
            _cell('Peso Cobre', negrita, true),
          ],
        ),
        for (int i = 0; i < items.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isEven ? PdfColors.white : grisFondo,
            ),
            children: [
              _cell('${i + 1}', normal, false),
              _cell(items[i].codigo, normal, false),
              _cell(items[i].descripcion, normal, false),
              _cell(items[i].cliente, normal, false),
              _cell(fecha.format(items[i].fechaIngreso), normal, false),
              _diasCell(items[i].dias, normal, negrita),
              _cell(cantidad.format(items[i].stock), normal, false),
              _cell(moneda.format(items[i].precio), normal, false),
              _cell(
                'US\$ ${moneda.format(items[i].valorTotal)}',
                normal,
                false,
              ),
              _cell(
                '${moneda.format(items[i].peso)} t',
                normal,
                false,
              ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _cell(
    String texto,
    pw.Font font,
    bool header,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 3.5,
      ),
      child: pw.Text(
        texto,
        maxLines: header ? 1 : 2,
        style: pw.TextStyle(
          font: font,
          fontSize: header ? 6.2 : 5.8,
          color: header ? PdfColors.white : PdfColors.grey900,
        ),
      ),
    );
  }

  static pw.Widget _diasCell(
    int dias,
    pw.Font normal,
    pw.Font negrita,
  ) {
    final color = dias > 90
        ? rojo
        : dias >= 61
            ? PdfColor.fromInt(0xFFE85D04)
            : dias >= 31
                ? amarillo
                : verde;

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 3,
      ),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 2,
        ),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Text(
          '$dias',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            font: negrita,
            fontSize: 6,
            color: PdfColors.white,
          ),
        ),
      ),
    );
  }

  static pw.Widget _rangos({
    required List<StockAntiguoPdfItem> items,
    required pw.Font normal,
    required pw.Font negrita,
  }) {
    final rangos = <String, int>{
      '> 90 días': items.where((e) => e.dias > 90).length,
      '61 - 90 días':
          items.where((e) => e.dias >= 61 && e.dias <= 90).length,
      '31 - 60 días':
          items.where((e) => e.dias >= 31 && e.dias <= 60).length,
      '30 días': items.where((e) => e.dias == 30).length,
    };

    return pw.Container(
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: grisFondo,
        border: pw.Border.all(color: grisLinea, width: .7),
        borderRadius: pw.BorderRadius.circular(7),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            'DISTRIBUCIÓN POR RANGO DE DÍAS',
            style: pw.TextStyle(
              font: negrita,
              fontSize: 8,
              color: verdeOscuro,
            ),
          ),
          pw.SizedBox(width: 15),
          for (final entry in rangos.entries)
            pw.Expanded(
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 7,
                    height: 7,
                    color: entry.key == '> 90 días'
                        ? rojo
                        : entry.key == '61 - 90 días'
                            ? PdfColor.fromInt(0xFFE85D04)
                            : entry.key == '31 - 60 días'
                                ? amarillo
                                : verde,
                  ),
                  pw.SizedBox(width: 4),
                  pw.Text(
                    '${entry.key}: ${entry.value}',
                    style: pw.TextStyle(
                      font: normal,
                      fontSize: 6.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
