import 'package:flutter/material.dart';
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

  Future<void> _imprimirFicha() async {
    final cliente = _cliente;
    if (cliente == null) return;
    final nombre = _s(cliente['razon_social']).isEmpty ? _s(cliente['nombre']) : _s(cliente['razon_social']);
    final total = _facturas.fold<double>(0, (sum, f) => sum + _n(f['monto_calculado']));
    final peso = _facturas.fold<double>(0, (sum, f) => sum + _n(f['peso_calculado']));
    final metraje = _productos.fold<double>(0, (sum, p) => sum + _n(p['cantidad']));
    final pdf = pw.Document(title: 'Ficha Comercial - $nombre', author: 'ELCOPE');
    final azul = PdfColor.fromInt(0xFF0B3B63);
    final azulClaro = PdfColor.fromInt(0xFF1677E8);
    final gris = PdfColor.fromInt(0xFFE1E7EC);
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      header: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: azulClaro, width: 2))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('ELCOPE | FICHA COMERCIAL 360°', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: azul)),
          pw.Text('Impreso: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8)),
        ]),
      ),
      footer: (ctx) => pw.Container(alignment: pw.Alignment.centerRight, padding: const pw.EdgeInsets.only(top: 6), child: pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8))),
      build: (ctx) => [
        pw.SizedBox(height: 12),
        pw.Text(nombre, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: azul)),
        pw.SizedBox(height: 5),
        pw.Text('RUC: ${_s(cliente['ruc']).isEmpty ? _s(cliente['codigo_cliente']) : _s(cliente['ruc'])}     |     Sector: ${_s(cliente['sector'])}     |     Departamento: ${_s(cliente['departamento'])}     |     Vendedor: ${_s(cliente['vendedor'])}', style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 14),
        pw.Row(children: [
          _pdfKpi('FACTURACIÓN TOTAL', _moneyValue(total), azulClaro),
          pw.SizedBox(width: 10), _pdfKpi('METRAJE VENDIDO', '${_money.format(metraje)} m', azulClaro),
          pw.SizedBox(width: 10), _pdfKpi('PESO VENDIDO', '${_money.format(peso)} kg', azulClaro),
          pw.SizedBox(width: 10), _pdfKpi('N.º FACTURAS', '${_facturas.length}', azulClaro),
        ]),
        pw.SizedBox(height: 16),
        pw.Text('Últimas compras / facturas', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: azul)),
        pw.SizedBox(height: 6),
        pw.Table.fromTextArray(
          headers: ['Fecha', 'Factura', 'Productos', 'Cantidad', 'Peso (kg)', 'Monto sin IGV'],
          data: _facturas.take(25).map((f) => [
            _dateText(f['fecha_factura']), '${_s(f['punto_factura'])}-${_s(f['numero_factura'])}',
            _s(f['productos_resumen']).isEmpty ? 'Detalle no disponible' : _s(f['productos_resumen']),
            _money.format(_n(f['cantidad_calculada'])), _money.format(_n(f['peso_calculado'])), _moneyValue(f['monto_calculado']),
          ]).toList(),
          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: pw.BoxDecoration(color: azul),
          cellStyle: const pw.TextStyle(fontSize: 7),
          cellPadding: const pw.EdgeInsets.all(5),
          border: pw.TableBorder.all(color: gris, width: .5),
          oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4F7FA)),
        ),
        pw.SizedBox(height: 12),
        pw.Text('Documento generado desde el CRM de ELCOPE. Los importes corresponden a la información disponible en el sistema y al periodo seleccionado.', style: const pw.TextStyle(fontSize: 8)),
      ],
    ));
    await Printing.layoutPdf(name: 'Ficha_Comercial_${nombre.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.pdf', onLayout: (_) async => pdf.save());
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
          IconButton(tooltip: 'Imprimir ficha comercial en PDF', onPressed: _cliente == null ? null : _imprimirFicha, icon: const Icon(Icons.picture_as_pdf_outlined)),
          IconButton(tooltip: 'Actualizar', onPressed: _cargar, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _cliente == null
              ? _errorView()
              : SingleChildScrollView(
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
        return Column(children: [_monthlyChart(), const SizedBox(height: 12), _annualCard(), const SizedBox(height: 12), _comparisonAdvisorCard(total)]);
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
    return _panel('Frecuencia de compra por producto', SizedBox(height: 250, child: rows.isEmpty ? const Text('Sin historial suficiente.') : ListView.separated(itemCount: rows.length, separatorBuilder: (_, __) => const Divider(height: 8), itemBuilder: (context, i) { final p = rows[i]; final dates = (p['fechas_compra'] as List<String>? ?? []).map(DateTime.tryParse).whereType<DateTime>().toList()..sort(); var avg = 0; if (dates.length > 1) { var days = 0; for (var j = 1; j < dates.length; j++) { days += dates[j].difference(dates[j - 1]).inDays; } avg = days ~/ (dates.length - 1); } final last = DateTime.tryParse(_s(p['ultima_compra'])); final elapsed = last == null ? 0 : DateTime.now().difference(last).inDays; final status = avg == 0 ? 'Sin datos' : elapsed > avg * 1.5 ? 'Retrasada' : elapsed > avg * .8 ? 'Por reponer' : 'Normal'; final color = status == 'Normal' ? const Color(0xFF21B982) : status == 'Retrasada' ? Colors.redAccent : Colors.orange; return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_s(p['descripcion']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: _azul, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Row(children: [Expanded(child: Text('Última: ${_dateText(p['ultima_compra'])}', style: const TextStyle(fontSize: 9, color: Colors.blueGrey))), Text(avg == 0 ? '—' : '$avg días', style: const TextStyle(fontSize: 9, color: _azul)), const SizedBox(width: 5), _pill(status, color.withValues(alpha: .12), color)] )]); })));
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
    final avg = _productos.map((p) => (p['fechas_compra'] as List<String>? ?? []).length).fold<int>(0, (a, b) => a + b);
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
