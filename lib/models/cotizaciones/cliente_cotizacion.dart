class ClienteCotizacion {
  final String codigoVendedor;
  final String vendedor;
  final String ruc;
  final String razonSocial;
  final String direccion;
  final String localidad;
  final String departamento;
  final String canal;
  final String giro;
  final String sector;

  const ClienteCotizacion({
    required this.codigoVendedor,
    required this.vendedor,
    required this.ruc,
    required this.razonSocial,
    required this.direccion,
    required this.localidad,
    required this.departamento,
    required this.canal,
    required this.giro,
    required this.sector,
  });

  factory ClienteCotizacion.fromMap(Map<String, dynamic> map) {
    return ClienteCotizacion(
      codigoVendedor: (map['codigo_vendedor'] ?? '').toString(),
      vendedor: (map['vendedor'] ?? '').toString(),
      ruc: (map['ruc'] ?? '').toString(),
      razonSocial: (map['razon_social'] ?? '').toString(),
      direccion: (map['direccion'] ?? '').toString(),
      localidad: (map['localidad'] ?? '').toString(),
      departamento: (map['departamento'] ?? '').toString(),
      canal: (map['canal'] ?? '').toString(),
      giro: (map['giro'] ?? '').toString(),
      sector: (map['sector'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'codigo_vendedor': codigoVendedor,
      'vendedor': vendedor,
      'ruc': ruc,
      'razon_social': razonSocial,
      'direccion': direccion,
      'localidad': localidad,
      'departamento': departamento,
      'canal': canal,
      'giro': giro,
      'sector': sector,
    };
  }
}