import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../models/dashboard/peso_clase_resumen.dart';

class PesoClasePieChart extends StatelessWidget {
  final List<PesoClaseResumen> datos;

  const PesoClasePieChart({
    super.key,
    required this.datos,
  });

  @override
  Widget build(BuildContext context) {
    final numero = NumberFormat.decimalPattern('en_US');

    // =========================================================
    // TOTAL
    // =========================================================

    final totalPeso = datos.fold<double>(
      0,
      (total, item) => total + item.peso,
    );

    // =========================================================
    // PORCENTAJE
    // =========================================================

    double porcentaje(double peso) {
      if (totalPeso == 0) {
        return 0;
      }

      return (peso / totalPeso) * 100;
    }

    // =========================================================
    // COLOR POR CLASE
    // =========================================================

    Color colorClase(String clase) {
      switch (clase) {
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
    }

    // =========================================================
    // FORMATO DE PESO
    // =========================================================

    String pesoToneladas(double peso) {
      return '${numero.format(peso / 1000)} t';
    }

    // =========================================================
    // DONA
    // =========================================================

    Widget construirDona() {
      return SizedBox(
        height: 340,
        child: SfCircularChart(
          tooltipBehavior: TooltipBehavior(
            enable: true,
            format: 'point.x\npoint.y Kg',
          ),

          series: <DoughnutSeries<
              PesoClaseResumen,
              String>>[
            DoughnutSeries<
                PesoClaseResumen,
                String>(
              dataSource: datos,

              xValueMapper: (
                PesoClaseResumen item,
                _,
              ) =>
                  item.clase,

              yValueMapper: (
                PesoClaseResumen item,
                _,
              ) =>
                  item.peso,

              // -------------------------------------------------
              // COLORES
              // -------------------------------------------------

              pointColorMapper: (
                PesoClaseResumen item,
                _,
              ) {
                return colorClase(item.clase);
              },

              // -------------------------------------------------
              // NOMBRE CLASE DENTRO DE LA DONA
              // -------------------------------------------------

              dataLabelMapper: (
                PesoClaseResumen item,
                _,
              ) {
                return item.clase;
              },

              dataLabelSettings:
                  const DataLabelSettings(
                isVisible: true,
                labelPosition:
                    ChartDataLabelPosition.inside,
                textStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),

              radius: '90%',
              innerRadius: '62%',

              explode: false,

              animationDuration: 1200,
            ),
          ],

          // =====================================================
          // TOTAL EN EL CENTRO
          // =====================================================

          annotations: [
            CircularChartAnnotation(
              widget: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  const Text(
                    'TOTAL',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    pesoToneladas(totalPeso),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
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
    // LEYENDA DERECHA
    // =========================================================

    Widget construirLeyenda() {
      return Container(
        width: 250,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(
            alpha: 0.55,
          ),
          borderRadius:
              BorderRadius.circular(18),
          border: Border.all(
            color: Colors.grey.shade300,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // -------------------------------------------------
            // CABECERA
            // -------------------------------------------------

            const Row(
              children: [

                Expanded(
                  flex: 3,
                  child: Text(
                    'CLASE',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),

                Expanded(
                  flex: 4,
                  child: Text(
                    'PESO',
                    textAlign:
                        TextAlign.right,
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),

                Expanded(
                  flex: 2,
                  child: Text(
                    '%',
                    textAlign:
                        TextAlign.right,
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Divider(
              height: 1,
              color: Colors.grey.shade300,
            ),

            const SizedBox(height: 8),

            // -------------------------------------------------
            // CLASES
            // -------------------------------------------------

            ...datos.map(
              (item) {
                final color =
                    colorClase(item.clase);

                final porcentajeClase =
                    porcentaje(item.peso);

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 6,
                  ),
                  child: Row(
                    children: [

                      // ---------------------------------------
                      // CLASE
                      // ---------------------------------------

                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [

                            Container(
                              width: 18,
                              height: 18,
                              decoration:
                                  BoxDecoration(
                                color: color,
                                shape:
                                    BoxShape.circle,
                              ),
                            ),

                            const SizedBox(
                              width: 8,
                            ),

                            Text(
                              item.clase,
                              style: TextStyle(
                                color: color,
                                fontWeight:
                                    FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ---------------------------------------
                      // PESO
                      // ---------------------------------------

                      Expanded(
                        flex: 4,
                        child: Text(
                          pesoToneladas(
                            item.peso,
                          ),
                          textAlign:
                              TextAlign.right,
                          style: TextStyle(
                            color: color,
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),

                      // ---------------------------------------
                      // PORCENTAJE
                      // ---------------------------------------

                      Expanded(
                        flex: 2,
                        child: Text(
                          '${porcentajeClase.toStringAsFixed(1)}%',
                          textAlign:
                              TextAlign.right,
                          style:
                              const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 8),

            // -------------------------------------------------
            // TOTAL
            // -------------------------------------------------

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(
                  alpha: 0.06,
                ),
                borderRadius:
                    BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.blue.shade200,
                ),
              ),
              child: Row(
                children: [

                  // -------------------------------------------
                  // ICONO
                  // -------------------------------------------

                  Container(
                    width: 44,
                    height: 44,
                    decoration:
                        const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.scale_outlined,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // -------------------------------------------
                  // TOTAL
                  // -------------------------------------------

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [

                        const Text(
                          'PESO TOTAL',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          pesoToneladas(
                            totalPeso,
                          ),
                          style:
                              const TextStyle(
                            color: Colors.blue,
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),

                        const SizedBox(height: 2),

                        const Text(
                          '100.0%',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
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
      );
    }

    // =========================================================
    // CARD
    // =========================================================

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
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
                  Icons.scale_outlined,
                  color: Colors.indigo,
                  size: 28,
                ),

                SizedBox(width: 10),

                Expanded(
                  child: Text(
                    'Peso de Cobre por Clase',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // =================================================
            // DONA + LEYENDA
            // =================================================

            LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {

                // ---------------------------------------------
                // PANTALLA PEQUEÑA
                // ---------------------------------------------

                if (constraints.maxWidth < 500) {
                  return Column(
                    children: [

                      construirDona(),

                      const SizedBox(
                        height: 15,
                      ),

                      construirLeyenda(),
                    ],
                  );
                }

                // ---------------------------------------------
                // ESCRITORIO
                // ---------------------------------------------

                return Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center,
                  children: [

                    // -----------------------------------------
                    // DONA IZQUIERDA
                    // -----------------------------------------

                    Expanded(
                      child: construirDona(),
                    ),

                    const SizedBox(
                      width: 15,
                    ),

                    // -----------------------------------------
                    // LEYENDA DERECHA
                    // -----------------------------------------

                    construirLeyenda(),
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