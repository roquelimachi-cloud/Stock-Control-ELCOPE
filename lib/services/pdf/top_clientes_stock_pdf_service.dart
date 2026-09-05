import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/dashboard/cliente_top.dart';

class TopClientesStockPdfService {
  static const PdfColor verdeElcope =
      PdfColor.fromInt(0xFF087A45);
  static const PdfColor verdeOscuro =
      PdfColor.fromInt(0xFF075C36);
  static const PdfColor verdeSuave =
      PdfColor.fromInt(0xFFEAF6EF);
  static const PdfColor azulAnalitico =
      PdfColor.fromInt(0xFF1565D8);
  static const PdfColor naranja =
      PdfColor.fromInt(0xFFF58220);
  static const PdfColor grisLinea =
      PdfColor.fromInt(0xFFD9E2DC);
  static const PdfColor grisFondo =
      PdfColor.fromInt(0xFFF7FAF8);

  Future<void> imprimirReporte({
    required List<ClienteTop> clientes,
    required BuildContext context,
  }) async {
    if (clientes.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No existen clientes para generar el reporte.'),
        ),
      );
      return;
    }

    try {
      final fuenteNormal = await PdfGoogleFonts.notoSansRegular();
      final fuenteNegrita = await PdfGoogleFonts.notoSansBold();

      pw.MemoryImage? logo;
      try {
        final ByteData data =
            await rootBundle.load('assets/images/logo_elcope.png');
        logo = pw.MemoryImage(data.buffer.asUint8List());
      } catch (_) {
        logo = null;
      }

      final data = [...clientes]
        ..sort((a, b) => b.valorStock.compareTo(a.valorStock));

      final totalValor = data.fold<double>(
        0,
        (suma, item) => suma + item.valorStock,
      );
      final totalPeso = data.fold<double>(
        0,
        (suma, item) => suma + item.pesoCobre,
      );

      final moneda = NumberFormat('#,##0.00', 'en_US');
      final peso = NumberFormat('#,##0.00', 'en_US');
      final fecha = DateFormat('dd/MM/yyyy').format(DateTime.now());
      final hora = DateFormat('HH:mm').format(DateTime.now());

      final pdf = pw.Document(
        title: 'Reporte Top Clientes - Stock',
        author: 'ELCOPE',
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          maxPages: 100,
          margin: const pw.EdgeInsets.fromLTRB(24, 20, 24, 25),
          theme: pw.ThemeData.withFont(
            base: fuenteNormal,
            bold: fuenteNegrita,
          ),
          header: (pw.Context pageContext) {
            return pw.Column(
              children: [
                pw.SizedBox(
                  height: 62,
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.SizedBox(
                        width: 145,
                        height: 58,
                        child: logo != null
                            ? pw.Image(
                                logo,
                                fit: pw.BoxFit.contain,
                              )
                            : pw.Text(
                                'ELCOPE',
                                style: pw.TextStyle(
                                  font: fuenteNegrita,
                                  fontSize: 23,
                                  color: verdeElcope,
                                ),
                              ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          mainAxisAlignment:
                              pw.MainAxisAlignment.center,
                          children: [
                            pw.Text(
                              'REPORTE DE STOCK',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                font: fuenteNegrita,
                                fontSize: 20,
                                color: verdeOscuro,
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              'TOP CLIENTES',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                font: fuenteNormal,
                                fontSize: 11,
                                color: verdeElcope,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(
                        width: 135,
                        child: pw.Column(
                          crossAxisAlignment:
                              pw.CrossAxisAlignment.start,
                          mainAxisAlignment:
                              pw.MainAxisAlignment.center,
                          children: [
                            _dato('Fecha:', fecha, fuenteNormal, fuenteNegrita),
                            pw.SizedBox(height: 4),
                            _dato('Hora:', hora, fuenteNormal, fuenteNegrita),
                            pw.SizedBox(height: 4),
                            _dato(
                              'Clientes:',
                              '${data.length}',
                              fuenteNormal,
                              fuenteNegrita,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Row(
                  children: [
                    pw.Container(
                      width: 50,
                      height: 4,
                      color: naranja,
                    ),
                    pw.Expanded(
                      child: pw.Container(
                        height: 4,
                        color: verdeElcope,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
              ],
            );
          },
          footer: (pw.Context pageContext) {
            return pw.Container(
              padding: const pw.EdgeInsets.only(top: 7),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(
                    color: grisLinea,
                    width: .5,
                  ),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'ELCOPE - Reporte de Stock - Top Clientes',
                    style: pw.TextStyle(
                      font: fuenteNormal,
                      fontSize: 6.5,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Página ${pageContext.pageNumber}',
                    style: pw.TextStyle(
                      font: fuenteNormal,
                      fontSize: 6.5,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            );
          },
          build: (pw.Context pageContext) {
            return [
              _indicadores(
                cantidad: data.length,
                totalValor: totalValor,
                totalPeso: totalPeso,
                moneda: moneda,
                peso: peso,
                fuenteNormal: fuenteNormal,
                fuenteNegrita: fuenteNegrita,
              ),
              pw.SizedBox(height: 14),
              pw.Text(
                'DETALLE DE CLIENTES',
                style: pw.TextStyle(
                  font: fuenteNegrita,
                  fontSize: 11,
                  color: verdeOscuro,
                ),
              ),
              pw.SizedBox(height: 6),
              _tabla(
                clientes: data,
                totalValor: totalValor,
                moneda: moneda,
                peso: peso,
                fuenteNormal: fuenteNormal,
                fuenteNegrita: fuenteNegrita,
              ),
              pw.SizedBox(height: 14),
              _ranking(
                clientes: data,
                totalValor: totalValor,
                moneda: moneda,
                fuenteNormal: fuenteNormal,
                fuenteNegrita: fuenteNegrita,
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();

      await Printing.layoutPdf(
        name: 'Reporte_Top_Clientes_Stock_ELCOPE.pdf',
        onLayout: (PdfPageFormat format) async => bytes,
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

  pw.Widget _dato(
    String titulo,
    String valor,
    pw.Font normal,
    pw.Font negrita,
  ) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$titulo ',
            style: pw.TextStyle(
              font: negrita,
              fontSize: 7.5,
              color: PdfColors.grey700,
            ),
          ),
          pw.TextSpan(
            text: valor,
            style: pw.TextStyle(
              font: normal,
              fontSize: 7.5,
              color: PdfColors.grey800,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _indicadores({
    required int cantidad,
    required double totalValor,
    required double totalPeso,
    required NumberFormat moneda,
    required NumberFormat peso,
    required pw.Font fuenteNormal,
    required pw.Font fuenteNegrita,
  }) {
    return pw.Row(
      children: [
        _indicador(
          'CLIENTES',
          '$cantidad',
          verdeElcope,
          fuenteNormal,
          fuenteNegrita,
        ),
        pw.SizedBox(width: 8),
        _indicador(
          'VALOR TOTAL',
          'US\$ ${moneda.format(totalValor)}',
          azulAnalitico,
          fuenteNormal,
          fuenteNegrita,
        ),
        pw.SizedBox(width: 8),
        _indicador(
          'PESO COBRE',
          '${peso.format(totalPeso / 1000)} t',
          naranja,
          fuenteNormal,
          fuenteNegrita,
        ),
      ],
    );
  }

  pw.Widget _indicador(
    String titulo,
    String valor,
    PdfColor color,
    pw.Font normal,
    pw.Font negrita,
  ) {
    return pw.Expanded(
      child: pw.Container(
        height: 50,
        padding: const pw.EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 7,
        ),
        decoration: pw.BoxDecoration(
          color: grisFondo,
          border: pw.Border.all(
            color: grisLinea,
            width: .7,
          ),
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
                fontSize: 7,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              valor,
              style: pw.TextStyle(
                font: negrita,
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _tabla({
    required List<ClienteTop> clientes,
    required double totalValor,
    required NumberFormat moneda,
    required NumberFormat peso,
    required pw.Font fuenteNormal,
    required pw.Font fuenteNegrita,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(
        color: grisLinea,
        width: .5,
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(28),
        1: pw.FlexColumnWidth(4),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(1.5),
        4: pw.FlexColumnWidth(1.4),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: verdeElcope,
          ),
          children: [
            _celda('#', fuenteNegrita, true),
            _celda('CLIENTE', fuenteNegrita, true),
            _celda('VALOR STOCK', fuenteNegrita, true),
            _celda('PESO COBRE', fuenteNegrita, true),
            _celda('% VALOR', fuenteNegrita, true),
          ],
        ),
        for (int i = 0; i < clientes.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isEven ? PdfColors.white : grisFondo,
            ),
            children: [
              _celda('${i + 1}', fuenteNormal, false),
              _celda(clientes[i].cliente, fuenteNormal, false),
              _celda(
                'US\$ ${moneda.format(clientes[i].valorStock)}',
                fuenteNormal,
                false,
              ),
              _celda(
                '${peso.format(clientes[i].pesoCobre / 1000)} t',
                fuenteNormal,
                false,
              ),
              _celda(
                totalValor == 0
                    ? '0.0 %'
                    : '${(clientes[i].valorStock / totalValor * 100).toStringAsFixed(1)} %',
                fuenteNormal,
                false,
              ),
            ],
          ),
      ],
    );
  }

  pw.Widget _celda(
    String texto,
    pw.Font fuente,
    bool encabezado,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 5,
        vertical: 4,
      ),
      child: pw.Text(
        texto,
        maxLines: encabezado ? 1 : 2,
        overflow: pw.TextOverflow.clip,
        style: pw.TextStyle(
          font: fuente,
          fontSize: encabezado ? 7 : 6.5,
          color: encabezado ? PdfColors.white : PdfColors.grey900,
        ),
      ),
    );
  }

  pw.Widget _ranking({
    required List<ClienteTop> clientes,
    required double totalValor,
    required NumberFormat moneda,
    required pw.Font fuenteNormal,
    required pw.Font fuenteNegrita,
  }) {
    final top = clientes.length > 10 ? clientes.take(10).toList() : clientes;
    final maximo = top.isEmpty ? 0.0 : top.first.valorStock;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: verdeSuave,
        borderRadius: pw.BorderRadius.circular(7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RANKING TOP 10',
            style: pw.TextStyle(
              font: fuenteNegrita,
              fontSize: 9,
              color: verdeOscuro,
            ),
          ),
          pw.SizedBox(height: 7),
          for (int i = 0; i < top.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                children: [
                  pw.SizedBox(
                    width: 18,
                    child: pw.Text(
                      '${i + 1}',
                      style: pw.TextStyle(
                        font: fuenteNegrita,
                        fontSize: 7,
                        color: azulAnalitico,
                      ),
                    ),
                  ),
                  pw.SizedBox(
                    width: 210,
                    child: pw.Text(
                      top[i].cliente,
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                      style: pw.TextStyle(
                        font: fuenteNormal,
                        fontSize: 6.5,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Container(
                      height: 5,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey300,
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                      child: pw.Align(
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Container(
                          width: maximo == 0
                              ? 0
                              : 100 * top[i].valorStock / maximo,
                          height: 5,
                          decoration: pw.BoxDecoration(
                            color: azulAnalitico,
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.SizedBox(
                    width: 90,
                    child: pw.Text(
                      'US\$ ${moneda.format(top[i].valorStock)}',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        font: fuenteNegrita,
                        fontSize: 6.5,
                        color: verdeElcope,
                      ),
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
