import 'dart:typed_data';

import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../services/sesion.dart';
import '../../../../services/supabase/supabase_service.dart';

/// Importador de facturación CRM.
///
/// Importante: el mapeo se hace por NOMBRE DE COLUMNA y no por posición fija.
/// Esto permite importar reportes históricos aunque ELCOPE cambie el orden
/// de las columnas o utilice saltos de línea/accentos en los encabezados.
class FacturacionImportacionService {
  FacturacionImportacionService({SupabaseClient? client})
      : _db = client ?? SupabaseService.client;

  final SupabaseClient _db;

  static const int _tamanoLote = 250;

  Future<PlatformFile?> seleccionarExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;
    return result.files.single;
  }

  Future<Map<String, dynamic>> leerExcel(PlatformFile archivo) async {
    final bytes = archivo.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('No se pudieron leer los bytes del archivo Excel.');
    }

    final libro = excel.Excel.decodeBytes(bytes);
    if (libro.tables.isEmpty) {
      throw Exception('El archivo no contiene hojas de cálculo.');
    }

    final hoja = libro.tables.values.first;
    if (hoja.maxRows < 2) {
      throw Exception('El Excel no contiene filas de datos.');
    }

    // ------------------------------------------------------------
    // 1. Detectar automáticamente la fila de encabezados.
    // ------------------------------------------------------------
    final encabezados = _detectarEncabezados(hoja);
    final columnas = <String, int>{};

    for (final entry in encabezados.entries) {
      final indice = _buscarColumna(encabezados, entry.key);
      if (indice != null) columnas[entry.key] = indice;
    }

    const requeridas = <String>[
      'codigo_canal',
      'canal',
      'codigo_vendedor',
      'vendedor',
      'codigo_almacen',
      'tipo_doc',
      'punto_factura',
      'numero_factura',
      'fecha_factura',
      'numero_orden_compra',
      'localidad_factura',
      'codigo_cliente',
      'cliente',
      'localidad_cliente',
      'departamento_cliente',
      'giro',
      'sector',
      'numero_item',
      'codigo_articulo',
      'articulo',
      'familia',
      'calibre',
      'clase',
      'factor_empaque',
      'cantidad',
      'cantidad_metros',
      'unidad_medida',
      'precio_bruto_factura',
      'porcentaje_descuento',
      'monto_descuento_factura',
      'precio_neto_factura',
      'monto_factura',
      'forma_pago',
      'peso_kg_cobre',
    ];

    final faltantes = requeridas
        .where((campo) => !columnas.containsKey(campo))
        .toList();

    if (faltantes.isNotEmpty) {
      throw Exception(
        'Formato de Excel no reconocido. Faltan columnas: '
        '${faltantes.join(', ')}.\n\n'
        'No se cargó ningún dato. Verifica que sea el reporte de '
        'Análisis de Facturación Detalle.',
      );
    }

    // ------------------------------------------------------------
    // 2. Leer filas usando las columnas detectadas.
    // ------------------------------------------------------------
    final filas = <Map<String, dynamic>>[];

    for (var i = encabezados['_fila_encabezado']! + 1;
        i < hoja.maxRows;
        i++) {
      final c = hoja.row(i);

      if (c.every((cell) => _texto(cell?.value).isEmpty)) continue;

      dynamic valor(String campo) {
        final indice = columnas[campo];
        if (indice == null || indice >= c.length) return null;
        return c[indice]?.value;
      }

      final codigoCliente = _texto(valor('codigo_cliente'));
      final nombreCliente = _texto(valor('cliente'));
      final numeroFactura = _texto(valor('numero_factura'));
      final puntoFactura = _texto(valor('punto_factura'));

      // Ignorar filas completamente vacías o que no representan documento.
      if (codigoCliente.isEmpty &&
          nombreCliente.isEmpty &&
          numeroFactura.isEmpty &&
          puntoFactura.isEmpty) {
        continue;
      }

      filas.add({
        'codigo_canal': _entero(valor('codigo_canal')),
        'canal': _texto(valor('canal')),
        'codigo_vendedor': _entero(valor('codigo_vendedor')),
        'vendedor': _texto(valor('vendedor')),
        'codigo_almacen': _entero(valor('codigo_almacen')),
        'tipo_doc': _entero(valor('tipo_doc')),
        'punto_factura': puntoFactura,
        'numero_factura': numeroFactura,
        'fecha_factura': _fecha(valor('fecha_factura')),
        'numero_orden_compra': _texto(valor('numero_orden_compra')),
        'localidad_factura': _texto(valor('localidad_factura')),
        'codigo_cliente': codigoCliente,
        'cliente': nombreCliente,
        'localidad_cliente': _texto(valor('localidad_cliente')),
        'departamento_cliente': _texto(valor('departamento_cliente')),
        'giro': _texto(valor('giro')),
        'sector': _texto(valor('sector')),
        'numero_item': _entero(valor('numero_item')),
        'codigo_articulo': _texto(valor('codigo_articulo')),
        'articulo': _texto(valor('articulo')),
        'familia': _texto(valor('familia')),
        'calibre': _texto(valor('calibre')),
        'clase': _texto(valor('clase')),
        'factor_empaque': _decimal(valor('factor_empaque')),
        'cantidad': _decimal(valor('cantidad')),
        'cantidad_metros': _decimal(valor('cantidad_metros')),
        'unidad_medida': _texto(valor('unidad_medida')),
        'precio_bruto_factura': _decimal(valor('precio_bruto_factura')),
        'porcentaje_descuento': _decimal(valor('porcentaje_descuento')),
        'monto_descuento_factura': _decimal(valor('monto_descuento_factura')),
        'precio_neto_factura': _decimal(valor('precio_neto_factura')),
        'monto_factura': _decimal(valor('monto_factura')),
        'forma_pago': _texto(valor('forma_pago')),
        'peso_kg_cobre': _decimal(valor('peso_kg_cobre')),
      });
    }

    if (filas.isEmpty) {
      throw Exception('No se encontraron filas válidas.');
    }

    final fechas = filas
        .map((e) => e['fecha_factura']?.toString())
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toList()
      ..sort();

    // Cliente: priorizar código. Si el código viene vacío, usar nombre.
    final clientes = filas
        .map((e) {
          final codigo = _normalizar(e['codigo_cliente']);
          if (codigo.isNotEmpty) return 'COD:$codigo';
          final nombre = _normalizar(e['cliente']);
          return nombre.isEmpty ? '' : 'NOM:$nombre';
        })
        .where((e) => e.isNotEmpty)
        .toSet();

    // Vendedor: priorizar código. Si no existe, usar nombre.
    final vendedores = filas
        .map((e) {
          final codigo = _normalizar(e['codigo_vendedor']);
          if (codigo.isNotEmpty) return 'COD:$codigo';
          final nombre = _normalizar(e['vendedor']);
          return nombre.isEmpty ? '' : 'NOM:$nombre';
        })
        .where((e) => e.isNotEmpty)
        .toSet();

    final facturas = filas
        .map((e) => [
              _normalizar(e['tipo_doc']),
              _normalizar(e['punto_factura']),
              _normalizar(e['numero_factura']),
            ].join('|'))
        .where((e) => e != '||')
        .toSet();

    return {
      'archivo': archivo.name,
      'filas': filas,
      'total_filas': filas.length,
      'periodo_desde': fechas.isEmpty ? null : fechas.first,
      'periodo_hasta': fechas.isEmpty ? null : fechas.last,
      'facturas': facturas.length,
      'clientes': clientes.length,
      'vendedores': vendedores.length,
      'columnas_detectadas': columnas.length,
    };
  }

  Future<int> crearImportacion({
    required String nombreArchivo,
    required int totalFilas,
    String? periodoDesde,
    String? periodoHasta,
  }) async {
    final usuarioId = Sesion.idUsuario;
    if (usuarioId <= 0) {
      throw Exception('No hay un usuario válido en la sesión.');
    }

    final result = await _db.rpc(
      'crm_crear_importacion',
      params: {
        'p_nombre_archivo': nombreArchivo,
        'p_periodo_desde': periodoDesde,
        'p_periodo_hasta': periodoHasta,
        'p_total_filas': totalFilas,
        'p_usuario_id': usuarioId,
        'p_observaciones': 'Carga iniciada desde CRM.',
      },
    );

    return (result as num).toInt();
  }

  Future<void> cargarStaging({
    required int importacionId,
    required List<Map<String, dynamic>> filas,
    void Function(int cargadas, int total)? onProgress,
  }) async {
    for (var inicio = 0; inicio < filas.length; inicio += _tamanoLote) {
      final fin = (inicio + _tamanoLote < filas.length)
          ? inicio + _tamanoLote
          : filas.length;

      final lote = filas.sublist(inicio, fin).map((fila) {
        final copia = Map<String, dynamic>.from(fila);
        copia['importacion_id'] = importacionId;
        return copia;
      }).toList();

      await _db.rpc(
        'crm_cargar_staging_lote',
        params: {
          'p_importacion_id': importacionId,
          'p_filas': lote,
        },
      );

      onProgress?.call(fin, filas.length);
    }
  }

  Future<Map<String, dynamic>> procesarImportacion(int importacionId) async {
    final result = await _db.rpc(
      'crm_procesar_importacion',
      params: {'p_importacion_id': importacionId},
    );

    if (result is Map<String, dynamic>) return result;
    return Map<String, dynamic>.from(result as Map);
  }

  // ------------------------------------------------------------
  // Encabezados
  // ------------------------------------------------------------

  static Map<String, int> _detectarEncabezados(excel.Sheet hoja) {
    const campos = <String>[
      'codigo_canal',
      'canal',
      'codigo_vendedor',
      'vendedor',
      'codigo_almacen',
      'tipo_doc',
      'punto_factura',
      'numero_factura',
      'fecha_factura',
      'numero_orden_compra',
      'localidad_factura',
      'codigo_cliente',
      'cliente',
      'localidad_cliente',
      'departamento_cliente',
      'giro',
      'sector',
      'numero_item',
      'codigo_articulo',
      'articulo',
      'familia',
      'calibre',
      'clase',
      'factor_empaque',
      'cantidad',
      'cantidad_metros',
      'unidad_medida',
      'precio_bruto_factura',
      'porcentaje_descuento',
      'monto_descuento_factura',
      'precio_neto_factura',
      'monto_factura',
      'forma_pago',
      'peso_kg_cobre',
    ];

    const aliases = <String, List<String>>{
      'codigo_canal': ['codigo canal', 'cod canal'],
      'canal': ['canal'],
      'codigo_vendedor': ['codigo vendedor', 'cod vendedor'],
      'vendedor': ['vendedor', 'asesor'],
      'codigo_almacen': ['codigo almacen', 'codigo almacén', 'cod almacen'],
      'tipo_doc': ['tipo doc', 'tipo documento'],
      'punto_factura': ['punto factura', 'punto de factura'],
      'numero_factura': ['numero factura', 'número factura', 'nro factura'],
      'fecha_factura': ['fecha factura'],
      'numero_orden_compra': ['numero orden compra', 'número orden compra', 'orden compra'],
      'localidad_factura': ['localidad factura', 'localdiad factura'],
      'codigo_cliente': ['codigo cliente', 'código cliente', 'cod cliente'],
      'cliente': ['cliente', 'razon social', 'razón social'],
      'localidad_cliente': ['localidad cliente', 'localdiad cliente'],
      'departamento_cliente': ['departamento cliente'],
      'giro': ['giro'],
      'sector': ['sector'],
      'numero_item': ['numero item', 'número item', 'n item', 'item'],
      'codigo_articulo': ['codigo articulo', 'código articulo', 'codigo artículo', 'código artículo', 'cod articulo'],
      'articulo': ['articulo', 'artículo'],
      'familia': ['familia'],
      'calibre': ['calibre'],
      'clase': ['clase'],
      'factor_empaque': ['factor empaque'],
      'cantidad': ['cantidad'],
      'cantidad_metros': ['cantidad metros', 'cantidad m'],
      'unidad_medida': ['unidad medida', 'unidad'],
      'precio_bruto_factura': ['precio bruto factura', 'precio bruto'],
      'porcentaje_descuento': ['porcentaje descuento factura', 'porcentaje descuento', 'descto factura', 'descto'],
      'monto_descuento_factura': ['monto descuento factura', 'monto descuento'],
      'precio_neto_factura': ['precio neto factura', 'precio neto'],
      'monto_factura': ['monto factura', 'importe factura'],
      'forma_pago': ['forma pago', 'forma de pago'],
      'peso_kg_cobre': ['peso kg cobre', 'peso kg', 'peso cobre'],
    };

    for (var fila = 0; fila < hoja.maxRows && fila < 20; fila++) {
      final row = hoja.row(fila);

      // EL reporte oficial de ELCOPE tiene 34 columnas y este orden estable.
      // Usamos esta ruta primero para que los CellValue del paquete excel,
      // saltos de línea y tildes del encabezado nunca bloqueen la detección.
      if (row.length >= 34) {
        final primera = _textoCeldaSeguro(row[0]?.value).toLowerCase();
        final segunda = _textoCeldaSeguro(row[1]?.value).toLowerCase();
        final tercera = _textoCeldaSeguro(row[2]?.value).toLowerCase();
        final octava = _textoCeldaSeguro(row[7]?.value).toLowerCase();

        final pareceReporte =
            primera.contains('codigo') &&
            primera.contains('canal') &&
            segunda.contains('canal') &&
            tercera.contains('vendedor') &&
            octava.contains('factura');

        if (pareceReporte) {
          final salida = <String, int>{'_fila_encabezado': fila};
          for (var i = 0; i < campos.length; i++) {
            salida[campos[i]] = i;
          }
          return salida;
        }
      }

      final normalizados = <String, int>{};
      for (var col = 0; col < row.length; col++) {
        final texto = _normalizarEncabezado(row[col]?.value);
        if (texto.isNotEmpty) normalizados[texto] = col;
      }

      var encontrados = 0;
      for (final campo in campos) {
        final opciones = aliases[campo] ?? const <String>[];
        if (opciones.any((op) => normalizados.containsKey(_normalizarEncabezado(op)))) {
          encontrados++;
        }
      }

      // Ruta principal: encabezados por nombre.
      if (encontrados >= 10) {
        final salida = <String, int>{'_fila_encabezado': fila};
        for (final campo in campos) {
          final opciones = aliases[campo] ?? const <String>[];
          for (final opcion in opciones) {
            final indice = normalizados[_normalizarEncabezado(opcion)];
            if (indice != null) {
              salida[campo] = indice;
              break;
            }
          }
        }
        if (campos.every(salida.containsKey)) return salida;
      }

      // Respaldo específico para el reporte estándar de ELCOPE:
      // 34 columnas en el orden oficial del reporte. Esto evita que un
      // salto de línea/typo del encabezado bloquee una carga histórica.
      if (row.length >= 34) {
        final primero = _normalizarEncabezado(row[0]?.value);
        final segundo = _normalizarEncabezado(row.length > 1 ? row[1]?.value : null);
        if (primero == 'codigo canal' && segundo == 'canal') {
          final salida = <String, int>{'_fila_encabezado': fila};
          for (var i = 0; i < campos.length; i++) {
            salida[campos[i]] = i;
          }
          return salida;
        }
      }
    }

    throw Exception(
      'No se encontró una fila de encabezados reconocible. El archivo debe ser el reporte '
      '"Análisis de Facturación Detalle" de ELCOPE.',
    );
  }

  static int? _buscarColumna(Map<String, int> encabezados, String campo) {
    return encabezados[campo];
  }

  static int? opcionesIndice(
    Map<String, int> normalizados,
    List<String> opciones,
  ) {
    for (final opcion in opciones) {
      final indice = normalizados[_normalizarEncabezado(opcion)];
      if (indice != null) return indice;
    }
    return null;
  }

  static String _textoCeldaSeguro(dynamic value) {
    if (value == null) return '';
    dynamic actual = value;
    try {
      actual = actual.value;
    } catch (_) {}
    final texto = actual?.toString() ?? '';
    return texto.replaceAll('\n', ' ').replaceAll('\r', ' ').trim();
  }

  static String _normalizarEncabezado(dynamic value) {
    var s = _normalizar(value);
    s = s
        .replaceAll('º', '')
        .replaceAll('°', '')
        .replaceAll('%', ' porcentaje ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    return s;
  }

  static dynamic _valorCelda(dynamic value) {
    if (value == null) return null;

    // excel >= 4.x entrega CellValue (TextCellValue, IntCellValue,
    // DoubleCellValue, DateTimeCellValue, etc.) en lugar del valor primitivo.
    // Extraemos su propiedad value para que el importador funcione con el
    // formato real del reporte de ELCOPE.
    try {
      final dynamic interno = value.value;
      return interno;
    } catch (_) {
      return value;
    }
  }

  static String _normalizar(dynamic value) {
    value = _valorCelda(value);
    if (value == null) return '';
    var s = value.toString().trim().toLowerCase();
    const mapa = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    mapa.forEach((a, b) => s = s.replaceAll(a, b));
    return s.replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _texto(dynamic value) {
    value = _valorCelda(value);
    if (value == null) return '';
    return value.toString().trim();
  }

  static int? _entero(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();

    var text = value.toString().trim();
    if (text.isEmpty) return null;
    text = text.replaceAll(',', '');
    final entero = int.tryParse(text);
    if (entero != null) return entero;
    final decimal = double.tryParse(text);
    return decimal?.toInt();
  }

  static double? _decimal(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();

    var text = value.toString().trim();
    if (text.isEmpty) return null;

    text = text.replaceAll('%', '').replaceAll(',', '');
    return double.tryParse(text);
  }

  static String? _fecha(dynamic value) {
    value = _valorCelda(value);
    if (value == null) return null;

    if (value is DateTime) {
      return value.toIso8601String().substring(0, 10);
    }

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    final parsed = DateTime.tryParse(text);
    return parsed?.toIso8601String().substring(0, 10) ?? text;
  }
}
