import 'package:excel/excel.dart';

import '../models/excel/stock_excel_row.dart';
import 'excel_date.dart';
import 'excel_helper.dart';

class ExcelMapper {
  ExcelMapper._();

  static StockExcelRow convertir(
    List<Data?> fila,
    Map<String, int> columnas,
  ) {
    DateTime? fechaIngreso;

    final indiceFecha = columnas['fechaIngreso'] ?? -1;

    if (indiceFecha >= 0 && indiceFecha < fila.length) {
      fechaIngreso = ExcelDate.convertir(
        fila[indiceFecha],
      );
    }

    DateTime? fechaOrdenProduccion;

    final indiceFechaOP =
        columnas['fechaOrdenProduccion'] ?? -1;

    if (indiceFechaOP >= 0 &&
        indiceFechaOP < fila.length) {
      fechaOrdenProduccion = ExcelDate.convertir(
        fila[indiceFechaOP],
      );
    }

    return StockExcelRow(
      codigoAlmacen: ExcelHelper.obtenerTexto(
        fila,
        columnas['codigoAlmacen'] ?? -1,
      ),

      codigoArticulo: ExcelHelper.obtenerTexto(
        fila,
        columnas['codigoArticulo'] ?? -1,
      ),

      articulo: ExcelHelper.obtenerTexto(
        fila,
        columnas['articulo'] ?? -1,
      ),

      lote: ExcelHelper.obtenerTexto(
        fila,
        columnas['lote'] ?? -1,
      ),

      stockAlmacen: ExcelHelper.obtenerDouble(
        fila,
        columnas['stock'] ?? -1,
      ),

      pesoCobre: ExcelHelper.obtenerDouble(
        fila,
        columnas['peso'] ?? -1,
      ),

      fechaIngreso: fechaIngreso,

      codigoVendedor: ExcelHelper.obtenerTexto(
        fila,
        columnas['codigoVendedor'] ?? -1,
      ),

      vendedor: ExcelHelper.obtenerTexto(
        fila,
        columnas['vendedor'] ?? -1,
      ),

      codigoCliente: ExcelHelper.obtenerTexto(
        fila,
        columnas['codigoCliente'] ?? -1,
      ),

      cliente: ExcelHelper.obtenerTexto(
        fila,
        columnas['cliente'] ?? -1,
      ),

      ordenProduccion: ExcelHelper.obtenerTexto(
        fila,
        columnas['ordenProduccion'] ?? -1,
      ),

      fechaOrdenProduccion: fechaOrdenProduccion,

      modelo: ExcelHelper.obtenerTexto(
        fila,
        columnas['modelo'] ?? -1,
      ),

      unidadMedida: ExcelHelper.obtenerTexto(
        fila,
        columnas['unidad'] ?? -1,
      ),

      cantidadEmpaque: ExcelHelper.obtenerDouble(
        fila,
        columnas['cantidadEmpaque'] ?? -1,
      ),

      listaPrecioDolar: ExcelHelper.obtenerDouble(
        fila,
        columnas['listaPrecio'] ?? -1,
      ),

      ultimoPrecioFacturadoDolar:
          ExcelHelper.obtenerDouble(
        fila,
        columnas['ultimoPrecio'] ?? -1,
      ),

      codigoUltimoClienteFacturado:
          ExcelHelper.obtenerTexto(
        fila,
        columnas['codigoUltimoCliente'] ?? -1,
      ),

      ultimoClienteFacturado:
          ExcelHelper.obtenerTexto(
        fila,
        columnas['ultimoCliente'] ?? -1,
      ),

      valorListaPrecioDolar:
          ExcelHelper.obtenerDouble(
        fila,
        columnas['valorLista'] ?? -1,
      ),

      valorFacturacionDolar:
          ExcelHelper.obtenerDouble(
        fila,
        columnas['valorFacturacion'] ?? -1,
      ),

      familia: ExcelHelper.obtenerTexto(
        fila,
        columnas['familia'] ?? -1,
      ),

      calibre: ExcelHelper.obtenerTexto(
        fila,
        columnas['calibre'] ?? -1,
      ),

      clase: ExcelHelper.obtenerTexto(
        fila,
        columnas['clase'] ?? -1,
      ),

      color: ExcelHelper.obtenerTexto(
        fila,
        columnas['color'] ?? -1,
      ),

      presentacion: ExcelHelper.obtenerTexto(
        fila,
        columnas['presentacion'] ?? -1,
      ),
    );
  }
}