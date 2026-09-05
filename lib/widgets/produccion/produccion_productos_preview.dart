import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/produccion/produccion_productos_pdf_service.dart';

class ProduccionProductoResumen {
  final String producto;
  int ordenes;
  double pesoCobre;
  double valorNeto;

  ProduccionProductoResumen({
    required this.producto,
    required this.ordenes,
    required this.pesoCobre,
    required this.valorNeto,
  });
}

class ProduccionProductosPreview extends StatelessWidget {
  final List<ProduccionProductoResumen> productos;

  const ProduccionProductosPreview({
    super.key,
    required this.productos,
  });

  String _money(double value) =>
      'US\$ ${NumberFormat('#,##0.00', 'en_US').format(value)}';

  String _num(double value) =>
      NumberFormat('#,##0.00', 'en_US').format(value);

  @override
  Widget build(BuildContext context) {
    final ordenados = [...productos]
      ..sort((a, b) => b.valorNeto.compareTo(a.valorNeto));

    final valorTotal =
        ordenados.fold<double>(0, (s, e) => s + e.valorNeto);
    final pesoTotal =
        ordenados.fold<double>(0, (s, e) => s + e.pesoCobre);

    return Scaffold(
      backgroundColor: const Color(0xfff4f8f6),
      appBar: AppBar(
        title: const Text('PRODUCCIÓN POR PRODUCTO'),
        backgroundColor: const Color(0xff00864a),
        foregroundColor: Colors.white,
        actions: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xff00864a),
            ),
            onPressed: ordenados.isEmpty
                ? null
                : () => ProduccionProductosPdfService.imprimir(
                      context: context,
                      productos: ordenados,
                      titulo: 'PRODUCCIÓN POR PRODUCTO',
                    ),
            icon: const Icon(Icons.print_outlined),
            label: const Text('IMPRIMIR'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final movil = constraints.maxWidth < 800;

          return SingleChildScrollView(
            padding: EdgeInsets.all(movil ? 12 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _encabezado(
                  context,
                  ordenados.length,
                  pesoTotal,
                  valorTotal,
                  movil,
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xffdcebe3),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowColor: const WidgetStatePropertyAll(
                        Color(0xffe5f6ed),
                      ),
                      columns: const [
                        DataColumn(label: Text('N°')),
                        DataColumn(label: Text('PRODUCTO / ARTÍCULO')),
                        DataColumn(label: Text('ÓRDENES')),
                        DataColumn(label: Text('PESO COBRE (kg)')),
                        DataColumn(label: Text('VALOR NETO (US\$)')),
                      ],
                      rows: List.generate(ordenados.length, (i) {
                        final e = ordenados[i];
                        return DataRow(
                          cells: [
                            DataCell(Text('${i + 1}')),
                            DataCell(
                              SizedBox(
                                width: movil ? 260 : 460,
                                child: Text(
                                  e.producto,
                                  softWrap: true,
                                ),
                              ),
                            ),
                            DataCell(Text('${e.ordenes}')),
                            DataCell(Text(_num(e.pesoCobre))),
                            DataCell(
                              Text(
                                _money(e.valorNeto),
                                style: const TextStyle(
                                  color: Color(0xff006b3c),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _encabezado(
    BuildContext context,
    int cantidad,
    double peso,
    double valor,
    bool movil,
  ) {
    return Container(
      padding: EdgeInsets.all(movil ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffdcebe3)),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: Color(0xff00864a),
            size: 34,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'REPORTE DE PRODUCCIÓN POR PRODUCTO',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff006b3c),
                ),
              ),
              Text(
                'Todos los productos • ordenados por Valor Neto',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
          _miniKpi('PRODUCTOS', '$cantidad'),
          _miniKpi('PESO COBRE', '${_num(peso)} kg'),
          _miniKpi('VALOR NETO', _money(valor)),
        ],
      ),
    );
  }

  Widget _miniKpi(String titulo, String valor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xffe5f6ed),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xff006b3c),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xff006b3c),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
