class StockItem {
  final String codigo;
  final String descripcion;
  final String cliente;
  final String vendedor;
  final String lote;
  final String modelo;
  final double stock;
  final double peso;
  final String almacen;

  final double valorListaPrecioDolar;
  final double valorFacturacionDolar;
  final double listaPrecioDolar;

  // NUEVO CAMPO
  final String fechaIngreso;
final String prueba = "OK";
  StockItem({
    required this.codigo,
    required this.descripcion,
    required this.cliente,
    required this.vendedor,
    required this.lote,
    required this.modelo,
    required this.stock,
    required this.peso,
    required this.almacen,
    required this.valorListaPrecioDolar,
    required this.valorFacturacionDolar,
    required this.listaPrecioDolar,
    required this.fechaIngreso,
  });

  factory StockItem.fromJson(Map<String, dynamic> json) {
    return StockItem(
      codigo: json['codigo'] ?? '',
      descripcion: json['descripcion'] ?? '',
      cliente: json['cliente'] ?? '',
      vendedor: json['vendedor'] ?? '',
      lote: json['lote'] ?? '',
      modelo: json['modelo'] ?? '',
      stock: (json['stock'] ?? 0).toDouble(),
      peso: (json['peso'] ?? 0).toDouble(),
      almacen: json['almacen'] ?? '',

      listaPrecioDolar:
          (json['lista_precio_dolar'] ?? 0).toDouble(),

      valorListaPrecioDolar:
          (json['valor_lista_precio_dolar'] ?? 0).toDouble(),

      valorFacturacionDolar:
          (json['valor_facturacion_dolar'] ?? 0).toDouble(),

      fechaIngreso: json['fecha_ingreso'] ?? '',
    );
  }
}