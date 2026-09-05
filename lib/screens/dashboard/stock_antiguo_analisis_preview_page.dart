import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/pdf/stock_antiguo_analisis_pdf_service.dart';

class StockAntiguoAnalisisPreviewItem {
  final String codigo;
  final String descripcion;
  final String cliente;
  final String asesor;
  final String clase;
  final String almacen;
  final DateTime fechaIngreso;
  final int dias;
  final double stock;
  final double precio;
  final double valorTotal;
  final double peso;

  const StockAntiguoAnalisisPreviewItem({
    required this.codigo,
    required this.descripcion,
    required this.cliente,
    required this.asesor,
    required this.clase,
    required this.almacen,
    required this.fechaIngreso,
    required this.dias,
    required this.stock,
    required this.precio,
    required this.valorTotal,
    required this.peso,
  });
}

class StockAntiguoAnalisisPreviewPage extends StatelessWidget {
  final String titulo;
  final List<StockAntiguoAnalisisPreviewItem> items;

  // Identifica la pestaña/vista desde la cual se abrió la preliminar.
  // 0 = Resumen General
  // 1 = Por Asesor
  // 2 = Por Cliente
  // 3 = Por Clase
  // 4 = Por Almacén
  // 5 = Evolución
  final int vista;

  final String filtroBusqueda;
  final String cliente;
  final String asesor;
  final String clase;
  final String almacen;
  final int diasMinimos;
  final String estado;

  const StockAntiguoAnalisisPreviewPage({
    super.key,
    required this.titulo,
    required this.items,
    this.vista = 0,
    this.filtroBusqueda = '',
    this.cliente = 'Todos',
    this.asesor = 'Todos',
    this.clase = 'Todos',
    this.almacen = 'Todos',
    this.diasMinimos = 30,
    this.estado = 'Todos',
  });

  static const verde = Color(0xFF08783B);
  static const verdeSuave = Color(0xFFEAF5EE);
  static const azul = Color(0xFF1565D8);
  static const naranja = Color(0xFFF59E0B);
  static const rojo = Color(0xFFEF4444);
  static const grisFondo = Color(0xFFF5F7F8);

  double get valor => items.fold(0, (s, e) => s + e.valorTotal);
  double get peso => items.fold(0, (s, e) => s + e.peso);
  double get promedio => items.isEmpty
      ? 0
      : items.fold<int>(0, (s, e) => s + e.dias) / items.length;

  Future<void> _imprimir(BuildContext context) async {
    await StockAntiguoAnalisisPdfService.imprimir(
      context: context,
      items: items
          .map(
            (e) => StockAntiguoAnalisisPdfItem(
              codigo: e.codigo,
              descripcion: e.descripcion,
              cliente: e.cliente,
              asesor: e.asesor,
              clase: e.clase,
              almacen: e.almacen,
              fechaIngreso: e.fechaIngreso,
              dias: e.dias,
              stock: e.stock,
              precio: e.precio,
              valorTotal: e.valorTotal,
              peso: e.peso,
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
        foregroundColor: const Color(0xFF263238),
        elevation: 0,
        titleSpacing: 18,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: verdeSuave,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.preview_outlined, color: verde),
            ),
            const SizedBox(width: 12),
            const Text(
              'VISTA PRELIMINAR',
              style: TextStyle(
                color: verde,
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: ElevatedButton.icon(
              onPressed: items.isEmpty ? null : () => _imprimir(context),
              icon: const Icon(Icons.print, size: 18),
              label: const Text('IMPRIMIR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: verde,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final movil = constraints.maxWidth < 900;
          final moneda = NumberFormat('#,##0.00', 'en_US');
          final numero = NumberFormat('#,##0.##', 'en_US');
          final fecha = DateFormat('dd/MM/yyyy');

          return SingleChildScrollView(
            padding: EdgeInsets.all(movil ? 12 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cabecera(movil),
                const SizedBox(height: 12),
                _kpis(movil, moneda),
                const SizedBox(height: 12),
                _filtrosResumen(movil),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDCE4DF)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: const BoxDecoration(
                          color: verde,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(10),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'DETALLE QUE SE ENVIARÁ A IMPRESIÓN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                              'Total: ${numero.format(items.length)} artículos',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (movil)
                        _tablaMovil(fecha, moneda, numero)
                      else
                        _tablaDesktop(fecha, moneda, numero),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _nota(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _cabecera(bool movil) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(movil ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE4DF)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: verdeSuave,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.analytics_outlined, color: verde, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ELCOPE',
                  style: TextStyle(
                    color: verde,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF263238),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Vista preliminar con exactamente los filtros y selección actual.',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          if (!movil)
            Text(
              DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _kpis(bool movil, NumberFormat moneda) {
    final cards = [
      _Kpi('ARTÍCULOS', NumberFormat('#,##0', 'en_US').format(items.length),
          'con más de 30 días', Icons.inventory_2_outlined, verde),
      _Kpi('VALOR TOTAL', 'US\$ ${moneda.format(valor)}', 'en stock antiguo',
          Icons.attach_money, azul),
      _Kpi('PESO COBRE', '${moneda.format(peso)} t', 'en stock antiguo',
          Icons.scale_outlined, naranja),
      _Kpi('DÍAS PROMEDIO', '${promedio.round()} días', 'de permanencia',
          Icons.access_time, azul),
    ];
    return movil
        ? Column(children: cards.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: e,
            )).toList())
        : Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: cards[i]),
              ],
            ],
          );
  }

  Widget _filtrosResumen(bool movil) {
    final numero = NumberFormat('#,##0', 'en_US');
    final moneda = NumberFormat('#,##0.00', 'en_US');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE4DF)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _chip('Vista', _nombreVista, verde),
          if (filtroBusqueda.trim().isNotEmpty)
            _chip('Búsqueda', filtroBusqueda.trim(), azul),
          _chip('Cliente', cliente, azul),
          _chip('Asesor', asesor, azul),
          _chip('Clase', clase, azul),
          _chip('Almacén', almacen, azul),
          _chip('Días mínimos', '$diasMinimos', naranja),
          _chip('Estado', estado, rojo),
          _chip('Resultado', '${numero.format(items.length)} artículos', verde),
          _chip('Valor', 'US\$ ${moneda.format(valor)}', azul),
          _chip('Peso', '${moneda.format(peso)} t', naranja),
          _chip(
            'Mayor antigüedad',
            '${items.isEmpty ? 0 : items.map((e) => e.dias).reduce((a, b) => a > b ? a : b)} días',
            rojo,
          ),
        ],
      ),
    );
  }

  String get _nombreVista {
    switch (vista) {
      case 1:
        return 'Por Asesor';
      case 2:
        return 'Por Cliente';
      case 3:
        return 'Por Clase';
      case 4:
        return 'Por Almacén';
      case 5:
        return 'Evolución';
      default:
        return 'Resumen General';
    }
  }

  Widget _chip(String titulo, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11, color: Colors.black87),
          children: [
            TextSpan(text: '$titulo: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: valor, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _tablaDesktop(DateFormat fecha, NumberFormat moneda, NumberFormat numero) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(verde),
        dataRowMinHeight: 46,
        dataRowMaxHeight: 58,
        columnSpacing: 18,
        columns: const [
          DataColumn(label: Text('N°', style: _th)),
          DataColumn(label: Text('Código', style: _th)),
          DataColumn(label: Text('Descripción', style: _th)),
          DataColumn(label: Text('Cliente', style: _th)),
          DataColumn(label: Text('Asesor', style: _th)),
          DataColumn(label: Text('Clase', style: _th)),
          DataColumn(label: Text('Almacén', style: _th)),
          DataColumn(label: Text('Ingreso', style: _th)),
          DataColumn(label: Text('Días', style: _th)),
          DataColumn(label: Text('Stock', style: _th)),
          DataColumn(label: Text('Precio US\$', style: _th)),
          DataColumn(label: Text('Valor Total', style: _th)),
          DataColumn(label: Text('Peso Cobre', style: _th)),
        ],
        rows: [
          for (int i = 0; i < items.length; i++)
            DataRow(cells: [
              DataCell(Text('${i + 1}')),
              DataCell(Text(items[i].codigo, style: const TextStyle(fontWeight: FontWeight.w700))),
              DataCell(SizedBox(width: 300, child: Text(items[i].descripcion, softWrap: false))),
              DataCell(SizedBox(width: 170, child: Text(items[i].cliente, softWrap: false))),
              DataCell(SizedBox(width: 130, child: Text(items[i].asesor, softWrap: false))),
              DataCell(Text(items[i].clase)),
              DataCell(Text(items[i].almacen)),
              DataCell(Text(fecha.format(items[i].fechaIngreso))),
              DataCell(_dias(items[i].dias)),
              DataCell(Text(numero.format(items[i].stock))),
              DataCell(Text(moneda.format(items[i].precio))),
              DataCell(Text('US\$ ${moneda.format(items[i].valorTotal)}', style: const TextStyle(fontWeight: FontWeight.w700))),
              DataCell(Text('${moneda.format(items[i].peso)} t')),
            ]),
        ],
      ),
    );
  }

  Widget _tablaMovil(DateFormat fecha, NumberFormat moneda, NumberFormat numero) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final e = items[index];
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: verdeSuave,
                    child: Text('${index + 1}', style: const TextStyle(color: verde, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.codigo, style: const TextStyle(fontWeight: FontWeight.w800))),
                  _dias(e.dias),
                ],
              ),
              const SizedBox(height: 8),
              Text(e.descripcion, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(e.cliente, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 5,
                children: [
                  Text('Ingreso: ${fecha.format(e.fechaIngreso)}'),
                  Text('Stock: ${numero.format(e.stock)}'),
                  Text('Precio: US\$ ${moneda.format(e.precio)}'),
                  Text('Valor: US\$ ${moneda.format(e.valorTotal)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('Peso: ${moneda.format(e.peso)} t'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dias(int dias) {
    final color = dias > 90 ? rojo : dias >= 61 ? Colors.deepOrange : dias >= 31 ? const Color(0xFFF4C430) : verde;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text('$dias', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
    );
  }

  Widget _nota() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE4DF)),
      ),
      child: const Text(
        'Esta pantalla es una vista preliminar. El botón IMPRIMIR genera el PDF con los mismos artículos mostrados aquí, respetando la selección actual.',
        style: TextStyle(color: Colors.grey, fontSize: 11),
      ),
    );
  }

  static const _th = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w800,
    fontSize: 11,
  );
}

class _Kpi extends StatelessWidget {
  final String titulo;
  final String valor;
  final String subtitulo;
  final IconData icono;
  final Color color;

  const _Kpi(this.titulo, this.valor, this.subtitulo, this.icono, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE4DF)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, color: color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(valor, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
                Text(subtitulo, style: const TextStyle(color: Colors.grey, fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
