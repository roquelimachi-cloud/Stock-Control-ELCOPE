import '../../models/excel/stock_excel_row.dart';
import '../../models/imports/almacen_import.dart';
import '../../models/imports/clase_import.dart';
import '../../models/imports/cliente_import.dart';
import '../../models/imports/color_import.dart';
import '../../models/imports/familia_import.dart';
import '../../models/imports/presentacion_import.dart';
import '../../models/imports/producto_import.dart';
import '../../models/imports/vendedor_import.dart';

class ImportBuilder {
  const ImportBuilder();

  ProductoImport buildProducto(StockExcelRow row) {
    return ProductoImport(
      codigo: row.codigoArticulo.trim(),
      descripcion: row.articulo.trim(),
      familia: row.familia.trim(),
      calibre: row.calibre.trim(),
      clase: row.clase.trim(),
      color: row.color.trim(),
      presentacion: row.presentacion.trim(),
      unidad: row.unidadMedida.trim(),
      modelo: row.modelo.trim(),
    );
  }

  ClienteImport? buildCliente(StockExcelRow row) {
    if (row.codigoCliente.trim().isEmpty) {
      return null;
    }

    return ClienteImport(
      codigo: row.codigoCliente.trim(),
      nombre: row.cliente.trim(),
    );
  }

  VendedorImport? buildVendedor(StockExcelRow row) {
    if (row.codigoVendedor.trim().isEmpty) {
      return null;
    }

    return VendedorImport(
      codigo: row.codigoVendedor.trim(),
      nombre: row.vendedor.trim(),
    );
  }

  AlmacenImport? buildAlmacen(StockExcelRow row) {
    if (row.codigoAlmacen.trim().isEmpty) {
      return null;
    }

    return AlmacenImport(
      codigo: row.codigoAlmacen.trim(),
      nombre: row.codigoAlmacen.trim(),
    );
  }

  FamiliaImport? buildFamilia(StockExcelRow row) {
    if (row.familia.trim().isEmpty) {
      return null;
    }

    return FamiliaImport(
      nombre: row.familia.trim(),
    );
  }

  ClaseImport? buildClase(StockExcelRow row) {
    if (row.clase.trim().isEmpty) {
      return null;
    }

    return ClaseImport(
      nombre: row.clase.trim(),
    );
  }

  ColorImport? buildColor(StockExcelRow row) {
    if (row.color.trim().isEmpty) {
      return null;
    }

    return ColorImport(
      nombre: row.color.trim(),
    );
  }

  PresentacionImport? buildPresentacion(StockExcelRow row) {
    if (row.presentacion.trim().isEmpty) {
      return null;
    }

    return PresentacionImport(
      nombre: row.presentacion.trim(),
    );
  }
}