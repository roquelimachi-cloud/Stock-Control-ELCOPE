import 'dart:typed_data';

import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
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

  Future<void> _exportarExcel(BuildContext context) async {
    try {
      final rows = [...clientes]
        ..sort((a, b) => b.valorNeto.compareTo(a.valorNeto));

      final workbook = excel.Excel.createExcel();
      final sheet = workbook['Top 5 Clientes'];

      final ahora = DateTime.now();
      final fecha = DateFormat('dd/MM/yyyy HH:mm').format(ahora);

      sheet.appendRow([
        excel.TextCellValue('REPORTE TOP 5 CLIENTES - PRODUCCIÓN'),
      ]);

      sheet.appendRow([
        excel.TextCellValue('Fecha de generación'),
        excel.TextCellValue(fecha),
      ]);

      sheet.appendRow([
        excel.TextCellValue('Cantidad de clientes'),
        excel.IntCellValue(rows.length),
      ]);

      final totalValor =
          rows.fold<double>(0, (s, e) => s + e.valorNeto);
      final totalPeso =
          rows.fold<double>(0, (s, e) => s + e.pesoCobre);

      sheet.appendRow([
        excel.TextCellValue('Valor Neto Total'),
        excel.DoubleCellValue(totalValor),
      ]);

      sheet.appendRow([
        excel.TextCellValue('Peso Cobre Total'),
        excel.DoubleCellValue(totalPeso),
      ]);

      sheet.appendRow([]);

      sheet.appendRow([
        excel.TextCellValue('N°'),
        excel.TextCellValue('CLIENTE'),
        excel.TextCellValue('ÓRDENES'),
        excel.TextCellValue('VALOR NETO (US\$)'),
        excel.TextCellValue('PESO COBRE (kg)'),
      ]);

      for (int i = 0; i < rows.length; i++) {
        final e = rows[i];

        sheet.appendRow([
          excel.IntCellValue(i + 1),
          excel.TextCellValue(e.cliente),
          excel.IntCellValue(e.ordenes),
          excel.DoubleCellValue(e.valorNeto),
          excel.DoubleCellValue(e.pesoCobre),
        ]);
      }

      final widths = <int, double>{
        0: 8,
        1: 55,
        2: 12,
        3: 20,
        4: 20,
      };

      for (final entry in widths.entries) {
        sheet.setColumnWidth(entry.key, entry.value);
      }

      final bytes = workbook.encode();

      if (bytes == null || bytes.isEmpty) {
        throw Exception('No se pudo generar el archivo Excel.');
      }

      final nombre =
          'Top_5_Clientes_Produccion_${DateFormat('yyyyMMdd_HHmmss').format(ahora)}.xlsx';

      final ruta = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar Top 5 Clientes en Excel',
        fileName: nombre,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(bytes),
      );

      if (!context.mounted) return;

      if (ruta != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excel generado correctamente.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar Excel: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _imprimir(BuildContext context) async {
    final rows = [...clientes]
      ..sort((a, b) => b.valorNeto.compareTo(a.valorNeto));

    if (rows.isEmpty) return;

    await ProduccionClientesPdfService.imprimir(
      context: context,
      clientes: rows,
      titulo: 'TOP 5 CLIENTES - PRODUCCIÓN',
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = [...clientes]
      ..sort((a, b) => b.valorNeto.compareTo(a.valorNeto));

    final totalValor =
        rows.fold<double>(0, (s, e) => s + e.valorNeto);
    final totalPeso =
        rows.fold<double>(0, (s, e) => s + e.pesoCobre);

    final ancho = MediaQuery.sizeOf(context).width;
    final movil = ancho < 700;

    return Scaffold(
      backgroundColor: const Color(0xfff4f8f6),
      appBar: AppBar(
        backgroundColor: const Color(0xff00864a),
        foregroundColor: Colors.white,
        elevation: 1,
        leading: const BackButton(),
        title: const Text(
          'VISTA PREVIA - TOP 5 CLIENTES',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Exportar Excel',
            onPressed: rows.isEmpty
                ? null
                : () => _exportarExcel(context),
            icon: const Icon(Icons.table_view_outlined),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Imprimir PDF',
              onPressed: rows.isEmpty
                  ? null
                  : () => _imprimir(context),
              icon: const Icon(Icons.print_outlined),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(movil ? 12 : 22),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOP 5 CLIENTES',
                    style: TextStyle(
                      fontSize: movil ? 20 : 24,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xff006b3c),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Producción • Dinero (US\$) • Peso de cobre (kg)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: movil ? 14 : 30,
                    runSpacing: 12,
                    children: [
                      _kpi(
                        'CLIENTES',
                        '${rows.length}',
                      ),
                      _kpi(
                        'VALOR NETO TOTAL',
                        _money(totalValor),
                      ),
                      _kpi(
                        'PESO COBRE TOTAL',
                        '${_num(totalPeso)} kg',
                      ),
                    ],
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
                      DataColumn(label: Text('CLIENTE')),
                      DataColumn(label: Text('ÓRDENES')),
                      DataColumn(
                        label: Text('VALOR NETO (US\$)'),
                      ),
                      DataColumn(
                        label: Text('PESO COBRE (kg)'),
                      ),
                    ],
                    rows: List.generate(rows.length, (i) {
                      final e = rows[i];

                      return DataRow(
                        cells: [
                          DataCell(Text('${i + 1}')),
                          DataCell(
                            SizedBox(
                              width: movil ? 280 : 420,
                              child: Text(
                                e.cliente,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text('${e.ordenes}')),
                          DataCell(
                            Text(_money(e.valorNeto)),
                          ),
                          DataCell(
                            Text(_num(e.pesoCobre)),
                          ),
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

  Widget _kpi(String titulo, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          valor,
          style: const TextStyle(
            fontSize: 18,
            color: Color(0xff006b3c),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
