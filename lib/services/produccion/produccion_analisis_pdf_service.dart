import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ProduccionAnalisisPdfItem {
  final int posicion;
  final String nombre;
  final int op;
  final double peso;
  final double valor;
  const ProduccionAnalisisPdfItem({
    required this.posicion,
    required this.nombre,
    required this.op,
    required this.peso,
    required this.valor,
  });
}

class ProduccionAnalisisPdfService {
  static Future<void> imprimir({
    required BuildContext context,
    required String titulo,
    required List<ProduccionAnalisisPdfItem> items,
  }) async {
    if (items.isEmpty) return;
    final pdf = pw.Document();
    final f = NumberFormat('#,##0.00', 'en_US');
    final fi = NumberFormat('#,##0', 'en_US');
    final totalPeso = items.fold<double>(0, (s, e) => s + e.peso);
    final totalValor = items.fold<double>(0, (s, e) => s + e.valor);
    final totalOp = items.fold<int>(0, (s, e) => s + e.op);
    final maxPeso = items.fold<double>(0, (m, e) => e.peso > m ? e.peso : m);
    final maxValor = items.fold<double>(0, (m, e) => e.valor > m ? e.valor : m);
    final max = maxPeso > maxValor ? maxPeso : maxValor;
    final verde = PdfColor.fromInt(0xff006b3c);
    final azul = PdfColor.fromInt(0xff2457c5);
    final verdeClaro = PdfColor.fromInt(0xffe5f6ed);
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        maxPages: 100,
        margin: const pw.EdgeInsets.all(24),
        header: (_) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.only(bottom: 7),
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: verde, width: 1.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('ELCOPE', style: pw.TextStyle(color: verde, fontSize: 17, fontWeight: pw.FontWeight.bold)),
                pw.Text(titulo, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ]),
              pw.Text(
                'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 7),
              ),
            ],
          ),
        ),
        footer: (c) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('ELCOPE - Análisis de Producción', style: const pw.TextStyle(fontSize: 7)),
            pw.Text('Página ${c.pageNumber} de ${c.pagesCount}', style: const pw.TextStyle(fontSize: 7)),
          ],
        ),
        build: (_) => [
          pw.Row(children: [
            _kpi('N.º DE OP', fi.format(totalOp), verde, verdeClaro),
            pw.SizedBox(width: 8),
            _kpi('VALOR NETO', 'US\$ ${f.format(totalValor)}', azul, PdfColor.fromInt(0xffeaf0ff)),
            pw.SizedBox(width: 8),
            _kpi('PESO DE COBRE', '${f.format(totalPeso)} kg', verde, verdeClaro),
          ]),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromInt(0xffdcebe3)),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(titulo, style: pw.TextStyle(color: verde, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('Valor Neto (US\$) + Peso de cobre (kg)', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 9),
                ...([...items]..sort((a, b) => b.valor.compareTo(a.valor))).map((e) => _barRow(e, max, f, verde, azul)),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _legend(azul, 'Valor Neto (US\$)'),
            pw.SizedBox(width: 25),
            _legend(verde, 'Peso de cobre (kg)'),
          ]),
          pw.SizedBox(height: 10),
          pw.Text('DETALLE', style: pw.TextStyle(color: verde, fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColor.fromInt(0xffd7dce0), width: .5),
            headerDecoration: pw.BoxDecoration(color: verdeClaro),
            headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            headers: const ['N°', 'Nombre', 'N.º de OP', 'Valor Neto (US\$)', 'Peso de cobre (kg)'],
            data: ([...items]..sort((a, b) => b.valor.compareTo(a.valor))).map((e) => [
              '${e.posicion}', e.nombre, fi.format(e.op), 'US\$ ${f.format(e.valor)}', f.format(e.peso)
            ]).toList(),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: '$titulo.pdf',
    );
  }

  static pw.Widget _kpi(String t, String v, PdfColor c, PdfColor bg) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: bg, border: pw.Border.all(color: c, width: .7),
        borderRadius: pw.BorderRadius.circular(7),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(t, style: const pw.TextStyle(fontSize: 7)),
        pw.SizedBox(height: 3),
        pw.Text(v, style: pw.TextStyle(color: c, fontSize: 11, fontWeight: pw.FontWeight.bold)),
      ]),
    ),
  );

  static pw.Widget _barRow(
    ProduccionAnalisisPdfItem e, double max, NumberFormat f, PdfColor verde, PdfColor azul) {
    final fp = max <= 0 ? 0.0 : (e.peso / max).clamp(0.0, 1.0);
    final fv = max <= 0 ? 0.0 : (e.valor / max).clamp(0.0, 1.0);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7),
      child: pw.Row(children: [
        pw.SizedBox(width: 125, child: pw.Text(e.nombre, maxLines: 2, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(width: 6),
        pw.Expanded(child: pw.Column(children: [
          _bar(fv, azul, 'US\$ ${f.format(e.valor)}'),
          pw.SizedBox(height: 3),
          _bar(fp, verde, '${f.format(e.peso)} kg'),
        ])),
      ]),
    );
  }

  static pw.Widget _bar(double factor, PdfColor color, String text) => pw.Row(children: [
    pw.Expanded(child: pw.Container(
      height: 8,
      decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xffedf2ef), borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Align(
        alignment: pw.Alignment.centerLeft,
        child: pw.Container(
          width: 230 * factor,
          height: 8,
          decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(3)),
        ),
      ),
    )),
    pw.SizedBox(width: 6),
    pw.SizedBox(width: 75, child: pw.Text(text, textAlign: pw.TextAlign.right, style: pw.TextStyle(color: color, fontSize: 6.5, fontWeight: pw.FontWeight.bold))),
  ]);

  static pw.Widget _legend(PdfColor color, String text) => pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Container(width: 10, height: 10, decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(2))),
      pw.SizedBox(width: 5),
      pw.Text(text, style: const pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
    ],
  );
}
