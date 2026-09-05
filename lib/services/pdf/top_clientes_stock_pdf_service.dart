import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/dashboard/cliente_top.dart';

class TopClientesStockPdfService {
  static const verdeElcope = PdfColor.fromInt(0xFF087A45);
  static const verdeOscuro = PdfColor.fromInt(0xFF075C36);
  static const verdeSuave = PdfColor.fromInt(0xFFEAF6EF);
  static const azulAnalitico = PdfColor.fromInt(0xFF1565D8);
  static const naranja = PdfColor.fromInt(0xFFF58220);
  static const grisLinea = PdfColor.fromInt(0xFFD9E2DC);
  static const grisFondo = PdfColor.fromInt(0xFFF7FAF8);

  Future<void> imprimirReporte({
    required List<ClienteTop> clientes,
    required BuildContext context,
  }) async {
    if (clientes.isEmpty) return;

    try {
      final normal = await PdfGoogleFonts.notoSansRegular();
      final negrita = await PdfGoogleFonts.notoSansBold();

      pw.MemoryImage? logo;
      try {
        final data = await rootBundle.load('assets/images/logo_elcope.png');
        logo = pw.MemoryImage(data.buffer.asUint8List());
      } catch (_) {}

      final data = [...clientes]
        ..sort((a, b) => b.valorStock.compareTo(a.valorStock));
      final totalValor =
          data.fold<double>(0, (s, e) => s + e.valorStock);
      final totalPeso =
          data.fold<double>(0, (s, e) => s + e.pesoCobre);

      final money = NumberFormat('#,##0.00', 'en_US');
      final fecha = DateFormat('dd/MM/yyyy').format(DateTime.now());

      final pdf = pw.Document(
        title: 'Top 10 Clientes con Mayor Stock',
        author: 'ELCOPE',
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          maxPages: 100,
          margin: const pw.EdgeInsets.fromLTRB(22, 18, 22, 22),
          theme: pw.ThemeData.withFont(base: normal, bold: negrita),
          header: (_) => _header(logo, normal, negrita, fecha, data.length),
          footer: (ctx) => pw.Text(
            'ELCOPE - Top Clientes - Página ${ctx.pageNumber}',
            style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
          ),
          build: (_) => [
            _kpis(data.length, totalValor, totalPeso, money, normal, negrita),
            pw.SizedBox(height: 12),
            _verticalChart(
              data.take(10).toList(),
              money,
              normal,
              negrita,
            ),
            pw.SizedBox(height: 12),
            _tabla(
              data,
              totalValor,
              money,
              normal,
              negrita,
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      await Printing.layoutPdf(
        name: 'Reporte_Top_Clientes_Stock_ELCOPE.pdf',
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

  pw.Widget _header(
    pw.MemoryImage? logo,
    pw.Font normal,
    pw.Font bold,
    String fecha,
    int cantidad,
  ) {
    return pw.Column(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            border: pw.Border.all(color: grisLinea),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 95,
                height: 45,
                child: logo != null
                    ? pw.Image(logo, fit: pw.BoxFit.contain)
                    : pw.Text(
                        'ELCOPE',
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 18,
                          color: verdeElcope,
                        ),
                      ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TOP 10 CLIENTES CON MAYOR STOCK',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 16,
                        color: verdeOscuro,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Valor de stock (US\$) + Peso de cobre (kg)',
                      style: pw.TextStyle(
                        font: normal,
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('FECHA', style: pw.TextStyle(font: bold, fontSize: 6.5, color: PdfColors.grey600)),
                  pw.Text(fecha, style: pw.TextStyle(font: normal, fontSize: 7)),
                  pw.SizedBox(height: 3),
                  pw.Text('CLIENTES', style: pw.TextStyle(font: bold, fontSize: 6.5, color: PdfColors.grey600)),
                  pw.Text('$cantidad', style: pw.TextStyle(font: bold, fontSize: 8, color: azulAnalitico)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  pw.Widget _kpis(
    int cantidad,
    double valor,
    double peso,
    NumberFormat money,
    pw.Font normal,
    pw.Font bold,
  ) {
    return pw.Row(
      children: [
        _kpi('CLIENTES', '$cantidad', verdeElcope, bold),
        pw.SizedBox(width: 8),
        _kpi('VALOR STOCK', 'US\$ ${money.format(valor)}', azulAnalitico, bold),
        pw.SizedBox(width: 8),
        _kpi('PESO COBRE', '${money.format(peso)} kg', verdeElcope, bold),
      ],
    );
  }

  pw.Widget _kpi(String title, String value, PdfColor color, pw.Font bold) {
    return pw.Expanded(
      child: pw.Container(
        height: 45,
        padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: pw.BoxDecoration(
          color: grisFondo,
          border: pw.Border.all(color: grisLinea),
          borderRadius: pw.BorderRadius.circular(7),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 6.5, color: PdfColors.grey600)),
            pw.SizedBox(height: 2),
            pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }

  pw.Widget _verticalChart(
    List<ClienteTop> data,
    NumberFormat money,
    pw.Font normal,
    pw.Font bold,
  ) {
    final maxValor = data.isEmpty
        ? 1.0
        : data.map((e) => e.valorStock).reduce(mathMax);
    final maxPeso = data.isEmpty
        ? 1.0
        : data.map((e) => e.pesoCobre).reduce(mathMax);

    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(10, 9, 10, 7),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: grisLinea),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'GRÁFICO — TOP 10 CLIENTES',
            style: pw.TextStyle(font: bold, fontSize: 9, color: verdeOscuro),
          ),
          pw.SizedBox(height: 5),
          pw.SizedBox(
            height: 205,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < data.length; i++)
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text(
                            'US\$ ${money.format(data[i].valorStock)}',
                            maxLines: 1,
                            style: pw.TextStyle(
                              font: bold,
                              fontSize: 5.5,
                              color: azulAnalitico,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.SizedBox(
                            height: 125 * (maxValor == 0 ? 0 : data[i].valorStock / maxValor),
                            width: 13,
                            child: pw.Container(
                              decoration: pw.BoxDecoration(
                                color: azulAnalitico,
                                borderRadius: const pw.BorderRadius.vertical(
                                  top: pw.Radius.circular(3),
                                ),
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.SizedBox(
                            height: 70 * (maxPeso == 0 ? 0 : data[i].pesoCobre / maxPeso),
                            width: 13,
                            child: pw.Container(
                              decoration: pw.BoxDecoration(
                                color: verdeElcope,
                                borderRadius: const pw.BorderRadius.vertical(
                                  top: pw.Radius.circular(3),
                                ),
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            '${money.format(data[i].pesoCobre)} kg',
                            maxLines: 1,
                            style: pw.TextStyle(
                              font: bold,
                              fontSize: 5.2,
                              color: verdeElcope,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.SizedBox(
                            height: 22,
                            child: pw.Text(
                              '${i + 1}. ${data[i].cliente}',
                              textAlign: pw.TextAlign.center,
                              maxLines: 2,
                              overflow: pw.TextOverflow.clip,
                              style: pw.TextStyle(font: normal, fontSize: 5.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              _legend(azulAnalitico, 'Valor Stock (US\$)', bold),
              pw.SizedBox(width: 18),
              _legend(verdeElcope, 'Peso de cobre (kg)', bold),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _legend(PdfColor color, String text, pw.Font bold) {
    return pw.Row(
      children: [
        pw.Container(width: 7, height: 7, color: color),
        pw.SizedBox(width: 3),
        pw.Text(text, style: pw.TextStyle(font: bold, fontSize: 6.5, color: PdfColors.grey700)),
      ],
    );
  }

  pw.Widget _tabla(
    List<ClienteTop> data,
    double totalValor,
    NumberFormat money,
    pw.Font normal,
    pw.Font bold,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: grisLinea, width: .5),
      columnWidths: const {
        0: pw.FixedColumnWidth(25),
        1: pw.FlexColumnWidth(4),
        2: pw.FlexColumnWidth(1.8),
        3: pw.FlexColumnWidth(1.7),
        4: pw.FlexColumnWidth(1.1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: verdeElcope),
          children: [
            _cell('#', bold, true),
            _cell('CLIENTE', bold, true),
            _cell('VALOR STOCK', bold, true),
            _cell('PESO COBRE (kg)', bold, true),
            _cell('% VALOR', bold, true),
          ],
        ),
        for (int i = 0; i < data.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : grisFondo),
            children: [
              _cell('${i + 1}', normal, false),
              _cell(data[i].cliente, normal, false),
              _cell('US\$ ${money.format(data[i].valorStock)}', normal, false),
              _cell(money.format(data[i].pesoCobre), normal, false),
              _cell(
                totalValor == 0
                    ? '0.0 %'
                    : '${(data[i].valorStock / totalValor * 100).toStringAsFixed(1)} %',
                normal,
                false,
              ),
            ],
          ),
      ],
    );
  }

  pw.Widget _cell(String text, pw.Font font, bool header) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        maxLines: header ? 1 : 2,
        overflow: pw.TextOverflow.clip,
        style: pw.TextStyle(
          font: font,
          fontSize: header ? 6.5 : 6,
          color: header ? PdfColors.white : PdfColors.grey900,
        ),
      ),
    );
  }
}

double mathMax(double a, double b) => a > b ? a : b;
