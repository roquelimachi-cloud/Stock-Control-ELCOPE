import 'package:flutter/material.dart';

import '../../models/dashboard/dashboard_summary.dart';
import '../../services/dashboard/dashboard_service.dart';
import '../../widgets/dashboard/kpi_card.dart';

class DashboardScreen extends StatefulWidget {
  final String vendedor;

  const DashboardScreen({
    super.key,
    required this.vendedor,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

  late Future<DashboardSummary> resumen;

  @override
  void initState() {
    super.initState();

    resumen = DashboardService.obtenerResumen(
      vendedor: widget.vendedor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: FutureBuilder<DashboardSummary>(
          future: resumen,

          builder: (context, snapshot) {

            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(snapshot.error.toString()),
              );
            }

            final data = snapshot.data!;

            return Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                const Text(
                  "Dashboard Comercial",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  "Asesor: ${data.asesor}",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 30),

                Row(
                  children: [

                    Expanded(
                      child: KpiCard(
                        titulo: "Stock",
                        valor: data.stockTotal
                            .toStringAsFixed(0),
                        icono: Icons.inventory,
                        color: Colors.blue,
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: KpiCard(
                        titulo: "Peso",
                        valor:
                            "${data.pesoTotal.toStringAsFixed(2)} kg",
                        icono: Icons.scale,
                        color: Colors.green,
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: KpiCard(
                        titulo: "Valor Stock",
                        valor:
                            "US\$ ${data.valorStock.toStringAsFixed(2)}",
                        icono:
                            Icons.attach_money,
                        color: Colors.orange,
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: KpiCard(
                        titulo: "Clientes",
                        valor:
                            data.clientes.toString(),
                        icono: Icons.groups,
                        color: Colors.purple,
                      ),
                    ),

                  ],
                ),

                const SizedBox(height: 30),

                Expanded(
                  child: Card(
                    child: Center(
                      child: Text(
                        "Aquí irá el gráfico de Top Clientes",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),

              ],
            );
          },
        ),
      ),
    );
  }
}