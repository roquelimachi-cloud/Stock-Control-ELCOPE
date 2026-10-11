import '../../../services/sesion.dart';
import '../../../services/supabase/supabase_service.dart';

/// Permisos por usuario y módulo administrados desde Usuarios y Accesos.
class CrmModuloPermisos {
  static bool get esAdministrador =>
      Sesion.esAdministrador ||
      Sesion.rol.trim().toLowerCase() == 'administrador' ||
      Sesion.rol.trim().toLowerCase() == 'admin';

  static Future<Map<String, bool>> cargar(String codigoModulo) async {
    if (esAdministrador) {
      return {
        'ver': true,
        'crear': true,
        'editar': true,
        'eliminar': true,
        'imprimir': true,
      };
    }

    if (Sesion.idUsuario <= 0) {
      return {'ver': false, 'crear': false, 'editar': false, 'eliminar': false, 'imprimir': false};
    }

    try {
      final row = await SupabaseService.client
          .from('accesos_usuario')
          .select('puede_ver, puede_crear, puede_editar, puede_eliminar, puede_imprimir, accesos_modulos!inner(codigo)')
          .eq('usuario_id', Sesion.idUsuario)
          .eq('accesos_modulos.codigo', codigoModulo)
          .maybeSingle();

      if (row == null) {
        return {'ver': false, 'crear': false, 'editar': false, 'eliminar': false, 'imprimir': false};
      }

      return {
        'ver': row['puede_ver'] == true,
        'crear': row['puede_crear'] == true,
        'editar': row['puede_editar'] == true,
        'eliminar': row['puede_eliminar'] == true,
        'imprimir': row['puede_imprimir'] == true,
      };
    } catch (_) {
      // En caso de error se aplica denegación por defecto.
      return {'ver': false, 'crear': false, 'editar': false, 'eliminar': false, 'imprimir': false};
    }
  }
}
