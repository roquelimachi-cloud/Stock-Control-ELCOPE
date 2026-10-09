import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show compute;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border, TextSpan, TextDirection;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../services/supabase/supabase_service.dart';
import '../../../services/sesion.dart';
import '../cliente_360/crm_cliente_360_page.dart';

class CrmClientesPage extends StatefulWidget {
  const CrmClientesPage({super.key});

  @override
  State<CrmClientesPage> createState() => _CrmClientesPageState();
}

class _CrmClientesPageState extends State<CrmClientesPage> {
  static const _azul = Color(0xFF0B3B63);
  static const _azulClaro = Color(0xFF1468A8);
  static const _verde = Color(0xFF0A9B61);
  static const _fondo = Color(0xFFF4F7FA);
  static const _borde = Color(0xFFE1E7EC);

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
  Timer? _busquedaDebounce;
  List<String> _vendedoresAutorizados = [];
  String _vendedor = 'TODOS';
  String _sector = 'TODOS';
  String _giro = 'TODOS';
  String _departamento = 'TODOS';
  String _anio = 'TODOS';
  bool _soloActivos = true;
  String _estado = 'TODOS';
  String _ultimaCompraFiltro = 'TODAS';
  Map<String, dynamic> _gestionStats = {};
  final Map<int, double> _facturacionMensual = {for (var i = 1; i <= 12; i++) i: 0};

  int _pagina = 0;
  static const int _porPagina = 12;
  bool _haySiguiente = false;
  String _orden = 'FACTURACION_DESC';
  double _facturacionTotal = 0;
  double _pesoTotal = 0;
  int _totalClientes = 0;
  int _conFacturacion = 0;

  // Acepta el indicador de sesión y el rol textual usado en el encabezado.
  // Esto evita ocultar la importación cuando el rol dice Administrador,
  // pero el booleano de sesión no fue actualizado correctamente.
  bool get _puedeImportarCartera {
    final rol = Sesion.rol.trim().toLowerCase();
    return Sesion.esAdministrador ||
        rol == 'administrador' ||
        rol == 'admin';
  }

  @override
  void initState() {
    super.initState();
    final rol = Sesion.rol.trim().toLowerCase();
    final vendedorSesion = Sesion.vendedor.trim();
    // Un asesor, incluso si además tiene rol Administrador, inicia viendo su propia cartera.
    // Las jefaturas pueden trabajar con TODOS los vendedores autorizados.
    if (vendedorSesion.isNotEmpty && rol != 'jefe lima' && rol != 'jefe provincia' && rol != 'gerencia') {
      _vendedor = vendedorSesion;
    }
    // La jefatura inicia con todos los departamentos para ver la cartera
    // completa de sus vendedores autorizados. El alcance sigue restringido
    // por _vendedoresPermitidos() y por p_vendedores_permitidos en Supabase.
    // El usuario puede elegir LIMA manualmente si necesita ese filtro.
    _departamento = 'TODOS';
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


  double _facturacionCliente(Map<String, dynamic> c) {
    final id = _s(c['id']);
    final codigo = _s(c['codigo']);
    if (id.isNotEmpty) return _facturacionPorCliente['ID:$id'] ?? _n(c['facturacion']);
    if (codigo.isNotEmpty) return _facturacionPorCliente['COD:$codigo'] ?? _n(c['facturacion']);
    return _n(c['facturacion']);
  }

  double _pesoCliente(Map<String, dynamic> c) {
    final id = _s(c['id']);
    final codigo = _s(c['codigo']);
    if (id.isNotEmpty) return _pesoPorCliente['ID:$id'] ?? _n(c['peso_kg']);
    if (codigo.isNotEmpty) return _pesoPorCliente['COD:$codigo'] ?? _n(c['peso_kg']);
    return _n(c['peso_kg']);
  }

  DateTime? _ultimaCompra(Map<String, dynamic> c) {
    final id = _s(c['id']);
    final codigo = _s(c['codigo']);
    if (id.isNotEmpty && _ultimaCompraPorCliente.containsKey('ID:$id')) {
      return _ultimaCompraPorCliente['ID:$id'];
    }
    if (codigo.isNotEmpty && _ultimaCompraPorCliente.containsKey('COD:$codigo')) {
      return _ultimaCompraPorCliente['COD:$codigo'];
    }
    return _date(c['ultima_compra']);
  }

  Widget _estadoDark(bool activo) {
    final color = activo ? const Color(0xFF35D39A) : const Color(0xFFFF5252);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Text(
        activo ? 'Activo' : 'Inactivo',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }

  Future<List<String>?> _vendedoresPermitidos() async {
    final rol = Sesion.rol.trim().toLowerCase();
    final vendedorSesion = Sesion.vendedor.trim();

    // Gerencia puede consultar todo.
    if (rol == 'gerencia') {
      return null;
    }

    // Jefaturas: solo vendedores autorizados en usuario_permisos.
    if (rol == 'jefe lima' || rol == 'jefe provincia') {
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

    // Usuario/vendedor: exclusivamente su vendedor de sesión.
    if (vendedorSesion.isEmpty) return <String>[];
    return <String>[vendedorSesion];
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final vendedoresPermitidos = await _vendedoresPermitidos();
      final vendedoresOpciones = <String>{};
      if (vendedoresPermitidos != null) {
        vendedoresOpciones.addAll(vendedoresPermitidos.where((v) => v.trim().isNotEmpty));
      } else {
        // Gerencia puede consultar vendedores de toda la cartera; se recogen
        // los nombres de todos los registros paginados.
      }

      final compraFiltroRpc = switch (_ultimaCompraFiltro) {
        'SIN_VENTAS' => 'SIN VENTAS',
        'CON_VENTAS' => 'CON VENTAS',
        '0_30' => '0-30 DIAS',
        '31_60' => '31-60 DIAS',
        '61_90' => '61-90 DIAS',
        'MAS_30' => 'MAS DE 30 DIAS',
        'MAS_60' => 'MAS DE 60 DIAS',
        'MAS_90' => 'MAS DE 90 DIAS',
        _ => 'TODAS',
      };

      // Carga todas las páginas de la consulta filtrada. El límite de 200 es
      // por llamada a Supabase, no el total de clientes que debe ver el usuario.
      const int pageSize = 200;
      final clientes = <Map<String, dynamic>>[];
      var offset = 0;
      while (true) {
        final result = await _db.rpc(
          'crm_obtener_clientes_cartera_fast_v1',
          params: {
            'p_busqueda': _busqueda.trim(),
            'p_vendedor': _vendedor,
            'p_sector': _sector,
            'p_giro': _giro,
            'p_departamento': _departamento,
            'p_estado': _estado,
            'p_segmento': 'TODOS',
            'p_solo_activos': _soloActivos,
            'p_limit': pageSize,
            'p_offset': offset,
            'p_orden': _orden,
            'p_anio': _anio == 'TODOS' ? null : int.tryParse(_anio),
            'p_vendedores_permitidos': vendedoresPermitidos,
            'p_compra_filtro': compraFiltroRpc,
          },
        );
        final page = List<Map<String, dynamic>>.from(
          (result as List).map((row) => Map<String, dynamic>.from(row as Map)),
        );
        clientes.addAll(page);
        for (final c in page) {
          final v = _s(c['vendedor']);
          if (v.isNotEmpty) vendedoresOpciones.add(v);
        }
        if (page.length < pageSize) break;
        offset += page.length;
      }

      // Las banderas se consultan por bloques para que las estadísticas y el
      // gráfico se calculen con toda la cartera filtrada, no solo la primera página.
      const int flagsBatchSize = 200;
      for (var start = 0; start < clientes.length; start += flagsBatchSize) {
        final end = (start + flagsBatchSize < clientes.length)
            ? start + flagsBatchSize
            : clientes.length;
        final bloque = clientes.sublist(start, end);
        final codigos = bloque.map((c) => _s(c['codigo']))
            .where((c) => c.isNotEmpty).toSet().toList();
        if (codigos.isEmpty) continue;
        final flagsResult = await _db.rpc(
          'crm_obtener_clientes_gestion_flags_v1',
          params: {'p_codigos': codigos},
        );
        final flags = <String, Map<String, dynamic>>{};
        if (flagsResult is List) {
          for (final row in flagsResult) {
            if (row is Map) {
              final codigo = _s(row['codigo']);
              if (codigo.isNotEmpty) flags[codigo] = Map<String, dynamic>.from(row);
            }
          }
        }
        for (final cliente in bloque) {
          final f = flags[_s(cliente['codigo'])];
          if (f == null) continue;
          cliente['ultimo_contacto'] = f['ultimo_contacto'];
          cliente['dias_sin_contacto'] = f['dias_sin_contacto'];
          cliente['tiene_llamada'] = f['tiene_llamada'];
          cliente['tiene_whatsapp'] = f['tiene_whatsapp'];
          cliente['tiene_correo'] = f['tiene_correo'];
          cliente['tiene_visita'] = f['tiene_visita'];
          cliente['tiene_oportunidad'] = f['tiene_oportunidad'];
          cliente['alerta_contacto'] = f['alerta_contacto'];
          cliente['proxima_accion'] = f['proxima_accion'];
          cliente['fecha_proxima_accion'] = f['fecha_proxima_accion'];
        }
      }

      // Estadísticas derivadas de exactamente la misma lista filtrada que se
      // presenta en la tabla. Evita que los KPI incluyan otros departamentos,
      // estados o clientes fuera de la búsqueda actual.
      final activos = clientes.where((c) => c['activo'] == true).length;
      final sinLlamada = clientes.where((c) => !_b(c['tiene_llamada'])).length;
      final sinWhatsapp = clientes.where((c) => !_b(c['tiene_whatsapp'])).length;
      final sinCorreo = clientes.where((c) => !_b(c['tiene_correo'])).length;
      final sinVisita = clientes.where((c) => !_b(c['tiene_visita'])).length;
      final sinOportunidad = clientes.where((c) => !_b(c['tiene_oportunidad'])).length;
      final sinContacto = clientes.where((c) => !_b(c['tiene_llamada']) &&
          !_b(c['tiene_whatsapp']) && !_b(c['tiene_correo']) && !_b(c['tiene_visita'])).length;
      final oportunidades = clientes.where((c) => _b(c['tiene_oportunidad'])).length;
      final gestionStats = <String, dynamic>{
        'total': clientes.length,
        'activos': activos,
        'inactivos': clientes.length - activos,
        'sin_llamada': sinLlamada,
        'sin_whatsapp': sinWhatsapp,
        'sin_correo': sinCorreo,
        'sin_visita': sinVisita,
        'sin_oportunidad': sinOportunidad,
        'sin_contacto': sinContacto,
        'con_oportunidad': oportunidades,
        'en_riesgo': sinContacto,
      };

      final mensual = <int, double>{for (var i = 1; i <= 12; i++) i: 0};
      try {
        final resumen = await _db.rpc(
          'crm_obtener_facturacion_mensual_anio_v1',
          params: {
            'p_anio': DateTime.now().year,
            'p_vendedor': _vendedor,
            'p_usuario_id': Sesion.idUsuario,
          },
        );
        if (resumen is Map && resumen['meses'] is List) {
          for (final item in resumen['meses']) {
            if (item is! Map) continue;
            final mes = int.tryParse(_s(item['mes']));
            if (mes != null && mes >= 1 && mes <= 12) {
              mensual[mes] = _n(item['facturacion']);
            }
          }
        }
      } catch (_) {
        // Un fallo del gráfico mensual no debe impedir la carga de clientes.
      }

      if (!mounted) return;
      setState(() {
        _clientes = clientes;
        _gestionStats = gestionStats;
        _vendedoresAutorizados = (Sesion.rol.trim().toLowerCase() == 'gerencia'
                ? vendedoresOpciones.toList()
                : (vendedoresPermitidos ?? vendedoresOpciones.toList()))
            .where((v) => v.trim().isNotEmpty).toSet().toList()..sort();
        _facturacionMensual
          ..clear()
          ..addAll(mensual);
        _facturacionTotal = clientes.fold<double>(0, (sum, c) => sum + _n(c['facturacion']));
        _pesoTotal = clientes.fold<double>(0, (sum, c) => sum + _n(c['peso_kg']));
        _totalClientes = clientes.length;
        _conFacturacion = clientes.where((c) => _n(c['facturacion']) > 0).length;
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
        _pagina = 0;
        _haySiguiente = _clientesVisibles.length > _porPagina;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _busquedaDebounce?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> get _clientesVisibles {
    final hoy = DateTime.now();
    final lista = _clientes.where((c) {
      final fecha = _ultimaCompra(c);
      switch (_ultimaCompraFiltro) {
        case 'SIN_VENTAS':
          return fecha == null;
        case 'CON_VENTAS':
          return fecha != null;
        case '0_30':
          return fecha != null && hoy.difference(fecha).inDays >= 0 &&
              hoy.difference(fecha).inDays <= 30;
        case '31_60':
          return fecha != null && hoy.difference(fecha).inDays >= 31 &&
              hoy.difference(fecha).inDays <= 60;
        case '61_90':
          return fecha != null && hoy.difference(fecha).inDays >= 61 &&
              hoy.difference(fecha).inDays <= 90;
        case 'MAS_30':
          return fecha != null && hoy.difference(fecha).inDays > 30;
        case 'MAS_60':
          return fecha != null && hoy.difference(fecha).inDays > 60;
        case 'MAS_90':
          return fecha != null && hoy.difference(fecha).inDays > 90;
        default:
          return true;
      }
    }).toList();

    if (_orden == 'CLIENTE_ASC') {
      lista.sort((a,b) => _nombreCliente(a).compareTo(_nombreCliente(b)));
    } else if (_orden == 'CLIENTE_DESC') {
      lista.sort((a,b) => _nombreCliente(b).compareTo(_nombreCliente(a)));
    } else if (_orden == 'ULTIMA_COMPRA_DESC') {
      lista.sort((a,b) => (_ultimaCompra(b) ?? DateTime(1900))
          .compareTo(_ultimaCompra(a) ?? DateTime(1900)));
    } else if (_orden == 'ULTIMA_COMPRA_ASC') {
      lista.sort((a,b) => (_ultimaCompra(a) ?? DateTime(1900))
          .compareTo(_ultimaCompra(b) ?? DateTime(1900)));
    } else if (_orden == 'FACTURACION_ASC') {
      lista.sort((a,b) => _facturacionCliente(a).compareTo(_facturacionCliente(b)));
    } else {
      lista.sort((a,b) => _facturacionCliente(b).compareTo(_facturacionCliente(a)));
    }
    return lista;
  }

  List<Map<String, dynamic>> get _paginaClientes {
    final lista = _clientesVisibles;
    final inicio = _pagina * _porPagina;
    if (inicio >= lista.length) return const [];
    final fin = (inicio + _porPagina).clamp(0, lista.length);
    return lista.sublist(inicio, fin);
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

  List<String> get _vendedoresOpciones {
    final values = <String>{..._vendedoresAutorizados};
    for (final c in _clientes) {
      final v = _s(c['vendedor']);
      if (v.isNotEmpty) values.add(v);
    }
    if (Sesion.vendedor.trim().isNotEmpty) values.add(Sesion.vendedor.trim());
    final list = values.toList()..sort();
    return ['TODOS', ...list];
  }

  List<String> get _ordenes => const [
    'FACTURACION_DESC',
    'FACTURACION_ASC',
    'ULTIMA_COMPRA_DESC',
    'ULTIMA_COMPRA_ASC',
    'CLIENTE_ASC',
    'CLIENTE_DESC',
  ];

  String _ordenLabel(String value) {
    switch (value) {
      case 'FACTURACION_ASC': return 'Menor facturación';
      case 'ULTIMA_COMPRA_DESC': return 'Compra más reciente';
      case 'ULTIMA_COMPRA_ASC': return 'Compra más antigua';
      case 'CLIENTE_ASC': return 'Cliente A-Z';
      case 'CLIENTE_DESC': return 'Cliente Z-A';
      default: return 'Mayor facturación';
    }
  }

  Future<void> _cambiarPagina(int nueva) async {
    final totalPaginas = (_clientesVisibles.length / _porPagina).ceil();
    if (nueva < 0 || (totalPaginas > 0 && nueva >= totalPaginas)) return;
    setState(() => _pagina = nueva);
  }

  void _actualizarFiltro(VoidCallback fn) {
    setState(() {
      fn();
      _pagina = 0;
    });
    _cargar();
  }

  Future<void> _exportarExcel() async {
    if (_procesando) return;

    try {
      setState(() => _procesando = true);
      _mensaje('Consultando todos los clientes que coinciden con los filtros...');

      final vendedoresPermitidos = await _vendedoresPermitidos();
      final compraFiltroRpc = switch (_ultimaCompraFiltro) {
        'SIN_VENTAS' => 'SIN VENTAS',
        'CON_VENTAS' => 'CON VENTAS',
        '0_30' => '0-30 DIAS',
        '31_60' => '31-60 DIAS',
        '61_90' => '61-90 DIAS',
        'MAS_30' => 'MAS DE 30 DIAS',
        'MAS_60' => 'MAS DE 60 DIAS',
        'MAS_90' => 'MAS DE 90 DIAS',
        _ => 'TODAS',
      };

      // La pantalla carga solo 200 clientes para mantenerla ágil.
      // La exportación, en cambio, recorre la RPC por páginas hasta obtenerlos todos.
      const pageSize = 200;
      var offset = 0;
      final todos = <Map<String, dynamic>>[];
      while (true) {
        final result = await _db.rpc(
          'crm_obtener_clientes_cartera_fast_v1',
          params: {
            'p_busqueda': _busqueda.trim(),
            'p_vendedor': _vendedor,
            'p_sector': _sector,
            'p_giro': _giro,
            'p_departamento': _departamento,
            'p_estado': _estado,
            'p_segmento': 'TODOS',
            'p_solo_activos': _soloActivos,
            'p_limit': pageSize,
            'p_offset': offset,
            'p_orden': _orden,
            'p_anio': _anio == 'TODOS' ? null : int.tryParse(_anio),
            'p_vendedores_permitidos': vendedoresPermitidos,
            'p_compra_filtro': compraFiltroRpc,
          },
        );
        final page = List<Map<String, dynamic>>.from(
          (result as List).map((row) => Map<String, dynamic>.from(row as Map)),
        );
        todos.addAll(page);
        if (page.length < pageSize) break;
        offset += page.length;
        if (mounted) {
          _mensaje('Preparando Excel: ${todos.length} clientes consultados...');
        }
      }

      if (todos.isEmpty) {
        _mensaje('No hay clientes para exportar con los filtros actuales.');
        return;
      }

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

      for (final c in todos) {
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
          TextCellValue(fecha == null ? '' : DateFormat('dd/MM/yyyy').format(fecha)),
          TextCellValue(c['activo'] == true ? 'ACTIVO' : 'INACTIVO'),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('No se pudo generar el archivo Excel.');
      final ruta = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar reporte de clientes',
        fileName: 'clientes_crm_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (ruta == null) return;
      final path = ruta.toLowerCase().endsWith('.xlsx') ? ruta : '$ruta.xlsx';
      await File(path).writeAsBytes(bytes, flush: true);
      _mensaje('Excel generado correctamente: ${todos.length} clientes exportados.');
    } catch (e) {
      _mensaje('Error al exportar Excel: $e', error: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _importarExcel() async {
    // La importación de carteras está reservada al administrador.
    if (!_puedeImportarCartera) {
      _mensaje('Solo el administrador puede importar carteras.', error: true);
      return;
    }

    if (_procesando) return;

    bool preparacionAbierta = false;
    Future<void>? preparacionFuture;
    StateSetter? actualizarPreparacion;
    String etapaPreparacion = 'Abriendo el archivo...';

    void cambiarEtapa(String etapa) {
      etapaPreparacion = etapa;
      actualizarPreparacion?.call(() {});
    }

    Future<void> cerrarPreparacion() async {
      if (preparacionAbierta && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        preparacionAbierta = false;
        final future = preparacionFuture;
        if (future != null) await future;
      }
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      if (file.path == null || file.path!.isEmpty) {
        _mensaje('No se pudo obtener la ruta del Excel.', error: true);
        return;
      }

      setState(() => _procesando = true);
      preparacionAbierta = true;
      preparacionFuture = showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            actualizarPreparacion = setDialogState;
            return AlertDialog(
              title: const Text('Preparando vista previa'),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(etapaPreparacion),
                    const SizedBox(height: 14),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text(
                      'Todavía no se ha guardado ni reemplazado ningún cliente.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
      cambiarEtapa('Leyendo el archivo Excel...');
      final bytes = await File(file.path!).readAsBytes();
      if (bytes.isEmpty) throw Exception('El archivo Excel está vacío.');

      cambiarEtapa('Analizando el Excel en segundo plano...');
      // Excel.decodeBytes es síncrono y puede bloquear Windows con archivos grandes.
      // compute lo ejecuta en otro isolate para mantener viva la interfaz.
      final filas = await compute(_decodificarFilasExcel, bytes);
      if (filas.length < 2) {
        throw Exception('El Excel no contiene registros.');
      }

      final headers = filas.first.map(_normalizar).toList();
      int col(String name) => headers.indexOf(_normalizar(name));
      int colAny(List<String> names) {
        for (final name in names) {
          final index = col(name);
          if (index >= 0) return index;
        }
        return -1;
      }

      final cCodigo = colAny(['codigo', 'codigo_cliente', 'cod_cliente']);
      final cRuc = colAny(['ruc', 'dni', 'documento']);
      final cNombre = colAny(['nombre', 'cliente']);
      final cRazon = colAny(['razon_social', 'descripcion_del_cliente', 'descripcion_cliente', 'razon social']);
      final cDireccion = colAny(['direccion', 'dirección']);
      final cLocalidad = colAny(['localidad', 'distrito']);
      final cDepartamento = colAny(['departamento', 'region']);
      final cCanal = colAny(['canal']);
      final cGiro = colAny(['giro']);
      final cSector = colAny(['sector']);
      final cCodigoVendedor = colAny(['codigo_vendedor', 'cod_vendedor']);
      final cVendedor = colAny(['vendedor', 'asesor', 'nombre_vendedor']);
      final cActivo = colAny(['activo', 'estado']);

      if (cCodigo < 0 && cRuc < 0) {
        throw Exception('El Excel debe contener por lo menos la columna Código Cliente o RUC/DNI.');
      }

      final registros = <Map<String, dynamic>>[];
      for (int i = 1; i < filas.length; i++) {
        final row = filas[i];
        String cell(int index) => index < 0 || index >= row.length
            ? '' : row[index].trim();
        final codigo = cell(cCodigo);
        final ruc = cell(cRuc);
        final razon = cell(cRazon);
        final nombre = cell(cNombre);
        if (codigo.isEmpty && ruc.isEmpty) continue;
        if (razon.isEmpty && nombre.isEmpty) continue;
        // La columna public.clientes.nombre es NOT NULL.
        // Algunos Excel de cartera solo traen 'Descripción del Cliente', que
        // se interpreta como razon_social; en ese caso usarla también como nombre.
        final nombreFinal = nombre.isNotEmpty ? nombre : razon;
        final razonFinal = razon.isNotEmpty ? razon : nombre;
        if (nombreFinal.trim().isEmpty) continue;
        registros.add({
          if (codigo.isNotEmpty) 'codigo': codigo,
          if (ruc.isNotEmpty) 'ruc': ruc,
          'nombre': nombreFinal,
          'razon_social': razonFinal,
          if (cell(cDireccion).isNotEmpty) 'direccion': cell(cDireccion),
          if (cell(cLocalidad).isNotEmpty) 'localidad': cell(cLocalidad),
          if (cell(cDepartamento).isNotEmpty) 'departamento': cell(cDepartamento),
          if (cell(cCanal).isNotEmpty) 'canal': cell(cCanal),
          if (cell(cGiro).isNotEmpty) 'giro': cell(cGiro),
          if (cell(cSector).isNotEmpty) 'sector': cell(cSector),
          if (cell(cCodigoVendedor).isNotEmpty) 'codigo_vendedor': cell(cCodigoVendedor),
          if (cell(cVendedor).isNotEmpty) 'vendedor': cell(cVendedor),
          if (cell(cActivo).isNotEmpty) 'activo': _textoBooleano(cell(cActivo)),
        });
      }
      if (registros.isEmpty) throw Exception('No se encontraron clientes válidos en el Excel.');

      // Consultar por lotes para mostrar una vista previa real antes de guardar.
      cambiarEtapa('Comparando códigos y RUC/DNI con los clientes existentes...');
      final codigos = registros.map((r) => _s(r['codigo'])).where((v) => v.isNotEmpty).toSet().toList();
      final rucs = registros.map((r) => _s(r['ruc'])).where((v) => v.isNotEmpty).toSet().toList();
      final existentesCodigos = <String>{};
      final existentesRuc = <String>{};
      final idPorCodigo = <String, dynamic>{};
      final idPorRuc = <String, dynamic>{};
      // Traer los IDs en consultas por lote. Antes se consultaba Supabase dos
      // veces por cada fila durante el guardado, haciendo muy lenta la carga.
      for (var i = 0; i < codigos.length; i += 100) {
        final lote = codigos.skip(i).take(100).toList();
        final rows = await _db.from('clientes').select('id,codigo,ruc').inFilter('codigo', lote);
        for (final row in (rows as List)) {
          final codigoExistente = _s(row['codigo']);
          final rucExistente = _s(row['ruc']);
          if (codigoExistente.isNotEmpty) {
            existentesCodigos.add(codigoExistente);
            idPorCodigo[codigoExistente] = row['id'];
          }
          if (rucExistente.isNotEmpty) {
            existentesRuc.add(rucExistente);
            idPorRuc[rucExistente] = row['id'];
          }
        }
      }
      for (var i = 0; i < rucs.length; i += 100) {
        final lote = rucs.skip(i).take(100).toList();
        final rows = await _db.from('clientes').select('id,codigo,ruc').inFilter('ruc', lote);
        for (final row in (rows as List)) {
          final codigoExistente = _s(row['codigo']);
          final rucExistente = _s(row['ruc']);
          if (codigoExistente.isNotEmpty) {
            existentesCodigos.add(codigoExistente);
            idPorCodigo[codigoExistente] = row['id'];
          }
          if (rucExistente.isNotEmpty) {
            existentesRuc.add(rucExistente);
            idPorRuc[rucExistente] = row['id'];
          }
        }
      }

      final nuevos = <Map<String, dynamic>>[];
      final porActualizar = <Map<String, dynamic>>[];
      final codigosEnExcel = <String>{};
      final rucsEnExcel = <String>{};
      for (final registro in registros) {
        final codigo = _s(registro['codigo']);
        final ruc = _s(registro['ruc']);
        final repetidoEnExcel = (codigo.isNotEmpty && !codigosEnExcel.add(codigo)) ||
            (ruc.isNotEmpty && !rucsEnExcel.add(ruc));
        if (repetidoEnExcel ||
            (codigo.isNotEmpty && existentesCodigos.contains(codigo)) ||
            (ruc.isNotEmpty && existentesRuc.contains(ruc))) {
          porActualizar.add(registro);
        } else {
          nuevos.add(registro);
        }
      }

      // Cerrar el indicador de preparación para mostrar la vista previa real.
      await cerrarPreparacion();
      if (!mounted) return;
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Vista previa de importación'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Archivo: ${file.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    Chip(avatar: const Icon(Icons.people_alt_outlined, size: 18), label: Text('Leídos: ${registros.length}')),
                    Chip(avatar: const Icon(Icons.person_add_alt_1, size: 18, color: Colors.green), label: Text('Nuevos: ${nuevos.length}')),
                    Chip(avatar: const Icon(Icons.sync, size: 18, color: Colors.orange), label: Text('Actualizar: ${porActualizar.length}')),
                  ]),
                  const SizedBox(height: 10),
                  const Text(
                    'CLIENTES NUEVOS (se agregarán)',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.green),
                  ),
                  const SizedBox(height: 6),
                  if (nuevos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No hay clientes nuevos para agregar.'),
                    ),
                  if (nuevos.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 190),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(dialogContext).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: nuevos.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final cliente = nuevos[index];
                          final nombre = _s(cliente['razon_social']).isNotEmpty
                              ? _s(cliente['razon_social'])
                              : _s(cliente['nombre']);
                          return Material(
                            color: Theme.of(dialogContext).colorScheme.surface,
                            child: ListTile(
                            dense: true,
                            tileColor: Theme.of(dialogContext).colorScheme.surface,
                            leading: const Icon(Icons.person_add_alt_1, color: Colors.green),
                            title: Text(
                              nombre.isEmpty ? '(Sin nombre)' : nombre,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Código: ${_s(cliente['codigo']).isEmpty ? '—' : _s(cliente['codigo'])} · RUC/DNI: ${_s(cliente['ruc']).isEmpty ? '—' : _s(cliente['ruc'])}',
                            ),
                          ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 14),
                  const Text(
                    'CLIENTES EXISTENTES (se actualizarán)',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.orange),
                  ),
                  const SizedBox(height: 6),
                  if (porActualizar.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No hay clientes existentes para actualizar.'),
                    ),
                  if (porActualizar.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 210),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(dialogContext).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: porActualizar.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final cliente = porActualizar[index];
                          final nombre = _s(cliente['razon_social']).isNotEmpty
                              ? _s(cliente['razon_social'])
                              : _s(cliente['nombre']);
                          return Material(
                            color: Theme.of(dialogContext).colorScheme.surface,
                            child: ListTile(
                            dense: true,
                            tileColor: Theme.of(dialogContext).colorScheme.surface,
                            leading: const Icon(Icons.sync, color: Colors.orange),
                            title: Text(
                              nombre.isEmpty ? '(Sin nombre)' : nombre,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Código: ${_s(cliente['codigo']).isEmpty ? '—' : _s(cliente['codigo'])} · RUC/DNI: ${_s(cliente['ruc']).isEmpty ? '—' : _s(cliente['ruc'])}',
                            ),
                          ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 10),
                  const Text('Al confirmar, los clientes existentes se actualizarán con los campos incluidos en el Excel; los campos que no estén en el archivo se conservarán. Revisa ambas listas antes de continuar.', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton.icon(onPressed: () => Navigator.pop(dialogContext, true), icon: const Icon(Icons.upload), label: const Text('Confirmar importación')),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;

      // Diálogo de progreso persistente: evita que parezca que la aplicación se congeló.
      var progreso = 0;
      var estado = 'Preparando registros...';
      StateSetter? actualizarDialogo;
      final progresoFuture = showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            actualizarDialogo = setDialogState;
            return AlertDialog(
              title: const Text('Importando cartera de clientes'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(estado),
                    const SizedBox(height: 14),
                    LinearProgressIndicator(value: registros.isEmpty ? null : progreso / registros.length),
                    const SizedBox(height: 8),
                    Text('$progreso de ${registros.length} registros procesados'),
                    const SizedBox(height: 4),
                    Text('Nuevos previstos: ${nuevos.length} · Actualizaciones previstas: ${porActualizar.length}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            );
          },
        ),
      );

      setState(() => _procesando = true);
      int actualizados = 0;
      int creados = 0;
      try {
        for (var i = 0; i < registros.length; i++) {
          final registro = registros[i];
          final codigo = _s(registro['codigo']);
          final ruc = _s(registro['ruc']);
          final idExistente = (codigo.isNotEmpty ? idPorCodigo[codigo] : null) ??
              (ruc.isNotEmpty ? idPorRuc[ruc] : null);
          if (idExistente != null) {
            await _db.from('clientes').update(registro).eq('id', idExistente);
            actualizados++;
          } else {
            registro['activo'] ??= true;
            // Devuelve el ID creado para que filas repetidas en el mismo Excel
            // actualicen el registro recién insertado y no intenten duplicarlo.
            final insertado = await _db.from('clientes')
                .insert(registro).select('id,codigo,ruc').single();
            final idNuevo = insertado['id'];
            if (codigo.isNotEmpty) {
              idPorCodigo[codigo] = idNuevo;
              existentesCodigos.add(codigo);
            }
            if (ruc.isNotEmpty) {
              idPorRuc[ruc] = idNuevo;
              existentesRuc.add(ruc);
            }
            creados++;
          }
          progreso = i + 1;
          estado = 'Procesando: ${_s(registro['razon_social']).isNotEmpty ? _s(registro['razon_social']) : _s(registro['nombre'])}';
          // Actualizar el diálogo en intervalos y ceder el hilo para que Windows
          // pueda pintar el progreso mientras siguen las operaciones de red.
          if (progreso % 5 == 0 || progreso == registros.length) {
            actualizarDialogo?.call(() {});
            await Future<void>.delayed(const Duration(milliseconds: 1));
          }
        }
      } finally {
        if (mounted) {
          // Cierra específicamente el diálogo de progreso que abrimos arriba.
          Navigator.of(context, rootNavigator: true).pop();
        }
        await progresoFuture;
      }

      _mensaje('Importación terminada: $creados clientes nuevos y $actualizados actualizados.');
      _pagina = 0;
      await _cargar();
    } catch (e) {
      await cerrarPreparacion();
      _mensaje('Error al importar Excel: $e', error: true);
    } finally {
      await cerrarPreparacion();
      if (mounted) setState(() => _procesando = false);
    }
  }

  bool _b(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final v = value?.toString().trim().toLowerCase() ?? '';
    return v == 'true' || v == '1' || v == 'si' || v == 'sí' || v == 'yes' || v == 'activo';
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

  Widget _topHeader() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF063B63), Color(0xFF0A527F)],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 25),
          const SizedBox(width: 14),
          const Text('ELCOPE',
              style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
          const SizedBox(width: 9),
          const Text('CRM', style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(width: 35),
          Expanded(
            child: Container(
              height: 40,
              constraints: const BoxConstraints(maxWidth: 620),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 15),
                  Icon(Icons.search, color: Colors.white, size: 21),
                  SizedBox(width: 10),
                  Text('Buscar clientes, oportunidades, actividades, facturas, RUC...',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ),
          const Spacer(),
          IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh, color: Colors.white)),
          const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 26),
          const SizedBox(width: 12),
          const CircleAvatar(radius: 19, backgroundColor: Colors.white, child: Text('MR', style: TextStyle(color: _azul, fontWeight: FontWeight.w900))),
          const SizedBox(width: 8),
          const Text('Michael Roque', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _sidebar() {
    final items = [
      (Icons.home_outlined, 'Inicio'),
      (Icons.people_alt_outlined, 'Clientes'),
      (Icons.person_search_outlined, 'Oportunidades'),
      (Icons.checklist_rtl_outlined, 'Actividades'),
      (Icons.receipt_long_outlined, 'Facturación'),
      (Icons.track_changes_outlined, 'Cobranza'),
      (Icons.bar_chart_outlined, 'Reportes'),
      (Icons.percent_outlined, 'Comisiones'),
      (Icons.settings_outlined, 'Configuración'),
    ];
    return Container(
      width: 78,
      color: const Color(0xFF062E4D),
      child: Column(
        children: [
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Tooltip(
                message: item.$2,
                child: Container(
                  width: 66,
                  height: 55,
                  decoration: item.$2 == 'Clientes'
                      ? BoxDecoration(color: const Color(0xFF087BCB), borderRadius: BorderRadius.circular(13))
                      : null,
                  child: Icon(item.$1, color: Colors.white, size: 23),
                ),
              ),
            ),
          const Spacer(),
          const Icon(Icons.logout_rounded, color: Colors.white70),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _pageTitle() {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF0877E6).withValues(alpha: .18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.people_alt_outlined, color: Color(0xFF39A9FF), size: 23),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Clientes', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                SizedBox(height: 1),
                Text('Gestiona tu cartera y realiza seguimiento comercial.',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () {},
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
              minimumSize: const WidgetStatePropertyAll(Size(0, 38)),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nuevo cliente', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          if (_puedeImportarCartera) ...[
            OutlinedButton.icon(
              onPressed: _procesando ? null : _importarExcel,
              style: ButtonStyle(
                foregroundColor: const WidgetStatePropertyAll(Colors.white),
                side: const WidgetStatePropertyAll(BorderSide(color: Color(0xFF4A88B5))),
                padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 13, vertical: 9)),
                minimumSize: const WidgetStatePropertyAll(Size(0, 38)),
              ),
              icon: const Icon(Icons.upload_file_outlined, size: 17),
              label: const Text('Importar Excel', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
          ],
          OutlinedButton.icon(
            onPressed: _procesando ? null : _exportarExcel,
            style: ButtonStyle(
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
              side: const WidgetStatePropertyAll(BorderSide(color: Color(0xFF4A88B5))),
              padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 13, vertical: 9)),
              minimumSize: const WidgetStatePropertyAll(Size(0, 38)),
            ),
            icon: const Icon(Icons.download_outlined, size: 17),
            label: const Text('Exportar Excel', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _filtrosNuevo() {
    String _ultimaCompraLabel(String value) {
      switch (value) {
        case 'TODAS': return 'Todas las compras';
        case 'SIN_VENTAS': return 'Sin ventas';
        case 'CON_VENTAS': return 'Con ventas';
        case '0_30': return 'Compra 0-30 días';
        case '31_60': return 'Compra 31-60 días';
        case '61_90': return 'Compra 61-90 días';
        case 'MAS_30': return 'Sin compra > 30 días';
        case 'MAS_60': return 'Sin compra > 60 días';
        case 'MAS_90': return 'Sin compra > 90 días';
        default: return value;
      }
    }

    Widget field(String label, String value, List<String> options, ValueChanged<String> cb) {
      return SizedBox(
        width: 145,
        height: 54,
        child: DropdownButtonFormField<String>(
          initialValue: options.contains(value) ? value : 'TODOS',
          isExpanded: true,
          iconSize: 18,
          dropdownColor: const Color(0xFF0A3A59),
          menuMaxHeight: 420,
          style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(fontSize: 10, color: Color(0xFF9FB4C8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            filled: true,
            fillColor: const Color(0xFF0A3A59),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFF155B7F))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFF155B7F))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFF35D39A))),
          ),
          items: options.map((v) => DropdownMenuItem<String>(
            value: v,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              color: const Color(0xFF0A3A59),
              child: Text(
                label == 'Última compra' ? _ultimaCompraLabel(v) : v,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          )).toList(),
          onChanged: (v) { if (v != null) cb(v); },
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 7),
      decoration: BoxDecoration(
        color: const Color(0xFF062F4D),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF0B5B88)),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 38,
            child: TextField(
              onSubmitted: (_) => _actualizarFiltro(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar por cliente, RUC, código o vendedor...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9FB4C8)),
                prefixIcon: const Icon(Icons.search, size: 19, color: Color(0xFFB9CAD8)),
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                filled: true,
                fillColor: const Color(0xFF0A3A59),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFF155B7F))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFF35D39A))),
              ),
              onChanged: (v) {
                _busqueda = v;
                _busquedaDebounce?.cancel();
                _busquedaDebounce = Timer(const Duration(milliseconds: 350), () {
                  if (mounted) _actualizarFiltro(() {});
                });
              },
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              field('Vendedor', _vendedor, _vendedoresOpciones, (v) => _actualizarFiltro(() => _vendedor = v)),
              field('Sector', _sector, _opcionesLocales('sector'), (v) => _actualizarFiltro(() => _sector = v)),
              field('Giro', _giro, _opcionesLocales('giro'), (v) => _actualizarFiltro(() => _giro = v)),
              field('Departamento', _departamento, _opcionesLocales('departamento'), (v) => _actualizarFiltro(() => _departamento = v)),
              field('Estado', _estado, const ['TODOS', 'ACTIVO', 'INACTIVO'], (v) => _actualizarFiltro(() { _estado = v; if (v == 'INACTIVO') _soloActivos = false; })),
              field('Última compra', _ultimaCompraFiltro, const ['TODAS', 'SIN_VENTAS', 'CON_VENTAS', '0_30', '31_60', '61_90', 'MAS_30', 'MAS_60', 'MAS_90'], (v) => _actualizarFiltro(() => _ultimaCompraFiltro = v)),
            ],
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 30,
            child: Row(
              children: [
                Switch.adaptive(value: _soloActivos, onChanged: (v) => _actualizarFiltro(() => _soloActivos = v)),
                const Text('Solo clientes activos', style: TextStyle(fontSize: 11.5, color: Colors.white70, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 7), foregroundColor: const Color(0xFF9EDBFF)),
                  onPressed: () {
                    setState(() {
                      _busqueda = '';
                      _vendedor = Sesion.vendedor.trim().isEmpty ? 'TODOS' : Sesion.vendedor.trim();
                      _sector = _giro = _departamento = _estado = 'TODOS';
                      _ultimaCompraFiltro = 'TODAS';
                      _soloActivos = true;
                      _pagina = 0;
                    });
                    _cargar();
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
                  label: const Text('Limpiar filtros', style: TextStyle(fontSize: 11.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String title, String value, IconData icon, Color color, {String? footer}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF062F4D), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF0B5B88))),
      child: Row(
        children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: .18), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color, size: 27)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
            if (footer != null) Text(footer, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ])),
        ],
      ),
    );
  }

  Widget _kpisNuevo() {
    // Los KPI representan TODA la cartera filtrada, no solo los 12/200
    // registros cargados para la tabla.
    final total = int.tryParse(_s(_gestionStats['total'])) ?? 0;
    final activos = int.tryParse(_s(_gestionStats['activos'])) ?? 0;
    final sinContacto = int.tryParse(_s(_gestionStats['sin_contacto'])) ?? 0;
    final sinLlamada = int.tryParse(_s(_gestionStats['sin_llamada'])) ?? 0;
    final sinVisita = int.tryParse(_s(_gestionStats['sin_visita'])) ?? 0;
    final oportunidades = int.tryParse(_s(_gestionStats['con_oportunidad'])) ?? 0;

    final cards = [
      _kpi('Total clientes', '$total', Icons.people_alt_outlined, const Color(0xFF39A9FF)),
      _kpi('Clientes activos', '$activos', Icons.check_circle_outline, const Color(0xFF35D39A)),
      _kpi('Sin contacto', '$sinContacto', Icons.access_time_rounded, const Color(0xFFFFA726)),
      _kpi('Sin llamada', '$sinLlamada', Icons.phone_outlined, const Color(0xFFFF5252)),
      _kpi('Sin visita', '$sinVisita', Icons.calendar_month_outlined, const Color(0xFFB56CFF)),
      _kpi('Con oportunidad', '$oportunidades', Icons.star_outline, const Color(0xFFFFC107)),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 255,
        mainAxisExtent: 92,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: cards.length,
      itemBuilder: (_, i) => cards[i],
    );
  }

  Widget _facturacionMensualPanel() {
    final valores = List<double>.generate(12, (i) => _facturacionMensual[i + 1] ?? 0);
    final total = valores.fold<double>(0, (a, b) => a + b);
    final maximo = valores.fold<double>(0, (a, b) => math.max(a, b));
    const nombres = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];

    return _darkPanel(
      title: 'Facturación por mes - ${DateTime.now().year}',
      icon: Icons.bar_chart_rounded,
      child: SizedBox(
        height: 235,
        child: Row(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  return CustomPaint(
                    painter: _MonthlyBillingPainter(valores: valores, labels: nombres),
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
            Container(
              width: 150,
              margin: const EdgeInsets.only(left: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF05263E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0B5B88)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total del año', style: TextStyle(color: Colors.white60, fontSize: 10)),
                  const SizedBox(height: 4),
                  Text('US\$ ${_money.format(total)}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 18),
                  const Text('Meses con venta', style: TextStyle(color: Colors.white60, fontSize: 10)),
                  const SizedBox(height: 4),
                  Text('${valores.where((v) => v > 0).length}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tablaOLista(bool mobile) {
    final lista = _paginaClientes;
    if (lista.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(35),
        child: Center(child: Text('No hay clientes que coincidan con los filtros.', style: TextStyle(color: Colors.white70))),
      );
    }
    if (mobile) return Column(children: lista.map(_clienteCard).toList());

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: const WidgetStatePropertyAll(Color(0xFF0A4166)),
        dataRowColor: const WidgetStatePropertyAll(Color(0xFF062F4D)),
        headingRowHeight: 36,
        dataRowMinHeight: 38,
        dataRowMaxHeight: 40,
        horizontalMargin: 7,
        columnSpacing: 10,
        dividerThickness: .7,
        columns: const [
          DataColumn(label: Text('Cliente', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800))),
          DataColumn(label: Text('RUC', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800))),
          DataColumn(label: Text('Vendedor', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800))),
          DataColumn(label: Text('Sector', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800))),
          DataColumn(label: Text('Departamento', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800))),
          DataColumn(label: Text('Facturación', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800))),
          DataColumn(label: Text('Días', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800))),
          DataColumn(label: Text('Últ. contacto', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800))),
          DataColumn(label: Text('Estado', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800))),
        ],
        rows: lista.map((c) {
          final fecha = _ultimaCompra(c);
          final dias = fecha == null ? null : DateTime.now().difference(fecha).inDays;
          return DataRow(
            onSelectChanged: (_) => _abrirCliente360(c),
            cells: [
            DataCell(
              SizedBox(
                width: 132,
                child: Tooltip(
                  message: _nombreCliente(c),
                  child: Text(
                    _nombreCliente(c),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ),
            ),
            DataCell(Text(_s(c['ruc']).isEmpty ? '-' : _s(c['ruc']), style: const TextStyle(color: Colors.white70, fontSize: 11.5), overflow: TextOverflow.ellipsis)),
            DataCell(SizedBox(width: 100, child: Text(_s(c['vendedor']), style: const TextStyle(color: Colors.white70, fontSize: 11.5), overflow: TextOverflow.ellipsis))),
            DataCell(SizedBox(width: 90, child: Text(_s(c['sector']), style: const TextStyle(color: Colors.white70, fontSize: 11.5), overflow: TextOverflow.ellipsis))),
            DataCell(SizedBox(width: 78, child: Text(_s(c['departamento']), style: const TextStyle(color: Colors.white70, fontSize: 11.5), overflow: TextOverflow.ellipsis))),
            DataCell(SizedBox(width: 98, child: Text('US\$ ${_money.format(_facturacionCliente(c))}', style: const TextStyle(color: Color(0xFF35D39A), fontWeight: FontWeight.w900, fontSize: 11.5), overflow: TextOverflow.ellipsis))),
            DataCell(SizedBox(width: 62, child: Text(dias == null ? 'Sin compra' : '$dias d', style: TextStyle(color: dias != null && dias > 30 ? const Color(0xFFFFA726) : const Color(0xFF35D39A), fontWeight: FontWeight.w700, fontSize: 11)))),
            DataCell(SizedBox(width: 82, child: Text(fecha == null ? 'Nunca' : DateFormat('dd/MM/yyyy').format(fecha), style: TextStyle(color: fecha == null ? const Color(0xFFFF5252) : Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis))),
            DataCell(_estadoDark(c['activo'] == true)),
          ]);
        }).toList(),
      ),
    );
  }

  void _abrirCliente360(Map<String, dynamic> c) {
    final codigo = _s(c['codigo']).isNotEmpty ? _s(c['codigo']) : _s(c['ruc']);
    if (codigo.isEmpty) {
      _mensaje('Este cliente no tiene código/RUC para abrir Cliente 360°.', error: true);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CrmCliente360Page(codigoInicial: codigo)),
    );
  }

  Widget _clienteCard(Map<String, dynamic> c) {
    final fecha = _ultimaCompra(c);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _abrirCliente360(c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFF062F4D), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF0B5B88))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.business_outlined, color: Color(0xFF24D6A1)),
          const SizedBox(width: 9),
          Expanded(child: Text(_nombreCliente(c), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
          _estadoDark(c['activo'] == true),
        ]),
        const SizedBox(height: 9),
        Text('RUC: ${_s(c['ruc']).isEmpty ? '-' : _s(c['ruc'])}', style: const TextStyle(color: Colors.white70)),
        Text('Vendedor: ${_s(c['vendedor'])}', style: const TextStyle(color: Colors.white70)),
        Text('Facturación: US\$ ${_money.format(_facturacionCliente(c))}', style: const TextStyle(color: Color(0xFF35D39A), fontWeight: FontWeight.w900)),
        Text('Última compra: ${fecha == null ? 'Sin compra' : DateFormat('dd/MM/yyyy').format(fecha)}', style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 9),
        Align(alignment: Alignment.centerRight, child: FilledButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CrmCliente360Page(codigoInicial: _s(c['codigo'])))),
          icon: const Icon(Icons.person_search_outlined), label: const Text('Cliente 360°'),
        )),
      ]),
    ),
    );
  }


  Widget _darkPanel({required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF062F4D),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF0B5B88)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: const Color(0xFF35D39A), size: 22),
              const SizedBox(width: 9),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _paginacionNuevo() {
    final total = _clientesVisibles.length;
    final paginas = total == 0 ? 1 : (total / _porPagina).ceil();
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
      child: Row(children: [
        Text('Página ${_pagina + 1} de $paginas  ·  $total clientes', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const Spacer(),
        IconButton(
          tooltip: 'Anterior',
          onPressed: _pagina == 0 ? null : () => _cambiarPagina(_pagina - 1),
          icon: const Icon(Icons.chevron_left, color: Colors.white),
        ),
        IconButton(
          tooltip: 'Siguiente',
          onPressed: _pagina + 1 >= paginas ? null : () => _cambiarPagina(_pagina + 1),
          icon: const Icon(Icons.chevron_right, color: Colors.white),
        ),
      ]),
    );
  }

  Widget _clientesRecientes() {
    final lista = List<Map<String, dynamic>>.from(_clientes)..sort((a, b) {
      final da = _ultimaCompra(a) ?? DateTime(1900);
      final db = _ultimaCompra(b) ?? DateTime(1900);
      return db.compareTo(da);
    });
    final recientes = lista.take(5).toList();
    return _darkPanel(
      title: 'Clientes recientes',
      icon: Icons.groups_outlined,
      child: Column(
        children: recientes.isEmpty
            ? [const Padding(padding: EdgeInsets.all(12), child: Text('Sin clientes recientes', style: TextStyle(color: Colors.white70)))]
            : recientes.map((c) => Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF0B466B)))),
                child: Row(children: [
                  const Icon(Icons.business_outlined, color: Color(0xFF24D6A1), size: 19),
                  const SizedBox(width: 9),
                  Expanded(child: Text(_nombreCliente(c), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
                  Text(_s(c['ruc']), style: const TextStyle(color: Colors.white54, fontSize: 10)),
                ]),
              )).toList(),
      ),
    );
  }

  Widget _estadoCartera() {
    final total = (int.tryParse(_s(_gestionStats['total'])) ?? _clientes.length).toDouble();
    final activos = (int.tryParse(_s(_gestionStats['activos'])) ??
        _clientes.where((c) => c['activo'] == true).length).toDouble();
    final inactivos = (int.tryParse(_s(_gestionStats['inactivos'])) ??
        math.max(0, total.toInt() - activos.toInt())).toDouble();
    final sinContacto = (int.tryParse(_s(_gestionStats['sin_contacto'])) ?? 0).toDouble();
    final oportunidades = (int.tryParse(_s(_gestionStats['con_oportunidad'])) ?? 0).toDouble();

    Widget leyenda(Color color, String titulo, double cantidad) {
      final pct = total <= 0 ? 0.0 : cantidad / total * 100;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(
            color: color, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: .65), blurRadius: 8, spreadRadius: 1)],
          )),
          const SizedBox(width: 9),
          Expanded(child: Text(titulo, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          Text('${cantidad.toInt()}  ·  ${pct.toStringAsFixed(1)}%',
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
        ]),
      );
    }

    return _darkPanel(
      title: 'Estado de tu cartera',
      icon: Icons.pie_chart_outline,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${total.toInt()} clientes en la cartera filtrada',
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final donut = SizedBox(
              width: 142, height: 142,
              child: Stack(alignment: Alignment.center, children: [
                CustomPaint(size: const Size(142, 142), painter: _DonutPainter(activos, inactivos, 0)),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${total.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
                  const Text('Clientes', style: TextStyle(color: Color(0xFF9FB4C8), fontSize: 11)),
                ]),
              ]),
            );
            final legend = Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              leyenda(const Color(0xFF35FFB0), 'Activos', activos),
              leyenda(const Color(0xFFFF4D6D), 'Inactivos', inactivos),
              leyenda(const Color(0xFFFFD60A), 'Con oportunidad', oportunidades),
              leyenda(const Color(0xFF7DD3FC), 'Sin contacto', sinContacto),
            ]));
            if (constraints.maxWidth < 360) {
              return Column(children: [donut, const SizedBox(height: 10),
                Column(children: [
                  leyenda(const Color(0xFF35FFB0), 'Activos', activos),
                  leyenda(const Color(0xFFFF4D6D), 'Inactivos', inactivos),
                  leyenda(const Color(0xFFFFD60A), 'Con oportunidad', oportunidades),
                  leyenda(const Color(0xFF7DD3FC), 'Sin contacto', sinContacto),
                ])]);
            }
            return Row(children: [donut, const SizedBox(width: 12), legend]);
          }),
          const SizedBox(height: 6),
          const Text('“Con oportunidad” y “Sin contacto” pueden coincidir con clientes activos o inactivos.',
            style: TextStyle(color: Colors.white54, fontSize: 10)),
        ]),
      ),
    );
  }

  Widget _barraEstadoCartera(Color color, String label, double value, double total) {
    final porcentaje = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 7),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11))),
            Text('${value.toInt()}  ·  ${(porcentaje * 100).toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: porcentaje,
              minHeight: 8,
              backgroundColor: const Color(0xFF153F5C),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 900;

    return Scaffold(
      backgroundColor: const Color(0xFF041E33),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : Container(
                  color: const Color(0xFF05263E),
                  child: RefreshIndicator(
                                onRefresh: _cargar,
                                child: SingleChildScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.all(mobile ? 12 : 18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      _pageTitle(),
                                      const SizedBox(height: 10),
                                      _kpisNuevo(),
                                      const SizedBox(height: 12),
                                      LayoutBuilder(
                                        builder: (context, c) => c.maxWidth < 900
                                            ? _facturacionMensualPanel()
                                            : _facturacionMensualPanel(),
                                      ),
                                      const SizedBox(height: 12),
                                      _filtrosNuevo(),
                                      const SizedBox(height: 16),
                                      LayoutBuilder(
                                        builder: (context, c) {
                                          if (c.maxWidth < 1100) {
                                            return Column(children: [
                                              _darkPanel(
                                                title: 'Lista de clientes',
                                                icon: Icons.list_alt_outlined,
                                                child: Column(children: [
                                                  _tablaOLista(true),
                                                  const SizedBox(height: 8),
                                                  _paginacionNuevo(),
                                                ]),
                                              ),
                                              const SizedBox(height: 14),
                                              _clientesRecientes(),
                                              const SizedBox(height: 14),
                                              _estadoCartera(),
                                            ]);
                                          }
                                          return Column(children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  flex: 7,
                                                  child: _darkPanel(
                                                    title: 'Lista de clientes',
                                                    icon: Icons.list_alt_outlined,
                                                    child: Column(children: [
                                                      _tablaOLista(false),
                                                      const SizedBox(height: 8),
                                                      _paginacionNuevo(),
                                                    ]),
                                                  ),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(flex: 3, child: Column(children: [
                                                  _clientesRecientes(),
                                                  const SizedBox(height: 14),
                                                  _estadoCartera(),
                                                ])),
                                              ],
                                            ),
                                          ]);
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
    );
  }
}

class _MonthlyBillingPainter extends CustomPainter {
  final List<double> valores;
  final List<String> labels;

  _MonthlyBillingPainter({required this.valores, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    final left = 38.0;
    final right = 8.0;
    final top = 24.0;
    final bottom = 30.0;
    final chartW = math.max(10, size.width - left - right);
    final chartH = math.max(10, size.height - top - bottom);
    final maxValue = valores.fold<double>(0, (a, b) => math.max(a, b));
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.15;

    final gridPaint = Paint()..color = const Color(0xFF174D70)..strokeWidth = 1;
    final barPaint = Paint()..color = const Color(0xFF1597E5);
    final linePaint = Paint()
      ..color = const Color(0xFF8ED8FF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final pointPaint = Paint()..color = Colors.white;

    for (var i = 0; i <= 4; i++) {
      final y = (top + chartH - chartH * i / 4).toDouble();
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), gridPaint);
      final value = (maxY * i / 4).toDouble();
      final label = value >= 1000000
          ? 'US\$ ${(value / 1000000).toStringAsFixed(1)}M'
          : value >= 1000
              ? 'US\$ ${(value / 1000).toStringAsFixed(0)}K'
              : '0';
      final tp = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: left - 4);
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    final points = <Offset>[];
    final slot = (chartW / 12).toDouble();
    final barW = math.min(28.0, slot * .52).toDouble();
    for (var i = 0; i < 12; i++) {
      final x = left + slot * i + slot / 2;
      final value = valores[i];
      final h = (chartH * value / maxY).toDouble();
      final y = (top + chartH - h).toDouble();
      canvas.drawRect(Rect.fromLTWH(x - barW / 2, y, barW, h), barPaint);
      points.add(Offset(x, y));

      final label = labels[i];
      final tp = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - bottom + 7));

      if (value > 0) {
        final monto = value >= 1000000
            ? 'US\$ ${(value / 1000000).toStringAsFixed(2)} M'
            : value >= 1000
                ? 'US\$ ${(value / 1000).toStringAsFixed(0)} K'
                : 'US\$ ${value.toStringAsFixed(0)}';
        final mt = TextPainter(
          text: TextSpan(text: monto, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
          textDirection: ui.TextDirection.ltr,
        )..layout(maxWidth: slot + 14);
        mt.paint(canvas, Offset(x - mt.width / 2, math.max(1.0, y - mt.height - 2.0)));
      }
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      if (i == 0) {
        path.moveTo(points[i].dx, points[i].dy);
      } else {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }
    canvas.drawPath(path, linePaint);
    for (final p in points) {
      canvas.drawCircle(p, 3.5, pointPaint);
      canvas.drawCircle(p, 2.2, Paint()..color = const Color(0xFF1597E5));
    }
  }

  @override
  bool shouldRepaint(covariant _MonthlyBillingPainter oldDelegate) =>
      oldDelegate.valores != valores;
}

// Debe estar fuera de la clase para que compute pueda ejecutarlo en un isolate.
// Devuelve solo tipos simples, compatibles con el paso de mensajes entre isolates.
List<List<String>> _decodificarFilasExcel(Uint8List bytes) {
  final libro = Excel.decodeBytes(bytes);
  if (libro.tables.isEmpty) return <List<String>>[];
  final hoja = libro.tables[libro.tables.keys.first];
  if (hoja == null) return <List<String>>[];
  return hoja.rows
      .map((fila) => fila
          .map((celda) => celda?.value?.toString().trim() ?? '')
          .toList(growable: false))
      .toList(growable: false);
}

class _DonutPainter extends CustomPainter {
  final double activos;
  final double inactivos;
  final double oportunidades;
  _DonutPainter(this.activos, this.inactivos, this.oportunidades);

  @override
  void paint(Canvas canvas, Size size) {
    final total = activos + inactivos;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .34;
    final stroke = size.shortestSide * .12;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = const Color(0xFF173D56)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, track);
    if (total <= 0) return;
    final values = [activos, inactivos];
    final colors = [const Color(0xFF35FFB0), const Color(0xFFFF4D6D)];
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final sweep = values[i] / total * math.pi * 2;
      final glow = Paint()
        ..color = colors[i].withValues(alpha: .42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
      canvas.drawArc(rect, start, sweep, false, glow);
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.activos != activos || oldDelegate.inactivos != inactivos ||
      oldDelegate.oportunidades != oportunidades;
}
