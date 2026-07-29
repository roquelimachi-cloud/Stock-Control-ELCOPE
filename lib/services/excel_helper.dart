import 'package:excel/excel.dart';

class ExcelHelper {
  ExcelHelper._();

  //=====================================================
  // BUSCAR COLUMNA POR NOMBRE
  //=====================================================

  static int buscarColumna(
    List<String> encabezados,
    List<String> nombres,
  ) {
    for (int i = 0; i < encabezados.length; i++) {
      final texto = encabezados[i].toLowerCase().trim();

      for (final nombre in nombres) {
        if (texto.contains(nombre.toLowerCase())) {
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

    final valor = fila[indice]?.value;

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
    final texto = obtenerTexto(fila, indice)
        .replaceAll(",", "")
        .trim();

    return double.tryParse(texto) ?? 0;
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

  static bool filaVacia(List<Data?> fila) {
    for (final celda in fila) {
      final valor = celda?.value?.toString().trim() ?? "";

      if (valor.isNotEmpty) {
        return false;
      }
    }

    return true;
  }
}