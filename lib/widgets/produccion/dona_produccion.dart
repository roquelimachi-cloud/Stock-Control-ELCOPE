import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../models/produccion/grafico_produccion.dart';

class DonaProduccion extends StatelessWidget {
  final String titulo;
  final List<GraficoProduccion> datos;

  final String? centroValor;
  final String? centroTexto;

  const DonaProduccion({
    super.key,
    required this.titulo,
    required this.datos,
    this.centroValor,
    this.centroTexto,
  });

  @override
  Widget build(BuildContext context) {
    final total = datos.fold<double>(
      0,
      (suma, e) => suma + e.valor,
    );

    final formatter = NumberFormat.compact();

    final colores = <Color>[
      const Color(0xff00E676),
      const Color(0xff2979FF),
      const Color(0xffFF9100),
      const Color(0xffFF1744),
      const Color(0xffAA00FF),
      const Color(0xff00BCD4),
      const Color(0xffFFD600),
      const Color(0xff40C4FF),
      const Color(0xff64FFDA),
      const Color(0xff7C4DFF),
    ];

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                titulo,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: Row(
                children: [

                  //--------------------------------------------------
                  // DONA
                  //--------------------------------------------------

                  Expanded(
                    flex: 6,
                    child: SfCircularChart(

                      tooltipBehavior: TooltipBehavior(
                        enable: true,
                      ),

                      legend: const Legend(
                        isVisible: false,
                      ),

                      annotations: [

                        CircularChartAnnotation(

                          widget: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [

                              Text(
                                centroValor ??
                                    formatter.format(total),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 4),

                              Text(
                                centroTexto ?? "Total",
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),

                            ],
                          ),

                        ),

                      ],

                      series: [

                        DoughnutSeries<GraficoProduccion, String>(

                          dataSource: datos,

                          xValueMapper: (e, _) => e.nombre,

                          yValueMapper: (e, _) => e.valor,

                          pointColorMapper: (e, index) =>
                              colores[index! % colores.length],

                          dataLabelSettings:
                              const DataLabelSettings(
                            isVisible: false,
                          ),

                          radius: "90%",
                          innerRadius: "68%",

                          explode: true,
                          explodeOffset: "3%",

                          animationDuration: 1800,
                        ),

                      ],

                    ),
                  ),

                  const SizedBox(width: 20),

                  //--------------------------------------------------
                  // LEYENDA
                  //--------------------------------------------------

                  Expanded(
                    flex: 4,
                    child: ListView.separated(

                      physics:
                          const NeverScrollableScrollPhysics(),

                      itemCount: datos.length,

                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),

                      itemBuilder: (_, i) {

                        final item = datos[i];

                        final porcentaje =
                            total == 0
                                ? 0
                                : (item.valor / total) * 100;

                        return Row(

                          children: [

                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color:
                                    colores[i % colores.length],
                                shape: BoxShape.circle,
                              ),
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: Text(
                                item.nombre,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            ),

                            Text(
                              "${porcentaje.toStringAsFixed(1)}%",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                          ],

                        );

                      },

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