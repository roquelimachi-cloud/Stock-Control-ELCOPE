import 'package:flutter/material.dart';

import '../../controllers/produccion/produccion_dashboard_controller.dart';

import '../../services/produccion/produccion_excel_service.dart';
import '../../services/produccion/produccion_import_service.dart';
import '../../services/pdf/pdf_dashboard_service.dart';

import '../../services/sesion.dart';

import '../../widgets/produccion/produccion_kpis.dart';
import '../../widgets/produccion/dona_produccion.dart';
import '../../widgets/produccion/top_clientes_widget.dart';
import '../../widgets/produccion/mis_producciones_widget.dart';
import 'package:intl/intl.dart';

class ProduccionDashboard extends StatefulWidget {

  const ProduccionDashboard({super.key});

  @override
  State<ProduccionDashboard> createState() =>
      _ProduccionDashboardState();

}

class _ProduccionDashboardState
    extends State<ProduccionDashboard> {

  final excelService =
      ProduccionExcelService();

  final importService =
      ProduccionImportService();

  final controller =
      ProduccionDashboardController();

  final pdfService =
      PdfDashboardService();

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

      body: SingleChildScrollView(

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

                mainAxisAlignment:
                    MainAxisAlignment.end,

                children: [

                  ElevatedButton.icon(

                    icon: const Icon(
                      Icons.upload_file,
                    ),

                    label: const Text(
                      "Importar Excel",
                    ),

                    onPressed: () async {

                      try {

                        final excel =
                            await excelService
                                .seleccionarExcel();

                        if (excel == null) return;

                        final lista =
                            excelService
                                .leerProduccion(
                                    excel);

                        final cantidad =
                            await importService
                                .importar(lista);

                        await controller.cargar();

                        if (!mounted) return;

                        ScaffoldMessenger.of(context)
                            .showSnackBar(

                          SnackBar(

                            backgroundColor:
                                Colors.green,

                            content: Text(
                              "Se importaron $cantidad registros correctamente.",
                            ),

                          ),

                        );

                      } catch (e) {

                        if (!mounted) return;

                        ScaffoldMessenger.of(context)
                            .showSnackBar(

                          SnackBar(

                            backgroundColor:
                                Colors.red,

                            content:
                                Text(e.toString()),

                          ),

                        );

                      }

                    },

                  ),

                  const SizedBox(width: 12),

                  ElevatedButton.icon(

                    style:
                        ElevatedButton.styleFrom(

                      backgroundColor:
                          Colors.red,

                      foregroundColor:
                          Colors.white,

                    ),

                    icon: const Icon(
                      Icons.picture_as_pdf,
                    ),

                    label: const Text(
                      "Exportar PDF",
                    ),

                    onPressed: () async {

                      await pdfService.generar(

                        totalOp:
                            controller.totalOp,

                        clientes:
                            controller.clientes,

                        valorNeto:
                            controller.valorNeto,

                        pesoCobre:
                            controller.pesoCobre,

                        topClientes:
                            controller.topClientes,

                        producciones:
                            controller.producciones,

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

            const SizedBox(height: 25),

            //====================================================
            // DONAS
            //====================================================
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

        //--------------------------------------------------
        // DONAS
        //--------------------------------------------------

        Expanded(

          flex: 6,

          child: Column(

            children: [

              //------------------------------------------------
              // FILA 1
              //------------------------------------------------

              Row(

                children: [

                  Expanded(

                    child: SizedBox(

                     height: 380,

                      child: DonaProduccion(
  titulo: "Producción por Estado",
  datos: controller.estado,
  centroValor: "US\$ ${NumberFormat("#,##0").format(controller.valorNeto)}",
  centroTexto: "Valor",
),

                    ),

                  ),

                  const SizedBox(width: 15),

                  Expanded(

                    child: SizedBox(

                      height: 320,

                      child: DonaProduccion(
  titulo: "Producción por Canal",
  datos: controller.canal,
  centroValor: controller.totalOp.toString(),
  centroTexto: "Total",
),

                    ),

                  ),

                ],

              ),

              const SizedBox(height: 20),

              //------------------------------------------------
              // FILA 2
              //------------------------------------------------

              Row(

                children: [

                  Expanded(

                    child: SizedBox(

                      height: 320,

                      child:DonaProduccion(
  titulo: "Producción por Clase",
  datos: controller.clase,
  centroValor: "US\$ ${NumberFormat("#,##0").format(controller.valorNeto)}",
  centroTexto: "Valor",
),

                    ),

                  ),

                  const SizedBox(width: 15),

                  Expanded(

                    child: SizedBox(

                      height: 320,

                      child: DonaProduccion(
  titulo: "Producción por Familia",
  datos: controller.familia,
  centroValor: "${NumberFormat("#,##0").format(controller.pesoCobre)} Kg",
  centroTexto: "Kg Cobre",
),

                    ),

                  ),

                ],

              ),

            ],

          ),

        ),

        const SizedBox(width: 20),

        //--------------------------------------------------
        // TOP CLIENTES
        //--------------------------------------------------

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

//====================================================
// MIS PRODUCCIONES
//====================================================

const MisProduccionesWidget(),

const SizedBox(height: 25),

//====================================================
// RESUMEN EJECUTIVO
//====================================================

Card(

  elevation: 6,

  shape: RoundedRectangleBorder(

    borderRadius:
        BorderRadius.circular(18),

  ),

  child: Container(

    padding:
        const EdgeInsets.all(25),

    height: 160,

    child: Row(

      children: [

        const Icon(

          Icons.analytics,

          size: 45,

          color: Colors.indigo,

        ),

        const SizedBox(width: 20),

        Expanded(

          child: Column(

            mainAxisAlignment:
                MainAxisAlignment.center,

            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              const Text(

                "Resumen Ejecutivo",

                style: TextStyle(

                  fontSize: 24,

                  fontWeight:
                      FontWeight.bold,

                ),

              ),

              const SizedBox(height: 10),

              Text(

                "Próximamente se mostrarán indicadores de cumplimiento, retrasos, utilización de cobre, análisis por semana, ranking de familias y proyección de producción.",

                style: TextStyle(

                  color:
                      Colors.grey.shade700,

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
  );
}
}