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

  // =========================================================
  // COLORES POR CLASE
  // =========================================================

  Color colorClase(String clase) {
    switch (clase.trim().toUpperCase()) {
      case 'CL1':
        return const Color(0xff2979FF);

      case 'CL2':
        return const Color(0xff00C853);

      case 'CL5':
        return const Color(0xffff9100);

      case 'CL6':
        return const Color(0xffFF1744);

      default:
        return const Color(0xff9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moneda = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'US\$ ',
      decimalDigits: 0,
    );

    // =========================================================
    // TOTAL
    // =========================================================

    final double total = datos.fold<double>(
      0,
      (suma, item) => suma + item.monto,
    );

    // =========================================================
    // GRÁFICO
    // =========================================================

    Widget construirGrafico() {
      return SfCircularChart(
        margin: EdgeInsets.zero,

        tooltipBehavior: TooltipBehavior(
          enable: true,
          format: 'point.x\nUS\$ point.y',
        ),

        legend: const Legend(
          isVisible: false,
        ),

        series: <DoughnutSeries<ClaseResumen, String>>[
          DoughnutSeries<ClaseResumen, String>(
            dataSource: datos,

            xValueMapper: (
              ClaseResumen item,
              _,
            ) =>
                item.clase,

            yValueMapper: (
              ClaseResumen item,
              _,
            ) =>
                item.monto,

            pointColorMapper: (
              ClaseResumen item,
              _,
            ) =>
                colorClase(item.clase),

            // Dona grande
            radius: '88%',

            // Agujero central
            innerRadius: '58%',

            // Separación pequeña entre clases
            explode: true,

            explodeOffset: '2%',

            // Animación
            animationDuration: 1200,

            // =================================================
            // NOMBRE Y VALOR DENTRO DE LA DONA
            // =================================================

            dataLabelMapper: (
              ClaseResumen item,
              _,
            ) {
              final porcentaje = total == 0
                  ? 0
                  : (item.monto / total) * 100;

              // No mostramos texto en segmentos
              // demasiado pequeños.
              if (porcentaje < 3) {
                return '';
              }

              return item.clase;
            },

            dataLabelSettings:
                const DataLabelSettings(
              isVisible: true,

              labelPosition:
                  ChartDataLabelPosition.inside,

              textStyle: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],

        // =====================================================
        // CENTRO DE LA DONA
        // =====================================================

        annotations: [
          CircularChartAnnotation(
            widget: SizedBox(
              width: 155,
              height: 105,

              child: FittedBox(
                fit: BoxFit.scaleDown,

                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,

                  mainAxisSize:
                      MainAxisSize.min,

                  children: [
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      moneda.format(total),

                      maxLines: 1,

                      textAlign:
                          TextAlign.center,

                      style: const TextStyle(
                        color:
                            Color(0xff202124),
                        fontSize: 25,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // =========================================================
    // LEYENDA
    // =========================================================

    Widget construirLeyenda() {
      return Container(
        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          color: const Color(0xffF8F9FC),

          borderRadius:
              BorderRadius.circular(16),

          border: Border.all(
            color:
                const Color(0xffE5E7EB),
          ),
        ),

        child: Column(
          children: [
            // -----------------------------------------------
            // ENCABEZADO
            // -----------------------------------------------

            const Padding(
              padding:
                  EdgeInsets.only(
                bottom: 8,
              ),

              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'CLASE',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  SizedBox(
                    width: 105,
                    child: Text(
                      'VALOR',
                      textAlign:
                          TextAlign.right,
                      style: TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  SizedBox(width: 12),

                  SizedBox(
                    width: 48,
                    child: Text(
                      '%',
                      textAlign:
                          TextAlign.right,
                      style: TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(
              height: 10,
            ),

            // -----------------------------------------------
            // CLASES
            // -----------------------------------------------

            ...datos.map((item) {
              final color =
                  colorClase(item.clase);

              final porcentaje =
                  total == 0
                      ? 0.0
                      : (item.monto /
                              total) *
                          100;

              return Padding(
                padding:
                    const EdgeInsets
                        .symmetric(
                  vertical: 7,
                ),

                child: Row(
                  children: [
                    // Color
                    Container(
                      width: 16,
                      height: 16,

                      decoration:
                          BoxDecoration(
                        color: color,
                        shape:
                            BoxShape.circle,

                        boxShadow: [
                          BoxShadow(
                            color: color
                                .withOpacity(
                              0.25,
                            ),
                            blurRadius: 5,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    // Clase
                    Expanded(
                      child: Text(
                        item.clase,

                        style:
                            TextStyle(
                          fontSize: 14,
                          fontWeight:
                              FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),

                    // Valor
                    SizedBox(
                      width: 105,

                      child: Text(
                        moneda.format(
                          item.monto,
                        ),

                        textAlign:
                            TextAlign.right,

                        style:
                            TextStyle(
                          fontSize: 13,
                          fontWeight:
                              FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 12,
                    ),

                    // Porcentaje
                    SizedBox(
                      width: 48,

                      child: Text(
                        '${porcentaje.toStringAsFixed(1)}%',

                        textAlign:
                            TextAlign.right,

                        style:
                            const TextStyle(
                          fontSize: 12,
                          color:
                              Colors.grey,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(
              height: 8,
            ),

            // -----------------------------------------------
            // TOTAL GENERAL
            // -----------------------------------------------

            Container(
              width: double.infinity,

              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 14,
                vertical: 12,
              ),

              decoration: BoxDecoration(
                color:
                    const Color(
                  0xffEEF4FF,
                ),

                borderRadius:
                    BorderRadius.circular(
                  12,
                ),

                border: Border.all(
                  color:
                      const Color(
                    0xffC9DBFF,
                  ),
                ),
              ),

              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,

                    decoration:
                        const BoxDecoration(
                      color:
                          Color(0xff2979FF),
                      shape:
                          BoxShape.circle,
                    ),

                    child: const Icon(
                      Icons
                          .account_balance_wallet,
                      color:
                          Colors.white,
                      size: 18,
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'TOTAL GENERAL',
                          style:
                              TextStyle(
                            fontSize: 11,
                            color:
                                Color(
                              0xff2979FF,
                            ),
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        Text(
                          '100.0%',
                          style:
                              TextStyle(
                            fontSize: 12,
                            color:
                                Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Text(
                    moneda.format(total),

                    style:
                        const TextStyle(
                      color:
                          Color(0xff2979FF),
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // =========================================================
    // SIN DATOS
    // =========================================================

    if (datos.isEmpty) {
      return Card(
        elevation: 6,

        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(20),
        ),

        child: const SizedBox(
          height: 300,

          child: Center(
            child: Text(
              'No hay datos de stock por clase.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 15,
              ),
            ),
          ),
        ),
      );
    }

    // =========================================================
    // CARD PRINCIPAL RESPONSIVE
    // =========================================================

    return Card(
      elevation: 6,

      shadowColor:
          Colors.black.withOpacity(
        0.08,
      ),

      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(20),
      ),

      child: Padding(
        padding:
            const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            // =================================================
            // TÍTULO
            // =================================================

            const Row(
              children: [
                Icon(
                  Icons.pie_chart,
                  color:
                      Color(0xff2979FF),
                  size: 28,
                ),

                SizedBox(width: 10),

                Expanded(
                  child: Text(
                    'Valor Stock por Clase',

                    style: TextStyle(
                      fontSize: 22,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 18,
            ),

            // =================================================
            // CONTENIDO RESPONSIVE
            // =================================================

            LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                final ancho =
                    constraints.maxWidth;

                // =============================================
                // 📱 CELULAR
                // =============================================

                if (ancho < 650) {
                  return Column(
                    children: [
                      SizedBox(
                        width:
                            double.infinity,
                        height: 320,
                        child:
                            construirGrafico(),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      construirLeyenda(),
                    ],
                  );
                }

                // =============================================
                // 💻 PC / WEB / TABLET
                // =============================================

                return Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center,

                  children: [
                    Expanded(
                      flex: 6,

                      child: SizedBox(
                        height: 430,
                        child:
                            construirGrafico(),
                      ),
                    ),

                    const SizedBox(
                      width: 22,
                    ),

                    Expanded(
                      flex: 4,

                      child:
                          construirLeyenda(),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}