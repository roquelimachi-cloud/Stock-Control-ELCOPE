import 'package:flutter/material.dart';

import '../../models/dashboard/dashboard_summary.dart';
import '../../services/supabase/dashboard_service.dart';
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
    resumen = DashboardService().obtenerResumen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      body: FutureBuilder<DashboardSummary>(
        future: resumen,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(snapshot.error.toString()),
            );
          }

          final data = snapshot.data!;

          return LayoutBuilder(
            builder: (context, constraints) {
              final esMovil = constraints.maxWidth < 700;

              final anchoTarjeta = esMovil
    ? (constraints.maxWidth - 40) / 2
    : (constraints.maxWidth - 48) / 4;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 30),

                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: anchoTarjeta,
                          child: KpiCard(
                            titulo: "Stock",
                            valor: data.stockTotal.toStringAsFixed(0),
                            icono: Icons.inventory,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(
                          width: anchoTarjeta,
                          child: KpiCard(
                            titulo: "Peso",
                            valor:
                                "${data.pesoTotal.toStringAsFixed(2)} kg",
                            icono: Icons.scale,
                            color: Colors.green,
                          ),
                        ),
                        SizedBox(
                          width: anchoTarjeta,
                          child: KpiCard(
                            titulo: "Valor Stock",
                            valor:
                                "US\$ ${data.valorStock.toStringAsFixed(2)}",
                            icono: Icons.attach_money,
                            color: Colors.orange,
                          ),
                        ),
                        SizedBox(
                          width: anchoTarjeta,
                          child: KpiCard(
                            titulo: "Clientes",
                            valor: data.clientes.toString(),
                            icono: Icons.groups,
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      height: 500,
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}