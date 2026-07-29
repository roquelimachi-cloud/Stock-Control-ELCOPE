class StockModel {
  final String vendedor;
  final String cliente;
  final String codigo;
  final String descripcion;
  final String lote;
  final String produccion;
  final DateTime fechaIngreso;
  final double stock;
  final double peso;
  final String estado;
  final String almacen;

  StockModel({
    required this.vendedor,
    required this.cliente,
    required this.codigo,
    required this.descripcion,
    required this.lote,
    required this.produccion,
    required this.fechaIngreso,
    required this.stock,
    required this.peso,
    required this.estado,
    required this.almacen,
  });
}