import '../models/usuario.dart';

class Sesion {
  static Usuario? usuarioActual;

  static bool get logueado => usuarioActual != null;

  static bool get esAdministrador =>
      usuarioActual?.rol == "Administrador";

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

  static void cerrarSesion() {
    usuarioActual = null;
  }
}