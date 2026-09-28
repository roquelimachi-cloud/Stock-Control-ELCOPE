import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/sesion.dart';
import '../../../services/supabase/supabase_service.dart';

class CrmCobranzaPage extends StatefulWidget {
  const CrmCobranzaPage({super.key});

  @override
  State<CrmCobranzaPage> createState() => _CrmCobranzaPageState();
}

class _CrmCobranzaPageState extends State<CrmCobranzaPage> {
  static const azul = Color(0xFF0B3B63);
  static const verde = Color(0xFF0A9B61);
  static const fondo = Color(0xFFF4F7FA);
  static const rojo = Color(0xFFC62828);
  static const naranja = Color(0xFFE67E22);

  final db = SupabaseService.client;
  final search = TextEditingController();
  final money = NumberFormat('#,##0.00', 'en_US');
  final date = DateFormat('dd/MM/yyyy');

  bool loading = true;
  String? error;
  String estado = 'TODOS';
  String vendedor = 'TODOS';
  List<String>? vendedoresPermitidos;
  List<String> vendedores = [];
  List<Map<String, dynamic>> rows = [];

  double get total => rows.fold(0, (a, r) => a + _n(r['monto_factura']));
  double get pagado => rows.fold(0, (a, r) => a + _n(r['monto_pagado']));
  double get saldo => rows.fold(0, (a, r) => a + _n(r['saldo']));
  int get vencidas => rows.where((r) => _s(r['estado']) == 'VENCIDA').length;

  bool get esGerencia => Sesion.rol.trim().toLowerCase() == 'gerencia';
  bool get esJefatura {
    final r = Sesion.rol.trim().toLowerCase();
    return r == 'jefe lima' || r == 'jefe provincia';
  }

  String _s(dynamic v) => v?.toString().trim() ?? '';
  double _n(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(_s(v).replaceAll(',', '')) ?? 0;
  }
  DateTime? _dt(dynamic v) => DateTime.tryParse(_s(v));

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _cargarPermisos();
    await _cargar();
  }

  Future<void> _cargarPermisos() async {
    try {
      if (esGerencia) {
        vendedoresPermitidos = null;
      } else if (esJefatura) {
        final data = await db
            .from('usuario_permisos')
            .select('vendedor,ver_produccion')
            .eq('usuario_jefe_id', Sesion.idUsuario)
            .eq('ver_produccion', true);
        final set = <String>{};
        for (final x in data as List) {
          final v = _s(x['vendedor']);
          if (v.isNotEmpty) set.add(v);
        }
        if (Sesion.vendedor.trim().isNotEmpty) set.add(Sesion.vendedor.trim());
        vendedoresPermitidos = set.toList()..sort();
      } else {
        vendedoresPermitidos = Sesion.vendedor.trim().isEmpty
            ? <String>[]
            : <String>[Sesion.vendedor.trim()];
      }
      vendedores = vendedoresPermitidos == null
          ? await _todosVendedores()
          : List<String>.from(vendedoresPermitidos!);
    } catch (_) {
      vendedoresPermitidos = esGerencia ? null : <String>[Sesion.vendedor.trim()];
      vendedores = vendedoresPermitidos ?? [];
    }
  }

  Future<List<String>> _todosVendedores() async {
    final data = await db
        .from('crm_facturas')
        .select('vendedor')
        .not('vendedor', 'is', null)
        .limit(5000);
    final set = <String>{};
    for (final x in data as List) {
      final v = _s(x['vendedor']);
      if (v.isNotEmpty) set.add(v);
    }
    return set.toList()..sort();
  }

  Future<void> _cargar() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final data = await db.rpc('crm_obtener_cobranzas', params: {
        'p_vendedores_permitidos': vendedoresPermitidos,
        'p_vendedor': vendedor,
        'p_estado': estado,
        'p_busqueda': search.text.trim(),
        'p_limit': 1000,
      });
      if (!mounted) return;
      setState(() {
        rows = List<Map<String, dynamic>>.from(data as List);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; error = e.toString(); });
    }
  }

  Future<List<Map<String, dynamic>>> _buscarClientes(String text) async {
    final q = text.trim();
    if (q.length < 2) return [];
    final data = await db
        .from('clientes')
        .select('codigo,ruc,razon_social,nombre,vendedor,departamento')
        .or('razon_social.ilike.%$q%,ruc.ilike.%$q%,codigo.ilike.%$q%')
        .limit(20);
    var result = List<Map<String, dynamic>>.from(data);
    if (vendedoresPermitidos != null && vendedoresPermitidos!.isNotEmpty) {
      result = result.where((r) => vendedoresPermitidos!.contains(_s(r['vendedor']))).toList();
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _facturasCliente(String codigo) async {
    final data = await db
        .from('crm_facturas')
        .select('id,punto_factura,numero_factura,fecha_factura,cliente,codigo_cliente,vendedor,monto_factura,estado')
        .eq('codigo_cliente', codigo)
        .neq('estado', 'ANULADA')
        .order('fecha_factura', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _nuevaCobranza() async {
    Map<String, dynamic>? cliente;
    Map<String, dynamic>? factura;
    DateTime fechaVencimiento = DateTime.now();
    final monto = TextEditingController();
    final pagado = TextEditingController(text: '0');
    final obs = TextEditingController();
    final clienteSearch = TextEditingController();
    List<Map<String, dynamic>> clientes = [];
    List<Map<String, dynamic>> facturas = [];
    String? vendedorSeleccionado;

    Future<void> buscar(String value, void Function(void Function()) setLocal) async {
      if (value.trim().length < 2) {
        setLocal(() => clientes = []);
        return;
      }
      try {
        final result = await _buscarClientes(value);
        setLocal(() => clientes = result);
      } catch (_) {
        setLocal(() => clientes = []);
      }
    }

    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Registrar cobranza'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: clienteSearch,
                  onChanged: (v) => buscar(v, setLocal),
                  decoration: const InputDecoration(
                    labelText: 'Cliente / RUC / código *',
                    hintText: 'Escribe el nombre o RUC',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (clientes.isNotEmpty && cliente == null) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 190),
                    decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(10)),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: clientes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final r = clientes[i];
                        final nombre = _s(r['razon_social']).isEmpty ? _s(r['nombre']) : _s(r['razon_social']);
                        final codigo = _s(r['ruc']).isEmpty ? _s(r['codigo']) : _s(r['ruc']);
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.business_outlined, color: azul),
                          title: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('$codigo · ${_s(r['vendedor'])} · ${_s(r['departamento'])}'),
                          onTap: () async {
                            cliente = r;
                            vendedorSeleccionado = _s(r['vendedor']);
                            clienteSearch.text = nombre;
                            clientes = [];
                            factura = null;
                            monto.clear();
                            facturas = await _facturasCliente(_s(r['codigo']));
                            setLocal(() {});
                          },
                        );
                      },
                    ),
                  ),
                ],
                if (cliente != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Text('${_s(cliente!['razon_social']).isEmpty ? _s(cliente!['nombre']) : _s(cliente!['razon_social'])} · ${_s(cliente!['vendedor'])}', style: const TextStyle(fontWeight: FontWeight.w700))),
                    IconButton(onPressed: () { cliente = null; factura = null; facturas = []; monto.clear(); clienteSearch.clear(); vendedorSeleccionado = null; setLocal(() {}); }, icon: const Icon(Icons.clear)),
                  ]),
                ],
                if (facturas.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: factura?['id'] as int?,
                    decoration: const InputDecoration(labelText: 'Factura (opcional)', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Sin factura')),
                      ...facturas.map((f) => DropdownMenuItem<int?>(
                        value: f['id'] as int?,
                        child: Text('${_s(f['punto_factura'])}-${_s(f['numero_factura'])} · US\$ ${money.format(_n(f['monto_factura']))}'),
                      )),
                    ],
                    onChanged: (id) {
                      factura = id == null ? null : facturas.firstWhere((f) => f['id'] == id);
                      if (factura != null) {
                        monto.text = _n(factura!['monto_factura']).toStringAsFixed(2);
                        vendedorSeleccionado = _s(factura!['vendedor']);
                      }
                      setLocal(() {});
                    },
                  ),
                ],
                const SizedBox(height: 10),
                TextField(controller: monto, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Monto factura USD *', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: pagado, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Monto pagado USD', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: Text('Vencimiento: ${date.format(fechaVencimiento)}')),
                  TextButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: fechaVencimiento);
                      if (d != null) setLocal(() => fechaVencimiento = d);
                    },
                    icon: const Icon(Icons.calendar_month), label: const Text('Cambiar'),
                  ),
                ]),
                TextField(controller: obs, maxLines: 3, decoration: const InputDecoration(labelText: 'Observación', border: OutlineInputBorder())),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: cliente == null ? null : () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );

    if (guardar != true || cliente == null || !mounted) {
      monto.dispose(); pagado.dispose(); obs.dispose(); clienteSearch.dispose();
      return;
    }
    try {
      await db.rpc('crm_registrar_cobranza', params: {
        'p_codigo_cliente': _s(cliente!['codigo']),
        'p_factura_id': factura?['id'],
        'p_documento': factura == null ? null : '${_s(factura!['punto_factura'])}-${_s(factura!['numero_factura'])}',
        'p_fecha_emision': factura?['fecha_factura'],
        'p_fecha_vencimiento': DateFormat('yyyy-MM-dd').format(fechaVencimiento),
        'p_monto_factura': double.tryParse(monto.text.replaceAll(',', '')) ?? 0,
        'p_monto_pagado': double.tryParse(pagado.text.replaceAll(',', '')) ?? 0,
        'p_observacion': obs.text.trim().isEmpty ? null : obs.text.trim(),
        'p_vendedor': vendedorSeleccionado,
        'p_usuario_id': Sesion.idUsuario,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cobranza registrada correctamente.')));
      await _cargar();
    } catch (e) {
      if (mounted) _msg('No se pudo registrar la cobranza: $e');
    } finally {
      monto.dispose(); pagado.dispose(); obs.dispose(); clienteSearch.dispose();
    }
  }

  Future<void> _registrarPago(Map<String, dynamic> row) async {
    final pago = TextEditingController(text: _n(row['monto_pagado']).toStringAsFixed(2));
    final obs = TextEditingController(text: _s(row['observacion']));
    DateTime? fecha = _dt(row['fecha_ultimo_pago']) ?? DateTime.now();
    String est = _s(row['estado']).isEmpty ? 'PENDIENTE' : _s(row['estado']);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Actualizar cobranza · ${_s(row['documento'])}'),
          content: SizedBox(width: 500, child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Saldo actual: US\$ ${money.format(_n(row['saldo']))}', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(controller: pago, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Total pagado acumulado USD')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Text('Último pago: ${date.format(fecha!)}')),
              TextButton.icon(onPressed: () async { final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: fecha!); if (d != null) setLocal(() => fecha = d); }, icon: const Icon(Icons.event), label: const Text('Fecha')),
            ]),
            DropdownButtonFormField<String>(initialValue: ['PENDIENTE','PROMESA','PAGADA','OBSERVADA'].contains(est) ? est : 'PENDIENTE', decoration: const InputDecoration(labelText: 'Estado'), items: const [DropdownMenuItem(value:'PENDIENTE',child:Text('Pendiente')),DropdownMenuItem(value:'PROMESA',child:Text('Promesa de pago')),DropdownMenuItem(value:'PAGADA',child:Text('Pagada')),DropdownMenuItem(value:'OBSERVADA',child:Text('Observada'))], onChanged:(v){if(v!=null)setLocal(()=>est=v);}),
            const SizedBox(height: 10),
            TextField(controller: obs, maxLines: 3, decoration: const InputDecoration(labelText: 'Observación')),
          ])),
          actions: [TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Guardar'))],
        ),
      ),
    );
    if (ok != true) { pago.dispose(); obs.dispose(); return; }
    try {
      await db.rpc('crm_actualizar_cobranza', params: {
        'p_id': row['id'],
        'p_monto_pagado': double.tryParse(pago.text.replaceAll(',', '')) ?? 0,
        'p_fecha_ultimo_pago': DateFormat('yyyy-MM-dd').format(fecha!),
        'p_observacion': obs.text.trim().isEmpty ? null : obs.text.trim(),
        'p_estado': est,
      });
      await _cargar();
    } catch (e) { if (mounted) _msg('No se pudo actualizar: $e'); }
    pago.dispose(); obs.dispose();
  }

  void _msg(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Color _estadoColor(String e) {
    switch (e) { case 'PAGADA': return verde; case 'VENCIDA': return rojo; case 'PROMESA': return naranja; default: return azul; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(backgroundColor: azul, foregroundColor: Colors.white, title: const Text('Cobranza CRM'), actions: [IconButton(onPressed: loading ? null : _cargar, icon: const Icon(Icons.refresh))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _nuevaCobranza, backgroundColor: verde, foregroundColor: Colors.white, icon: const Icon(Icons.add), label: const Text('Nueva cobranza')),
      body: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
        _toolbar(), const SizedBox(height: 14), _kpis(), const SizedBox(height: 14),
        Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : error != null ? _errorView() : _table()),
      ])),
    );
  }

  Widget _toolbar() => Card(child: Padding(padding: const EdgeInsets.all(14), child: Wrap(spacing:12,runSpacing:12,crossAxisAlignment:WrapCrossAlignment.center,children:[
    SizedBox(width:340,child:TextField(controller:search,onSubmitted:(_)=>_cargar(),decoration:InputDecoration(labelText:'Buscar cliente, RUC o documento',prefixIcon:const Icon(Icons.search),suffixIcon:IconButton(onPressed:(){search.clear();_cargar();},icon:const Icon(Icons.clear)),border:const OutlineInputBorder()))),
    SizedBox(width:180,child:DropdownButtonFormField<String>(initialValue:estado,decoration:const InputDecoration(labelText:'Estado',border:OutlineInputBorder()),items:const [DropdownMenuItem(value:'TODOS',child:Text('Todos')),DropdownMenuItem(value:'PENDIENTE',child:Text('Pendiente')),DropdownMenuItem(value:'PROMESA',child:Text('Promesa')),DropdownMenuItem(value:'VENCIDA',child:Text('Vencida')),DropdownMenuItem(value:'PAGADA',child:Text('Pagada'))],onChanged:(v){if(v!=null){setState(()=>estado=v);_cargar();}})),
    SizedBox(width:230,child:DropdownButtonFormField<String>(initialValue:vendedor,decoration:const InputDecoration(labelText:'Vendedor',border:OutlineInputBorder()),items:[const DropdownMenuItem(value:'TODOS',child:Text('Todos')), ...vendedores.map((v)=>DropdownMenuItem(value:v,child:Text(v,overflow:TextOverflow.ellipsis)))],onChanged:(v){if(v!=null){setState(()=>vendedor=v);_cargar();}})),
    FilledButton.icon(onPressed:_cargar,icon:const Icon(Icons.filter_alt),label:const Text('Aplicar')),
  ])));

  Widget _kpis()=>Wrap(spacing:12,runSpacing:12,children:[_kpi('Cartera', 'US\$ ${money.format(total)}', azul, Icons.account_balance_wallet),_kpi('Pagado','US\$ ${money.format(pagado)}',verde,Icons.payments),_kpi('Saldo','US\$ ${money.format(saldo)}',rojo,Icons.warning_amber),_kpi('Vencidas','$vencidas',naranja,Icons.event_busy)]);
  Widget _kpi(String t,String v,Color c,IconData i)=>SizedBox(width:220,child:Card(child:Padding(padding:const EdgeInsets.all(15),child:Row(children:[CircleAvatar(backgroundColor:c.withValues(alpha:.1),child:Icon(i,color:c)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(t,style:const TextStyle(color:Colors.grey)),Text(v,style:TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:c))]))]))));

  Widget _table(){
    if(rows.isEmpty)return const Center(child:Text('No hay cobranzas para los filtros seleccionados.'));
    return Card(child: Scrollbar(thumbVisibility:true,child:SingleChildScrollView(scrollDirection:Axis.vertical,child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(columns:const [DataColumn(label:Text('VENCIMIENTO')),DataColumn(label:Text('CLIENTE')),DataColumn(label:Text('DOCUMENTO')),DataColumn(label:Text('VENDEDOR')),DataColumn(label:Text('FACTURA')),DataColumn(label:Text('PAGADO')),DataColumn(label:Text('SALDO')),DataColumn(label:Text('ESTADO')),DataColumn(label:Text('ACCIONES'))],rows:rows.map((r){final e=_s(r['estado']);return DataRow(cells:[DataCell(Text(_dt(r['fecha_vencimiento'])==null?'—':date.format(_dt(r['fecha_vencimiento'])!))),DataCell(Text(_s(r['codigo_cliente']))),DataCell(Text(_s(r['documento']).isEmpty?'—':_s(r['documento']))),DataCell(Text(_s(r['vendedor']))),DataCell(Text('US\$ ${money.format(_n(r['monto_factura']))}')),DataCell(Text('US\$ ${money.format(_n(r['monto_pagado']))}')),DataCell(Text('US\$ ${money.format(_n(r['saldo']))}',style:TextStyle(fontWeight:FontWeight.w800,color:_estadoColor(e)))),DataCell(Chip(label:Text(e),avatar:Icon(e=='PAGADA'?Icons.check:e=='VENCIDA'?Icons.warning_amber:Icons.schedule,size:16,color:_estadoColor(e)))),DataCell(IconButton(tooltip:'Registrar pago / actualizar',onPressed:()=>_registrarPago(r),icon:const Icon(Icons.edit_note)))]);}).toList())))));
  }

  Widget _errorView()=>Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.error_outline,size:50,color:rojo),const SizedBox(height:10),Text(error??'Error'),const SizedBox(height:12),FilledButton(onPressed:_cargar,child:const Text('Reintentar'))]));
}
