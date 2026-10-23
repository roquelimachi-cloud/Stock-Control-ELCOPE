import 'package:supabase_flutter/supabase_flutter.dart';

import '../sesion.dart';
import 'supabase_service.dart';

/// Cliente del backend protegido de Cliente 360.
/// No consulta crm_facturas ni crm_factura_detalles desde el dispositivo.
class CrmCliente360Service {
  final SupabaseClient _db = SupabaseService.client;

  Map<String, String> get _headers {
    final token = Sesion.tokenCliente360;
    if (token == null || token.isEmpty) {
      throw Exception('La sesión segura no está activa. Cierra sesión e ingresa nuevamente.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<List<Map<String, dynamic>>> buscarClientes({
    String busqueda = '',
    int limit = 25,
    String departamento = 'TODOS',
    String sector = 'TODOS',
    String giro = 'TODOS',
    int? anio,
  }) async {
    final response = await _db.functions.invoke(
      'crm-cliente360',
      headers: _headers,
      body: {
        'action': 'search',
        'busqueda': busqueda,
        'limit': limit,
        'departamento': departamento,
        'sector': sector,
        'giro': giro,
        'anio': anio,
      },
    );
    final payload = Map<String, dynamic>.from(response.data as Map);
    if (payload['error'] != null) {
      throw Exception('Cliente 360 búsqueda: ${payload['error']} ${payload['details'] ?? ''}'.trim());
    }
    final rows = payload['clientes'];
    if (rows is! List) return [];
    return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> obtenerDetalle({
    required String codigo,
    int? anio,
    String departamento = 'TODOS',
  }) async {
    final response = await _db.functions.invoke(
      'crm-cliente360',
      headers: _headers,
      body: {
        'action': 'detail',
        'codigo': codigo,
        'anio': anio,
        'departamento': departamento,
      },
    );
    final payload = Map<String, dynamic>.from(response.data as Map);
    if (payload['error'] != null) {
      throw Exception('Cliente 360 detalle: ${payload['error']} ${payload['details'] ?? ''}'.trim());
    }
    return payload;
  }

  Future<void> cerrarSesionSegura() async {
    final token = Sesion.tokenCliente360;
    if (token == null || token.isEmpty) return;
    try {
      await _db.functions.invoke(
        'crm-cliente360',
        headers: {'Authorization': 'Bearer $token'},
        body: {'action': 'logout'},
      );
    } finally {
      Sesion.tokenCliente360 = null;
    }
  }
}
