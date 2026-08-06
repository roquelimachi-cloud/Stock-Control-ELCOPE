class ProduccionModel {
  final String canal;
  final String representante;
  final DateTime? fechaOrdenVenta;
  final int? nroPedido;
  final String numeroProduccion;
  final String cliente;
  final String? clase;
  final String? abreviadoFamilia;
  final String? codigoArticulo;
  final String? articulo;
  final DateTime? fechaProduccion;
  final DateTime? fechaEntregaEstimada;
  final int? diasRetraso;
  final double? cantidadTotal;
  final String? medida;
  final String? presentacion;
  final double? valorNeto;
  final double? pesoCobre;
  final int? numeroSemana;

  ProduccionModel({
    required this.canal,
    required this.representante,
    this.fechaOrdenVenta,
    this.nroPedido,
    required this.numeroProduccion,
    required this.cliente,
    this.clase,
    this.abreviadoFamilia,
    this.codigoArticulo,
    this.articulo,
    this.fechaProduccion,
    this.fechaEntregaEstimada,
    this.diasRetraso,
    this.cantidadTotal,
    this.medida,
    this.presentacion,
    this.valorNeto,
    this.pesoCobre,
    this.numeroSemana,
  });

  factory ProduccionModel.fromMap(Map<String, dynamic> map) {
    return ProduccionModel(
      canal: map["canal"] ?? "",
      representante: map["representante"] ?? "",
      fechaOrdenVenta: map["fecha_orden_venta"] != null
          ? DateTime.tryParse(map["fecha_orden_venta"].toString())
          : null,
      nroPedido: map["nro_pedido"],
      numeroProduccion: map["numero_produccion"] ?? "",
      cliente: map["cliente"] ?? "",
      clase: map["clase"],
      abreviadoFamilia: map["abreviado_familia"],
      codigoArticulo: map["codigo_articulo"],
      articulo: map["articulo"],
      fechaProduccion: map["fecha_produccion"] != null
          ? DateTime.tryParse(map["fecha_produccion"].toString())
          : null,
      fechaEntregaEstimada: map["fecha_entrega_estimada"] != null
          ? DateTime.tryParse(
              map["fecha_entrega_estimada"].toString(),
            )
          : null,
      diasRetraso: map["dias_retraso"],
      cantidadTotal:
          (map["cantidad_total"] as num?)?.toDouble(),
      medida: map["medida"],
      presentacion: map["presentacion"],
      valorNeto:
          (map["valor_neto"] as num?)?.toDouble(),
      pesoCobre:
          (map["peso_cobre"] as num?)?.toDouble(),
      numeroSemana: map["numero_semana"],
    );
  }
 
 //=========================================================
// ESTADO CALCULADO
//=========================================================

String get estado {

  if (fechaProduccion == null) {
    return "Sin Fecha";
  }

  final retraso = diasRetraso ?? 0;

  if (retraso <= 0) {
    return "En Tiempo";
  }

  if (retraso <= 7) {
    return "Próximo";
  }

  if (retraso <= 30) {
    return "Retrasado";
  }

  return "Crítico";
}

  Map<String, dynamic> toMap() {
    return {
      "canal": canal,
      "representante": representante,
      "fecha_orden_venta": fechaOrdenVenta?.toIso8601String(),
      "nro_pedido": nroPedido,
      "numero_produccion": numeroProduccion,
      "cliente": cliente,
      "clase": clase,
      "abreviado_familia": abreviadoFamilia,
      "codigo_articulo": codigoArticulo,
      "articulo": articulo,
      "fecha_produccion": fechaProduccion?.toIso8601String(),
      "fecha_entrega_estimada":
          fechaEntregaEstimada?.toIso8601String(),
      "dias_retraso": diasRetraso,
      "cantidad_total": cantidadTotal,
      "medida": medida,
      "presentacion": presentacion,
      "valor_neto": valorNeto,
      "peso_cobre": pesoCobre,
      "numero_semana": numeroSemana,
    };
  }
}