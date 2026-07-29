import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/stock/stock_item.dart';
import 'supabase_service.dart';

class StockQueryService {
  final SupabaseClient db = SupabaseService.client;

  Future<List<StockItem>> buscar(String texto) async {
    final respuesta = await db
        .from('stock')
        .select()
       .or(
'codigo.ilike.%$texto%,descripcion.ilike.%$texto%,cliente.ilike.%$texto%,vendedor.ilike.%$texto%,lote.ilike.%$texto%,produccion.ilike.%$texto%,modelo.ilike.%$texto%',
)
        .limit(300);

    return (respuesta as List)
        .map((e) => StockItem.fromJson(e))
        .toList();
  }
}