import 'package:excel/excel.dart';

class ExcelDate {
  ExcelDate._();

  //=====================================================
  // CONVERTIR FECHA EXCEL
  //=====================================================

  static DateTime? convertir(Data? celda) {
    if (celda == null) return null;

    final valor = celda.value;

    if (valor == null) return null;

    // Fecha propia del paquete excel
    if (valor is DateCellValue) {
      return valor.asDateTimeLocal();
    }

    // Número entero (fecha Excel)
    if (valor is IntCellValue) {
      return DateTime(1899, 12, 30).add(
        Duration(days: valor.value),
      );
    }

    // Número decimal (fecha Excel)
    if (valor is DoubleCellValue) {
      return DateTime(1899, 12, 30).add(
        Duration(days: valor.value.toInt()),
      );
    }

    // Texto
    if (valor is TextCellValue) {
      final texto = valor.toString().trim();

      if (texto.isEmpty) return null;

      return DateTime.tryParse(texto);
    }

    return null;
  }

  //=====================================================
  // FORMATO yyyy-MM-dd
  //=====================================================

  static String? formatoSql(DateTime? fecha) {
    if (fecha == null) return null;

    final anio = fecha.year.toString().padLeft(4, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');

    return '$anio-$mes-$dia';
  }
}