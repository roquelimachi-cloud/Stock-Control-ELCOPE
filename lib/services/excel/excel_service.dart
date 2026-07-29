import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

class ExcelService {
  Future<Map<String, dynamic>> leerExcel(String rutaArchivo) async {
    final file = File(rutaArchivo);

    if (!await file.exists()) {
      throw Exception("No existe el archivo.");
    }

    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    if (excel.tables.isEmpty) {
      throw Exception("El Excel no contiene hojas.");
    }

    final Sheet hoja = excel.tables.values.first;

    final filas = hoja.rows.length;

    if (filas == 0) {
      throw Exception("El Excel está vacío.");
    }

    // ==========================
    // Encabezados
    // ==========================

    final List<String> encabezados = [];

    for (final celda in hoja.rows.first) {
      encabezados.add(celda?.value?.toString() ?? "");
    }

    // ==========================
    // Primeras filas (máximo 5)
    // ==========================

    final List<List<String>> primerasFilas = [];

    for (int i = 1; i < hoja.rows.length && i <= 5; i++) {
      primerasFilas.add(
        hoja.rows[i]
            .map((celda) => celda?.value?.toString() ?? "")
            .toList(),
      );
    }

    // ==========================
    // Análisis de columnas
    // ==========================

    final List<Map<String, String>> analisisColumnas = [];

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

    // Solo visible en modo desarrollo
    debugPrint("Encabezados encontrados: $encabezados");

    return {
      "filas": filas - 1,
      "columnas": encabezados.length,
      "encabezados": encabezados,
      "primerasFilas": primerasFilas,
      "analisisColumnas": analisisColumnas,
    };
  }
}