import 'package:excel/excel.dart';

class ExcelDate {
  ExcelDate._();

  //=====================================================
  // CONVERTIR FECHA EXCEL
  //=====================================================

  static DateTime? convertir(Data? celda) {
    if (celda == null) {
      return null;
    }

    final valor = celda.value;

    if (valor == null) {
      return null;
    }

    // Si ya viene como DateTime
    if (valor is DateTime) {
      return valor;
    }

    // Si viene como número serial de Excel
    if (valor is num) {
      return DateTime(1899, 12, 30).add(
        Duration(days: valor.toInt()),
      );
    }

    // Si viene como texto
    final texto = valor.toString().trim();

    if (texto.isEmpty) {
      return null;
    }

    return DateTime.tryParse(texto);
  }

  //=====================================================
  // FORMATO yyyy-MM-dd
  //=====================================================

  static String? formatoSql(DateTime? fecha) {
    if (fecha == null) {
      return null;
    }

    final anio = fecha.year.toString().padLeft(4, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');

    return "$anio-$mes-$dia";
  }
}