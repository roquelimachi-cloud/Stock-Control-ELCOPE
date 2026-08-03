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
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 4,
                ),
                child: Row(
                  children: [

                    Expanded(
                      child: Text(
                        e.descripcion,
                        overflow:
                            TextOverflow.ellipsis,
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
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}