import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/imports/producto_import.dart';

class ProductService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<int> insertarProducto({
    required ProductoImport producto,
    required int familiaId,
    required int claseId,
    required int colorId,
    required int presentacionId,
  }) async {
    final response = await _client
        .from('productos')
        .insert({
          'codigo': producto.codigo,
          'descripcion': producto.descripcion,
          'familia_id': familiaId,
          'calibre': producto.calibre,
          'clase_id': claseId,
          'color_id': colorId,
          'presentacion_id': presentacionId,
          'modelo': producto.modelo,
          'unidad_medida': producto.unidad,
        })
        .select('id')
        .single();

    return response['id'] as int;
  }

  Future<void> actualizarProducto({
    required int id,
    required ProductoImport producto,
    required int familiaId,
    required int claseId,
    required int colorId,
    required int presentacionId,
  }) async {
    await _client
        .from('productos')
        .update({
          'descripcion': producto.descripcion,
          'familia_id': familiaId,
          'calibre': producto.calibre,
          'clase_id': claseId,
          'color_id': colorId,
          'presentacion_id': presentacionId,
          'modelo': producto.modelo,
          'unidad_medida': producto.unidad,
        })
        .eq('id', id);
  }
}