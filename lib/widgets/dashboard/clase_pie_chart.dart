import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../models/dashboard/clase_resumen.dart';

class ClasePieChart extends StatelessWidget {
  final List<ClaseResumen> datos;

  const ClasePieChart({
    super.key,
    required this.datos,
  });

  @override
  Widget build(BuildContext context) {
    final moneda = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'US\$ ',
      decimalDigits: 0,
    );

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            const Row(
              children: [

                Icon(
                  Icons.pie_chart,
                  color: Colors.indigo,
                  size: 28,
                ),

                SizedBox(width: 10),

                Text(
                  "Valor Stock por Clase",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 360,
              child: SfCircularChart(

                legend: const Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                  overflowMode:
                      LegendItemOverflowMode.wrap,
                ),

                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  format: 'point.x\npoint.y',
                ),

                series: <DoughnutSeries<ClaseResumen, String>>[
                  DoughnutSeries<ClaseResumen, String>(

                    dataSource: datos,

                    xValueMapper: (e, _) => e.clase,

                    yValueMapper: (e, _) => e.monto,

                    pointColorMapper: (e, _) {

                      switch (e.clase) {

                        case 'CL1':
                          return Colors.blue;

                        case 'CL2':
                          return Colors.green;

                        case 'CL5':
                          return Colors.orange;

                        case 'CL6':
                          return Colors.red;

                        default:
                          return Colors.grey;
                      }
                    },

                    dataLabelMapper: (e, _) =>
                        e.clase,

                    dataLabelSettings:
                        const DataLabelSettings(
                      isVisible: true,
                    ),

                    radius: '95%',
                    innerRadius: '65%',

                    explode: true,
                    explodeOffset: '5%',

                    animationDuration: 1800,
                  ),
                ],

                annotations: [

                  CircularChartAnnotation(
                    widget: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        const Text(
                          "Total",
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),

                        Text(
                          moneda.format(
                            datos.fold<double>(
                              0,
                              (suma, e) =>
                                  suma + e.monto,
                            ),
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}