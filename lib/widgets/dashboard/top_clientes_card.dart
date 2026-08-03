import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/dashboard/cliente_top.dart';
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

    final double maximo =
        clientes.isEmpty ? 1 : clientes.first.valorStock;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Row(
              children: [

                Icon(
                  Icons.emoji_events,
                  color: Colors.amber,
                  size: 28,
                ),

                SizedBox(width: 10),

                Text(
                  "Top Clientes",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

              ],
            ),

            const SizedBox(height: 20),

            if (clientes.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "No existen clientes",
                  ),
                ),
              ),

            ...clientes.map((cliente) {

              final porcentaje =
                  cliente.valorStock / maximo;

              return ClienteHover(
                cliente: cliente.cliente,

                child: Container(
                  margin:
                      const EdgeInsets.only(bottom: 16),

                  padding:
                      const EdgeInsets.all(14),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(14),

                    border: Border.all(
                      color: Colors.grey.shade300,
                    ),
                  ),

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [

                      Row(
                        children: [

                          Expanded(
                            child: Text(
                              cliente.cliente,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Text(
                            moneda.format(
                              cliente.valorStock,
                            ),
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: porcentaje,
                          minHeight: 12,
                          backgroundColor:
                              Colors.grey.shade200,
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}