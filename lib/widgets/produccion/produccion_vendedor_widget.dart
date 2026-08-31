import 'package:flutter/material.dart';

import '../../models/produccion/produccion_model.dart';

class ProduccionVendedorWidget extends StatelessWidget {
  final List<ProduccionModel> producciones;

  const ProduccionVendedorWidget({
    super.key,
    required this.producciones,
  });

  // ============================================================
  // COLORES POR VENDEDOR
  // ============================================================

  static const List<Color> colores = [
    Color(0xff2563EB),
    Color(0xff7C3AED),
    Color(0xffF59E0B),
    Color(0xff10B981),
    Color(0xff06B6D4),
    Color(0xffEF4444),
    Color(0xffEC4899),
    Color(0xff8B5CF6),
    Color(0xff14B8A6),
    Color(0xffF97316),
  ];

  // ============================================================
  // AGRUPAR PRODUCCIÓN POR VENDEDOR
  // ============================================================

  List<Map<String, dynamic>> _agruparPorVendedor() {
    final Map<String, Map<String, double>> mapa = {};

    for (final produccion in producciones) {
      final vendedor = produccion.representante.trim();

      if (vendedor.isEmpty) {
        continue;
      }

      final valor = _toDouble(produccion.valorNeto);
      final peso = _toDouble(produccion.pesoCobre);

      if (!mapa.containsKey(vendedor)) {
        mapa[vendedor] = {
          'valor': 0.0,
          'peso': 0.0,
        };
      }

      mapa[vendedor]!['valor'] =
          mapa[vendedor]!['valor']! + valor;

      mapa[vendedor]!['peso'] =
          mapa[vendedor]!['peso']! + peso;
    }

    final resultado = mapa.entries.map((e) {
      return {
        'vendedor': e.key,
        'valor': e.value['valor'] ?? 0.0,
        'peso': e.value['peso'] ?? 0.0,
      };
    }).toList();

    // Ordenar de mayor a menor valor
    resultado.sort(
      (a, b) =>
          (b['valor'] as double).compareTo(
        a['valor'] as double,
      ),
    );

    return resultado;
  }

  // ============================================================
  // CONVERTIR A DOUBLE
  // ============================================================

  double _toDouble(dynamic valor) {
    if (valor == null) {
      return 0.0;
    }

    if (valor is num) {
      return valor.toDouble();
    }

    return double.tryParse(
          valor
              .toString()
              .replaceAll(',', '')
              .trim(),
        ) ??
        0.0;
  }

  // ============================================================
  // FORMATO MONETARIO
  // ============================================================

  String _formatear(double valor) {
    return 'US\$ ${valor.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
        )}';
  }

  // ============================================================
  // FORMATO DE PESO
  //
  // Ejemplo:
  // 48765.17  -> 48,765.17
  // 12942.33  -> 12,942.33
  // 493.98    -> 493.98
  // ============================================================

  String _formatearPeso(double peso) {
    final partes = peso.toStringAsFixed(2).split('.');

    final entero = partes[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );

    return '$entero.${partes[1]}';
  }

  // ============================================================
  // ITEM DEL VENDEDOR
  // ============================================================

  Widget _vendedorItem({
    required int index,
    required String vendedor,
    required double valor,
    required double peso,
    required double maximo,
    required bool esMovil,
  }) {
    final color =
        colores[index % colores.length];

    final porcentaje =
        maximo <= 0
            ? 0.0
            : valor / maximo;

    return Padding(
      padding: EdgeInsets.only(
        bottom: esMovil ? 14 : 12,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ======================================================
          // NOMBRE + VALOR + PESO
          // ======================================================

          Row(
            children: [
              // --------------------------------------------------
              // NUMERO
              // --------------------------------------------------

              Container(
                width: esMovil ? 30 : 32,
                height: esMovil ? 30 : 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      color.withOpacity(0.10),
                  border: Border.all(
                    color:
                        color.withOpacity(0.65),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: color,
                    fontWeight:
                        FontWeight.bold,
                    fontSize:
                        esMovil ? 12 : 13,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // --------------------------------------------------
              // NOMBRE DEL VENDEDOR
              // --------------------------------------------------

              Expanded(
                child: Text(
                  vendedor,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize:
                        esMovil ? 14 : 15,
                    fontWeight:
                        FontWeight.w500,
                    color:
                        const Color(0xff202124),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // --------------------------------------------------
              // VALOR + PESO
              // --------------------------------------------------

              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatear(valor),
                    style: TextStyle(
                      color: color,
                      fontSize:
                          esMovil ? 12 : 13,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    '${_formatearPeso(peso)} Kg',
                    style: TextStyle(
                      color:
                          color.withOpacity(0.85),
                      fontSize:
                          esMovil ? 10 : 11,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ======================================================
          // BARRA
          // ======================================================

          Container(
            height: esMovil ? 9 : 10,
            width: double.infinity,
            decoration: BoxDecoration(
              color:
                  const Color(0xffE9EDF5),
              borderRadius:
                  BorderRadius.circular(20),
            ),
            child: FractionallySizedBox(
              alignment:
                  Alignment.centerLeft,
              widthFactor:
                  porcentaje.clamp(
                0.0,
                1.0,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          color.withOpacity(
                        0.25,
                      ),
                      blurRadius: 5,
                      offset:
                          const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final datos =
        _agruparPorVendedor();

    // ==========================================================
    // SIN DATOS
    // ==========================================================

    if (datos.isEmpty) {
      return Card(
        elevation: 5,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(18),
        ),
        child: const Padding(
          padding: EdgeInsets.all(25),
          child: Center(
            child: Text(
              'No hay producción pendiente por vendedor.',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );
    }

    // ==========================================================
    // VALOR MÁXIMO
    // ==========================================================

    final maximo =
        datos.first['valor'] as double;

    // ==========================================================
    // RESPONSIVE
    // ==========================================================

    return LayoutBuilder(
      builder: (context, constraints) {
        final esMovil =
            constraints.maxWidth < 700;

        final cantidadVisible =
            datos.length > 8
                ? 8
                : datos.length;

        return Card(
          elevation: 5,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(18),
            side: const BorderSide(
              color:
                  Color(0xffE3E8F2),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(
              esMovil ? 16 : 20,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // ==================================================
                // ENCABEZADO
                // ==================================================

                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape.circle,
                        color:
                            const Color(
                          0xff2563EB,
                        ).withOpacity(0.10),
                        border: Border.all(
                          color:
                              const Color(
                            0xff2563EB,
                          ).withOpacity(0.35),
                        ),
                      ),
                      child: const Icon(
                        Icons
                            .factory_outlined,
                        color:
                            Color(0xff2563EB),
                        size: 22,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        'Producción por Vendedor',
                        style: TextStyle(
                          fontSize:
                              esMovil
                                  ? 18
                                  : 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),

                    // ==============================================
                    // VER TODOS
                    // ==============================================

                    if (datos.length > 8)
                      TextButton.icon(
                        onPressed: () {
                          _mostrarTodos(
                            context,
                            datos,
                            maximo,
                          );
                        },
                        icon:
                            const Icon(
                          Icons.arrow_forward,
                          size: 18,
                        ),
                        label:
                            const Text(
                          'Ver todos',
                        ),
                      ),
                  ],
                ),

                SizedBox(
                  height:
                      esMovil ? 16 : 20,
                ),

                // ==================================================
                // VENDEDORES
                // ==================================================

                ...List.generate(
                  cantidadVisible,
                  (index) {
                    final item =
                        datos[index];

                    return _vendedorItem(
                      index: index,
                      vendedor:
                          item['vendedor']
                              as String,
                      valor:
                          item['valor']
                              as double,
                      peso:
                          item['peso']
                              as double,
                      maximo:
                          maximo,
                      esMovil:
                          esMovil,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // VER TODOS
  // ============================================================

  void _mostrarTodos(
    BuildContext context,
    List<Map<String, dynamic>> datos,
    double maximo,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final ancho =
            MediaQuery.of(context)
                .size
                .width;

        return AlertDialog(
          title: const Text(
            'Producción por Vendedor',
          ),

          content: SizedBox(
            width:
                ancho > 700
                    ? 650
                    : double.infinity,

            height:
                MediaQuery.of(context)
                        .size
                        .height *
                    0.65,

            child:
                ListView.builder(
              itemCount:
                  datos.length,

              itemBuilder:
                  (context, index) {
                final item =
                    datos[index];

                return _vendedorItem(
                  index: index,
                  vendedor:
                      item['vendedor']
                          as String,
                  valor:
                      item['valor']
                          as double,
                  peso:
                      item['peso']
                          as double,
                  maximo:
                      maximo,
                  esMovil:
                      ancho < 700,
                );
              },
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                );
              },
              child:
                  const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}