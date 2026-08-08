import 'package:excel/excel.dart';

class ExcelHelper {
  ExcelHelper._();

  //=====================================================
  // NORMALIZAR TEXTO
  //=====================================================

  static String _normalizar(String texto) {
    return texto
        .toLowerCase()
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\t', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .trim();
  }

  //=====================================================
  // BUSCAR COLUMNA POR NOMBRE
  //=====================================================

  static int buscarColumna(
    List encabezados,
    List nombres,
  ) {
    for (int i = 0; i < encabezados.length; i++) {
      final texto = _normalizar(encabezados[i].toString());

      for (final nombre in nombres) {
        final buscado = _normalizar(nombre.toString());

        if (texto.contains(buscado)) {
          return i;
        }
      }
    }

    return -1;
  }

  //=====================================================
  // OBTENER TEXTO
  //=====================================================

  static String obtenerTexto(
    List<Data?> fila,
    int indice,
  ) {
    if (indice < 0 || indice >= fila.length) {
      return "";
    }

    final celda = fila[indice];

    if (celda == null) {
      return "";
    }

    final valor = celda.value;

    if (valor == null) {
      return "";
    }

    return valor.toString().trim();
  }

  //=====================================================
  // OBTENER DOUBLE
  //=====================================================

static double obtenerDouble(
  List<Data?> fila,
  int indice,
) {
  if (indice < 0 || indice >= fila.length) {
    return 0;
  }

  final celda = fila[indice];

  if (celda == null || celda.value == null) {
    return 0;
  }

  final valor = celda.value;

  // Excel 4.x: número entero
  if (valor is IntCellValue) {
    return valor.value.toDouble();
  }

  // Excel 4.x: número decimal
  if (valor is DoubleCellValue) {
    return valor.value;
  }

  // Texto
  if (valor is TextCellValue) {
    String texto = valor.value.toString().trim();

    if (texto.isEmpty) {
      return 0;
    }

    texto = texto
        .replaceAll('US\$', '')
        .replaceAll('\$', '')
        .replaceAll('S/', '')
        .replaceAll(' ', '')
        .trim();

    // 1.234,56
    if (texto.contains(',') && texto.contains('.')) {
      final ultimaComa = texto.lastIndexOf(',');
      final ultimoPunto = texto.lastIndexOf('.');

      if (ultimaComa > ultimoPunto) {
        texto = texto
            .replaceAll('.', '')
            .replaceAll(',', '.');
      } else {
        // 1,234.56
        texto = texto.replaceAll(',', '');
      }
    } else if (texto.contains(',')) {
      final partes = texto.split(',');

      if (partes.length == 2 && partes[1].length <= 4) {
        texto = texto.replaceAll(',', '.');
      } else {
        texto = texto.replaceAll(',', '');
      }
    }

    return double.tryParse(texto) ?? 0;
  }

  return 0;
}
  //=====================================================
  // OBTENER ENTERO
  //=====================================================

  static int obtenerInt(
    List<Data?> fila,
    int indice,
  ) {
    return obtenerDouble(fila, indice).toInt();
  }

  //=====================================================
  // CELDA VACÍA
  //=====================================================

  static bool estaVacia(
    List<Data?> fila,
    int indice,
  ) {
    return obtenerTexto(fila, indice).isEmpty;
  }

  //=====================================================
  // FILA VACÍA
  //=====================================================

  static bool filaVacia(
    List<Data?> fila,
  ) {
    for (final celda in fila) {
      final valor = celda?.value?.toString().trim() ?? "";

      if (valor.isNotEmpty) {
        return false;
      }
    }

    return true;
  }
}