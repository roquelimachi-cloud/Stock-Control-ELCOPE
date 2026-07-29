import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/stock/stock_item.dart';
import 'supabase_service.dart';

class StockQueryService {
  final SupabaseClient db = SupabaseService.client;

  Future<List<StockItem>> buscar(String texto) async {
    var consulta = db.from('stock').select();

    if (texto.trim().isNotEmpty) {
      final palabras = texto
          .trim()
          .split(RegExp(r'\s+'))
          .where((e) => e.isNotEmpty)
          .toList();

      for (final palabra in palabras) {
        consulta = consulta.or(
          'codigo.ilike.%$palabra%,'
          'descripcion.ilike.%$palabra%,'
          'cliente.ilike.%$palabra%,'
          'vendedor.ilike.%$palabra%,'
          'lote.ilike.%$palabra%,'
          'produccion.ilike.%$palabra%,'
          'modelo.ilike.%$palabra%',
        );
      }
    }

    final respuesta = await consulta.limit(300);

    return (respuesta as List)
        .map((e) => StockItem.fromJson(e))
        .toList();
  }
}