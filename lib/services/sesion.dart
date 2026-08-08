import '../models/usuario.dart';

class Sesion {
  static Usuario? usuarioActual;

  // ============================================================
  // ESTADO DE SESIÓN
  // ============================================================

  static bool get logueado =>
      usuarioActual != null;

  // ============================================================
  // DATOS DEL USUARIO
  // ============================================================

  static int get idUsuario =>
      usuarioActual?.id ?? 0;

  static String get nombre =>
      usuarioActual?.nombre ?? "";

  static String get usuario =>
      usuarioActual?.usuario ?? "";

  static String get rol =>
      usuarioActual?.rol ?? "";

  static String get vendedor =>
      usuarioActual?.vendedor ?? "";

  // ============================================================
  // ROLES
  // ============================================================

  static bool get esAdministrador =>
      usuarioActual?.rol == "Administrador";

  static bool get esGerencia =>
      usuarioActual?.rol == "Gerencia";

  static bool get esJefeLima =>
      usuarioActual?.rol == "Jefe Lima";

  static bool get esJefeProvincia =>
      usuarioActual?.rol == "Jefe Provincia";

  // ============================================================
  // PERFIL DE SUPERVISIÓN
  // ============================================================

  static bool get esSupervisor =>
      esGerencia ||
      esJefeLima ||
      esJefeProvincia;

  // ============================================================
  // CERRAR SESIÓN
  // ============================================================

  static void cerrarSesion() {
    usuarioActual = null;
  }
}