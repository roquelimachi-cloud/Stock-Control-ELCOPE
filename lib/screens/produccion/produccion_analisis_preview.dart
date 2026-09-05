import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/produccion/produccion_analisis_pdf_service.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ProduccionAnalisisPreviewItem {
  final int posicion;
  final String nombre;
  final int op;
  final double peso;
  final double valor;

  const ProduccionAnalisisPreviewItem({
    required this.posicion,
    required this.nombre,
    required this.op,
    required this.peso,
    required this.valor,
  });
}

class ProduccionAnalisisPreview extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final List<ProduccionAnalisisPreviewItem> items;

  const ProduccionAnalisisPreview({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.items,
  });

  String _money(double value) => 'US\$ ${NumberFormat('#,##0.00', 'en_US').format(value)}';
  String _num(double value) => NumberFormat('#,##0.00', 'en_US').format(value);

  double get totalPeso => items.fold(0.0, (s, e) => s + e.peso);
  double get totalValor => items.fold(0.0, (s, e) => s + e.valor);
  int get totalOp => items.fold(0, (s, e) => s + e.op);

  Future<void> _imprimir(BuildContext context) async {
    await ProduccionAnalisisPdfService.imprimir(
      context: context,
      titulo: titulo,
      subtitulo: subtitulo,
      items: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    final movil = MediaQuery.sizeOf(context).width < 700;

    return Scaffold(
      backgroundColor: const Color(0xfff4f8f6),
      appBar: AppBar(
        backgroundColor: const Color(0xff08783b),
        foregroundColor: Colors.white,
        title: Text(titulo),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xff08783b),
              ),
              onPressed: items.isEmpty ? null : () => _imprimir(context),
              icon: const Icon(Icons.print_outlined),
              label: const Text('IMPRIMIR'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(movil ? 12 : 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xffdcebe3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VISTA PREVIA',
                        style: TextStyle(
                          color: Color(0xff08783b),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        titulo,
                        style: const TextStyle(
                          color: Color(0xff006b3c),
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitulo,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _kpi('ÓRDENES', NumberFormat('#,##0', 'en_US').format(totalOp)),
                          _kpi('PESO DE COBRE', '${_num(totalPeso)} kg'),
                          _kpi('VALOR NETO', _money(totalValor)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _dashboardGrafico(movil),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xffdcebe3)),
                  ),
                  child: movil
                      ? Column(
                          children: items.map((e) => _mobileItem(e)).toList(),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: const WidgetStatePropertyAll(Color(0xffe5f6ed)),
                            columns: const [
                              DataColumn(label: Text('N°')),
                              DataColumn(label: Text('Nombre')),
                              DataColumn(label: Text('N.º de OP')),
                              DataColumn(label: Text('Peso de cobre (kg)')),
                              DataColumn(label: Text('Valor Neto (US\$)')),
                            ],
                            rows: items.map((e) {
                              return DataRow(cells: [
                                DataCell(Text('${e.posicion}')),
                                DataCell(Text(e.nombre)),
                                DataCell(Text(NumberFormat('#,##0', 'en_US').format(e.op))),
                                DataCell(Text(_num(e.peso))),
                                DataCell(Text(_money(e.valor))),
                              ]);
                            }).toList(),
                          ),
                        ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff08783b),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    ),
                    onPressed: items.isEmpty ? null : () => _imprimir(context),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('IMPRIMIR'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dashboardGrafico(bool movil) {
    final maxValor = items.fold<double>(0, (m, e) => e.valor > m ? e.valor : m);
    final maxPeso = items.fold<double>(0, (m, e) => e.peso > m ? e.peso : m);
    final escala = maxPeso == 0 ? 1.0 : (maxValor / maxPeso);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffdcebe3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: Color(0xff08783b),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Misma información visual del dashboard: Peso de cobre + Valor Neto',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: movil ? 330 : 380,
            child: SfCartesianChart(
              primaryXAxis: CategoryAxis(
                labelRotation: movil ? -45 : -35,
                majorGridLines: const MajorGridLines(width: 0),
              ),
              primaryYAxis: NumericAxis(
                numberFormat: NumberFormat('#,##0.00', 'en_US'),
                majorGridLines: const MajorGridLines(width: .5),
              ),
              legend: const Legend(
                isVisible: true,
                position: LegendPosition.bottom,
                overflowMode: LegendItemOverflowMode.wrap,
              ),
              tooltipBehavior: TooltipBehavior(enable: true),
              series: <CartesianSeries<ProduccionAnalisisPreviewItem, String>>[
                ColumnSeries<ProduccionAnalisisPreviewItem, String>(
                  name: 'Peso de cobre (kg)',
                  dataSource: items,
                  xValueMapper: (e, _) => e.nombre,
                  yValueMapper: (e, _) => e.peso,
                  color: const Color(0xff00864a),
                  dataLabelMapper: (e, _) => '${_num(e.peso)} kg',
                  dataLabelSettings: const DataLabelSettings(
                    isVisible: true,
                    labelPosition: ChartDataLabelPosition.outside,
                    textStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
                ColumnSeries<ProduccionAnalisisPreviewItem, String>(
                  name: 'Valor (US\$)',
                  dataSource: items,
                  xValueMapper: (e, _) => e.nombre,
                  yValueMapper: (e, _) => e.peso * escala,
                  color: const Color(0xff7bcf9f),
                  dataLabelMapper: (e, _) => 'US\$ ${NumberFormat('#,##0.00', 'en_US').format(e.valor)}',
                  dataLabelSettings: const DataLabelSettings(
                    isVisible: true,
                    labelPosition: ChartDataLabelPosition.outside,
                    textStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String titulo, String valor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xfff4f8f6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffdcebe3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(valor, style: const TextStyle(fontSize: 18, color: Color(0xff006b3c), fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _mobileItem(ProduccionAnalisisPreviewItem e) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xffe5e7eb)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${e.posicion}. ${e.nombre}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xff006b3c))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              Text('OP: ${NumberFormat('#,##0', 'en_US').format(e.op)}'),
              Text('Peso: ${_num(e.peso)} kg'),
              Text('Valor: ${_money(e.valor)}'),
            ],
          ),
        ],
      ),
    );
  }
}
