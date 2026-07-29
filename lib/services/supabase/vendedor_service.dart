import 'package:supabase_flutter/supabase_flutter.dart';

class VendedorService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<String>> obtenerVendedores() async {
    final response = await _supabase
        .from('stock')
        .select('vendedor');

    final vendedores = response
        .map<String>((e) => e['vendedor'].toString())
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList();

    vendedores.sort();

    return vendedores;
  }
}