import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/excel/stock_excel_row.dart';
import 'supabase_service.dart';

class StockService {
  final SupabaseClient _db = SupabaseService.client;

  Future<void> sincronizar(List<StockExcelRow> rows) async {
    if (rows.isEmpty) {
      return;
    }

    // Borra el stock anterior
    await _db.from('stock').delete().neq('id', 0);

    final mapa = <String, Map<String, dynamic>>{};

    for (final r in rows) {
      final llave = "${r.codigoArticulo}|${r.lote}";

      mapa[llave] = {
        'codigo': r.codigoArticulo,
        'descripcion': r.articulo,
        'cliente': r.cliente,
        'vendedor': r.vendedor,
        'lote': r.lote,
        'modelo': r.modelo,
        'produccion': r.ordenProduccion,
        'fecha_ingreso': r.fechaIngreso?.toIso8601String(),
        'stock': r.stockAlmacen,
        'peso': r.pesoCobre,
        'estado': 'ACTIVO',
        'almacen': r.codigoAlmacen,
        'familia': r.familia,
        'calibre': r.calibre,
        'clase': r.clase,
        'color': r.color,
        'presentacion': r.presentacion,

       // PRECIOS
'lista_precio_dolar': r.listaPrecioDolar,
'valor_lista_precio_dolar': r.valorListaPrecioDolar,
'valor_facturacion_dolar': r.valorFacturacionDolar,

      };
    }

    final registros = mapa.values.toList();

    const int tamanoLote = 500;

    for (int i = 0; i < registros.length; i += tamanoLote) {
      final fin =
          (i + tamanoLote > registros.length) ? registros.length : i + tamanoLote;

      await _db.from('stock').insert(registros.sublist(i, fin));
    }
  }
}