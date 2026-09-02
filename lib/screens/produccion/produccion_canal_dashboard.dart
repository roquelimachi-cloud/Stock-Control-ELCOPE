import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../models/produccion/produccion_model.dart';
import '../../services/sesion.dart';

class CanalResumen {
  final String canal;
  final int producciones;
  final double monto;
  final double peso;

  const CanalResumen({
    required this.canal,
    required this.producciones,
    required this.monto,
    required this.peso,
  });
}

class ProduccionCanalDashboard extends StatelessWidget {
  final List<ProduccionModel> producciones;

  const ProduccionCanalDashboard({
    super.key,
    required this.producciones,
  });

  static const _ordenCanales = <String>[
    'LIMA',
    'PROVINCIA',
    'LICITACION',
    'CADENAS',
  ];

  List<CanalResumen> _resumen() {
    final mapa = <String, _Acumulador>{};

    for (final op in producciones) {
      final canal = op.canal.trim().toUpperCase().isEmpty
          ? 'SIN CANAL'
          : op.canal.trim().toUpperCase();

      final item = mapa.putIfAbsent(canal, _Acumulador.new);
      item.producciones++;
      item.monto += op.valorNeto ?? 0;
      item.peso += op.pesoCobre ?? 0;
    }

    final resultado = mapa.entries
        .map(
          (e) => CanalResumen(
            canal: e.key,
            producciones: e.value.producciones,
            monto: e.value.monto,
            peso: e.value.peso,
          ),
        )
        .toList();

    resultado.sort((a, b) {
      final ia = _ordenCanales.indexOf(a.canal);
      final ib = _ordenCanales.indexOf(b.canal);
      if (ia != -1 && ib != -1) return ia.compareTo(ib);
      if (ia != -1) return -1;
      if (ib != -1) return 1;
      return b.monto.compareTo(a.monto);
    });

    return resultado;
  }

  String _moneda(double valor) =>
      'US\$ ${NumberFormat('#,##0.00', 'en_US').format(valor)}';

  String _numero(double valor) =>
      NumberFormat('#,##0.00', 'en_US').format(valor);

  @override
  Widget build(BuildContext context) {
    final data = _resumen();
    final totalProducciones = producciones.length;
    final totalMonto = producciones.fold<double>(
      0,
      (suma, op) => suma + (op.valorNeto ?? 0),
    );
    final totalPeso = producciones.fold<double>(
      0,
      (suma, op) => suma + (op.pesoCobre ?? 0),
    );

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('PRODUCCIÓN POR CANAL'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final movil = constraints.maxWidth < 800;

          return SingleChildScrollView(
            padding: EdgeInsets.all(movil ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard preliminar',
                  style: TextStyle(
                    fontSize: movil ? 24 : 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${Sesion.rol} • ${Sesion.nombre}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
                _kpis(
                  movil,
                  totalProducciones,
                  totalMonto,
                  totalPeso,
                  data.length,
                ),
                const SizedBox(height: 20),
                if (movil)
                  Column(
                    children: [
                      _graficoMonto(data, totalMonto, 430),
                      const SizedBox(height: 16),
                      _graficoPeso(data, totalPeso, 430),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _graficoMonto(data, totalMonto, 470),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _graficoPeso(data, totalPeso, 470),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                _detalle(data, totalMonto, totalPeso, movil),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Los datos mostrados son preliminares y pueden variar.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _kpis(
    bool movil,
    int producciones,
    double monto,
    double peso,
    int canales,
  ) {
    final cards = [
      _KpiData(Icons.assignment, 'Total Producciones', '$producciones'),
      _KpiData(Icons.attach_money, 'Monto Total', _moneda(monto)),
      _KpiData(Icons.scale, 'Peso Total', '${_numero(peso)} Kg'),
      _KpiData(Icons.groups, 'Canales', '$canales'),
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: cards
          .map(
            (e) => SizedBox(
              width: movil ? double.infinity : 250,
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.indigo.withOpacity(.1),
                        child: Icon(e.icon, color: Colors.indigo),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.titulo, style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                e.valor,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _graficoMonto(List<CanalResumen> data, double total, double alto) {
    return _chartCard(
      'Monto por Canal',
      alto,
      SfCartesianChart(
        primaryXAxis: CategoryAxis(),
        primaryYAxis: NumericAxis(
          numberFormat: NumberFormat.compactCurrency(
            symbol: 'US\$ ',
            decimalDigits: 0,
          ),
        ),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries<CanalResumen, String>>[
          BarSeries<CanalResumen, String>(
            dataSource: data,
            xValueMapper: (e, _) => e.canal,
            yValueMapper: (e, _) => e.monto,
            dataLabelSettings: const DataLabelSettings(
              isVisible: true,
              labelAlignment: ChartDataLabelAlignment.outer,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(5)),
            color: Colors.indigo,
          ),
        ],
      ),
    );
  }

  Widget _graficoPeso(List<CanalResumen> data, double total, double alto) {
    return _chartCard(
      'Peso por Canal',
      alto,
      SfCartesianChart(
        primaryXAxis: CategoryAxis(),
        primaryYAxis: NumericAxis(
          numberFormat: NumberFormat('#,##0'),
          title: AxisTitle(text: 'Kg'),
        ),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries<CanalResumen, String>>[
          BarSeries<CanalResumen, String>(
            dataSource: data,
            xValueMapper: (e, _) => e.canal,
            yValueMapper: (e, _) => e.peso,
            dataLabelSettings: const DataLabelSettings(
              isVisible: true,
              labelAlignment: ChartDataLabelAlignment.outer,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(5)),
            color: Colors.teal,
          ),
        ],
      ),
    );
  }

  Widget _chartCard(String titulo, double alto, Widget chart) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
        child: SizedBox(
          height: alto,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(child: chart),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detalle(
    List<CanalResumen> data,
    double totalMonto,
    double totalPeso,
    bool movil,
  ) {
    final encabezados = [
      'Canal',
      'OP',
      'Monto',
      '% Monto',
      'Peso',
      '% Peso',
    ];

    if (movil) {
      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Detalle por Canal',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...data.map(
                (e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    e.canal,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${e.producciones} OP • ${_moneda(e.monto)} • ${_numero(e.peso)} Kg',
                  ),
                  trailing: Text(
                    '${_porcentaje(e.monto, totalMonto)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detalle por Canal',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStatePropertyAll(Colors.indigo.shade50),
                columns: encabezados
                    .map((e) => DataColumn(label: Text(e)))
                    .toList(),
                rows: data
                    .map(
                      (e) => DataRow(
                        cells: [
                          DataCell(Text(e.canal)),
                          DataCell(Text('${e.producciones}')),
                          DataCell(Text(_moneda(e.monto))),
                          DataCell(Text('${_porcentaje(e.monto, totalMonto)}%')),
                          DataCell(Text('${_numero(e.peso)} Kg')),
                          DataCell(Text('${_porcentaje(e.peso, totalPeso)}%')),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _porcentaje(double valor, double total) {
    if (total == 0) return '0.0';
    return (valor / total * 100).toStringAsFixed(1);
  }
}

class _Acumulador {
  int producciones = 0;
  double monto = 0;
  double peso = 0;
}

class _KpiData {
  final IconData icon;
  final String titulo;
  final String valor;

  const _KpiData(this.icon, this.titulo, this.valor);
}
