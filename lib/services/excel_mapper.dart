import 'package:excel/excel.dart';

import '../models/stock_item.dart';
import 'excel_date.dart';
import 'excel_helper.dart';

class ExcelMapper {
  ExcelMapper._();

  static StockItem convertir(
    List<Data?> fila,
    Map<String, int> columnas,
  ) {
    return StockItem(
      codigoAlmacen: ExcelHelper.obtenerTexto(
        fila,
        columnas['codigoAlmacen'] ?? -1,
      ),

      codigo: ExcelHelper.obtenerTexto(
        fila,
        columnas['codigoArticulo'] ?? -1,
      ),

      descripcion: ExcelHelper.obtenerTexto(
        fila,
        columnas['articulo'] ?? -1,
      ),

      lote: ExcelHelper.obtenerTexto(
        fila,
        columnas['lote'] ?? -1,
      ),

      stock: ExcelHelper.obtenerDouble(
        fila,
        columnas['stock'] ?? -1,
      ),

      peso: ExcelHelper.obtenerDouble(
        fila,
        columnas['peso'] ?? -1,
      ),

      fechaIngreso: ExcelDate.convertir(
        (columnas['fechaIngreso'] ?? -1) >= 0 &&
                (columnas['fechaIngreso'] ?? -1) < fila.length
            ? fila[columnas['fechaIngreso']!]
            : null,
      ),

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

      fechaOrdenProduccion: ExcelDate.convertir(
        (columnas['fechaOrdenProduccion'] ?? -1) >= 0 &&
                (columnas['fechaOrdenProduccion'] ?? -1) < fila.length
            ? fila[columnas['fechaOrdenProduccion']!]
            : null,
      ),

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

      ultimoPrecioFacturadoDolar: ExcelHelper.obtenerDouble(
        fila,
        columnas['ultimoPrecio'] ?? -1,
      ),

      codigoUltimoCliente: ExcelHelper.obtenerTexto(
        fila,
        columnas['codigoUltimoCliente'] ?? -1,
      ),

      ultimoCliente: ExcelHelper.obtenerTexto(
        fila,
        columnas['ultimoCliente'] ?? -1,
      ),

      valorListaPrecio: ExcelHelper.obtenerDouble(
        fila,
        columnas['valorLista'] ?? -1,
      ),

      valorFacturacion: ExcelHelper.obtenerDouble(
        fila,
        columnas['valorFacturacion'] ?? -1,
      ),

      almacen: ExcelHelper.obtenerTexto(
        fila,
        columnas['codigoAlmacen'] ?? -1,
      ),

      estado: "",

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