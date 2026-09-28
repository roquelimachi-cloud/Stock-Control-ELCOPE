import 'dart:typed_data';

import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart' as date_local;

import '../../../services/sesion.dart';
import '../../../services/supabase/supabase_service.dart';

/// Pantalla de consulta de comisión del vendedor.
///
/// Fuente de cálculo:
/// - crm_facturas
/// - crm_factura_detalles
/// - comisiones_productos
/// - RPC crm_obtener_comisiones_resumen
/// - RPC crm_obtener_comisiones_detalle
/// - RPC crm_obtener_reportes
/// - RPC crm_obtener_puntos_comision
///
/// Las tasas NO están hardcodeadas. Se toman de comisiones_productos,
/// que es alimentada mediante el Excel de tasas.
class CrmMiComisionPage extends StatefulWidget {
  const CrmMiComisionPage({super.key});

  @override
  State<CrmMiComisionPage> createState() => _CrmMiComisionPageState();
}

class _CrmMiComisionPageState extends State<CrmMiComisionPage> {
  static const _verde = Color(0xFF087A4A);
  static const _azul = Color(0xFF2457A6);
  static const _fondo = Color(0xFFF4F7FA);

  final _db = SupabaseService.client;
  final _money = NumberFormat('#,##0.00', 'en_US');
  final _percent = NumberFormat('0.00');

  bool _loading = true;
  bool _localeInicializado = false;
  String? _error;

  DateTime _periodo = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int? _puntoId;
  String _puntoNombre = 'CORTE 25';
  int _puntoDiaCorte = 25;

  String _vendedor = '';
  List<String> _vendedores = [];
  List<Map<String, dynamic>> _puntos = [];

  List<Map<String, dynamic>> _detalle = [];
  List<Map<String, dynamic>> _historial = [];

  double _ventasPeriodo = 0;
  double _baseComisionable = 0;
  double _comision = 0;
  double _tasaPromedio = 0;
  int _facturas = 0;
  int _sinTasa = 0;

  int _pagina = 0;
  static const int _filasPagina = 10;

  bool get _esAdministrador =>
      Sesion.esAdministrador ||
      Sesion.rol.trim().toLowerCase() == 'administrador';

  String get _nombreUsuario {
    final nombre = Sesion.nombre.trim();
    if (nombre.isNotEmpty) return nombre;
    return 'Mi comisión';
  }

  DateTime get _desde => DateTime(_periodo.year, _periodo.month, 1);

  DateTime get _hasta {
    final ultimoDia = DateTime(_periodo.year, _periodo.month + 1, 0).day;
    final diaCorte = _puntoDiaCorte.clamp(1, ultimoDia);
    return DateTime(_periodo.year, _periodo.month, diaCorte);
  }

  String get _periodoTexto => DateFormat('MMMM yyyy', 'es').format(_periodo);

  List<Map<String, dynamic>> get _detallePagina {
    final inicio = _pagina * _filasPagina;
    if (inicio >= _detalle.length) return const [];

    final fin = (inicio + _filasPagina).clamp(0, _detalle.length);
    return _detalle.sublist(inicio, fin);
  }

  int get _paginas {
    if (_detalle.isEmpty) return 1;
    return (_detalle.length / _filasPagina).ceil();
  }

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    try {
      await date_local.initializeDateFormatting('es');
      if (mounted) {
        setState(() => _localeInicializado = true);
      }

      await _cargarVendedores();
      await _cargarPuntos();
      await _calcular();
      await _cargarHistorial();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _cargarVendedores() async {
    if (!_esAdministrador) {
      _vendedor = Sesion.vendedor.trim();
      return;
    }

    try {
      final data = await _db
          .from('usuarios')
          .select('vendedor, nombre')
          .eq('activo', true)
          .not('vendedor', 'is', null)
          .order('vendedor');

      final valores = <String>{};
      for (final row in List<Map<String, dynamic>>.from(data)) {
        final vendedor = _s(row['vendedor']);
        if (vendedor.isNotEmpty) valores.add(vendedor);
      }

      final lista = valores.toList()..sort();

      if (lista.isNotEmpty) {
        final actual = Sesion.vendedor.trim();
        _vendedores = lista;
        _vendedor = lista.contains(actual) ? actual : lista.first;
      }
    } catch (_) {
      _vendedor = Sesion.vendedor.trim();
    }
  }

  Future<void> _cargarPuntos() async {
    final result = await _db.rpc('crm_obtener_puntos_comision');
    final lista = List<Map<String, dynamic>>.from(result as List);

    if (!mounted) return;

    setState(() {
      _puntos = lista;
      if (_puntos.isNotEmpty) {
        final seleccionado = _puntos.firstWhere(
          (x) => _s(x['nombre']).toUpperCase() == 'CORTE 25',
          orElse: () => _puntos.first,
        );
        _puntoId = _i(seleccionado['id']);
        _puntoNombre = _s(seleccionado['nombre']).isEmpty
            ? 'CORTE 25'
            : _s(seleccionado['nombre']);
        _puntoDiaCorte = _i(seleccionado['dia_corte']) > 0
            ? _i(seleccionado['dia_corte'])
            : 25;
      }
    });
  }

  Future<void> _calcular() async {
    if (_vendedor.trim().isEmpty) {
      _mostrarError('No se encontró el vendedor asociado al usuario.');
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _pagina = 0;
      });
    }

    try {
      final desde = _dateSql(_desde);
      final hasta = _dateSql(_hasta);

      final resumenResult = await _db.rpc(
        'crm_obtener_comisiones_resumen',
        params: {
          'p_vendedores_permitidos': <String>[_vendedor],
          'p_vendedor': _vendedor,
          'p_desde': desde,
          'p_hasta': hasta,
        },
      );

      final resumen = List<Map<String, dynamic>>.from(
        resumenResult as List,
      );

      double base = 0;
      double comision = 0;
      int facturas = 0;
      int sinTasa = 0;

      if (resumen.isNotEmpty) {
        final row = resumen.first;
        base = _n(row['base_comision']);
        comision = _n(row['comision']);
        facturas = _i(row['facturas']);
        sinTasa = _i(row['sin_tasa']);
      }

      // Facturación total del periodo, independiente de que tenga o no tasa.
      final reporteResult = await _db.rpc(
        'crm_obtener_reportes',
        params: {
          'p_vendedores_permitidos': <String>[_vendedor],
          'p_vendedor': _vendedor,
          'p_desde': desde,
          'p_hasta': hasta,
        },
      );

      final reporte = Map<String, dynamic>.from(
        reporteResult as Map,
      );
      final kpis = Map<String, dynamic>.from(
        reporte['kpis'] as Map? ?? <String, dynamic>{},
      );

      final detalleResult = await _db.rpc(
        'crm_obtener_comisiones_detalle',
        params: {
          'p_vendedores_permitidos': <String>[_vendedor],
          'p_vendedor': _vendedor,
          'p_desde': desde,
          'p_hasta': hasta,
          'p_limit': 1000,
        },
      );

      final detalle = List<Map<String, dynamic>>.from(
        detalleResult as List,
      );

      final tasa = base == 0 ? 0.0 : (comision / base) * 100;

      if (!mounted) return;

      setState(() {
        _ventasPeriodo = _n(kpis['facturacion']);
        _baseComisionable = base;
        _comision = comision;
        _tasaPromedio = tasa;
        _facturas = facturas;
        _sinTasa = sinTasa;
        _detalle = detalle;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _cargarHistorial() async {
    try {
      final data = await _db
          .from('crm_liquidaciones_comision')
          .select(
            'id,punto_id,vendedor,fecha_desde,fecha_hasta,estado,'
            'total_base,total_comision,created_at,'
            'crm_puntos_comision(nombre)',
          )
          .eq('vendedor', _vendedor)
          .order('fecha_hasta', ascending: false)
          .limit(12);

      if (!mounted) return;
      setState(() {
        _historial = List<Map<String, dynamic>>.from(data);
      });
    } catch (_) {
      // El historial es complementario; no bloquea el cálculo.
    }
  }

  Future<void> _seleccionarPeriodo() async {
    final seleccionado = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        DateTime local = _periodo;

        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Seleccionar periodo'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: local.year,
                      decoration: const InputDecoration(
                        labelText: 'Año',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(
                        9,
                        (index) => 2022 + index,
                      )
                          .map(
                            (year) => DropdownMenuItem(
                              value: year,
                              child: Text('$year'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setLocal(() {
                          local = DateTime(value, local.month, 1);
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      value: local.month,
                      decoration: const InputDecoration(
                        labelText: 'Mes',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(
                        12,
                        (index) => index + 1,
                      )
                          .map(
                            (month) => DropdownMenuItem(
                              value: month,
                              child: Text(
                                DateFormat(
                                  'MMMM',
                                  'es',
                                ).format(DateTime(2020, month, 1)),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setLocal(() {
                          local = DateTime(local.year, value, 1);
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, local),
                  child: const Text('Aceptar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (seleccionado == null) return;

    setState(() => _periodo = seleccionado);
    await _calcular();
    await _cargarHistorial();
  }

Future<void> _seleccionarPunto() async {
  final ultimoDia = DateTime(
    _periodo.year,
    _periodo.month + 1,
    0,
  ).day;

  final diaActual = _puntoDiaCorte.clamp(1, ultimoDia);

  final fechaInicial = DateTime(
    _periodo.year,
    _periodo.month,
    diaActual,
  );

  final fecha = await showDialog<DateTime>(
    context: context,
    builder: (dialogContext) {
      return Localizations(
        locale: const Locale('es'),
        delegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        child: Builder(
          builder: (context) {
            return Theme(
              data: Theme.of(this.context),
              child: DatePickerDialog(
                initialDate: fechaInicial,
                firstDate: DateTime(
                  _periodo.year,
                  _periodo.month,
                  1,
                ),
                lastDate: DateTime(
                  _periodo.year,
                  _periodo.month,
                  ultimoDia,
                ),
                helpText: 'Seleccionar fecha de corte',
                cancelText: 'Cancelar',
                confirmText: 'Aceptar',
              ),
            );
          },
        ),
      );
    },
  );

  if (fecha == null) return;

  // Buscar si existe un punto de comisión configurado
  // para el día seleccionado.
  Map<String, dynamic>? puntoCoincidente;

  for (final punto in _puntos) {
    if (_i(punto['dia_corte']) == fecha.day) {
      puntoCoincidente = punto;
      break;
    }
  }

  setState(() {
    _puntoDiaCorte = fecha.day;

    _puntoId = puntoCoincidente == null
        ? null
        : _i(puntoCoincidente['id']);

    _puntoNombre = puntoCoincidente == null
        ? 'CORTE PERSONALIZADO'
        : _s(puntoCoincidente['nombre']).isEmpty
            ? 'CORTE ${fecha.day}'
            : _s(puntoCoincidente['nombre']);
  });

  await _calcular();
  await _cargarHistorial();
}
  Future<void> _exportarExcel() async {
    if (_detalle.isEmpty) {
      _mostrarError('No hay detalle para exportar.');
      return;
    }

    try {
      final workbook = excel.Excel.createExcel();
      final sheet = workbook['Mi Comisión'];

      sheet.appendRow([
        excel.TextCellValue('MI COMISIÓN'),
      ]);
      sheet.appendRow([
        excel.TextCellValue('Vendedor'),
        excel.TextCellValue(_vendedor),
      ]);
      sheet.appendRow([
        excel.TextCellValue('Periodo'),
        excel.TextCellValue(_periodoTexto),
      ]);
      sheet.appendRow([
        excel.TextCellValue('Punto de comisión'),
        excel.TextCellValue(_puntoNombre),
      ]);
      sheet.appendRow([
        excel.TextCellValue('Ventas del periodo'),
        excel.DoubleCellValue(_ventasPeriodo),
      ]);
      sheet.appendRow([
        excel.TextCellValue('Base comisionable'),
        excel.DoubleCellValue(_baseComisionable),
      ]);
      sheet.appendRow([
        excel.TextCellValue('Comisión'),
        excel.DoubleCellValue(_comision),
      ]);
      sheet.appendRow([]);

      sheet.appendRow([
        excel.TextCellValue('Fecha'),
        excel.TextCellValue('Factura'),
        excel.TextCellValue('Cliente'),
        excel.TextCellValue('Producto'),
        excel.TextCellValue('Venta / Base US\$'),
        excel.TextCellValue('% Comisión'),
        excel.TextCellValue('Comisión US\$'),
      ]);

      for (final row in _detalle) {
        sheet.appendRow([
          excel.TextCellValue(_fechaTexto(row['fecha_factura'])),
          excel.TextCellValue(
            '${_s(row['punto_factura'])}-${_s(row['numero_factura'])}',
          ),
          excel.TextCellValue(_s(row['cliente'])),
          excel.TextCellValue(_s(row['articulo'])),
          excel.DoubleCellValue(_n(row['base_comision'])),
          excel.DoubleCellValue(_n(row['porcentaje'])),
          excel.DoubleCellValue(_n(row['monto_comision'])),
        ]);
      }

      sheet.setColumnWidth(0, 15);
      sheet.setColumnWidth(1, 18);
      sheet.setColumnWidth(2, 38);
      sheet.setColumnWidth(3, 48);
      sheet.setColumnWidth(4, 18);
      sheet.setColumnWidth(5, 15);
      sheet.setColumnWidth(6, 18);

      final bytes = workbook.encode();
      if (bytes == null || bytes.isEmpty) {
        throw Exception('No se pudo generar el Excel.');
      }

      final nombre =
          'Mi_Comision_${_vendedor.replaceAll(' ', '_')}_'
          '${DateFormat('yyyyMM').format(_periodo)}.xlsx';

      final ruta = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar comisión en Excel',
        fileName: nombre,
        bytes: Uint8List.fromList(bytes),
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
      );

      if (!mounted || ruta == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Excel de comisión generado correctamente.'),
          backgroundColor: _verde,
        ),
      );
    } catch (e) {
      _mostrarError('No se pudo exportar el Excel: $e');
    }
  }

  Future<void> _generarLiquidacion() async {
    if (_vendedor.trim().isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generar liquidación'),
        content: Text(
          'Se generará la liquidación de $_periodoTexto para '
          '$_vendedor con fecha de corte ${DateFormat('dd/MM/yyyy').format(_hasta)}.\n\n'
          'Base comisionable: US\$ ${_money.format(_baseComisionable)}\n'
          'Comisión: US\$ ${_money.format(_comision)}',
        ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.check),
          label: const Text('Generar'),
        ),
      ],
    ),
    );

    if (confirmar != true) return;

    try {
      final inserted = await _db
          .from('crm_liquidaciones_comision')
          .insert({
            'punto_id': _puntoId,
            'vendedor': _vendedor,
            'fecha_desde': _dateSql(_desde),
            'fecha_hasta': _dateSql(_hasta),
            'estado': 'BORRADOR',
            'total_base': _baseComisionable,
            'total_comision': _comision,
            'usuario_id': Sesion.idUsuario,
          })
          .select('id')
          .single();

      final liquidacionId = _i(inserted['id']);

      if (liquidacionId > 0 && _detalle.isNotEmpty) {
        final detalles = _detalle.map((row) {
          return {
            'liquidacion_id': liquidacionId,
            'factura_id': _i(row['factura_id']),
            'factura_detalle_id': null,
            'codigo_articulo': _s(row['codigo_articulo']),
            'articulo': _s(row['articulo']),
            'codigo_cliente': _s(row['codigo_cliente']),
            'cliente': _s(row['cliente']),
            'fecha_factura': _s(row['fecha_factura']),
            'base_comision': _n(row['base_comision']),
            'porcentaje': _n(row['porcentaje']),
            'monto_comision': _n(row['monto_comision']),
          };
        }).toList();

        await _db
            .from('crm_liquidacion_comision_detalles')
            .insert(detalles);
      }

      await _cargarHistorial();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Liquidación generada en estado BORRADOR.'),
          backgroundColor: _verde,
        ),
      );
    } catch (e) {
      _mostrarError('No se pudo generar la liquidación: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _verde,
        foregroundColor: Colors.white,
        title: const Text(
          'Mi Comisión',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: _loading ? null : _exportarExcel,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
            ),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Exportar Excel'),
          ),
          const SizedBox(width: 10),
          if (_esAdministrador)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _loading ? null : _generarLiquidacion,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _verde,
                ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Generar liquidación'),
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 900;

          if (!_localeInicializado) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await _calcular();
              await _cargarHistorial();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _filtros(mobile),
                  const SizedBox(height: 16),
                  if (_error != null) _errorCard(),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    _kpis(mobile),
                    const SizedBox(height: 16),
                    _detalleCard(mobile),
                    const SizedBox(height: 16),
                    _inferior(mobile),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _filtros(bool mobile) {
    final contenido = [
      _selectorBox(
        label: 'Vendedor',
        icon: Icons.person_outline,
        child: _esAdministrador
            ? DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _vendedores.contains(_vendedor) ? _vendedor : null,
                  items: _vendedores
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(
                            v,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    if (value == null) return;
                    setState(() => _vendedor = value);
                    await _calcular();
                    await _cargarHistorial();
                  },
                ),
              )
            : Text(
                _vendedor.isEmpty ? _nombreUsuario : _vendedor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
      ),
      _selectorBox(
        label: 'Periodo',
        icon: Icons.calendar_month_outlined,
        child: InkWell(
          onTap: _seleccionarPeriodo,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _capitalizar(_periodoTexto),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down),
            ],
          ),
        ),
      ),
      _selectorBox(
        label: 'Fecha de corte',
        icon: Icons.event_available_outlined,
        child: InkWell(
          onTap: _seleccionarPunto,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('dd/MM/yyyy').format(_hasta),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.calendar_today_outlined, size: 18),
            ],
          ),
        ),
      ),
      SizedBox(
        height: 68,
        child: FilledButton.icon(
          onPressed: _loading ? null : _calcular,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1E73D8),
          ),
          icon: const Icon(Icons.calculate_outlined),
          label: const Text(
            'Calcular comisión',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ];

    if (mobile) {
      return Column(
        children: [
          for (final item in contenido) ...[
            item,
            const SizedBox(height: 10),
          ],
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE4EC)),
      ),
      child: Row(
        children: [
          Expanded(child: contenido[0]),
          const SizedBox(width: 12),
          Expanded(child: contenido[1]),
          const SizedBox(width: 12),
          Expanded(child: contenido[2]),
          const SizedBox(width: 12),
          Expanded(child: contenido[3]),
        ],
      ),
    );
  }

  Widget _selectorBox({
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD1D8E0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _azul, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _azul,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF202833),
                  ),
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpis(bool mobile) {
    final cards = [
      _kpi(
        icon: Icons.bar_chart_outlined,
        title: 'Ventas del periodo',
        value: 'US\$ ${_money.format(_ventasPeriodo)}',
        color: const Color(0xFF2468D8),
        subtitle: '$_facturas facturas',
      ),
      _kpi(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Base comisionable',
        value: 'US\$ ${_money.format(_baseComisionable)}',
        color: _verde,
        subtitle: _sinTasa == 0
            ? 'Todas las líneas tienen tasa'
            : '$_sinTasa líneas sin tasa',
      ),
      _kpi(
        icon: Icons.percent,
        title: '% Comisión promedio',
        value: '${_percent.format(_tasaPromedio)}%',
        color: const Color(0xFFE97800),
        subtitle: 'Calculado sobre base',
      ),
      _kpi(
        icon: Icons.payments_outlined,
        title: 'Comisión estimada',
        value: 'US\$ ${_money.format(_comision)}',
        color: const Color(0xFF7B36C8),
        subtitle: 'Periodo seleccionado',
      ),
    ];

    if (mobile) {
      return Column(
        children: [
          for (final card in cards) ...[
            card,
            const SizedBox(height: 10),
          ],
        ],
      );
    }

    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i < cards.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }

  Widget _kpi({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E6EC)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 29),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF59636E),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF7A8490),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detalleCard(bool mobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E6EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  color: _azul,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Detalle de facturas del periodo',
                    style: TextStyle(
                      color: _azul,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '$_facturas facturas',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_detalle.isEmpty)
            const Padding(
              padding: EdgeInsets.all(45),
              child: Center(
                child: Text(
                  'No hay facturas para el periodo seleccionado.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            SizedBox(
              height: mobile ? 480 : 500,
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: const WidgetStatePropertyAll(
                        Color(0xFFF0F4FA),
                      ),
                      columns: const [
                        DataColumn(label: Text('Fecha')),
                        DataColumn(label: Text('Factura')),
                        DataColumn(label: Text('Cliente')),
                        DataColumn(label: Text('Producto')),
                        DataColumn(label: Text('Venta / Base (US\$)')),
                        DataColumn(label: Text('% Comisión')),
                        DataColumn(label: Text('Comisión (US\$)')),
                      ],
                      rows: _detallePagina.map((row) {
                        final porcentaje = _n(row['porcentaje']);
                        final comision = _n(row['monto_comision']);

                        return DataRow(
                          cells: [
                            DataCell(
                              Text(_fechaTexto(row['fecha_factura'])),
                            ),
                            DataCell(
                              Text(
                                '${_s(row['punto_factura'])}-'
                                '${_s(row['numero_factura'])}',
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 230,
                                child: Text(
                                  _s(row['cliente']),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 300,
                                child: Text(
                                  _s(row['articulo']),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _money.format(
                                  _n(row['base_comision']),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${_percent.format(porcentaje)}%',
                              ),
                            ),
                            DataCell(
                              Text(
                                _money.format(comision),
                                style: const TextStyle(
                                  color: _verde,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          if (_detalle.isNotEmpty) _paginacion(),
        ],
      ),
    );
  }

  Widget _paginacion() {
    final desde = _pagina * _filasPagina + 1;
    final hasta = ((_pagina + 1) * _filasPagina).clamp(
      0,
      _detalle.length,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Mostrando $desde-$hasta de ${_detalle.length}',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _pagina == 0
                ? null
                : () => setState(() => _pagina--),
            icon: const Icon(Icons.chevron_left),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1E73D8),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${_pagina + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: _pagina + 1 >= _paginas
                ? null
                : () => setState(() => _pagina++),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _inferior(bool mobile) {
    final resumen = _resumenCard();
    final historial = _historialCard();

    if (mobile) {
      return Column(
        children: [
          resumen,
          const SizedBox(height: 14),
          historial,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: resumen),
        const SizedBox(width: 14),
        Expanded(child: historial),
      ],
    );
  }

  Widget _resumenCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E6EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.summarize_outlined, color: _azul),
              SizedBox(width: 9),
              Text(
                'Resumen de comisión del periodo',
                style: TextStyle(
                  color: _azul,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _lineaResumen(
            'Periodo de comisión',
            '${DateFormat('dd/MM/yyyy').format(_desde)} - '
            '${DateFormat('dd/MM/yyyy').format(_hasta)}',
          ),
          _lineaResumen(
            'Total ventas del periodo',
            'US\$ ${_money.format(_ventasPeriodo)}',
          ),
          _lineaResumen(
            'Total base comisionable',
            'US\$ ${_money.format(_baseComisionable)}',
          ),
          _lineaResumen(
            'Comisión generada (${_percent.format(_tasaPromedio)}%)',
            'US\$ ${_money.format(_comision)}',
          ),
          _lineaResumen(
            'Líneas sin tasa',
            '$_sinTasa',
            valueColor: _sinTasa == 0 ? _verde : Colors.orange,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F7ED),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Comisión del periodo',
                    style: TextStyle(
                      color: _verde,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  'US\$ ${_money.format(_comision)}',
                  style: const TextStyle(
                    color: _verde,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineaResumen(
    String label,
    String value, {
    Color valueColor = const Color(0xFF343B45),
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _historialCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E6EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, color: _azul),
              SizedBox(width: 9),
              Text(
                'Historial de liquidaciones',
                style: TextStyle(
                  color: _azul,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_historial.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Todavía no hay liquidaciones registradas.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Periodo')),
                  DataColumn(label: Text('Punto')),
                  DataColumn(label: Text('Base US\$')),
                  DataColumn(label: Text('Comisión US\$')),
                  DataColumn(label: Text('Estado')),
                ],
                rows: _historial.map((row) {
                  final punto = row['crm_puntos_comision'];
                  final puntoMap = punto is Map
                      ? Map<String, dynamic>.from(punto)
                      : <String, dynamic>{};

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          '${_fechaTexto(row['fecha_desde'])} - '
                          '${_fechaTexto(row['fecha_hasta'])}',
                        ),
                      ),
                      DataCell(
                        Text(
                          _s(puntoMap['nombre']).isEmpty
                              ? '—'
                              : _s(puntoMap['nombre']),
                        ),
                      ),
                      DataCell(
                        Text(
                          _money.format(_n(row['total_base'])),
                        ),
                      ),
                      DataCell(
                        Text(
                          _money.format(_n(row['total_comision'])),
                        ),
                      ),
                      DataCell(
                        _estadoChip(_s(row['estado'])),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _estadoChip(String estado) {
    final value = estado.isEmpty ? 'BORRADOR' : estado.toUpperCase();

    Color background;
    Color foreground;

    switch (value) {
      case 'PAGADA':
        background = const Color(0xFFDDF5E9);
        foreground = const Color(0xFF087A4A);
        break;
      case 'CALCULADA':
        background = const Color(0xFFDCEBFF);
        foreground = const Color(0xFF2468D8);
        break;
      case 'ANULADA':
        background = const Color(0xFFFFE2E2);
        foreground = Colors.red.shade700;
        break;
      default:
        background = const Color(0xFFFFF0C7);
        foreground = const Color(0xFF9A6800);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _errorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECEC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFC7C7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(child: Text(_error!)),
          IconButton(
            onPressed: () => setState(() => _error = null),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  String _s(dynamic value) => value?.toString().trim() ?? '';

  double _n(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
          _s(value).replaceAll(',', ''),
        ) ??
        0;
  }

  int _i(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(_s(value)) ?? 0;
  }

  String _dateSql(DateTime value) {
    return DateFormat('yyyy-MM-dd').format(value);
  }

  String _fechaTexto(dynamic value) {
    final raw = _s(value);
    if (raw.isEmpty) return '—';

    final date = DateTime.tryParse(raw);
    if (date == null) return raw;

    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _capitalizar(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  void _mostrarError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }
}
