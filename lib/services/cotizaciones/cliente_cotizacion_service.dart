import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/cotizaciones/cliente_cotizacion.dart';

class ClienteCotizacionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<ClienteCotizacion>> buscarClientes(
    String texto,
  ) async {
    final busqueda = texto.trim();

    if (busqueda.isEmpty) {
      return [];
    }

    final resultado = await _supabase
        .from('clientes')
        .select()
        .or(
          'ruc.ilike.%$busqueda%,'
          'razon_social.ilike.%$busqueda%,'
          'codigo_vendedor.ilike.%$busqueda%',
        )
        .eq('activo', true)
        .order('razon_social')
        .limit(30);

    return (resultado as List)
        .map(
          (fila) => ClienteCotizacion.fromMap(
            Map<String, dynamic>.from(fila),
          ),
        )
        .toList();
  }
}