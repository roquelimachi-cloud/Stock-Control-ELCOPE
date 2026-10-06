import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../services/supabase/supabase_service.dart';
import '../../../services/sesion.dart';
import '../cliente_360/crm_cliente_360_page.dart';


String _normalizarExcelImport(String value) {
  return value
      .toLowerCase()
      .trim()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

List<Map<String, dynamic>> _parsearClientesExcel(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  if (excel.tables.isEmpty) return <Map<String, dynamic>>[];

  final sheet = excel.tables[excel.tables.keys.first];
  if (sheet == null || sheet.maxRows < 2) return <Map<String, dynamic>>[];

  final headers = sheet.rows.first.map((cell) {
    return _normalizarExcelImport(cell?.value?.toString() ?? '');
  }).toList();

  int colAny(List<String> names) {
    for (final name in names) {
      final index = headers.indexOf(_normalizarExcelImport(name));
      if (index >= 0) return index;
    }
    return -1;
  }

  final cCodigo = colAny(['codigo cliente', 'codigo', 'codigo_cliente']);
  final cRuc = colAny(['ruc']);
  final cNombre = colAny(['nombre', 'cliente']);
  final cRazon = colAny([
    'descripcion del cliente',
    'descripcion cliente',
    'razon social',
    'razon_social',
  ]);
  final cDireccion = colAny(['direccion']);
  final cLocalidad = colAny(['localidad']);
  final cDepartamento = colAny(['departamento']);
  final cCanal = colAny(['canal']);
  final cGiro = colAny(['giro']);
  final cSector = colAny(['sector']);
  final cCodigoVendedor = colAny(['codigo vendedor', 'codigo_vendedor']);
  final cVendedor = colAny(['vendedor']);
  final cActivo = colAny(['activo', 'estado']);

  if (cCodigo < 0 && cRuc < 0) {
    throw Exception('El Excel debe contener por lo menos Código Cliente o RUC.');
  }

  String cell(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index]?.value?.toString().trim() ?? '';
  }

  bool activo(String value) {
    final v = value.toLowerCase().trim();
    return v == 'true' || v == '1' || v == 'si' || v == 'sí' || v == 'activo';
  }

  final registros = <Map<String, dynamic>>[];

  for (final row in sheet.rows.skip(1)) {
    final codigo = cell(row, cCodigo);
    final ruc = cell(row, cRuc);
    final razon = cell(row, cRazon);
    final nombreExcel = cell(row, cNombre);
    final nombre = nombreExcel.isNotEmpty ? nombreExcel : razon;

    if (codigo.isEmpty && ruc.isEmpty) continue;
    if (razon.isEmpty && nombre.isEmpty) continue;

    final direccion = cell(row, cDireccion);
    final localidad = cell(row, cLocalidad);
    final departamento = cell(row, cDepartamento);
    final canal = cell(row, cCanal);
    final giro = cell(row, cGiro);
    final sector = cell(row, cSector);
    final codigoVendedor = cell(row, cCodigoVendedor);
    final vendedor = cell(row, cVendedor);
    final activoTexto = cell(row, cActivo);

    registros.add({
      if (codigo.isNotEmpty) 'codigo': codigo,
      if (ruc.isNotEmpty) 'ruc': ruc,
      if (nombre.isNotEmpty) 'nombre': nombre,
      if (razon.isNotEmpty) 'razon_social': razon,
      if (direccion.isNotEmpty) 'direccion': direccion,
      if (localidad.isNotEmpty) 'localidad': localidad,
      if (departamento.isNotEmpty) 'departamento': departamento,
      if (canal.isNotEmpty) 'canal': canal,
      if (giro.isNotEmpty) 'giro': giro,
      if (sector.isNotEmpty) 'sector': sector,
      if (codigoVendedor.isNotEmpty) 'codigo_vendedor': codigoVendedor,
      if (vendedor.isNotEmpty) 'vendedor': vendedor,
      if (activoTexto.isNotEmpty) 'activo': activo(activoTexto),
    });
  }

  return registros;
}

class CrmClientesPage extends StatefulWidget {
  const CrmClientesPage({super.key});

  @override
  State<CrmClientesPage> createState() => _CrmClientesPageState();
}

class _CrmClientesPageState extends State<CrmClientesPage> {
  static const _azul = Color(0xFF0B4F83);
  static const _azulClaro = Color(0xFF1677C8);
  static const _verde = Color(0xFF12A36A);
  static const _fondo = Color(0xFFF5F8FC);
  static const _borde = Color(0xFFE2E8F0);

  final _db = SupabaseService.client;
  final _money = NumberFormat('#,##0.00', 'en_US');

  bool _cargando = true;
  bool _procesando = false;
  String? _error;

  List<Map<String, dynamic>> _clientes = [];
  Map<String, double> _facturacionPorCliente = {};
  Map<String, double> _pesoPorCliente = {};
  Map<String, DateTime> _ultimaCompraPorCliente = {};

  String _busqueda = '';
  String _vendedor = 'TODOS';
  String _sector = 'TODOS';
  String _giro = 'TODOS';
  String _departamento = 'TODOS';
  String _anio = 'TODOS';
  String _compraFiltro = 'TODOS';
  bool _soloActivos = true;

  int _pagina = 0;
  static const int _porPagina = 12;
  bool _haySiguiente = false;
  String _orden = 'FACTURACION_DESC';
  double _facturacionTotal = 0;
  double _pesoTotal = 0;
  int _totalClientes = 0;
  int _conFacturacion = 0;

  String _segmento = 'TODOS';
  Map<String, int> _carteraStats = {};
  Map<String, int> _contactoResumen = {};

  @override
  void initState() {
    super.initState();
    final rol = Sesion.rol.trim().toLowerCase();
    final vendedorSesion = Sesion.vendedor.trim();
    // Si la sesión tiene vendedor asignado (ej. mroque -> Michael Roque),
    // la cartera inicial debe ser exclusivamente la de ese vendedor, incluso
    // si el usuario tiene rol Administrador. El permiso de importación sigue
    // siendo independiente.
    if (vendedorSesion.isNotEmpty && rol != 'jefe lima' && rol != 'jefe provincia' && rol != 'gerencia') {
      _vendedor = vendedorSesion;
    }
    _cargar();
  }

  String _s(dynamic value) => value?.toString().trim() ?? '';

  double _n(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
          value?.toString().replaceAll(',', '').trim() ?? '',
        ) ??
        0;
  }

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String _nombreCliente(Map<String, dynamic> c) {
    final razon = _s(c['razon_social']);
    if (razon.isNotEmpty) return razon;
    final nombre = _s(c['nombre']);
    if (nombre.isNotEmpty) return nombre;
    return 'Cliente sin razón social';
  }

  String _normalizar(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  String _anioDesdeFecha(dynamic value) {
    final d = _date(value);
    return d == null ? '' : d.year.toString();
  }

  bool get _puedeImportarCartera {
    final rol = Sesion.rol.trim().toLowerCase();
    return Sesion.esAdministrador &&
        (rol == 'administrador' ||
            rol == 'admin' ||
            rol.contains('administrador'));
  }

  bool get _esJefeLima => Sesion.rol.trim().toLowerCase() == 'jefe lima';

  Future<List<String>?> _vendedoresPermitidos() async {
    final rol = Sesion.rol.trim().toLowerCase();
    final vendedorSesion = Sesion.vendedor.trim();

    // Jefe Lima trabaja con TODA la cartera de Lima, no solo con
    // los vendedores registrados en usuario_permisos.
    if (rol == 'jefe lima') {
      return null;
    }

    // Administrador y Gerencia pueden consultar toda la cartera.
    if (rol == 'administrador' ||
        rol == 'admin' ||
        rol.contains('administrador') ||
        rol == 'gerencia') {
      return null;
    }

    // Jefe Provincia mantiene la cartera autorizada por usuario_permisos.
    if (rol == 'jefe provincia') {
      final data = await _db
          .from('usuario_permisos')
          .select('vendedor, ver_produccion')
          .eq('usuario_jefe_id', Sesion.idUsuario)
          .eq('ver_produccion', true);

      final permitidos = <String>{};
      for (final row in data as List) {
        final v = row['vendedor']?.toString().trim();
        if (v != null && v.isNotEmpty) permitidos.add(v);
      }
      if (vendedorSesion.isNotEmpty) permitidos.add(vendedorSesion);
      return permitidos.toList();
    }

    // Asesor/vendedor: exclusivamente su vendedor de sesión.
    if (vendedorSesion.isEmpty) return <String>[];
    return <String>[vendedorSesion];
  }

  Future<String> _vendedorRealSesion() async {
    final directo = Sesion.vendedor.trim();
    if (directo.isNotEmpty) return directo;
    try {
      final row = await _db
          .from('usuarios')
          .select('vendedor')
          .eq('id', Sesion.idUsuario)
          .maybeSingle();
      final vendedor = _s(row?['vendedor']);
      return vendedor;
    } catch (_) {
      return '';
    }
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() { _cargando = true; _error = null; });

    try {
      final rol = Sesion.rol.trim().toLowerCase();
      // La fuente de verdad del usuario es public.usuarios. Esto evita que
      // un Administrador con vendedor asignado termine viendo TODA la cartera.
      final vendedorSesion = await _vendedorRealSesion();

      if (vendedorSesion.isNotEmpty &&
          rol != 'jefe lima' &&
          rol != 'jefe provincia' &&
          rol != 'gerencia' &&
          _vendedor != vendedorSesion) {
        if (mounted) setState(() => _vendedor = vendedorSesion);
      }

      final vendedoresPermitidos = await _vendedoresPermitidos();

      final vendedorEfectivo = vendedorSesion.isNotEmpty &&
              rol != 'jefe lima' &&
              rol != 'jefe provincia' &&
              rol != 'gerencia'
          ? vendedorSesion
          : _vendedor;
      final departamentoEfectivo = _esJefeLima ? 'LIMA' : _departamento;

      final baseParams = <String, dynamic>{
        'p_busqueda': _busqueda.trim(),
        'p_vendedor': vendedorEfectivo,
        'p_vendedores_permitidos': vendedoresPermitidos,
        'p_sector': _sector,
        'p_giro': _giro,
        'p_departamento': departamentoEfectivo,
        'p_solo_activos': _soloActivos,
        'p_anio': _anio == 'TODOS' ? null : int.tryParse(_anio),
        'p_compra_filtro': _compraFiltro,
      };

      // IMPORTANTE: la tabla base usa el RPC v6 que ya estaba probado y
      // optimizado en este proyecto. NO usar aquí crm_obtener_cartera_gestion_v1
      // ni crm_obtener_clientes_cartera_v2 porque son los que provocaban 57014.
      dynamic result;
      Object? ultimoError;

      for (var intento = 1; intento <= 2; intento++) {
        try {
          result = await _db.rpc(
            'crm_obtener_clientes_pagina_por_usuario_v2',
            params: {
              'p_usuario_id': Sesion.idUsuario,
              ...baseParams,
              'p_limit': _porPagina,
              'p_offset': _pagina * _porPagina,
              'p_orden': _orden,
            },
          );
          ultimoError = null;
          break;
        } catch (e) {
          ultimoError = e;
          if (intento < 2) {
            await Future<void>.delayed(const Duration(milliseconds: 250));
          }
        }
      }

      if (ultimoError != null || result == null) {
        throw ultimoError ?? Exception('No se pudo cargar la cartera base.');
      }

      var clientes = List<Map<String, dynamic>>.from(result as List);
      final totalDesdeRpc = clientes.isNotEmpty ? int.tryParse(clientes.first['total_clientes']?.toString() ?? '') : 0;

      // Los indicadores comerciales se consultan SOLO para los 12 clientes
      // visibles. Así evitamos una consulta pesada sobre toda la cartera.
      try {
        final codigos = clientes
            .map((c) => _s(c['codigo']))
            .where((v) => v.isNotEmpty)
            .toList();

        if (codigos.isNotEmpty) {
          final flags = await _db.rpc(
            'crm_obtener_clientes_gestion_flags_v1',
            params: {'p_codigos': codigos},
          );

          final porCodigo = <String, Map<String, dynamic>>{};
          for (final row in List.from(flags as List)) {
            final m = Map<String, dynamic>.from(row as Map);
            porCodigo[_s(m['codigo'])] = m;
          }

          clientes = clientes.map((c) {
            final f = porCodigo[_s(c['codigo'])];
            if (f == null) return c;
            return {...c, ...f};
          }).toList();
        }
      } catch (_) {
        // Los indicadores son secundarios: la tabla debe seguir apareciendo.
      }

      // Si se seleccionó un segmento, filtramos los clientes visibles sin
      // volver a ejecutar una consulta pesada sobre toda la base.
      if (_segmento != 'TODOS') {
        bool coincide(Map<String, dynamic> c) {
          final llamada = c['tiene_llamada'] == true;
          final whatsapp = c['tiene_whatsapp'] == true;
          final correo = c['tiene_correo'] == true;
          final visita = c['tiene_visita'] == true;
          final oportunidad = c['tiene_oportunidad'] == true;
          final alerta = _s(c['alerta_contacto']).toUpperCase();
          final activo = c['activo'] == true;

          switch (_segmento) {
            case 'SIN LLAMADA': return !llamada;
            case 'SIN WHATSAPP': return !whatsapp;
            case 'SIN CORREO': return !correo;
            case 'SIN VISITA': return !visita;
            case 'SIN OPORTUNIDAD': return !oportunidad;
            case 'SIN CONTACTO': return alerta == 'NUNCA';
            case 'EN RIESGO': return alerta == 'VENCIDO';
            case 'CON OPORTUNIDAD': return oportunidad;
            case 'ACTIVOS': return activo;
            case 'INACTIVOS': return !activo;
            default: return true;
          }
        }
        clientes = clientes.where(coincide).toList();
      }

      if (!mounted) return;
      setState(() {
        _clientes = clientes;
        _cargando = false;
        _totalClientes = totalDesdeRpc ?? 0;
        _facturacionPorCliente = {};
        _pesoPorCliente = {};
        _ultimaCompraPorCliente = {};

        for (final c in clientes) {
          final id = _s(c['id']);
          final codigo = _s(c['codigo']);
          final key = id.isNotEmpty ? 'ID:$id' : 'COD:$codigo';
          _facturacionPorCliente[key] = _n(c['facturacion']);
          _pesoPorCliente[key] = _n(c['peso_kg']);
          final fecha = _date(c['ultima_compra']);
          if (fecha != null) _ultimaCompraPorCliente[key] = fecha;
        }

        _haySiguiente = clientes.length == _porPagina && _segmento == 'TODOS';
      });

      // Todo lo siguiente es complementario. Si alguno falla por timeout,
      // NO se vuelve a caer la pantalla de Clientes.
      try {
        final stats = await _db.rpc(
          'crm_obtener_clientes_estadisticas_v6',
          params: baseParams,
        );
        final st = (stats as List).isNotEmpty
            ? Map<String, dynamic>.from((stats as List).first)
            : <String, dynamic>{};
        if (mounted) {
          setState(() {
            _facturacionTotal = _n(st['total_facturacion']);
            _pesoTotal = _n(st['total_peso_kg']);
            _conFacturacion = int.tryParse(
                  st['total_con_facturacion']?.toString() ?? '',
                ) ??
                0;
          });
        }
      } catch (_) {}

      try {
        final stats = await _db.rpc(
          'crm_obtener_cartera_gestion_stats_v2',
          params: {
            ...baseParams,
          },
        );
        final g = (stats as List).isNotEmpty
            ? Map<String, dynamic>.from((stats as List).first)
            : <String, dynamic>{};
        int n(String k) => int.tryParse(g[k]?.toString() ?? '') ?? 0;
        if (mounted) {
          setState(() {
            _carteraStats = {
              'TODOS': n('total_clientes') > 0 ? n('total_clientes') : _totalClientes,
              'SIN LLAMADA': n('sin_llamada'),
              'SIN WHATSAPP': n('sin_whatsapp'),
              'SIN CORREO': n('sin_correo'),
              'SIN VISITA': n('sin_visita'),
              'SIN OPORTUNIDAD': n('sin_oportunidad'),
              'SIN CONTACTO': n('sin_contacto'),
              'EN RIESGO': n('en_riesgo'),
              'CON OPORTUNIDAD': n('con_oportunidad'),
              'ACTIVOS': n('activos'),
              'INACTIVOS': n('inactivos'),
            };
            final totalStats = n('total_clientes');
            if (_compraFiltro == 'TODOS') {
              _totalClientes = _segmento == 'TODOS'
                  ? (totalStats > 0 ? totalStats : _totalClientes)
                  : n(_segmento);
            }
            _haySiguiente = clientes.length == _porPagina && (_pagina + 1) * _porPagina < _totalClientes;
          });
        }
      } catch (_) {}

      try {
        final rs = await _db.rpc(
          'crm_obtener_cartera_contacto_resumen_v1',
          params: {
            'p_vendedor': vendedorEfectivo,
            'p_departamento': departamentoEfectivo,
            'p_sector': _sector,
            'p_giro': _giro,
            'p_solo_activos': _soloActivos,
            'p_vendedores_permitidos': vendedoresPermitidos,
          },
        );
        final r = (rs as List).isNotEmpty
            ? Map<String, dynamic>.from((rs as List).first)
            : <String, dynamic>{};
        int n(String k) => int.tryParse(r[k]?.toString() ?? '') ?? 0;
        if (mounted) {
          setState(() {
            _contactoResumen = {
              'total_clientes': n('total_clientes'),
              'sin_contacto': n('sin_contacto'),
              'con_contacto': n('con_contacto'),
              'con_oportunidad': n('con_oportunidad'),
              'inactivos': n('inactivos'),
              'hace_0_7': n('hace_0_7'),
              'hace_8_30': n('hace_8_30'),
              'hace_31_90': n('hace_31_90'),
              'mas_90': n('mas_90'),
            };
          });
        }
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString();
      });
    }
  }

  List<String> _opcionesLocales(String campo) {
    final values = <String>{};
    for (final c in _clientes) {
      final value = _s(c[campo]);
      if (value.isNotEmpty) values.add(value);
    }
    final list = values.toList()..sort();
    return ['TODOS', ...list];
  }

  List<String> get _ordenes => const [
        'FACTURACION_DESC',
        'FACTURACION_ASC',
        'PESO_DESC',
        'PESO_ASC',
        'ULTIMA_COMPRA_DESC',
        'ULTIMA_COMPRA_ASC',
        'CLIENTE_ASC',
        'CLIENTE_DESC',
      ];

  String _ordenLabel(String value) {
    switch (value) {
      case 'FACTURACION_ASC':
        return 'Menor facturación';
      case 'PESO_DESC':
        return 'Mayor peso';
      case 'PESO_ASC':
        return 'Menor peso';
      case 'ULTIMA_COMPRA_DESC':
        return 'Compra más reciente';
      case 'ULTIMA_COMPRA_ASC':
        return 'Compra más antigua';
      case 'CLIENTE_ASC':
        return 'Cliente A-Z';
      case 'CLIENTE_DESC':
        return 'Cliente Z-A';
      default:
        return 'Mayor facturación';
    }
  }

  double _facturacionCliente(Map<String, dynamic> c) {
    final id = _s(c['id']);
    final codigo = _s(c['codigo']);

    if (id.isNotEmpty) {
      return _facturacionPorCliente['ID:$id'] ?? 0;
    }
    if (codigo.isNotEmpty) {
      return _facturacionPorCliente['COD:$codigo'] ?? 0;
    }
    return 0;
  }

  double _pesoCliente(Map<String, dynamic> c) {
    final id = _s(c['id']);
    final codigo = _s(c['codigo']);

    if (id.isNotEmpty) {
      return _pesoPorCliente['ID:$id'] ?? 0;
    }
    if (codigo.isNotEmpty) {
      return _pesoPorCliente['COD:$codigo'] ?? 0;
    }
    return 0;
  }

  DateTime? _ultimaCompra(Map<String, dynamic> c) {
    final id = _s(c['id']);
    final codigo = _s(c['codigo']);

    if (id.isNotEmpty) {
      return _ultimaCompraPorCliente['ID:$id'];
    }
    if (codigo.isNotEmpty) {
      return _ultimaCompraPorCliente['COD:$codigo'];
    }
    return null;
  }

  List<Map<String, dynamic>> get _filtrados {
    // La consulta ya viene filtrada desde Supabase.
    // Se mantiene esta capa para conservar el comportamiento de la pantalla.
    return _clientes;
  }

  Future<void> _cambiarPagina(int nueva) async {
    if (nueva < 0) return;
    if (nueva > _pagina && !_haySiguiente) return;

    setState(() => _pagina = nueva);
    await _cargar();
  }

  Future<void> _exportarExcel() async {
    if (_clientes.isEmpty) {
      _mensaje('No hay clientes para exportar.');
      return;
    }

    try {
      setState(() => _procesando = true);

      final excel = Excel.createExcel();
      final sheet = excel['Clientes'];

      sheet.appendRow([
        TextCellValue('Código'),
        TextCellValue('RUC'),
        TextCellValue('Cliente'),
        TextCellValue('Vendedor'),
        TextCellValue('Sector'),
        TextCellValue('Giro'),
        TextCellValue('Departamento'),
        TextCellValue('Facturación'),
        TextCellValue('Peso (kg)'),
        TextCellValue('Última compra'),
        TextCellValue('Estado'),
      ]);

      for (final c in _clientes) {
        final fecha = _ultimaCompra(c);
        sheet.appendRow([
          TextCellValue(_s(c['codigo'])),
          TextCellValue(_s(c['ruc'])),
          TextCellValue(_nombreCliente(c)),
          TextCellValue(_s(c['vendedor'])),
          TextCellValue(_s(c['sector'])),
          TextCellValue(_s(c['giro'])),
          TextCellValue(_s(c['departamento'])),
          DoubleCellValue(_facturacionCliente(c)),
          DoubleCellValue(_pesoCliente(c)),
          TextCellValue(
            fecha == null ? '' : DateFormat('dd/MM/yyyy').format(fecha),
          ),
          TextCellValue(c['activo'] == true ? 'ACTIVO' : 'INACTIVO'),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('No se pudo generar el archivo Excel.');
      }

      final ruta = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar reporte de clientes',
        fileName: 'clientes_crm_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (ruta == null) return;

      final path = ruta.toLowerCase().endsWith('.xlsx') ? ruta : '$ruta.xlsx';
      await File(path).writeAsBytes(bytes, flush: true);

      _mensaje('Excel generado correctamente.');
    } catch (e) {
      _mensaje('Error al exportar Excel: $e', error: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _importarExcel() async {
    if (!_puedeImportarCartera) {
      _mensaje('Solo el administrador puede importar carteras.', error: true);
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        // IMPORTANTE: no cargamos el archivo completo dentro de FilePicker.
        // En Windows usamos la ruta y luego lo leemos una sola vez.
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      if (file.path == null || file.path!.isEmpty) {
        _mensaje('No se pudo obtener la ruta del Excel.', error: true);
        return;
      }

      if (!mounted) return;
      setState(() => _procesando = true);
      _mensaje('Leyendo Excel en segundo plano...');

      final bytes = await File(file.path!).readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('El archivo Excel está vacío.');
      }

      // Excel.decodeBytes es costoso. Lo ejecutamos en un isolate para que
      // Windows no congele la pantalla mientras prepara los registros.
      final registros = await compute(_parsearClientesExcel, bytes);

      if (registros.isEmpty) {
        _mensaje('No se encontraron clientes válidos en el Excel.', error: true);
        return;
      }

      if (!mounted) return;
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Importar clientes'),
          content: Text(
            'Se encontraron ${registros.length} registros válidos.\n\n'
            'La importación se ejecutará en una sola operación optimizada en Supabase.\n'
            'Código Cliente es la clave principal; RUC se usa como respaldo.\n\n'
            '¿Deseas continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.upload),
              label: const Text('Importar'),
            ),
          ],
        ),
      );

      if (confirmar != true) return;
      if (!mounted) return;
      _mensaje('Importando ${registros.length} clientes a Supabase...');

      final respuesta = await _db.rpc(
        'crm_importar_clientes_masivo_v3',
        params: {'p_registros': registros},
      );

      final data = (respuesta as List).isNotEmpty
          ? Map<String, dynamic>.from((respuesta as List).first)
          : <String, dynamic>{};

      final creados = int.tryParse(data['creados']?.toString() ?? '') ?? 0;
      final actualizados =
          int.tryParse(data['actualizados']?.toString() ?? '') ?? 0;
      final omitidos = int.tryParse(data['omitidos']?.toString() ?? '') ?? 0;

      _mensaje(
        'Importación terminada: $creados creados, $actualizados actualizados'
        '${omitidos > 0 ? ', $omitidos omitidos' : ''}.',
      );

      _pagina = 0;
      await _cargar();
    } catch (e) {
      _mensaje('Error al importar Excel: $e', error: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  bool _textoBooleano(String value) {
    final v = value.toLowerCase().trim();
    return v == 'true' ||
        v == '1' ||
        v == 'si' ||
        v == 'sí' ||
        v == 'activo';
  }

  Future<void> _imprimir() async {
    if (_clientes.isEmpty) {
      _mensaje('No hay clientes para imprimir.');
      return;
    }

    try {
      setState(() => _procesando = true);

      final pdf = pw.Document(
        title: 'Clientes CRM ELCOPE',
        author: 'ELCOPE',
      );

      pw.MemoryImage? logo;
      try {
        final data =
            await rootBundle.load('assets/images/logo_elcope.png');
        logo = pw.MemoryImage(data.buffer.asUint8List());
      } catch (_) {}

      final fecha = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      final filtroAnio = _anio == 'TODOS' ? 'Todos los años' : _anio;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.fromLTRB(22, 18, 22, 22),
          header: (_) => pw.Column(
            children: [
              pw.Row(
                children: [
                  if (logo != null)
                    pw.SizedBox(
                      width: 100,
                      height: 40,
                      child: pw.Image(logo!, fit: pw.BoxFit.contain),
                    )
                  else
                    pw.Text(
                      'ELCOPE',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF0B3B63),
                      ),
                    ),
                  pw.SizedBox(width: 16),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'REPORTE DE CLIENTES - CRM',
                        style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF0B3B63),
                        ),
                      ),
                      pw.Text(
                        'Generado: $fecha | Periodo: $filtroAnio',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
            ],
          ),
          footer: (ctx) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'ELCOPE - Clientes CRM - Página ${ctx.pageNumber}',
              style: const pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey600,
              ),
            ),
          ),
          build: (_) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(9),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF2F6FA),
                borderRadius: pw.BorderRadius.circular(7),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Text('Clientes: ${_clientes.length}'),
                  pw.Text(
                    'Facturación: US\$ ${_money.format(_clientes.fold<double>(0, (s, c) => s + _facturacionCliente(c)))}',
                  ),
                  pw.Text(
                    'Peso: ${_money.format(_clientes.fold<double>(0, (s, c) => s + _pesoCliente(c)))} kg',
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              border: pw.TableBorder.all(
                color: const PdfColor.fromInt(0xFFD8E0E6),
                width: .5,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF0B3B63),
              ),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 6.5),
              cellPadding: const pw.EdgeInsets.all(4),
              headers: const [
                'Cliente',
                'RUC',
                'Vendedor',
                'Sector',
                'Departamento',
                'Facturación',
                'Peso kg',
                'Última compra',
                'Estado',
              ],
              data: _clientes.map((c) {
                final fechaCompra = _ultimaCompra(c);
                return [
                  _nombreCliente(c),
                  _s(c['ruc']),
                  _s(c['vendedor']),
                  _s(c['sector']),
                  _s(c['departamento']),
                  'US\$ ${_money.format(_facturacionCliente(c))}',
                  '${_money.format(_pesoCliente(c))} kg',
                  fechaCompra == null
                      ? '-'
                      : DateFormat('dd/MM/yyyy').format(fechaCompra),
                  c['activo'] == true ? 'ACTIVO' : 'INACTIVO',
                ];
              }).toList(),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        name: 'Clientes CRM ELCOPE',
        onLayout: (_) async => pdf.save(),
      );
    } catch (e) {
      _mensaje('Error al imprimir: $e', error: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _mensaje(String mensaje, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? Colors.red.shade700 : _azul,
        content: Text(mensaje),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 44,
                ),
                const SizedBox(height: 10),
                const Text(
                  'No se pudo cargar Clientes',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _cargar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _encabezado(bool mobile) {
    return Row(children: [
      Container(width: 48,height: 48,decoration:BoxDecoration(color:const Color(0xFFEAF2FB),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.people_alt_outlined,color:_azul,size:28)),
      const SizedBox(width:12),
      const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Clientes',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900,color:_azul,letterSpacing:-.4)),SizedBox(height:2),Text('Gestiona tu cartera de clientes y realiza seguimiento comercial.',style:TextStyle(color:Colors.black54))])),
    ]);
  }

  List<String> get _segmentos => const [
    'TODOS','SIN LLAMADA','SIN WHATSAPP','SIN CORREO','SIN VISITA',
    'SIN OPORTUNIDAD','ACTIVOS','INACTIVOS',
  ];

  String _segmentoLabel(String value) {
    switch (value) {
      case 'SIN CONTACTO':
        return 'Sin contacto';
      case 'SIN LLAMADA':
        return 'Sin llamada';
      case 'SIN WHATSAPP':
        return 'Sin WhatsApp';
      case 'SIN CORREO':
        return 'Sin correo';
      case 'SIN VISITA':
        return 'Sin visita';
      case 'EN RIESGO':
        return 'En riesgo';
      case 'SIN OPORTUNIDAD':
        return 'Sin oportunidad';
      case 'CON OPORTUNIDAD':
        return 'Con oportunidad';
      case 'ACTIVOS':
        return 'Clientes activos';
      case 'INACTIVOS':
        return 'Clientes inactivos';
      default:
        return 'Todos';
    }
  }

  IconData _segmentoIcon(String value) {
    switch (value) {
      case 'SIN CONTACTO':
        return Icons.notifications_active_outlined;
      case 'SIN LLAMADA':
        return Icons.phone_disabled_outlined;
      case 'SIN WHATSAPP':
        return Icons.chat_bubble_outline;
      case 'SIN CORREO':
        return Icons.mail_outline;
      case 'SIN VISITA':
        return Icons.event_busy_outlined;
      case 'EN RIESGO':
        return Icons.warning_amber_rounded;
      case 'SIN OPORTUNIDAD':
        return Icons.star_border_rounded;
      case 'CON OPORTUNIDAD':
        return Icons.star_rounded;
      case 'ACTIVOS':
        return Icons.check_circle_outline;
      case 'INACTIVOS':
        return Icons.pause_circle_outline;
      default:
        return Icons.people_alt_outlined;
    }
  }

  Color _segmentoColor(String value) {
    switch (value) {
      case 'SIN CONTACTO':
      case 'EN RIESGO':
        return Colors.red.shade600;
      case 'SIN LLAMADA':
        return Colors.red.shade500;
      case 'SIN WHATSAPP':
        return Colors.green.shade600;
      case 'SIN CORREO':
        return Colors.deepPurple.shade500;
      case 'SIN VISITA':
        return Colors.indigo.shade500;
      case 'SIN OPORTUNIDAD':
        return Colors.orange.shade700;
      case 'CON OPORTUNIDAD':
        return Colors.amber.shade800;
      case 'ACTIVOS':
        return _verde;
      case 'INACTIVOS':
        return Colors.grey.shade700;
      default:
        return _azul;
    }
  }

  Widget _gestionTabs(bool mobile) {
    final visible = _segmentos;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _borde),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: visible.map((segmento) {
              final selected = _segmento == segmento;
              final color = _segmentoColor(segmento);
              final count = _carteraStats[segmento] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _segmento = segmento;
                      _pagina = 0;
                    });
                    _cargar();
                  },
                  avatar: Icon(
                    _segmentoIcon(segmento),
                    size: 18,
                    color: selected ? Colors.white : color,
                  ),
                  label: Text('$count  ${_segmentoLabel(segmento)}'),
                  selectedColor: _azul,
                  backgroundColor: const Color(0xFFF5F8FB),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF173B5C),
                    fontWeight: FontWeight.w800,
                  ),
                  side: BorderSide(
                    color: selected ? _azul : _borde,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  DateTime? _ultimoContactoGestion(Map<String, dynamic> c) => _date(c['ultimo_contacto']);

  bool _gestionBool(Map<String, dynamic> c, String key) => c[key] == true;

  Widget _contactoIcon(Map<String, dynamic> c, String key, IconData icon) {
    final ok = _gestionBool(c, key);
    return Tooltip(
      message: ok ? 'Registrado' : 'Sin registro',
      child: Icon(
        ok ? Icons.check_circle : Icons.cancel,
        size: 20,
        color: ok ? _verde : Colors.red.shade500,
      ),
    );
  }

  Widget _campanita(Map<String, dynamic> c) {
    final alerta = _s(c['alerta_contacto']).toUpperCase();
    final dias = int.tryParse(c['dias_sin_contacto']?.toString() ?? '') ?? 0;
    final color = alerta == 'NUNCA'
        ? Colors.red.shade600
        : alerta == 'VENCIDO'
            ? Colors.orange.shade700
            : _verde;
    final texto = alerta == 'NUNCA'
        ? 'Nunca se ha registrado contacto'
        : alerta == 'VENCIDO'
            ? 'Sin contacto hace $dias días'
            : 'Contacto al día';

    return Tooltip(
      message: texto,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.notifications_active_rounded, color: color, size: 21),
          if (alerta != 'OK')
            Positioned(
              right: -2,
              top: -3,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ultimoContactoWidget(Map<String, dynamic> c) {
    final fecha = _ultimoContactoGestion(c);
    final alerta = _s(c['alerta_contacto']).toUpperCase();
    if (fecha == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _campanita(c),
          const SizedBox(width: 6),
          Text(
            'Nunca',
            style: TextStyle(
              color: Colors.red.shade600,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _campanita(c),
        const SizedBox(width: 6),
        Text(
          DateFormat('dd/MM/yyyy').format(fecha),
          style: TextStyle(
            color: alerta == 'VENCIDO' ? Colors.orange.shade800 : Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  static const List<String> _compraOpciones = [
    'TODOS',
    'SIN VENTAS',
    'CON VENTAS',
    '0-30 DIAS',
    '31-60 DIAS',
    '61-90 DIAS',
    'MAS DE 30 DIAS',
    'MAS DE 60 DIAS',
    'MAS DE 90 DIAS',
  ];

  String _compraFiltroLabel(String value) {
    switch (value) {
      case 'SIN VENTAS': return 'Sin ventas';
      case 'CON VENTAS': return 'Con ventas';
      case '0-30 DIAS': return 'Compra 0-30 días';
      case '31-60 DIAS': return 'Compra 31-60 días';
      case '61-90 DIAS': return 'Compra 61-90 días';
      case 'MAS DE 30 DIAS': return 'Sin compra > 30 días';
      case 'MAS DE 60 DIAS': return 'Sin compra > 60 días';
      case 'MAS DE 90 DIAS': return 'Sin compra > 90 días';
      default: return 'Todas las compras';
    }
  }

  int? _diasSinCompra(Map<String, dynamic> c) {
    final fecha = _ultimaCompra(c);
    if (fecha == null) return null;
    final hoy = DateTime.now();
    final d = DateTime(fecha.year, fecha.month, fecha.day);
    return hoy.difference(d).inDays;
  }

  void _abrir360(Map<String, dynamic> c) {
    final codigo = _s(c['codigo']);
    if (codigo.isEmpty) {
      _mensaje('Este cliente no tiene Código Cliente para abrir Cliente 360°.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CrmCliente360Page(codigoInicial: codigo)),
    );
  }

  Widget _filtros(bool mobile) {
    final vendedorOptions = _esJefeLima || Sesion.esAdministrador || Sesion.rol.trim().toLowerCase() == 'gerencia'
        ? _opcionesLocales('vendedor')
        : <String>[Sesion.vendedor.trim().isEmpty ? _vendedor : Sesion.vendedor.trim()];
    final campos = [
      _filtro('Vendedor', _vendedor, vendedorOptions.isEmpty ? ['TODOS'] : vendedorOptions, (v) {
        setState(() { _vendedor = v; _pagina = 0; }); _cargar();
      }),
      _filtro('Sector', _sector, _opcionesLocales('sector'), (v) { setState(() { _sector = v; _pagina = 0; }); _cargar(); }),
      _filtro('Giro', _giro, _opcionesLocales('giro'), (v) { setState(() { _giro = v; _pagina = 0; }); _cargar(); }),
      _filtro('Departamento', _departamento, _opcionesLocales('departamento'), (v) { setState(() { _departamento = v; _pagina = 0; }); _cargar(); }),
      _filtro('Estado', _segmento == 'ACTIVOS' ? 'ACTIVO' : _segmento == 'INACTIVOS' ? 'INACTIVO' : 'TODOS', const ['TODOS','ACTIVO','INACTIVO'], (v) {
        setState(() { _segmento = v == 'ACTIVO' ? 'ACTIVOS' : v == 'INACTIVO' ? 'INACTIVOS' : 'TODOS'; _pagina = 0; }); _cargar();
      }),
      _filtro('Última compra', _compraFiltro, _compraOpciones, (v) {
        setState(() { _compraFiltro = v; _pagina = 0; });
        _cargar();
      }, labels: true),
    ];
    return Card(
      elevation: 0, color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: _borde)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          TextField(
            controller: TextEditingController(text: _busqueda)..selection = TextSelection.collapsed(offset: _busqueda.length),
            onChanged: (v) => _busqueda = v,
            onSubmitted: (_) { _pagina = 0; _cargar(); },
            decoration: InputDecoration(
              hintText: 'Buscar por cliente, RUC, código o vendedor...', prefixIcon: const Icon(Icons.search),
              filled: true, fillColor: _fondo, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          mobile ? Column(children: [for (final f in campos) Padding(padding: const EdgeInsets.only(bottom: 8), child: f)]) : Wrap(spacing: 10, runSpacing: 10, children: campos),
          Row(children: [
            Switch(value: _soloActivos, onChanged: (v) { setState(() { _soloActivos = v; _pagina = 0; }); _cargar(); }),
            const Text('Solo clientes activos', style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton.icon(onPressed: () {
              final rol = Sesion.rol.trim().toLowerCase();
              final vendedorSesion = Sesion.vendedor.trim();
              setState(() {
                _busqueda=''; _sector='TODOS'; _giro='TODOS'; _departamento='TODOS'; _pagina=0; _segmento='TODOS'; _compraFiltro='TODOS'; _soloActivos=true;
                _vendedor = (rol == 'jefe lima' || rol == 'jefe provincia' || rol == 'gerencia')
                    ? 'TODOS'
                    : (vendedorSesion.isNotEmpty ? vendedorSesion : 'TODOS');
              }); _cargar();
            }, icon: const Icon(Icons.filter_alt_off_outlined), label: const Text('Limpiar filtros')),
          ]),
        ]),
      ),
    );
  }

  Widget _filtro(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged, {
    bool labels = false,
  }) {
    return SizedBox(
      width: 210,
      child: DropdownButtonFormField<String>(
        initialValue: options.contains(value) ? value : 'TODOS',
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: _fondo,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        items: options
            .map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(
                  labels ? (label == 'Última compra' ? _compraFiltroLabel(v) : _ordenLabel(v)) : v,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _acciones(bool mobile) {
    final botones = <Widget>[
      FilledButton.icon(onPressed: () => _mensaje('Nuevo cliente: próximamente disponible.'), icon: const Icon(Icons.add), label: const Text('Nuevo cliente')),
      if (_puedeImportarCartera) OutlinedButton.icon(onPressed: _procesando ? null : _importarExcel, icon: const Icon(Icons.upload_file_outlined), label: const Text('Importar Excel')),
      OutlinedButton.icon(onPressed: _procesando ? null : _exportarExcel, icon: const Icon(Icons.download_outlined), label: const Text('Exportar Excel')),
      OutlinedButton.icon(onPressed: _procesando ? null : _imprimir, icon: const Icon(Icons.print_outlined), label: const Text('Imprimir')),
    ];
    return Align(alignment: Alignment.centerRight, child: Wrap(spacing: 10, runSpacing: 8, children: botones));
  }

  Widget _resumen(bool mobile) {
    final cards = [
      _miniKpi('Total clientes', '${_totalClientes}', Icons.people_alt_outlined),
      _miniKpi('Sin llamada', '${_carteraStats['SIN LLAMADA'] ?? 0}', Icons.phone_outlined, color: Colors.red.shade600),
      _miniKpi('Sin WhatsApp', '${_carteraStats['SIN WHATSAPP'] ?? 0}', Icons.chat_outlined, color: Colors.green.shade600),
      _miniKpi('Sin correo', '${_carteraStats['SIN CORREO'] ?? 0}', Icons.mail_outline, color: Colors.deepOrange.shade500),
      _miniKpi('Sin visita', '${_carteraStats['SIN VISITA'] ?? 0}', Icons.event_outlined, color: Colors.deepPurple.shade500),
      _miniKpi('Con oportunidad', '${_carteraStats['CON OPORTUNIDAD'] ?? 0}', Icons.star_rounded, color: Colors.amber.shade700),
    ];
    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth >= 1250 ? 6 : c.maxWidth >= 900 ? 3 : c.maxWidth >= 600 ? 2 : 1;
      return GridView.count(crossAxisCount: columns, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: mobile ? 2.8 : 2.35, children: cards);
    });
  }

  Widget _miniKpi(
    String title,
    String value,
    IconData icon, {
    Color color = _azul,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _borde),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.black54),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paginacion() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _borde),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        child: Row(
          children: [
            Text(
              'Página ${_pagina + 1} · ${_totalClientes} clientes',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Anterior',
              onPressed: _pagina == 0 || _cargando
                  ? null
                  : () => _cambiarPagina(_pagina - 1),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Siguiente',
              onPressed: !_haySiguiente || _cargando
                  ? null
                  : () => _cambiarPagina(_pagina + 1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panelCartera() {
    final total = _contactoResumen['total_clientes'] ?? (_carteraStats['TODOS'] ?? 0);
    final sin = _contactoResumen['sin_contacto'] ?? (_carteraStats['SIN CONTACTO'] ?? 0);
    final con = _contactoResumen['con_contacto'] ?? (total - sin);
    final opp = _contactoResumen['con_oportunidad'] ?? (_carteraStats['CON OPORTUNIDAD'] ?? 0);
    final ina = _contactoResumen['inactivos'] ?? (_carteraStats['INACTIVOS'] ?? 0);
    final otros = (total - sin - con - ina).clamp(0, total);
    return _sideCard('Estado de tu cartera', Column(children: [
      SizedBox(height: 125, child: Stack(alignment: Alignment.center, children: [
        SizedBox(width: 120, height: 120, child: CircularProgressIndicator(value: total == 0 ? 0 : sin / total, strokeWidth: 18, backgroundColor: Colors.green.shade100, color: Colors.red.shade500)),
        Column(mainAxisSize: MainAxisSize.min, children: [Text('$total', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _azul)), const Text('Clientes')]),
      ])),
      _legend('Sin contacto', sin, Colors.red.shade500, total),
      _legend('Con contacto', con, _verde, total),
      _legend('Con oportunidad', opp, Colors.indigo.shade500, total),
      _legend('Inactivos', ina, Colors.grey, total),
      _legend('Otros', otros, Colors.orange.shade400, total),
    ]));
  }

  Widget _panelContacto() {
    final vals = [
      ('Hace 0-7 días', _contactoResumen['hace_0_7'] ?? 0, _verde),
      ('Hace 8-30 días', _contactoResumen['hace_8_30'] ?? 0, Colors.blue),
      ('Hace 31-90 días', _contactoResumen['hace_31_90'] ?? 0, Colors.orange),
      ('Más de 90 días', _contactoResumen['mas_90'] ?? 0, Colors.red),
      ('Nunca', _contactoResumen['sin_contacto'] ?? 0, Colors.grey),
    ];
    final max = vals.fold<int>(1, (m, x) => x.$2 > m ? x.$2 : m);
    return _sideCard('Último contacto', Column(children: [for (final x in vals) Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [SizedBox(width: 90, child: Text(x.$1, style: const TextStyle(fontSize: 11))), Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(minHeight: 9, value: x.$2 / max, color: x.$3, backgroundColor: const Color(0xFFE7ECF2)))), const SizedBox(width: 8), SizedBox(width: 22, child: Text('${x.$2}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)))]))]));
  }

  Widget _panelTop5() {
    final top = _clientes.take(5).toList();
    return _sideCard('Top 5 clientes por facturación', Column(children: [for (var i=0;i<top.length;i++) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Container(width: 24,height:24,alignment:Alignment.center,decoration:BoxDecoration(color:const Color(0xFFF2F4F7),shape:BoxShape.circle),child:Text('${i+1}',style:const TextStyle(fontWeight:FontWeight.w800))),const SizedBox(width:8),Expanded(child:Text(_nombreCliente(top[i]),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700))),Text('US\$ ${_money.format(_facturacionCliente(top[i]))}',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800,color:_azul))]))]));
  }

  Widget _sideCard(String title, Widget child) => Card(elevation:0,color:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14),side:const BorderSide(color:_borde)),child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w900,color:_azul)),const SizedBox(height:10),child])));
  Widget _legend(String label,int value,Color color,int total) => Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Row(children:[Container(width:9,height:9,decoration:BoxDecoration(color:color,shape:BoxShape.circle)),const SizedBox(width:6),Expanded(child:Text(label,style:const TextStyle(fontSize:11))),Text('$value',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800)),if(total>0) Text(' (${(value*100/total).round()}%)',style:const TextStyle(fontSize:10,color:Colors.grey))]));

  Widget _tablaOLista(bool mobile) {
    final lista = _filtrados;

    if (lista.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.search_off_rounded, size: 44, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                Text(
                  'No hay clientes que coincidan con el filtro.',
                  style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (mobile) {
      return Column(children: lista.map(_clienteCard).toList());
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 18,
          horizontalMargin: 14,
          headingRowHeight: 48,
          dataRowMinHeight: 46,
          dataRowMaxHeight: 54,
          headingRowColor: const WidgetStatePropertyAll(Color(0xFFF0F5FA)),
          columns: const [
            DataColumn(label: Text('Cliente')),
            DataColumn(label: Text('RUC')),
            DataColumn(label: Text('Vendedor')),
            DataColumn(label: Text('Sector')),
            DataColumn(label: Text('Departamento')),
            DataColumn(label: Text('Monto / Facturación')),
            DataColumn(label: Text('Días sin compra')),
            DataColumn(label: Text('Último contacto')),
            DataColumn(label: Text('Llamada')),
            DataColumn(label: Text('WhatsApp')),
            DataColumn(label: Text('Correo')),
            DataColumn(label: Text('Visita')),
            DataColumn(label: Text('Oportunidad')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('')),
          ],
          rows: lista.map(_fila).toList(),
        ),
      ),
    );
  }

  Widget _diasSinCompraWidget(Map<String, dynamic> c) {
    final dias = _diasSinCompra(c);
    if (dias == null) {
      return const Text('Nunca', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800));
    }
    final color = dias > 90 ? Colors.red.shade600 : dias > 30 ? Colors.orange.shade700 : _verde;
    return Text('$dias días', style: TextStyle(color: color, fontWeight: FontWeight.w800));
  }

  DataRow _fila(Map<String, dynamic> c) {
    final oportunidad = _gestionBool(c, 'tiene_oportunidad');
    final montoOportunidad = _n(c['monto_oportunidad']);

    return DataRow(
      cells: [
        DataCell(
          InkWell(
            onTap: () => _abrir360(c),
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 225,
              child: Row(
              children: [
                _campanita(c),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _nombreCliente(c),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: _azul),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
        DataCell(Text(_s(c['ruc']).isEmpty ? '-' : _s(c['ruc']))),
        DataCell(Text(_s(c['vendedor']).isEmpty ? '-' : _s(c['vendedor']))),
        DataCell(Text(_s(c['sector']).isEmpty ? '-' : _s(c['sector']))),
        DataCell(Text(_s(c['departamento']).isEmpty ? '-' : _s(c['departamento']))),
        DataCell(
          Text(
            'US\$ ${_money.format(_facturacionCliente(c))}',
            style: const TextStyle(fontWeight: FontWeight.w800, color: _verde),
          ),
        ),
        DataCell(_diasSinCompraWidget(c)),
        DataCell(_ultimoContactoWidget(c)),
        DataCell(_contactoIcon(c, 'tiene_llamada', Icons.phone_outlined)),
        DataCell(_contactoIcon(c, 'tiene_whatsapp', Icons.chat_outlined)),
        DataCell(_contactoIcon(c, 'tiene_correo', Icons.mail_outline)),
        DataCell(_contactoIcon(c, 'tiene_visita', Icons.event_outlined)),
        DataCell(
          oportunidad
              ? Text(
                  montoOportunidad > 0 ? 'US\$ ${_money.format(montoOportunidad)}' : 'ACTIVA',
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900),
                )
              : const Text('-', style: TextStyle(color: Colors.grey)),
        ),
        DataCell(_estado(c['activo'] == true)),
        DataCell(
          PopupMenuButton<String>(
            tooltip: 'Acciones',
            onSelected: (value) {
              if (value == '360') {
                _abrir360(c);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: '360', child: Text('Ver Cliente 360°')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _clienteCard(Map<String, dynamic> c) {
    final fecha = _ultimaCompra(c);
    final oportunidad = _gestionBool(c, 'tiene_oportunidad');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _borde),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _campanita(c),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_nombreCliente(c), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                _estado(c['activo'] == true),
              ],
            ),
            const SizedBox(height: 10),
            _ultimoContactoWidget(c),
            const SizedBox(height: 6),
            Text('RUC: ${_s(c['ruc']).isEmpty ? '-' : _s(c['ruc'])}'),
            Text('Vendedor: ${_s(c['vendedor']).isEmpty ? '-' : _s(c['vendedor'])}'),
            Text('Sector: ${_s(c['sector']).isEmpty ? '-' : _s(c['sector'])}'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _estadoGestion('Llamada', _gestionBool(c, 'tiene_llamada'), Icons.phone_outlined),
                _estadoGestion('WhatsApp', _gestionBool(c, 'tiene_whatsapp'), Icons.chat_outlined),
                _estadoGestion('Correo', _gestionBool(c, 'tiene_correo'), Icons.mail_outline),
                _estadoGestion('Visita', _gestionBool(c, 'tiene_visita'), Icons.event_outlined),
              ],
            ),
            const SizedBox(height: 8),
            Text('Monto / Facturación: US\$ ${_money.format(_facturacionCliente(c))}', style: const TextStyle(color: _verde, fontWeight: FontWeight.w800)),
            _diasSinCompraWidget(c),
            Text('Última compra: ${fecha == null ? 'Sin compra registrada' : DateFormat('dd/MM/yyyy').format(fecha)}'),
            if (oportunidad) ...[
              const SizedBox(height: 4),
              const Text('⭐ Oportunidad comercial activa', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w800)),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CrmCliente360Page(codigoInicial: _s(c['codigo']))),
                ),
                icon: const Icon(Icons.person_search_outlined),
                label: const Text('Ver Cliente 360°'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _estadoGestion(String label, bool activo, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: activo ? const Color(0xFFE8F7EF) : const Color(0xFFFFEEEE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(activo ? Icons.check_circle : Icons.cancel, size: 15, color: activo ? _verde : Colors.red.shade500),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: activo ? _verde : Colors.red.shade600)),
        ],
      ),
    );
  }

  Widget _estado(bool activo) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: activo
            ? const Color(0xFFE6F7EF)
            : const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        activo ? 'ACTIVO' : 'INACTIVO',
        style: TextStyle(
          color: activo ? _verde : Colors.grey.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  void _proximamente(String cliente) {
    _mensaje('Cliente 360°: $cliente');
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 750;

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _fondo,
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Inter', bodyColor: const Color(0xFF19344D), displayColor: const Color(0xFF19344D)),
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: _azul, secondary: _azulClaro),
      ),
      child: Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _azul,
        elevation: 0,
        title: const Text(
          'Clientes',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargar,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: _cargar,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 16, vertical: mobile ? 12 : 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _encabezado(mobile),
                            const SizedBox(height: 10),
                            _gestionTabs(mobile),
                            const SizedBox(height: 10),
                            _filtros(mobile),
                            const SizedBox(height: 10),
                            _acciones(mobile),
                            const SizedBox(height: 10),
                            _resumen(mobile),
                            const SizedBox(height: 10),
                            if (mobile) ...[
                              _tablaOLista(mobile),
                              const SizedBox(height: 12),
                              _panelCartera(), const SizedBox(height: 12),
                              _panelContacto(), const SizedBox(height: 12),
                              _panelTop5(),
                            ] else
                              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Expanded(flex: 4, child: Column(children: [_tablaOLista(mobile), const SizedBox(height: 10), _paginacion()])),
                                const SizedBox(width: 12),
                                SizedBox(width: 285, child: Column(children: [_panelCartera(), const SizedBox(height: 10), _panelContacto(), const SizedBox(height: 10), _panelTop5()])),
                              ]),
                          ],
                        ),
                      ),
                    ),
                    if (_procesando)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: .12),
                          child: const Center(
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 12),
                                    Text(
                                      'Procesando...',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
      ),
    );
  }
}
