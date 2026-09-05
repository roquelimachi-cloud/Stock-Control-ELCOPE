import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../widgets/produccion/produccion_productos_preview.dart';

class ProduccionProductosPdfService {
  static const _verde = PdfColor.fromInt(0xff00864a);
  static const _verdeClaro = PdfColor.fromInt(0xffe5f6ed);
  static const _borde = PdfColor.fromInt(0xffdcebe3);
  static const _gris = PdfColor.fromInt(0xff6b7280);

  static final _money = NumberFormat('#,##0.00', 'en_US');
  static final _number = NumberFormat('#,##0.00', 'en_US');

  static Future<void> imprimir({
    required BuildContext context,
    required List<ProduccionProductoResumen> productos,
    required String titulo,
  }) async {
    final doc = pw.Document();

    final valorTotal =
        productos.fold<double>(0, (s, e) => s + e.valorNeto);
    final pesoTotal =
        productos.fold<double>(0, (s, e) => s + e.pesoCobre);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(22),
        maxPages: 100,
        header: (_) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            border: pw.Border.all(color: _borde),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: _verdeClaro,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'ELCOPE',
                  style: pw.TextStyle(
                    color: _verde,
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      titulo,
                      style: pw.TextStyle(
                        color: _verde,
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Detalle completo de productos de producción.',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: _gris,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Text(
                DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                style: const pw.TextStyle(fontSize: 7, color: _gris),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'ELCOPE • Producción por Producto',
              style: const pw.TextStyle(fontSize: 7, color: _gris),
            ),
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: _gris),
            ),
          ],
        ),
        build: (_) => [
          pw.Row(
            children: [
              _kpi('PRODUCTOS', '${productos.length}'),
              _kpi('PESO COBRE', '${_number.format(pesoTotal)} kg'),
              _kpi('VALOR NETO', 'US\$ ${_money.format(valorTotal)}'),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: _borde, width: .5),
            headerDecoration: const pw.BoxDecoration(
              color: _verdeClaro,
            ),
            headerStyle: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: _verde,
            ),
            cellStyle: const pw.TextStyle(fontSize: 6.5),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 5,
            ),
            headers: const [
              'N°',
              'PRODUCTO / ARTÍCULO',
              'ÓRDENES',
              'PESO COBRE (kg)',
              'VALOR NETO (US\$)',
            ],
            data: List.generate(productos.length, (i) {
              final e = productos[i];
              return [
                '${i + 1}',
                e.producto,
                '${e.ordenes}',
                _number.format(e.pesoCobre),
                'US\$ ${_money.format(e.valorNeto)}',
              ];
            }),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'produccion_por_producto.pdf',
    );
  }

  static pw.Widget _kpi(String titulo, String valor) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 7),
        padding: const pw.EdgeInsets.all(9),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: _borde),
          borderRadius: pw.BorderRadius.circular(7),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              titulo,
              style: const pw.TextStyle(fontSize: 6.5, color: _gris),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              valor,
              style: pw.TextStyle(
                fontSize: 11,
                color: _verde,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
