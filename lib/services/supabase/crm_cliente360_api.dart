import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class CrmCliente360Api {
  static final SupabaseClient _db = SupabaseService.client;

  static Map<String, String> _headers(String? token) {
    final t = token?.trim() ?? '';
    if (t.isEmpty) throw Exception('No hay sesión segura de Cliente 360. Cierra sesión e ingresa nuevamente.');
    return {'Authorization': 'Bearer $t'};
  }

  static Future<List<dynamic>> buscar({
    required String? token,
    required String busqueda,
    required String departamento,
    required int? anio,
  }) async {
    final response = await _db.functions.invoke(
      'crm-cliente360',
      headers: _headers(token),
      body: {
        'action': 'search',
        'busqueda': busqueda,
        'departamento': departamento,
        'anio': anio,
        'limit': 25,
      },
    );
    final payload = Map<String, dynamic>.from(response.data as Map);
    if (payload['error'] != null) {
      throw Exception('Cliente 360 búsqueda: ${payload['error']} ${payload['details'] ?? ''}');
    }
    return List<dynamic>.from(payload['clientes'] ?? const []);
  }

  static Future<Map<String, dynamic>> detalle({
    required String codigo,
    required String? token,
    required int? anio,
  }) async {
    final response = await _db.functions.invoke(
      'crm-cliente360',
      headers: _headers(token),
      body: {
        'action': 'detail',
        'codigo': codigo,
        'anio': anio,
      },
    );
    final payload = Map<String, dynamic>.from(response.data as Map);
    if (payload['error'] != null) {
      throw Exception('Cliente 360 detalle: ${payload['error']} ${payload['details'] ?? ''}');
    }
    return payload;
  }
}
