import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfDashboardService {

  Future<void> generar({
    required Uint8List dashboard,
  }) async {

    final pdf = pw.Document();

    final imagen = pw.MemoryImage(dashboard);

    pdf.addPage(

      pw.Page(

        pageFormat: PdfPageFormat.a4.landscape,

        margin: const pw.EdgeInsets.all(15),

        build: (context) {

          return pw.Center(

            child: pw.Image(
              imagen,
              fit: pw.BoxFit.contain,
            ),

          );

        },

      ),

    );

    await Printing.layoutPdf(

      onLayout: (format) async {

        return pdf.save();

      },

    );

  }

}