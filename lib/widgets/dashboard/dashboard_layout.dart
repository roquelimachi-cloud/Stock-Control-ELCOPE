import 'package:flutter/material.dart';

import '../../models/dashboard/dashboard_summary.dart';
import '../../models/dashboard/clase_resumen.dart';
import '../../models/dashboard/cliente_top.dart';

import 'dashboard_kpis.dart';
import 'clase_pie_chart.dart';
import 'top_clientes_card.dart';

class DashboardLayout extends StatelessWidget {
  final DashboardSummary resumen;
  final List<ClaseResumen> clases;
  final List<ClienteTop> topClientes;

  const DashboardLayout({
    super.key,
    required this.resumen,
    required this.clases,
    required this.topClientes,
  });

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;

    final esMovil = ancho < 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        //--------------------------------------
        // KPI
        //--------------------------------------

        DashboardKpis(
          resumen: resumen,
        ),

        const SizedBox(height: 30),

        //--------------------------------------
        // SEGUNDA FILA
        //--------------------------------------

        if (esMovil)

          Column(
            children: [

              ClasePieChart(
                datos: clases,
              ),

              const SizedBox(height: 20),

              TopClientesCard(
                clientes: topClientes,
              ),
            ],
          )

        else

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [

              Expanded(
                flex: 4,
                child: ClasePieChart(
                  datos: clases,
                ),
              ),

              const SizedBox(width: 25),

              Expanded(
                flex: 6,
                child: TopClientesCard(
                  clientes: topClientes,
                ),
              ),
            ],
          ),
      ],
    );
  }
}