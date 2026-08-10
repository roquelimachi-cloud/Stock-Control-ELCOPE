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
    Color(0xff2563EB), // Azul
    Color(0xff7C3AED), // Violeta
    Color(0xffF59E0B), // Ámbar
    Color(0xff10B981), // Verde
    Color(0xff06B6D4), // Cyan
    Color(0xffEF4444), // Rojo
    Color(0xffEC4899), // Rosa
    Color(0xff8B5CF6), // Morado
    Color(0xff14B8A6), // Turquesa
    Color(0xffF97316), // Naranja
  ];

  // ============================================================
  // AGRUPAR PRODUCCIÓN POR VENDEDOR
  // ============================================================

  List<Map<String, dynamic>> _agruparPorVendedor() {
    final Map<String, double> mapa = {};

    for (final produccion in producciones) {
      final vendedor =
          produccion.representante.trim();

      if (vendedor.isEmpty) {
        continue;
      }

      final valor =
          produccion.valorNeto ?? 0;

      mapa.update(
        vendedor,
        (actual) => actual + valor,
        ifAbsent: () => valor,
      );
    }

    final resultado = mapa.entries
        .map(
          (e) => {
            'vendedor': e.key,
            'valor': e.value,
          },
        )
        .toList();

    // Mayor producción primero
    resultado.sort(
      (a, b) =>
          (b['valor'] as double)
              .compareTo(a['valor'] as double),
    );

    return resultado;
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
  // BARRA DE VENDEDOR
  // ============================================================

  Widget _vendedorItem({
    required int index,
    required String vendedor,
    required double valor,
    required double maximo,
    required bool esMovil,
  }) {
    final color =
        colores[index % colores.length];

    final porcentaje =
        maximo <= 0 ? 0.0 : valor / maximo;

    return Padding(
      padding: EdgeInsets.only(
        bottom: esMovil ? 14 : 12,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ======================================================
          // NOMBRE + VALOR
          // ======================================================

          Row(
            children: [
              Container(
                width: esMovil ? 30 : 32,
                height: esMovil ? 30 : 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.10),
                  border: Border.all(
                    color: color.withOpacity(0.65),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: esMovil ? 12 : 13,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  vendedor,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: esMovil ? 14 : 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xff202124),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Text(
                _formatear(valor),
                style: TextStyle(
                  color: color,
                  fontSize: esMovil ? 12 : 13,
                  fontWeight: FontWeight.bold,
                ),
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
              color: const Color(0xffE9EDF5),
              borderRadius:
                  BorderRadius.circular(20),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor:
                  porcentaje.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius:
                      BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.25),
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

  @override
  Widget build(BuildContext context) {
    final datos = _agruparPorVendedor();

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

    final maximo =
        datos.first['valor'] as double;

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
            side: BorderSide(
              color: const Color(0xffE3E8F2),
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
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            const Color(0xff2563EB)
                                .withOpacity(0.10),
                        border: Border.all(
                          color: const Color(
                            0xff2563EB,
                          ).withOpacity(0.35),
                        ),
                      ),
                      child: const Icon(
                        Icons.factory_outlined,
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
                              esMovil ? 18 : 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),

                    if (datos.length > 8)
                      TextButton.icon(
                        onPressed: () {
                          _mostrarTodos(
                            context,
                            datos,
                            maximo,
                          );
                        },
                        icon: const Icon(
                          Icons.arrow_forward,
                          size: 18,
                        ),
                        label:
                            const Text('Ver todos'),
                      ),
                  ],
                ),

                SizedBox(
                  height: esMovil ? 16 : 20,
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
                      maximo: maximo,
                      esMovil: esMovil,
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
            MediaQuery.of(context).size.width;

        return AlertDialog(
          title: const Text(
            'Producción por Vendedor',
          ),
          content: SizedBox(
            width:
                ancho > 700 ? 650 : double.infinity,
            height:
                MediaQuery.of(context)
                        .size
                        .height *
                    0.65,
            child: ListView.builder(
              itemCount: datos.length,
              itemBuilder: (context, index) {
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
                  maximo: maximo,
                  esMovil: ancho < 700,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}