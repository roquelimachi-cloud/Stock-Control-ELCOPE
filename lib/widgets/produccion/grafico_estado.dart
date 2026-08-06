import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../models/produccion/produccion_estado.dart';
import '../../services/produccion/produccion_estado_service.dart';

class GraficoEstado extends StatefulWidget {
  const GraficoEstado({super.key});

  @override
  State<GraficoEstado> createState() =>
      _GraficoEstadoState();
}

class _GraficoEstadoState
    extends State<GraficoEstado> {

  final service = ProduccionEstadoService();

  late Future<List<ProduccionEstado>> future;

  @override
  void initState() {
    super.initState();

    future = service.obtener();
  }

  @override
  Widget build(BuildContext context) {

    return FutureBuilder<List<ProduccionEstado>>(

      future: future,

      builder: (context, snapshot) {

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(snapshot.error.toString()),
          );
        }

        final datos = snapshot.data!;

        return SfCircularChart(

          title: ChartTitle(
            text: "Producciones por Estado",
          ),

          legend: const Legend(
            isVisible: true,
            position: LegendPosition.bottom,
          ),

          series: [

            DoughnutSeries<ProduccionEstado, String>(

              dataSource: datos,

              xValueMapper: (e, _) => e.estado,

              yValueMapper: (e, _) => e.cantidad,

              dataLabelMapper: (e, _) =>
                  "${e.cantidad}",

              dataLabelSettings:
                  const DataLabelSettings(
                isVisible: true,
              ),

            )

          ],

        );
      },

    );
  }
}