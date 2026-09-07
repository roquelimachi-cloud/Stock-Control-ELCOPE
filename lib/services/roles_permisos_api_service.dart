import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RolApi {
  final int id;
  final String nombre;
  final String? descripcion;
  final bool activo;
  final int usuarios;

  const RolApi({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.activo,
    required this.usuarios,
  });
}

class PermisoRolApi {
  final int id;
  final String codigo;
  final String nombre;
  final String modulo;
  final bool asignado;

  bool puedeVer;
  bool puedeCrear;
  bool puedeEditar;
  bool puedeEliminar;
  bool puedeImprimir;

  PermisoRolApi({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.modulo,
    required this.asignado,
    required this.puedeVer,
    required this.puedeCrear,
    required this.puedeEditar,
    required this.puedeEliminar,
    required this.puedeImprimir,
  });

  bool get tieneAlgunaAccion =>
      puedeVer ||
      puedeCrear ||
      puedeEditar ||
      puedeEliminar ||
      puedeImprimir;

  bool get tieneTodasLasAcciones =>
      puedeVer &&
      puedeCrear &&
      puedeEditar &&
      puedeEliminar &&
      puedeImprimir;
}

class RolesPermisosApiService {
  RolesPermisosApiService._();

  static const String baseUrl = 'http://localhost:5298/api';

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  static String _error(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map) {
        final mensaje = decoded['mensaje']?.toString();
        if (mensaje != null && mensaje.isNotEmpty) return mensaje;

        final detail = decoded['detail']?.toString();
        if (detail != null && detail.isNotEmpty) return detail;

        final title = decoded['title']?.toString();
        if (title != null && title.isNotEmpty) return title;
      }
    } catch (_) {}

    return 'Error HTTP ${response.statusCode}.';
  }

  static Future<List<RolApi>> listarRoles() async {
    final response = await http.get(
      Uri.parse('$baseUrl/Roles'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception(_error(response));
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      throw Exception('El API devolvió un formato de roles no válido.');
    }

    return decoded.map<RolApi>((item) {
      final map = Map<String, dynamic>.from(item as Map);

      return RolApi(
        id: _toInt(map['rolId'] ?? map['RolId'] ?? map['id']),
        nombre: _toString(map['nombre'] ?? map['Nombre']),
        descripcion: _nullableString(
          map['descripcion'] ?? map['Descripcion'],
        ),
        activo: _toBool(map['activo'] ?? map['Activo']),
        usuarios: _toInt(map['usuarios'] ?? map['Usuarios']),
      );
    }).toList();
  }

  static Future<void> crearRol(
    String nombre,
    String descripcion,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/Roles'),
      headers: await _headers(),
      body: jsonEncode({
        'nombre': nombre.trim(),
        'descripcion': descripcion.trim(),
        'activo': true,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception(_error(response));
    }
  }

  static Future<void> actualizarRol(
    int id,
    String nombre,
    String descripcion,
    bool activo,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/Roles/$id'),
      headers: await _headers(),
      body: jsonEncode({
        'nombre': nombre.trim(),
        'descripcion': descripcion.trim(),
        'activo': activo,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(_error(response));
    }
  }

  static Future<void> cambiarEstado(
    int id,
    bool activo,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/Roles/$id/estado'),
      headers: await _headers(),
      body: jsonEncode({'activo': activo}),
    );

    if (response.statusCode != 200) {
      throw Exception(_error(response));
    }
  }

  static Future<List<PermisoRolApi>> listarPermisos(
    int rolId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/Permisos?rolId=$rolId'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception(_error(response));
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      throw Exception(
        'El API devolvió un formato de permisos no válido.',
      );
    }

    return decoded.map<PermisoRolApi>((item) {
      final map = Map<String, dynamic>.from(item as Map);

      return PermisoRolApi(
        id: _toInt(
          map['permisoId'] ?? map['PermisoId'] ?? map['id'],
        ),
        codigo: _toString(
          map['codigo'] ?? map['Codigo'],
        ),
        nombre: _toString(
          map['nombre'] ?? map['Nombre'],
        ),
        modulo: _toString(
          map['modulo'] ?? map['Modulo'],
        ),
        asignado: _toBool(
          map['asignado'] ?? map['Asignado'],
        ),
        puedeVer: _toBool(
          map['puedeVer'] ?? map['PuedeVer'],
        ),
        puedeCrear: _toBool(
          map['puedeCrear'] ?? map['PuedeCrear'],
        ),
        puedeEditar: _toBool(
          map['puedeEditar'] ?? map['PuedeEditar'],
        ),
        puedeEliminar: _toBool(
          map['puedeEliminar'] ?? map['PuedeEliminar'],
        ),
        puedeImprimir: _toBool(
          map['puedeImprimir'] ?? map['PuedeImprimir'],
        ),
      );
    }).toList();
  }

  static Future<void> guardarPermisos(
    int rolId,
    List<PermisoRolApi> permisos,
  ) async {
    final body = permisos.map((p) {
      return {
        'permisoId': p.id,
        'puedeVer': p.puedeVer,
        'puedeCrear': p.puedeCrear,
        'puedeEditar': p.puedeEditar,
        'puedeEliminar': p.puedeEliminar,
        'puedeImprimir': p.puedeImprimir,
      };
    }).toList();

    final response = await http.put(
      Uri.parse('$baseUrl/Permisos/rol/$rolId'),
      headers: await _headers(),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(_error(response));
    }
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().trim().toLowerCase();

    return text == 'true' ||
        text == '1' ||
        text == 'si' ||
        text == 'sí' ||
        text == 'yes';
  }

  static String _toString(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();

    if (text == null ||
        text.isEmpty ||
        text.toLowerCase() == 'null') {
      return null;
    }

    return text;
  }
}
