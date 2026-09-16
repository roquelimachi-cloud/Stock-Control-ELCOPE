import 'dart:typed_data';

import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../models/produccion/produccion_model.dart';
import '../../services/produccion/mis_producciones_pdf_service.dart';

class MisProduccionesPreview extends StatelessWidget {
  final List<ProduccionModel> producciones;

  const MisProduccionesPreview({
    super.key,
    required this.producciones,
  });

  Future<void> _exportarExcel(BuildContext context) async {
    try {
      final workbook = excel.Excel.createExcel();
      final sheet = workbook['Mis Producciones'];

      final fecha = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      // ==========================================================
      // ENCABEZADO
      // ==========================================================

      sheet.appendRow([
        excel.TextCellValue('REPORTE MIS PRODUCCIONES'),
      ]);

      sheet.appendRow([
        excel.TextCellValue('Fecha de generación'),
        excel.TextCellValue(fecha),
      ]);

      sheet.appendRow([
        excel.TextCellValue('Total de registros'),
        excel.IntCellValue(producciones.length),
      ]);

      sheet.appendRow([]);

      // ==========================================================
      // DETALLE
      // ==========================================================

      sheet.appendRow([
        excel.TextCellValue('N°'),
        excel.TextCellValue('OP'),
        excel.TextCellValue('Cliente'),
        excel.TextCellValue('Artículo'),
        excel.TextCellValue('Código'),
        excel.TextCellValue('Fecha Producción'),
        excel.TextCellValue('Retraso'),
        excel.TextCellValue('Cantidad'),
        excel.TextCellValue('Valor Neto'),
        excel.TextCellValue('Peso Cobre'),
        excel.TextCellValue('Canal'),
        excel.TextCellValue('Clase'),
        excel.TextCellValue('Familia'),
        excel.TextCellValue('Estado'),
      ]);

      final dateFormat = DateFormat('dd/MM/yyyy');

      for (int i = 0; i < producciones.length; i++) {
        final p = producciones[i];

        sheet.appendRow([
          excel.IntCellValue(i + 1),
          excel.TextCellValue(p.numeroProduccion),
          excel.TextCellValue(p.cliente),
          excel.TextCellValue(p.articulo ?? ''),
          excel.TextCellValue(p.codigoArticulo ?? ''),
          excel.TextCellValue(
            p.fechaProduccion == null
                ? ''
                : dateFormat.format(p.fechaProduccion!),
          ),
          excel.IntCellValue(p.diasRetraso ?? 0),
          excel.DoubleCellValue(p.cantidadTotal ?? 0),
          excel.DoubleCellValue(p.valorNeto ?? 0),
          excel.DoubleCellValue(p.pesoCobre ?? 0),
          excel.TextCellValue(p.canal),
          excel.TextCellValue(p.clase ?? ''),
          excel.TextCellValue(p.abreviadoFamilia ?? ''),
          excel.TextCellValue(p.estado),
        ]);
      }

      // ==========================================================
      // ANCHO DE COLUMNAS
      // ==========================================================

      final widths = <int, double>{
        0: 8,
        1: 18,
        2: 32,
        3: 48,
        4: 22,
        5: 18,
        6: 12,
        7: 15,
        8: 16,
        9: 16,
        10: 16,
        11: 12,
        12: 18,
        13: 16,
      };

      for (final entry in widths.entries) {
        sheet.setColumnWidth(entry.key, entry.value);
      }

      final bytes = workbook.encode();

      if (bytes == null || bytes.isEmpty) {
        throw Exception('No se pudo generar el archivo Excel.');
      }

      final nombreArchivo =
          'Reporte_Mis_Producciones_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

      final String? ruta = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar reporte Excel',
        fileName: nombreArchivo,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(bytes),
      );

      if (!context.mounted) return;

      if (ruta != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reporte Excel generado correctamente.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar Excel: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _imprimir(BuildContext context) async {
    final pdfService = MisProduccionesPdfService();

    await Printing.layoutPdf(
      onLayout: (format) async {
        return pdfService.generar(
          producciones: producciones,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pdfService = MisProduccionesPdfService();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),

      // ========================================================
      // BARRA SUPERIOR RESPONSIVE
      // ========================================================

      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 1,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Regresar',
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: LayoutBuilder(
          builder: (context, constraints) {
            final width = MediaQuery.sizeOf(context).width;

            if (width < 500) {
              return const Text(
                'Vista previa',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              );
            }

            return const Row(
              children: [
                Icon(
                  Icons.visibility_outlined,
                  color: Color(0xFF007A45),
                ),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Vista previa del reporte',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        actions: [
          // ======================================================
          // EXCEL
          // ======================================================

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: IconButton(
              tooltip: 'Exportar Excel',
              icon: const Icon(
                Icons.table_view_outlined,
                color: Color(0xFF007A45),
              ),
              onPressed: () => _exportarExcel(context),
            ),
          ),

          // ======================================================
          // IMPRIMIR
          // ======================================================

          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Imprimir',
              icon: const Icon(Icons.print),
              onPressed: () => _imprimir(context),
            ),
          ),
        ],
      ),

      // ========================================================
      // PREVISUALIZACIÓN PDF
      // ========================================================

      body: PdfPreview(
        build: (format) {
          return pdfService.generar(
            producciones: producciones,
          );
        },

        pdfFileName: 'Reporte_Mis_Producciones.pdf',

        allowPrinting: true,
        allowSharing: true,

        canChangeOrientation: false,
        canChangePageFormat: false,

        initialPageFormat: PdfPageFormat.a4.landscape,

        scrollViewDecoration: const BoxDecoration(
          color: Color(0xFFEDEEF2),
        ),
      ),
    );
  }
}
