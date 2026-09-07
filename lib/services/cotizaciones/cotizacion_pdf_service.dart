import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Servicio PDF de Cotizaciones.
/// La pantalla actual usa su propio preview para mantener la implementación
/// autocontenida; este servicio queda preparado para reutilizar el PDF desde
/// otras pantallas en una siguiente etapa.
class CotizacionPdfService {
  CotizacionPdfService._();

  static Future<void> imprimir({
    required String nombreArchivo,
    required Uint8List bytes,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: nombreArchivo,
    );
  }

  static Future<Uint8List> documentoVacio() async {
    pw.MemoryImage? logo;
    try {
      final data = await rootBundle.load('assets/images/logo_elcope.png');
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {}

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Column(
          children: [
            if (logo != null) pw.Image(logo, width: 100),
            pw.SizedBox(height: 20),
            pw.Text(
              'Cotización ELCOPE',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
    return pdf.save();
  }
}
