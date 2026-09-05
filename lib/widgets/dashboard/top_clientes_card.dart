import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/dashboard/cliente_top.dart';
import '../../screens/dashboard/top_clientes_preview_page.dart';
import '../../screens/dashboard/todos_clientes_page.dart';
import '../../services/pdf/cliente_pdf_service.dart';
import 'cliente_hover.dart';

class TopClientesCard extends StatelessWidget {
  final List<ClienteTop> clientes;

  const TopClientesCard({
    super.key,
    required this.clientes,
  });

  @override
  Widget build(BuildContext context) {
    final moneda = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'US\$ ',
      decimalDigits: 0,
    );

    if (clientes.isEmpty) {
      return Card(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'No existen clientes',
            ),
          ),
        ),
      );
    }

    // =========================================================
    // TOP 10
    // =========================================================

    final top10 = clientes.take(10).toList();

    // =========================================================
    // TOTAL GENERAL
    // =========================================================

    double total = 0;

    for (final cliente in clientes) {
      total += cliente.valorStock;
    }

    // =========================================================
    // VALOR MAXIMO PARA LAS BARRAS
    // =========================================================

    double maximo = 0;

    if (top10.isNotEmpty) {
      maximo = top10.first.valorStock;
    }

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // ===================================================
            // TITULO
            // ===================================================

            Row(
              children: [
                const Icon(
                  Icons.emoji_events,
                  color: Colors.amber,
                  size: 28,
                ),

                const SizedBox(width: 10),

                const Expanded(
                  child: Text(
                    'Top 10 Clientes',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // =================================================
                // VER TODOS
                // =================================================

                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) {
                          return TopClientesPreviewPage(
                            clientes: clientes,
                          );
                        },
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.arrow_forward,
                    size: 18,
                  ),
                  label: const Text(
                    'Ver todos',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ===================================================
            // TOP 10
            // ===================================================

            for (int index = 0;
                index < top10.length;
                index++)
              _clienteItem(
                cliente: top10[index],
                index: index,
                total: total,
                maximo: maximo,
                moneda: moneda,
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================
  // CLIENTE
  // ===========================================================

  Widget _clienteItem({
    required ClienteTop cliente,
    required int index,
    required double total,
    required double maximo,
    required NumberFormat moneda,
  }) {
    // ===========================================================
    // PORCENTAJE
    // ===========================================================

    final porcentaje = total == 0
        ? 0.0
        : (cliente.valorStock / total) * 100;

    // ===========================================================
    // PROGRESO
    // ===========================================================

    final progreso = maximo == 0
        ? 0.0
        : cliente.valorStock / maximo;

    // ===========================================================
    // PESO EN TONELADAS
    // ===========================================================

    final toneladas = cliente.pesoCobre / 1000;

    return ClienteHover(
      cliente: cliente.cliente,

      child: Container(
        margin: const EdgeInsets.only(
          bottom: 14,
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            // ===================================================
            // NOMBRE + MONTO
            // ===================================================

            Row(
              children: [
                // ------------------------------------------------
                // NUMERO
                // ------------------------------------------------

                Container(
                  width: 32,
                  height: 32,

                  alignment:
                      Alignment.center,

                  decoration:
                      BoxDecoration(
                    color: Colors.blue
                        .withOpacity(0.08),

                    shape:
                        BoxShape.circle,

                    border:
                        Border.all(
                      color: Colors.blue
                          .withOpacity(0.35),
                    ),
                  ),

                  child: Text(
                    '${index + 1}',

                    style:
                        const TextStyle(
                      color:
                          Colors.blue,

                      fontSize: 12,

                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                // ------------------------------------------------
                // CLIENTE
                // ------------------------------------------------

                Expanded(
                  child: Text(
                    cliente.cliente,

                    maxLines: 1,

                    overflow:
                        TextOverflow.ellipsis,

                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,

                      fontSize: 14,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                // ------------------------------------------------
                // MONTO
                // ------------------------------------------------

                Text(
                  moneda.format(
                    cliente.valorStock,
                  ),

                  style:
                      const TextStyle(
                    color:
                        Colors.green,

                    fontWeight:
                        FontWeight.bold,

                    fontSize: 13,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 4,
            ),

            // ===================================================
            // PORCENTAJE
            // ===================================================

            Align(
              alignment:
                  Alignment.centerRight,

              child: Text(
                '${porcentaje.toStringAsFixed(1)} %',

                style:
                    const TextStyle(
                  color:
                      Colors.blue,

                  fontSize: 11,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(
              height: 2,
            ),

            // ===================================================
            // PESO DE COBRE
            // ===================================================

            Align(
              alignment:
                  Alignment.centerRight,

              child: Text(
                '${toneladas.toStringAsFixed(2)} t',

                style:
                    const TextStyle(
                  color:
                      Colors.orange,

                  fontSize: 11,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(
              height: 5,
            ),

            // ===================================================
            // BARRA
            // ===================================================

            ClipRRect(
              borderRadius:
                  BorderRadius.circular(8),

              child:
                  LinearProgressIndicator(
                value:
                    progreso,

                minHeight: 12,

                backgroundColor:
                    const Color(
                  0xffE5E7EB,
                ),

                color:
                    Colors.indigo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}