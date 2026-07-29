import 'package:supabase_flutter/supabase_flutter.dart';

class CatalogService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<int> insertarSiNoExiste({
    required String tabla,
    required String campo,
    required String valor,
  }) async {
    final existe = await _client
        .from(tabla)
        .select('id')
        .eq(campo, valor)
        .maybeSingle();

    if (existe != null) {
      return existe['id'] as int;
    }

    final nuevo = await _client
        .from(tabla)
        .insert({
          campo: valor,
        })
        .select('id')
        .single();

    return nuevo['id'] as int;
  }

  Future<int> insertarAlmacen({
    required String codigo,
    required String nombre,
  }) async {
    final existe = await _client
        .from('almacenes')
        .select('id')
        .eq('codigo', codigo)
        .maybeSingle();

    if (existe != null) {
      return existe['id'] as int;
    }

    final nuevo = await _client
        .from('almacenes')
        .insert({
          'codigo': codigo,
          'nombre': nombre,
        })
        .select('id')
        .single();

    return nuevo['id'] as int;
  }
}