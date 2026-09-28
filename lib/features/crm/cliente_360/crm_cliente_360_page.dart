import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/supabase/supabase_service.dart';
import '../../../services/sesion.dart';

class CrmCliente360Page extends StatefulWidget {
  const CrmCliente360Page({super.key, this.codigoInicial});

  final String? codigoInicial;

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
  final _money = NumberFormat('#,##0.00', 'en_US');
  final _date = DateFormat('dd/MM/yyyy');
  final _search = TextEditingController();

  bool _loading = true;
  bool _loadingDetail = false;
  String? _error;
  String _departamento = 'TODOS';
  int? _anio;
  List<String>? _vendedoresPermitidos;
  List<Map<String, dynamic>> _resultados = [];
  Map<String, dynamic>? _cliente;
  List<Map<String, dynamic>> _facturas = [];
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _actividades = [];

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
    if (_esGerencia) return null;
    if (_esJefatura) {
      final rows = await _db
          .from('usuario_permisos')
          .select('vendedor,ver_produccion')
          .eq('usuario_jefe_id', Sesion.idUsuario)
          .eq('ver_produccion', true);
      final set = <String>{};
      for (final r in rows as List) {
        final v = _s(r['vendedor']);
        if (v.isNotEmpty) set.add(v);
      }
      if (Sesion.vendedor.trim().isNotEmpty) set.add(Sesion.vendedor.trim());
      return set.toList();
    }
    final v = Sesion.vendedor.trim();
    return v.isEmpty ? <String>[] : <String>[v];
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
    final departamento = _esJefeLima ? 'LIMA' : _departamento;
    final result = await _db.rpc(
      'crm_obtener_clientes_pagina_v6',
      params: {
        'p_busqueda': texto.trim(),
        'p_vendedor': 'TODOS',
        'p_vendedores_permitidos': _vendedoresPermitidos,
        'p_sector': 'TODOS',
        'p_giro': 'TODOS',
        'p_departamento': departamento,
        'p_solo_activos': false,
        'p_limit': 25,
        'p_offset': 0,
        'p_orden': 'FACTURACION_DESC',
        'p_anio': _anio,
      },
    );
    final rows = List<Map<String, dynamic>>.from(result as List);
    if (!mounted) return;
    setState(() => _resultados = rows);
    if (seleccionarPrimero && rows.isNotEmpty) {
      await _seleccionar(rows.first);
    }
  }

  Future<void> _seleccionar(Map<String, dynamic> row) async {
    final codigo = _s(row['codigo']);
    if (codigo.isEmpty) return;
    setState(() {
      _loadingDetail = true;
      _error = null;
      _cliente = null;
      _facturas = [];
      _productos = [];
      _actividades = [];
    });
    try {
      final resumen = await _db.rpc(
        'crm_obtener_cliente_360_resumen',
        params: {
          'p_codigo_cliente': codigo,
          'p_vendedores_permitidos': _vendedoresPermitidos,
          'p_departamento': _esJefeLima ? 'LIMA' : _departamento,
          'p_anio': _anio,
        },
      );
      final lista = List<Map<String, dynamic>>.from(resumen as List);
      if (lista.isEmpty) throw Exception('El cliente no pertenece a la cartera autorizada.');

      final invoiceResult = await _db.rpc(
        'crm_obtener_cliente_360_facturas',
        params: {
          'p_codigo_cliente': codigo,
          'p_vendedores_permitidos': _vendedoresPermitidos,
          'p_departamento': _esJefeLima ? 'LIMA' : _departamento,
          'p_anio': _anio,
        },
      );
      final invoiceRows = List<Map<String, dynamic>>.from(invoiceResult as List);

      final productResult = await _db.rpc(
        'crm_obtener_cliente_360_productos',
        params: {
          'p_codigo_cliente': codigo,
          'p_vendedores_permitidos': _vendedoresPermitidos,
          'p_departamento': _esJefeLima ? 'LIMA' : _departamento,
          'p_anio': _anio,
        },
      );
      final products = List<Map<String, dynamic>>.from(productResult as List);

      final activityResult = await _db.rpc(
        'crm_obtener_cliente_360_actividades',
        params: {
          'p_codigo_cliente': codigo,
          'p_vendedores_permitidos': _vendedoresPermitidos,
          'p_limit': 50,
        },
      );
      final activities = List<Map<String, dynamic>>.from(activityResult as List);

      if (!mounted) return;
      setState(() {
        _cliente = lista.first;
        _facturas = invoiceRows;
        _productos = products;
        _actividades = activities;
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

  Widget _kpi(String title, String value, IconData icon, Color color) => Expanded(
        child: Container(
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
        ),
      );

  String _moneyValue(dynamic value) => 'US\$ ${_money.format(_n(value))}';

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
        actions: [IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh))],
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
    final fact = _n(c['facturacion_total']);
    final peso = _n(c['peso_total_kg']);
    final facturas = _s(c['cantidad_facturas']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _card(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 58, height: 58, decoration: BoxDecoration(color: _azul, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.business, color: Colors.white, size: 30)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _azul)),
          const SizedBox(height: 4),
          Text('RUC: ${_s(c['ruc']).isEmpty ? _s(c['codigo_cliente']) : _s(c['ruc'])} · Vendedor: ${_s(c['vendedor'])}', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            Chip(label: Text(_s(c['sector']).isEmpty ? 'Sin sector' : _s(c['sector']))),
            Chip(label: Text(_s(c['giro']).isEmpty ? 'Sin giro' : _s(c['giro']))),
            Chip(label: Text(_s(c['departamento']).isEmpty ? 'Sin departamento' : _s(c['departamento']))),
            Chip(label: Text(c['activo'] == true ? 'ACTIVO' : 'INACTIVO'), backgroundColor: c['activo'] == true ? Colors.green.shade50 : Colors.red.shade50),
          ]),
        ])),
      ])),
      const SizedBox(height: 14),
      mobile
          ? Column(children: [
              _kpi('Ventas del período', _moneyValue(fact), Icons.attach_money, _verde),
              const SizedBox(height: 10),
              _kpi('Peso vendido', '${_money.format(peso)} kg', Icons.scale_outlined, _verde),
              const SizedBox(height: 10),
              _kpi('Facturas', facturas, Icons.receipt_long_outlined, _azulClaro),
              const SizedBox(height: 10),
              _kpi('Ticket promedio', _moneyValue(c['ticket_promedio']), Icons.analytics_outlined, Colors.orange),
            ])
          : Row(children: [
              _kpi('Ventas del período', _moneyValue(fact), Icons.attach_money, _verde),
              const SizedBox(width: 10),
              _kpi('Peso vendido', '${_money.format(peso)} kg', Icons.scale_outlined, _verde),
              const SizedBox(width: 10),
              _kpi('Facturas', facturas, Icons.receipt_long_outlined, _azulClaro),
              const SizedBox(width: 10),
              _kpi('Ticket promedio', _moneyValue(c['ticket_promedio']), Icons.analytics_outlined, Colors.orange),
            ]),
      const SizedBox(height: 16),
      _infoCliente(c),
      const SizedBox(height: 16),
      if (_loadingDetail) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
      if (!_loadingDetail) ...[
        _facturacion(mobile),
        const SizedBox(height: 16),
        _productosCard(),
        const SizedBox(height: 16),
        _actividadCard(),
      ],
    ]);
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

  Widget _facturacion(bool mobile) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historial de facturación',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _azul,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Importes calculados desde el detalle de las facturas.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _facturas.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No hay facturas para los filtros seleccionados.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : Scrollbar(
                    thumbVisibility: true,
                    notificationPredicate: (notification) =>
                        notification.metrics.axis == Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('FECHA')),
                          DataColumn(label: Text('DOCUMENTO')),
                          DataColumn(label: Text('VENDEDOR')),
                          DataColumn(label: Text('MONTO USD')),
                          DataColumn(label: Text('PESO KG')),
                          DataColumn(label: Text('ESTADO')),
                        ],
                        rows: _facturas
                            .map(
                              (f) => DataRow(
                                cells: [
                                  DataCell(Text(_dateText(f['fecha_factura']))),
                                  DataCell(Text(
                                    '${_s(f['punto_factura'])}-${_s(f['numero_factura'])}',
                                  )),
                                  DataCell(Text(_s(f['vendedor']))),
                                  DataCell(
                                    Text(
                                      _moneyValue(f['monto_calculado']),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: _verde,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(_money.format(_n(f['peso_calculado']))),
                                  ),
                                  DataCell(Text(_s(f['estado']))),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
          ],
        ),
      );

  Widget _productosCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Productos comprados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _azul,
              ),
            ),
            const SizedBox(height: 12),
            _productos.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No hay productos para los filtros seleccionados.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : Scrollbar(
                    thumbVisibility: true,
                    notificationPredicate: (notification) =>
                        notification.metrics.axis == Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('CÓDIGO')),
                          DataColumn(label: Text('PRODUCTO')),
                          DataColumn(label: Text('CANTIDAD')),
                          DataColumn(label: Text('VENTA USD')),
                          DataColumn(label: Text('PESO KG')),
                        ],
                        rows: _productos
                            .map(
                              (p) => DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      _s(p['codigo']).isEmpty
                                          ? '-'
                                          : _s(p['codigo']),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 320,
                                      child: Text(
                                        _s(p['descripcion']),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(_money.format(_n(p['cantidad']))),
                                  ),
                                  DataCell(
                                    Text(
                                      _moneyValue(p['monto']),
                                      style: const TextStyle(
                                        color: _verde,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(_money.format(_n(p['peso']))),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
          ],
        ),
      );

  String _actividadFecha(dynamic value) {
    final d = _dt(value);
    return d == null ? '-' : '${_date.format(d)} ${DateFormat('HH:mm').format(d)}';
  }

  Future<void> _nuevaActividad() async {
    if (_cliente == null) return;
    String tipo = 'LLAMADA';
    final asunto = TextEditingController();
    final descripcion = TextEditingController();
    final resultado = TextEditingController();
    final proxima = TextEditingController();
    DateTime? fechaProxima;

    final guardar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Registrar actividad comercial'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  value: tipo,
                  decoration: const InputDecoration(labelText: 'Tipo de actividad'),
                  items: const [
                    DropdownMenuItem(value: 'LLAMADA', child: Text('Llamada')),
                    DropdownMenuItem(value: 'WHATSAPP', child: Text('WhatsApp')),
                    DropdownMenuItem(value: 'CORREO', child: Text('Correo')),
                    DropdownMenuItem(value: 'VISITA', child: Text('Visita')),
                    DropdownMenuItem(value: 'REUNION', child: Text('Reunión')),
                    DropdownMenuItem(value: 'SEGUIMIENTO', child: Text('Seguimiento')),
                    DropdownMenuItem(value: 'COBRANZA', child: Text('Cobranza')),
                  ],
                  onChanged: (v) => setLocal(() => tipo = v ?? 'LLAMADA'),
                ),
                const SizedBox(height: 10),
                TextField(controller: asunto, decoration: const InputDecoration(labelText: 'Asunto *')),
                const SizedBox(height: 10),
                TextField(controller: descripcion, maxLines: 3, decoration: const InputDecoration(labelText: 'Descripción')),
                const SizedBox(height: 10),
                TextField(controller: resultado, maxLines: 2, decoration: const InputDecoration(labelText: 'Resultado')),
                const SizedBox(height: 10),
                TextField(controller: proxima, maxLines: 2, decoration: const InputDecoration(labelText: 'Próxima acción')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: Text(fechaProxima == null ? 'Sin próxima fecha' : 'Próxima: ${_date.format(fechaProxima!)}')),
                  TextButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDate: fechaProxima ?? DateTime.now(),
                      );
                      if (d != null) setLocal(() => fechaProxima = d);
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: const Text('Fecha'),
                  ),
                ]),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );

    if (guardar != true || asunto.text.trim().isEmpty || !mounted) {
      asunto.dispose();
      descripcion.dispose();
      resultado.dispose();
      proxima.dispose();
      return;
    }

    try {
      await _db.rpc('crm_registrar_actividad', params: {
        'p_codigo_cliente': _s(_cliente!['codigo_cliente']),
        'p_tipo': tipo,
        'p_asunto': asunto.text.trim(),
        'p_descripcion': descripcion.text.trim().isEmpty ? null : descripcion.text.trim(),
        'p_resultado': resultado.text.trim().isEmpty ? null : resultado.text.trim(),
        'p_proxima_accion': proxima.text.trim().isEmpty ? null : proxima.text.trim(),
        'p_fecha_proxima_accion': fechaProxima == null ? null : DateFormat('yyyy-MM-dd').format(fechaProxima!),
        'p_usuario_id': Sesion.idUsuario,
        'p_vendedor': _s(_cliente!['vendedor']),
      });
      await _recargarActividades();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Actividad registrada correctamente.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo registrar: $e')));
    } finally {
      asunto.dispose();
      descripcion.dispose();
      resultado.dispose();
      proxima.dispose();
    }
  }

  Future<void> _recargarActividades() async {
    if (_cliente == null) return;
    final result = await _db.rpc('crm_obtener_cliente_360_actividades', params: {
      'p_codigo_cliente': _s(_cliente!['codigo_cliente']),
      'p_vendedores_permitidos': _vendedoresPermitidos,
      'p_limit': 50,
    });
    if (mounted) setState(() => _actividades = List<Map<String, dynamic>>.from(result as List));
  }

  Widget _actividadCard() => _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.orange.withValues(alpha: .11), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.history, color: Colors.orange)),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Actividad comercial', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _azul)),
            SizedBox(height: 4),
            Text('Llamadas, WhatsApp, correos, visitas, reuniones, seguimientos y cobranza.', style: TextStyle(color: Colors.grey)),
          ])),
          ElevatedButton.icon(onPressed: _nuevaActividad, icon: const Icon(Icons.add), label: const Text('Nueva actividad')),
        ]),
        const SizedBox(height: 14),
        if (_actividades.isEmpty)
          Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _fondo, borderRadius: BorderRadius.circular(12)), child: const Column(children: [Icon(Icons.history_toggle_off, size: 38, color: Colors.grey), SizedBox(height: 8), Text('Sin actividad registrada', style: TextStyle(fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('Registra la primera llamada, visita, WhatsApp o seguimiento de este cliente.', style: TextStyle(color: Colors.grey))]))
        else
          SizedBox(
            height: 360,
            child: ListView.separated(
              itemCount: _actividades.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final a = _actividades[i];
                final icon = switch (_s(a['tipo']).toUpperCase()) {
                  'LLAMADA' => Icons.phone_outlined,
                  'WHATSAPP' => Icons.chat_outlined,
                  'CORREO' => Icons.email_outlined,
                  'VISITA' => Icons.location_on_outlined,
                  'REUNION' => Icons.groups_outlined,
                  'COBRANZA' => Icons.payments_outlined,
                  _ => Icons.task_alt_outlined,
                };
                return ListTile(
                  leading: CircleAvatar(backgroundColor: _azul.withValues(alpha: .08), child: Icon(icon, color: _azul)),
                  title: Text(_s(a['asunto']), style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${_s(a['tipo'])} · ${_actividadFecha(a['fecha'])}\n${_s(a['resultado']).isEmpty ? _s(a['descripcion']) : _s(a['resultado'])}'),
                  isThreeLine: true,
                  trailing: _s(a['fecha_proxima_accion']).isEmpty ? null : Text('Próxima\n${_s(a['fecha_proxima_accion'])}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                );
              },
            ),
          ),
      ]));

  Widget _empty() => _card(child: const Center(child: Padding(padding: EdgeInsets.all(45), child: Column(children: [Icon(Icons.person_search_outlined, size: 52, color: Colors.grey), SizedBox(height: 10), Text('Selecciona un cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), SizedBox(height: 5), Text('Busca por razón social, RUC o código para abrir su Cliente 360°.', style: TextStyle(color: Colors.grey))]))));

  Widget _errorView() => Center(child: Padding(padding: const EdgeInsets.all(24), child: _card(child: Column(children: [const Icon(Icons.error_outline, color: Colors.red, size: 45), const SizedBox(height: 10), const Text('No se pudo cargar Cliente 360°', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 8), Text(_error ?? 'Error desconocido', textAlign: TextAlign.center), const SizedBox(height: 14), ElevatedButton.icon(onPressed: _cargar, icon: const Icon(Icons.refresh), label: const Text('Reintentar'))]))));
}
