import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/dashboard/stock_vendedor.dart';

class StockVendedorCard extends StatelessWidget {
  final List<StockVendedor> vendedores;

  const StockVendedorCard({
    super.key,
    required this.vendedores,
  });

  @override
  Widget build(BuildContext context) {
    final moneda = NumberFormat(
      '#,##0',
      'en_US',
    );

    final pesoFormato = NumberFormat(
      '#,##0.00',
      'en_US',
    );

    if (vendedores.isEmpty) {
      return const SizedBox.shrink();
    }

    // =========================================================
    // COLORES POR ASESOR
    // =========================================================

    const colores = <Color>[
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

    // =========================================================
    // TOTAL
    // =========================================================

    final total = vendedores.fold<double>(
      0,
      (suma, vendedor) => suma + vendedor.valorStock,
    );

    // =========================================================
    // PRIMEROS 8
    // =========================================================

    final mostrar = vendedores.take(8).toList();

    // =========================================================
    // MAYOR STOCK
    // =========================================================

    final mayorStock = vendedores.isEmpty
        ? 0.0
        : vendedores
            .map((e) => e.valorStock)
            .reduce(
              (a, b) => a > b ? a : b,
            );

    return Card(
      elevation: 5,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xffFCFCFE),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xffE3E8F2),
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // =================================================
            // ENCABEZADO
            // =================================================

            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xff2563EB)
                        .withOpacity(0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xff2563EB)
                          .withOpacity(0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xff2563EB),
                    size: 21,
                  ),
                ),

                const SizedBox(width: 10),

                const Expanded(
                  child: Text(
                    'Stock por Vendedor',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff20242D),
                    ),
                  ),
                ),

                // =================================================
                // VER TODOS
                // =================================================

                if (vendedores.length > 8)
                  TextButton.icon(
                    onPressed: () {
                      _mostrarTodos(
                        context,
                        vendedores,
                        moneda,
                        pesoFormato,
                        colores,
                      );
                    },
                    icon: const Icon(
                      Icons.arrow_forward,
                      size: 17,
                    ),
                    label: const Text(
                      'Ver todos',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          const Color(0xff2563EB),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 18),

            // =================================================
            // VENDEDORES
            // =================================================

            ...mostrar.asMap().entries.map(
              (entry) {
                final index = entry.key;
                final vendedor = entry.value;

                // ---------------------------------------------
                // COLOR DEL ASESOR
                // ---------------------------------------------

                final color =
                    colores[index % colores.length];

                // ---------------------------------------------
                // PORCENTAJE DE LA BARRA
                // ---------------------------------------------

                final porcentaje =
                    mayorStock == 0
                        ? 0.0
                        : vendedor.valorStock /
                            mayorStock;

                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 14,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [

                      // =========================================
                      // NOMBRE + VALOR + PESO
                      // =========================================

                      Row(
                        children: [

                          // -------------------------------------
                          // NÚMERO
                          // -------------------------------------

                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color:
                                  color.withOpacity(0.08),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    color.withOpacity(0.50),
                                width: 1.2,
                              ),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(width: 9),

                          // -------------------------------------
                          // NOMBRE
                          // -------------------------------------

                          Expanded(
                            child: Text(
                              vendedor.vendedor,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff252A34),
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          // -------------------------------------
                          // VALOR + PESO
                          // -------------------------------------

                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.end,
                            children: [

                              Text(
                                'US\$ ${moneda.format(vendedor.valorStock)}',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 3),

                              Text(
                                '${pesoFormato.format(vendedor.peso)} Kg',
                                style: TextStyle(
                                  color:
                                      Colors.grey.shade600,
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // =========================================
                      // BARRA DE FONDO
                      // =========================================

                      Container(
                        height: 9,
                        decoration: BoxDecoration(
                          color: const Color(0xffE9EDF4),
                          borderRadius:
                              BorderRadius.circular(10),
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
                                  BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      color.withOpacity(0.25),
                                  blurRadius: 5,
                                  spreadRadius: 0.3,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // VER TODOS
  // =========================================================

  void _mostrarTodos(
    BuildContext context,
    List<StockVendedor> vendedores,
    NumberFormat moneda,
    NumberFormat pesoFormato,
    List<Color> colores,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 600,
              maxHeight: 650,
            ),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xffFCFCFE),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xffE3E8F2),
              ),
            ),
            child: Column(
              children: [

                // =============================================
                // TÍTULO
                // =============================================

                Row(
                  children: [

                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xff2563EB)
                            .withOpacity(0.08),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xff2563EB)
                              .withOpacity(0.25),
                        ),
                      ),
                      child: const Icon(
                        Icons.people,
                        color: Color(0xff2563EB),
                      ),
                    ),

                    const SizedBox(width: 10),

                    const Expanded(
                      child: Text(
                        'Stock por Vendedor',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(
                        Icons.close,
                      ),
                    ),
                  ],
                ),

                const Divider(),

                // =============================================
                // LISTA
                // =============================================

                Expanded(
                  child: ListView.builder(
                    itemCount: vendedores.length,
                    itemBuilder: (
                      context,
                      index,
                    ) {
                      final vendedor =
                          vendedores[index];

                      final color =
                          colores[
                              index % colores.length];

                      return Container(
                        margin: const EdgeInsets.only(
                          bottom: 8,
                        ),
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                color.withOpacity(0.20),
                          ),
                        ),
                        child: Row(
                          children: [

                            // =================================
                            // NÚMERO
                            // =================================

                            Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color:
                                    color.withOpacity(0.08),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      color.withOpacity(0.50),
                                ),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: color,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),

                            const SizedBox(width: 10),

                            // =================================
                            // NOMBRE
                            // =================================

                            Expanded(
                              child: Text(
                                vendedor.vendedor,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),

                            const SizedBox(width: 10),

                            // =================================
                            // VALOR + PESO
                            // =================================

                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [

                                Text(
                                  'US\$ ${moneda.format(vendedor.valorStock)}',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 3),

                                Text(
                                  '${pesoFormato.format(vendedor.peso)} Kg',
                                  style: TextStyle(
                                    color:
                                        Colors.grey.shade600,
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}