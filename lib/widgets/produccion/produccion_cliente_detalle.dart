import 'dart:typed_data';

import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/produccion/produccion_model.dart';
import '../../services/cotizaciones/cliente_cotizacion_service.dart';

class ProduccionClienteDetallePreview extends StatefulWidget {
  final String cliente;
  final List<ProduccionModel> producciones;

  const ProduccionClienteDetallePreview({
    super.key,
    required this.cliente,
    required this.producciones,
  });

  @override
  State<ProduccionClienteDetallePreview> createState() =>
      _ProduccionClienteDetallePreviewState();
}

class _ProduccionClienteDetallePreviewState
    extends State<ProduccionClienteDetallePreview> {
  String _ruc = '-';
  bool _cargandoRuc = true;

  final _moneyFormat = NumberFormat('#,##0.00', 'en_US');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _cargarRuc();
  }

  Future<void> _cargarRuc() async {
    try {
      final resultados = await ClienteCotizacionService()
          .buscarClientes(widget.cliente);

      if (!mounted) return;

      final exacto = resultados.where(
        (e) => e.razonSocial.trim().toUpperCase() ==
            widget.cliente.trim().toUpperCase(),
      );

      setState(() {
        _ruc = exacto.isNotEmpty
            ? exacto.first.ruc.trim().isEmpty
                ? '-'
                : exacto.first.ruc.trim()
            : (resultados.isNotEmpty && resultados.first.ruc.trim().isNotEmpty
                ? resultados.first.ruc.trim()
                : '-');
        _cargandoRuc = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ruc = '-';
        _cargandoRuc = false;
      });
    }
  }

  List<ProduccionModel> get _rows {
    final data = [...widget.producciones];
    data.sort((a, b) {
      final fa = a.fechaProduccion ?? DateTime(1900);
      final fb = b.fechaProduccion ?? DateTime(1900);
      return fb.compareTo(fa);
    });
    return data;
  }

  double get _totalCantidad =>
      _rows.fold(0, (s, e) => s + (e.cantidadTotal ?? 0));

  double get _totalValor =>
      _rows.fold(0, (s, e) => s + (e.valorNeto ?? 0));

  double get _totalPeso =>
      _rows.fold(0, (s, e) => s + (e.pesoCobre ?? 0));

  String _money(double value) => 'US\$ ${_moneyFormat.format(value)}';

  String _num(double value) => _moneyFormat.format(value);

  String _fecha(DateTime? value) =>
      value == null ? '-' : _dateFormat.format(value);

  String _texto(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? '-' : text;
  }

  Future<void> _imprimirPdf() async {
    final rows = _rows;
    if (rows.isEmpty) return;

    final pdf = pw.Document();

    final totalCantidad =
        rows.fold<double>(0, (s, e) => s + (e.cantidadTotal ?? 0));
    final totalValor =
        rows.fold<double>(0, (s, e) => s + (e.valorNeto ?? 0));
    final totalPeso =
        rows.fold<double>(0, (s, e) => s + (e.pesoCobre ?? 0));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        maxPages: 100,
        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ELCOPE',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'DETALLE DE PRODUCCIÓN POR CLIENTE',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text('Cliente: ${widget.cliente}'),
                  pw.Text('RUC: $_ruc'),
                ],
              ),
              pw.Text(
                'Fecha: ${_dateFormat.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'ELCOPE - Detalle de producción por cliente',
              style: const pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey600,
              ),
            ),
            pw.Text(
              'Página ${context.pageNumber}',
              style: const pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(9),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Text('Registros: ${rows.length}'),
                pw.Text('Cantidad: ${_num(totalCantidad)}'),
                pw.Text('Valor Neto: ${_money(totalValor)}'),
                pw.Text('Peso Cobre: ${_num(totalPeso)} kg'),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'DETALLE',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green800,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const [
              'N°',
              'OP',
              'FECHA',
              'CÓDIGO',
              'ARTÍCULO',
              'CANTIDAD',
              'MEDIDA',
              'VALOR NETO (US\$)',
              'PESO COBRE (kg)',
              'ASESOR',
              'CANAL',
              'CLASE',
            ],
            data: List.generate(rows.length, (i) {
              final e = rows[i];
              return [
                '${i + 1}',
                e.numeroProduccion,
                _fecha(e.fechaProduccion),
                _texto(e.codigoArticulo),
                _texto(e.articulo),
                _num(e.cantidadTotal ?? 0),
                _texto(e.medida),
                _money(e.valorNeto ?? 0),
                _num(e.pesoCobre ?? 0),
                _texto(e.representante),
                _texto(e.canal),
                _texto(e.clase),
              ];
            }),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 6.5,
            ),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.green800),
            cellStyle: const pw.TextStyle(fontSize: 6.2),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            border: pw.TableBorder.all(
              color: PdfColors.grey300,
              width: .4,
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();

    await Printing.layoutPdf(
      name: 'Detalle_Produccion_${widget.cliente}.pdf',
      onLayout: (_) async => bytes,
    );
  }

  Future<void> _exportarExcel() async {
    try {
      final rows = _rows;
      if (rows.isEmpty) return;

      final workbook = excel.Excel.createExcel();
      final sheet = workbook['Detalle Cliente'];

      final ahora = DateTime.now();

      sheet.appendRow([
        excel.TextCellValue('DETALLE DE PRODUCCIÓN POR CLIENTE'),
      ]);
      sheet.appendRow([
        excel.TextCellValue('CLIENTE'),
        excel.TextCellValue(widget.cliente),
      ]);
      sheet.appendRow([
        excel.TextCellValue('RUC'),
        excel.TextCellValue(_ruc),
      ]);
      sheet.appendRow([
        excel.TextCellValue('FECHA DE GENERACIÓN'),
        excel.TextCellValue(
          DateFormat('dd/MM/yyyy HH:mm').format(ahora),
        ),
      ]);
      sheet.appendRow([]);
      sheet.appendRow([
        excel.TextCellValue('N°'),
        excel.TextCellValue('OP'),
        excel.TextCellValue('FECHA'),
        excel.TextCellValue('CÓDIGO'),
        excel.TextCellValue('ARTÍCULO'),
        excel.TextCellValue('CANTIDAD'),
        excel.TextCellValue('MEDIDA'),
        excel.TextCellValue('PRESENTACIÓN'),
        excel.TextCellValue('VALOR NETO (US\$)'),
        excel.TextCellValue('PESO COBRE (kg)'),
        excel.TextCellValue('ASESOR'),
        excel.TextCellValue('CANAL'),
        excel.TextCellValue('CLASE'),
        excel.TextCellValue('ESTADO'),
      ]);

      for (int i = 0; i < rows.length; i++) {
        final e = rows[i];

        sheet.appendRow([
          excel.IntCellValue(i + 1),
          excel.TextCellValue(e.numeroProduccion),
          excel.TextCellValue(_fecha(e.fechaProduccion)),
          excel.TextCellValue(_texto(e.codigoArticulo)),
          excel.TextCellValue(_texto(e.articulo)),
          excel.DoubleCellValue(e.cantidadTotal ?? 0),
          excel.TextCellValue(_texto(e.medida)),
          excel.TextCellValue(_texto(e.presentacion)),
          excel.DoubleCellValue(e.valorNeto ?? 0),
          excel.DoubleCellValue(e.pesoCobre ?? 0),
          excel.TextCellValue(_texto(e.representante)),
          excel.TextCellValue(_texto(e.canal)),
          excel.TextCellValue(_texto(e.clase)),
          excel.TextCellValue(e.estado),
        ]);
      }

      final widths = <int, double>{
        0: 7,
        1: 16,
        2: 13,
        3: 20,
        4: 48,
        5: 14,
        6: 12,
        7: 20,
        8: 20,
        9: 18,
        10: 24,
        11: 16,
        12: 16,
        13: 16,
      };

      for (final entry in widths.entries) {
        sheet.setColumnWidth(entry.key, entry.value);
      }

      final bytes = workbook.encode();

      if (bytes == null || bytes.isEmpty) {
        throw Exception('No se pudo generar el archivo Excel.');
      }

      final nombre =
          'Detalle_Produccion_${_nombreArchivo(widget.cliente)}_${DateFormat('yyyyMMdd_HHmmss').format(ahora)}.xlsx';

      final ruta = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar detalle de producción en Excel',
        fileName: nombre,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(bytes),
      );

      if (!mounted) return;

      if (ruta != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excel generado correctamente.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Error al exportar Excel: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String _nombreArchivo(String value) {
    final limpio = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return limpio.isEmpty ? 'Cliente' : limpio;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final movil = MediaQuery.sizeOf(context).width < 800;

    return Scaffold(
      backgroundColor: const Color(0xfff4f8f6),
      appBar: AppBar(
        backgroundColor: const Color(0xff00864a),
        foregroundColor: Colors.white,
        title: Text(
          'DETALLE - ${widget.cliente}',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Exportar Excel',
            onPressed: rows.isEmpty ? null : _exportarExcel,
            icon: const Icon(Icons.table_view_outlined),
          ),
          IconButton(
            tooltip: 'Imprimir PDF',
            onPressed: rows.isEmpty ? null : _imprimirPdf,
            icon: const Icon(Icons.print_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(movil ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(movil ? 14 : 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xffdcebe3),
                ),
              ),
              child: Wrap(
                spacing: 26,
                runSpacing: 14,
                children: [
                  _dato('CLIENTE', widget.cliente, ancho: movil ? 320 : 460),
                  _dato(
                    'RUC',
                    _cargandoRuc ? 'Consultando...' : _ruc,
                    ancho: 160,
                  ),
                  _dato('REGISTROS', '${rows.length}', ancho: 120),
                  _dato(
                    'CANTIDAD TOTAL',
                    _num(_totalCantidad),
                    ancho: 150,
                  ),
                  _dato(
                    'VALOR NETO',
                    _money(_totalValor),
                    ancho: 190,
                  ),
                  _dato(
                    'PESO COBRE',
                    '${_num(_totalPeso)} kg',
                    ancho: 170,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xffdcebe3),
                ),
              ),
              child: Scrollbar(
                thumbVisibility: !movil,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor:
                        const WidgetStatePropertyAll(
                      Color(0xffe5f6ed),
                    ),
                    columns: const [
                      DataColumn(label: Text('N°')),
                      DataColumn(label: Text('OP')),
                      DataColumn(label: Text('FECHA')),
                      DataColumn(label: Text('CÓDIGO')),
                      DataColumn(label: Text('ARTÍCULO')),
                      DataColumn(label: Text('CANTIDAD')),
                      DataColumn(label: Text('MEDIDA')),
                      DataColumn(label: Text('VALOR NETO')),
                      DataColumn(label: Text('PESO COBRE')),
                      DataColumn(label: Text('ASESOR')),
                      DataColumn(label: Text('CANAL')),
                      DataColumn(label: Text('CLASE')),
                      DataColumn(label: Text('ESTADO')),
                    ],
                    rows: List.generate(rows.length, (i) {
                      final e = rows[i];

                      return DataRow(
                        cells: [
                          DataCell(Text('${i + 1}')),
                          DataCell(Text(e.numeroProduccion)),
                          DataCell(Text(_fecha(e.fechaProduccion))),
                          DataCell(Text(_texto(e.codigoArticulo))),
                          DataCell(
                            SizedBox(
                              width: movil ? 260 : 420,
                              child: Text(
                                _texto(e.articulo),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(_num(e.cantidadTotal ?? 0)),
                          ),
                          DataCell(Text(_texto(e.medida))),
                          DataCell(Text(_money(e.valorNeto ?? 0))),
                          DataCell(
                            Text('${_num(e.pesoCobre ?? 0)} kg'),
                          ),
                          DataCell(Text(_texto(e.representante))),
                          DataCell(Text(_texto(e.canal))),
                          DataCell(Text(_texto(e.clase))),
                          DataCell(Text(e.estado)),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dato(
    String titulo,
    String valor, {
    double? ancho,
  }) {
    return SizedBox(
      width: ancho,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            valor,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xff006b3c),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
