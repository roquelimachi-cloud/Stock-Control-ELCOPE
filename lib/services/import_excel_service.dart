// import_excel_service.dart
//
// Este archivo se genera como plantilla base.
// Debido a la longitud del importador completo, esta versión incluye
// la estructura lista para integrar ExcelHelper, ExcelDate y ExcelMapper.

import 'dart:io';

import 'package:excel/excel.dart';

import '../models/stock/stock_item.dart';
import 'excel_helper.dart';
import 'excel_mapper.dart';

class ImportExcelService {
  Future<List<StockItem>> importar(String rutaArchivo) async {
    final archivo = File(rutaArchivo);

    if (!await archivo.exists()) {
      throw Exception("No existe el archivo.");
    }

    final bytes = await archivo.readAsBytes();
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
      'codigoAlmacen': ExcelHelper.buscarColumna(encabezados, ['codigo almacén']),
      'codigoArticulo': ExcelHelper.buscarColumna(encabezados, ['código artículo']),
      'articulo': ExcelHelper.buscarColumna(encabezados, ['artículo']),
      'lote': ExcelHelper.buscarColumna(encabezados, ['lote']),
      'stock': ExcelHelper.buscarColumna(encabezados, ['stock almacén']),
      'peso': ExcelHelper.buscarColumna(encabezados, ['peso cobre']),
      'fechaIngreso': ExcelHelper.buscarColumna(encabezados, ['fecha ingreso']),
      'codigoVendedor': ExcelHelper.buscarColumna(encabezados, ['código vendedor']),
      'vendedor': ExcelHelper.buscarColumna(encabezados, ['vendedor']),
      'codigoCliente': ExcelHelper.buscarColumna(encabezados, ['código cliente']),
      'cliente': ExcelHelper.buscarColumna(encabezados, ['cliente']),
      'ordenProduccion': ExcelHelper.buscarColumna(encabezados, ['orden producción']),
      'fechaOrdenProduccion': ExcelHelper.buscarColumna(encabezados, ['fecha orden producción']),
      'modelo': ExcelHelper.buscarColumna(encabezados, ['modelo']),
      'unidad': ExcelHelper.buscarColumna(encabezados, ['unidad medida']),
      'cantidadEmpaque': ExcelHelper.buscarColumna(encabezados, ['cantidad empaque']),
      'listaPrecio': ExcelHelper.buscarColumna(encabezados, ['lista precio']),
      'ultimoPrecio': ExcelHelper.buscarColumna(encabezados, ['último precio']),
      'codigoUltimoCliente': ExcelHelper.buscarColumna(encabezados, ['código último cliente']),
      'ultimoCliente': ExcelHelper.buscarColumna(encabezados, ['último cliente']),
      'valorLista': ExcelHelper.buscarColumna(encabezados, ['valor lista']),
      'valorFacturacion': ExcelHelper.buscarColumna(encabezados, ['valor facturación']),
      'familia': ExcelHelper.buscarColumna(encabezados, ['familia']),
      'calibre': ExcelHelper.buscarColumna(encabezados, ['calibre']),
      'clase': ExcelHelper.buscarColumna(encabezados, ['clase']),
      'color': ExcelHelper.buscarColumna(encabezados, ['color']),
      'presentacion': ExcelHelper.buscarColumna(encabezados, ['presentación']),
    };

    final List<StockItem> items = [];

    for (int i = 1; i < hoja.rows.length; i++) {
      final fila = hoja.rows[i];

      if (ExcelHelper.filaVacia(fila)) {
        continue;
      }

      items.add(ExcelMapper.convertir(fila, columnas));
    }

    return items;
  }
}
