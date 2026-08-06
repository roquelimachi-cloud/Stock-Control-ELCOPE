class ProduccionResumen {
  final int totalOp;
  final double valorNeto;
  final double pesoCobre;
  final int clientes;

  const ProduccionResumen({
    required this.totalOp,
    required this.valorNeto,
    required this.pesoCobre,
    required this.clientes,
  });

  factory ProduccionResumen.fromMap(Map<String, dynamic> json) {
    return ProduccionResumen(
      totalOp: json["total_op"] ?? 0,
      valorNeto: (json["valor_neto"] ?? 0).toDouble(),
      pesoCobre: (json["peso_cobre"] ?? 0).toDouble(),
      clientes: json["clientes"] ?? 0,
    );
  }
}