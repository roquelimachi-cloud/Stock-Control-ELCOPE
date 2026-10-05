import '../../../services/supabase/supabase_service.dart';

class CrmCatalogosService {
  static final _db = SupabaseService.client;

  static Future<List<Map<String, dynamic>>> obtener(
    String categoria, {
    bool soloActivos = true,
  }) async {
    final builder = _db
        .from('crm_catalogos')
        .select()
        .eq('categoria', categoria);

    final data = soloActivos
        ? await builder.eq('activo', true).order('orden').order('nombre')
        : await builder.order('orden').order('nombre');

    return List<Map<String, dynamic>>.from(data);
  }

  static Future<List<String>> obtenerNombres(
    String categoria, {
    bool soloActivos = true,
  }) async {
    final rows = await obtener(categoria, soloActivos: soloActivos);
    final nombres = <String>[];
    final vistos = <String>{};
    for (final row in rows) {
      final nombre = row['nombre']?.toString().trim() ?? '';
      final clave = nombre.toUpperCase();
      if (nombre.isNotEmpty && vistos.add(clave)) {
        nombres.add(nombre);
      }
    }
    return nombres;
  }
}
