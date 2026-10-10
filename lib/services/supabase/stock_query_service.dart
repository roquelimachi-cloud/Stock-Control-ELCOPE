import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/stock/stock_item.dart';
import 'supabase_service.dart';

class StockQueryService {
  final SupabaseClient db = SupabaseService.client;

  Future<List<StockItem>> buscar(String texto) async {
    final entrada = texto.trim();

    // No consultar cientos de filas al abrir la pantalla.
    // La consulta se realiza cuando el usuario escribe una búsqueda.
    if (entrada.isEmpty) return <StockItem>[];

    final palabras = _separarBusqueda(entrada);
    if (palabras.isEmpty) return <StockItem>[];

    var consulta = db.from('stock').select();

    // Cada término debe aparecer en al menos uno de los campos.
    // Esto permite búsquedas compactas como N2XOH4 aunque la descripción
    // esté guardada como "N2XOH 0.6/1kV 4 mm2".
    for (final palabra in palabras) {
      final segura = palabra
          .replaceAll(',', '')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_')
          .trim();
      if (segura.isEmpty) continue;

      consulta = consulta.or(
        'codigo.ilike.%$segura%,'
        'descripcion.ilike.%$segura%,'
        'cliente.ilike.%$segura%,'
        'vendedor.ilike.%$segura%,'
        'lote.ilike.%$segura%,'
        'produccion.ilike.%$segura%,'
        'modelo.ilike.%$segura%',
      );
    }

    final respuesta = await consulta.limit(50);

    return (respuesta as List)
        .map((e) => StockItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  List<String> _separarBusqueda(String entrada) {
    final normalizada = entrada.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final partes = normalizada.split(' ').where((e) => e.isNotEmpty).toList();

    // Convierte búsquedas compactas de familia + calibre/sección:
    // "n2xoh4" -> ["n2xoh", "4"]; "n2xoh10" -> ["n2xoh", "10"].
    // No divide consultas que ya contienen espacios.
    if (partes.length == 1) {
      final compacta = partes.first.replaceAll(RegExp(r'[^a-z0-9.]'), '');
      final match = RegExp(r'^([a-z]+\d+[a-z]+)(\d+(?:\.\d+)?)$')
          .firstMatch(compacta);
      if (match != null) {
        final familia = match.group(1) ?? '';
        final medida = match.group(2) ?? '';
        if (familia.isNotEmpty && medida.isNotEmpty) {
          return <String>[familia, medida];
        }
      }
    }

    return partes;
  }
}
