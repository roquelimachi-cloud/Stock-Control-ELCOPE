import 'dart:typed_data';
import 'package:excel/excel.dart';

import '../../models/excel/stock_excel_row.dart';
import '../excel_helper.dart';
import '../excel_mapper.dart';

class ImportExcelService {
  // Mantiene compatibilidad con pantallas que llaman importar(bytes: ...).
  Future<List<StockExcelRow>> importar({required Uint8List bytes}) {
    return importarBytes(bytes);
  }

  Future<List<StockExcelRow>> importarBytes(Uint8List bytes) async {
    if (bytes.isEmpty) {
      throw Exception("El archivo Excel está vacío.");
    }

    final excel = Excel.decodeBytes(bytes);

    if (excel.tables.isEmpty) {
      throw Exception("El Excel no contiene hojas.");
    }

    final hoja = excel.tables.values.first;

    if (hoja.rows.length <= 1) {
      return [];
    }

    final encabezados = hoja.rows.first
        .map((e) => e?.value?.toString().trim() ?? "")
        .toList();

    final columnas = <String, int>{
      'codigoAlmacen': ExcelHelper.buscarColumna(
        encabezados,
        ['codigo almacen'],
      ),
      'codigoArticulo': ExcelHelper.buscarColumna(
        encabezados,
        ['codigo articulo'],
      ),
      'articulo': ExcelHelper.buscarColumna(
        encabezados,
        ['articulo'],
      ),
      'lote': ExcelHelper.buscarColumna(
        encabezados,
        ['lote'],
      ),
      'stock': ExcelHelper.buscarColumna(
        encabezados,
        ['stock almacen'],
      ),
      'peso': ExcelHelper.buscarColumna(
        encabezados,
        ['peso cobre'],
      ),
      'fechaIngreso': ExcelHelper.buscarColumna(
        encabezados,
        ['fecha ingreso'],
      ),
      'codigoVendedor': ExcelHelper.buscarColumna(
        encabezados,
        ['codigo vendedor'],
      ),
      'vendedor': ExcelHelper.buscarColumna(
        encabezados,
        ['vendedor'],
      ),
      'codigoCliente': ExcelHelper.buscarColumna(
        encabezados,
        ['codigo cliente'],
      ),
      'cliente': ExcelHelper.buscarColumna(
        encabezados,
        ['cliente'],
      ),
      'ordenProduccion': ExcelHelper.buscarColumna(
        encabezados,
        ['orden produccion'],
      ),
      'fechaOrdenProduccion': ExcelHelper.buscarColumna(
        encabezados,
        ['fecha orden produccion'],
      ),
      'modelo': ExcelHelper.buscarColumna(
        encabezados,
        ['modelo'],
      ),
      'unidad': ExcelHelper.buscarColumna(
        encabezados,
        ['unidad medida'],
      ),
      'cantidadEmpaque': ExcelHelper.buscarColumna(
        encabezados,
        ['cantidad empaque'],
      ),
      'listaPrecio': ExcelHelper.buscarColumna(
        encabezados,
        ['lista precio dolar'],
      ),
      'ultimoPrecio': ExcelHelper.buscarColumna(
        encabezados,
        ['ultimo precio facturado dolar'],
      ),
      'codigoUltimoCliente': ExcelHelper.buscarColumna(
        encabezados,
        ['codigo ultimo cliente facturado'],
      ),
      'ultimoCliente': ExcelHelper.buscarColumna(
        encabezados,
        ['ultimo cliente facturado'],
      ),
      'valorLista': ExcelHelper.buscarColumna(
        encabezados,
        ['valor lista precio dolar'],
      ),
      'valorFacturacion': ExcelHelper.buscarColumna(
        encabezados,
        ['valor facturacion dolar'],
      ),
      'familia': ExcelHelper.buscarColumna(
        encabezados,
        ['familia'],
      ),
      'calibre': ExcelHelper.buscarColumna(
        encabezados,
        ['calibre'],
      ),
      'clase': ExcelHelper.buscarColumna(
        encabezados,
        ['clase'],
      ),
      'color': ExcelHelper.buscarColumna(
        encabezados,
        ['color'],
      ),
      'presentacion': ExcelHelper.buscarColumna(
        encabezados,
        ['presentacion'],
      ),
    };

    // Evita importar silenciosamente el stock si no se detectó "Modelo".
    if ((columnas['modelo'] ?? -1) < 0) {
      throw Exception(
        'No se encontró la columna "Modelo" en el Excel. '
        'Verifica que el encabezado esté escrito como Modelo.',
      );
    }

    final List<StockExcelRow> items = [];

    for (int i = 1; i < hoja.rows.length; i++) {
      final fila = hoja.rows[i];

      if (ExcelHelper.filaVacia(fila)) {
        continue;
      }

      items.add(
        ExcelMapper.convertir(
          fila,
          columnas,
        ),
      );
    }

    return items;
  }
}