import 'package:excel/excel.dart';

import '../models/stock/stock_item.dart';
import 'excel_date.dart';
import 'excel_helper.dart';

class ExcelMapper {
  ExcelMapper._();

  static StockItem convertir(
    List<Data?> fila,
    Map<String, int> columnas,
  ) {
    final fecha = ExcelDate.formatoSql(
      ExcelDate.convertir(
        (columnas['fechaIngreso'] ?? -1) >= 0 &&
                (columnas['fechaIngreso'] ?? -1) < fila.length
            ? fila[columnas['fechaIngreso']!]
            : null,
      ),
    );

    return StockItem(
      codigo: ExcelHelper.obtenerTexto(
        fila,
        columnas['codigoArticulo'] ?? -1,
      ),

      descripcion: ExcelHelper.obtenerTexto(
        fila,
        columnas['articulo'] ?? -1,
      ),

      cliente: ExcelHelper.obtenerTexto(
        fila,
        columnas['cliente'] ?? -1,
      ),

      vendedor: ExcelHelper.obtenerTexto(
        fila,
        columnas['vendedor'] ?? -1,
      ),

      lote: ExcelHelper.obtenerTexto(
        fila,
        columnas['lote'] ?? -1,
      ),

      modelo: ExcelHelper.obtenerTexto(
        fila,
        columnas['modelo'] ?? -1,
      ),

      stock: ExcelHelper.obtenerDouble(
        fila,
        columnas['stock'] ?? -1,
      ),

      peso: ExcelHelper.obtenerDouble(
        fila,
        columnas['peso'] ?? -1,
      ),

      almacen: ExcelHelper.obtenerTexto(
        fila,
        columnas['codigoAlmacen'] ?? -1,
      ),

      listaPrecioDolar: ExcelHelper.obtenerDouble(
        fila,
        columnas['listaPrecio'] ?? -1,
      ),

      valorListaPrecioDolar: ExcelHelper.obtenerDouble(
        fila,
        columnas['valorLista'] ?? -1,
      ),

      valorFacturacionDolar: ExcelHelper.obtenerDouble(
        fila,
        columnas['valorFacturacion'] ?? -1,
      ),

      fechaIngreso: fecha ?? '',
    );
  }
}