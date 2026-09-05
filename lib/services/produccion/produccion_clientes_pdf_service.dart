import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../widgets/produccion/produccion_clientes_preview.dart';

class ProduccionClientesPdfService {
  static String _money(double v) =>
      'US\$ ${v.toStringAsFixed(2).replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          )}';

  static String _num(double v) =>
      v.toStringAsFixed(2).replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          );

  static Future<void> imprimir({
    required BuildContext context,
    required List<ProduccionClienteResumen> clientes,
    required String titulo,
  }) async {
    final pdf = pw.Document();

    final totalValor =
        clientes.fold<double>(0, (s, e) => s + e.valorNeto);
    final totalPeso =
        clientes.fold<double>(0, (s, e) => s + e.pesoCobre);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        maxPages: 100,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ELCOPE',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800,
                    ),
                  ),
                  pw.Text(
                    titulo,
                    style: pw.TextStyle(
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Text(
                'Fecha: ${DateTime.now().day.toString().padLeft(2, '0')}/'
                '${DateTime.now().month.toString().padLeft(2, '0')}/'
                '${DateTime.now().year}',
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Text('Clientes: ${clientes.length}'),
                pw.Text('Valor Neto Total: ${_money(totalValor)}'),
                pw.Text('Peso Cobre Total: ${_num(totalPeso)} kg'),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'DETALLE DE CLIENTES',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green800,
            ),
          ),
          pw.SizedBox(height: 7),
          pw.TableHelper.fromTextArray(
            headers: [
              'N°',
              'CLIENTE',
              'ÓRDENES',
              'VALOR NETO (US\$)',
              'PESO COBRE (kg)',
            ],
            data: List.generate(clientes.length, (i) {
              final e = clientes[i];
              return [
                '${i + 1}',
                e.cliente,
                '${e.ordenes}',
                _money(e.valorNeto),
                _num(e.pesoCobre),
              ];
            }),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
            ),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.green800),
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            border: pw.TableBorder.all(
              color: PdfColors.grey300,
              width: .5,
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
    );
  }
}
