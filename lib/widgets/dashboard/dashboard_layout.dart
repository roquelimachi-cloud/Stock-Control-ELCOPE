import 'package:flutter/material.dart';

import '../../models/dashboard/dashboard_summary.dart';
import '../../models/dashboard/clase_resumen.dart';
import '../../models/dashboard/cliente_top.dart';
import '../../models/dashboard/peso_clase_resumen.dart';

import 'dashboard_kpis.dart';
import 'clase_pie_chart.dart';
import 'peso_clase_pie_chart.dart';
import 'top_clientes_card.dart';

class DashboardLayout extends StatelessWidget {
  final DashboardSummary resumen;

  final List<ClaseResumen> clases;

  final List<PesoClaseResumen> pesoClases;

  final List<ClienteTop> topClientes;

  const DashboardLayout({
    super.key,
    required this.resumen,
    required this.clases,
    required this.pesoClases,
    required this.topClientes,
  });

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;

    final esMovil = ancho < 900;

    // =========================================================
    // ESCRITORIO
    // =========================================================

    if (!esMovil) {
      return Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [

          // ===================================================
          // KPI
          // ===================================================

          DashboardKpis(
            resumen: resumen,
          ),

          const SizedBox(height: 30),

          // ===================================================
          // DONAS
          // ===================================================

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [

              // =================================================
              // DONA 1
              // =================================================

              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 650,
                  child: ClasePieChart(
                    datos: clases,
                  ),
                ),
              ),

              const SizedBox(width: 25),

              // =================================================
              // DONA 2
              // =================================================

              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 650,
                  child: PesoClasePieChart(
                    datos: pesoClases,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),

          // ===================================================
          // TOP CLIENTES
          // ===================================================

          TopClientesCard(
            clientes: topClientes,
          ),
        ],
      );
    }

    // =========================================================
    // CELULAR
    // =========================================================

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [

        // =====================================================
        // KPI
        // =====================================================

        DashboardKpis(
          resumen: resumen,
        ),

        const SizedBox(height: 30),

        // =====================================================
        // DONA 1
        // =====================================================

        ClasePieChart(
          datos: clases,
        ),

        const SizedBox(height: 20),

        // =====================================================
        // DONA 2
        // =====================================================

        PesoClasePieChart(
          datos: pesoClases,
        ),

        const SizedBox(height: 20),

        // =====================================================
        // TOP CLIENTES
        // =====================================================

        TopClientesCard(
          clientes: topClientes,
        ),
      ],
    );
  }
}