import 'package:supabase_flutter/supabase_flutter.dart';

/// Registro de producto utilizado exclusivamente por Cotizaciones.
/// Conserva cada registro de stock individual para distinguir lotes.
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
  final String unidadMedida;
  final String presentacionStock;
  final double cantidadEmpaque;

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
    this.unidadMedida = '',
    this.presentacionStock = '',
    this.cantidadEmpaque = 0,
  });

  bool get tieneStock => stock > 0;

  /// Código especial utilizado por Cotizaciones como producto comodín.
  bool get esComodin => codigo.trim() == '199000000000000';

  String get stockTexto => _formatearNumero(stock);

  String get pesoTexto => _formatearNumero(peso);

  static String _formatearNumero(double valor) {
    final decimales = valor == valor.roundToDouble() ? 0 : 2;
    final fijo = valor.toStringAsFixed(decimales);
    final partes = fijo.split('.');
    final entero = partes[0];
    final conMiles = entero.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return partes.length == 1 ? conMiles : '$conMiles.${partes[1]}';
  }

  String get estadoStock {
    if (stock <= 0) return 'SIN STOCK';
    if (stock <= 100) return 'STOCK BAJO';
    return 'CON STOCK';
  }

  String get unidadVisible {
    var unidad = unidadMedida.trim().toUpperCase();
    unidad = unidad.replaceAll('.', '').replaceAll(' ', '');

    // Regla comercial: si el producto está definido como vendido por metro
    // (unidad MT/M/METRO o descripción terminada en "(m)"), SIEMPRE se
    // muestra y se cotiza como METRO. No se debe convertir a ROLLO solo
    // porque el registro de stock tenga una presentación ROLx100MT.
    final descripcionNormalizada = descripcion
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), ' ');
    final esDescripcionMetro = RegExp(
      r'\(\s*M\s*\)\s*$',
      caseSensitive: false,
    ).hasMatch(descripcionNormalizada);

    if (unidad == 'MT' ||
        unidad == 'M' ||
        unidad == 'METRO' ||
        unidad == 'METROS' ||
        esDescripcionMetro) {
      return 'METRO (MT)';
    }

    if (unidad == 'ROL' ||
        unidad == 'RO' ||
        unidad == 'ROLLO' ||
        unidad == 'ROLLOS' ||
        unidad == 'BOBINA' ||
        unidad == 'BOBINAS') {
      return 'ROLLO';
    }

    final texto = '${presentacionStock.trim()} $descripcion $lote'.toUpperCase();

    // Solo inferimos ROLLO desde la presentación cuando el producto NO está
    // definido como venta por metro.
    if (RegExp(
      r'(?:\d+\s*)?(?:ROL(?:LO|LOS)?|RO|BOBIN(?:A|AS)?|CARRETE(?:S)?|CAR)\s*[xX]',
      caseSensitive: false,
    ).hasMatch(texto)) {
      return 'ROLLO';
    }

    if (RegExp(r'\(\s*M\s*\)|\bMT\b|\bMETROS?\b|\bMETR[AO]S?\b')
        .hasMatch(texto)) {
      return 'METRO (MT)';
    }

    return unidad.isEmpty ? 'NO DEFINIDA' : unidad;
  }

  /// Presentación comercial. Prioriza la columna del stock y luego intenta
  /// detectar formatos escritos en la descripción.
  String get presentacion {
    // Si el producto se vende por metro, la presentación SIEMPRE es MT.
    // No mostrar ROL x 100 metros aunque el stock haya sido registrado así.
    if (unidadVisible == 'METRO (MT)') {
      return 'METRO (MT)';
    }

    final desdeStock = presentacionStock.trim();
    if (desdeStock.isNotEmpty) {
      final match = RegExp(
        r'(?:\d+\s*)?(rol(?:lo|los)?|ro|bob(?:ina|inas)?|carrete(?:s)?|car|paquete(?:s)?|caja(?:s)?)\s*[xX]\s*(\d+(?:[.,]\d+)?)\s*(?:MT|M|METROS?)?',
        caseSensitive: false,
      ).firstMatch(desdeStock);

      if (match != null) {
        final tipo = _capitalizar(match.group(1) ?? 'Presentación');
        final cantidad = match.group(2);
        return '$tipo x $cantidad metros';
      }

      return desdeStock;
    }

    final texto = descripcion.trim();

    final match = RegExp(
      r'\(\s*(?:\d+\s*)?(rol(?:lo|los)?|ro|bob(?:ina|inas)?|carrete(?:s)?|car|paquete(?:s)?|caja(?:s)?)\s*[xX]\s*(\d+(?:[.,]\d+)?)\s*(?:MT|M|METROS?)?\s*\)',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final tipo = match.group(1) ?? 'Presentación';
      final cantidad = match.group(2) ?? '1';
      return '${_capitalizar(tipo)} x $cantidad metros';
    }

    final simple = RegExp(
      r'(?:\d+\s*)?(rol(?:lo|los)?|ro|bob(?:ina|inas)?|carrete(?:s)?|car|paquete(?:s)?|caja(?:s)?)\s*[xX]\s*(\d+(?:[.,]\d+)?)\s*(?:MT|M|METROS?)?\b',
      caseSensitive: false,
    ).firstMatch(texto);

    if (simple != null) {
      final tipo = simple.group(1) ?? 'Presentación';
      final cantidad = simple.group(2) ?? '1';
      return '${_capitalizar(tipo)} x $cantidad metros';
    }

    if (unidadVisible == 'ROLLO') return 'ROLLO';
    if (unidadVisible == 'METRO (MT)') return 'METRO (MT)';
    return 'Por definir';
  }

  double get factorPresentacion {
    // En MT el precio siempre es unitario por metro.
    if (unidadVisible == 'METRO (MT)') {
      return 1;
    }

    final texto = presentacion;
    final match = RegExp(
      r'(?:rollos?|rol|ro|bobinas?|bob|carretes?|car|paquetes?|paquete|cajas?|caja)\s*x\s*(\d+(?:[.,]\d+)?)|\bx\s*(\d+(?:[.,]\d+)?)\b',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match == null) return 1;
    final valor = match.group(1) ?? match.group(2) ?? '1';
    return double.tryParse(valor.replaceAll(',', '.')) ?? 1;
  }

  static String _capitalizar(String texto) {
    if (texto.isEmpty) return texto;
    return texto[0].toUpperCase() + texto.substring(1).toLowerCase();
  }

  factory ProductoCotizacionStock.fromMap(Map<String, dynamic> map) {
    final descripcion = _texto(
      map,
      const ['descripcion', 'articulo', 'producto', 'nombre_producto'],
      defecto: 'SIN DESCRIPCIÓN',
    );

    final modelo = _texto(
      map,
      const ['modelo', 'modelo_producto', 'modelo_articulo', 'modeloArticulo'],
    );

    return ProductoCotizacionStock(
      codigo: _texto(
        map,
        const ['codigo', 'codigo_articulo', 'codigoArticulo'],
      ),
      descripcion: descripcion,
      stock: _numero(map['stock']),
      peso: _numero(map['peso'] ?? map['peso_cobre'] ?? map['pesoCobre']),
      valorListaPrecioDolar: _numero(map['valor_lista_precio_dolar']),
      cliente: _texto(map, const ['cliente'], defecto: 'SIN CLIENTE'),
      almacen: _texto(
        map,
        const ['almacen', 'almacén', 'almacen_nombre', 'almacenNombre', 'ubicacion'],
        defecto: 'SIN ALMACÉN',
      ),
      condicion: _texto(
        map,
        const ['condicion', 'condición', 'estado', 'estado_stock', 'situacion', 'situación'],
      ),
      vendedor: _texto(map, const ['vendedor', 'asesor', 'representante']),
      lote: _texto(map, const ['lote']),
      fechaIngreso: _texto(map, const ['fecha_ingreso', 'fechaIngreso']),
      modelo: modelo,
      datosBusqueda: _normalizarMapa(map),
      unidadMedida: _texto(map, const ['unidad_medida', 'unidadMedida', 'unidad']),
      presentacionStock: _texto(map, const ['presentacion', 'presentación']),
      cantidadEmpaque: _numero(
        map['cantidad_empaque'] ?? map['cantidadEmpaque'],
      ),
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
      if (texto.isNotEmpty) partes.add(texto);
    }
    return _normalizarTexto(partes.join(' '));
  }

  static String _normalizarTexto(String texto) {
    var resultado = texto.toLowerCase();
    const reemplazos = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
    };
    reemplazos.forEach((origen, destino) {
      resultado = resultado.replaceAll(origen, destino);
    });
    return resultado.replaceAll(RegExp(r'[^a-z0-9.]+'), ' ').trim();
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
    return double.tryParse(valor.toString().trim().replaceAll(',', '')) ?? 0;
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

    // Conservamos los decimales: "1.5" debe seguir siendo un único término.
    resultado = resultado.replaceAll(RegExp(r'(?<=\d),(?=\d)'), '.');
    return resultado.replaceAll(RegExp(r'[^a-z0-9.]+'), ' ').trim();
  }

  String _compacto(String texto) => _normalizar(texto).replaceAll(' ', '');

  String _codigo(Map<String, dynamic> fila) {
    return ProductoCotizacionStock._texto(
      fila,
      const ['codigo', 'codigo_articulo', 'codigoArticulo'],
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
      'unidad_medida',
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

  Future<Map<String, Map<String, dynamic>>> _cargarDatosProductos(
    Iterable<String> codigos,
  ) async {
    final lista = codigos
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (lista.isEmpty) return {};

    final resultado = <String, Map<String, dynamic>>{};

    // Los resultados de búsqueda están acotados, por lo que esta consulta es
    // mucho más rápida que cargar toda la tabla productos.
    for (int inicio = 0; inicio < lista.length; inicio += 500) {
      final fin = (inicio + 500 < lista.length) ? inicio + 500 : lista.length;
      final lote = lista.sublist(inicio, fin);

      final filas = await _supabase
          .from('productos')
          .select(
            'codigo, descripcion, modelo, calibre, unidad, presentacion, '
            'precio_vigente_dolar, activo',
          )
          .inFilter('codigo', lote);

      for (final filaOriginal in (filas as List)) {
        final fila = Map<String, dynamic>.from(filaOriginal);
        final codigo = fila['codigo']?.toString().trim() ?? '';
        if (codigo.isEmpty) continue;
        resultado[_normalizar(codigo)] = fila;
      }
    }

    return resultado;
  }

  Map<String, dynamic> _enriquecerFila(
    Map<String, dynamic> fila,
    Map<String, Map<String, dynamic>> productos,
  ) {
    final salida = Map<String, dynamic>.from(fila);
    final codigo = _codigo(salida);
    final producto = productos[_normalizar(codigo)];

    if (producto != null) {
      final precio = ProductoCotizacionStock._numero(
        producto['precio_vigente_dolar'],
      );
      salida['valor_lista_precio_dolar'] = precio;

      // El stock sincronizado conserva la presentación del Excel. Si por
      // alguna razón falta, aprovechamos los datos del catálogo de productos.
      if ((salida['descripcion']?.toString().trim() ?? '').isEmpty ||
          (salida['descripcion']?.toString().trim() ?? '').toUpperCase() == 'SIN DESCRIPCIÓN') {
        salida['descripcion'] = producto['descripcion'] ?? '';
      }
      if ((salida['modelo']?.toString().trim() ?? '').isEmpty) {
        salida['modelo'] = producto['modelo'] ?? '';
      }
      if ((salida['unidad']?.toString().trim() ?? '').isEmpty) {
        salida['unidad'] = producto['unidad'] ?? '';
      }
      if ((salida['presentacion']?.toString().trim() ?? '').isEmpty) {
        salida['presentacion'] = producto['presentacion'] ?? '';
      }
    } else {
      salida['valor_lista_precio_dolar'] =
          ProductoCotizacionStock._numero(
        salida['valor_lista_precio_dolar'],
      );
    }

    return salida;
  }

  Future<List<ProductoCotizacionStock>> obtenerMuestraInicial({
    int limite = 20,
  }) async {
    // Al abrir el selector mostramos 20 códigos DISTINTOS que sí tienen stock.
    // Se ordenan por código para que el usuario tenga una referencia estable.
    final filas = await _supabase
        .from('stock')
        .select('*')
        .gt('stock', 0)
        .order('codigo', ascending: true)
        .limit(300);

    final porCodigo = <String, Map<String, dynamic>>{};

    for (final original in (filas as List)) {
      final fila = Map<String, dynamic>.from(original);
      final codigo = _codigo(fila);
      if (codigo.isEmpty) continue;

      final clave = _normalizar(codigo);
      final existente = porCodigo[clave];
      final stockActual = ProductoCotizacionStock._numero(fila['stock']);
      final stockExistente = existente == null
          ? -1
          : ProductoCotizacionStock._numero(existente['stock']);

      if (existente == null || stockActual > stockExistente) {
        porCodigo[clave] = fila;
      }
    }

    final muestra = porCodigo.values.toList()
      ..sort((a, b) => _codigo(a).compareTo(_codigo(b)));

    final seleccion = muestra.take(limite).toList();
    final datosProductos = await _cargarDatosProductos(seleccion.map(_codigo));
    final enriquecidos = seleccion
        .map((fila) => _enriquecerFila(fila, datosProductos))
        .toList();

    return enriquecidos.map(ProductoCotizacionStock.fromMap).toList();
  }

  /// Busca primero en el catálogo de productos para incluir también códigos
  /// que actualmente tengan stock 0. Luego incorpora el mejor registro de
  /// stock disponible para cada código.
  Future<List<Map<String, dynamic>>> _buscarCatalogoPorTexto(
    List<String> palabras,
  ) async {
    final porCodigo = <String, Map<String, dynamic>>{};

    String compactar(String value) =>
        _normalizar(value).replaceAll(' ', '');

    bool coincide(Map<String, dynamic> fila) {
      final buscable = _textoBuscableProducto(fila);
      final q = palabras.join(' ');
      return _coincideBusqueda(q, buscable);
    }

    for (final palabra in palabras) {
      final termino = palabra.trim();
      if (termino.isEmpty) continue;

      final variantes = <String>{termino};
      final compacto = compactar(termino);

      // THW14 / NLT14 / NYY25: probamos también la forma separada
      // "THW 14" porque así puede estar guardado el modelo/descripción.
      final match = RegExp(r'^([a-z]+)([0-9]+)$').firstMatch(compacto);
      if (match != null) {
        variantes.add('${match.group(1)} ${match.group(2)}');
        variantes.add(match.group(1)!);
        variantes.add(match.group(2)!);
      }

      for (final variante in variantes) {
        final patron = '%${variante.replaceAll('%', '')}%';

        // Catálogo: incluye productos aunque tengan stock 0.
        final productos = await _supabase
            .from('productos')
            .select(
              'codigo, descripcion, modelo, calibre, unidad, presentacion, '
              'precio_vigente_dolar, activo',
            )
            .eq('activo', true)
            .or(
              'codigo.ilike.$patron,'
              'descripcion.ilike.$patron,'
              'modelo.ilike.$patron,'
              'calibre.ilike.$patron',
            )
            .limit(500);

        for (final original in (productos as List)) {
          final fila = Map<String, dynamic>.from(original);
          final codigo = fila['codigo']?.toString().trim() ?? '';
          if (codigo.isEmpty || !coincide(fila)) continue;
          porCodigo[_normalizar(codigo)] = fila;
        }

        // Stock: buscamos también directamente en lo que ya está ingresado
        // al almacén. Se conservan después TODOS sus lotes/registros.
        // En STOCK usamos únicamente columnas confirmadas por el modelo
        // actual. codigo_articulo no forma parte de todos los registros y
        // provocaba que PostgREST rechazara toda la consulta.
        final stocks = await _supabase
            .from('stock')
            .select('*')
            .or(
              'codigo.ilike.$patron,'
              'descripcion.ilike.$patron,'
              'modelo.ilike.$patron',
            )
            .limit(1000);

        for (final original in (stocks as List)) {
          final fila = Map<String, dynamic>.from(original);
          final codigo = _codigo(fila);
          if (codigo.isEmpty || !coincide(fila)) continue;

          final clave = _normalizar(codigo);
          porCodigo.putIfAbsent(clave, () => fila);
        }
      }
    }

    return porCodigo.values.toList();
  }

  Future<List<Map<String, dynamic>>> _buscarTodosStockPorCodigos(
    Iterable<String> codigos,
  ) async {
    final lista = codigos
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final resultado = <Map<String, dynamic>>[];

    // Supabase/PostgREST admite listas grandes, pero las procesamos en lotes
    // para no perder registros cuando hay muchos códigos coincidentes.
    for (int inicio = 0; inicio < lista.length; inicio += 100) {
      final fin = (inicio + 100 < lista.length) ? inicio + 100 : lista.length;
      final lote = lista.sublist(inicio, fin);

      final filas = await _supabase
          .from('stock')
          .select('*')
          .inFilter('codigo', lote)
          .order('stock', ascending: false);

      for (final original in (filas as List)) {
        resultado.add(Map<String, dynamic>.from(original));
      }
    }

    return resultado;
  }

  Future<Map<String, Map<String, dynamic>>> _buscarMejorStockPorCodigos(
    Iterable<String> codigos,
  ) async {
    final lista = codigos
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final resultado = <String, Map<String, dynamic>>{};
    for (int inicio = 0; inicio < lista.length; inicio += 100) {
      final fin = (inicio + 100 < lista.length) ? inicio + 100 : lista.length;
      final lote = lista.sublist(inicio, fin);

      final filas = await _supabase
          .from('stock')
          .select('*')
          .inFilter('codigo', lote)
          .order('stock', ascending: false);

      for (final original in (filas as List)) {
        final fila = Map<String, dynamic>.from(original);
        final codigo = _codigo(fila);
        if (codigo.isEmpty) continue;
        final clave = _normalizar(codigo);
        if (!resultado.containsKey(clave)) {
          resultado[clave] = fila;
        }
      }
    }
    return resultado;
  }

  Future<List<Map<String, dynamic>>> _buscarStockRapido(
    List<String> palabras,
  ) async {
    // Conservamos esta función para compatibilidad con el resto del servicio.
    // Ahora consulta el catálogo por código y recupera el mejor stock de cada
    // código, por lo que también encuentra artículos sin stock.
    final productos = await _buscarCatalogoPorTexto(palabras);
    final stocks = await _buscarMejorStockPorCodigos(
      productos.map((e) => e['codigo']?.toString() ?? ''),
    );

    final resultado = <Map<String, dynamic>>[];
    for (final producto in productos) {
      final codigo = producto['codigo']?.toString().trim() ?? '';
      final stock = stocks[_normalizar(codigo)];
      if (stock != null) {
        resultado.add(_enriquecerFila(stock, {
          _normalizar(codigo): producto,
        }));
      } else {
        resultado.add({
          'codigo': codigo,
          'descripcion': producto['descripcion'] ?? '',
          'stock': 0,
          'peso': 0,
          'valor_lista_precio_dolar': ProductoCotizacionStock._numero(
            producto['precio_vigente_dolar'],
          ),
          'cliente': '',
          'almacen': '',
          'condicion': 'SIN STOCK',
          'vendedor': '',
          'lote': '',
          'fecha_ingreso': '',
          'modelo': producto['modelo'] ?? '',
          'unidad': producto['unidad'] ?? '',
          'presentacion': producto['presentacion'] ?? '',
          'calibre': producto['calibre'] ?? '',
        });
      }
    }
    return resultado;
  }

  Future<List<Map<String, dynamic>>> _buscarProductosSinStock(
    List<String> palabras,
  ) async {
    return _buscarCatalogoPorTexto(palabras);
  }

  Future<List<Map<String, dynamic>>> _cargarCatalogoCompleto() async {
    if (_catalogo != null) return _catalogo!;

    final stock = await _cargarTodasLasFilas('stock');
    final porCodigo = <String, Map<String, dynamic>>{};
    for (final fila in stock) {
      final codigo = _codigo(fila);
      if (codigo.isEmpty) continue;
      final clave = _normalizar(codigo);
      final existente = porCodigo[clave];
      if (existente == null ||
          ProductoCotizacionStock._numero(fila['stock']) >
              ProductoCotizacionStock._numero(existente['stock'])) {
        porCodigo[clave] = fila;
      }
    }

    final datosProductos = await _cargarDatosProductos(
      porCodigo.values.map(_codigo),
    );

    _catalogo = porCodigo.values
        .map((fila) => _enriquecerFila(fila, datosProductos))
        .toList();
    return _catalogo!;
  }

  Future<List<ProductoCotizacionStock>> buscarProductos(
    String texto,
  ) async {
    final busqueda = _normalizar(texto);
    if (busqueda.isEmpty) return [];

    final palabras = busqueda
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    // 1) Catálogo: aquí están TODOS los códigos, incluso los que no tienen stock.
    final productos = await _buscarCatalogoPorTexto(palabras);
    if (productos.isEmpty) return [];

    // 2) Traemos TODOS los registros de stock de los códigos encontrados.
    // No agrupamos por código: un mismo código puede tener varios lotes,
    // ingresos y existencias, y todos deben aparecer en la búsqueda.
    final stocks = await _buscarTodosStockPorCodigos(
      productos.map((e) => e['codigo']?.toString() ?? ''),
    );

    final productosPorCodigo = <String, Map<String, dynamic>>{};
    for (final producto in productos) {
      final codigo = producto['codigo']?.toString().trim() ?? '';
      if (codigo.isEmpty) continue;
      productosPorCodigo[_normalizar(codigo)] = producto;
    }

    final candidatos = <Map<String, dynamic>>[];

    // Primero conservamos cada fila real de stock.
    for (final filaStock in stocks) {
      final codigo = _codigo(filaStock);
      if (codigo.isEmpty) continue;

      final producto = productosPorCodigo[_normalizar(codigo)];
      if (producto != null) {
        candidatos.add(
          _enriquecerFila(
            filaStock,
            {_normalizar(codigo): producto},
          ),
        );
      } else {
        candidatos.add(filaStock);
      }
    }

    // Luego agregamos una fila SIN STOCK para cada producto del catálogo
    // que no tenga ninguna fila en la tabla stock.
    final codigosConStock = stocks
        .map(_codigo)
        .where((e) => e.trim().isNotEmpty)
        .map(_normalizar)
        .toSet();

    for (final producto in productos) {
      final codigo = producto['codigo']?.toString().trim() ?? '';
      if (codigo.isEmpty) continue;
      final clave = _normalizar(codigo);
      if (codigosConStock.contains(clave)) continue;

      candidatos.add({
        'codigo': codigo,
        'descripcion': producto['descripcion'] ?? 'SIN DESCRIPCIÓN',
        'stock': 0,
        'peso': 0,
        'valor_lista_precio_dolar': ProductoCotizacionStock._numero(
          producto['precio_vigente_dolar'],
        ),
        'cliente': '',
        'almacen': '',
        'condicion': 'SIN STOCK',
        'vendedor': '',
        'lote': '',
        'fecha_ingreso': '',
        'modelo': producto['modelo'] ?? '',
        'unidad': producto['unidad'] ?? '',
        'presentacion': producto['presentacion'] ?? '',
        'calibre': producto['calibre'] ?? '',
      });
    }

    // 3) Validación final: TODAS las partes de la búsqueda deben coincidir.
    // Evita falsos positivos como buscar NLT14 y devolver un TW 18 AWG.
    final encontrados = <Map<String, dynamic>>[];
    for (final fila in candidatos) {
      final buscable = _textoBuscableProducto(fila);
      if (_coincideBusqueda(busqueda, buscable)) {
        encontrados.add(fila);
      }
    }

    // 4) Stock disponible primero; dentro de cada grupo, código ascendente.
    encontrados.sort((a, b) {
      final stockA = ProductoCotizacionStock._numero(a['stock']);
      final stockB = ProductoCotizacionStock._numero(b['stock']);
      if ((stockA > 0) != (stockB > 0)) {
        return stockA > 0 ? -1 : 1;
      }
      if (stockA != stockB) return stockB.compareTo(stockA);
      return _codigo(a).compareTo(_codigo(b));
    });

    // No eliminamos filas por código: el usuario pidió ver TODO el stock
    // asociado al modelo, incluidos lotes/ingresos distintos.
    encontrados.sort((a, b) {
      final stockA = ProductoCotizacionStock._numero(a['stock']);
      final stockB = ProductoCotizacionStock._numero(b['stock']);
      if ((stockA > 0) != (stockB > 0)) return stockA > 0 ? -1 : 1;
      if (stockA != stockB) return stockB.compareTo(stockA);

      final codigo = _codigo(a).compareTo(_codigo(b));
      if (codigo != 0) return codigo;

      final fechaA = a['fecha_ingreso']?.toString() ?? '';
      final fechaB = b['fecha_ingreso']?.toString() ?? '';
      return fechaB.compareTo(fechaA);
    });

    // Límite de seguridad para la ventana de resultados, pero sin reducir
    // artificialmente a un solo registro por código.
    return encontrados
        .take(100)
        .map(ProductoCotizacionStock.fromMap)
        .toList();
  }

  bool _coincideBusqueda(String consulta, String buscable) {
    final q = _normalizar(consulta);
    final b = _normalizar(buscable);
    if (q.isEmpty || b.isEmpty) return false;

    // Coincidencia completa: NLT14 también puede existir como modelo/código.
    final qCompacto = _compacto(q);
    final bCompacto = _compacto(b);
    if (b.contains(q) || (qCompacto.length >= 4 && bCompacto.contains(qCompacto))) {
      return true;
    }

    // Para términos compactos como NLT14, N2XOH10 o THW14:
    // se separan letras y números, ignorando la x usada como separador.
    final tokens = q.split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final componentes = <String>[];

    for (final token in tokens) {
      final compact = token.replaceAll('.', '');
      final partes = RegExp(r'[a-z]+|\d+(?:\.\d+)?')
          .allMatches(compact)
          .map((m) => m.group(0)!)
          .where((p) => p != 'x')
          .toList();

      if (partes.isEmpty) return false;
      componentes.addAll(partes);
    }

    // No exigir una letra suelta que venga de un patrón alfanumérico raro.
    // Sí exigimos cada componente significativo.
    return componentes.every((componente) {
      final c = _normalizar(componente);
      if (c.isEmpty || c == 'x') return true;
      return b.contains(c) || bCompacto.contains(c);
    });
  }

  Future<List<ProductoCotizacionStock>> obtenerTodosProductos() async {
    final catalogo = await _cargarCatalogoCompleto();
    return catalogo.map(ProductoCotizacionStock.fromMap).toList();
  }

  Future<List<ProductoCotizacionStock>> obtenerPorCodigo(String codigo) async {
    final buscado = _normalizar(codigo);
    if (buscado.isEmpty) return [];

    final catalogo = await _cargarCatalogoCompleto();
    return catalogo
        .where((fila) => _normalizar(_codigo(fila)) == buscado)
        .map(ProductoCotizacionStock.fromMap)
        .toList();
  }

  void limpiarCache() {
    _catalogo = null;
  }
}
