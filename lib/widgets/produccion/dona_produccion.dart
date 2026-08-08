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

    final moneyFormatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'US\$ ',
      decimalDigits: 0,
    );

    final kgFormatter = NumberFormat("#,##0");

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

    Widget construirGrafico() {
      return SfCircularChart(
        margin: EdgeInsets.zero,

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
                SizedBox(
                  width: 140,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      centroValor ??
                          total.toStringAsFixed(0),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  centroTexto ?? "Total",
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
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

            radius: "90%",

            innerRadius: "68%",

            explode: true,

            explodeOffset: "3%",

            animationDuration: 1700,
          ),
        ],
      );
    }

    Widget construirLeyenda() {
      return ListView.separated(
        padding: EdgeInsets.zero,
        physics:
            const NeverScrollableScrollPhysics(),

        itemCount: datos.length,

        separatorBuilder: (_, __) =>
            const SizedBox(height: 12),

        itemBuilder: (_, i) {
          final item = datos[i];

          final porcentaje = total == 0
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

              const SizedBox(width: 8),

              Text(
                "${porcentaje.toStringAsFixed(1)}%",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        },
      );
    }

    return Card(
      elevation: 8,

      shadowColor: Colors.black26,

      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(22),
      ),

      child: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            // =====================================================
            // TITULO
            // =====================================================

            Align(
              alignment: Alignment.centerLeft,

              child: Text(
                titulo,

                maxLines: 1,

                overflow:
                    TextOverflow.ellipsis,

                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // =====================================================
            // CONTENIDO RESPONSIVE
            // =====================================================

            Expanded(
              child: LayoutBuilder(
                builder:
                    (context, constraints) {
                  final ancho =
                      constraints.maxWidth;

                  // =================================================
                  // 📱 CELULAR
                  // =================================================

                  if (ancho < 500) {
                    return Column(
                      children: [
                        // -----------------------------
                        // GRAFICO
                        // -----------------------------

                        SizedBox(
                          height: 220,
                          width: double.infinity,
                          child:
                              construirGrafico(),
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        // -----------------------------
                        // LEYENDA
                        // -----------------------------

                        Expanded(
                          child:
                              construirLeyenda(),
                        ),
                      ],
                    );
                  }

                  // =================================================
                  // 💻 TABLET / WEB / WINDOWS
                  // =================================================

                  return Row(
                    children: [
                      // -----------------------------
                      // GRAFICO
                      // -----------------------------

                      Expanded(
                        flex: 6,
                        child:
                            construirGrafico(),
                      ),

                      const SizedBox(
                        width: 20,
                      ),

                      // -----------------------------
                      // LEYENDA
                      // -----------------------------

                      Expanded(
                        flex: 4,
                        child:
                            construirLeyenda(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}