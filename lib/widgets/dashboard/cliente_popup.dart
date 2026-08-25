import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/dashboard/producto_cliente.dart';

class ClientePopup extends StatelessWidget {
  final String cliente;
  final List<ProductoCliente> productos;

  const ClientePopup({
    super.key,
    required this.cliente,
    required this.productos,
  });

  @override
  Widget build(BuildContext context) {
    final moneda = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'US\$ ',
      decimalDigits: 2,
    );

    final peso = productos.fold(
      0.0,
      (suma, e) => suma + e.peso,
    );

    final valor = productos.fold(
      0.0,
      (suma, e) => suma + e.valor,
    );

    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cliente,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),

            const Divider(),

            Text(
              "Valor Stock: ${moneda.format(valor)}",
            ),

            Text(
              "Peso Total: ${peso.toStringAsFixed(2)} Kg",
            ),

            const SizedBox(height: 15),

            const Text(
              "Productos",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            ...productos.take(8).map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.descripcion,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      e.stock.toStringAsFixed(0),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.inventory),
                label: const Text("Ver Stock"),
                onPressed: () {
                  _mostrarStockCompleto(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MOSTRAR STOCK COMPLETO DEL CLIENTE
  // ============================================================

  void _mostrarStockCompleto(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 850,
              maxHeight: 700,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ==================================================
                  // ENCABEZADO
                  // ==================================================

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF1FA),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: Color(0xFF1F4E79),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Stock del cliente',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              cliente,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  const Divider(),

                  const SizedBox(height: 10),

                  // ==================================================
                  // RESUMEN
                  // ==================================================

                  Row(
                    children: [
                      Expanded(
                        child: _ResumenStock(
                          titulo: 'Productos',
                          valor: productos.length
                              .toString(),
                          icono: Icons.inventory_2_outlined,
                          color: const Color(0xFF1F4E79),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: _ResumenStock(
                          titulo: 'Peso',
                          valor:
                              '${productos.fold<double>(0, (s, e) => s + e.peso).toStringAsFixed(2)} Kg',
                          icono: Icons.scale_outlined,
                          color: Colors.orange,
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: _ResumenStock(
                          titulo: 'Valor',
                          valor: NumberFormat.currency(
                            locale: 'en_US',
                            symbol: 'US\$ ',
                            decimalDigits: 0,
                          ).format(
                            productos.fold<double>(
                              0,
                              (s, e) => s + e.valor,
                            ),
                          ),
                          icono:
                              Icons.attach_money_outlined,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // ==================================================
                  // LISTA COMPLETA
                  // ==================================================

                  Expanded(
                    child: productos.isEmpty
                        ? const Center(
                            child: Text(
                              'Este cliente no tiene stock.',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: productos.length,
                            separatorBuilder:
                                (_, __) =>
                                    const Divider(
                              height: 1,
                            ),
                            itemBuilder:
                                (context, index) {
                              final producto =
                                  productos[index];

                              return Padding(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  vertical: 12,
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Container(
                                      padding:
                                          const EdgeInsets
                                              .all(8),
                                      decoration:
                                          BoxDecoration(
                                        color:
                                            const Color(
                                          0xFFEAF1FA,
                                        ),
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          10,
                                        ),
                                      ),
                                      child:
                                          const Icon(
                                        Icons
                                            .inventory_2_outlined,
                                        size: 20,
                                        color: Color(
                                          0xFF1F4E79,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(
                                      width: 12,
                                    ),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          Text(
                                            producto
                                                .descripcion,
                                            style:
                                                const TextStyle(
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                              fontSize: 14,
                                            ),
                                          ),

                                          const SizedBox(
                                            height: 5,
                                          ),

                                     Text(
  'Fecha ingreso: ${producto.fechaIngreso}',
  style: TextStyle(
    fontSize: 11,
    color: Colors.grey,
  ),
),

const SizedBox(height: 3),

Text(
  'Peso: ${producto.peso.toStringAsFixed(2)} Kg',
  style: TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Colors.orange.shade700,
  ),
),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(
                                      width: 10,
                                    ),

                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .end,
                                      children: [
                                        Text(
                                          producto.stock
                                              .toStringAsFixed(
                                            0,
                                          ),
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                            fontSize: 16,
                                            color: Color(
                                              0xFF1F4E79,
                                            ),
                                          ),
                                        ),

                                        const SizedBox(
                                          height: 3,
                                        ),

                                        const Text(
                                          'Stock',
                                          style:
                                              TextStyle(
                                            fontSize: 10,
                                            color:
                                                Colors.grey,
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
          ),
        );
      },
    );
  }
}

// ============================================================
// RESUMEN DEL STOCK
// ============================================================

class _ResumenStock extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;

  const _ResumenStock({
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icono,
            size: 20,
            color: color,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}