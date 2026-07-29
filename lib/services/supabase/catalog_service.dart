import 'package:supabase_flutter/supabase_flutter.dart';

class CatalogService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<int> insertarSiNoExiste({
    required String tabla,
    required String campo,
    required String valor,
  }) async {
    if (valor.trim().isEmpty) {
      return 0;
    }

    final existente = await _supabase
        .from(tabla)
        .select('id')
        .eq(campo, valor)
        .maybeSingle();

    if (existente != null) {
      return existente['id'] as int;
    }

    final nuevo = await _supabase
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
    required String descripcion,
  }) async {
    if (codigo.trim().isEmpty) {
      return 0;
    }

    final existente = await _supabase
        .from('almacenes')
        .select('id')
        .eq('codigo', codigo)
        .maybeSingle();

    if (existente != null) {
      return existente['id'] as int;
    }

    final nuevo = await _supabase
        .from('almacenes')
        .insert({
          'codigo': codigo,
          'descripcion': descripcion,
        })
        .select('id')
        .single();

    return nuevo['id'] as int;
  }
}