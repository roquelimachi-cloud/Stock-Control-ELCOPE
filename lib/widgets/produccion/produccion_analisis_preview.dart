import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/produccion/produccion_analisis_pdf_service.dart';

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
  final List<ProduccionAnalisisPreviewItem> items;

  const ProduccionAnalisisPreview({
    super.key,
    required this.titulo,
    required this.items,
  });

  static const verde = Color(0xff006b3c);
  static const verdeClaro = Color(0xffe5f6ed);
  static const azul = Color(0xff2457c5);
  static const grisFondo = Color(0xfff4f8f6);

  String _money(double v) => 'US\$ ${NumberFormat('#,##0.00', 'en_US').format(v)}';
  String _num(double v) => NumberFormat('#,##0.00', 'en_US').format(v);

  double get totalPeso => items.fold(0.0, (s, e) => s + e.peso);
  double get totalValor => items.fold(0.0, (s, e) => s + e.valor);
  int get totalOp => items.fold(0, (s, e) => s + e.op);

  List<ProduccionAnalisisPreviewItem> get _ordenados =>
      [...items]..sort((a, b) => b.valor.compareTo(a.valor));

  Future<void> _imprimir(BuildContext context) async {
    await ProduccionAnalisisPdfService.imprimir(
      context: context,
      titulo: titulo,
      items: _ordenados
          .map(
            (e) => ProduccionAnalisisPdfItem(
              posicion: e.posicion,
              nombre: e.nombre,
              op: e.op,
              peso: e.peso,
              valor: e.valor,
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: grisFondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff263238),
        elevation: 0,
        title: Text(titulo),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: items.isEmpty ? null : () => _imprimir(context),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('IMPRIMIR'),
              style: FilledButton.styleFrom(backgroundColor: verde),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final movil = constraints.maxWidth < 850;
          return SingleChildScrollView(
            padding: EdgeInsets.all(movil ? 12 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _encabezado(movil),
                const SizedBox(height: 14),
                _kpis(movil),
                const SizedBox(height: 14),
                _grafica(movil),
                const SizedBox(height: 14),
                _leyenda(),
                const SizedBox(height: 14),
                _tabla(movil),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _encabezado(bool movil) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(movil ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffdcebe3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: verdeClaro,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.analytics_outlined, color: verde, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VISTA PREVIA DEL DASHBOARD',
                  style: TextStyle(
                    color: verde,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  titulo,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 3),
                const Text(
                  'La impresión conservará la gráfica, leyenda y detalle.',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpis(bool movil) {
    final cards = [
      ('N.º DE OP', NumberFormat('#,##0', 'en_US').format(totalOp), Icons.assignment_outlined),
      ('VALOR NETO', _money(totalValor), Icons.attach_money),
      ('PESO DE COBRE', '${_num(totalPeso)} kg', Icons.layers_outlined),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: movil ? 1 : 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: movil ? 4.0 : 3.0,
      ),
      itemBuilder: (_, i) {
        final c = cards[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xffdcebe3)),
          ),
          child: Row(
            children: [
              Icon(c.$3, color: i == 1 ? azul : verde),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.$1, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        c.$2,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: i == 1 ? azul : verde,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _grafica(bool movil) {
    final maxPeso = items.fold<double>(0, (m, e) => e.peso > m ? e.peso : m);
    final maxValor = items.fold<double>(0, (m, e) => e.valor > m ? e.valor : m);
    final maxBase = maxPeso > maxValor ? maxPeso : maxValor;
    final anchoBarra = movil ? 180.0 : 260.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(movil ? 12 : 18),
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
              color: verde,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Valor Neto (US\$) + Peso de cobre (kg)',
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: 16),
          for (final item in _ordenados)
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: movil ? 95 : 180,
                        child: Text(
                          item.nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          children: [
                            _barra(
                              'Valor',
                              item.valor,
                              maxBase,
                              anchoBarra,
                              azul,
                              _money(item.valor),
                            ),
                            const SizedBox(height: 5),
                            _barra(
                              'Peso',
                              item.peso,
                              maxBase,
                              anchoBarra,
                              verde,
                              '${_num(item.peso)} kg',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (items.length > 0)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Ordenado de mayor a menor por Valor Neto. Se muestran todos los registros.',
                style: TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  Widget _barra(
    String tipo,
    double valor,
    double max,
    double ancho,
    Color color,
    String etiqueta,
  ) {
    final proporcion = max <= 0 ? 0.0 : (valor / max).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 35,
          child: Text(tipo, style: const TextStyle(fontSize: 8, color: Colors.grey)),
        ),
        Expanded(
          child: Container(
            height: 18,
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: proporcion,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
        SizedBox(
          width: 100,
          child: Text(
            etiqueta,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
    );
  }

  Widget _leyenda() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffdcebe3)),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 8,
        children: const [
          _Legend(color: azul, text: 'Valor Neto (US\$)'),
          _Legend(color: verde, text: 'Peso de cobre (kg)'),
        ],
      ),
    );
  }

  Widget _tabla(bool movil) {
    if (movil) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffdcebe3)),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _ordenados.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final e = _ordenados[i];
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: verdeClaro,
                        child: Text(
                          '${e.posicion}',
                          style: const TextStyle(color: verde, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('N.º de OP: ${NumberFormat('#,##0', 'en_US').format(e.op)}', style: const TextStyle(fontSize: 10)),
                  Text('Peso de cobre: ${_num(e.peso)} kg', style: const TextStyle(fontSize: 10)),
                  Text('Valor Neto: ${_money(e.valor)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                ],
              ),
            );
          },
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffdcebe3)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(verdeClaro),
          columns: const [
            DataColumn(label: Text('N°')),
            DataColumn(label: Text('Nombre')),
            DataColumn(label: Text('N.º de OP')),
            DataColumn(label: Text('Peso de cobre (kg)')),
            DataColumn(label: Text('Valor Neto (US\$)')),
          ],
          rows: _ordenados.map((e) {
            return DataRow(
              cells: [
                DataCell(Text('${e.posicion}')),
                DataCell(SizedBox(width: 300, child: Text(e.nombre, maxLines: 2))),
                DataCell(Text(NumberFormat('#,##0', 'en_US').format(e.op))),
                DataCell(Text(_num(e.peso))),
                DataCell(Text(_money(e.valor))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;

  const _Legend({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 7),
        Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
