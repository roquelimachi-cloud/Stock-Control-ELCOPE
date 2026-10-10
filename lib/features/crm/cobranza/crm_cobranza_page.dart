import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
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
  static const verde = Color(0xFF00C98D);
  static const fondo = Color(0xFF06263B);
  static const panel = Color(0xFF0A3550);
  static const panelClaro = Color(0xFF104361);
  static const borde = Color(0xFF176184);
  static const texto = Color(0xFFF4F8FC);
  static const textoSuave = Color(0xFFAAC4D6);
  static const rojo = Color(0xFFFF5364);
  static const naranja = Color(0xFFFFA31A);

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

  bool get _puedeImportar =>
      Sesion.esAdministrador ||
      ['administrador', 'gerencia'].contains(Sesion.rol.trim().toLowerCase());

  String _normalizarColumna(dynamic value) => '$value'
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  String _celdaTexto(dynamic value) {
    if (value == null) return '';
    return '$value'.trim();
  }

  double _celdaNumero(dynamic value) {
    if (value is num) return value.toDouble();
    var raw = _celdaTexto(value).replaceAll('S/', '').replaceAll('US\$', '').replaceAll(' ', '');
    if (raw.contains(',') && raw.contains('.')) {
      raw = raw.lastIndexOf(',') > raw.lastIndexOf('.')
          ? raw.replaceAll('.', '').replaceAll(',', '.')
          : raw.replaceAll(',', '');
    } else if (raw.contains(',')) {
      raw = raw.replaceAll(',', '.');
    }
    return double.tryParse(raw) ?? 0;
  }

  String? _celdaFecha(dynamic value) {
    if (value == null || '$value'.trim().isEmpty) return null;
    DateTime? d;
    if (value is DateTime) d = value;
    if (value is num) {
      // Excel usa 1899-12-30 como origen para sus fechas serializadas.
      d = DateTime(1899, 12, 30).add(Duration(days: value.floor()));
    }
    final raw = _celdaTexto(value);
    d ??= DateTime.tryParse(raw);
    if (d == null) {
      for (final f in ['dd/MM/yyyy', 'd/M/yyyy', 'dd-MM-yyyy', 'd-M-yyyy']) {
        try { d = DateFormat(f).parseStrict(raw); break; } catch (_) {}
      }
    }
    return d == null ? null : DateFormat('yyyy-MM-dd').format(d);
  }

  Future<void> _importarExcel() async {
    if (!_puedeImportar) {
      _msg('Solo Administrador o Gerencia puede importar cobranzas.');
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) throw Exception('No se pudieron leer los datos del archivo.');
      final workbook = Excel.decodeBytes(Uint8List.fromList(bytes));
      Sheet? sheet;
      for (final candidate in workbook.tables.values) {
        if (candidate.rows.length > 1) { sheet = candidate; break; }
      }
      if (sheet == null) throw Exception('El archivo no tiene filas para importar.');

      final headers = <String, int>{};
      final first = sheet.rows.first;
      for (var i = 0; i < first.length; i++) {
        final h = _normalizarColumna(first[i]?.value);
        if (h.isNotEmpty) headers[h] = i;
      }
      int col(List<String> names) {
        for (final name in names) {
          final index = headers[_normalizarColumna(name)];
          if (index != null) return index;
        }
        return -1;
      }
      dynamic cell(List<Data?> row, List<String> names) {
        final i = col(names);
        return i < 0 || i >= row.length ? null : row[i]?.value;
      }

      final cCliente = col(['codigo_cliente', 'codigo cliente', 'codigo', 'ruc', 'cliente', 'razon social', 'razon_social']);
      final cMonto = col(['monto_factura', 'monto factura', 'importe', 'total factura', 'total', 'monto', 'deuda']);
      final cVence = col(['fecha_vencimiento', 'fecha vencimiento', 'vencimiento', 'fecha de vencimiento']);
      if (cCliente < 0 || cMonto < 0 || cVence < 0) {
        throw Exception('Faltan columnas obligatorias. Se requiere código/RUC del cliente, monto de factura y fecha de vencimiento.');
      }

      final parsed = <Map<String, dynamic>>[];
      var omitidas = 0;
      for (final row in sheet.rows.skip(1)) {
        final codigo = _celdaTexto(cell(row, ['codigo_cliente', 'codigo cliente', 'codigo', 'ruc']));
        final documento = _celdaTexto(cell(row, ['documento', 'factura', 'numero_factura', 'numero factura', 'nro factura', 'comprobante']));
        final vencimiento = _celdaFecha(cell(row, ['fecha_vencimiento', 'fecha vencimiento', 'vencimiento', 'fecha de vencimiento']));
        final montoFactura = _celdaNumero(cell(row, ['monto_factura', 'monto factura', 'importe', 'total factura', 'total', 'monto', 'deuda']));
        if (codigo.isEmpty || vencimiento == null || montoFactura <= 0) { omitidas++; continue; }
        parsed.add({
          'codigo_cliente': codigo,
          'documento': documento,
          'fecha_emision': _celdaFecha(cell(row, ['fecha_emision', 'fecha emision', 'fecha factura', 'fecha'])) ,
          'fecha_vencimiento': vencimiento,
          'monto_factura': montoFactura,
          'monto_pagado': _celdaNumero(cell(row, ['monto_pagado', 'monto pagado', 'pagado', 'cobrado', 'importe cobrado'])),
          'vendedor': _celdaTexto(cell(row, ['vendedor', 'asesor comercial'])),
          'observacion': _celdaTexto(cell(row, ['observacion', 'observación', 'comentario'])),
        });
      }
      if (parsed.isEmpty) throw Exception('No se encontraron filas válidas. Revisa los encabezados y las fechas.');
      if (!mounted) return;
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar importación de cobranzas'),
          content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Archivo: ${result.files.single.name}'),
            const SizedBox(height: 8),
            Text('Filas listas para importar: ${parsed.length}', style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('Filas omitidas por datos incompletos: $omitidas'),
            const SizedBox(height: 10),
            const Text('Se revisarán duplicados por cliente y documento antes de registrar. Confirma que el archivo corresponde a la tabla especial de cobranzas.'),
            const SizedBox(height: 10),
            Container(height: 150, decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)), child: ListView.builder(itemCount: parsed.length < 6 ? parsed.length : 6, itemBuilder: (_, i) {
              final r = parsed[i];
              return ListTile(dense: true, title: Text('${r['codigo_cliente']} · ${r['documento'].toString().isEmpty ? 'Sin documento' : r['documento']}'), subtitle: Text('Vence ${r['fecha_vencimiento']} · US\$ ${money.format(r['monto_factura'])}'));
            })),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.cloud_upload_outlined), label: const Text('Importar'))],
        ),
      );
      if (confirmar != true) return;

      // Detecta duplicados sin borrar ni sobrescribir registros existentes.
      final existentesData = await db.from('crm_cobranzas').select('codigo_cliente,documento').limit(10000);
      final existentes = <String>{};
      for (final e in existentesData as List) {
        final m = Map<String, dynamic>.from(e);
        existentes.add('${_s(m['codigo_cliente'])}|${_s(m['documento']).toUpperCase()}');
      }
      var insertadas = 0;
      var duplicadas = 0;
      var errores = 0;
      for (final r in parsed) {
        final codigo = _s(r['codigo_cliente']);
        final documento = _s(r['documento']);
        final key = '$codigo|${documento.toUpperCase()}';
        if (documento.isNotEmpty && existentes.contains(key)) { duplicadas++; continue; }
        try {
          await db.rpc('crm_registrar_cobranza', params: {
            'p_codigo_cliente': codigo,
            'p_factura_id': null,
            'p_documento': documento.isEmpty ? null : documento,
            'p_fecha_emision': r['fecha_emision'],
            'p_fecha_vencimiento': r['fecha_vencimiento'],
            'p_monto_factura': r['monto_factura'],
            'p_monto_pagado': r['monto_pagado'],
            'p_fecha_ultimo_pago': null,
            'p_observacion': _s(r['observacion']).isEmpty ? 'Importado desde ${result.files.single.name}' : r['observacion'],
            'p_vendedor': _s(r['vendedor']).isEmpty ? null : r['vendedor'],
            'p_usuario_id': Sesion.idUsuario,
          });
          insertadas++;
          if (documento.isNotEmpty) existentes.add(key);
        } catch (_) { errores++; }
      }
      await _cargar();
      if (mounted) _msg('Importación finalizada. Insertadas: $insertadas · Duplicadas: $duplicadas · Con error: $errores · Omitidas: $omitidas.');
    } catch (e) {
      if (mounted) _msg('No se pudo importar el archivo: $e');
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
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: fondo,
        cardColor: panel,
        canvasColor: panel,
        dividerColor: borde,
        colorScheme: base.colorScheme.copyWith(
          brightness: Brightness.dark,
          primary: const Color(0xFF12B8FF),
          secondary: verde,
          surface: panel,
          onSurface: texto,
          error: rojo,
        ),
        textTheme: base.textTheme.apply(bodyColor: texto, displayColor: texto),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panelClaro,
          labelStyle: const TextStyle(color: textoSuave),
          hintStyle: const TextStyle(color: textoSuave),
          prefixIconColor: const Color(0xFF12B8FF),
          suffixIconColor: textoSuave,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borde)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borde)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF12B8FF), width: 1.5)),
        ),
        dataTableTheme: const DataTableThemeData(
          headingRowColor: WidgetStatePropertyAll(Color(0xFF104361)),
          dataRowColor: WidgetStatePropertyAll(Color(0xFF0A3550)),
          headingTextStyle: TextStyle(color: texto, fontWeight: FontWeight.w800),
          dataTextStyle: TextStyle(color: texto),
          dividerThickness: 0.7,
        ),
      ),
      child: Scaffold(
        backgroundColor: fondo,
        appBar: AppBar(
          backgroundColor: azul,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('Cobranza CRM', style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            if (_puedeImportar)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: FilledButton.icon(
                  onPressed: _importarExcel,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Importar'),
                  style: FilledButton.styleFrom(backgroundColor: verde, foregroundColor: const Color(0xFF032D37)),
                ),
              ),
            IconButton(tooltip: 'Actualizar', onPressed: loading ? null : _cargar, icon: const Icon(Icons.refresh)),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _nuevaCobranza,
          backgroundColor: verde,
          foregroundColor: const Color(0xFF032D37),
          icon: const Icon(Icons.add),
          label: const Text('Nueva cobranza', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            _toolbar(),
            const SizedBox(height: 16),
            _kpis(),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: borde)),
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                        ? _errorView()
                        : _table(),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _toolbar() => Card(color: panel, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: borde)), child: Padding(padding: const EdgeInsets.all(14), child: Wrap(spacing:12,runSpacing:12,crossAxisAlignment:WrapCrossAlignment.center,children:[
    SizedBox(width:340,child:TextField(controller:search,onSubmitted:(_)=>_cargar(),decoration:InputDecoration(labelText:'Buscar cliente, RUC o documento',prefixIcon:const Icon(Icons.search),suffixIcon:IconButton(onPressed:(){search.clear();_cargar();},icon:const Icon(Icons.clear)),border:const OutlineInputBorder()))),
    SizedBox(width:180,child:DropdownButtonFormField<String>(initialValue:estado,decoration:const InputDecoration(labelText:'Estado',border:OutlineInputBorder()),items:const [DropdownMenuItem(value:'TODOS',child:Text('Todos')),DropdownMenuItem(value:'PENDIENTE',child:Text('Pendiente')),DropdownMenuItem(value:'PROMESA',child:Text('Promesa')),DropdownMenuItem(value:'VENCIDA',child:Text('Vencida')),DropdownMenuItem(value:'PAGADA',child:Text('Pagada'))],onChanged:(v){if(v!=null){setState(()=>estado=v);_cargar();}})),
    SizedBox(width:230,child:DropdownButtonFormField<String>(initialValue:vendedor,decoration:const InputDecoration(labelText:'Vendedor',border:OutlineInputBorder()),items:[const DropdownMenuItem(value:'TODOS',child:Text('Todos')), ...vendedores.map((v)=>DropdownMenuItem(value:v,child:Text(v,overflow:TextOverflow.ellipsis)))],onChanged:(v){if(v!=null){setState(()=>vendedor=v);_cargar();}})),
    FilledButton.icon(onPressed:_cargar,icon:const Icon(Icons.filter_alt),label:const Text('Aplicar')),
  ])));

  Widget _kpis()=>Wrap(spacing:12,runSpacing:12,children:[_kpi('Cartera', 'US\$ ${money.format(total)}', azul, Icons.account_balance_wallet),_kpi('Pagado','US\$ ${money.format(pagado)}',verde,Icons.payments),_kpi('Saldo','US\$ ${money.format(saldo)}',rojo,Icons.warning_amber),_kpi('Vencidas','$vencidas',naranja,Icons.event_busy)]);
  Widget _kpi(String t,String v,Color c,IconData i)=>SizedBox(width:220,child:Card(color:panel,elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),side:const BorderSide(color:borde)),child:Padding(padding:const EdgeInsets.all(15),child:Row(children:[CircleAvatar(backgroundColor:c.withValues(alpha:.14),child:Icon(i,color:c)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(t,style:const TextStyle(color:textoSuave)),Text(v,style:TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:c))]))]))));

  Future<List<Map<String, dynamic>>> _buscarClientePorCodigo(String codigo) async {
    if (codigo.isEmpty) return [];
    final data = await db.from('clientes').select('codigo,razon_social,nombre').eq('codigo', codigo).limit(1);
    return List<Map<String, dynamic>>.from(data);
  }

  Widget _table(){
    if(rows.isEmpty)return const Center(child:Padding(padding:EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.receipt_long_outlined,size:48,color:Color(0xFF12B8FF)),SizedBox(height:12),Text('No hay cobranzas para los filtros seleccionados.',style:TextStyle(color:texto,fontWeight:FontWeight.w700,fontSize:16)),SizedBox(height:6),Text('Importa tu archivo o registra una cobranza para comenzar.',style:TextStyle(color:textoSuave))])));
    return Card(color:panel,elevation:0,child: Scrollbar(thumbVisibility:true,child:SingleChildScrollView(scrollDirection:Axis.vertical,child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(columns:const [DataColumn(label:Text('VENCIMIENTO')),DataColumn(label:Text('CLIENTE')),DataColumn(label:Text('DOCUMENTO')),DataColumn(label:Text('VENDEDOR')),DataColumn(label:Text('FACTURA')),DataColumn(label:Text('PAGADO')),DataColumn(label:Text('SALDO')),DataColumn(label:Text('ESTADO')),DataColumn(label:Text('ACCIONES'))],rows:rows.map((r){final e=_s(r['estado']);return DataRow(cells:[DataCell(Text(_dt(r['fecha_vencimiento'])==null?'—':date.format(_dt(r['fecha_vencimiento'])!))),DataCell(SizedBox(width:220, child: FutureBuilder<List<Map<String, dynamic>>>(future: _buscarClientePorCodigo(_s(r['codigo_cliente'])), builder: (context, snapshot) { final cl = snapshot.data?.isNotEmpty == true ? snapshot.data!.first : null; final nombre = cl == null ? '' : (_s(cl['razon_social']).isNotEmpty ? _s(cl['razon_social']) : _s(cl['nombre'])); return Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Text(nombre.isEmpty ? _s(r['codigo_cliente']) : nombre,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w700)),if(nombre.isNotEmpty) Text(_s(r['codigo_cliente']),style:const TextStyle(color:textoSuave,fontSize:11))]); }))),DataCell(Text(_s(r['documento']).isEmpty?'—':_s(r['documento']))),DataCell(Text(_s(r['vendedor']))),DataCell(Text('US\$ ${money.format(_n(r['monto_factura']))}')),DataCell(Text('US\$ ${money.format(_n(r['monto_pagado']))}')),DataCell(Text('US\$ ${money.format(_n(r['saldo']))}',style:TextStyle(fontWeight:FontWeight.w800,color:_estadoColor(e)))),DataCell(Chip(label:Text(e),avatar:Icon(e=='PAGADA'?Icons.check:e=='VENCIDA'?Icons.warning_amber:Icons.schedule,size:16,color:_estadoColor(e)))),DataCell(IconButton(tooltip:'Registrar pago / actualizar',onPressed:()=>_registrarPago(r),icon:const Icon(Icons.edit_note)))]);}).toList())))));
  }

  Widget _errorView()=>Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.error_outline,size:50,color:rojo),const SizedBox(height:10),Text(error??'Error'),const SizedBox(height:12),FilledButton(onPressed:_cargar,child:const Text('Reintentar'))]));
}
