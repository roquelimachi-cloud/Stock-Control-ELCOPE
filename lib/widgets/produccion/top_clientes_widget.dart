import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/produccion/top_cliente_model.dart';

class TopClientesWidget extends StatelessWidget {
  final List<TopClienteModel> clientes;

  const TopClientesWidget({
    super.key,
    required this.clientes,
  });

  @override
  Widget build(BuildContext context) {
    final moneda = NumberFormat.currency(
      locale: "en_US",
      symbol: "US\$ ",
      decimalDigits: 0,
    );

    final total = clientes.fold<double>(
      0,
      (suma, e) => suma + e.valor,
    );

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "🏆 Top 10 Clientes",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 25),

            Expanded(
              child: ListView.builder(
                itemCount: clientes.length,
                itemBuilder: (_, i) {

                  final item = clientes[i];
final double porcentaje =
    total == 0
        ? 0.0
        : (item.valor / total).toDouble();

                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: 18,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [

                        Row(
                          children: [

                            Text(
                              switch (i) {
                                0 => "🥇",
                                1 => "🥈",
                                2 => "🥉",
                                _ => "${i + 1}"
                              },
                            ),

                            const SizedBox(width: 8),

                            Expanded(
                              child: Text(
                                item.cliente,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              
                            ),

                          Column(
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [

    Text(
      moneda.format(item.valor),
      style: const TextStyle(
        fontWeight: FontWeight.bold,
      ),
    ),

    Text(
      "${(porcentaje * 100).toStringAsFixed(1)} %",
      style: TextStyle(
        color: switch (i) {
          0 => const Color(0xff00E676),
          1 => const Color(0xff00B0FF),
          2 => const Color(0xffFF9100),
          3 => const Color(0xffD500F9),
          4 => const Color(0xffFF1744),
          5 => const Color(0xff00E5FF),
          6 => const Color(0xff76FF03),
          7 => const Color(0xffFFD600),
          8 => const Color(0xffFF4081),
          _ => const Color(0xff7C4DFF),
        },
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    ),
  ],
),


                          ],
                        ),

                        const SizedBox(height: 8),

                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(30),
                          child: LinearProgressIndicator(
                            minHeight: 14,
                            value: porcentaje.clamp(0.0, 1.0),
                            backgroundColor:
                                Colors.grey.shade300,
                            valueColor:
                                AlwaysStoppedAnimation(
                              switch (i) {
                                 0 => const Color(0xff00E676), // Verde
    1 => const Color(0xff00B0FF), // Azul
    2 => const Color(0xffFF9100), // Naranja
    3 => const Color(0xffD500F9), // Morado
    4 => const Color(0xffFF1744), // Rojo
    5 => const Color(0xff00E5FF), // Celeste
    6 => const Color(0xff76FF03), // Lima
    7 => const Color(0xffFFD600), // Amarillo
    8 => const Color(0xffFF4081), // Rosa
    _ => const Color(0xff7C4DFF), // Violeta
                              },
                            ),
                          ),
                          
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
  }
}