class Usuario {
  final int id;
  final String usuario;
  final String nombre;
  final String correo;
  final String rol;
  final String vendedor;
  final bool activo;

  Usuario({
    required this.id,
    required this.usuario,
    required this.nombre,
    required this.correo,
    required this.rol,
    required this.vendedor,
    required this.activo,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] ?? 0,
      usuario: json['usuario'] ?? '',
      nombre: json['nombre'] ?? '',
      correo: json['correo'] ?? '',
      rol: json['rol'] ?? '',
      vendedor: json['vendedor'] ?? '',
      activo: json['activo'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuario': usuario,
      'nombre': nombre,
      'correo': correo,
      'rol': rol,
      'vendedor': vendedor,
      'activo': activo,
    };
  }
}