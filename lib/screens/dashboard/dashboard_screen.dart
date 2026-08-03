import 'package:flutter/material.dart';

import '../../models/dashboard/dashboard_summary.dart';
import '../../services/supabase/dashboard_service.dart';
import '../../utils/formato.dart';
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

          return LayoutBuilder(
            builder: (context, constraints) {
              final esMovil = constraints.maxWidth < 700;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  const Text(
  "MICHAEL PRUEBA",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "Asesor: ${data.asesor}",
                      style: const TextStyle(
                        fontSize: 17,
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 30),

                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: esMovil ? 2 : 4,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                      childAspectRatio: esMovil ? 0.95 : 1.10,
                      children: [
                        KpiCard(
                          titulo: "Stock Total",
                          valor: Formato.entero(data.stockTotal),
                          icono: Icons.inventory_2,
                          color: Colors.blue,
                        ),

                        KpiCard(
                          titulo: "Peso Total",
                          valor: Formato.peso(data.pesoTotal),
                          icono: Icons.scale,
                          color: Colors.orange,
                        ),

                        KpiCard(
                          titulo: "Valor Stock",
                          valor: Formato.moneda(data.valorStock),
                          icono: Icons.attach_money,
                          color: Colors.green,
                        ),

                        KpiCard(
                          titulo: "Clientes",
                          valor: Formato.entero(data.clientes),
                          icono: Icons.groups,
                          color: Colors.purple,
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      height: 500,
                      child: Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            "Aquí irá el gráfico de Top Clientes",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 18,
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