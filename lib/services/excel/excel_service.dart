import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

class ExcelService {
  Future<Map<String, dynamic>> leerExcel({
    required Uint8List bytes,
  }) async {
    final excel = Excel.decodeBytes(bytes);

    if (excel.tables.isEmpty) {
      throw Exception("El Excel no contiene hojas.");
    }

    final hoja = excel.tables.values.first;

    final filas = hoja.rows.length;

    if (filas == 0) {
      throw Exception("El Excel está vacío.");
    }

    final encabezados = hoja.rows.first
        .map((c) => c?.value?.toString() ?? "")
        .toList();

    final primerasFilas = <List<String>>[];

    for (int i = 1; i < hoja.rows.length && i <= 5; i++) {
      primerasFilas.add(
        hoja.rows[i].map((c) => c?.value?.toString() ?? "").toList(),
      );
    }

    final analisisColumnas = <Map<String, String>>[];

    if (hoja.rows.length > 1) {
      final primeraFila = hoja.rows[1];

      for (int i = 0; i < encabezados.length; i++) {
        analisisColumnas.add({
          "numero": "${i + 1}",
          "columna": encabezados[i],
          "valor": i < primeraFila.length
              ? (primeraFila[i]?.value?.toString() ?? "")
              : "",
        });
      }
    }

    debugPrint(encabezados.toString());

    return {
      "filas": filas - 1,
      "columnas": encabezados.length,
      "encabezados": encabezados,
      "primerasFilas": primerasFilas,
      "analisisColumnas": analisisColumnas,
    };
  }
}