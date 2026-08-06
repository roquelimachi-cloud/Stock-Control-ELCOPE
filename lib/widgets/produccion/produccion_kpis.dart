import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'produccion_kpi_card.dart';

class ProduccionKpis extends StatelessWidget {
  final int totalOp;
  final double valorNeto;
  final double pesoCobre;
  final int clientes;

  const ProduccionKpis({
    super.key,
    required this.totalOp,
    required this.valorNeto,
    required this.pesoCobre,
    required this.clientes,
  });

  @override
  Widget build(BuildContext context) {
    final formato = NumberFormat("#,##0.00", "en_US");
    final formatoEntero = NumberFormat("#,##0", "en_US");

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      childAspectRatio: 2.2,
      children: [

        ProduccionKpiCard(
          titulo: "Total OP",
          valor: formatoEntero.format(totalOp),
          icono: Icons.factory,
          color: Colors.indigo,
        ),

        ProduccionKpiCard(
          titulo: "Valor Neto",
          valor: "US\$ ${formato.format(valorNeto)}",
          icono: Icons.attach_money,
          color: Colors.green,
        ),

        ProduccionKpiCard(
          titulo: "Peso Cobre",
          valor: "${formato.format(pesoCobre)} Kg",
          icono: Icons.scale,
          color: Colors.orange,
        ),

        ProduccionKpiCard(
          titulo: "Clientes",
          valor: formatoEntero.format(clientes),
          icono: Icons.people,
          color: Colors.purple,
        ),

      ],
    );
  }
}