/// Modelo de producto utilizado dentro de una cotización.
///
/// La información de stock/precio/peso proviene de la tabla `stock`.
/// Los datos propios de la cotización (cantidad, presentación,
/// descuento y tiempo de fabricación) se mantienen separados.
class ProductoCotizacion {
  final String codigo;
  final String descripcion;

  /// Stock actual disponible en MT.
  final double stockDisponible;

  /// Peso del producto expresado en kg por MT.
  final double pesoPorMt;

  /// Precio base del catálogo: X1.
  final double precioBaseX1;

  /// Datos informativos provenientes del stock.
  final String clienteStock;
  final String almacen;
  final String condicion;
  final String vendedor;

  /// Presentación seleccionada para esta cotización.
  ///
  /// Ejemplos: X1, X10, X50, X100, X500, X1000.
  /// También puede ser Personalizado.
  String presentacion;

  /// Factor correspondiente a la presentación.
  ///
  /// X100 = 100 MT por unidad de presentación.
  double factorPresentacion;

  /// Cantidad de presentaciones que se está cotizando.
  double cantidad;

  /// Descuento aplicado exclusivamente a esta línea.
  double descuentoPorcentaje;

  /// Tiempo de fabricación/entrega seleccionado para esta línea.
  ///
  /// Ejemplo: "STOCK - ATENCIÓN INMEDIATA", "20-25 días".
  String tiempoFabricacion;

  /// Permite escribir un tiempo de fabricación personalizado.
  String tiempoFabricacionPersonalizado;

  ProductoCotizacion({
    required this.codigo,
    required this.descripcion,
    required this.stockDisponible,
    required this.pesoPorMt,
    required this.precioBaseX1,
    this.clienteStock = '',
    this.almacen = '',
    this.condicion = '',
    this.vendedor = '',
    this.presentacion = 'X1',
    this.factorPresentacion = 1,
    this.cantidad = 1,
    this.descuentoPorcentaje = 0,
    this.tiempoFabricacion = 'STOCK - ATENCIÓN INMEDIATA',
    this.tiempoFabricacionPersonalizado = '',
  });

  /// Indica si actualmente existe stock.
  bool get tieneStock => stockDisponible > 0;

  /// Metros equivalentes de la cantidad cotizada.
  ///
  /// Ejemplo:
  /// cantidad = 5
  /// presentación = X100
  /// resultado = 500 MT
  double get metros => cantidad * factorPresentacion;

  /// Peso total de la línea.
  ///
  /// Ejemplo:
  /// 500 MT × 0.0364 kg/MT = 18.20 kg
  double get pesoTotal => metros * pesoPorMt;

  /// Precio de una unidad de la presentación seleccionada.
  ///
  /// Ejemplo:
  /// precio X1 = US$ 0.76
  /// X100 = US$ 76.00
  double get precioPresentacion =>
      precioBaseX1 * factorPresentacion;

  /// Importe bruto de la línea antes del descuento.
  double get importeBruto => metros * precioBaseX1;

  /// Importe del descuento de esta línea.
  double get importeDescuento =>
      importeBruto * (descuentoPorcentaje / 100);

  /// Importe neto de la línea.
  double get importeNeto =>
      importeBruto - importeDescuento;

  /// Texto final que aparecerá como condición de entrega.
  String get entrega {
    if (tiempoFabricacion == 'PERSONALIZADO') {
      final personalizado =
          tiempoFabricacionPersonalizado.trim();

      if (personalizado.isNotEmpty) {
        return personalizado;
      }

      return 'POR CONFIRMAR';
    }

    return tiempoFabricacion;
  }

  /// Crea una copia del producto.
  ProductoCotizacion copyWith({
    String? codigo,
    String? descripcion,
    double? stockDisponible,
    double? pesoPorMt,
    double? precioBaseX1,
    String? clienteStock,
    String? almacen,
    String? condicion,
    String? vendedor,
    String? presentacion,
    double? factorPresentacion,
    double? cantidad,
    double? descuentoPorcentaje,
    String? tiempoFabricacion,
    String? tiempoFabricacionPersonalizado,
  }) {
    return ProductoCotizacion(
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
      stockDisponible:
          stockDisponible ?? this.stockDisponible,
      pesoPorMt: pesoPorMt ?? this.pesoPorMt,
      precioBaseX1:
          precioBaseX1 ?? this.precioBaseX1,
      clienteStock:
          clienteStock ?? this.clienteStock,
      almacen: almacen ?? this.almacen,
      condicion: condicion ?? this.condicion,
      vendedor: vendedor ?? this.vendedor,
      presentacion:
          presentacion ?? this.presentacion,
      factorPresentacion:
          factorPresentacion ?? this.factorPresentacion,
      cantidad: cantidad ?? this.cantidad,
      descuentoPorcentaje:
          descuentoPorcentaje ?? this.descuentoPorcentaje,
      tiempoFabricacion:
          tiempoFabricacion ?? this.tiempoFabricacion,
      tiempoFabricacionPersonalizado:
          tiempoFabricacionPersonalizado ??
              this.tiempoFabricacionPersonalizado,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'codigo': codigo,
      'descripcion': descripcion,
      'stock_disponible': stockDisponible,
      'peso_por_mt': pesoPorMt,
      'precio_base_x1': precioBaseX1,
      'cliente_stock': clienteStock,
      'almacen': almacen,
      'condicion': condicion,
      'vendedor': vendedor,
      'presentacion': presentacion,
      'factor_presentacion': factorPresentacion,
      'cantidad': cantidad,
      'metros': metros,
      'peso_total': pesoTotal,
      'descuento_porcentaje': descuentoPorcentaje,
      'importe_bruto': importeBruto,
      'importe_descuento': importeDescuento,
      'importe_neto': importeNeto,
      'tiempo_fabricacion': entrega,
    };
  }
}
