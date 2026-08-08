import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../models/produccion/grafico_produccion.dart';

class DonaProduccion extends StatelessWidget {
  final String titulo;
  final List<GraficoProduccion> datos;

  final String? centroValor;
  final String? centroTexto;

  final bool mostrarPesoEnLeyenda;
  final int columnasLeyenda;

  const DonaProduccion({
    super.key,
    required this.titulo,
    required this.datos,
    this.centroValor,
    this.centroTexto,
    this.mostrarPesoEnLeyenda = false,
    this.columnasLeyenda = 1,
  });

  @override
  Widget build(BuildContext context) {
    final double total = datos.fold<double>(
      0,
      (suma, e) => suma + e.valor,
    );

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

    // =========================================================
    // NOMBRE
    // =========================================================

    String nombreMostrar(String nombre) {
      final texto = nombre.trim().toUpperCase();

      if (texto.startsWith('CLASE ')) {
        return 'CL${texto.substring(6).trim()}';
      }

      if (texto.startsWith('CLASE')) {
        return 'CL${texto.substring(5).trim()}';
      }

      return texto;
    }

    // =========================================================
    // CENTRO DE LA DONA
    // =========================================================

    Widget construirCentro(double anchoGrafico) {
      /*
       * El centro se adapta al tamaño real del gráfico.
       * Esto permite que funcione tanto en Windows/Web
       * como en celular.
       */

      final anchoCentro = (anchoGrafico * 0.58)
          .clamp(110.0, 210.0);

      final textoCentro =
          centroValor ?? total.toStringAsFixed(0);

      /*
       * Tamaño adaptable según la cantidad de caracteres.
       */

      double tamano;

      if (textoCentro.length >= 12) {
        tamano = 22;
      } else if (textoCentro.length >= 10) {
        tamano = 24;
      } else if (textoCentro.length >= 8) {
        tamano = 27;
      } else {
        tamano = 31;
      }

      return SizedBox(
        width: anchoCentro,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                textoCentro,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: tamano,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 3),

            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                centroTexto ?? 'Total',
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // =========================================================
    // GRÁFICO
    // =========================================================

    Widget construirGrafico(double anchoGrafico) {
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
            widget: construirCentro(
              anchoGrafico,
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

            // DONA GRANDE
            radius: '98%',

            // AGUJERO GRANDE PARA EL VALOR CENTRAL
            innerRadius: '60%',

            explode: false,

            animationDuration: 1200,
          ),
        ],
      );
    }

    // =========================================================
    // ITEM DE LEYENDA
    // =========================================================

    Widget construirItemLeyenda(
      GraficoProduccion item,
      int index,
    ) {
      final toneladas = item.valor / 1000;

      final porcentaje = total == 0
          ? 0
          : (item.valor / total) * 100;

      final nombre = mostrarPesoEnLeyenda
          ? nombreMostrar(item.nombre)
          : item.nombre;

      final valor = mostrarPesoEnLeyenda
          ? '${toneladas.toStringAsFixed(2)} t'
          : '${porcentaje.toStringAsFixed(1)}%';

      return Row(
        children: [
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: colores[index % colores.length],
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(width: 8),

          Text(
            valor,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    // =========================================================
    // LEYENDA
    // =========================================================

    Widget construirLeyenda() {
      // -------------------------------------------------------
      // UNA COLUMNA
      // -------------------------------------------------------

      if (columnasLeyenda <= 1) {
        return Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children:
              datos.asMap().entries.map(
            (entry) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 7,
                ),
                child:
                    construirItemLeyenda(
                  entry.value,
                  entry.key,
                ),
              );
            },
          ).toList(),
        );
      }

      // -------------------------------------------------------
      // DOS COLUMNAS
      // -------------------------------------------------------

      return GridView.builder(
        padding: EdgeInsets.zero,

        physics:
            const NeverScrollableScrollPhysics(),

        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 8,
          childAspectRatio: 3.8,
        ),

        itemCount: datos.length,

        itemBuilder: (context, index) {
          return construirItemLeyenda(
            datos[index],
            index,
          );
        },
      );
    }

    // =========================================================
    // CARD
    // =========================================================

    return Card(
      elevation: 7,

      shadowColor: Colors.black26,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),

      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          22,
          18,
          22,
          18,
        ),

        child: Column(
          children: [
            // ===================================================
            // TITULO
            // ===================================================

            Align(
              alignment: Alignment.centerLeft,

              child: Text(
                titulo,

                maxLines: 1,

                overflow:
                    TextOverflow.ellipsis,

                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 5),

            // ===================================================
            // CONTENIDO RESPONSIVE
            // ===================================================

            Expanded(
              child: LayoutBuilder(
                builder:
                    (context, constraints) {
                  final ancho =
                      constraints.maxWidth;

                  // =================================================
                  // CELULAR
                  // =================================================

                  if (ancho < 650) {
                    return Column(
                      children: [
                        Expanded(
                          flex: 6,

                          child: LayoutBuilder(
                            builder:
                                (context, grafico) {
                              return construirGrafico(
                                grafico.maxWidth,
                              );
                            },
                          ),
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Expanded(
                          flex: 4,

                          child:
                              SingleChildScrollView(
                            child:
                                construirLeyenda(),
                          ),
                        ),
                      ],
                    );
                  }

                  // =================================================
                  // WINDOWS / WEB / TABLET
                  // =================================================

                  return Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.center,

                    children: [
                      // ---------------------------------------------
                      // DONA
                      // ---------------------------------------------

                      Expanded(
                        flex: 6,

                        child: LayoutBuilder(
                          builder:
                              (context, grafico) {
                            return construirGrafico(
                              grafico.maxWidth,
                            );
                          },
                        ),
                      ),

                      const SizedBox(
                        width: 22,
                      ),

                      // ---------------------------------------------
                      // LEYENDA
                      // ---------------------------------------------

                      Expanded(
                        flex: 5,

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