class ProduccionFamilia {
  final String familia;
  final int totalOp;
  final double valorNeto;
  final double pesoCobre;

  ProduccionFamilia({
    required this.familia,
    required this.totalOp,
    required this.valorNeto,
    required this.pesoCobre,
  });

  factory ProduccionFamilia.fromMap(
      Map<String, dynamic> json) {
    return ProduccionFamilia(
      familia: json["abreviado_familia"] ?? "",
      totalOp: json["total_op"] ?? 0,
      valorNeto:
          (json["valor_neto"] ?? 0).toDouble(),
      pesoCobre:
          (json["peso_cobre"] ?? 0).toDouble(),
    );
  }
}