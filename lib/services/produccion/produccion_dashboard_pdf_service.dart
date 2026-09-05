import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/produccion/produccion_model.dart';

class ProduccionDashboardPdfService {
  static const _verde = PdfColor.fromInt(0xff00864a);
  static const _verdeClaro = PdfColor.fromInt(0xffe5f6ed);
  static const _azul = PdfColor.fromInt(0xff2457c5);
  static const _gris = PdfColor.fromInt(0xff6b7280);
  static const _borde = PdfColor.fromInt(0xffdcebe3);

  static final _moneyFormat = NumberFormat('#,##0.00', 'en_US');
  static final _numberFormat = NumberFormat('#,##0.00', 'en_US');
  static final _dateFormat = DateFormat('dd/MM/yyyy');

  static String money(double value) => 'US\$ ${_moneyFormat.format(value)}';
  static String number(double value) => _numberFormat.format(value);

  static Future<void> imprimir({
    required BuildContext context,
    required List<ProduccionModel> data,
    required String titulo,
    required String filtroAsesor,
    required String filtroClase,
    required String filtroCanal,
    required DateTime? fechaDesde,
    required DateTime? fechaHasta,
  }) async {
    final document = pw.Document();

    final ordenadas = [...data]
      ..sort((a, b) {
        final da = a.fechaProduccion ?? DateTime(1900);
        final db = b.fechaProduccion ?? DateTime(1900);
        return db.compareTo(da);
      });

    final valorTotal =
        data.fold<double>(0, (s, e) => s + (e.valorNeto ?? 0));
    final cobreTotal =
        data.fold<double>(0, (s, e) => s + (e.pesoCobre ?? 0));

    final clientes = data
        .map((e) => e.cliente.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .length;
    final asesores = data
        .map((e) => e.representante.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .length;
    final canales = data
        .map((e) => e.canal.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .length;

    final rankingAsesor = _ranking(data, (e) => e.representante).take(7).toList();
    final rankingClase =
        _ranking(data, (e) => e.clase ?? 'SIN CLASE').take(7).toList();
    final rankingCanal = _ranking(data, (e) => e.canal).take(7).toList();

    final estados = _groupCount(data, (e) => e.estado);
    final zonas = _groupCount(
      data,
      (e) => e.canal.toUpperCase().contains('PROV')
          ? 'PROVINCIA'
          : 'LIMA',
    );
    final tiempos = _tiempo(data);

    final productos =
        _ranking(data, (e) => e.articulo ?? 'SIN ARTÍCULO').take(5).toList();
    final topClientes = _ranking(data, (e) => e.cliente).take(5).toList();
    final topCanales = _ranking(data, (e) => e.canal).take(5).toList();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(22),
        maxPages: 100,
        header: (context) => _header(
          titulo,
          filtroAsesor,
          filtroClase,
          filtroCanal,
          fechaDesde,
          fechaHasta,
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'ELCOPE • Dashboard de Producción',
              style: const pw.TextStyle(fontSize: 7, color: _gris),
            ),
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: _gris),
            ),
          ],
        ),
        build: (context) => [
          _kpis(data.length, cobreTotal, valorTotal, clientes, asesores, canales),
          pw.SizedBox(height: 12),

          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _chartPanel(
                  'PRODUCCIÓN POR ASESOR',
                  rankingAsesor,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _chartPanel(
                  'PRODUCCIÓN POR CLASE',
                  rankingClase,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _chartPanel(
                  'PRODUCCIÓN POR CANAL',
                  rankingCanal,
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 10),

          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _donutPanel('DISTRIBUCIÓN POR ESTADO', estados),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _donutPanel('PRODUCCIÓN POR ZONA', zonas),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _timePanel(tiempos),
              ),
            ],
          ),

          pw.SizedBox(height: 10),

          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _topPanel('TOP 5 PRODUCTOS', productos)),
              pw.SizedBox(width: 10),
              pw.Expanded(child: _topPanel('TOP 5 CLIENTES', topClientes)),
              pw.SizedBox(width: 10),
              pw.Expanded(child: _topPanel('TOP 5 CANALES', topCanales)),
            ],
          ),

          pw.SizedBox(height: 12),
          _ordersTable(ordenadas),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => document.save(),
      name: 'produccion_dashboard.pdf',
    );
  }

  static pw.Widget _header(
    String titulo,
    String asesor,
    String clase,
    String canal,
    DateTime? desde,
    DateTime? hasta,
  ) {
    final fechas = desde == null && hasta == null
        ? 'Todas las fechas'
        : '${desde == null ? '--/--/----' : _dateFormat.format(desde)} → '
          '${hasta == null ? '--/--/----' : _dateFormat.format(hasta)}';

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _borde),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: _verdeClaro,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              'ELCOPE',
              style: pw.TextStyle(
                color: _verde,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  titulo,
                  style: pw.TextStyle(
                    color: _verde,
                    fontSize: 17,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Análisis gerencial por asesor, clase, canal, cliente, peso, valor y tiempo.',
                  style: const pw.TextStyle(fontSize: 8, color: _gris),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Filtros aplicados',
                style: pw.TextStyle(
                  fontSize: 7,
                  color: _verde,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Asesor: $asesor • Clase: $clase • Canal: $canal',
                style: const pw.TextStyle(fontSize: 7, color: _gris),
              ),
              pw.Text(
                fechas,
                style: const pw.TextStyle(fontSize: 7, color: _gris),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _kpis(
    int ops,
    double cobre,
    double valor,
    int clientes,
    int asesores,
    int canales,
  ) {
    final cards = [
      ('ÓRDENES DE PRODUCCIÓN', '$ops'),
      ('PESO DE COBRE', '${number(cobre)} kg'),
      ('VALOR DE PRODUCCIÓN', money(valor)),
      ('CLIENTES', '$clientes'),
      ('ASESORES', '$asesores'),
      ('CANALES', '$canales'),
    ];

    return pw.Row(
      children: cards
          .map(
            (c) => pw.Expanded(
              child: pw.Container(
                margin: const pw.EdgeInsets.only(right: 6),
                padding: const pw.EdgeInsets.all(9),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  border: pw.Border.all(color: _borde),
                  borderRadius: pw.BorderRadius.circular(7),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      c.$1,
                      style: const pw.TextStyle(fontSize: 6.5, color: _gris),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      c.$2,
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: _verde,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  static pw.Widget _chartPanel(String title, List<_PdfRow> rows) {
    final maxCobre =
        rows.fold<double>(0, (m, r) => r.cobre > m ? r.cobre : m);
    final maxValor =
        rows.fold<double>(0, (m, r) => r.valor > m ? r.valor : m);

    return _box(
      title,
      pw.Column(
        children: [
          _legendLine('Peso de cobre (kg)', _verde),
          _legendLine('Valor (US\$)', _azul),
          pw.SizedBox(height: 5),
          ...rows.map((r) {
            final pesoRatio = maxCobre == 0 ? 0.0 : r.cobre / maxCobre;
            final valorRatio = maxValor == 0 ? 0.0 : r.valor / maxValor;
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    r.nombre,
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip,
                    style: const pw.TextStyle(fontSize: 6.5),
                  ),
                  pw.SizedBox(height: 2),
                  _bar(pesoRatio, '${number(r.cobre)} kg', _verde),
                  pw.SizedBox(height: 2),
                  _bar(valorRatio, money(r.valor), _azul),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _bar(double ratio, String label, PdfColor color) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Container(
            height: 7,
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Container(
                width: 180 * ratio.clamp(0, 1),
                height: 7,
                decoration: pw.BoxDecoration(
                  color: color,
                  borderRadius: pw.BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        pw.SizedBox(width: 4),
        pw.SizedBox(
          width: 55,
          child: pw.Text(
            label,
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 5.5),
          ),
        ),
      ],
    );
  }

  static pw.Widget _donutPanel(String title, Map<String, int> values) {
    final total = values.values.fold<int>(0, (a, b) => a + b);

    return _box(
      title,
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            height: 80,
            alignment: pw.Alignment.center,
            child: pw.Stack(
              alignment: pw.Alignment.center,
              children: [
                pw.Container(
                  width: 66,
                  height: 66,
                  decoration: const pw.BoxDecoration(
                    color: _verde,
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.Container(
                  width: 38,
                  height: 38,
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.white,
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.Text(
                  '$total',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _verde,
                  ),
                ),
              ],
            ),
          ),
          ...values.entries.map((e) {
            final pct = total == 0 ? 0 : (e.value / total * 100);
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 6,
                    height: 6,
                    decoration: const pw.BoxDecoration(
                      color: _verde,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                    child: pw.Text(
                      e.key,
                      style: const pw.TextStyle(fontSize: 6.5),
                    ),
                  ),
                  pw.Text(
                    '${e.value} (${pct.toStringAsFixed(1)}%)',
                    style: const pw.TextStyle(fontSize: 6.5),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _timePanel(List<_TimeRow> rows) {
    final max = rows.fold<double>(0, (m, r) => r.count > m ? r.count.toDouble() : m);

    return _box(
      'TIEMPO DE PRODUCCIÓN',
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Días entre producción y entrega estimada',
            style: const pw.TextStyle(fontSize: 6.5, color: _gris),
          ),
          pw.SizedBox(height: 7),
          ...rows.map(
            (r) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 7),
              child: pw.Row(
                children: [
                  pw.SizedBox(
                    width: 50,
                    child: pw.Text(
                      r.nombre,
                      style: const pw.TextStyle(fontSize: 6.5),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Container(
                      height: 11,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                      child: pw.Align(
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Container(
                          width: (175 *
                              (max == 0 ? 0 : r.count / max).clamp(0, 1))
                          .toDouble(),
                          height: 11,
                          decoration: pw.BoxDecoration(
                            color: _verde,
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 5),
                  pw.Text(
                    '${r.count}',
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _topPanel(String title, List<_PdfRow> rows) {
    return _box(
      title,
      pw.Column(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            color: _verdeClaro,
            child: pw.Row(
              children: [
                pw.SizedBox(width: 18, child: pw.Text('N°', style: _th())),
                pw.Expanded(flex: 5, child: pw.Text('Nombre', style: _th())),
                pw.SizedBox(width: 42, child: pw.Text('OP', style: _th())),
                pw.SizedBox(width: 65, child: pw.Text('Peso kg', style: _th())),
                pw.SizedBox(width: 75, child: pw.Text('Valor US\$', style: _th())),
              ],
            ),
          ),
          ...rows.asMap().entries.map(
            (entry) {
              final i = entry.key;
              final r = entry.value;
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: _borde, width: .5),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 18,
                      child: pw.Text('${i + 1}', style: _td()),
                    ),
                    pw.Expanded(
                      flex: 5,
                      child: pw.Text(
                        r.nombre,
                        maxLines: 2,
                        style: _td(),
                      ),
                    ),
                    pw.SizedBox(width: 42, child: pw.Text('${r.op}', style: _td())),
                    pw.SizedBox(
                      width: 65,
                      child: pw.Text(number(r.cobre), style: _td()),
                    ),
                    pw.SizedBox(
                      width: 75,
                      child: pw.Text(money(r.valor), style: _td()),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static pw.Widget _ordersTable(List<ProduccionModel> rows) {
    return _box(
      'ÚLTIMAS ÓRDENES DE PRODUCCIÓN',
      pw.TableHelper.fromTextArray(
        border: pw.TableBorder.all(color: _borde, width: .5),
        headerDecoration: const pw.BoxDecoration(color: _verdeClaro),
        headerStyle: pw.TextStyle(
          fontSize: 6.5,
          fontWeight: pw.FontWeight.bold,
          color: _verde,
        ),
        cellStyle: const pw.TextStyle(fontSize: 5.8),
        cellPadding: const pw.EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 4,
        ),
        headers: const [
          'OP',
          'Fecha',
          'Cliente',
          'Artículo',
          'Clase',
          'Asesor',
          'Canal',
          'Cantidad',
          'Peso Cobre (kg)',
          'Valor (US\$)',
          'Estado',
        ],
        data: rows.map((e) {
          return [
            e.numeroProduccion,
            e.fechaProduccion == null
                ? '-'
                : _dateFormat.format(e.fechaProduccion!),
            e.cliente,
            e.articulo ?? '-',
            e.clase ?? '-',
            e.representante,
            e.canal,
            '${number(e.cantidadTotal ?? 0)} ${e.medida ?? ''}'.trim(),
            number(e.pesoCobre ?? 0),
            money(e.valorNeto ?? 0),
            e.estado,
          ];
        }).toList(),
      ),
    );
  }

  static pw.Widget _box(String title, pw.Widget child) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _borde),
        borderRadius: pw.BorderRadius.circular(7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              color: _verde,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          child,
        ],
      ),
    );
  }

  static pw.Widget _legendLine(String text, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        children: [
          pw.Container(width: 6, height: 6, color: color),
          pw.SizedBox(width: 4),
          pw.Text(text, style: const pw.TextStyle(fontSize: 6)),
        ],
      ),
    );
  }

  static pw.TextStyle _th() => pw.TextStyle(
        fontSize: 5.8,
        fontWeight: pw.FontWeight.bold,
        color: _verde,
      );

  static const _tdStyle = pw.TextStyle(fontSize: 5.8);

  static pw.TextStyle _td() => _tdStyle;

  static List<_PdfRow> _ranking(
    List<ProduccionModel> data,
    String Function(ProduccionModel) key,
  ) {
    final map = <String, _PdfRow>{};
    for (final e in data) {
      final nombre = key(e).trim().isEmpty ? 'SIN DATO' : key(e).trim();
      final current = map[nombre];
      if (current == null) {
        map[nombre] = _PdfRow(
          nombre,
          1,
          e.valorNeto ?? 0,
          e.pesoCobre ?? 0,
        );
      } else {
        current.op++;
        current.valor += e.valorNeto ?? 0;
        current.cobre += e.pesoCobre ?? 0;
      }
    }
    final result = map.values.toList()
      ..sort((a, b) => b.valor.compareTo(a.valor));
    return result;
  }

  static Map<String, int> _groupCount(
    List<ProduccionModel> data,
    String Function(ProduccionModel) key,
  ) {
    final map = <String, int>{};
    for (final e in data) {
      final value = key(e).trim().isEmpty ? 'SIN DATO' : key(e).trim();
      map[value] = (map[value] ?? 0) + 1;
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in entries) e.key: e.value};
  }

  static List<_TimeRow> _tiempo(List<ProduccionModel> data) {
    final buckets = <String, int>{
      '<= 1 día': 0,
      '2 - 3 días': 0,
      '4 - 7 días': 0,
      '8 - 15 días': 0,
      '> 15 días': 0,
    };

    for (final e in data) {
      final inicio = e.fechaProduccion;
      final fin = e.fechaEntregaEstimada;
      if (inicio == null || fin == null) continue;

      final d = fin.difference(inicio).inDays;
      if (d <= 1) {
        buckets['<= 1 día'] = buckets['<= 1 día']! + 1;
      } else if (d <= 3) {
        buckets['2 - 3 días'] = buckets['2 - 3 días']! + 1;
      } else if (d <= 7) {
        buckets['4 - 7 días'] = buckets['4 - 7 días']! + 1;
      } else if (d <= 15) {
        buckets['8 - 15 días'] = buckets['8 - 15 días']! + 1;
      } else {
        buckets['> 15 días'] = buckets['> 15 días']! + 1;
      }
    }

    return buckets.entries
        .map((e) => _TimeRow(e.key, e.value))
        .toList();
  }
}

class _PdfRow {
  final String nombre;
  int op;
  double valor;
  double cobre;

  _PdfRow(this.nombre, this.op, this.valor, this.cobre);
}

class _TimeRow {
  final String nombre;
  final int count;

  _TimeRow(this.nombre, this.count);
}
