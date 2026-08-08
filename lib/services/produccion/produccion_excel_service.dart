import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/produccion/produccion_model.dart';
import 'package:flutter/material.dart';
class ProduccionExcelService {
  Future<Excel?> seleccionarExcel() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (resultado == null) {
      return null;
    }

    final archivo = File(resultado.files.single.path!);

    final bytes = archivo.readAsBytesSync();

    return Excel.decodeBytes(bytes);
  }

Sheet obtenerHojaData(Excel excel) {
  // Buscar automáticamente una hoja que contenga
  // alguna de las columnas que identifican nuestro Excel.
  for (final nombre in excel.tables.keys) {
    final hoja = excel.tables[nombre];

    if (hoja == null || hoja.rows.isEmpty) {
      continue;
    }

    final encabezados = hoja.rows.first;

    final columnas = encabezados
        .map(
          (celda) => celda?.value?.toString().trim().toLowerCase() ?? "",
        )
        .toList();

    // Buscamos una columna clave del Excel
    if (columnas.contains("numeroproduccion") ||
        columnas.contains("numero produccion") ||
        columnas.contains("número producción")) {
      debugPrint(
        "Hoja de producción encontrada automáticamente: $nombre",
      );

      return hoja;
    }
  }

  // Si no encontramos una hoja por sus encabezados,
  // buscamos la primera hoja que tenga información.
  for (final nombre in excel.tables.keys) {
    final hoja = excel.tables[nombre];

    if (hoja != null && hoja.rows.isNotEmpty) {
      debugPrint(
        "No se encontró una hoja por encabezados. "
        "Se utilizará la primera hoja con información: $nombre",
      );

      return hoja;
    }
  }

  throw Exception(
    "No se encontró ninguna hoja con información en el archivo Excel.",
  );
}

  Map<String, int> obtenerColumnas(Sheet hoja) {
    final encabezados = hoja.rows.first;

    final columnas = <String, int>{};

    for (int i = 0; i < encabezados.length; i++) {
      final nombre =
          encabezados[i]?.value?.toString().trim() ?? "";

      columnas[nombre] = i;
      debugPrint("[$i] -> '$nombre'");
    }

    return columnas;
  }

  List<ProduccionModel> leerProduccion(Excel excel) {
    final hoja = obtenerHojaData(excel);

    final columnas = obtenerColumnas(hoja);

    final List<ProduccionModel> lista = [];

    String texto(List<Data?> fila, String columna) {
      final idx = columnas[columna];

      if (idx == null) return "";
      if (idx >= fila.length) return "";

      return fila[idx]?.value?.toString().trim() ?? "";
    }

    double decimal(List<Data?> fila, String columna) {
      final valor = texto(fila, columna)
          .replaceAll(",", "")
          .replaceAll(" ", "");

      return double.tryParse(valor) ?? 0;
    }

    int entero(List<Data?> fila, String columna) {
      return decimal(fila, columna).toInt();
    }

    DateTime? fecha(List<Data?> fila, String columna) {
      final idx = columnas[columna];

      if (idx == null) return null;
      if (idx >= fila.length) return null;

      final celda = fila[idx];

      if (celda == null || celda.value == null) {
        return null;
      }

      debugPrint(
        "$columna => ${celda.value} (${celda.value.runtimeType})",
      );
final valor = celda.value;

debugPrint(
  "$columna => ${valor.runtimeType} -> $valor",
);
    

      final textoFecha = valor.toString().trim();

      if (textoFecha.isEmpty) return null;

      try {
        final partes = textoFecha.split(" ");

        final fecha = partes[0].split("/");

        final hora = partes.length > 1
            ? partes[1].split(":")
            : ["0", "0"];

        return DateTime(
          int.parse(fecha[2]),
          int.parse(fecha[1]),
          int.parse(fecha[0]),
          int.parse(hora[0]),
          int.parse(hora[1]),
        );
      } catch (_) {}

      try {
        return DateTime.parse(textoFecha);
      } catch (_) {}

      return null;
    }

    for (int i = 1; i < hoja.rows.length; i++) {
      final fila = hoja.rows[i];

      if (fila.isEmpty) continue;

      if (texto(fila, "NumeroProduccion").isEmpty) {
        continue;
      }
debugPrint(
    "FechaProd Excel: ${texto(fila, "FechaProd")}"
);

debugPrint(
    "FechaEntrega: ${texto(fila, "FechaEntregaEstimada")}"
);
      lista.add(
        ProduccionModel(
          canal: texto(fila, "Canal"),
          representante: texto(fila, "Representante"),
          fechaOrdenVenta: fecha(fila, "FechaOrdenVenta"),
          nroPedido: entero(fila, "NroPedido"),
          numeroProduccion: texto(fila, "NumeroProduccion"),
          cliente: texto(fila, "Cliente"),
          clase: texto(fila, "Clase"),
          abreviadoFamilia: texto(fila, "AbreviadoFamilia"),
          codigoArticulo: texto(fila, "CodigoArticulo"),
          articulo: texto(fila, "Articulo"),
          fechaProduccion: fecha(fila, "FechaProd"),
          fechaEntregaEstimada:
              fecha(fila, "FechaEntregaEstimada"),
          diasRetraso: entero(fila, "DiasDeRetraso"),
          cantidadTotal: decimal(fila, "Cantidad_TOTAL"),
          medida: texto(fila, "Medida"),
          presentacion: texto(fila, "Presentacion"),
          valorNeto: decimal(fila, "Suma de ValorNeto"),
          pesoCobre: decimal(fila, "Peso de Cobre"),
          numeroSemana: null,
        ),
      );
    }

    return lista;
  }
}