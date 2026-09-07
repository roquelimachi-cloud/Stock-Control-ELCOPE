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

    if (unidad == 'ROL' ||
        unidad == 'RO' ||
        unidad == 'ROLLO' ||
        unidad == 'ROLLOS' ||
        unidad == 'BOBINA' ||
        unidad == 'BOBINAS') {
      return 'ROLLO';
    }

    if (unidad == 'MT' ||
        unidad == 'M' ||
        unidad == 'METRO' ||
        unidad == 'METROS') {
      return 'METRO (MT)';
    }

    final texto = '${presentacionStock.trim()} $descripcion $lote'.toUpperCase();

    // El Excel de stock suele identificar metros como "(m)" o "...MT".
    if (RegExp(r'\(\s*M\s*\)|\bMT\b|\bMETROS?\b|\bMETR[AO]S?\b')
        .hasMatch(texto)) {
      // Si además aparece ROL/BOB en una presentación explícita, prevalece ROLLO.
      if (!RegExp(r'\bROL(?:LO|LOS)?\b|\bBOBIN(?:A|AS)\b', caseSensitive: false)
          .hasMatch(texto)) {
        return 'METRO (MT)';
      }
    }

    if (RegExp(r'\bROL(?:LO|LOS)?\b|\bBOBIN(?:A|AS)\b|\bCARRETE(?:S)?\b', caseSensitive: false)
        .hasMatch(texto)) {
      return 'ROLLO';
    }

    return unidad.isEmpty ? 'NO DEFINIDA' : unidad;
  }

  /// Presentación comercial. Prioriza la columna del stock y luego intenta
  /// detectar formatos escritos en la descripción.
  String get presentacion {
    final desdeStock = presentacionStock.trim();
    if (desdeStock.isNotEmpty) {
      final match = RegExp(
        r'(rollos?|bobinas?|carretes?|paquetes?|cajas?)\s*[xX]?\s*(\d+(?:[.,]\d+)?)?\s*(?:MT|M|METROS?)?',
        caseSensitive: false,
      ).firstMatch(desdeStock);

      if (match != null) {
        final tipo = _capitalizar(match.group(1) ?? 'Presentación');
        final cantidad = match.group(2);
        return cantidad != null && cantidad.isNotEmpty
            ? '$tipo x $cantidad metros'
            : tipo;
      }

      return desdeStock;
    }

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

    if (unidadVisible == 'ROLLO') return 'ROLLO';
    if (unidadVisible == 'METRO (MT)') return 'METRO (MT)';
    return 'Por definir';
  }

  double get factorPresentacion {
    final texto = presentacion;
    final match = RegExp(
      r'(?:rollos?|bobinas?|carretes?|paquetes?|cajas?)\s*x\s*(\d+(?:[.,]\d+)?)|\bx\s*(\d+(?:[.,]\d+)?)\b',
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

    for (final palabra in palabras) {
      final termino = palabra.trim();
      if (termino.isEmpty) continue;

      final variantes = <String>{
        termino,
        termino.replaceAll('.', ''),
      };
      if (termino.contains('.')) {
        variantes.add(termino.replaceAll('.', ' '));
      }

      // Para búsquedas compactas (NYY25, NYSY4, THW14, N2XOH10, etc.)
      // consultamos también los componentes que pueden estar separados en la
      // descripción del catálogo. Ejemplo:
      //   N2XOH10 -> N2XOH + 10
      //   NYY25   -> NYY + 25
      //   N2XOH10MM2 -> N2XOH + 10 + MM + 2
      // La validación final exige todos los componentes, evitando resultados
      // falsos por consultar solamente un número.
      final compacta = termino.replaceAll('.', '');
      final numeros = RegExp(r'\d+').allMatches(compacta).toList();

      if (numeros.isNotEmpty && RegExp(r'[a-z]').hasMatch(compacta)) {
        if (numeros.length == 1) {
          final inicioNumero = numeros.first.start;
          final base = compacta.substring(0, inicioNumero);
          if (base.isNotEmpty) variantes.add(base);
          variantes.add(numeros.first.group(0)!);
        } else {
          // La primera parte alfanumérica representa la familia/modelo.
          // Para N2XOH10MM2 tomamos N2XOH y luego los componentes posteriores.
          final inicioSegundoNumero = numeros[1].start;
          final base = compacta.substring(0, inicioSegundoNumero);
          if (base.isNotEmpty && RegExp(r'[a-z]').hasMatch(base)) {
            variantes.add(base);
          }

          for (int i = 1; i < numeros.length; i++) {
            variantes.add(numeros[i].group(0)!);
          }

          final despuesSegundoNumero = compacta.substring(numeros[1].end);
          for (final m in RegExp(r'[a-z]+').allMatches(despuesSegundoNumero)) {
            variantes.add(m.group(0)!);
          }
        }
      }

      for (final variante in variantes) {
        final patron = '%${variante.replaceAll('%', '')}%';
        final respuesta = await _supabase
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
              'calibre.ilike.$patron,'
              'unidad.ilike.$patron,'
              'presentacion.ilike.$patron',
            )
            .limit(500);

        for (final original in (respuesta as List)) {
          final fila = Map<String, dynamic>.from(original);
          final codigo = fila['codigo']?.toString().trim() ?? '';
          if (codigo.isEmpty) continue;
          porCodigo[_normalizar(codigo)] = fila;
        }
      }
    }

    return porCodigo.values.toList();
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

    // 2) Traemos el mejor registro de stock para cada código encontrado.
    final stocks = await _buscarMejorStockPorCodigos(
      productos.map((e) => e['codigo']?.toString() ?? ''),
    );

    final candidatos = <Map<String, dynamic>>[];
    for (final producto in productos) {
      final codigo = producto['codigo']?.toString().trim() ?? '';
      if (codigo.isEmpty) continue;

      final filaStock = stocks[_normalizar(codigo)];
      if (filaStock != null) {
        candidatos.add(_enriquecerFila(
          filaStock,
          {_normalizar(codigo): producto},
        ));
      } else {
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
    }

    // 3) Validación final: todas las palabras deben estar presentes en el
    // código, descripción, modelo, unidad o presentación.
    final encontrados = <Map<String, dynamic>>[];
    for (final fila in candidatos) {
      final buscable = _textoBuscableProducto(fila);
      final compacto = _compacto(buscable);
      final coincide = palabras.every((palabra) {
        final p = _normalizar(palabra);
        final pc = _compacto(p);
        if (buscable.contains(p) || compacto.contains(pc)) return true;

        // Acepta formatos compactos cuando el origen los guarda separados.
        // Esto cubre tanto NYY25/NYSY4/THW14 como N2XOH10.
        final componentes = <String>[];
        final numeros = RegExp(r'\d+').allMatches(pc).toList();

        if (numeros.isNotEmpty && RegExp(r'[a-z]').hasMatch(pc)) {
          if (numeros.length == 1) {
            final base = pc.substring(0, numeros.first.start);
            if (base.isNotEmpty) componentes.add(base);
            componentes.add(numeros.first.group(0)!);
          } else {
            final base = pc.substring(0, numeros[1].start);
            if (base.isNotEmpty && RegExp(r'[a-z]').hasMatch(base)) {
              componentes.add(base);
            }

            for (int i = 1; i < numeros.length; i++) {
              componentes.add(numeros[i].group(0)!);
            }

            final cola = pc.substring(numeros[1].end);
            componentes.addAll(
              RegExp(r'[a-z]+')
                  .allMatches(cola)
                  .map((m) => m.group(0)!),
            );
          }
        }

        if (componentes.isEmpty) return false;

        // Cada componente puede estar separado por espacios/puntuación.
        return componentes.every((componente) {
          final c = _normalizar(componente);
          if (c.isEmpty) return true;
          return buscable.contains(c) || compacto.contains(c);
        });
      });
      if (coincide) encontrados.add(fila);
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

    // Máximo 15 códigos distintos. Los códigos sin stock quedan disponibles
    // para fabricación después de los que sí tienen existencia.
    final unicos = <String, Map<String, dynamic>>{};
    for (final fila in encontrados) {
      final codigo = _codigo(fila);
      if (codigo.isEmpty) continue;
      final clave = _normalizar(codigo);
      final existente = unicos[clave];
      if (existente == null ||
          ProductoCotizacionStock._numero(fila['stock']) >
              ProductoCotizacionStock._numero(existente['stock'])) {
        unicos[clave] = fila;
      }
    }

    final resultado = unicos.values.toList()
      ..sort((a, b) {
        final stockA = ProductoCotizacionStock._numero(a['stock']);
        final stockB = ProductoCotizacionStock._numero(b['stock']);
        if ((stockA > 0) != (stockB > 0)) return stockA > 0 ? -1 : 1;
        if (stockA != stockB) return stockB.compareTo(stockA);
        return _codigo(a).compareTo(_codigo(b));
      });

    return resultado
        .take(15)
        .map(ProductoCotizacionStock.fromMap)
        .toList();
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
