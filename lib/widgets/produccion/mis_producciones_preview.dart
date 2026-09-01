import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final pdfService =
        MisProduccionesPdfService();

    return Scaffold(
      backgroundColor:
          const Color(0xFFF4F5F7),

      // ========================================================
      // BARRA SUPERIOR
      // ========================================================

      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor:
            const Color(0xFF1F2937),

        elevation: 1,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
          ),

          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Row(
          children: [
            Icon(
              Icons.visibility_outlined,
              color: Color(0xFF007A45),
            ),

            SizedBox(width: 10),

            Text(
              "Vista previa del reporte",
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ),

        actions: [
          Padding(
            padding:
                const EdgeInsets.only(
              right: 15,
            ),

            child: ElevatedButton.icon(
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                  0xFF007A45,
                ),

                foregroundColor:
                    Colors.white,

                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
              ),

              icon: const Icon(
                Icons.print,
              ),

              label: const Text(
                "Imprimir",
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              onPressed: () async {
                await Printing.layoutPdf(
                  onLayout:
                      (format) async {
                    return pdfService
                        .generar(
                      producciones:
                          producciones,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // ========================================================
      // PREVISUALIZACIÓN
      // ========================================================

      body: PdfPreview(
        build: (format) {
          return pdfService.generar(
            producciones:
                producciones,
          );
        },

        pdfFileName:
            "Reporte_Mis_Producciones.pdf",

        allowPrinting: true,

        allowSharing: true,

        canChangeOrientation: false,

        canChangePageFormat: false,

        initialPageFormat:
            PdfPageFormat.a4.landscape,

        scrollViewDecoration:
            const BoxDecoration(
          color: Color(0xFFEDEEF2),
        ),
      ),
    );
  }
}