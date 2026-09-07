import 'package:supabase_flutter/supabase_flutter.dart';

/// Registro de producto utilizado exclusivamente por Cotizaciones.
///
/// IMPORTANTE:
/// - El stock se obtiene de public.stock.
/// - El precio unitario base se obtiene de public.productos.
/// - El valor de stock.valor_lista_precio_dolar NO se usa como precio
///   unitario, porque puede representar la valorización del registro.
/// - Los registros de stock se mantienen individualmente.
/// - Los productos sin stock pueden aparecer desde la lista vigente de precios.
class ProductoCotizacionStock {
  final String codigo;
  final String descripcion;
  final double stock;
  final double peso;
  final double valorListaPrecioDolar;
  final String cliente;
  final String almacen;
  final String condicion;
  final String vendedor;
  final String lote;
  final String fechaIngreso;
  final String modelo;
  final String datosBusqueda;

  const ProductoCotizacionStock({
    required this.codigo,
    required this.descripcion,
    required this.stock,
    required this.peso,
    required this.valorListaPrecioDolar,
    required this.cliente,
    required this.almacen,
    required this.condicion,
    required this.vendedor,
    required this.lote,
    required this.fechaIngreso,
    required this.modelo,
    this.datosBusqueda = '',
  });

  bool get tieneStock => stock > 0;

  String get stockTexto {
    if (stock <= 0) return '0';
    return stock.toStringAsFixed(
      stock == stock.roundToDouble() ? 0 : 2,
    );
  }

  String get estadoStock {
    if (stock <= 0) return 'SIN STOCK';
    if (stock <= 100) return 'STOCK BAJO';
    return 'CON STOCK';
  }

  /// Presentación detectada desde la descripción.
  /// Ejemplo: "(Rollosx100)" -> "Rollos x 100 metros".
  String get presentacion {
    final texto = descripcion.trim();

    final match = RegExp(
      r'\(\s*(rollos?|bobinas?|carretes?|paquetes?|cajas?)\s*[xX]\s*(\d+(?:[.,]\d+)?)\s*(?:MT|M|METROS?)?\s*\)',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final tipo = match.group(1) ?? 'Presentación';
      final cantidad = match.group(2) ?? '1';
      return '${_capitalizar(tipo)} x $cantidad metros';
    }

    final simple = RegExp(
      r'\b(rollos?|bobinas?|carretes?|paquetes?|cajas?)\s*[xX]\s*(\d+(?:[.,]\d+)?)\s*(?:MT|M|METROS?)?\b',
      caseSensitive: false,
    ).firstMatch(texto);

    if (simple != null) {
      final tipo = simple.group(1) ?? 'Presentación';
      final cantidad = simple.group(2) ?? '1';
      return '${_capitalizar(tipo)} x $cantidad metros';
    }

    // También acepta la columna presentacion si la descripción no la trae.
    return 'Por definir';
  }

  double get factorPresentacion {
    final texto = descripcion.trim();

    final match = RegExp(
      r'(?:rollos?|bobinas?|carretes?|paquetes?|cajas?)\s*[xX]\s*(\d+(?:[.,]\d+)?)\s*(?:MT|M|METROS?)?',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match == null) return 1;

    return double.tryParse(
          (match.group(1) ?? '1').replaceAll(',', '.'),
        ) ??
        1;
  }

  static String _capitalizar(String texto) {
    if (texto.isEmpty) return texto;
    return texto[0].toUpperCase() + texto.substring(1).toLowerCase();
  }

  factory ProductoCotizacionStock.fromMap(Map<String, dynamic> map) {
    final descripcion = _texto(
      map,
      const [
        'descripcion',
        'articulo',
        'producto',
        'nombre_producto',
      ],
      defecto: 'SIN DESCRIPCIÓN',
    );

    final modelo = _texto(
      map,
      const [
        'modelo',
        'modelo_producto',
        'modelo_articulo',
        'modeloArticulo',
      ],
    );

    return ProductoCotizacionStock(
      codigo: _texto(
        map,
        const [
          'codigo',
          'codigo_articulo',
          'codigoArticulo',
        ],
      ),
      descripcion: descripcion,
      stock: _numero(map['stock']),
      peso: _numero(
        map['peso'] ??
            map['peso_cobre'] ??
            map['pesoCobre'],
      ),
      valorListaPrecioDolar: _numero(
        map['valor_lista_precio_dolar'],
      ),
      cliente: _texto(
        map,
        const ['cliente'],
        defecto: 'SIN CLIENTE',
      ),
      almacen: _texto(
        map,
        const [
          'almacen',
          'almacén',
          'almacen_nombre',
          'almacenNombre',
          'ubicacion',
        ],
        defecto: 'SIN ALMACÉN',
      ),
      condicion: _texto(
        map,
        const [
          'condicion',
          'condición',
          'estado',
          'estado_stock',
          'situacion',
          'situación',
        ],
      ),
      vendedor: _texto(
        map,
        const [
          'vendedor',
          'asesor',
          'representante',
        ],
      ),
      lote: _texto(map, const ['lote']),
      fechaIngreso: _texto(
        map,
        const ['fecha_ingreso', 'fechaIngreso'],
      ),
      modelo: modelo,
      datosBusqueda: _normalizarMapa(map),
    );
  }

  static String _normalizarMapa(Map<String, dynamic> map) {
    final partes = <String>[];

    for (final entrada in map.entries) {
      final clave = entrada.key.toLowerCase();

      if (const {
        'cliente',
        'vendedor',
        'asesor',
        'representante',
        'lote',
        'fecha_ingreso',
        'fechaingreso',
        'created_at',
        'updated_at',
        'id',
      }.contains(clave)) {
        continue;
      }

      final valor = entrada.value;
      if (valor == null) continue;

      final texto = valor.toString().trim();
      if (texto.isEmpty) continue;

      partes.add(texto);
    }

    return _normalizarTexto(partes.join(' '));
  }

  static String _normalizarTexto(String texto) {
    var resultado = texto.toLowerCase();

    const reemplazos = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };

    reemplazos.forEach((origen, destino) {
      resultado = resultado.replaceAll(origen, destino);
    });

    return resultado.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static String _texto(
    Map<String, dynamic> map,
    List<String> campos, {
    String defecto = '',
  }) {
    for (final campo in campos) {
      final valor = map[campo];
      if (valor == null) continue;

      final texto = valor.toString().trim();
      if (texto.isNotEmpty) return texto;
    }

    return defecto;
  }

  static double _numero(dynamic valor) {
    if (valor == null) return 0;

    if (valor is num) return valor.toDouble();

    return double.tryParse(
          valor.toString().trim().replaceAll(',', ''),
        ) ??
        0;
  }
}

class ProductoCotizacionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>>? _catalogo;

  Future<List<Map<String, dynamic>>> _cargarTodasLasFilas(
    String tabla, {
    String columnas = '*',
  }) async {
    const tamanoPagina = 1000;
    final todas = <Map<String, dynamic>>[];
    var inicio = 0;

    while (true) {
      final respuesta = await _supabase
          .from(tabla)
          .select(columnas)
          .range(inicio, inicio + tamanoPagina - 1);

      final pagina = (respuesta as List)
          .map((fila) => Map<String, dynamic>.from(fila))
          .toList();

      todas.addAll(pagina);

      if (pagina.length < tamanoPagina) break;

      inicio += tamanoPagina;
    }

    return todas;
  }

  String _normalizar(String texto) {
    var resultado = texto.toLowerCase().trim();

    const reemplazos = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };

    reemplazos.forEach((origen, destino) {
      resultado = resultado.replaceAll(origen, destino);
    });

    // Conservamos los decimales para que una búsqueda como "1.5"
    // NO se convierta en "1 5". De lo contrario, productos que solo
    // contienen "1" y "5" en otros lugares también aparecen.
    resultado = resultado.replaceAll(RegExp(r'(?<=\d),(?=\d)'), '.');
    return resultado.replaceAll(RegExp(r'[^a-z0-9.]+'), ' ').trim();
  }

  String _compacto(String texto) {
    return _normalizar(texto).replaceAll(' ', '');
  }

  String _codigo(Map<String, dynamic> fila) {
    return ProductoCotizacionStock._texto(
      fila,
      const [
        'codigo',
        'codigo_articulo',
        'codigoArticulo',
      ],
    ).trim();
  }

  String _textoBuscableProducto(Map<String, dynamic> fila) {
    const campos = [
      'codigo',
      'codigo_articulo',
      'codigoArticulo',
      'descripcion',
      'articulo',
      'producto',
      'nombre_producto',
      'modelo',
      'modelo_producto',
      'modelo_articulo',
      'modeloArticulo',
      'familia',
      'categoria',
      'clase',
      'clase_producto',
      'tipo',
      'tipo_producto',
      'color',
      'calibre',
      'seccion',
      'conductor',
      'aislamiento',
      'tension',
      'voltaje',
      'presentacion',
      'unidad',
    ];

    final partes = <String>[];

    for (final campo in campos) {
      final valor = fila[campo];
      if (valor == null) continue;

      final texto = valor.toString().trim();
      if (texto.isNotEmpty) partes.add(texto);
    }

    return _normalizar(partes.join(' '));
  }

  Future<Map<String, double>> _cargarPreciosVigentes() async {
    final filas = await _cargarTodasLasFilas(
      'productos',
      columnas: 'codigo, precio_vigente_dolar, activo',
    );

    final precios = <String, double>{};

    for (final fila in filas) {
      if (fila['activo'] == false) continue;

      final codigo = fila['codigo']?.toString().trim() ?? '';
      if (codigo.isEmpty) continue;

      precios[_normalizar(codigo)] =
          ProductoCotizacionStock._numero(
        fila['precio_vigente_dolar'],
      );
    }

    return precios;
  }

  Future<List<Map<String, dynamic>>> _cargarCatalogoCompleto() async {
    if (_catalogo != null) return _catalogo!;

    final stock = await _cargarTodasLasFilas('stock');
    final precios = await _cargarPreciosVigentes();

    final resultado = <Map<String, dynamic>>[];
    final codigosStock = <String>{};

    // 1. Todos los registros reales de stock, sin agrupar.
    for (final original in stock) {
      final fila = Map<String, dynamic>.from(original);
      final codigo = _codigo(fila);

      if (codigo.isEmpty) continue;

      final clave = _normalizar(codigo);
      codigosStock.add(clave);

      // ESTE es el precio correcto: precio base de la lista vigente.
      // Si es Rollos x 100, la página aplica el factor 100 una sola vez.
      fila['valor_lista_precio_dolar'] = precios[clave] ?? 0;

      resultado.add(fila);
    }

    // 2. Catálogo de precios vigente para códigos que NO están en stock.
    // Esto permite cotizar productos sin existencia y luego enviarlos
    // a Producción.
    final productos = await _cargarTodasLasFilas(
      'productos',
      columnas: 'codigo, descripcion, precio_vigente_dolar, activo',
    );

    for (final producto in productos) {
      if (producto['activo'] == false) continue;

      final codigo = producto['codigo']?.toString().trim() ?? '';
      if (codigo.isEmpty) continue;

      final clave = _normalizar(codigo);

      if (codigosStock.contains(clave)) continue;

      final precio = ProductoCotizacionStock._numero(
        producto['precio_vigente_dolar'],
      );

      resultado.add({
        'codigo': codigo,
        'descripcion':
            producto['descripcion']?.toString() ?? 'SIN DESCRIPCIÓN',
        'stock': 0,
        'peso': 0,
        'valor_lista_precio_dolar': precio,
        'cliente': '',
        'almacen': '',
        'condicion': 'SIN STOCK',
        'vendedor': '',
        'lote': '',
        'fecha_ingreso': '',
        'modelo': '',
      });
    }

    _catalogo = resultado;
    return resultado;
  }

  Future<List<ProductoCotizacionStock>> buscarProductos(
    String texto,
  ) async {
    final busqueda = _normalizar(texto);
    if (busqueda.isEmpty) return [];

    // Cada término se conserva como unidad. Por ejemplo:
    // "nysy 1.5" => ["nysy", "1.5"], no ["nysy", "1", "5"].
    final palabras = busqueda
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    final catalogo = await _cargarCatalogoCompleto();
    final encontrados = <Map<String, dynamic>>[];

    for (final fila in catalogo) {
      final buscable = _textoBuscableProducto(fila);
      final buscableCompacto = _compacto(buscable);

      final coincide = palabras.every((palabra) {
        final p = _normalizar(palabra);
        final pc = _compacto(p);

        // Esto permite:
        // "NYSY4" -> encuentra "NYSY 4x..."
        // "NYSY 4" -> también encuentra "NYSY4..."
        return buscable.contains(p) ||
            buscableCompacto.contains(pc);
      });

      if (coincide) {
        encontrados.add(fila);
      }
    }

    // Disponibles primero; SIN STOCK después, pero nunca ocultos.
    encontrados.sort((a, b) {
      final stockA = ProductoCotizacionStock._numero(a['stock']);
      final stockB = ProductoCotizacionStock._numero(b['stock']);

      final porStock = stockB.compareTo(stockA);
      if (porStock != 0) return porStock;

      return _codigo(a).compareTo(_codigo(b));
    });

    return encontrados
        .map((fila) => ProductoCotizacionStock.fromMap(fila))
        .toList();
  }

  Future<List<ProductoCotizacionStock>> obtenerTodosProductos() async {
    final catalogo = await _cargarCatalogoCompleto();

    return catalogo
        .map((fila) => ProductoCotizacionStock.fromMap(fila))
        .toList();
  }

  Future<List<ProductoCotizacionStock>> obtenerPorCodigo(
    String codigo,
  ) async {
    final buscado = _normalizar(codigo);
    if (buscado.isEmpty) return [];

    final catalogo = await _cargarCatalogoCompleto();

    return catalogo
        .where(
          (fila) => _normalizar(_codigo(fila)) == buscado,
        )
        .map((fila) => ProductoCotizacionStock.fromMap(fila))
        .toList();
  }

  void limpiarCache() {
    _catalogo = null;
  }
}
