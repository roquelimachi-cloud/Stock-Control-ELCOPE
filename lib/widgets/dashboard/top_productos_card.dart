import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/dashboard/producto_top.dart';

class TopProductosCard extends StatelessWidget {
  final List<ProductoTop> productos;

  const TopProductosCard({
    super.key,
    required this.productos,
  });

  @override
  Widget build(BuildContext context) {
    final moneda = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'US\$ ',
      decimalDigits: 0,
    );

    final maximo =
        productos.isEmpty ? 1 : productos.first.valor;

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

            const Row(
              children: [

                Icon(
                  Icons.inventory,
                  color: Colors.blue,
                ),

                SizedBox(width: 10),

                Text(
                  "Top Productos",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

              ],
            ),

            const SizedBox(height: 20),

            ...productos.map((producto) {

              final porcentaje =
                  producto.valor / maximo;

              return Padding(
                padding:
                    const EdgeInsets.only(bottom: 18),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Text(
                      producto.descripcion,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: porcentaje,
                        minHeight: 12,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      moneda.format(producto.valor),
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                  ],
                ),
              );
            }),

          ],
        ),
      ),
    );
  }
}