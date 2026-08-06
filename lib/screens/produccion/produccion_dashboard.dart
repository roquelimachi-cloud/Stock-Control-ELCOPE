import 'package:flutter/material.dart';
import '../../widgets/produccion/produccion_kpis.dart';
import '../../models/produccion/produccion_resumen.dart';
import '../../services/produccion/produccion_dashboard_service.dart';
import '../../services/produccion/produccion_excel_service.dart';
import '../../services/produccion/produccion_import_service.dart';
import '../../services/sesion.dart';
import '../../widgets/produccion/mis_producciones_widget.dart';
class ProduccionDashboard extends StatefulWidget {
  const ProduccionDashboard({super.key});

  @override
  State<ProduccionDashboard> createState() =>
      _ProduccionDashboardState();
}
class _ProduccionDashboardState
    extends State<ProduccionDashboard>
    with SingleTickerProviderStateMixin {

  late TabController tabController;

final dashboardService = ProduccionDashboardService();
final excelService = ProduccionExcelService();
final importService = ProduccionImportService();
late Future<ProduccionResumen> resumenFuture;
@override
void initState() {
  super.initState();

  resumenFuture = dashboardService.obtenerResumen();
}
  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("PRODUCCIÓN PENDIENTE"),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

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
  Align(
    alignment: Alignment.centerRight,
    child: ElevatedButton.icon(
    
    icon: const Icon(Icons.upload_file),
    label: const Text("Importar Excel"),
    onPressed: () async {

      try {

        final excel =
            await excelService.seleccionarExcel();

        if (excel == null) return;

        final lista =
            excelService.leerProduccion(excel);

        debugPrint("Registros leídos: ${lista.length}");

        final cantidad =
            await importService.importar(lista);

        debugPrint("Registros importados: $cantidad");

        if (!mounted) return;

        resumenFuture =
            dashboardService.obtenerResumen();

        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              "Se importaron $cantidad registros correctamente.",
            ),
          ),
        );

      } catch (e) {

        debugPrint("ERROR IMPORTANDO:");
        debugPrint(e.toString());

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text("Error: $e"),
          ),
        );

      }

    },
  ),
),

const SizedBox(height: 30),
FutureBuilder<ProduccionResumen>(
  future: resumenFuture,
  builder: (context, snapshot) {

    if (snapshot.connectionState ==
        ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (snapshot.hasError) {
      return Center(
        child: Text(
          "Error: ${snapshot.error}",
        ),
      );
    }

    final resumen = snapshot.data!;

    return ProduccionKpis(
      totalOp: resumen.totalOp,
      valorNeto: resumen.valorNeto,
      pesoCobre: resumen.pesoCobre,
      clientes: resumen.clientes,
    );
  },
),

const SizedBox(height: 25), 

            Row(

              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Expanded(
                  flex: 5,
                  child: Card(
                    child: SizedBox(
                      height: 350,
                      child: Center(
                        child: Text(
                          "Gráfico Producción",
                          style: TextStyle(
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                Expanded(
                  flex: 5,
                  child: Card(
                    child: SizedBox(
                      height: 350,
                      child: Center(
                        child: Text(
                          "Top Clientes",
                          style: TextStyle(
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              ],
            ),

            const SizedBox(height: 25),

const MisProduccionesWidget(),

 Card(
  child: SizedBox(
    height: 420,
    child: Center(
      child: Text(
        "Tabla Producción",
        style: TextStyle(
          fontSize: 22,
        ),
      ),
    ),
  ),
),

          ],
        ),
      ),
    );
  }
}