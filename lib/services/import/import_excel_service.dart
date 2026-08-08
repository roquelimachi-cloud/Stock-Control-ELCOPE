
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../models/excel/stock_excel_row.dart';
class ImportExcelService {

Future<List<StockExcelRow>> importar({
  required Uint8List bytes,
}) async {
final excel = Excel.decodeBytes(bytes);

    if (excel.tables.isEmpty) {
      throw Exception("El archivo no contiene hojas.");
    }

    final Sheet hoja = excel.tables.values.first;

    final List<StockExcelRow> registros = [];

    if (hoja.rows.length <= 1) {
      return registros;
    }

    for (int i = 1; i < hoja.rows.length; i++) {
      final fila = hoja.rows[i];

      String texto(int index) {
        if (index >= fila.length) return "";
        return fila[index]?.value?.toString().trim() ?? "";
      }

      double numero(int index) {
        if (index >= fila.length) return 0;

        final cell = fila[index];

        if (cell == null || cell.value == null) return 0;

        final valor = cell.value.toString();

        return double.tryParse(
              valor.replaceAll(",", ""),
            ) ??
            0;
      }

      DateTime? fecha(int index) {
        if (index >= fila.length) return null;

        final cell = fila[index];

        if (cell == null || cell.value == null) {
          return null;
        }

        return DateTime.tryParse(cell.value.toString());
      }

      // ========= SOLO PARA DEPURAR =========
      if (i == 1) {
        print("========== PRIMER REGISTRO ==========");

        for (int c = 0; c < fila.length; c++) {
          print("Columna $c = ${texto(c)}");
        }

        print("=====================================");
      }
      // ====================================

      registros.add(
 StockExcelRow(
  codigoAlmacen: texto(0),
  codigoArticulo: texto(1),
  articulo: texto(2),
  lote: texto(3),
  stockAlmacen: numero(4),
  pesoCobre: numero(5),
  fechaIngreso: fecha(6),
  codigoVendedor: texto(7),
  vendedor: texto(8),
  codigoCliente: texto(9),
  cliente: texto(10),
  ordenProduccion: texto(11),
  fechaOrdenProduccion: fecha(12),
  modelo: texto(13),
  unidadMedida: texto(14),
  cantidadEmpaque: numero(15),
  listaPrecioDolar: numero(16),
  ultimoPrecioFacturadoDolar: numero(17),
  codigoUltimoClienteFacturado: texto(18),
  ultimoClienteFacturado: texto(19),

  // PRECIOS CORRECTOS
  valorListaPrecioDolar: numero(20),
  valorFacturacionDolar: numero(21),

  // DATOS DEL PRODUCTO
  familia: texto(22),
  calibre: texto(23),
  clase: texto(24),
  color: texto(25),
  presentacion: texto(26),
),
      );
    }

    return registros;
  }
}