import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseCacheService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, int>> cargarProductos() async {
    final response = await _client
        .from('productos')
        .select('id,codigo');

    final Map<String, int> datos = {};

    for (final item in response) {
      datos[item['codigo']] = item['id'];
    }

    return datos;
  }

  Future<Map<String, int>> cargarClientes() async {
    final response = await _client
        .from('clientes')
        .select('id,codigo');

    final Map<String, int> datos = {};

    for (final item in response) {
      datos[item['codigo']] = item['id'];
    }

    return datos;
  }

  Future<Map<String, int>> cargarVendedores() async {
    final response = await _client
        .from('vendedores')
        .select('id,codigo');

    final Map<String, int> datos = {};

    for (final item in response) {
      datos[item['codigo']] = item['id'];
    }

    return datos;
  }

  Future<Map<String, int>> cargarFamilias() async {
    final response = await _client
        .from('familias')
        .select('id,nombre');

    final Map<String, int> datos = {};

    for (final item in response) {
      datos[item['nombre']] = item['id'];
    }

    return datos;
  }

  Future<Map<String, int>> cargarClases() async {
    final response = await _client
        .from('clases')
        .select('id,nombre');

    final Map<String, int> datos = {};

    for (final item in response) {
      datos[item['nombre']] = item['id'];
    }

    return datos;
  }

  Future<Map<String, int>> cargarColores() async {
    final response = await _client
        .from('colores')
        .select('id,nombre');

    final Map<String, int> datos = {};

    for (final item in response) {
      datos[item['nombre']] = item['id'];
    }

    return datos;
  }

  Future<Map<String, int>> cargarPresentaciones() async {
    final response = await _client
        .from('presentaciones')
        .select('id,nombre');

    final Map<String, int> datos = {};

    for (final item in response) {
      datos[item['nombre']] = item['id'];
    }

    return datos;
  }

  Future<Map<String, int>> cargarAlmacenes() async {
    final response = await _client
        .from('almacenes')
        .select('id,codigo');

    final Map<String, int> datos = {};

    for (final item in response) {
      datos[item['codigo']] = item['id'];
    }

    return datos;
  }
}