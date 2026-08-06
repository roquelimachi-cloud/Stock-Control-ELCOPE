import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/dashboard/dashboard_summary.dart';
import 'kpi_card.dart';

class DashboardKpis extends StatelessWidget {
  final DashboardSummary resumen;

  const DashboardKpis({
    super.key,
    required this.resumen,
  });

  @override
  Widget build(BuildContext context) {
    final moneda = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'US\$ ',
      decimalDigits: 2,
    );

    final entero = NumberFormat("#,##0", "en_US");

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      childAspectRatio:
    MediaQuery.of(context).size.width < 700
        ? 1.9
        : 2.8,
      children: [

        KpiCard(
          titulo: "Peso Total",
          valor:
              "${entero.format(resumen.pesoTotal)} Kg",
          icono: Icons.scale,
          color: Colors.orange,
        ),

        KpiCard(
          titulo: "Valor Stock",
          valor:
              moneda.format(resumen.valorStock),
          icono: Icons.attach_money,
          color: Colors.green,
        ),

        KpiCard(
          titulo: "Clientes",
          valor:
              entero.format(resumen.clientes),
          icono: Icons.people,
          color: Colors.indigo,
        ),
      ],
    );
  }
}