import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/dashboard/producto_cliente.dart';

class ClientePdfService {
  // =========================================================
  // COLORES CORPORATIVOS ELCOPE
  // =========================================================

  static const PdfColor verdeOscuro =
      PdfColor.fromInt(0xff006B32);

  static const PdfColor verde =
      PdfColor.fromInt(0xff00843D);

  static const PdfColor verdeClaro =
      PdfColor.fromInt(0xffEAF6EF);

  static const PdfColor verdeSuave =
      PdfColor.fromInt(0xffF4FAF6);

  static const PdfColor verdeLima =
      PdfColor.fromInt(0xff8CC63F);

  static const PdfColor gris =
      PdfColor.fromInt(0xff666666);

  static const PdfColor grisClaro =
      PdfColor.fromInt(0xffE5E7EB);

  // =========================================================
  // GENERAR REPORTE
  // =========================================================

  static Future<void> imprimirReporteStock({
    required BuildContext context,
    required String cliente,
    required List<ProductoCliente> productos,
  }) async {
    try {
      // =======================================================
      // VALIDAR
      // =======================================================

      if (productos.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'El cliente no tiene productos para generar el reporte.',
              ),
            ),
          );
        }

        return;
      }

      // =======================================================
      // FECHA
      // =======================================================

      final fechaReporte =
          DateFormat('dd/MM/yyyy').format(DateTime.now());

      // =======================================================
      // TOTALES
      // =======================================================

      double totalCantidad = 0;
      double totalPeso = 0;

      for (final producto in productos) {
        totalCantidad += producto.stock;
        totalPeso += producto.peso;
      }

      // =======================================================
      // LOGO ELCOPE
      // =======================================================

      pw.MemoryImage? logo;

      try {
        final logoData =
            await rootBundle.load(
          'assets/images/logo_elcope.png',
        );

        logo = pw.MemoryImage(
          logoData.buffer.asUint8List(),
        );
      } catch (_) {
        logo = null;
      }

      // =======================================================
      // DOCUMENTO
      // =======================================================

      final pdf = pw.Document();

      // =======================================================
      // FORMATEADORES
      // =======================================================

      final cantidadFormat =
          NumberFormat('#,##0.##', 'en_US');

      final pesoFormat =
          NumberFormat('#,##0.00', 'en_US');

      // =======================================================
      // PDF
      // =======================================================

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,

          margin: const pw.EdgeInsets.fromLTRB(
            28,
            28,
            28,
            38,
          ),

          // ===================================================
          // ENCABEZADO
          // ===================================================

          header: (context) {
            return pw.Column(
              children: [

                // -----------------------------------------------
                // FRANJA SUPERIOR
                // -----------------------------------------------

                pw.Container(
                  height: 7,
                  width: double.infinity,
                  color: verdeOscuro,
                ),

                pw.Container(
                  height: 4,
                  width: double.infinity,
                  color: verdeLima,
                ),

                pw.SizedBox(height: 16),

                // -----------------------------------------------
                // CABECERA
                // -----------------------------------------------

                pw.Row(
                  crossAxisAlignment:
                      pw.CrossAxisAlignment.start,

                  children: [

                    // -------------------------------------------
                    // INFORMACIÓN
                    // -------------------------------------------

                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment:
                            pw.CrossAxisAlignment.start,
                        children: [

                          pw.Text(
                            'REPORTE DE STOCK',
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight:
                                  pw.FontWeight.bold,
                              color: verdeOscuro,
                            ),
                          ),

                          pw.SizedBox(height: 7),

                          pw.Text(
                            cliente,
                            style: pw.TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                          ),

                          pw.SizedBox(height: 5),

                          pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                const pw.TextSpan(
                                  text:
                                      'Fecha del reporte: ',
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    color: gris,
                                  ),
                                ),
                                pw.TextSpan(
                                  text: fechaReporte,
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    color: verdeOscuro,
                                    fontWeight:
                                        pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // -------------------------------------------
                    // LOGO
                    // -------------------------------------------

                    if (logo != null)
                      pw.Container(
                        width: 170,
                        height: 75,
                        alignment:
                            pw.Alignment.topRight,
                        child: pw.Image(
                          logo,
                          fit: pw.BoxFit.contain,
                        ),
                      ),
                  ],
                ),

                pw.SizedBox(height: 12),

                // -----------------------------------------------
                // LÍNEA VERDE
                // -----------------------------------------------

                pw.Container(
                  height: 2,
                  width: double.infinity,
                  color: verdeOscuro,
                ),

                pw.SizedBox(height: 12),
              ],
            );
          },

          // ===================================================
          // PIE DE PÁGINA
          // ===================================================

          footer: (context) {
            return pw.Column(
              children: [

                pw.Container(
                  height: 1,
                  width: double.infinity,
                  color: verdeOscuro,
                ),

                pw.SizedBox(height: 6),

                pw.Row(
                  mainAxisAlignment:
                      pw.MainAxisAlignment.spaceBetween,
                  children: [

                    pw.Text(
                      'Este documento contiene únicamente información '
                      'referente al stock disponible del cliente.',
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: gris,
                      ),
                    ),

                    pw.Text(
                      'Página ${context.pageNumber}',
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: gris,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },

          // ===================================================
          // CONTENIDO
          // ===================================================

          build: (context) {
            return [

              // =================================================
              // RESUMEN
              // =================================================

              pw.Container(
                width: double.infinity,

                padding:
                    const pw.EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),

                decoration: pw.BoxDecoration(
                  color: verdeSuave,

                  border: pw.Border.all(
                    color: verdeClaro,
                    width: 1,
                  ),

                  borderRadius:
                      pw.BorderRadius.circular(8),
                ),

                child: pw.Row(
                  mainAxisAlignment:
                      pw.MainAxisAlignment.spaceBetween,

                  children: [

                    // -------------------------------------------
                    // ARTÍCULOS
                    // -------------------------------------------

                    _resumenDato(
                      titulo: 'Artículos',
                      valor:
                          '${productos.length}',
                    ),

                    // -------------------------------------------
                    // CANTIDAD
                    // -------------------------------------------

                    _resumenDato(
                      titulo: 'Cantidad total',
                      valor:
                          cantidadFormat.format(
                        totalCantidad,
                      ),
                    ),

                    // -------------------------------------------
                    // PESO
                    // -------------------------------------------

                    _resumenDato(
                      titulo: 'Peso total',
                      valor:
                          '${pesoFormat.format(totalPeso)} Kg',
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // =================================================
              // TÍTULO DETALLE
              // =================================================

              pw.Row(
                children: [

                  pw.Container(
                    width: 25,
                    height: 25,
                    decoration: pw.BoxDecoration(
                      color: verde,
                      shape: pw.BoxShape.circle,
                    ),

                    child: pw.Center(
                      child: pw.Text(
                        '✓',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 13,
                          fontWeight:
                              pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  pw.SizedBox(width: 8),

                  pw.Text(
                    'DETALLE DEL STOCK',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight:
                          pw.FontWeight.bold,
                      color: verdeOscuro,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),

              // =================================================
              // TABLA
              // =================================================

              pw.TableHelper.fromTextArray(
                headers: [
                  'N°',
                  'Artículo',
                  'Fecha ingreso',
                  'Cantidad',
                  'Peso (Kg)',
                ],

                data: List.generate(
                  productos.length,
                  (index) {
                    final producto =
                        productos[index];

                    return [
                      '${index + 1}',

                      producto.descripcion,

                      _formatearFecha(
                        producto.fechaIngreso,
                      ),

                      cantidadFormat.format(
                        producto.stock,
                      ),

                      pesoFormat.format(
                        producto.peso,
                      ),
                    ];
                  },
                ),

                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),

                headerDecoration:
                    const pw.BoxDecoration(
                  color: verdeOscuro,
                ),

                headerStyle: pw.TextStyle(
                  fontSize: 8,
                  fontWeight:
                      pw.FontWeight.bold,
                  color: PdfColors.white,
                ),

                cellStyle:
                    const pw.TextStyle(
                  fontSize: 7.5,
                ),

                cellPadding:
                    const pw.EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 6,
                ),

                columnWidths: {
                  0: const pw.FixedColumnWidth(25),

                  1: const pw.FlexColumnWidth(5),

                  2: const pw.FixedColumnWidth(70),

                  3: const pw.FixedColumnWidth(55),

                  4: const pw.FixedColumnWidth(55),
                },

                cellAlignments: {
                  0: pw.Alignment.center,

                  1: pw.Alignment.centerLeft,

                  2: pw.Alignment.center,

                  3: pw.Alignment.center,

                  4: pw.Alignment.center,
                },

                rowDecoration: const pw.BoxDecoration(
  color: PdfColors.white,
),


              ),

              pw.SizedBox(height: 18),

              // =================================================
              // TOTAL DE STOCK
              // =================================================

              pw.Container(
                alignment:
                    pw.Alignment.centerRight,

                child: pw.Container(
                  width: 250,

                  padding:
                      const pw.EdgeInsets.all(13),

                  decoration: pw.BoxDecoration(
                    color: verdeSuave,

                    border: pw.Border.all(
                      color: verde,
                      width: 1,
                    ),

                    borderRadius:
                        pw.BorderRadius.circular(8),
                  ),

                  child: pw.Column(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment.start,

                    children: [

                      pw.Text(
                        'TOTAL DE STOCK',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight:
                              pw.FontWeight.bold,
                          color: verdeOscuro,
                        ),
                      ),

                      pw.SizedBox(height: 7),

                      pw.Container(
                        height: 1,
                        width: double.infinity,
                        color: verde,
                      ),

                      pw.SizedBox(height: 8),

                      pw.Text(
                        'Artículos: ${productos.length}',
                        style:
                            const pw.TextStyle(
                          fontSize: 9,
                        ),
                      ),

                      pw.SizedBox(height: 4),

                      pw.Text(
                        'Cantidad: '
                        '${cantidadFormat.format(totalCantidad)}',
                        style:
                            const pw.TextStyle(
                          fontSize: 9,
                        ),
                      ),

                      pw.SizedBox(height: 4),

                      pw.Text(
                        'Peso: '
                        '${pesoFormat.format(totalPeso)} Kg',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight:
                              pw.FontWeight.bold,
                          color: verdeOscuro,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(height: 20),

              // =================================================
              // NOTA
              // =================================================

              pw.Container(
                width: double.infinity,

                padding:
                    const pw.EdgeInsets.all(9),

                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,

                  borderRadius:
                      pw.BorderRadius.circular(5),
                ),

                child: pw.Text(
                  'Documento informativo. '
                  'La información mostrada corresponde '
                  'únicamente al stock disponible del cliente '
                  'al momento de generar este reporte.',
                  style: const pw.TextStyle(
                    fontSize: 7.5,
                    color: gris,
                  ),
                ),
              ),
            ];
          },
        ),
      );

      // =======================================================
      // ABRIR IMPRESIÓN / GUARDAR PDF
      // =======================================================

      await Printing.layoutPdf(
        onLayout: (format) async {
          return pdf.save();
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al generar el reporte: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // =========================================================
  // RESUMEN
  // =========================================================

  static pw.Widget _resumenDato({
    required String titulo,
    required String valor,
  }) {
    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,
      children: [

        pw.Text(
          titulo,
          style: const pw.TextStyle(
            fontSize: 8,
            color: gris,
          ),
        ),

        pw.SizedBox(height: 4),

        pw.Text(
          valor,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight:
                pw.FontWeight.bold,
            color: verdeOscuro,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // FORMATEAR FECHA
  // =========================================================

  static String _formatearFecha(
    String fecha,
  ) {
    if (fecha.trim().isEmpty) {
      return '-';
    }

    try {
      final date =
          DateTime.parse(fecha);

      return DateFormat(
        'dd/MM/yyyy',
      ).format(date);
    } catch (_) {
      return fecha;
    }
  }
}