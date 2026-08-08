import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/usuario.dart';
import 'supabase_service.dart';

class UsuarioService {
  final SupabaseClient db = SupabaseService.client;

  // ============================================================
  // OBTENER TODOS LOS USUARIOS
  // ============================================================

  Future<List<Usuario>> obtenerUsuarios() async {
    final respuesta = await db
        .from('usuarios')
        .select()
        .order('nombre');

    return (respuesta as List)
        .map(
          (e) => Usuario.fromJson(e),
        )
        .toList();
  }

  // ============================================================
  // INSERTAR USUARIO
  // ============================================================

  Future<void> insertarUsuario({
    required String usuario,
    required String nombre,
    required String correo,
    required String password,
    required String rol,
    required String vendedor,
  }) async {
    await db.from('usuarios').insert({
      'usuario': usuario,
      'nombre': nombre,
      'correo': correo,
      'password': password,
      'rol': rol,
      'vendedor': vendedor,
      'activo': true,
    });
  }

  // ============================================================
  // ACTUALIZAR USUARIO
  // ============================================================

  Future<void> actualizarUsuario(
    int id, {
    required String usuario,
    required String nombre,
    required String correo,
    required String password,
    required String rol,
    required String vendedor,
    required bool activo,
  }) async {
    final datos = <String, dynamic>{
      'usuario': usuario,
      'nombre': nombre,
      'correo': correo,
      'rol': rol,
      'vendedor': vendedor,
      'activo': activo,
    };

    // Solo actualizamos password si se ingresó una nueva.
    if (password.trim().isNotEmpty) {
      datos['password'] = password.trim();
    }

    await db
        .from('usuarios')
        .update(datos)
        .eq('id', id);
  }

  // ============================================================
  // ELIMINAR USUARIO
  // ============================================================

  Future<void> eliminarUsuario(int id) async {
    await db
        .from('usuarios')
        .delete()
        .eq('id', id);
  }

  // ============================================================
  // ACTUALIZAR MI PERFIL
  // ============================================================

  Future<void> actualizarMiPerfil({
    required int id,
    required String nombre,
    required String correo,
    required String password,
  }) async {
    final datos = <String, dynamic>{
      'nombre': nombre,
      'correo': correo,
    };

    if (password.trim().isNotEmpty) {
      datos['password'] = password.trim();
    }

    await db
        .from('usuarios')
        .update(datos)
        .eq('id', id);
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<Usuario?> login(
    String usuario,
    String password,
  ) async {
    final respuesta = await db
        .from('usuarios')
        .select()
        .eq('usuario', usuario)
        .eq('password', password);

    if (respuesta.isEmpty) {
      return null;
    }

    return Usuario.fromJson(
      respuesta.first,
    );
  }

  // ============================================================
  // OBTENER VENDEDORES PERMITIDOS
  // ============================================================
  //
  // Devuelve los nombres de vendedores que el administrador
  // asignó al jefe.
  //
  // Ejemplo:
  //
  // Richard Figueroa
  // ID = 15
  //
  // devuelve:
  //
  // [
  //   "Michael",
  //   "Daniela",
  //   "Johana"
  // ]
  //
  // ============================================================

  Future<List<String>> obtenerVendedoresPermitidos(
    int usuarioJefeId,
  ) async {
    final respuesta = await db
        .from('usuario_permisos')
        .select('vendedor')
        .eq(
          'usuario_jefe_id',
          usuarioJefeId,
        );

    return (respuesta as List)
        .map(
          (e) => e['vendedor']
              .toString()
              .trim(),
        )
        .where(
          (e) => e.isNotEmpty,
        )
        .toList();
  }

  // ============================================================
  // GUARDAR PERMISOS POR VENDEDOR
  // ============================================================
  //
  // Primero elimina los permisos anteriores.
  //
  // Después guarda exactamente los vendedores seleccionados.
  //
  // ============================================================

  Future<void> guardarPermisosVendedores({
    required int usuarioJefeId,
    required List<String> vendedores,
  }) async {
    // ----------------------------------------------------------
    // 1. ELIMINAR PERMISOS ANTERIORES
    // ----------------------------------------------------------

    await db
        .from('usuario_permisos')
        .delete()
        .eq(
          'usuario_jefe_id',
          usuarioJefeId,
        );

    // ----------------------------------------------------------
    // 2. SI NO SE SELECCIONÓ NINGÚN VENDEDOR
    // ----------------------------------------------------------

    if (vendedores.isEmpty) {
      return;
    }

    // ----------------------------------------------------------
    // 3. LIMPIAR Y ELIMINAR DUPLICADOS
    // ----------------------------------------------------------

    final vendedoresLimpios = vendedores
        .map(
          (v) => v.trim(),
        )
        .where(
          (v) => v.isNotEmpty,
        )
        .toSet()
        .toList();

    // ----------------------------------------------------------
    // 4. PREPARAR REGISTROS
    // ----------------------------------------------------------

    final registros =
        vendedoresLimpios.map(
      (vendedor) {
        return {
          'usuario_jefe_id':
              usuarioJefeId,
          'vendedor': vendedor,
        };
      },
    ).toList();

    // ----------------------------------------------------------
    // 5. INSERTAR EN SUPABASE
    // ----------------------------------------------------------

    await db
        .from('usuario_permisos')
        .insert(registros);
  }
}