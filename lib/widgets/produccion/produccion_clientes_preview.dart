import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/produccion/produccion_clientes_pdf_service.dart';

class ProduccionClienteResumen {
  final String cliente;
  int ordenes;
  double pesoCobre;
  double valorNeto;

  ProduccionClienteResumen({
    required this.cliente,
    required this.ordenes,
    required this.pesoCobre,
    required this.valorNeto,
  });
}

class ProduccionClientesPreview extends StatelessWidget {
  final List<ProduccionClienteResumen> clientes;

  const ProduccionClientesPreview({
    super.key,
    required this.clientes,
  });

  String _money(double v) =>
      'US\$ ${NumberFormat('#,##0.00', 'en_US').format(v)}';

  String _num(double v) =>
      NumberFormat('#,##0.00', 'en_US').format(v);

  @override
  Widget build(BuildContext context) {
    final rows = [...clientes]
      ..sort((a, b) => b.valorNeto.compareTo(a.valorNeto));

    final totalValor = rows.fold<double>(0, (s, e) => s + e.valorNeto);
    final totalPeso = rows.fold<double>(0, (s, e) => s + e.pesoCobre);

    return Scaffold(
      backgroundColor: const Color(0xfff4f8f6),
      appBar: AppBar(
        backgroundColor: const Color(0xff00864a),
        foregroundColor: Colors.white,
        title: const Text('VISTA PREVIA - PRODUCCIÓN POR CLIENTE'),
        actions: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xff00864a),
            ),
            onPressed: rows.isEmpty
                ? null
                : () => ProduccionClientesPdfService.imprimir(
                      context: context,
                      clientes: rows,
                      titulo: 'PRODUCCIÓN POR CLIENTE',
                    ),
            icon: const Icon(Icons.print_outlined),
            label: const Text('IMPRIMIR'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xffdcebe3)),
              ),
              child: Wrap(
                spacing: 30,
                runSpacing: 12,
                children: [
                  Text('CLIENTES: ${rows.length}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff006b3c),
                      )),
                  Text('VALOR NETO TOTAL: ${_money(totalValor)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff006b3c),
                      )),
                  Text('PESO COBRE TOTAL: ${_num(totalPeso)} kg',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff006b3c),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xffdcebe3)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      const WidgetStatePropertyAll(Color(0xffe5f6ed)),
                  columns: const [
                    DataColumn(label: Text('N°')),
                    DataColumn(label: Text('CLIENTE')),
                    DataColumn(label: Text('ÓRDENES')),
                    DataColumn(label: Text('VALOR NETO (US\$)')),
                    DataColumn(label: Text('PESO COBRE (kg)')),
                  ],
                  rows: List.generate(rows.length, (i) {
                    final e = rows[i];
                    return DataRow(cells: [
                      DataCell(Text('${i + 1}')),
                      DataCell(SizedBox(
                        width: 420,
                        child: Text(e.cliente),
                      )),
                      DataCell(Text('${e.ordenes}')),
                      DataCell(Text(_money(e.valorNeto))),
                      DataCell(Text(_num(e.pesoCobre))),
                    ]);
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
