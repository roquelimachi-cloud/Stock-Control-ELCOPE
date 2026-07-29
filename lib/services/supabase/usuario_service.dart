import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/usuario.dart';
import 'supabase_service.dart';

class UsuarioService {
  final SupabaseClient db = SupabaseService.client;

  Future<List<Usuario>> obtenerUsuarios() async {
    final respuesta = await db
        .from('usuarios')
        .select()
        .order('nombre');

    return (respuesta as List)
        .map((e) => Usuario.fromJson(e))
        .toList();
  }

  Future<void> insertarUsuario({
    required String usuario,
    required String nombre,
    required String correo,
    required String password,
    required String rol,
  }) async {
    await db.from('usuarios').insert({
      'usuario': usuario,
      'nombre': nombre,
      'correo': correo,
      'password': password,
      'rol': rol,
      'activo': true,
    });
  }

  Future<void> actualizarUsuario(
    int id, {
    required String usuario,
    required String nombre,
    required String correo,
    required String password,
    required String rol,
    required bool activo,
  }) async {
    await db
        .from('usuarios')
        .update({
          'usuario': usuario,
          'nombre': nombre,
          'correo': correo,
          'password': password,
          'rol': rol,
          'activo': activo,
        })
        .eq('id', id);
  }

  Future<void> eliminarUsuario(int id) async {
    await db
        .from('usuarios')
        .delete()
        .eq('id', id);
  }

  /// Actualiza únicamente el perfil del usuario que inició sesión.
Future<void> actualizarMiPerfil({
  required int id,
  required String nombre,
  required String correo,
  required String password,
}) async {

  if (password.trim().isEmpty) {

    await db
        .from('usuarios')
        .update({
          'nombre': nombre,
          'correo': correo,
        })
        .eq('id', id);

  } else {

    await db
        .from('usuarios')
        .update({
          'nombre': nombre,
          'correo': correo,
          'password': password.trim(),
        })
        .eq('id', id);

  }
}
  Future<Usuario?> login(
    String usuario,
    String password,
  ) async {
    final respuesta = await db
        .from('usuarios')
        .select()
        .eq('usuario', usuario)
        .eq('password', password);

    print("RESPUESTA LOGIN:");
    print(respuesta);

    if (respuesta.isEmpty) {
      return null;
    }

    return Usuario.fromJson(respuesta.first);
  }
}