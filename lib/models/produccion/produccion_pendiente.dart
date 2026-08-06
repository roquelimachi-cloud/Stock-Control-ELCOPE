class ProduccionPendiente {
  final String? id;

  final String canal;
  final String representante;
  final DateTime? fechaOrdenVenta;
  final int? nroPedido;
  final String numeroProduccion;
  final String cliente;
  final String clase;
  final String abreviadoFamilia;
  final String codigoArticulo;
  final String articulo;
  final DateTime? fechaProduccion;
  final DateTime? fechaEntregaEstimada;
  final int diasRetraso;
  final double cantidadTotal;
  final String medida;
  final String presentacion;
  final double valorNeto;
  final double pesoCobre;
  final int numeroSemana;

  ProduccionPendiente({
    this.id,
    required this.canal,
    required this.representante,
    this.fechaOrdenVenta,
    this.nroPedido,
    required this.numeroProduccion,
    required this.cliente,
    required this.clase,
    required this.abreviadoFamilia,
    required this.codigoArticulo,
    required this.articulo,
    this.fechaProduccion,
    this.fechaEntregaEstimada,
    required this.diasRetraso,
    required this.cantidadTotal,
    required this.medida,
    required this.presentacion,
    required this.valorNeto,
    required this.pesoCobre,
    required this.numeroSemana,
  });

  factory ProduccionPendiente.fromJson(
      Map<String, dynamic> json) {
    return ProduccionPendiente(
      id: json['id'],

      canal: json['canal'] ?? '',

      representante:
          json['representante'] ?? '',

      fechaOrdenVenta:
          json['fecha_orden_venta'] == null
              ? null
              : DateTime.parse(
                  json['fecha_orden_venta']),

      nroPedido: json['nro_pedido'],

      numeroProduccion:
          json['numero_produccion'] ?? '',

      cliente: json['cliente'] ?? '',

      clase: json['clase'] ?? '',

      abreviadoFamilia:
          json['abreviado_familia'] ?? '',

      codigoArticulo:
          json['codigo_articulo'] ?? '',

      articulo: json['articulo'] ?? '',

      fechaProduccion:
          json['fecha_produccion'] == null
              ? null
              : DateTime.parse(
                  json['fecha_produccion']),

      fechaEntregaEstimada:
          json['fecha_entrega_estimada'] ==
                  null
              ? null
              : DateTime.parse(
                  json[
                      'fecha_entrega_estimada']),

      diasRetraso:
          json['dias_retraso'] ?? 0,

      cantidadTotal:
          (json['cantidad_total'] ?? 0)
              .toDouble(),

      medida: json['medida'] ?? '',

      presentacion:
          json['presentacion'] ?? '',

      valorNeto:
          (json['valor_neto'] ?? 0)
              .toDouble(),

      pesoCobre:
          (json['peso_cobre'] ?? 0)
              .toDouble(),

      numeroSemana:
          json['numero_semana'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,

      'canal': canal,

      'representante':
          representante,

      'fecha_orden_venta':
          fechaOrdenVenta
              ?.toIso8601String(),

      'nro_pedido': nroPedido,

      'numero_produccion':
          numeroProduccion,

      'cliente': cliente,

      'clase': clase,

      'abreviado_familia':
          abreviadoFamilia,

      'codigo_articulo':
          codigoArticulo,

      'articulo': articulo,

      'fecha_produccion':
          fechaProduccion
              ?.toIso8601String(),

      'fecha_entrega_estimada':
          fechaEntregaEstimada
              ?.toIso8601String(),

      'dias_retraso':
          diasRetraso,

      'cantidad_total':
          cantidadTotal,

      'medida': medida,

      'presentacion':
          presentacion,

      'valor_neto':
          valorNeto,

      'peso_cobre':
          pesoCobre,

      'numero_semana':
          numeroSemana,
    };
  }
}