import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:excel/excel.dart' as xl;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../services/supabase/supabase_service.dart';
import '../../../services/sesion.dart';
import '../../../services/supabase/crm_cliente360_service.dart';

class CrmCliente360Page extends StatefulWidget {
  const CrmCliente360Page({super.key, this.codigoInicial, this.onAbrirActividades});

  final String? codigoInicial;
  final ValueChanged<String>? onAbrirActividades;

  @override
  State<CrmCliente360Page> createState() => _CrmCliente360PageState();
}

class _CrmCliente360PageState extends State<CrmCliente360Page> {
  static const _azul = Color(0xFF0B3B63);
  static const _azulClaro = Color(0xFF1468A8);
  static const _verde = Color(0xFF0A9B61);
  static const _fondo = Color(0xFFF4F7FA);
  static const _borde = Color(0xFFE1E7EC);

  final _db = SupabaseService.client;
  final _cliente360 = CrmCliente360Service();
  final _money = NumberFormat('#,##0.00', 'en_US');
  final _date = DateFormat('dd/MM/yyyy');
  final _search = TextEditingController();

  bool _loading = true;
  bool _loadingDetail = false;
  String? _error;
  String _departamento = 'TODOS';
  int? _anio;
  int _tabActivo = 0;
  List<String>? _vendedoresPermitidos;
  List<Map<String, dynamic>> _resultados = [];
  Map<String, dynamic>? _cliente;
  List<Map<String, dynamic>> _facturas = [];
  List<Map<String, dynamic>> _productos = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _s(dynamic v) => v?.toString().trim() ?? '';

  double _n(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(_s(v).replaceAll(',', '')) ?? 0;
  }

  DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(_s(v));

  List<String> _stringList(dynamic value) {
    if (value is! List) return <String>[];
    return value.map((item) => item?.toString() ?? '').where((item) => item.isNotEmpty).toList();
  }

  bool get _esGerencia => Sesion.rol.trim().toLowerCase() == 'gerencia';
  bool get _esJefeLima => Sesion.rol.trim().toLowerCase() == 'jefe lima';
  bool get _esJefatura => _esJefeLima || Sesion.rol.trim().toLowerCase() == 'jefe provincia';

  Future<List<String>?> _permisosVendedor() async {
    // La autorización real se valida en la Edge Function con el usuario autenticado.
    if (_esGerencia) return null;
    final vendedor = Sesion.vendedor.trim();
    return vendedor.isEmpty ? <String>[] : <String>[vendedor];
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _vendedoresPermitidos = await _permisosVendedor();
      _departamento = _esJefeLima ? 'LIMA' : 'TODOS';
      final codigo = _s(widget.codigoInicial);
      if (codigo.isNotEmpty) {
        _search.text = codigo;
        await _buscarClientes(codigo, seleccionarPrimero: true);
      } else {
        await _buscarClientes('', seleccionarPrimero: false);
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _buscarClientes(String texto, {bool seleccionarPrimero = false}) async {
    try {
      final rows = await _cliente360.buscarClientes(
        busqueda: texto.trim(),
        limit: 25,
        departamento: _esJefeLima ? 'LIMA' : _departamento,
        anio: _anio,
      );
      if (!mounted) return;
      setState(() {
        _resultados = rows;
        _error = null;
      });
      if (seleccionarPrimero && rows.isNotEmpty) {
        await _seleccionar(rows.first);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resultados = [];
        _error = e.toString();
      });
      rethrow;
    }
  }

  Future<void> _seleccionar(Map<String, dynamic> row) async {
    final codigo = _s(row['codigo']).isNotEmpty ? _s(row['codigo']) : _s(row['ruc']);
    if (codigo.isEmpty) return;
    setState(() {
      _loadingDetail = true;
      _error = null;
      _cliente = null;
      _facturas = [];
      _productos = [];
    });
    try {
      final payload = await _cliente360.obtenerDetalle(
        codigo: codigo,
        anio: _anio,
        departamento: _esJefeLima ? 'LIMA' : _departamento,
      );
      if (payload['error'] != null) {
        throw Exception('${payload['error']} ${payload['details'] ?? ''}'.trim());
      }
      final clienteRaw = payload['cliente'];
      if (clienteRaw is! Map) {
        throw Exception('La respuesta segura no contiene la ficha del cliente.');
      }
      final cliente = Map<String, dynamic>.from(clienteRaw);
      final facturasRaw = payload['facturas'];
      final productosRaw = payload['productos'];
      final facturas = facturasRaw is List
          ? facturasRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      final productos = productosRaw is List
          ? productosRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _cliente = {
          ...cliente,
          'codigo_cliente': _s(cliente['codigo_cliente']).isNotEmpty
              ? cliente['codigo_cliente']
              : cliente['codigo'],
        };
        _facturas = facturas;
        _productos = productos;
        _loadingDetail = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDetail = false;
        _error = e.toString();
      });
    }
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borde),
        ),
        child: child,
      );

  Widget _kpi(String title, String value, IconData icon, Color color) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: _borde),
          ),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: color.withValues(alpha: .11), shape: BoxShape.circle),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              FittedBox(alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _azul))),
            ])),
          ]),
        );

  String _moneyValue(dynamic value) => 'US\$ ${_money.format(_n(value))}';

  Future<DateTimeRange?> _pedirRangoReporte() async {
    final hoy = DateTime.now();
    final inicioAnio = DateTime(hoy.year, 1, 1);
    return showDateRangePicker(
      context: context,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(hoy.year, hoy.month, hoy.day),
      initialDateRange: DateTimeRange(start: inicioAnio, end: DateTime(hoy.year, hoy.month, hoy.day)),
      helpText: 'Selecciona el periodo del reporte',
      cancelText: 'Cancelar',
      confirmText: 'Generar reporte',
      saveText: 'Aplicar periodo',
      fieldStartHintText: 'Fecha inicial',
      fieldEndHintText: 'Fecha final',
    );
  }

  Future<Map<String, dynamic>> _datosReportePeriodo(DateTimeRange rango) async {
    final cliente = _cliente;
    if (cliente == null) throw Exception('Selecciona un cliente primero.');
    final codigo = _s(cliente['codigo_cliente']).isNotEmpty
        ? _s(cliente['codigo_cliente'])
        : (_s(cliente['codigo']).isNotEmpty ? _s(cliente['codigo']) : _s(cliente['ruc']));
    // Recargar sin filtro anual para que el rango elegido no quede limitado
    // por el selector de año de la pantalla.
    final payload = await _cliente360.obtenerDetalle(
      codigo: codigo,
      anio: null,
      departamento: _esJefeLima ? 'LIMA' : _departamento,
    );
    if (payload['error'] != null) {
      throw Exception('${payload['error']} ${payload['details'] ?? ''}'.trim());
    }
    final rawFacturas = payload['facturas'];
    final todasFacturas = rawFacturas is List
        ? rawFacturas.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    final desde = DateTime(rango.start.year, rango.start.month, rango.start.day);
    final hastaExclusivo = DateTime(rango.end.year, rango.end.month, rango.end.day).add(const Duration(days: 1));
    final facturas = todasFacturas.where((f) {
      final fecha = _dt(f['fecha_factura']);
      return fecha != null && !fecha.isBefore(desde) && fecha.isBefore(hastaExclusivo);
    }).toList()
      ..sort((a, b) => _s(b['fecha_factura']).compareTo(_s(a['fecha_factura'])));
    if (facturas.isEmpty) {
      throw Exception('No hay facturas para el periodo ${_date.format(rango.start)} - ${_date.format(rango.end)}.');
    }

    final rawDetalles = payload['detalles'];
    final detalles = rawDetalles is List
        ? rawDetalles.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    final ids = facturas.map((f) => _s(f['id'])).where((id) => id.isNotEmpty).toSet();
    final fechaPorId = <String, String>{
      for (final f in facturas) if (_s(f['id']).isNotEmpty) _s(f['id']): _s(f['fecha_factura']),
    };
    final productosPorClave = <String, Map<String, dynamic>>{};
    for (final d in detalles) {
      final facturaId = _s(d['factura_id']);
      if (!ids.contains(facturaId)) continue;
      final codigoProducto = _s(d['codigo_articulo']);
      final descripcion = _s(d['articulo']);
      final clave = codigoProducto.isNotEmpty ? codigoProducto : descripcion;
      if (clave.isEmpty) continue;
      final cantidadMetros = _n(d['cantidad_metros']);
      final cantidad = cantidadMetros > 0 ? cantidadMetros : _n(d['cantidad']);
      final monto = _n(d['monto_factura']);
      final pesoLinea = _n(d['peso_kg_cobre']);
      final fecha = fechaPorId[facturaId] ?? '';
      final producto = productosPorClave.putIfAbsent(clave, () => {
        'codigo': codigoProducto,
        'descripcion': descripcion,
        'cantidad': 0.0,
        'monto': 0.0,
        'peso': 0.0,
        'fechas_compra': <String>[],
        'ultima_compra': '',
      });
      producto['cantidad'] = _n(producto['cantidad']) + cantidad;
      producto['monto'] = _n(producto['monto']) + monto;
      producto['peso'] = _n(producto['peso']) + pesoLinea;
      final fechas = producto['fechas_compra'] as List<String>;
      if (fecha.isNotEmpty && !fechas.contains(fecha)) fechas.add(fecha);
      if (fecha.isNotEmpty && (_s(producto['ultima_compra']).isEmpty || fecha.compareTo(_s(producto['ultima_compra'])) > 0)) {
        producto['ultima_compra'] = fecha;
      }
    }
    final productos = productosPorClave.values.toList()
      ..sort((a, b) => _n(b['monto']).compareTo(_n(a['monto'])));
    return <String, dynamic>{'facturas': facturas, 'productos': productos, 'facturasHistoricas': todasFacturas, 'detallesHistoricos': detalles};
  }

  List<String> _conclusionesReporte(
    List<Map<String, dynamic>> productos,
    DateTimeRange rango, {
    List<Map<String, dynamic>> facturasHistoricas = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> detallesHistoricos = const <Map<String, dynamic>>[],
  }) {
    if (productos.isEmpty) {
      return <String>[
        'No se encontraron productos detallados en el periodo seleccionado; no es posible determinar la rotación de cables.',
        'Se recomienda validar que las facturas del periodo tengan líneas de detalle cargadas antes de programar una reposición.',
      ];
    }

    final porMetraje = [...productos]
      ..sort((a, b) => _n(b['cantidad']).compareTo(_n(a['cantidad'])));
    final principal = porMetraje.first;
    final descripcion = _s(principal['descripcion']).isEmpty
        ? 'Producto sin descripción registrada'
        : _s(principal['descripcion']);
    final metraje = _n(principal['cantidad']);
    final monto = _n(principal['monto']);
    final peso = _n(principal['peso']);
    final diasPeriodo = rango.end.difference(rango.start).inDays + 1;
    final semanasPeriodo = diasPeriodo / 7.0;
    final metrajeSemanal = semanasPeriodo <= 0 ? 0.0 : metraje / semanasPeriodo;
    final fechasRaw = principal['fechas_compra'];
    final fechas = (fechasRaw is List ? fechasRaw : <dynamic>[])
        .map((e) => DateTime.tryParse(e.toString()))
        .whereType<DateTime>()
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList()
      ..sort();

    final conclusiones = <String>[];
    final inicio = DateTime(rango.start.year, rango.start.month, rango.start.day);
    final finExclusivo = DateTime(rango.end.year, rango.end.month, rango.end.day).add(const Duration(days: 1));
    final totalActual = facturasHistoricas.where((f) {
      final d = _dt(f['fecha_factura']);
      return d != null && !d.isBefore(inicio) && d.isBefore(finExclusivo);
    }).fold<double>(0, (sum, f) => sum + _n(f['monto_calculado']));
    final inicioAnterior = DateTime(rango.start.year - 1, rango.start.month, rango.start.day);
    final finAnteriorExclusivo = DateTime(rango.end.year - 1, rango.end.month, rango.end.day).add(const Duration(days: 1));
    final facturasAnterior = facturasHistoricas.where((f) {
      final d = _dt(f['fecha_factura']);
      return d != null && !d.isBefore(inicioAnterior) && d.isBefore(finAnteriorExclusivo);
    }).toList();
    final totalAnterior = facturasAnterior.fold<double>(0, (sum, f) => sum + _n(f['monto_calculado']));
    if (facturasAnterior.isNotEmpty) {
      final variacion = totalAnterior == 0 ? 0.0 : ((totalActual - totalAnterior) / totalAnterior) * 100;
      final comparacion = variacion > 0 ? 'aumentaron ${variacion.abs().toStringAsFixed(1)}%' : variacion < 0 ? 'disminuyeron ${variacion.abs().toStringAsFixed(1)}%' : 'se mantuvieron al mismo nivel';
      conclusiones.add('📊 Comparación anual: entre ${_date.format(rango.start)} y ${_date.format(rango.end)} se registraron ${_moneyValue(totalActual)} en compras, frente a ${_moneyValue(totalAnterior)} en el mismo periodo del año anterior. Las compras $comparacion. Esta referencia ayuda a observar la evolución del abastecimiento; la variación puede responder al calendario de proyectos y a las necesidades de consumo de cada periodo.');
    } else {
      conclusiones.add('📊 Durante el periodo seleccionado se registraron ${_moneyValue(totalActual)} en compras. No hay facturación histórica suficiente del mismo periodo del año anterior para realizar una comparación fiable; cuando exista información comparable, podremos evaluar mejor la evolución del abastecimiento.');
    }

    final monthly = <int, double>{};
    for (final f in facturasHistoricas) {
      final d = _dt(f['fecha_factura']);
      if (d == null || d.year != rango.start.year || d.isBefore(inicio) || !d.isBefore(finExclusivo)) continue;
      monthly[d.month] = (monthly[d.month] ?? 0) + _n(f['monto_calculado']);
    }
    if (monthly.isNotEmpty) {
      final peak = monthly.entries.reduce((a, b) => a.value >= b.value ? a : b);
      const meses = ['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'];
      conclusiones.add('📅 El mes con mayor volumen de compras fue ${meses[peak.key - 1]}, con ${_moneyValue(peak.value)}. Este dato puede servir como referencia para anticipar la coordinación de pedidos en periodos de mayor actividad, sin asumir que la demanda se repetirá automáticamente.');
    }

    // Comparación mensual de cables por metraje: año del periodo vs. año anterior.
    // Se vinculan las líneas de detalle con la fecha de su factura para no inventar datos.
    if (detallesHistoricos.isNotEmpty && facturasHistoricas.isNotEmpty) {
      final fechaPorFactura = <String, DateTime>{};
      for (final f in facturasHistoricas) {
        final id = _s(f['id']);
        final fecha = _dt(f['fecha_factura']);
        if (id.isNotEmpty && fecha != null) fechaPorFactura[id] = fecha;
      }
      final metrajePorMesAnioProducto = <int, Map<int, Map<String, double>>>{};
      final descripcionPorClave = <String, String>{};
      for (final d in detallesHistoricos) {
        final fecha = fechaPorFactura[_s(d['factura_id'])];
        if (fecha == null) continue;
        final clave = _s(d['codigo_articulo']).isNotEmpty
            ? _s(d['codigo_articulo'])
            : _s(d['articulo']);
        if (clave.isEmpty) continue;
        final descripcionCable = _s(d['articulo']).isNotEmpty ? _s(d['articulo']) : clave;
        descripcionPorClave[clave] = descripcionCable;
        final rawMetros = _n(d['cantidad_metros']);
        final metros = rawMetros > 0 ? rawMetros : _n(d['cantidad']);
        final porAnio = metrajePorMesAnioProducto.putIfAbsent(fecha.month, () => <int, Map<String, double>>{});
        final porProducto = porAnio.putIfAbsent(fecha.year, () => <String, double>{});
        porProducto[clave] = (porProducto[clave] ?? 0) + metros;
      }
      final anioActual = rango.end.year;
      final mesInicio = rango.start.year == anioActual ? rango.start.month : 1;
      final mesFin = rango.end.month;
      const nombresMeses = ['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'];
      final aniosDisponibles = metrajePorMesAnioProducto.values
          .expand((porAnio) => porAnio.keys)
          .where((anio) => anio <= anioActual)
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));
      final comparacionesMensuales = <String>[];
      for (var mes = mesInicio; mes <= mesFin; mes++) {
        final porAnio = metrajePorMesAnioProducto[mes];
        if (porAnio == null) continue;
        final resultadosAnio = <String>[];
        for (final anio in aniosDisponibles) {
          final productosAnio = porAnio[anio];
          if (productosAnio == null || productosAnio.isEmpty) continue;
          final top = productosAnio.entries.reduce((a, b) => a.value >= b.value ? a : b);
          final nombreCable = descripcionPorClave[top.key] ?? top.key;
          resultadosAnio.add('$anio: $nombreCable (${_money.format(top.value)} m)');
        }
        if (resultadosAnio.isNotEmpty) {
          comparacionesMensuales.add('${nombresMeses[mes - 1]} — ${resultadosAnio.join('; ')}');
        }
      }
      if (comparacionesMensuales.isNotEmpty) {
        conclusiones.add('📈 Cables de mayor movimiento por mes: para cada mes se muestra el cable con mayor metraje y su volumen por año disponible, hasta $anioActual: ${comparacionesMensuales.join(' | ')}. La comparación utiliza únicamente las líneas de detalle y fechas registradas; si un año no tiene datos para un mes, no se completa con estimaciones. Esto ayuda a detectar cambios en los cables demandados y planificar reposiciones con anticipación.');
      } else {
        conclusiones.add('📈 Comparación mensual de cables: no se encontraron líneas de detalle suficientes para comparar el metraje mensual entre los años disponibles.');
      }
    } else {
      conclusiones.add('📈 Comparación mensual de cables: el historial disponible no incluye suficiente detalle de productos vinculado a las fechas de factura para comparar los cables de mayor movimiento entre años.');
    }

    final topMetraje = [...productos]..sort((a, b) => _n(b['cantidad']).compareTo(_n(a['cantidad'])));
    if (topMetraje.isNotEmpty) {
      final top = topMetraje.take(3).toList();
      final listado = top.map((p) => '${_s(p['descripcion'])} (${_money.format(_n(p['cantidad']))} m)').join('; ');
      conclusiones.add('📦 Los productos con mayor metraje adquirido fueron: $listado. Este comportamiento permite identificar los cables de mayor movimiento y tomar como referencia las cantidades compradas al organizar futuras obras, mantenimientos o reposiciones.');
      conclusiones.add('💡 Planificación de abastecimiento: sugerimos revisar con anticipación los metrajes estimados, calibres, colores, clase del conductor, aislamiento y fecha requerida para cada proyecto. Con esa información, ELCOPE podrá verificar la disponibilidad real de stock, validar las especificaciones técnicas y, si corresponde, revisar alternativas compatibles o programar fabricación.');
      conclusiones.add('🧾 Recomendación comercial: para agilizar sus próximas compras, puede compartirnos su requerimiento proyectado y la fecha estimada de entrega. Así podremos preparar una cotización actualizada, evaluar cantidades por producto y coordinar oportunamente las condiciones de suministro, sin comprometer stock ni fechas hasta su confirmación.');
    } else {
      conclusiones.add('No se dispone de suficiente detalle de productos para identificar los cables de mayor movimiento. Recomendamos validar las líneas de las facturas y compartir el requerimiento próximo para que ELCOPE pueda revisar las especificaciones, confirmar disponibilidad y preparar una cotización.');
    }
    conclusiones.add('🤝 Compromiso ELCOPE: nuestro equipo comercial está a su disposición para acompañarlos en la planificación de sus próximos requerimientos, resolver consultas técnicas y preparar una propuesta comercial acorde con las cantidades, especificaciones y plazos de su proyecto.');
    return conclusiones;
  }

  Future<void> _imprimirFicha() async {
    final cliente = _cliente;
    if (cliente == null) return;
    final rango = await _pedirRangoReporte();
    if (rango == null) return;
    try {
      final datosPeriodo = await _datosReportePeriodo(rango);
      final facturasReporte = datosPeriodo['facturas'] as List<Map<String, dynamic>>;
      final productosReporte = datosPeriodo['productos'] as List<Map<String, dynamic>>;
      final periodoTexto = '${_date.format(rango.start)} - ${_date.format(rango.end)}';
      final nombre = _s(cliente['razon_social']).isEmpty ? _s(cliente['nombre']) : _s(cliente['razon_social']);
      final ruc = _s(cliente['ruc']).isEmpty ? _s(cliente['codigo_cliente']) : _s(cliente['ruc']);
      final total = facturasReporte.fold<double>(0, (sum, f) => sum + _n(f['monto_calculado']));
      final peso = facturasReporte.fold<double>(0, (sum, f) => sum + _n(f['peso_calculado']));
      final metraje = productosReporte.fold<double>(0, (sum, p) => sum + _n(p['cantidad']));
      final azul = PdfColor.fromInt(0xFF0B3B63);
      final azulClaro = PdfColor.fromInt(0xFF1677E8);
      final gris = PdfColor.fromInt(0xFFE1E7EC);
      final fondo = PdfColor.fromInt(0xFFF4F7FA);
      pw.MemoryImage? logo;
      try {
        final data = await rootBundle.load('assets/images/logo_elcope.png');
        logo = pw.MemoryImage(data.buffer.asUint8List());
      } catch (_) {
        // El reporte sigue funcionando si el logo no está declarado en assets.
      }

      // Cargar los iconos PNG del reporte desde assets/images/reportes.
      // Al ser imágenes, se imprimen correctamente en PDF sin depender de fuentes emoji.
      final iconosReporte = <String, pw.MemoryImage>{};
      const rutasIconosReporte = <String, String>{
        '📊': 'assets/images/reportes/evolucion_anual.png',
        '📅': 'assets/images/reportes/mes_mayor_compra.png',
        '📈': 'assets/images/reportes/productos_mayor_metraje.png',
        '📦': 'assets/images/reportes/productos_mayor_metraje.png',
        '💡': 'assets/images/reportes/planificacion_abastecimiento.png',
        '🧾': 'assets/images/reportes/siguiente_paso.png',
        '🤝': 'assets/images/reportes/compromiso_elcope.png',
      };
      for (final entrada in rutasIconosReporte.entries) {
        try {
          final data = await rootBundle.load(entrada.value);
          iconosReporte[entrada.key] = pw.MemoryImage(data.buffer.asUint8List());
        } catch (_) {
          // Si falta un recurso, se utiliza el indicador de respaldo más abajo.
        }
      }

      pw.Widget iconoConclusion(int index, String texto) {
        String? prefijo;
        for (final clave in rutasIconosReporte.keys) {
          if (texto.startsWith(clave)) {
            prefijo = clave;
            break;
          }
        }
        final imagen = prefijo == null ? null : iconosReporte[prefijo];
        if (imagen != null) {
          return pw.Container(
            width: 32,
            height: 32,
            child: pw.Image(imagen, fit: pw.BoxFit.contain),
          );
        }
        return pw.Container(
          width: 32,
          height: 32,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            color: azulClaro,
            borderRadius: pw.BorderRadius.circular(7),
          ),
          child: pw.Text(
            '${index + 1}',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        );
      }

      final monthly = List<double>.filled(12, 0);
      for (final f in facturasReporte) {
        final d = _dt(f['fecha_factura']);
        if (d != null) monthly[d.month - 1] += _n(f['monto_calculado']);
      }
      final monthNames = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
      final monthlyMax = monthly.fold<double>(1, (a, b) => a > b ? a : b);
      final familyTotals = <String, double>{};
      for (final p in productosReporte) {
        final family = _familiaCable(_s(p['descripcion']));
        familyTotals[family] = (familyTotals[family] ?? 0) + _n(p['monto']);
      }
      final families = familyTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final topProducts = productosReporte.take(5).toList();
      final facturasHistoricas = (datosPeriodo['facturasHistoricas'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final conclusiones = _conclusionesReporte(
        productosReporte, rango,
        facturasHistoricas: facturasHistoricas,
        detallesHistoricos: (datosPeriodo['detallesHistoricos'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
      final pdf = pw.Document(title: 'Reporte Comercial - $nombre', author: 'ELCOPE');
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(24, 20, 24, 24),
        header: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: azulClaro, width: 2))),
          child: pw.Row(children: [
            if (logo != null) pw.Container(width: 112, height: 36, margin: const pw.EdgeInsets.only(right: 12), child: pw.Image(logo!, fit: pw.BoxFit.contain)),
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('REPORTE COMERCIAL DEL CLIENTE', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: azul)),
              pw.Text('Resumen de compras y productos adquiridos', style: pw.TextStyle(fontSize: 9, color: azul)),
            ])),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('INFORMACIÓN CONFIDENCIAL', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: azul)),
              pw.Text('Emisión: ${_date.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Periodo: ${periodoTexto}', style: const pw.TextStyle(fontSize: 8)),
            ]),
          ]),
        ),
        footer: (ctx) => pw.Container(alignment: pw.Alignment.centerRight, padding: const pw.EdgeInsets.only(top: 6), child: pw.Text('ELCOPE | Soluciones en conductores eléctricos     ·     Página ${ctx.pageNumber} de ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7))),
        build: (ctx) => [
          pw.SizedBox(height: 10),
          pw.Container(padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(color: fondo, border: pw.Border.all(color: gris), borderRadius: pw.BorderRadius.circular(8)), child: pw.Row(children: [
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(nombre, style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: azul)),
              pw.SizedBox(height: 4),
              pw.Text('RUC: $ruc     |     Sector: ${_s(cliente['sector']).isEmpty ? '-' : _s(cliente['sector'])}     |     Departamento: ${_s(cliente['departamento']).isEmpty ? '-' : _s(cliente['departamento'])}     |     Asesor comercial: ${_s(cliente['vendedor']).isEmpty ? '-' : _s(cliente['vendedor'])}', style: const pw.TextStyle(fontSize: 8)),
            ])),
            pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFD8F7E9), borderRadius: pw.BorderRadius.circular(12)), child: pw.Text(cliente['activo'] == true ? 'CLIENTE ACTIVO' : 'CLIENTE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0A9B61)))),
          ])),
          pw.SizedBox(height: 10),
          pw.Row(children: [
            _pdfKpi('FACTURACIÓN TOTAL', _moneyValue(total), azulClaro), pw.SizedBox(width: 8),
            _pdfKpi('METRAJE VENDIDO', '${_money.format(metraje)} m', azulClaro), pw.SizedBox(width: 8),
            _pdfKpi('PESO VENDIDO', '${_money.format(peso)} kg', azulClaro), pw.SizedBox(width: 8),
            _pdfKpi('N.º DE FACTURAS', '${facturasReporte.length}', azulClaro),
          ]),
          pw.SizedBox(height: 10),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(flex: 6, child: pw.Container(padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(border: pw.Border.all(color: gris), borderRadius: pw.BorderRadius.circular(7)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('EVOLUCIÓN DE COMPRAS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: azul)),
              pw.SizedBox(height: 10),
              pw.SizedBox(height: 100, child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                for (var i = 0; i < 12; i++) pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 2), child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                  if (monthly[i] > 0) pw.Text(_compactMoney(monthly[i]), style: const pw.TextStyle(fontSize: 5.5)),
                  pw.Container(height: monthly[i] == 0 ? 2 : (monthly[i] / monthlyMax * 68).clamp(2, 68), decoration: pw.BoxDecoration(color: azulClaro, borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(2)))),
                  pw.SizedBox(height: 3), pw.Text(monthNames[i], style: const pw.TextStyle(fontSize: 6)),
                ]))),
              ])),
              pw.SizedBox(height: 4),
              pw.Text('Importes calculados desde los detalles disponibles.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
            ]))),
            pw.SizedBox(width: 10),
            pw.Expanded(flex: 4, child: pw.Container(padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(border: pw.Border.all(color: gris), borderRadius: pw.BorderRadius.circular(7)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('COMPRAS POR FAMILIA', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: azul)),
              pw.SizedBox(height: 8),
              if (families.isEmpty) pw.Text('Sin detalle para clasificar.', style: const pw.TextStyle(fontSize: 8)) else ...families.map((e) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 7), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Row(children: [pw.Expanded(child: pw.Text(e.key, style: const pw.TextStyle(fontSize: 8))), pw.Text('${familyTotals.values.fold<double>(0, (a,b) => a+b) == 0 ? 0 : (e.value / familyTotals.values.fold<double>(0, (a,b) => a+b) * 100).round()}%', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: azul))]),
                pw.SizedBox(height: 3), pw.ClipRRect(horizontalRadius: 3, verticalRadius: 3, child: pw.Container(height: 6, width: 140 * (familyTotals.values.fold<double>(0, (a,b) => a+b) == 0 ? 0 : e.value / familyTotals.values.fold<double>(0, (a,b) => a+b)), color: azulClaro)),
                pw.Text(_moneyValue(e.value), style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
              ]))),
            ]))),
          ]),
          pw.SizedBox(height: 10),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(flex: 6, child: pw.Container(padding: const pw.EdgeInsets.all(9), decoration: pw.BoxDecoration(border: pw.Border.all(color: gris), borderRadius: pw.BorderRadius.circular(7)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('TOP 5 PRODUCTOS POR MONTO', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: azul)),
              pw.SizedBox(height: 6),
              if (topProducts.isEmpty) pw.Text('Sin productos registrados.', style: const pw.TextStyle(fontSize: 8)) else pw.Table(
                columnWidths: {0: const pw.FixedColumnWidth(20), 1: const pw.FlexColumnWidth(5), 2: const pw.FixedColumnWidth(100)},
                children: [for (var i = 0; i < topProducts.length; i++) pw.TableRow(decoration: pw.BoxDecoration(color: i.isEven ? fondo : PdfColors.white), children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${i + 1}', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: azul))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_s(topProducts[i]['descripcion']), style: const pw.TextStyle(fontSize: 7))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_moneyValue(topProducts[i]['monto']), style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: azul)))),
                ]),
              ]),
            ]))),
            pw.SizedBox(width: 10),
            pw.Expanded(flex: 4, child: pw.Container(padding: const pw.EdgeInsets.all(9), decoration: pw.BoxDecoration(border: pw.Border.all(color: gris), borderRadius: pw.BorderRadius.circular(7)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('RESUMEN DEL PERIODO', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: azul)),
              pw.SizedBox(height: 8),
              pw.Text('Productos distintos: ${productosReporte.length}', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 4), pw.Text('Primera compra: ${facturasReporte.isEmpty ? '-' : _dateText(facturasReporte.last['fecha_factura'])}', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 4), pw.Text('Última compra: ${facturasReporte.isEmpty ? '-' : _dateText(facturasReporte.first['fecha_factura'])}', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 8), pw.Text('Este reporte resume la información comercial disponible en los sistemas de ELCOPE. Los importes se presentan según los datos registrados y el periodo seleccionado.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
            ]))),
          ]),
          // Iniciar el detalle extenso de productos en una página nueva para
          // evitar que el título y los encabezados queden aislados al pie de página.
          pw.NewPage(),
          pw.Text('DETALLE DE PRODUCTOS COMPRADOS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: azul)),
          pw.SizedBox(height: 5),
          pw.Text('Detalle por producto con última fecha de compra, cantidad, precio unitario estimado, peso e importe total.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          pw.SizedBox(height: 5),
          pw.Table(
            border: pw.TableBorder.all(color: gris, width: .5),
            columnWidths: {
              0: const pw.FixedColumnWidth(55),
              1: const pw.FlexColumnWidth(5),
              2: const pw.FixedColumnWidth(65),
              3: const pw.FixedColumnWidth(75),
              4: const pw.FixedColumnWidth(70),
              5: const pw.FixedColumnWidth(75),
              6: const pw.FixedColumnWidth(85),
            },
            children: [
              pw.TableRow(decoration: pw.BoxDecoration(color: azul), children: [
                for (final h in ['Última compra', 'Producto / cable', 'Cantidad (m)', 'Precio unit. USD/m', 'Peso (kg)', 'Importe (USD)', 'Familia'])
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(h, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
              ]),
              if (productosReporte.isEmpty)
                pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Sin productos registrados.', style: const pw.TextStyle(fontSize: 7))), for (var i = 0; i < 6; i++) pw.SizedBox()])
              else
                for (var i = 0; i < productosReporte.length; i++)
                  pw.TableRow(decoration: pw.BoxDecoration(color: i.isEven ? fondo : PdfColors.white), children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_productoUltimaCompra(productosReporte[i]), style: const pw.TextStyle(fontSize: 6.5))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_s(productosReporte[i]['descripcion']), style: const pw.TextStyle(fontSize: 6.5))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_money.format(_n(productosReporte[i]['cantidad'])), style: const pw.TextStyle(fontSize: 6.5)))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_money.format(_n(productosReporte[i]['cantidad']) == 0 ? 0 : _n(productosReporte[i]['monto']) / _n(productosReporte[i]['cantidad'])), style: const pw.TextStyle(fontSize: 6.5)))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_money.format(_n(productosReporte[i]['peso'])), style: const pw.TextStyle(fontSize: 6.5)))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_money.format(_n(productosReporte[i]['monto'])), style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: azul)))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_familiaCable(_s(productosReporte[i]['descripcion'])), style: const pw.TextStyle(fontSize: 6.5))),
                  ]),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text('HISTORIAL DE COMPRAS Y FACTURAS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: azul)),
          pw.SizedBox(height: 5),
          pw.Table(
            border: pw.TableBorder.all(color: gris, width: .5),
            columnWidths: {0: const pw.FixedColumnWidth(54), 1: const pw.FixedColumnWidth(78), 2: const pw.FlexColumnWidth(5), 3: const pw.FixedColumnWidth(65), 4: const pw.FixedColumnWidth(65), 5: const pw.FixedColumnWidth(82)},
            children: [
              pw.TableRow(decoration: pw.BoxDecoration(color: azul), children: [for (final h in ['Fecha','Documento','Productos adquiridos','Cantidad (m)','Peso (kg)','Importe (USD)']) pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(h, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white))) ]),
              for (var i = 0; i < facturasReporte.length; i++)
                pw.TableRow(decoration: pw.BoxDecoration(color: i.isEven ? fondo : PdfColors.white), children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_dateText(facturasReporte[i]['fecha_factura']), style: const pw.TextStyle(fontSize: 6.5))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${_s(facturasReporte[i]['punto_factura'])}-${_s(facturasReporte[i]['numero_factura'])}', style: const pw.TextStyle(fontSize: 6.5))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_s(facturasReporte[i]['productos_resumen']).isEmpty ? 'Detalle no disponible' : _s(facturasReporte[i]['productos_resumen']), style: const pw.TextStyle(fontSize: 6.5))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_money.format(_n(facturasReporte[i]['cantidad_calculada'])), style: const pw.TextStyle(fontSize: 6.5)))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_money.format(_n(facturasReporte[i]['peso_calculado'])), style: const pw.TextStyle(fontSize: 6.5)))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_money.format(_n(facturasReporte[i]['monto_calculado'])), style: const pw.TextStyle(fontSize: 6.5)))),
                ]),
            ],
          ),
          pw.NewPage(),
          pw.Text('CONCLUSIÓN Y RECOMENDACIONES COMERCIALES', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: azul)),
          pw.SizedBox(height: 5),
          pw.Text('Análisis automático del historial disponible para el periodo ${periodoTexto}. Las estimaciones se basan únicamente en los productos y fechas registrados.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: fondo, border: pw.Border.all(color: gris), borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              for (var i = 0; i < conclusiones.length; i++)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      iconoConclusion(i, conclusiones[i]),
                      pw.SizedBox(width: 9),
                      pw.Expanded(
                        child: pw.Text(
                          conclusiones[i].replaceFirst(
                            RegExp(r'^(📊|📅|📦|💡|🧾|🤝|📈)\\s*'),
                            '',
                          ),
                          style: const pw.TextStyle(fontSize: 9, lineSpacing: 2),
                        ),
                      ),
                    ],
                  ),
                ),
            ]),
          ),
          pw.SizedBox(height: 12),
          pw.Text('La frecuencia y la próxima compra son estimaciones comerciales; confirmar con el cliente antes de comprometer cantidades o fechas.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ],
      ));
      await Printing.layoutPdf(
        name: 'Reporte_Comercial_${nombre.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.pdf',
        onLayout: (_) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo generar el PDF: $e')));
    }
  }

  Future<void> _exportarExcel() async {
    final cliente = _cliente;
    if (cliente == null) return;
    final rango = await _pedirRangoReporte();
    if (rango == null) return;
    try {
    final datosPeriodo = await _datosReportePeriodo(rango);
    final facturasReporte = datosPeriodo['facturas'] as List<Map<String, dynamic>>;
    final productosReporte = datosPeriodo['productos'] as List<Map<String, dynamic>>;
    final periodoTexto = '${_date.format(rango.start)} - ${_date.format(rango.end)}';
    final nombre = _s(cliente['razon_social']).isEmpty
        ? _s(cliente['nombre'])
        : _s(cliente['razon_social']);
    final total = facturasReporte.fold<double>(
        0, (sum, f) => sum + _n(f['monto_calculado']));
    final peso = facturasReporte.fold<double>(
        0, (sum, f) => sum + _n(f['peso_calculado']));
    final metraje = productosReporte.fold<double>(
        0, (sum, p) => sum + _n(p['cantidad']));
    final excel = xl.Excel.createExcel();
    excel.delete('Sheet1');

    final resumen = excel['Resumen Comercial'];
    resumen.appendRow([
      xl.TextCellValue('ELCOPE | REPORTE COMERCIAL DEL CLIENTE'),
    ]);
    resumen.appendRow([xl.TextCellValue('Resumen de compras y productos adquiridos')]);
    resumen.appendRow([xl.TextCellValue('Fecha de emisión'), xl.TextCellValue(_date.format(DateTime.now()))]);
    resumen.appendRow([xl.TextCellValue('Razón social'), xl.TextCellValue(nombre)]);
    resumen.appendRow([xl.TextCellValue('RUC'), xl.TextCellValue(_s(cliente['ruc']).isEmpty ? _s(cliente['codigo_cliente']) : _s(cliente['ruc']))]);
    resumen.appendRow([xl.TextCellValue('Sector'), xl.TextCellValue(_s(cliente['sector']))]);
    resumen.appendRow([xl.TextCellValue('Departamento'), xl.TextCellValue(_s(cliente['departamento']))]);
    resumen.appendRow([xl.TextCellValue('Asesor comercial'), xl.TextCellValue(_s(cliente['vendedor']))]);
    resumen.appendRow([xl.TextCellValue('Periodo'), xl.TextCellValue(periodoTexto)]);
    resumen.appendRow([]);
    resumen.appendRow([xl.TextCellValue('INDICADORES COMERCIALES'), xl.TextCellValue('VALOR')]);
    resumen.appendRow([xl.TextCellValue('Facturación total (USD)'), xl.DoubleCellValue(total)]);
    resumen.appendRow([xl.TextCellValue('Metraje vendido (m)'), xl.DoubleCellValue(metraje)]);
    resumen.appendRow([xl.TextCellValue('Peso vendido (kg)'), xl.DoubleCellValue(peso)]);
    resumen.appendRow([xl.TextCellValue('Número de facturas'), xl.IntCellValue(facturasReporte.length)]);
    resumen.appendRow([]);
    resumen.appendRow([xl.TextCellValue('COMPRAS POR FAMILIA'), xl.TextCellValue('Monto (USD)'), xl.TextCellValue('Participación')]);

    final familyTotals = <String, double>{};
    for (final product in productosReporte) {
      final family = _familiaCable(_s(product['descripcion']));
      familyTotals[family] = (familyTotals[family] ?? 0) + _n(product['monto']);
    }
    final familyTotal = familyTotals.values.fold<double>(0, (a, b) => a + b);
    final familyEntries = familyTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in familyEntries) {
      resumen.appendRow([
        xl.TextCellValue(entry.key),
        xl.DoubleCellValue(entry.value),
        xl.DoubleCellValue(familyTotal == 0 ? 0 : entry.value / familyTotal),
      ]);
    }

    resumen.appendRow([]);
    resumen.appendRow([xl.TextCellValue('EVOLUCIÓN MENSUAL'), xl.TextCellValue('Monto (USD)')]);
    final monthlyTotals = List<double>.filled(12, 0);
    for (final f in facturasReporte) {
      final date = _dt(f['fecha_factura']);
      if (date != null) monthlyTotals[date.month - 1] += _n(f['monto_calculado']);
    }
    const monthNames = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
    for (var i = 0; i < monthNames.length; i++) {
      resumen.appendRow([xl.TextCellValue(monthNames[i]), xl.DoubleCellValue(monthlyTotals[i])]);
    }

    final facturas = excel['Historial de Compras'];
    facturas.appendRow([
      xl.TextCellValue('Fecha'), xl.TextCellValue('Documento'), xl.TextCellValue('Vendedor'),
      xl.TextCellValue('Productos'), xl.TextCellValue('Cantidad (m)'),
      xl.TextCellValue('Peso (kg)'), xl.TextCellValue('Monto (USD)'), xl.TextCellValue('Estado'),
    ]);
    for (final f in facturasReporte) {
      facturas.appendRow([
        xl.TextCellValue(_dateText(f['fecha_factura'])),
        xl.TextCellValue('${_s(f['punto_factura'])}-${_s(f['numero_factura'])}'),
        xl.TextCellValue(_s(f['vendedor'])),
        xl.TextCellValue(_s(f['productos_resumen']).isEmpty ? 'Detalle no disponible' : _s(f['productos_resumen'])),
        xl.DoubleCellValue(_n(f['cantidad_calculada'])),
        xl.DoubleCellValue(_n(f['peso_calculado'])),
        xl.DoubleCellValue(_n(f['monto_calculado'])),
        xl.TextCellValue(_s(f['estado'])),
      ]);
    }

    final productos = excel['Productos Comprados'];
    productos.appendRow([
      xl.TextCellValue('Última compra'), xl.TextCellValue('Código'),
      xl.TextCellValue('Producto / cable'), xl.TextCellValue('Familia'),
      xl.TextCellValue('Unidad'), xl.TextCellValue('Cantidad (m)'),
      xl.TextCellValue('Precio unitario estimado (USD/m)'), xl.TextCellValue('Peso (kg)'),
      xl.TextCellValue('Importe total (USD)'),
    ]);
    for (final p in productosReporte) {
      final cantidadProducto = _n(p['cantidad']);
      final montoProducto = _n(p['monto']);
      productos.appendRow([
        xl.TextCellValue(_productoUltimaCompra(p)),
        xl.TextCellValue(_s(p['codigo'])),
        xl.TextCellValue(_s(p['descripcion'])),
        xl.TextCellValue(_familiaCable(_s(p['descripcion']))),
        xl.TextCellValue('m'),
        xl.DoubleCellValue(cantidadProducto),
        xl.DoubleCellValue(cantidadProducto == 0 ? 0 : montoProducto / cantidadProducto),
        xl.DoubleCellValue(_n(p['peso'])),
        xl.DoubleCellValue(montoProducto),
      ]);
    }

    final facturasHistoricas = (datosPeriodo['facturasHistoricas'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final conclusionesExcel = _conclusionesReporte(
        productosReporte, rango,
        facturasHistoricas: facturasHistoricas,
        detallesHistoricos: (datosPeriodo['detallesHistoricos'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
    final recomendaciones = excel['Conclusiones y Recomendaciones'];
    recomendaciones.appendRow([xl.TextCellValue('ELCOPE | CONCLUSIÓN Y RECOMENDACIONES COMERCIALES')]);
    recomendaciones.appendRow([xl.TextCellValue('Cliente'), xl.TextCellValue(nombre)]);
    recomendaciones.appendRow([xl.TextCellValue('Periodo analizado'), xl.TextCellValue(periodoTexto)]);
    recomendaciones.appendRow([]);
    recomendaciones.appendRow([xl.TextCellValue('ANÁLISIS COMERCIAL')]);
    for (var i = 0; i < conclusionesExcel.length; i++) {
      recomendaciones.appendRow([xl.TextCellValue('${i + 1}. ${conclusionesExcel[i]}')]);
    }
    recomendaciones.appendRow([]);
    recomendaciones.appendRow([xl.TextCellValue('NOTA'), xl.TextCellValue('La frecuencia y próxima compra son estimaciones basadas en el historial disponible; confirmar con el cliente antes de comprometer cantidades o fechas.')]);

    // Apply a consistent ELCOPE navy header style to each report sheet.
    for (final sheet in [resumen, facturas, productos, recomendaciones]) {
      for (final row in sheet.rows) {
        if (row.isEmpty) continue;
        final first = row.first?.value;
        if (first is xl.TextCellValue &&
            (first.value.toString().contains('ELCOPE |') ||
             first.value.toString() == 'Fecha' ||
             first.value.toString() == 'Código' ||
             first.value.toString() == 'Última compra' ||
             first.value.toString() == 'INDICADORES COMERCIALES' ||
             first.value.toString() == 'COMPRAS POR FAMILIA' ||
             first.value.toString() == 'ANÁLISIS COMERCIAL' ||
             first.value.toString().contains('CONCLUSIÓN Y RECOMENDACIONES'))) {
          for (final cell in row) {
            if (cell == null) continue;
            cell.cellStyle = xl.CellStyle(
              bold: true,
              fontColorHex: xl.ExcelColor.white,
              backgroundColorHex: xl.ExcelColor.fromHexString('#0B3B63'),
            );
          }
        }
      }
    }

    // Anchos de columna para que el archivo sea legible al abrirlo en Excel.
    resumen.setColumnWidth(0, 34);
    resumen.setColumnWidth(1, 24);
    resumen.setColumnWidth(2, 20);
    resumen.setColumnWidth(3, 20);
    facturas.setColumnWidth(0, 16);
    facturas.setColumnWidth(1, 20);
    facturas.setColumnWidth(2, 24);
    facturas.setColumnWidth(3, 70);
    facturas.setColumnWidth(4, 18);
    facturas.setColumnWidth(5, 18);
    facturas.setColumnWidth(6, 20);
    facturas.setColumnWidth(7, 18);
    productos.setColumnWidth(0, 16);
    productos.setColumnWidth(1, 22);
    productos.setColumnWidth(2, 65);
    productos.setColumnWidth(3, 24);
    productos.setColumnWidth(4, 12);
    productos.setColumnWidth(5, 18);
    productos.setColumnWidth(6, 24);
    productos.setColumnWidth(7, 18);
    productos.setColumnWidth(8, 22);
    recomendaciones.setColumnWidth(0, 115);
    recomendaciones.setColumnWidth(1, 75);

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('No se pudo generar el archivo Excel.');
    }
    final safeName = nombre.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final userProfile = Platform.environment['USERPROFILE'];
    final downloadDirectory = userProfile == null || userProfile.isEmpty
        ? Directory.current
        : Directory('$userProfile\\Downloads');
    if (!await downloadDirectory.exists()) {
      await downloadDirectory.create(recursive: true);
    }
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${downloadDirectory.path}${Platform.pathSeparator}Reporte_Comercial_${safeName}_$stamp.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel guardado correctamente en: ${file.path}')),
      );
    }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo generar el Excel: $e'), duration: const Duration(seconds: 8)),
        );
      }
    }
  }

  pw.Widget _pdfKpi(String title, String value, PdfColor color) => pw.Expanded(child: pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColor.fromInt(0xFFE1E7EC)), borderRadius: pw.BorderRadius.circular(7)),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(title, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
      pw.SizedBox(height: 5), pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
    ]),
  ));

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 800;
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _azul,
        elevation: 0,
        title: const Text('Cliente 360°', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Generar reporte PDF',
            onPressed: _cliente == null ? null : _imprimirFicha,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Descargar reporte Excel',
            onPressed: _cliente == null ? null : _exportarExcel,
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(tooltip: 'Actualizar', onPressed: _cargar, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _cliente == null
              ? _errorView()
              : SelectionArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(mobile ? 14 : 24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _selector(mobile),
                      const SizedBox(height: 16),
                      if (_cliente == null)
                        _empty()
                      else
                        _detalle(mobile),
                    ]),
                  ),
                ),
    );
  }

  Widget _selector(bool mobile) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: _azul.withValues(alpha: .09), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.person_search_outlined, color: _azul)),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Buscar cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _azul)),
            SizedBox(height: 3),
            Text('Consulta integral de la relación comercial del cliente.', style: TextStyle(color: Colors.grey)),
          ])),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: mobile ? double.infinity : 440,
            child: TextField(
              controller: _search,
              onChanged: (v) {
                if (v.trim().length >= 2 || v.trim().isEmpty) _buscarClientes(v);
              },
              decoration: InputDecoration(
                hintText: 'Razón social, RUC o código...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: _fondo,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          DropdownButton<String>(
            value: _anio?.toString() ?? 'TODOS',
            items: ['TODOS', '2026', '2025', '2024', '2023', '2022'].map((e) => DropdownMenuItem(value: e, child: Text('Año: $e'))).toList(),
            onChanged: (v) async {
              setState(() => _anio = v == null || v == 'TODOS' ? null : int.tryParse(v));
              await _buscarClientes(_search.text);
              if (_cliente != null) { final actual = _resultados.where((r) => _s(r['codigo']) == _s(_cliente?['codigo_cliente'])).toList(); if (actual.isNotEmpty) await _seleccionar(actual.first); }
            },
          ),
          if (_esJefeLima) Chip(label: const Text('Cartera: LIMA'), avatar: const Icon(Icons.location_on_outlined, size: 18), backgroundColor: Colors.blue.shade50),
        ]),
        if (_resultados.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: ListView.separated(
              itemCount: _resultados.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = _resultados[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.business_outlined, color: _azulClaro),
                  title: Text(_s(r['razon_social']).isEmpty ? _s(r['nombre']) : _s(r['razon_social']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${_s(r['ruc']).isEmpty ? _s(r['codigo']) : _s(r['ruc'])} · ${_s(r['vendedor'])} · ${_s(r['departamento'])}'),
                  trailing: Text(_moneyValue(r['facturacion']), style: const TextStyle(color: _verde, fontWeight: FontWeight.w800)),
                  onTap: () => _seleccionar(r),
                );
              },
            ),
          ),
        ],
      ]),
    );
  }

  Widget _detalle(bool mobile) {
    final c = _cliente!;
    final nombre = _s(c['razon_social']).isEmpty ? _s(c['nombre']) : _s(c['razon_social']);
    final total = _facturas.fold<double>(0, (a, f) => a + _n(f['monto_calculado']));
    final peso = _facturas.fold<double>(0, (a, f) => a + _n(f['peso_calculado']));
    final cantidad = _productos.fold<double>(0, (a, p) => a + _n(p['cantidad']));
    final periodo = _anio == null ? 'Últimos movimientos disponibles' : 'Año $_anio';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _clientHeader(c, nombre, mobile),
      const SizedBox(height: 10),
      _tabsVisual(),
      const SizedBox(height: 12),
      if (_loadingDetail)
        const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
      else ...[
        _tabContent(mobile, c, total, cantidad),
        Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(top: 8), child: Text('$periodo · Datos calculados a partir de facturas y detalles disponibles.', style: const TextStyle(color: Colors.blueGrey, fontSize: 11)))),
      ],
    ]);
  }

  Widget _clientHeader(Map<String, dynamic> c, String nombre, bool mobile) => _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Container(width: 62, height: 62, decoration: BoxDecoration(color: const Color(0xFFE7F1FF), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.apartment, color: Color(0xFF1677E8), size: 36)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _azul)),
        const SizedBox(height: 5),
        Wrap(spacing: 7, runSpacing: 5, children: [
          _pill(c['activo'] == true ? 'Cliente activo' : 'Estado por verificar', c['activo'] == true ? const Color(0xFFD8F7E9) : const Color(0xFFFFF0D8), c['activo'] == true ? _verde : Colors.orange.shade800),
          Text('RUC: ${_s(c['ruc']).isEmpty ? _s(c['codigo_cliente']) : _s(c['ruc'])}', style: const TextStyle(color: _azul, fontSize: 12)),
          Text('Sector: ${_s(c['sector']).isEmpty ? 'No registrado' : _s(c['sector'])}', style: const TextStyle(color: _azul, fontSize: 12)),
          Text('Departamento: ${_s(c['departamento']).isEmpty ? 'No registrado' : _s(c['departamento'])}', style: const TextStyle(color: _azul, fontSize: 12)),
          Text('Vendedor: ${_s(c['vendedor'])}', style: const TextStyle(color: _azul, fontSize: 12)),
        ]),
      ])),
      if (!mobile) const SizedBox.shrink(),
    ]),
  ]));

  Widget _tabsVisual() {
    const labels = ['Resumen', 'Historial de compras', 'Productos comprados', 'Análisis por familia', 'Frecuencia de compra', 'Evolución mensual', 'Recomendaciones'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => setState(() => _tabActivo = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _tabActivo == i ? const Color(0xFFE7F1FF) : Colors.white,
                  border: Border.all(color: _tabActivo == i ? const Color(0xFF1685F8) : _borde),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(labels[i], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _tabActivo == i ? const Color(0xFF1266C3) : _azul)),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _tabContent(bool mobile, Map<String, dynamic> c, double total, double cantidad) {
    switch (_tabActivo) {
      case 1:
        return Column(children: [_facturacion(mobile), const SizedBox(height: 12), _previousAdvisorCard()]);
      case 2:
        return Column(children: [_productsTable(), const SizedBox(height: 12), _topProducts()]);
      case 3:
        return _familyCard();
      case 4:
        return Column(children: [_frequencyCard(), const SizedBox(height: 12), _recentPurchases()]);
      case 5:
        return Column(children: [_monthlyChart(), const SizedBox(height: 12), _comparisonAdvisorCard(total)]);
      case 6:
        return Column(children: [_insightsCard(total, cantidad), const SizedBox(height: 12), _previousAdvisorCard()]);
      default:
        return Column(children: [
          LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 850;
            final cards = [
              _kpi('Facturación total', _moneyValue(total), Icons.attach_money, const Color(0xFF1685F8)),
              _kpi('Metraje vendido', '${_money.format(cantidad)} m', Icons.shopping_cart_outlined, const Color(0xFF9855E8)),
              _kpi('Peso vendido', '${_money.format(_facturas.fold<double>(0, (a, f) => a + _n(f['peso_calculado'])))} kg', Icons.scale_outlined, const Color(0xFF21B982)),
              _kpi('N.º de facturas', '${_facturas.length}', Icons.receipt_long_outlined, const Color(0xFFFF9F24)),
            ];
            if (compact) return Column(children: cards.map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: SizedBox(width: double.infinity, child: w))).toList());
            return Row(children: [for (var i = 0; i < cards.length; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: cards[i])]]);
          }),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, constraints) {
            final narrow = constraints.maxWidth < 950;
            final first = _monthlyChart(), second = _familyCard(), third = _topProducts();
            if (narrow) return Column(children: [first, const SizedBox(height: 10), second, const SizedBox(height: 10), third]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 5, child: first), const SizedBox(width: 10), Expanded(flex: 4, child: second), const SizedBox(width: 10), Expanded(flex: 4, child: third)]);
          }),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, constraints) {
            final narrow = constraints.maxWidth < 1000;
            final products = _productsTable(), frequency = _frequencyCard(), recent = _recentPurchases();
            if (narrow) return Column(children: [products, const SizedBox(height: 10), frequency, const SizedBox(height: 10), recent]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 5, child: products), const SizedBox(width: 10), Expanded(flex: 4, child: frequency), const SizedBox(width: 10), Expanded(flex: 4, child: recent)]);
          }),
          const SizedBox(height: 10),
          _annualCard(),
          const SizedBox(height: 10),
          _comparisonAdvisorCard(total),
          const SizedBox(height: 10),
          _previousAdvisorCard(),
          const SizedBox(height: 12),
          _infoCliente(c),
          const SizedBox(height: 12),
          _facturacion(mobile),
          const SizedBox(height: 12),
          _actividadCard(),
        ]);
    }
  }

  Widget _previousAdvisorCard() {
    final ruc = _s(_cliente?['ruc']).isEmpty ? _s(_cliente?['codigo']) : _s(_cliente?['ruc']);
    final current = _s(_cliente?['vendedor']);
    final totals = <String, double>{};
    final count = <String, int>{};
    for (final f in _facturas) {
      final seller = _s(f['vendedor']);
      if (seller.isEmpty) continue;
      totals[seller] = (totals[seller] ?? 0) + _n(f['monto_calculado']);
      count[seller] = (count[seller] ?? 0) + 1;
    }
    final previous = totals.keys.where((v) => v.toLowerCase() != current.toLowerCase()).toList();
    return _panel('Historial de asesor por RUC', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('RUC/código consultado: $ruc', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
      const SizedBox(height: 8),
      if (previous.isEmpty)
        const Text('No se encontró otro asesor en las facturas históricas disponibles para este cliente.', style: TextStyle(fontSize: 12, color: Colors.blueGrey))
      else
        for (final v in previous)
          Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(children: [
            const Icon(Icons.history, size: 18, color: _azulClaro), const SizedBox(width: 7),
            Expanded(child: Text('$v${v.toLowerCase() == current.toLowerCase() ? ' (actual)' : ' (asesor anterior en facturación histórica)'}', style: const TextStyle(fontSize: 12, color: _azul, fontWeight: FontWeight.w700))),
            Text('${count[v]} facturas · ${_moneyValue(totals[v])}', style: const TextStyle(fontSize: 11, color: _verde, fontWeight: FontWeight.w800)),
          ])),
      const SizedBox(height: 4),
      const Text('El historial se infiere del vendedor registrado en las facturas; no sustituye una bitácora formal de reasignación de cartera.', style: TextStyle(fontSize: 10, color: Colors.blueGrey)),
    ]));
  }

  Widget _comparisonAdvisorCard(double totalActual) {
    final byYear = <int, double>{};
    final bySeller = <String, double>{};
    for (final f in _facturas) {
      final date = _dt(f['fecha_factura']);
      if (date != null) byYear[date.year] = (byYear[date.year] ?? 0) + _n(f['monto_calculado']);
      final seller = _s(f['vendedor']);
      if (seller.isNotEmpty) bySeller[seller] = (bySeller[seller] ?? 0) + _n(f['monto_calculado']);
    }
    final years = byYear.keys.toList()..sort();
    final maxValue = byYear.values.fold<double>(1, (a,b) => a > b ? a : b);
    return _panel('Comparación y evolución por RUC', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Cliente: ${_s(_cliente?['razon_social']).isEmpty ? _s(_cliente?['nombre']) : _s(_cliente?['razon_social'])} · RUC: ${_s(_cliente?['ruc']).isEmpty ? _s(_cliente?['codigo']) : _s(_cliente?['ruc'])}', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
      const SizedBox(height: 10),
      if (years.isEmpty) const Text('No hay facturación disponible para comparar.')
      else for (final year in years)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
          SizedBox(width: 40, child: Text('$year', style: const TextStyle(fontSize: 11, color: _azul))),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: (byYear[year]! / maxValue).clamp(0.0,1.0), minHeight: 11, backgroundColor: const Color(0xFFEAF0F6), color: const Color(0xFF2995F5)))),
          const SizedBox(width: 8), Text(_moneyValue(byYear[year]), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _azul)),
        ])),
      const Divider(height: 18),
      const Text('Facturación histórica por asesor registrado en las facturas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _azul)),
      const SizedBox(height: 7),
      for (final entry in (bySeller.entries.toList()..sort((a,b) => b.value.compareTo(a.value))))
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 11, color: _azul))), Text(_moneyValue(entry.value), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _verde))])),
    ]));
  }

  Widget _pill(String label, Color bg, Color fg) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)), child: Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w800)));

  Widget _panel(String title, Widget child, {IconData icon = Icons.analytics_outlined}) => Container(width: double.infinity, padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _borde), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, size: 18, color: const Color(0xFF1677E8)), const SizedBox(width: 7), Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _azul)))]), const SizedBox(height: 12), child]));

  String _familiaCable(String desc) {
    final d = desc.toUpperCase();
    if (d.contains('N2XS') || d.contains('NA2XS') || d.contains('MEDIA TENSION')) return 'Media tensión';
    if (d.contains('CONTROL') || d.contains('INSTRUMENT')) return 'Control';
    if (d.contains('LSOH') || d.contains('LSZH') || d.contains('LIBRE DE HALOG')) return 'Libre de halógenos';
    if (d.contains('N2XOH') || d.contains('NYY') || d.contains('THW') || d.contains('THHN') || d.contains('N2XY')) return 'Baja tensión';
    return 'Otros / por clasificar';
  }

  Widget _monthlyChart() {
    final months = List.generate(12, (i) => i + 1);
    final values = List<double>.filled(12, 0);
    for (final f in _facturas) { final d = _dt(f['fecha_factura']); if (d != null) values[d.month - 1] += _n(f['monto_calculado']); }
    final maxV = values.fold<double>(0, (a, b) => a > b ? a : b);
    return _panel('Evolución de compras', SizedBox(height: 190, child: Column(children: [Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [for (final m in months) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [if (values[m - 1] > 0) Text(_compactMoney(values[m - 1]), style: const TextStyle(fontSize: 8, color: _azul)), Container(height: maxV == 0 ? 2 : (values[m - 1] / maxV * 105).clamp(2, 105), decoration: BoxDecoration(color: const Color(0xFF2995F5), borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))), const SizedBox(height: 5), Text(['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'][m - 1], style: const TextStyle(fontSize: 8, color: Colors.blueGrey))])))])), const SizedBox(height: 6), const Text('Monto sin IGV calculado desde el detalle disponible', style: TextStyle(fontSize: 9, color: Colors.blueGrey))])));
  }

  String _compactMoney(double n) => n >= 1000000 ? '${(n / 1000000).toStringAsFixed(1)}M' : n >= 1000 ? '${(n / 1000).toStringAsFixed(0)}K' : n.toStringAsFixed(0);

  Widget _familyCard() {
    final sums = <String, double>{};
    for (final p in _productos) { final family = _familiaCable(_s(p['descripcion'])); sums[family] = (sums[family] ?? 0) + _n(p['monto']); }
    final total = sums.values.fold<double>(0, (a, b) => a + b);
    final colors = [const Color(0xFF2995F5), const Color(0xFF42C99A), const Color(0xFFFFA51F), const Color(0xFF9B65E8), const Color(0xFF8DA6C8)];
    final entries = sums.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return _panel('Compras por familia', Column(children: [
      if (entries.isEmpty) const Text('Sin detalles de productos para clasificar.', style: TextStyle(color: Colors.blueGrey, fontSize: 11)),
      for (var i = 0; i < entries.length; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Container(width: 9, height: 9, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)), const SizedBox(width: 7), Expanded(child: Text(entries[i].key, style: const TextStyle(fontSize: 10, color: _azul))), Text(total == 0 ? '0%' : '${(entries[i].value / total * 100).round()}%', style: const TextStyle(fontSize: 10, color: _azul, fontWeight: FontWeight.w800)), const SizedBox(width: 6), Text(_moneyValue(entries[i].value), style: const TextStyle(fontSize: 9, color: _azul))])),
    ]));
  }

  Widget _topProducts() => _panel('Top 5 cables por monto', Column(children: [
    if (_productos.isEmpty) const Text('No hay productos en el periodo.', style: TextStyle(color: Colors.blueGrey, fontSize: 11)),
    for (var i = 0; i < _productos.take(5).length; i++) Builder(builder: (context) { final p = _productos[i]; final max = _productos.isEmpty ? 1.0 : _n(_productos.first['monto']).clamp(1, double.infinity); return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Container(width: 22, height: 22, alignment: Alignment.center, decoration: const BoxDecoration(color: Color(0xFFEAF3FF), shape: BoxShape.circle), child: Text('${i + 1}', style: const TextStyle(color: _azul, fontWeight: FontWeight.w800, fontSize: 10))), const SizedBox(width: 7), Expanded(flex: 4, child: Text(_s(p['descripcion']), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: _azul, fontWeight: FontWeight.w700))), Expanded(flex: 3, child: ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: (_n(p['monto']) / max).clamp(0, 1), minHeight: 8, backgroundColor: const Color(0xFFEAF0F6), color: [const Color(0xFF2995F5), const Color(0xFF42C99A), const Color(0xFFFFA51F), const Color(0xFF9B65E8), const Color(0xFF8DA6C8)][i % 5]))), const SizedBox(width: 7), Text(_moneyValue(p['monto']), style: const TextStyle(fontSize: 9, color: _azul, fontWeight: FontWeight.w800))])); }),
  ]));

  Widget _productsTable() {
    final rows = _productos.take(20).map((p) {
      return DataRow(cells: [
        DataCell(Text(_s(p['codigo']).isEmpty ? '-' : _s(p['codigo']))),
        DataCell(SizedBox(
          width: 150,
          child: Text(
            _s(p['descripcion']),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        )),
        DataCell(Text(_familiaCable(_s(p['descripcion'])))),
        DataCell(Text(_money.format(_n(p['cantidad'])))),
        DataCell(Text(_money.format(_n(p['peso'])))),
        DataCell(Text(_moneyValue(p['monto']))),
      ]);
    }).toList();

    return _panel(
      'Detalle por tipo de cable',
      SizedBox(
        height: 250,
        child: rows.isEmpty
            ? const Center(child: Text('No hay productos en el periodo seleccionado.'))
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: 12,
                    headingRowHeight: 32,
                    dataRowMinHeight: 34,
                    dataRowMaxHeight: 44,
                    columns: const [
                      DataColumn(label: Text('Código')),
                      DataColumn(label: Text('Descripción')),
                      DataColumn(label: Text('Familia')),
                      DataColumn(label: Text('Cantidad (m)')),
                      DataColumn(label: Text('Peso (kg)')),
                      DataColumn(label: Text('Monto sin IGV')),
                    ],
                    rows: rows,
                  ),
                ),
              ),
      ),
    );
  }


  Widget _frequencyCard() {
    final rows = _productos.take(8).toList();
    return _panel('Frecuencia de compra por producto', SizedBox(height: 250, child: rows.isEmpty ? const Text('Sin historial suficiente.') : ListView.separated(itemCount: rows.length, separatorBuilder: (_, __) => const Divider(height: 8), itemBuilder: (context, i) { final p = rows[i]; final dates = _stringList(p['fechas_compra']).map(DateTime.tryParse).whereType<DateTime>().toList()..sort(); var avg = 0; if (dates.length > 1) { var days = 0; for (var j = 1; j < dates.length; j++) { days += dates[j].difference(dates[j - 1]).inDays; } avg = days ~/ (dates.length - 1); } final last = DateTime.tryParse(_s(p['ultima_compra'])); final elapsed = last == null ? 0 : DateTime.now().difference(last).inDays; final status = avg == 0 ? 'Sin datos' : elapsed > avg * 1.5 ? 'Retrasada' : elapsed > avg * .8 ? 'Por reponer' : 'Normal'; final color = status == 'Normal' ? const Color(0xFF21B982) : status == 'Retrasada' ? Colors.redAccent : Colors.orange; return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_s(p['descripcion']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: _azul, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Row(children: [Expanded(child: Text('Última: ${_dateText(p['ultima_compra'])}', style: const TextStyle(fontSize: 9, color: Colors.blueGrey))), Text(avg == 0 ? '—' : '$avg días', style: const TextStyle(fontSize: 9, color: _azul)), const SizedBox(width: 5), _pill(status, color.withValues(alpha: .12), color)] )]); })));
  }

  Widget _recentPurchases() => _panel('Últimas compras', SizedBox(height: 250, child: _facturas.isEmpty ? const Text('Sin facturas en el periodo.') : ListView.separated(itemCount: _facturas.take(8).length, separatorBuilder: (_, __) => const Divider(height: 8), itemBuilder: (context, i) { final f = _facturas[i]; final num = '${_s(f['punto_factura'])}-${_s(f['numero_factura'])}'; final product = _s(f['productos_resumen']).isEmpty ? 'Detalle no disponible' : _s(f['productos_resumen']); return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_dateText(f['fecha_factura']), style: const TextStyle(fontSize: 9, color: Colors.blueGrey)), Text(num, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _azul)), Text(product, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Peso: ${_money.format(_n(f['peso_calculado']))} kg', style: const TextStyle(fontSize: 9, color: Colors.blueGrey)), Text(_moneyValue(f['monto_calculado']), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _verde))])]); })));

  Widget _annualCard() {
    final years = <int>[2023, 2024, 2025, 2026];
    final totals = <int, double>{};
    for (final year in years) {
      totals[year] = _facturas.where((f) => _dt(f['fecha_factura'])?.year == year).fold<double>(
            0,
            (sum, f) => sum + _n(f['monto_calculado']),
          );
    }
    final maxTotal = totals.values.fold<double>(1, (maxValue, value) => value > maxValue ? value : maxValue);

    return _panel(
      'Evolución anual',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final year in years)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: Text('$year', style: const TextStyle(fontSize: 10, color: _azul)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: ((totals[year] ?? 0) / maxTotal).clamp(0.0, 1.0),
                        minHeight: 12,
                        backgroundColor: const Color(0xFFEAF0F6),
                        color: const Color(0xFF2995F5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _moneyValue(totals[year] ?? 0),
                    style: const TextStyle(fontSize: 10, color: _azul, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _insightsCard(double total, double cantidad) {
    final top = _productos.isEmpty ? null : _productos.first;
    final avg = _productos.map((p) => _stringList(p['fechas_compra']).length).fold<int>(0, (a, b) => a + b);
    final items = <String>[
      if (top != null) 'El producto de mayor facturación es ${_s(top['descripcion'])}, con ${_moneyValue(top['monto'])}.',
      'Se registran ${_productos.length} productos distintos y ${_facturas.length} facturas en el periodo.',
      if (avg == 0) 'Aún no hay suficientes fechas de compra para calcular patrones de reposición por producto.' else 'El historial disponible permite estimar intervalos de recompra por producto; validar las recomendaciones con el cliente.',
      if (cantidad > 0) 'El metraje agregado disponible es ${_money.format(cantidad)}; revisar inventario antes de proponer reposición.',
    ];
    return _panel('Recomendaciones comerciales', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (var i = 0; i < items.length; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 22, height: 22, alignment: Alignment.center, decoration: const BoxDecoration(color: Color(0xFFE7F1FF), shape: BoxShape.circle), child: Text('${i + 1}', style: const TextStyle(color: Color(0xFF1677E8), fontWeight: FontWeight.w900))), const SizedBox(width: 8), Expanded(child: Text(items[i], style: const TextStyle(fontSize: 11, color: _azul, height: 1.35)))]))]));
  }

  Widget _infoCliente(Map<String, dynamic> c) => _card(child: Wrap(spacing: 30, runSpacing: 14, children: [
        _info('Dirección', _s(c['direccion']).isEmpty ? '-' : _s(c['direccion'])),
        _info('Localidad', _s(c['localidad']).isEmpty ? '-' : _s(c['localidad'])),
        _info('Canal', _s(c['canal']).isEmpty ? '-' : _s(c['canal'])),
        _info('Primera compra', _dateText(c['primera_compra'])),
        _info('Última compra', _dateText(c['ultima_compra'])),
      ]));

  Widget _info(String label, String value) => SizedBox(width: 220, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))]));

  String _dateText(dynamic value) {
    final d = _dt(value);
    return d == null ? '-' : _date.format(d);
  }

  String _productoUltimaCompra(Map<String, dynamic> producto) {
    final directa = _s(producto['ultima_compra']);
    if (directa.isNotEmpty) return _dateText(directa);
    final fechas = _stringList(producto['fechas_compra'])
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .toList()
      ..sort();
    return fechas.isEmpty ? '-' : _date.format(fechas.last);
  }

  Widget _facturacion(bool mobile) => _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Historial de facturación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _azul)),
        const SizedBox(height: 4),
        const Text('Importes calculados desde el detalle de las facturas.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 12),
        SizedBox(
          height: 330,
          child: Scrollbar(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
            columns: const [
              DataColumn(label: Text('FECHA')),
              DataColumn(label: Text('DOCUMENTO')),
              DataColumn(label: Text('VENDEDOR')),
              DataColumn(label: Text('MONTO USD')),
              DataColumn(label: Text('PESO KG')),
              DataColumn(label: Text('ESTADO')),
            ],
            rows: _facturas.map((f) => DataRow(cells: [
              DataCell(Text(_dateText(f['fecha_factura']))),
              DataCell(Text('${_s(f['punto_factura'])}-${_s(f['numero_factura'])}')),
              DataCell(Text(_s(f['vendedor']))),
              DataCell(Text(_moneyValue(f['monto_calculado']), style: const TextStyle(fontWeight: FontWeight.w800, color: _verde))),
              DataCell(Text(_money.format(_n(f['peso_calculado'])))),
              DataCell(Text(_s(f['estado']))),
            ])).toList(),
          ))),
        ),
      ]));

  Widget _productosCard() => _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Productos comprados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _azul)),
        const SizedBox(height: 12),
        SizedBox(height: 300, child: Scrollbar(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          columns: const [DataColumn(label: Text('CÓDIGO')), DataColumn(label: Text('PRODUCTO')), DataColumn(label: Text('CANTIDAD')), DataColumn(label: Text('VENTA USD')), DataColumn(label: Text('PESO KG'))],
          rows: _productos.map((p) => DataRow(cells: [
            DataCell(Text(_s(p['codigo']).isEmpty ? '-' : _s(p['codigo']))),
            DataCell(SizedBox(width: 320, child: Text(_s(p['descripcion']), maxLines: 2, overflow: TextOverflow.ellipsis))),
            DataCell(Text(_money.format(_n(p['cantidad'])))),
            DataCell(Text(_moneyValue(p['monto']), style: const TextStyle(color: _verde, fontWeight: FontWeight.w800))),
            DataCell(Text(_money.format(_n(p['peso'])))),
          ])).toList(),
        )))),
      ]));

  Widget _actividadCard() => _card(
        child: Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.orange.withValues(alpha: .11), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.history, color: Colors.orange)),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Actividad comercial', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _azul)),
            SizedBox(height: 4),
            Text('Registra llamadas, WhatsApp, correos, visitas, reuniones y seguimientos desde el módulo de Actividades.', style: TextStyle(color: Colors.grey)),
          ])),
          if (widget.onAbrirActividades != null)
            ElevatedButton.icon(
              onPressed: () {
                final codigo = _s(_cliente?['codigo']);
                if (codigo.isNotEmpty) widget.onAbrirActividades!(codigo);
              },
              icon: const Icon(Icons.add_task),
              label: const Text('Registrar actividad'),
            ),
        ]),
      );

  Widget _empty() => _card(child: const Center(child: Padding(padding: EdgeInsets.all(45), child: Column(children: [Icon(Icons.person_search_outlined, size: 52, color: Colors.grey), SizedBox(height: 10), Text('Selecciona un cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), SizedBox(height: 5), Text('Busca por razón social, RUC o código para abrir su Cliente 360°.', style: TextStyle(color: Colors.grey))]))));

  Widget _errorView() => Center(child: Padding(padding: const EdgeInsets.all(24), child: _card(child: Column(children: [const Icon(Icons.error_outline, color: Colors.red, size: 45), const SizedBox(height: 10), const Text('No se pudo cargar Cliente 360°', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 8), Text(_error ?? 'Error desconocido', textAlign: TextAlign.center), const SizedBox(height: 14), ElevatedButton.icon(onPressed: _cargar, icon: const Icon(Icons.refresh), label: const Text('Reintentar'))]))));
}
