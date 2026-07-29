class StockExcelRow {
  final String codigoAlmacen;
  final String codigoArticulo;
  final String articulo;
  final String lote;
  final double stockAlmacen;
  final double pesoCobre;
  final DateTime? fechaIngreso;
  final String codigoVendedor;
  final String vendedor;
  final String codigoCliente;
  final String cliente;
  final String ordenProduccion;
  final DateTime? fechaOrdenProduccion;
  final String modelo;
  final String unidadMedida;
  final double cantidadEmpaque;
  final double listaPrecioDolar;
  final double ultimoPrecioFacturadoDolar;
  final String codigoUltimoClienteFacturado;
  final String ultimoClienteFacturado;
  final double valorListaPrecioDolar;
  final double valorFacturacionDolar;
  final String familia;
  final String calibre;
  final String clase;
  final String color;
  final String presentacion;

  const StockExcelRow({
    required this.codigoAlmacen,
    required this.codigoArticulo,
    required this.articulo,
    required this.lote,
    required this.stockAlmacen,
    required this.pesoCobre,
    required this.fechaIngreso,
    required this.codigoVendedor,
    required this.vendedor,
    required this.codigoCliente,
    required this.cliente,
    required this.ordenProduccion,
    required this.fechaOrdenProduccion,
    required this.modelo,
    required this.unidadMedida,
    required this.cantidadEmpaque,
    required this.listaPrecioDolar,
    required this.ultimoPrecioFacturadoDolar,
    required this.codigoUltimoClienteFacturado,
    required this.ultimoClienteFacturado,
    required this.valorListaPrecioDolar,
    required this.valorFacturacionDolar,
    required this.familia,
    required this.calibre,
    required this.clase,
    required this.color,
    required this.presentacion,
  });
}