import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
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
  String _vendedor = 'TODOS';
  String _sector = 'TODOS';
  String _giro = 'TODOS';
  String _departamento = 'TODOS';
  String _anio = 'TODOS';
  bool _soloActivos = true;

  int _pagina = 0;
  static const int _porPagina = 50;
  bool _haySiguiente = false;
  String _orden = 'FACTURACION_DESC';
  double _facturacionTotal = 0;
  double _pesoTotal = 0;
  int _totalClientes = 0;
  int _conFacturacion = 0;

  @override
  void initState() {
    super.initState();
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

  Future<List<String>?> _vendedoresPermitidos() async {
    final rol = Sesion.rol.trim();
    final vendedorSesion = Sesion.vendedor.trim();

    // Gerencia puede consultar todo.
    if (rol.toLowerCase() == 'gerencia') {
      return null;
    }

    // Jefaturas: solo vendedores autorizados en usuario_permisos.
    if (rol == 'Jefe Lima' || rol == 'Jefe Provincia') {
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
      final result = await _db.rpc(
        'crm_obtener_clientes_pagina_v6',
        params: {
          'p_busqueda': _busqueda.trim(),
          'p_vendedor': _vendedor,
          'p_vendedores_permitidos': vendedoresPermitidos,
          'p_sector': _sector,
          'p_giro': _giro,
          'p_departamento': _departamento,
          'p_solo_activos': _soloActivos,
          'p_limit': _porPagina,
          'p_offset': _pagina * _porPagina,
          'p_orden': _orden,
          'p_anio': _anio == 'TODOS' ? null : int.tryParse(_anio),
        },
      );

      final clientes = List<Map<String, dynamic>>.from(result as List);

      final stats = await _db.rpc(
        'crm_obtener_clientes_estadisticas_v6',
        params: {
          'p_busqueda': _busqueda.trim(),
          'p_vendedor': _vendedor,
          'p_vendedores_permitidos': vendedoresPermitidos,
          'p_sector': _sector,
          'p_giro': _giro,
          'p_departamento': _departamento,
          'p_solo_activos': _soloActivos,
          'p_anio': _anio == 'TODOS' ? null : int.tryParse(_anio),
        },
      );

      final stat = (stats as List).isNotEmpty
          ? Map<String, dynamic>.from((stats as List).first)
          : <String, dynamic>{};

      if (!mounted) return;

      setState(() {
        _clientes = clientes;
        _facturacionTotal = _n(stat['total_facturacion']);
        _pesoTotal = _n(stat['total_peso_kg']);
        _totalClientes = int.tryParse(
              stat['total_registros']?.toString() ?? '',
            ) ??
            0;
        _conFacturacion = int.tryParse(
              stat['total_con_facturacion']?.toString() ?? '',
            ) ??
            0;
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
          if (fecha != null) {
            _ultimaCompraPorCliente[key] = fecha;
          }
        }

        _haySiguiente = (_pagina + 1) * _porPagina < _totalClientes;
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
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      Uint8List? bytes = file.bytes;

      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null) {
        _mensaje('No se pudo leer el archivo Excel.', error: true);
        return;
      }

      final excel = Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) {
        _mensaje('El Excel no contiene hojas.', error: true);
        return;
      }

      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null || sheet.maxRows < 2) {
        _mensaje('El Excel no contiene registros.', error: true);
        return;
      }

      final headers = sheet.rows.first.map((cell) {
        return _normalizar(cell?.value?.toString() ?? '');
      }).toList();

      int col(String name) => headers.indexOf(_normalizar(name));

      final cCodigo = col('codigo');
      final cRuc = col('ruc');
      final cNombre = col('nombre');
      final cRazon = col('razon_social');
      final cDireccion = col('direccion');
      final cLocalidad = col('localidad');
      final cDepartamento = col('departamento');
      final cCanal = col('canal');
      final cGiro = col('giro');
      final cSector = col('sector');
      final cCodigoVendedor = col('codigo_vendedor');
      final cVendedor = col('vendedor');
      final cActivo = col('activo');

      if (cCodigo < 0 && cRuc < 0) {
        _mensaje(
          'El Excel debe contener por lo menos la columna CODIGO o RUC.',
          error: true,
        );
        return;
      }

      final registros = <Map<String, dynamic>>[];

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];

        String cell(int index) {
          if (index < 0 || index >= row.length) return '';
          return row[index]?.value?.toString().trim() ?? '';
        }

        final codigo = cell(cCodigo);
        final ruc = cell(cRuc);
        final razon = cell(cRazon);
        final nombre = cell(cNombre);

        if (codigo.isEmpty && ruc.isEmpty) continue;
        if (razon.isEmpty && nombre.isEmpty) continue;

        registros.add({
          if (codigo.isNotEmpty) 'codigo': codigo,
          if (ruc.isNotEmpty) 'ruc': ruc,
          if (nombre.isNotEmpty) 'nombre': nombre,
          if (razon.isNotEmpty) 'razon_social': razon,
          if (cell(cDireccion).isNotEmpty) 'direccion': cell(cDireccion),
          if (cell(cLocalidad).isNotEmpty) 'localidad': cell(cLocalidad),
          if (cell(cDepartamento).isNotEmpty)
            'departamento': cell(cDepartamento),
          if (cell(cCanal).isNotEmpty) 'canal': cell(cCanal),
          if (cell(cGiro).isNotEmpty) 'giro': cell(cGiro),
          if (cell(cSector).isNotEmpty) 'sector': cell(cSector),
          if (cell(cCodigoVendedor).isNotEmpty)
            'codigo_vendedor': cell(cCodigoVendedor),
          if (cell(cVendedor).isNotEmpty) 'vendedor': cell(cVendedor),
          if (cell(cActivo).isNotEmpty)
            'activo': _textoBooleano(cell(cActivo)),
        });
      }

      if (registros.isEmpty) {
        _mensaje('No se encontraron clientes válidos.', error: true);
        return;
      }

      if (!mounted) return;

      final confirmar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Importar clientes'),
          content: Text(
            'Se encontraron ${registros.length} registros.\n\n'
            'Los registros con CODIGO o RUC existente se actualizarán. '
            'Los nuevos se crearán.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Importar'),
            ),
          ],
        ),
      );

      if (confirmar != true) return;

      setState(() => _procesando = true);

      int actualizados = 0;
      int creados = 0;

      for (final registro in registros) {
        dynamic existente;

        if (_s(registro['codigo']).isNotEmpty) {
          existente = await _db
              .from('clientes')
              .select('id')
              .eq('codigo', registro['codigo'])
              .maybeSingle();
        }

        if (existente == null && _s(registro['ruc']).isNotEmpty) {
          existente = await _db
              .from('clientes')
              .select('id')
              .eq('ruc', registro['ruc'])
              .maybeSingle();
        }

        if (existente != null) {
          await _db
              .from('clientes')
              .update(registro)
              .eq('id', existente['id']);
          actualizados++;
        } else {
          registro['activo'] ??= true;
          await _db.from('clientes').insert(registro);
          creados++;
        }
      }

      _mensaje(
        'Importación terminada: $creados creados y $actualizados actualizados.',
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(mobile ? 18 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_azul, _azulClaro],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.people_alt_outlined,
            color: Colors.white,
            size: 38,
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestión de Clientes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Clientes existentes en ELCOPE, conectados con su facturación.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filtros(bool mobile) {
    final campos = [
      _filtro(
        'Vendedor',
        _vendedor,
        _opcionesLocales('vendedor'),
        (v) {
          setState(() {
            _vendedor = v;
            _pagina = 0;
          });
          _cargar();
        },
      ),
      _filtro(
        'Sector',
        _sector,
        _opcionesLocales('sector'),
        (v) {
          setState(() {
            _sector = v;
            _pagina = 0;
          });
          _cargar();
        },
      ),
      _filtro(
        'Giro',
        _giro,
        _opcionesLocales('giro'),
        (v) {
          setState(() {
            _giro = v;
            _pagina = 0;
          });
          _cargar();
        },
      ),
      _filtro(
        'Departamento',
        _departamento,
        _opcionesLocales('departamento'),
        (v) {
          setState(() {
            _departamento = v;
            _pagina = 0;
          });
          _cargar();
        },
      ),
      _filtro(
        'Año facturación',
        _anio,
        const ['TODOS', '2026', '2025', '2024', '2023'],
        (v) {
          setState(() {
            _anio = v;
            _pagina = 0;
          });
          _cargar();
        },
      ),
      _filtro(
        'Ordenar resultados',
        _orden,
        _ordenes,
        (v) {
          setState(() {
            _orden = v;
            _pagina = 0;
          });
          _cargar();
        },
        labels: true,
      ),
    ];

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _borde),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              onChanged: (v) {
                _busqueda = v;
              },
              onSubmitted: (_) {
                setState(() => _pagina = 0);
                _cargar();
              },
              decoration: InputDecoration(
                hintText: 'Buscar por cliente, RUC, código o vendedor',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busqueda.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          setState(() {
                            _busqueda = '';
                            _pagina = 0;
                          });
                          _cargar();
                        },
                        icon: const Icon(Icons.clear),
                      ),
                filled: true,
                fillColor: _fondo,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (mobile)
              Column(
                children: [
                  for (final f in campos) ...[
                    f,
                    const SizedBox(height: 8),
                  ],
                ],
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: campos,
              ),
            Row(
              children: [
                Switch(
                  value: _soloActivos,
                  onChanged: (v) {
                    setState(() {
                      _soloActivos = v;
                      _pagina = 0;
                    });
                    _cargar();
                  },
                ),
                const Text(
                  'Solo clientes activos',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _busqueda = '';
                      _vendedor = 'TODOS';
                      _sector = 'TODOS';
                      _giro = 'TODOS';
                      _departamento = 'TODOS';
                      _anio = 'TODOS';
                      _orden = 'FACTURACION_DESC';
                      _soloActivos = true;
                      _pagina = 0;
                    });
                    _cargar();
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Limpiar'),
                ),
              ],
            ),
          ],
        ),
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
                  labels ? _ordenLabel(v) : v,
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
    final botones = [
      OutlinedButton.icon(
        onPressed: _procesando ? null : _importarExcel,
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Importar Excel'),
      ),
      OutlinedButton.icon(
        onPressed: _procesando ? null : _exportarExcel,
        icon: const Icon(Icons.download_outlined),
        label: const Text('Exportar Excel'),
      ),
      FilledButton.icon(
        onPressed: _procesando ? null : _imprimir,
        icon: const Icon(Icons.print_outlined),
        label: const Text('Imprimir'),
      ),
    ];

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _borde),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: mobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final b in botones) ...[
                    b,
                    const SizedBox(height: 8),
                  ],
                ],
              )
            : Wrap(
                spacing: 10,
                runSpacing: 10,
                children: botones,
              ),
      ),
    );
  }

  Widget _resumen(bool mobile) {
    final cards = [
      _miniKpi(
        'Clientes',
        '$_totalClientes',
        Icons.people_alt_outlined,
      ),
      _miniKpi(
        'Con facturación',
        '$_conFacturacion',
        Icons.receipt_long_outlined,
        color: _verde,
      ),
      _miniKpi(
        'Facturación (USD)',
        'US\$ ${_money.format(_facturacionTotal)}',
        Icons.attach_money,
        color: _azulClaro,
      ),
      _miniKpi(
        'Peso',
        '${_money.format(_pesoTotal)} kg',
        Icons.scale_outlined,
        color: _verde,
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 1100
            ? 4
            : c.maxWidth >= 700
                ? 2
                : 1;

        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: mobile ? 4.2 : 3.5,
          children: cards,
        );
      },
    );
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

  Widget _tablaOLista(bool mobile) {
    final lista = _filtrados;

    if (lista.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Text(
              'No hay clientes que coincidan con los filtros.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }

    if (mobile) {
      return Column(
        children: lista.map(_clienteCard).toList(),
      );
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
          headingRowColor:
              const WidgetStatePropertyAll(Color(0xFFF2F6FA)),
          columns: const [
            DataColumn(label: Text('Cliente')),
            DataColumn(label: Text('RUC')),
            DataColumn(label: Text('Vendedor')),
            DataColumn(label: Text('Sector')),
            DataColumn(label: Text('Departamento')),
            DataColumn(label: Text('Facturación')),
            DataColumn(label: Text('Peso (kg)')),
            DataColumn(label: Text('Última compra')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('')),
          ],
          rows: lista.map(_fila).toList(),
        ),
      ),
    );
  }

  DataRow _fila(Map<String, dynamic> c) {
    final fecha = _ultimaCompra(c);

    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 260,
            child: Text(
              _nombreCliente(c),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        DataCell(Text(_s(c['ruc']).isEmpty ? '-' : _s(c['ruc']))),
        DataCell(
          Text(
            _s(c['vendedor']).isEmpty ? '-' : _s(c['vendedor']),
          ),
        ),
        DataCell(
          Text(_s(c['sector']).isEmpty ? '-' : _s(c['sector'])),
        ),
        DataCell(
          Text(
            _s(c['departamento']).isEmpty
                ? '-'
                : _s(c['departamento']),
          ),
        ),
        DataCell(
          Text(
            'US\$ ${_money.format(_facturacionCliente(c))}',
            style: const TextStyle(
              color: _verde,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        DataCell(
          Text('${_money.format(_pesoCliente(c))} kg'),
        ),
        DataCell(
          Text(
            fecha == null
                ? 'Sin compra registrada'
                : DateFormat('dd/MM/yyyy').format(fecha),
          ),
        ),
        DataCell(_estado(c['activo'] == true)),
        DataCell(
          IconButton(
            tooltip: 'Ver Cliente 360°',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CrmCliente360Page(codigoInicial: _s(c['codigo'])),
              ),
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ),
      ],
    );
  }

  Widget _clienteCard(Map<String, dynamic> c) {
    final fecha = _ultimaCompra(c);

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
                const CircleAvatar(
                  backgroundColor: Color(0xFFEAF2F8),
                  child: Icon(
                    Icons.business_outlined,
                    color: _azul,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _nombreCliente(c),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _estado(c['activo'] == true),
              ],
            ),
            const SizedBox(height: 12),
            Text('RUC: ${_s(c['ruc']).isEmpty ? '-' : _s(c['ruc'])}'),
            Text('Vendedor: ${_s(c['vendedor']).isEmpty ? '-' : _s(c['vendedor'])}'),
            Text('Sector: ${_s(c['sector']).isEmpty ? '-' : _s(c['sector'])}'),
            Text(
              'Facturación: US\$ ${_money.format(_facturacionCliente(c))}',
              style: const TextStyle(
                color: _verde,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Peso: ${_money.format(_pesoCliente(c))} kg',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'Última compra: ${fecha == null ? 'Sin compra registrada' : DateFormat('dd/MM/yyyy').format(fecha)}',
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CrmCliente360Page(codigoInicial: _s(c['codigo'])),
                  ),
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

    return Scaffold(
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
                        padding: EdgeInsets.all(mobile ? 12 : 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _encabezado(mobile),
                            const SizedBox(height: 14),
                            _filtros(mobile),
                            const SizedBox(height: 14),
                            _acciones(mobile),
                            const SizedBox(height: 14),
                            _resumen(mobile),
                            const SizedBox(height: 14),
                            _tablaOLista(mobile),
                            const SizedBox(height: 12),
                            _paginacion(),
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
    );
  }
}
