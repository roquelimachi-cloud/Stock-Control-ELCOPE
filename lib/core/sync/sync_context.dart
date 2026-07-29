import '../../models/excel/stock_excel_row.dart';

import '../../models/imports/almacen_import.dart';
import '../../models/imports/clase_import.dart';
import '../../models/imports/cliente_import.dart';
import '../../models/imports/color_import.dart';
import '../../models/imports/familia_import.dart';
import '../../models/imports/presentacion_import.dart';
import '../../models/imports/producto_import.dart';
import '../../models/imports/vendedor_import.dart';

class SyncContext {
  //=========================================================
  // FILAS LEÍDAS DEL EXCEL
  //=========================================================

  final List<StockExcelRow> rows = [];

  //=========================================================
  // OBJETOS DE IMPORTACIÓN
  //=========================================================

  final Map<String, ProductoImport> productos = {};

  final Map<String, ClienteImport> clientes = {};

  final Map<String, VendedorImport> vendedores = {};

  final Map<String, AlmacenImport> almacenes = {};

  final Map<String, FamiliaImport> familias = {};

  final Map<String, ClaseImport> clases = {};

  final Map<String, ColorImport> colores = {};

  final Map<String, PresentacionImport> presentaciones = {};

  //=========================================================
  // CACHE DE IDS EN SUPABASE
  //=========================================================

  final Map<String, int> productosDB = {};

  final Map<String, int> clientesDB = {};

  final Map<String, int> vendedoresDB = {};

  final Map<String, int> almacenesDB = {};

  final Map<String, int> familiasDB = {};

  final Map<String, int> clasesDB = {};

  final Map<String, int> coloresDB = {};

  final Map<String, int> presentacionesDB = {};

  //=========================================================
  // LIMPIAR CONTEXTO
  //=========================================================

  void clear() {
    rows.clear();

    productos.clear();
    clientes.clear();
    vendedores.clear();
    almacenes.clear();

    familias.clear();
    clases.clear();
    colores.clear();
    presentaciones.clear();

    productosDB.clear();
    clientesDB.clear();
    vendedoresDB.clear();
    almacenesDB.clear();

    familiasDB.clear();
    clasesDB.clear();
    coloresDB.clear();
    presentacionesDB.clear();
  }
}