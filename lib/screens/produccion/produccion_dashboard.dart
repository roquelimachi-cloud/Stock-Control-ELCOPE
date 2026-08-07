  import 'package:flutter/material.dart';

  import '../../controllers/produccion/produccion_dashboard_controller.dart';
  import '../../services/produccion/produccion_excel_service.dart';
  import '../../services/produccion/produccion_import_service.dart';
  import '../../services/sesion.dart';

  import '../../widgets/produccion/produccion_kpis.dart';
  import '../../widgets/produccion/dona_produccion.dart';
  import '../../widgets/produccion/top_clientes_widget.dart';
  import '../../widgets/produccion/mis_producciones_widget.dart';
  import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

import '../../services/pdf/pdf_dashboard_service.dart';
  class ProduccionDashboard extends StatefulWidget {
    const ProduccionDashboard({super.key});

    @override
    State<ProduccionDashboard> createState() =>
        _ProduccionDashboardState();
  }

  class _ProduccionDashboardState
      extends State<ProduccionDashboard>
      with SingleTickerProviderStateMixin {

    final excelService =
        ProduccionExcelService();

    final importService =
        ProduccionImportService();

    final controller =
        ProduccionDashboardController();
final pdfService = PdfDashboardService();

final GlobalKey dashboardKey = GlobalKey();
    @override
    void initState() {
      super.initState();

      controller.cargar();
    }

    @override
    Widget build(BuildContext context) {

      return Scaffold(

        appBar: AppBar(
          title: const Text(
            "PRODUCCIÓN PENDIENTE",
          ),
          centerTitle: true,
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
       body: RepaintBoundary(

  key: dashboardKey,

  child: SingleChildScrollView(

          padding: const EdgeInsets.all(20),

          child: Column(

            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              const Text(
                "Producción Pendiente",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Dashboard Ejecutivo",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 20),

              if (Sesion.esAdministrador)
  Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [

      //-----------------------------------------
      // IMPORTAR EXCEL
      //-----------------------------------------

      ElevatedButton.icon(

        icon: const Icon(Icons.upload_file),

        label: const Text("Importar Excel"),

        onPressed: () async {

          try {

            final excel =
                await excelService.seleccionarExcel();

            if (excel == null) return;

            final lista =
                excelService.leerProduccion(excel);

            final cantidad =
                await importService.importar(lista);

            await controller.cargar();

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(

              SnackBar(

                backgroundColor: Colors.green,

                content: Text(
                  "Se importaron $cantidad registros correctamente.",
                ),

              ),

            );

          } catch (e) {

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(

              SnackBar(

                backgroundColor: Colors.red,

                content: Text(e.toString()),

              ),

            );

          }

        },

      ),

      const SizedBox(width: 12),

      //-----------------------------------------
      // EXPORTAR PDF
      //-----------------------------------------

      ElevatedButton.icon(

        style: ElevatedButton.styleFrom(

          backgroundColor: Colors.red,

          foregroundColor: Colors.white,

        ),

        icon: const Icon(Icons.picture_as_pdf),

     label: const Text("Exportar PDF"),

onPressed: () async {

  final boundary =
      dashboardKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

  final ui.Image image =
      await boundary.toImage(pixelRatio: 3);

  final byteData = await image.toByteData(
    format: ui.ImageByteFormat.png,
  );

  if (byteData == null) return;

  await pdfService.generar(
    dashboard: byteData.buffer.asUint8List(),
  );
},

      ),

    ],
  ),
              const SizedBox(height: 25),

              AnimatedBuilder(

                animation: controller,

                builder: (_, __) {

                  if (controller.cargando) {

                    return const Center(
                      child:
                          CircularProgressIndicator(),
                    );

                  }

                  return ProduccionKpis(

                    totalOp:
                        controller.totalOp,

                    valorNeto:
                        controller.valorNeto,

                    pesoCobre:
                        controller.pesoCobre,

                    clientes:
                        controller.clientes,

                  );

                },

              ),

                  //--------------------------------------------------
              // DONAS + TOP CLIENTES
              //--------------------------------------------------

              AnimatedBuilder(
                animation: controller,
                builder: (context, _) {

                  if (controller.cargando) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  return Row(

                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [

                      //------------------------------------------------
                      // DONAS
                      //------------------------------------------------

                      Expanded(
                        flex: 6,
                        child: Column(

                          children: [

                            Row(

                              children: [

                                Expanded(
                                  child: SizedBox(
                                    height: 320,
                                    child: DonaProduccion(
                                      titulo:
                                          "Producción por Estado",
                                      datos:
                                          controller.estado,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 15),

                                Expanded(
                                  child: SizedBox(
                                    height: 320,
                                    child: DonaProduccion(
                                      titulo:
                                          "Producción por Canal",
                                      datos:
                                          controller.canal,
                                    ),
                                  ),
                                ),

                              ],

                            ),

                            const SizedBox(height: 18),

                            Row(

                              children: [

                                Expanded(
                                  child: SizedBox(
                                    height: 320,
                                    child: DonaProduccion(
                                      titulo:
                                          "Producción por Clase",
                                      datos:
                                          controller.clase,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 15),

                                Expanded(
                                  child: SizedBox(
                                    height: 320,
                                    child: DonaProduccion(
                                      titulo:
                                          "Producción por Familia",
                                      datos:
                                          controller.familia,
                                    ),
                                  ),
                                ),

                              ],

                            ),

                          ],

                        ),
                      ),

                      const SizedBox(width: 20),

                      //------------------------------------------------
                      // TOP CLIENTES
                      //------------------------------------------------

                      Expanded(
                        flex: 4,
                        child: SizedBox(
                          height: 660,
                          child: TopClientesWidget(
                            clientes:
                                controller.topClientes,
                          ),
                        ),
                      ),

                    ],

                  );

                },
              ),

              const SizedBox(height: 25),      

                  //--------------------------------------------------
              // MIS PRODUCCIONES
              //--------------------------------------------------

              const MisProduccionesWidget(),

              const SizedBox(height: 25),

              //--------------------------------------------------
              // RESUMEN (PRÓXIMAMENTE)
              //--------------------------------------------------

              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Container(
                  height: 160,
                  padding: const EdgeInsets.all(25),
                  child: Row(

                    children: [

                      const Icon(
                        Icons.analytics,
                        color: Colors.indigo,
                        size: 42,
                      ),

                      const SizedBox(width: 20),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [

                            const Text(
                              "Próximamente",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 10),

                            Text(
                              "Aquí mostraremos indicadores ejecutivos como retrasos, "
                              "producción semanal, utilización de cobre, "
                              "cumplimiento de entregas, ranking de familias y "
                              "análisis predictivo.",
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 15,
                              ),
                            ),

                          ],
                        ),
                      ),

                    ],
                  ),
                ),
              ),

                const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }
}