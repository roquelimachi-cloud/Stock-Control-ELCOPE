import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../services/sesion.dart';
import '../../../services/supabase/supabase_service.dart';
import '../dashboard/crm_dashboard_page.dart';

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
  bool _cargandoAccesoModulo = true;
  bool _permisoVerModulo = false;
  bool _permisoCrearModulo = false;
  bool _permisoEditarModulo = false;
  bool _permisoImprimirModulo = false;
  String? error;
  String estado = 'TODOS';
  String vendedor = 'TODOS';
  String filtroCliente = 'TODOS';
  String filtroDias = 'TODOS';
  String filtroCanal = 'TODOS';
  String filtroSector = 'TODOS';
  String filtroPunto = 'TODOS';
  int filtroAnio = 2026;
  int _tabSeleccionada = 0;
  List<String>? vendedoresPermitidos;
  String _vendedorSesionEfectivo = '';
  List<String> vendedores = [];
  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>>? _cacheCobranza;
  Map<String, Map<String, dynamic>> _clientesPorCodigo = {};
  bool _cargandoBase = false;
  bool _cargandoComisiones = false;
  bool _comisionesCargadas = false;
  DateTime _fechaCorteComision = DateTime.now();
  List<Map<String, dynamic>> _filasComision = [];
  String? _errorComisiones;
  final Map<String, List<String>> opcionesFiltros = {}; 

  // En Cobranza el importe de seguimiento y pago se presenta siempre en dólares.
  double get total => rows.fold(0, (a, r) => a + _n(r['monto_factura']));
  double get pagado => rows.fold(0, (a, r) => a + _n(r['monto_pagado']));
  double get saldo => rows.fold<double>(0, (a, r) => a + _n(r['saldo']).clamp(0, double.infinity).toDouble());
  double get igvTotal => rows.fold(0, (a, r) => a + _n(r['igv_factura_usd']));
  int get vencidas => rows.where((r) => ['VENCIDO', 'VENCIDO PARCIAL'].contains(_s(r['estado']))).length;

  bool get esAdmin => Sesion.esAdministrador || Sesion.rol.trim().toLowerCase() == 'administrador';
  bool get _puedeVerModulo => esAdmin || _permisoVerModulo;
  bool get _puedeCrearModulo => esAdmin || _permisoCrearModulo;
  bool get _puedeEditarModulo => esAdmin || _permisoEditarModulo;
  bool get _puedeImprimirModulo => esAdmin || _permisoImprimirModulo;
  bool get esGerencia => ['gerencia', 'administrador'].contains(Sesion.rol.trim().toLowerCase()) || Sesion.esAdministrador;
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

  Future<String> _resolverVendedorSesion() async {
    final directo = Sesion.vendedor.trim();
    if (directo.isNotEmpty) return directo;
    try {
      final usuario = await db.from('usuarios')
          .select('vendedor,vendedor_id')
          .eq('id', Sesion.idUsuario)
          .maybeSingle();
      final nombre = _s(usuario?['vendedor']);
      if (nombre.isNotEmpty) return nombre;
      final id = usuario?['vendedor_id'];
      if (id != null) {
        final vendedorRow = await db.from('vendedores')
            .select('nombre,codigo')
            .eq('id', id)
            .maybeSingle();
        final nombreVendedor = _s(vendedorRow?['nombre']);
        if (nombreVendedor.isNotEmpty) return nombreVendedor;
      }
    } catch (_) {}
    return '';
  }

  bool get _esPerfilConCarteraPropia {
    final rol = Sesion.rol.trim().toLowerCase();
    return rol != 'gerencia' &&
        rol != 'jefe lima' &&
        rol != 'jefe provincia' &&
        !rol.contains('licit');
  }

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
    await _cargarPermisosModulo();
    if (!_puedeVerModulo) {
      if (mounted) setState(() { _cargandoAccesoModulo = false; loading = false; });
      return;
    }
    _vendedorSesionEfectivo = await _resolverVendedorSesion();
    await _cargarPermisos();
    await _cargar();
  }

  // Consulta los permisos configurados por el administrador en Usuarios y Accesos.
  // Si no existe una asignación, el acceso queda denegado (salvo administrador).
  Future<void> _cargarPermisosModulo() async {
    if (esAdmin) {
      _permisoVerModulo = true;
      _permisoCrearModulo = true;
      _permisoEditarModulo = true;
      _permisoImprimirModulo = true;
      if (mounted) setState(() => _cargandoAccesoModulo = false);
      return;
    }
    try {
      final modulo = await db.from('accesos_modulos')
          .select('id').eq('codigo', 'crm_cobranza').maybeSingle();
      final moduloId = modulo?['id'];
      if (moduloId != null && Sesion.idUsuario != null) {
        final acceso = await db.from('accesos_usuario')
            .select('puede_ver,puede_crear,puede_editar,puede_imprimir')
            .eq('usuario_id', Sesion.idUsuario)
            .eq('modulo_id', moduloId).maybeSingle();
        _permisoVerModulo = acceso?['puede_ver'] == true;
        _permisoCrearModulo = acceso?['puede_crear'] == true;
        _permisoEditarModulo = acceso?['puede_editar'] == true;
        _permisoImprimirModulo = acceso?['puede_imprimir'] == true;
      }
    } catch (_) {
      _permisoVerModulo = false;
      _permisoCrearModulo = false;
      _permisoEditarModulo = false;
      _permisoImprimirModulo = false;
    } finally {
      if (mounted) setState(() => _cargandoAccesoModulo = false);
    }
  }

  Future<void> _cargarPermisos() async {
    try {
      final rol = Sesion.rol.trim().toLowerCase();
      // Gerencia puede ver el consolidado. Los perfiles operativos siempre
      // respetan la asignación del usuario, incluso si tienen permiso admin.
      if (rol == 'gerencia') {
        vendedoresPermitidos = null;
      } else if (rol == 'jefe lima' || rol == 'jefe provincia') {
        final data = await db.from('usuario_permisos')
            .select('vendedor,ver_produccion')
            .eq('usuario_jefe_id', Sesion.idUsuario)
            .eq('ver_produccion', true);
        final set = <String>{};
        for (final x in data as List) {
          final v = _s(x['vendedor']);
          if (v.isNotEmpty) set.add(v);
        }
        if (_vendedorSesionEfectivo.isNotEmpty) set.add(_vendedorSesionEfectivo);
        vendedoresPermitidos = set.toList()..sort();
      } else if (rol.contains('licit')) {
        vendedoresPermitidos = null; // se restringe por canal/sector de licitación
      } else {
        // Perfil vendedor/asesor: no mostrar nunca la cartera completa.
        vendedoresPermitidos = _vendedorSesionEfectivo.isEmpty
            ? <String>[]
            : <String>[_vendedorSesionEfectivo];
      }
      vendedores = vendedoresPermitidos == null
          ? await _todosVendedores()
          : List<String>.from(vendedoresPermitidos!);
    } catch (_) {
      // Ante un fallo de permisos, cerrar el acceso en vez de mostrar todos.
      vendedoresPermitidos = _vendedorSesionEfectivo.isEmpty
          ? <String>[]
          : <String>[_vendedorSesionEfectivo];
      vendedores = List<String>.from(vendedoresPermitidos!);
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

  String _normalizar(String value) => value.trim().toUpperCase().replaceAll('Á','A').replaceAll('É','E').replaceAll('Í','I').replaceAll('Ó','O').replaceAll('Ú','U');

  bool get _esVendedor => !esGerencia && !esJefatura && !esAdmin &&
      !Sesion.rol.toLowerCase().contains('licit');
  bool get _esLicitacion => Sesion.rol.toLowerCase().contains('licit');
  bool get _esJefeLima => Sesion.rol.toLowerCase().contains('jefe lima');
  bool get _esJefeProvincia => Sesion.rol.toLowerCase().contains('jefe provincia');

  bool _clienteDentroDeAmbito(Map<String, dynamic> x) {
    final cl = _clientesPorCodigo[_s(x['codigo_cliente'])];
    final departamento = _normalizar(_s(cl?['departamento']));
    final sector = _normalizar(_s(cl?['sector']));
    final canal = _normalizar(_s(x['canal']));
    final vendedorFila = _normalizar(_s(x['vendedor']));

    // Licitaciones conserva su ámbito específico.
    if (_esLicitacion) return sector.contains('LICIT') || canal.contains('LICIT');

    // Primero se limita por zona. Jefe Lima incluye Lima y Callao;
    // Jefe Provincia excluye ambas regiones.
    if (_esJefeLima && departamento != 'LIMA' && departamento != 'CALLAO') {
      return false;
    }
    if (_esJefeProvincia &&
        (departamento.isEmpty || departamento == 'LIMA' || departamento == 'CALLAO')) {
      return false;
    }

    // Para jefaturas también se respeta la asignación de vendedores configurada
    // en usuario_permisos. Si existe una lista asignada, no se muestran vendedores
    // ajenos a ella. La zona sigue siendo obligatoria aunque la lista esté vacía.
    if (esJefatura &&
        vendedoresPermitidos != null &&
        vendedoresPermitidos!.isNotEmpty &&
        !vendedoresPermitidos!.any((v) => _normalizar(v) == vendedorFila)) {
      return false;
    }

    // Los perfiles comerciales individuales solo ven su propia cartera.
    if (_esPerfilConCarteraPropia &&
        (vendedoresPermitidos == null ||
            vendedoresPermitidos!.isEmpty ||
            !vendedoresPermitidos!.any((v) => _normalizar(v) == vendedorFila))) {
      return false;
    }
    return true;
  }

  Future<void> _cargarBaseSiHaceFalta() async {
    if (_cacheCobranza != null && _clientesPorCodigo.isNotEmpty) return;
    if (_cargandoBase) return;
    _cargandoBase = true;
    try {
      if (_cacheCobranza == null) {
        final all = <Map<String, dynamic>>[];
        const pageSize = 1000;
        var offset = 0;
        while (true) {
          var query = db.from('crm_cobranzas_excel_staging').select('*');
          if (_esPerfilConCarteraPropia) {
            // Filtrar en Supabase para evitar descargar las 29 mil filas.
            if (_vendedorSesionEfectivo.isEmpty) {
              _cacheCobranza = <Map<String, dynamic>>[];
              break;
            }
            query = query.eq('vendedor', _vendedorSesionEfectivo);
          }
          final page = await query
              .order('fecha_factura', ascending: false).order('id', ascending: false)
              .range(offset, offset + pageSize - 1);
          final batch = List<Map<String, dynamic>>.from(page as List);
          all.addAll(batch);
          if (batch.length < pageSize) break;
          offset += pageSize;
        }
        _cacheCobranza = all;
      }
      // Cargar una sola vez el catálogo de clientes; así la tabla no ejecuta una
      // consulta Supabase por cada fila y los filtros sector/zona tienen datos reales.
      if (_clientesPorCodigo.isEmpty) {
        const pageSize = 1000;
        var offset = 0;
        while (true) {
          var clientesQuery = db.from('clientes')
              .select('codigo,razon_social,nombre,ruc,vendedor,departamento,sector,canal');
          if (_esPerfilConCarteraPropia && _vendedorSesionEfectivo.isNotEmpty) {
            clientesQuery = clientesQuery.eq('vendedor', _vendedorSesionEfectivo);
          }
          final page = await clientesQuery
              .order('id', ascending: true).range(offset, offset + pageSize - 1);
          final batch = List<Map<String, dynamic>>.from(page as List);
          for (final c in batch) {
            final code = _s(c['codigo']);
            if (code.isNotEmpty) _clientesPorCodigo[code] = c;
          }
          if (batch.length < pageSize) break;
          offset += pageSize;
        }
      }
    } finally {
      _cargandoBase = false;
    }
  }

  Future<void> _cargar() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      await _cargarBaseSiHaceFalta();
      final rawRows = _cacheCobranza ?? <Map<String, dynamic>>[];
      final hoy = DateTime.now();
      final mapped = <Map<String, dynamic>>[];
      final valores = <String, Set<String>>{
        'cliente': <String>{}, 'canal': <String>{}, 'sector': <String>{}, 'punto_factura': <String>{}
      };
      for (final item in rawRows) {
        final x = Map<String, dynamic>.from(item);
        final codigo = _s(x['codigo_cliente']);
        final cl = _clientesPorCodigo[codigo];
        final v = _s(x['vendedor']);
        final clienteNombre = _s(x['cliente']).isNotEmpty ? _s(x['cliente']) : _s(cl?['razon_social']).isNotEmpty ? _s(cl?['razon_social']) : _s(cl?['nombre']);
        x['cliente_mostrar'] = clienteNombre;
        x['sector'] = _s(cl?['sector']);
        x['departamento_cliente'] = _s(cl?['departamento']);
        // Restringir por perfil antes de generar KPIs, gráficos y filas.
        if (!_clienteDentroDeAmbito(x)) continue;
        if (vendedor != 'TODOS' && _normalizar(v) != _normalizar(vendedor)) continue;
        if (_esPerfilConCarteraPropia && (vendedoresPermitidos == null || !vendedoresPermitidos!.any((permitido) => _normalizar(permitido) == _normalizar(v)))) continue;
        valores['cliente']!.add(clienteNombre);
        if (_s(x['canal']).isNotEmpty) valores['canal']!.add(_s(x['canal']));
        if (_s(x['sector']).isNotEmpty) valores['sector']!.add(_s(x['sector']));
        if (_s(x['punto_factura']).isNotEmpty) valores['punto_factura']!.add(_s(x['punto_factura']));
        final doc = '${_s(x['punto_factura'])}-${_s(x['numero_factura'])}';
        final fechaDoc = _dt(x['fecha_factura']);
        if (fechaDoc != null && fechaDoc.year != filtroAnio) continue;
        if (filtroCliente != 'TODOS' && clienteNombre != filtroCliente) continue;
        if (filtroCanal != 'TODOS' && _s(x['canal']) != filtroCanal) continue;
        if (filtroSector != 'TODOS' && _s(x['sector']) != filtroSector) continue;
        if (filtroPunto != 'TODOS' && _s(x['punto_factura']) != filtroPunto) continue;
        final q = search.text.trim().toLowerCase();
        if (q.isNotEmpty && !('$clienteNombre ${_s(cl?['ruc'])} $codigo $doc ${_s(x['numero_factura'])}'.toLowerCase().contains(q))) continue;
        // Toda la analítica comercial y la base de comisión se presenta SIN IGV.
        // El Excel no trae un campo de pago neto, por eso el pago se prorratea
        // por la proporción neto/total de cada documento, manteniendo el bruto original.
        final totalBruto = _n(x['valor_total_factura_dolares']);
        final netoFactura = _n(x['valor_neto_factura_dolares']);
        final igvFactura = _n(x['valor_igv_factura_dolares']);
        final pagadoBruto = _n(x['importe_pagado_dolares']);
        final saldoBruto = _n(x['saldo_dolares']);
        final proporcionNeta = totalBruto.abs() > 0.01 ? netoFactura / totalBruto : 0.0;
        final pagadoNeto = pagadoBruto * proporcionNeta;
        final saldoNeto = netoFactura - pagadoNeto;
        final monto = netoFactura;
        final pagadoDoc = pagadoNeto;
        final saldoDoc = saldoNeto;
        final vcto = _dt(x['fecha_factura_vcto']);
        final hoyDia = DateTime(hoy.year, hoy.month, hoy.day);
        final vencida = vcto != null && DateTime(vcto.year, vcto.month, vcto.day).isBefore(hoyDia);
        final String est;
        if (saldoBruto.abs() <= 0.01) { est = 'PAGADO'; }
        else if (vencida && pagadoBruto > 0.01 && saldoBruto > 0.01) { est = 'VENCIDO PARCIAL'; }
        else if (vencida && saldoBruto > 0.01) { est = 'VENCIDO'; }
        else { est = 'PENDIENTE'; }
        if (estado != 'TODOS' && estado != est) continue;
        final diasAtraso = vcto == null ? 0 : hoyDia.difference(DateTime(vcto.year, vcto.month, vcto.day)).inDays;
        if (filtroDias == 'VENCIDO' && diasAtraso <= 0) continue;
        if (filtroDias == '1-30' && (diasAtraso < 1 || diasAtraso > 30)) continue;
        if (filtroDias == '31-60' && (diasAtraso < 31 || diasAtraso > 60)) continue;
        if (filtroDias == '61-90' && (diasAtraso < 61 || diasAtraso > 90)) continue;
        if (filtroDias == '90+' && diasAtraso <= 90) continue;
        if (filtroDias == 'AL_DIA' && diasAtraso > 0) continue;
        mapped.add({...x, 'documento': doc, 'fecha_vencimiento': x['fecha_factura_vcto'], 'monto_factura_bruto': totalBruto, 'monto_pagado_bruto': pagadoBruto, 'saldo_bruto': saldoBruto, 'monto_factura': monto, 'monto_pagado': pagadoDoc, 'saldo': saldoDoc, 'igv_factura_usd': igvFactura, 'estado': est, 'moneda_documento': 'US\$', 'codigo_cliente': codigo});
      }
      for (final key in valores.keys) { opcionesFiltros[key] = valores[key]!.where((v) => v.isNotEmpty).toList()..sort(); }
      if (!mounted) return;
      setState(() { rows = mapped; loading = false; _comisionesCargadas = false; _filasComision = []; });
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
    if (!_puedeCrearModulo) { _exigirPermiso(false, 'crear'); return; }
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

  // En Cobranza, el permiso CREAR también habilita importar el Excel.
  bool get _puedeImportar => _puedeCrearModulo;

  void _exigirPermiso(bool permitido, String accion) {
    if (!permitido && mounted) _msg('No tienes permiso para $accion en Cobranza. Solicítalo al administrador.');
  }

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
      _msg('No tienes permiso para importar cobranzas. Solicítalo al administrador.');
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
        if (candidate.rows.length > 1) {
          sheet = candidate;
          break;
        }
      }
      if (sheet == null) throw Exception('El archivo no contiene filas para importar.');

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

      // Las 23 columnas corresponden al Excel especial de cobranzas de ELCOPE.
      final cCanal = col(['canal']);
      final cCodVendedor = col(['codigo_vendedor', 'codigo vendedor']);
      final cVendedor = col(['vendedor']);
      final cTipo = col(['tipo_doc', 'tipo doc', 'tipo documento']);
      final cPunto = col(['punto_factura', 'punto factura']);
      final cNumero = col(['numero_factura', 'numero factura']);
      final cFecha = col(['fecha_factura', 'fecha factura']);
      final cVcto = col(['fecha_factura_vcto', 'fecha factura vcto', 'fecha_vencimiento', 'fecha vencimiento']);
      final cCodCliente = col(['codigo_cliente', 'codigo cliente']);
      final cCliente = col(['cliente', 'razon social']);
      final cMoneda = col(['moneda']);
      final cNetoS = col(['valor_neto_factura_soles_s', 'valor neto factura soles s', 'valor neto factura soles']);
      final cNetoD = col(['valor_neto_factura_dolares', 'valor neto factura dolares']);
      final cIgvS = col(['valor_igv_factura_soles_s', 'valor igv factura soles s', 'valor igv factura soles']);
      final cIgvD = col(['valor_igv_factura_dolares', 'valor igv factura dolares']);
      final cTotalS = col(['valor_total_factura_soles_s', 'valor total factura soles s', 'valor total factura soles']);
      final cTotalD = col(['valor_total_factura_dolares', 'valor total factura dolares']);
      final cForma = col(['forma_pago', 'forma pago']);
      final cPagadoD = col(['importe_pagado_dolares', 'importe pagado dolares']);
      final cPagadoS = col(['importe_pagado_soles', 'importe pagado soles']);
      final cSaldoD = col(['saldo_dolares', 'saldo dolares']);
      final cSaldoS = col(['saldo_soles', 'saldo soles']);
      final cPeso = col(['peso_kg_cobre', 'peso kg cobre']);

      final obligatorias = <String, int>{
        'Canal': cCanal,
        'Código Vendedor': cCodVendedor,
        'Vendedor': cVendedor,
        'Tipo Doc.': cTipo,
        'Punto Factura': cPunto,
        'Número Factura': cNumero,
        'Fecha Factura': cFecha,
        'Fecha Factura Vcto.': cVcto,
        'Código Cliente': cCodCliente,
        'Cliente': cCliente,
        'Moneda': cMoneda,
      };
      final faltantes = obligatorias.entries.where((e) => e.value < 0).map((e) => e.key).toList();
      if (faltantes.isNotEmpty) {
        throw Exception('Faltan columnas obligatorias: ${faltantes.join(', ')}. Verifica los encabezados del Excel.');
      }

      final parsed = <Map<String, dynamic>>[];
      var omitidas = 0;
      for (final row in sheet.rows.skip(1)) {
        final codigoCliente = _celdaTexto(cell(row, ['codigo_cliente', 'codigo cliente']));
        final cliente = _celdaTexto(cell(row, ['cliente', 'razon social']));
        final numero = _celdaTexto(cell(row, ['numero_factura', 'numero factura']));
        final fechaFactura = _celdaFecha(cell(row, ['fecha_factura', 'fecha factura']));
        final fechaVcto = _celdaFecha(cell(row, ['fecha_factura_vcto', 'fecha factura vcto', 'fecha_vencimiento', 'fecha vencimiento']));
        if (codigoCliente.isEmpty || cliente.isEmpty || numero.isEmpty || fechaFactura == null || fechaVcto == null) {
          // Ignora solo filas realmente vacías; una fila con contenido pero inválida se contabiliza.
          final tieneDatos = row.any((v) => _celdaTexto(v?.value).isNotEmpty);
          if (tieneDatos) omitidas++;
          continue;
        }
        parsed.add({
          'canal': _celdaTexto(cell(row, ['canal'])),
          'codigo_vendedor': _celdaTexto(cell(row, ['codigo_vendedor', 'codigo vendedor'])),
          'vendedor': _celdaTexto(cell(row, ['vendedor'])),
          'tipo_doc': _celdaTexto(cell(row, ['tipo_doc', 'tipo doc', 'tipo documento'])),
          'punto_factura': _celdaTexto(cell(row, ['punto_factura', 'punto factura'])),
          'numero_factura': numero,
          'fecha_factura': fechaFactura,
          'fecha_factura_vcto': fechaVcto,
          'codigo_cliente': codigoCliente,
          'cliente': cliente,
          'moneda': _celdaTexto(cell(row, ['moneda'])),
          'valor_neto_factura_soles': _celdaNumero(cell(row, ['valor_neto_factura_soles_s', 'valor neto factura soles s', 'valor neto factura soles'])),
          'valor_neto_factura_dolares': _celdaNumero(cell(row, ['valor_neto_factura_dolares', 'valor neto factura dolares'])),
          'valor_igv_factura_soles': _celdaNumero(cell(row, ['valor_igv_factura_soles_s', 'valor igv factura soles s', 'valor igv factura soles'])),
          'valor_igv_factura_dolares': _celdaNumero(cell(row, ['valor_igv_factura_dolares', 'valor igv factura dolares'])),
          'valor_total_factura_soles': _celdaNumero(cell(row, ['valor_total_factura_soles_s', 'valor total factura soles s', 'valor total factura soles'])),
          'valor_total_factura_dolares': _celdaNumero(cell(row, ['valor_total_factura_dolares', 'valor total factura dolares'])),
          'forma_pago': _celdaTexto(cell(row, ['forma_pago', 'forma pago'])),
          'importe_pagado_dolares': _celdaNumero(cell(row, ['importe_pagado_dolares', 'importe pagado dolares'])),
          'importe_pagado_soles': _celdaNumero(cell(row, ['importe_pagado_soles', 'importe pagado soles'])),
          'saldo_dolares': _celdaNumero(cell(row, ['saldo_dolares', 'saldo dolares'])),
          'saldo_soles': _celdaNumero(cell(row, ['saldo_soles', 'saldo soles'])),
          'peso_kg_cobre': _celdaNumero(cell(row, ['peso_kg_cobre', 'peso kg cobre'])),
        });
      }
      if (parsed.isEmpty) throw Exception('No se encontraron filas válidas. Revisa el archivo y las fechas.');
      if (!mounted) return;

      final totalDolares = parsed.fold<double>(0, (sum, r) => sum + _n(r['valor_total_factura_dolares']));
      final totalSoles = parsed.fold<double>(0, (sum, r) => sum + _n(r['valor_total_factura_soles']));
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: panel,
          title: const Text('Vista previa · Importación de cobranzas', style: TextStyle(color: texto, fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 760,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Archivo: ${result.files.single.name}', style: const TextStyle(color: textoSuave)),
              const SizedBox(height: 8),
              Text('Filas válidas: ${parsed.length} · Filas omitidas: $omitidas', style: const TextStyle(color: texto, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Total factura USD: US\$ ${money.format(totalDolares)}', style: const TextStyle(color: verde, fontWeight: FontWeight.w800)),
              Text('Total factura PEN: S/ ${money.format(totalSoles)}', style: const TextStyle(color: texto, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Text('Se reemplazará únicamente la carga temporal anterior. No se modificarán crm_cobranzas, facturas ni comisiones.', style: TextStyle(color: textoSuave)),
              const SizedBox(height: 12),
              Container(
                height: 180,
                decoration: BoxDecoration(border: Border.all(color: borde), borderRadius: BorderRadius.circular(10)),
                child: ListView.builder(
                  itemCount: parsed.length < 8 ? parsed.length : 8,
                  itemBuilder: (_, i) {
                    final r = parsed[i];
                    return ListTile(
                      dense: true,
                      title: Text('${r['cliente']} · ${r['punto_factura']}-${r['numero_factura']}', style: const TextStyle(color: texto)),
                      subtitle: Text('${r['fecha_factura']} → vence ${r['fecha_factura_vcto']} · ${r['moneda']}', style: const TextStyle(color: textoSuave)),
                      trailing: Text('US\$ ${money.format(r['valor_total_factura_dolares'])}', style: const TextStyle(color: verde, fontWeight: FontWeight.w700)),
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.cloud_upload_outlined), label: const Text('Reemplazar carga temporal')),
          ],
        ),
      );
      if (confirmar != true) return;

      // Se opera únicamente sobre la tabla de staging. No se escribe en producción.
      await db.from('crm_cobranzas_excel_staging').delete().gt('id', 0);
      _cacheCobranza = null;
      const batchSize = 250;
      var insertadas = 0;
      for (var i = 0; i < parsed.length; i += batchSize) {
        final fin = (i + batchSize < parsed.length) ? i + batchSize : parsed.length;
        await db.from('crm_cobranzas_excel_staging').insert(parsed.sublist(i, fin));
        insertadas += fin - i;
      }
      if (mounted) {
        _msg('Carga temporal lista: $insertadas filas importadas. Producción y comisiones no fueron modificadas.');
      }
    } catch (e) {
      if (mounted) _msg('No se pudo importar el archivo: $e');
    }
  }

  Future<void> _registrarPago(Map<String, dynamic> row) async {
    if (!_puedeEditarModulo) { _exigirPermiso(false, 'editar o registrar pagos'); return; }
    final pago = TextEditingController(text: _n(row['monto_pagado_bruto'] ?? row['monto_pagado']).toStringAsFixed(2));
    final obs = TextEditingController(text: _s(row['observacion']));
    DateTime? fecha = _dt(row['fecha_ultimo_pago']) ?? DateTime.now();
    String est = _s(row['estado']).isEmpty ? 'PENDIENTE' : _s(row['estado']);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Actualizar cobranza · ${_s(row['documento'])}'),
          content: SizedBox(width: 500, child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Saldo actual con IGV: US\$ ${money.format(_n(row['saldo_bruto'] ?? row['saldo']))}', style: const TextStyle(fontWeight: FontWeight.w800)),
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
    switch (e.trim().toUpperCase()) {
      case 'PAGADO':
      case 'PAGADA':
        return const Color(0xFF168BFF); // Azul: pagado
      case 'PENDIENTE':
        return const Color(0xFFFFFFFF); // Blanco: pendiente
      case 'VENCIDO':
      case 'VENCIDA':
        return const Color(0xFF28B463); // Verde: vencido sin abono
      case 'VENCIDO PARCIAL':
      case 'VENCIDA PARCIAL':
        return const Color(0xFF75DDF2); // Celeste: vencido con abonos
      case 'PROMESA':
        return const Color(0xFFB721FF);
      case 'OBSERVADA':
        return const Color(0xFFFF8A34);
      default:
        return const Color(0xFFFFFFFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoAccesoModulo) {
      return const Scaffold(backgroundColor: fondo, body: Center(child: CircularProgressIndicator()));
    }
    if (!_puedeVerModulo) {
      return Scaffold(backgroundColor: fondo, body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.lock_outline, size: 56, color: naranja), SizedBox(height: 14), Text('Acceso restringido a Cobranza', textAlign: TextAlign.center, style: TextStyle(color: texto, fontSize: 20, fontWeight: FontWeight.w900)), SizedBox(height: 8), Text('Tu usuario no tiene permiso para ver este módulo. Solicita al administrador que lo habilite en Usuarios y Accesos.', textAlign: TextAlign.center, style: TextStyle(color: textoSuave))]))));
    }
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
        body: LayoutBuilder(builder: (context, viewport) {
          final mobile = viewport.maxWidth < 700;
          final compact = viewport.maxWidth < 1000;
          final content = <Widget>[
            _toolbar(),
            const SizedBox(height: 8),
            _kpis(),
            const SizedBox(height: 8),
            if (!loading && error == null) _analisisNeon(),
            const SizedBox(height: 8),
            _tabsCobranza(),
            const SizedBox(height: 4),
          ];
          if (mobile) {
            // En celular, el dashboard completo se desplaza verticalmente; la tabla
            // conserva su desplazamiento horizontal para no recortar columnas.
            return SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ...content,
                SizedBox(
                  height: _tabSeleccionada == 0 ? 700 : 560,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(12), border: Border.all(color: borde)),
                    child: loading ? const Center(child: CircularProgressIndicator()) : error != null ? _errorView() : _contenidoTab(),
                  ),
                ),
              ]),
            );
          }
          return Padding(
            padding: EdgeInsets.all(compact ? 8 : 12),
            child: Column(children: [
              ...content,
              Expanded(child: Container(
                width: double.infinity,
                decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(12), border: Border.all(color: borde)),
                child: loading ? const Center(child: CircularProgressIndicator()) : error != null ? _errorView() : _contenidoTab(),
              )),
            ]),
          );
        }),
      ),
    );
  }

  Widget _analisisNeon() {
    final pagadoTotal = rows.fold<double>(0, (a, r) => a + _n(r['monto_pagado']));
    final saldoTotal = rows.fold<double>(0, (a, r) => a + _n(r['saldo']).clamp(0, double.infinity).toDouble());
    final vencidoRows = rows.where((r) => ['VENCIDO', 'VENCIDO PARCIAL'].contains(_s(r['estado']))).toList();
    final vencidoTotal = vencidoRows.fold<double>(0, (a, r) => a + _n(r['saldo']).clamp(0, double.infinity).toDouble());
    final porCobrar = rows.where((r) => _n(r['saldo']) > 0 && !['VENCIDO', 'VENCIDO PARCIAL'].contains(_s(r['estado']).toUpperCase())).fold<double>(0, (a, r) => a + _n(r['saldo']).clamp(0, double.infinity).toDouble());
    final hoy = DateTime.now();
    final antiguedad = <String, double>{'0–30 días': 0, '31–60 días': 0, '61–90 días': 0, '> 90 días': 0};
    for (final r in rows.where((r) => _n(r['saldo']) > 0)) {
      final vcto = _dt(r['fecha_vencimiento']);
      if (vcto == null) continue;
      final dias = hoy.difference(DateTime(vcto.year, vcto.month, vcto.day)).inDays;
      if (dias <= 0) continue; // La antigüedad solo considera documentos ya vencidos.
      final bucket = dias <= 30 ? '0–30 días' : dias <= 60 ? '31–60 días' : dias <= 90 ? '61–90 días' : '> 90 días';
      antiguedad[bucket] = (antiguedad[bucket] ?? 0) + _n(r['saldo']).clamp(0, double.infinity).toDouble();
    }
    final top = <String, double>{};
    for (final r in rows) {
      final name = _s(r['cliente']).isEmpty ? _s(r['codigo_cliente']) : _s(r['cliente']);
      top[name] = (top[name] ?? 0) + _n(r['saldo']).clamp(0, double.infinity).toDouble();
    }
    final ranking = top.entries.where((e) => e.value > 0).toList()..sort((a,b)=>b.value.compareTo(a.value));
    final neon = <Color>[const Color(0xFF168BFF), const Color(0xFFFFB000), const Color(0xFFB721FF), const Color(0xFFFF3CAC), const Color(0xFF00F5D4)];
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      final medium = constraints.maxWidth >= 560;
      final gap = 8.0;
      final available = constraints.maxWidth - gap * 3;
      final baseWidth = wide ? available / 4 : medium ? (constraints.maxWidth - gap) / 2 : constraints.maxWidth;
      final width = wide ? (available - baseWidth * 1.25) / 3 : baseWidth;
      final topWidth = wide ? baseWidth * 1.25 : baseWidth;
      final h = wide ? 184.0 : medium ? 168.0 : 160.0;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        SizedBox(width: width, height: h, child: _chartPanel('Estado de la cartera', Row(children: [
          SizedBox(width: 100, height: 100, child: CustomPaint(painter: _NeonDonutPainter(values: [pagadoTotal, porCobrar, vencidoTotal], colors: [const Color(0xFF168BFF), const Color(0xFFFFB000), const Color(0xFFFF3CAC)]), child: Center(child: SizedBox(width: 78, child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Saldo', style: TextStyle(color:textoSuave,fontSize:10)), Text('US\$ ${money.format(saldoTotal)}', textAlign:TextAlign.center, style: const TextStyle(color:Color(0xFF00F5D4),fontSize:11,fontWeight:FontWeight.w900))]))))),
          const SizedBox(width: 10), Expanded(child: Column(mainAxisAlignment:MainAxisAlignment.center, children: [_legendNeon('Cobrado',pagadoTotal,const Color(0xFF168BFF)), const SizedBox(height:9), _legendNeon('Por cobrar',porCobrar,const Color(0xFFFFB000)), const SizedBox(height:9), _legendNeon('Vencido',vencidoTotal,const Color(0xFFFF3CAC))]))
        ]))),
        SizedBox(width: width, height: h, child: _chartPanel('Evolución de cobranza', _evolucionMini(neon[1], neon[0], neon[4]))),
        SizedBox(width: width, height: h, child: _chartPanel('Antigüedad de saldos', Row(children: [
          SizedBox(width: 95, height: 95, child: CustomPaint(painter: _NeonDonutPainter(values: antiguedad.values.toList(), colors: [const Color(0xFF00D1FF), const Color(0xFF8B5CF6), const Color(0xFFFFB000), const Color(0xFFFF4D6D)]), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Vencido',style:TextStyle(color:textoSuave,fontSize:10)),Text('US\$ ${money.format(vencidoTotal)}',textAlign:TextAlign.center,style:const TextStyle(color:Color(0xFFFF3CAC),fontSize:10,fontWeight:FontWeight.w900))])))),
          const SizedBox(width: 8), Expanded(child: Column(mainAxisAlignment:MainAxisAlignment.center, children: [for (final e in antiguedad.entries) Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(children:[Container(width:7,height:7,decoration:BoxDecoration(color: [const Color(0xFF00D1FF),const Color(0xFF8B5CF6),const Color(0xFFFFB000),const Color(0xFFFF4D6D)][antiguedad.keys.toList().indexOf(e.key)],borderRadius:BorderRadius.circular(2))),const SizedBox(width:5),Expanded(child:Text(e.key,style:const TextStyle(color:textoSuave,fontSize:9),overflow:TextOverflow.ellipsis)),Text(money.format(e.value),style:const TextStyle(color:texto,fontSize:9,fontWeight:FontWeight.w800))]))]))
        ]))),
        SizedBox(width: topWidth, height: h, child: _chartPanel('Top 10 clientes por saldo', ranking.isEmpty ? const Center(child: Text('Sin saldos pendientes', style: TextStyle(color: textoSuave, fontSize: 11))) : LayoutBuilder(builder: (context, rankBox) {
          final topValue = ranking.take(10).fold<double>(1, (m, e) => e.value > m ? e.value : m);
          return Column(children: [
            for (var i = 0; i < ranking.take(10).length; i++)
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(children: [
                  SizedBox(width: 15, child: Text('${i + 1}', style: TextStyle(color: neon[i % neon.length], fontWeight: FontWeight.w900, fontSize: 10))),
                  Expanded(flex: 5, child: Text(ranking[i].key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: texto, fontWeight: FontWeight.w600))),
                  const SizedBox(width: 7),
                  Expanded(flex: 2, child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: (ranking[i].value / topValue).clamp(0, 1).toDouble(), minHeight: 5, backgroundColor: Colors.white.withValues(alpha: .08), valueColor: AlwaysStoppedAnimation<Color>(neon[i % neon.length])))),
                  const SizedBox(width: 7),
                  SizedBox(width: 72, child: Text(money.format(ranking[i].value), textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, color: neon[i % neon.length], fontWeight: FontWeight.w900))),
                ]),
              )),
          ]);
        }))),
      ]);
    });
  }

  Widget _evolucionMini(Color facturadoColor, Color cobradoColor, Color saldoColor) {
    final facturado = List<double>.filled(12, 0);
    final cobrado = List<double>.filled(12, 0);
    for (final r in rows) {
      final d = _dt(r['fecha_factura']);
      if (d == null || d.year != filtroAnio) continue;
      facturado[d.month - 1] += _n(r['monto_factura']);
      cobrado[d.month - 1] += _n(r['monto_pagado']);
    }
    final maxV = [...facturado, ...cobrado].fold<double>(1, (a, b) => b > a ? b : a);
    const nombresMeses = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _dotLegend(facturadoColor, 'Facturado'),
          const SizedBox(width: 8),
          _dotLegend(cobradoColor, 'Cobrado'),
        ]),
        const SizedBox(height: 6),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(12, (i) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(child: Container(
                              height: facturado[i] <= 0 ? 0 : (facturado[i] / maxV * 82).clamp(2, 82).toDouble(),
                              decoration: BoxDecoration(color: facturadoColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
                            )),
                            const SizedBox(width: 2),
                            Expanded(child: Container(
                              height: cobrado[i] <= 0 ? 0 : (cobrado[i] / maxV * 82).clamp(2, 82).toDouble(),
                              decoration: BoxDecoration(color: cobradoColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
                            )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(nombresMeses[i], style: const TextStyle(color: textoSuave, fontSize: 8)),
                  ],
                ),
              ),
            )),
          ),
        ),
        const SizedBox(height: 3),
        Align(alignment: Alignment.centerRight, child: Text('Importes en US\$ · Año $filtroAnio', style: const TextStyle(color: textoSuave, fontSize: 8))),
      ],
    );
  }

  Widget _dotLegend(Color color, String label) => Row(mainAxisSize:MainAxisSize.min,children:[Container(width:7,height:7,decoration:BoxDecoration(color:color,borderRadius:BorderRadius.circular(2))),const SizedBox(width:4),Text(label,style:const TextStyle(color:textoSuave,fontSize:9))]);

  Widget _chartPanel(String title, Widget child) => Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(12),border:Border.all(color:const Color(0xFF1683B5)),boxShadow:[BoxShadow(color:const Color(0xFF00B7FF).withValues(alpha:.06),blurRadius:10)] ),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:texto,fontWeight:FontWeight.w800,fontSize:13)),const SizedBox(height:10),Expanded(child:child)]));
  Widget _legendNeon(String label,double value,Color color)=>Row(children:[Container(width:10,height:10,decoration:BoxDecoration(color:color,borderRadius:BorderRadius.circular(3),boxShadow:[BoxShadow(color:color.withValues(alpha:.55),blurRadius:8)])),const SizedBox(width:8),Expanded(child:Text(label,style:const TextStyle(color:textoSuave,fontSize:12))),Text('US\$ ${money.format(value)}',style:TextStyle(color:color,fontSize:12,fontWeight:FontWeight.w900))]);
  Widget _miniBar(String label,double value,double max,Color color)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(label,style:const TextStyle(color:textoSuave,fontSize:11))),Text('US\$ ${money.format(value)}',style:TextStyle(color:color,fontSize:11,fontWeight:FontWeight.w800))]),const SizedBox(height:5),ClipRRect(borderRadius:BorderRadius.circular(10),child:LinearProgressIndicator(value:max<=0?0:(value/max).clamp(0,1).toDouble(),minHeight:9,backgroundColor:azul,valueColor:AlwaysStoppedAnimation(color)))]);

  List<String> _opciones(String key) => opcionesFiltros[key] ?? <String>[];

  Widget _filtro(String label, String value, List<String> options, ValueChanged<String?> onChanged, {double width = 125}) => SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      value: options.contains(value) ? value : 'TODOS',
      isExpanded: true,
      decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), isDense: true, labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: texto), floatingLabelBehavior: FloatingLabelBehavior.always, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
      dropdownColor: panelClaro,
      style: const TextStyle(color: texto, fontSize: 11),
      items: options.map((v) => DropdownMenuItem<String>(value: v, child: Text(v == 'TODOS' ? 'Todos' : v, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    ),
  );

  Widget _toolbar() => Card(
    color: panel,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: borde)),
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: 92, child: DropdownButtonFormField<int>(
            value: filtroAnio,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Año', floatingLabelBehavior: FloatingLabelBehavior.always, labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: texto), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 9)),
            dropdownColor: panelClaro,
            style: const TextStyle(color: texto, fontSize: 12),
            items: [2024, 2025, 2026, 2027].map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
            onChanged: (v) { if (v != null) setState(() => filtroAnio = v); _cargar(); },
          )),
          _filtro('Vendedor', vendedor, ['TODOS', ...vendedores], (v) { if (v != null) setState(() => vendedor = v); _cargar(); }, width: 112),
          _filtro('Cliente', filtroCliente, ['TODOS', ..._opciones('cliente')], (v) { if (v != null) setState(() => filtroCliente = v); _cargar(); }, width: 132),
          _filtro('Estado', estado, const ['TODOS', 'PAGADO', 'PENDIENTE', 'VENCIDO', 'VENCIDO PARCIAL'], (v) { if (v != null) setState(() => estado = v); _cargar(); }, width: 110),
          _filtro('Días de atraso', filtroDias, const ['TODOS', 'AL_DIA', 'VENCIDO', '1-30', '31-60', '61-90', '90+'], (v) { if (v != null) setState(() => filtroDias = v); _cargar(); }, width: 116),
          _filtro('Canal', filtroCanal, ['TODOS', ..._opciones('canal')], (v) { if (v != null) setState(() => filtroCanal = v); _cargar(); }, width: 104),
          _filtro('Sector', filtroSector, ['TODOS', ..._opciones('sector')], (v) { if (v != null) setState(() => filtroSector = v); _cargar(); }, width: 104),
          _filtro('Punto', filtroPunto, ['TODOS', ..._opciones('punto_factura')], (v) { if (v != null) setState(() => filtroPunto = v); _cargar(); }, width: 104),
          SizedBox(width: 185, child: TextField(controller: search, onSubmitted: (_) => _cargar(), style: const TextStyle(fontSize: 12), decoration: const InputDecoration(labelText: 'Buscar cliente, RUC o documento', floatingLabelBehavior: FloatingLabelBehavior.always, labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: texto), isDense: true, prefixIcon: Icon(Icons.search), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 9)))),
          OutlinedButton.icon(onPressed: () { setState(() { filtroAnio = 2026; vendedor = 'TODOS'; filtroCliente = 'TODOS'; estado = 'TODOS'; filtroDias = 'TODOS'; filtroCanal = 'TODOS'; filtroSector = 'TODOS'; filtroPunto = 'TODOS'; search.clear(); }); _cargar(); }, icon: const Icon(Icons.filter_alt_off, size: 16), label: const Text('Limpiar filtros')),
          if (_puedeImportar) FilledButton.icon(onPressed: _importarExcel, icon: const Icon(Icons.file_upload_outlined, size: 17), label: const Text('Importar'), style: FilledButton.styleFrom(backgroundColor: verde, foregroundColor: const Color(0xFF032D37))),
          IconButton(tooltip: 'Actualizar', onPressed: loading ? null : _cargar, icon: const Icon(Icons.refresh, color: texto)),
        ],
      ),
    ),
  );

  Widget _kpis()=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[LayoutBuilder(builder:(context,c)=>Wrap(spacing:8,runSpacing:8,children:[_kpi('Facturado sin IGV', 'US\$ ${money.format(total)}', const Color(0xFF00B7FF), Icons.account_balance_wallet,c.maxWidth),_kpi('Cobrado sin IGV*','US\$ ${money.format(pagado)}',const Color(0xFF00F5D4),Icons.payments,c.maxWidth),_kpi('Saldo sin IGV*','US\$ ${money.format(saldo)}',const Color(0xFFFF3D71),Icons.warning_amber,c.maxWidth),_kpi('Vencidas','$vencidas',const Color(0xFFFFB000),Icons.event_busy,c.maxWidth)])),Padding(padding:const EdgeInsets.only(top:5,left:4),child:Text('IGV facturado: US\$ ${money.format(igvTotal)} · *Cobrado y saldo sin IGV estimados proporcionalmente al neto de cada factura; validar contra el detalle de pagos.',style:const TextStyle(color:Color(0xFF75DDF2),fontSize:10,fontWeight:FontWeight.w700)))]);
  Widget _kpi(String t,String v,Color c,IconData i,double maxWidth)=>SizedBox(width:(maxWidth-24)/4 < 165 ? (maxWidth-24)/2 : ((maxWidth-24)/4).clamp(165,280).toDouble(),child:Card(color:panel,elevation:0,margin:EdgeInsets.zero,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12),side:const BorderSide(color:borde)),child:Padding(padding:const EdgeInsets.all(10),child:Row(children:[CircleAvatar(radius:18,backgroundColor:c.withValues(alpha:.14),child:Icon(i,color:c,size:20)),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(t,style:const TextStyle(color:textoSuave,fontSize:11)),Text(v,style:TextStyle(fontSize:15,fontWeight:FontWeight.w900,color:c),maxLines:2,overflow:TextOverflow.ellipsis)]))]))));

  Future<List<Map<String, dynamic>>> _buscarClientePorCodigo(String codigo) async {
    if (codigo.isEmpty) return [];
    final data = await db.from('clientes').select('codigo,razon_social,nombre').eq('codigo', codigo).limit(1);
    return List<Map<String, dynamic>>.from(data);
  }

  Widget _tabsCobranza() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: const Color(0xFF082D45),
      border: Border.all(color: borde, width: 1.2),
      borderRadius: BorderRadius.circular(13),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _tabButton(0, Icons.account_balance_wallet_outlined, 'Cartera de cobranzas'),
        _tabButton(1, Icons.event_available_outlined, 'Compromisos de pago'),
        _tabButton(2, Icons.warning_amber_rounded, 'Vencidos'),
        _tabButton(3, Icons.task_alt, 'Pagados'),
        _tabButton(4, Icons.percent, 'Comisiones'),
        _tabButton(5, Icons.account_balance_outlined, 'Por cobrar'),
      ]),
    ),
  );

  Widget _tabButton(int index, IconData icon, String label) {
    final selected = _tabSeleccionada == index;
    final color = selected ? const Color(0xFF00C8FF) : textoSuave;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: selected ? const Color(0xFF075B83) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () {
             setState(() => _tabSeleccionada = index);
             if (index == 4) _cargarComisiones();
           },
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: selected ? const Color(0xFF00B7FF) : Colors.transparent,
                width: 1.2,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: const Color(0xFF00B7FF).withValues(alpha: .14), blurRadius: 9)]
                  : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                color: selected ? texto : textoSuave,
              )),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _seleccionarCorteComision() async {
    final seleccion = await showDatePicker(
      context: context,
      initialDate: _fechaCorteComision,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Fecha de corte de comisiones',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar corte',
    );
    if (seleccion == null) return;
    setState(() => _fechaCorteComision = DateTime(seleccion.year, seleccion.month, seleccion.day));
    await _cargarComisiones();
  }

  String _claveDocumento(dynamic punto, dynamic numero) =>
      '${_s(punto)}-${_s(numero)}'.replaceAll(' ', '').toUpperCase();

  Future<void> _cargarComisiones() async {
    if (!mounted) return;
    setState(() {
      _cargandoComisiones = true;
      _comisionesCargadas = true;
      _errorComisiones = null;
    });
    try {
      final corte = DateTime(
        _fechaCorteComision.year,
        _fechaCorteComision.month,
        _fechaCorteComision.day,
      );

      // Leer el resultado precomputado en Supabase. El trigger mantiene esta
      // tabla auxiliar actualizada; Flutter ya no realiza varios JOIN grandes.
      final resultado = <Map<String, dynamic>>[];
      const tamanoPaginaComision = 1000;
      var inicioPaginaComision = 0;
      while (true) {
        var consulta = db.from('crm_comisiones_facturas_pagadas_cache').select('*');
        if (_esPerfilConCarteraPropia) {
          if (_vendedorSesionEfectivo.isEmpty) break;
          consulta = consulta.eq('vendedor', _vendedorSesionEfectivo);
        } else if (vendedor != 'TODOS') {
          consulta = consulta.eq('vendedor', vendedor);
        }
        final lote = await consulta
            .lte('fecha_factura', DateFormat('yyyy-MM-dd').format(corte))
            .order('fecha_factura', ascending: false)
            .range(inicioPaginaComision, inicioPaginaComision + tamanoPaginaComision - 1);
        final bloque = List<Map<String, dynamic>>.from(lote as List);
        for (final r in bloque) {
          final vendedorFila = _s(r['vendedor']);
          if (_esPerfilConCarteraPropia &&
              _normalizar(vendedorFila) != _normalizar(_vendedorSesionEfectivo)) continue;
          if (filtroCliente != 'TODOS' && _s(r['cliente']) != filtroCliente) continue;
          if (filtroCanal != 'TODOS' && _s(r['canal']) != filtroCanal) continue;
          if (filtroPunto != 'TODOS' && _s(r['punto_factura']) != filtroPunto) continue;
          final fila = <String, dynamic>{
            'fecha_factura': r['fecha_factura'],
            'fecha_corte': DateFormat('yyyy-MM-dd').format(corte),
            'cliente': r['cliente'],
            'codigo_cliente': r['codigo_cliente'],
            'documento': _claveDocumento(r['punto_factura'], r['numero_factura']),
            'vendedor': r['vendedor'],
            'codigo_articulo': r['codigo_articulo'],
            'articulo': r['articulo'],
            'cantidad': _n(r['cantidad']),
            'unidad_medida': r['unidad_medida'],
            'precio_bruto': _n(r['precio_bruto']),
            'porcentaje_descuento': _n(r['porcentaje_descuento']),
            'descuento_total': _n(r['monto_descuento']),
            'precio_neto': _n(r['precio_neto']),
            'base_comision': _n(r['base_comisionable']),
            'porcentaje': _n(r['porcentaje_comision']),
            'monto_comision': _n(r['monto_comision']),
            'tasa_encontrada': r['tasa_encontrada'] == true,
          };
          // Los filtros de cartera/cliente/canal/punto se aplican a la fila
          // preparada. La tabla cache todavía no almacena el sector.
          if (!_clienteDentroDeAmbito({
            'cliente': r['cliente'],
            'codigo_cliente': r['codigo_cliente'],
            'codigo_vendedor': r['codigo_vendedor'],
            'vendedor': r['vendedor'],
          })) continue;
          resultado.add(fila);
        }
        if (bloque.length < tamanoPaginaComision) break;
        inicioPaginaComision += tamanoPaginaComision;
      }
      resultado.sort((a, b) => _s(b['fecha_factura']).compareTo(_s(a['fecha_factura'])));
      if (!mounted) return;
      setState(() {
        _filasComision = resultado;
        _cargandoComisiones = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorComisiones = '$e';
        _filasComision = [];
        _cargandoComisiones = false;
      });
    }
  }


  Future<void> _vistaPreviaComisiones() async {
    if (_filasComision.isEmpty) {
      _msg('No hay líneas de comisión para mostrar. Primero actualiza el cálculo.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: fondo,
        title: Text('Vista previa de comisiones · Corte ${date.format(_fechaCorteComision)}'),
        content: SizedBox(
          width: 1100,
          height: 600,
          child: Column(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Líneas: ${_filasComision.length} · Base: US\$ ${money.format(_filasComision.fold<double>(0, (a,r) => a + _n(r['base_comision'])))} · Comisión: US\$ ${money.format(_filasComision.fold<double>(0, (a,r) => a + _n(r['monto_comision'])))}'),
            ),
            const SizedBox(height: 8),
            Expanded(child: SingleChildScrollView(
              child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
                columns: const [
                  DataColumn(label: Text('Fecha')), DataColumn(label: Text('Cliente')),
                  DataColumn(label: Text('Documento')), DataColumn(label: Text('Vendedor')),
                  DataColumn(label: Text('Código')), DataColumn(label: Text('Producto')),
                  DataColumn(label: Text('Cant.')), DataColumn(label: Text('Precio bruto')),
                  DataColumn(label: Text('% Desc.')), DataColumn(label: Text('Descuento USD')),
                  DataColumn(label: Text('Precio neto')), DataColumn(label: Text('Base USD')),
                  DataColumn(label: Text('%')), DataColumn(label: Text('Comisión USD')),
                ],
                rows: _filasComision.map((r) => DataRow(cells: [
                  DataCell(Text(_dt(r['fecha_factura']) == null ? '—' : date.format(_dt(r['fecha_factura'])!))),
                  DataCell(Text(_s(r['cliente']))), DataCell(Text(_s(r['documento']))),
                  DataCell(Text(_s(r['vendedor']))), DataCell(Text(_s(r['codigo_articulo']))),
                  DataCell(Text(_s(r['articulo']))), DataCell(Text(money.format(_n(r['cantidad'])))),
                  DataCell(Text(money.format(_n(r['precio_bruto'])))),
                  DataCell(Text('${money.format(_n(r['porcentaje_descuento']))}%')),
                  DataCell(Text(money.format(_n(r['descuento_total'])))),
                  DataCell(Text(money.format(_n(r['precio_neto'])))),
                  DataCell(Text(money.format(_n(r['base_comision'])))),
                  DataCell(Text('${money.format(_n(r['porcentaje']))}%')),
                  DataCell(Text(money.format(_n(r['monto_comision'])))),
                ])).toList(),
              )),
            )),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
      ),
    );
  }

  Future<void> _exportarComisionesExcel() async {
    if (!_puedeImprimirModulo) { _exigirPermiso(false, 'exportar'); return; }
    if (_filasComision.isEmpty) {
      _msg('No hay líneas de comisión para exportar. Actualiza el cálculo primero.');
      return;
    }
    try {
      final book = Excel.createExcel();
      final sheet = book['Comisiones'];
      sheet.appendRow([TextCellValue('Fecha factura'), TextCellValue('Fecha corte'), TextCellValue('Cliente'), TextCellValue('Código cliente'), TextCellValue('Documento'), TextCellValue('Vendedor'), TextCellValue('Código artículo'), TextCellValue('Producto'), TextCellValue('Cantidad'), TextCellValue('Unidad'), TextCellValue('Precio bruto unitario'), TextCellValue('% descuento'), TextCellValue('Descuento total USD'), TextCellValue('Precio neto unitario'), TextCellValue('Base USD'), TextCellValue('Porcentaje comisión'), TextCellValue('Comisión USD')]);
      for (final r in _filasComision) {
        sheet.appendRow([
          TextCellValue(_s(r['fecha_factura'])), TextCellValue(_s(r['fecha_corte'])),
          TextCellValue(_s(r['cliente'])), TextCellValue(_s(r['codigo_cliente'])),
          TextCellValue(_s(r['documento'])), TextCellValue(_s(r['vendedor'])),
          TextCellValue(_s(r['codigo_articulo'])), TextCellValue(_s(r['articulo'])),
          DoubleCellValue(_n(r['cantidad'])), TextCellValue(_s(r['unidad_medida'])),
          DoubleCellValue(_n(r['precio_bruto'])), DoubleCellValue(_n(r['porcentaje_descuento'])),
          DoubleCellValue(_n(r['descuento_total'])), DoubleCellValue(_n(r['precio_neto'])),
          DoubleCellValue(_n(r['base_comision'])), DoubleCellValue(_n(r['porcentaje'])),
          DoubleCellValue(_n(r['monto_comision'])),
        ]);
      }
      final bytes = book.encode();
      if (bytes == null) throw Exception('No se pudo generar el archivo Excel.');
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final ruta = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar Excel de comisiones',
        fileName: 'comisiones_cobranza_$stamp.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(bytes),
      );
      if (ruta == null) return;
      _msg('Excel de comisiones guardado correctamente.');
    } catch (e) {
      _msg('No se pudo exportar Excel: $e');
    }
  }

  Future<void> _imprimirComisiones() async {
    if (!_puedeImprimirModulo) { _exigirPermiso(false, 'imprimir'); return; }
    if (_filasComision.isEmpty) {
      _msg('No hay líneas de comisión para imprimir. Actualiza el cálculo primero.');
      return;
    }
    try {
      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(22),
        header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('ELCOPE CRM · Comisiones por cobranza', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.Text('Fecha de corte: ${date.format(_fechaCorteComision)} · Generado: ${date.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 8),
        ]),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: const ['Fecha','Cliente','Documento','Vendedor','Código','Producto','Cant.','Precio bruto','% Desc.','Descuento USD','Precio neto','Base USD','%','Comisión USD'],
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 7),
            data: _filasComision.map((r) => [
              _dt(r['fecha_factura']) == null ? '' : date.format(_dt(r['fecha_factura'])!),
              _s(r['cliente']), _s(r['documento']), _s(r['vendedor']), _s(r['codigo_articulo']),
              _s(r['articulo']), money.format(_n(r['cantidad'])),
              money.format(_n(r['precio_bruto'])), '${money.format(_n(r['porcentaje_descuento']))}%',
              money.format(_n(r['descuento_total'])), money.format(_n(r['precio_neto'])),
              money.format(_n(r['base_comision'])), '${money.format(_n(r['porcentaje']))}%',
              money.format(_n(r['monto_comision'])),
            ]).toList(),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Base total: US\$ ${money.format(_filasComision.fold<double>(0, (a,r) => a + _n(r['base_comision'])))} · Comisión total: US\$ ${money.format(_filasComision.fold<double>(0, (a,r) => a + _n(r['monto_comision'])))}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ],
      ));
      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
    } catch (e) {
      _msg('No se pudo imprimir el reporte: $e');
    }
  }

  Widget _contenidoComisiones() {
    final base = _filasComision.fold<double>(0, (s, r) => s + _n(r['base_comision']));
    final totalComision = _filasComision.fold<double>(0, (s, r) => s + _n(r['monto_comision']));
    final sinTasa = _filasComision.where((r) => _n(r['porcentaje']) <= 0).length;
    final descuentoTotal = _filasComision.fold<double>(0, (s, r) => s + _n(r['descuento_total']));
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Comisiones por cobranza', style: TextStyle(color: texto, fontSize: 15, fontWeight: FontWeight.w900)),
                Text('Facturas emitidas hasta el corte que figuran totalmente pagadas en la cartera. Tasa por producto y vigencia.', style: const TextStyle(color: textoSuave, fontSize: 11)),
              ]),
              OutlinedButton.icon(
                onPressed: _seleccionarCorteComision,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text('Corte: ${date.format(_fechaCorteComision)}'),
              ),
              IconButton(
                tooltip: 'Actualizar comisiones',
                onPressed: _cargandoComisiones ? null : _cargarComisiones,
                icon: const Icon(Icons.refresh, color: Color(0xFF12B8FF)),
              ),
              OutlinedButton.icon(
                onPressed: _filasComision.isEmpty ? null : _vistaPreviaComisiones,
                icon: const Icon(Icons.preview_outlined),
                label: const Text('Vista previa'),
              ),
              if (_puedeImprimirModulo) OutlinedButton.icon(
                onPressed: _filasComision.isEmpty ? null : _exportarComisionesExcel,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Excel'),
              ),
              if (_puedeImprimirModulo) FilledButton.icon(
                onPressed: _filasComision.isEmpty ? null : _imprimirComisiones,
                icon: const Icon(Icons.print_outlined),
                label: const Text('Imprimir'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 8, children: [
            _commissionCard('Líneas comisionables', '${_filasComision.length}', const Color(0xFF168BFF)),
            _commissionCard('Base con tasa', 'US\$ ${money.format(_filasComision.where((r) => _n(r['porcentaje']) > 0).fold<double>(0, (s, r) => s + _n(r['base_comision'])))}', const Color(0xFF28B463)),
            _commissionCard('Descuento aplicado', 'US\$ ${money.format(descuentoTotal)}', const Color(0xFFB26BFF)),
            _commissionCard('Comisión calculada', 'US\$ ${money.format(totalComision)}', const Color(0xFF75DDF2)),
            _commissionCard('Líneas sin tasa', '$sinTasa', sinTasa == 0 ? const Color(0xFF28B463) : naranja),
          ]),
          if (_errorComisiones != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('No se pudieron calcular las comisiones: $_errorComisiones', style: const TextStyle(color: rojo)),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: _cargandoComisiones
                ? const Center(child: CircularProgressIndicator())
                : _filasComision.isEmpty
                    ? const Center(child: Text('No hay facturas totalmente pagadas antes de la fecha de corte.', style: TextStyle(color: textoSuave)))
                    : Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('FECHA FACTURA')),
                                DataColumn(label: Text('FECHA CORTE')),
                                DataColumn(label: Text('CLIENTE')),
                                DataColumn(label: Text('DOCUMENTO')),
                                DataColumn(label: Text('VENDEDOR')),
                                DataColumn(label: Text('CÓDIGO')),
                                DataColumn(label: Text('PRODUCTO')),
                                DataColumn(label: Text('CANT.')),
                                DataColumn(label: Text('PRECIO BRUTO')),
                                DataColumn(label: Text('% DESC.')),
                                DataColumn(label: Text('DESCUENTO USD')),
                                DataColumn(label: Text('PRECIO NETO')),
                                DataColumn(label: Text('BASE USD')),
                                DataColumn(label: Text('%')),
                                DataColumn(label: Text('COMISIÓN USD')),
                              ],
                              rows: _filasComision.map((r) => DataRow(cells: [
                                DataCell(Text(_dt(r['fecha_factura']) == null ? '—' : date.format(_dt(r['fecha_factura'])!))),
                                DataCell(Text(_dt(r['fecha_corte']) == null ? '—' : date.format(_dt(r['fecha_corte'])!))),
                                DataCell(SizedBox(width: 180, child: Text(_s(r['cliente']), maxLines: 2, overflow: TextOverflow.ellipsis))),
                                DataCell(Text(_s(r['documento']))),
                                DataCell(Text(_s(r['vendedor']))),
                                DataCell(Text(_s(r['codigo_articulo']))),
                                DataCell(SizedBox(width: 230, child: Text(_s(r['articulo']), maxLines: 2, overflow: TextOverflow.ellipsis))),
                                DataCell(Text(money.format(_n(r['cantidad'])))),
                                DataCell(Text(money.format(_n(r['precio_bruto'])))),
                                DataCell(Text('${money.format(_n(r['porcentaje_descuento']))}%')),
                                DataCell(Text('US\$ ${money.format(_n(r['descuento_total']))}')),
                                DataCell(Text(money.format(_n(r['precio_neto'])))),
                                DataCell(Text('US\$ ${money.format(_n(r['base_comision']))}')),
                                DataCell(Text('${money.format(_n(r['porcentaje']))}%')),
                                DataCell(Text('US\$ ${money.format(_n(r['monto_comision']))}', style: const TextStyle(color: verde, fontWeight: FontWeight.w800))),
                              ])).toList(),
                            ),
                          ),
                        ),
                      ),
          ),
          const SizedBox(height: 8),
          Text('Base neta desde crm_factura_detalles (descuento ya aplicado, sin restarlo dos veces); tasa según comisiones_productos y vigencia de la factura. Total base: US\$ ${money.format(base)} · Comisión: US\$ ${money.format(totalComision)}',
              style: const TextStyle(color: textoSuave, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _contenidoTab() {
    if (_tabSeleccionada == 0) {
      // La cartera debe ocupar casi todo el espacio disponible. Los tres paneles
      // secundarios quedan debajo, contraídos inicialmente, para no tapar filas.
      return Column(
        children: [
          Expanded(child: _table()),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
              collapsedIconColor: textoSuave,
              iconColor: const Color(0xFF00B7FF),
              backgroundColor: const Color(0xFF082B42),
              collapsedBackgroundColor: const Color(0xFF082B42),
              title: const Text(
                'Detalle del cliente · Gestiones · Comisión',
                style: TextStyle(color: texto, fontSize: 11, fontWeight: FontWeight.w800),
              ),
              leading: const Icon(Icons.expand_more_rounded, color: Color(0xFF00B7FF), size: 18),
              children: [_resumenInferior()],
            ),
          ),
        ],
      );
    }
    if (_tabSeleccionada == 1) return _tablaSimple('Compromisos de pago', rows.where((r) => _n(r['saldo']) > 0 && _s(r['estado']) == 'PENDIENTE').toList());
    if (_tabSeleccionada == 2) return _tablaSimple('Vencidos', rows.where((r) { final e = _s(r['estado']).toUpperCase(); return e == 'VENCIDO' || e == 'VENCIDO PARCIAL'; }).toList());
    if (_tabSeleccionada == 3) return _tablaSimple('Documentos pagados', rows.where((r) => _s(r['estado']).toUpperCase() == 'PAGADO' || _s(r['estado']).toUpperCase() == 'PAGADA' || _n(r['saldo']) <= 0.01).toList());
    if (_tabSeleccionada == 5) return _tablaSimple('Por cobrar', rows.where((r) { final e = _s(r['estado']).toUpperCase(); return _n(r['saldo']) > 0.01 && e != 'VENCIDO' && e != 'VENCIDO PARCIAL' && e != 'PAGADO' && e != 'PAGADA'; }).toList());
    if (!_comisionesCargadas && !_cargandoComisiones && _errorComisiones == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tabSeleccionada == 4 && !_cargandoComisiones && _filasComision.isEmpty && _errorComisiones == null) {
          _cargarComisiones();
        }
      });
    }
    return _contenidoComisiones();
  }

  Widget _resumenInferior() {
    final docs = rows.take(3).toList();
    final cobrado = pagado;
    Widget panelInferior(String title, IconData icon, Widget child, {bool expand = true}) => Container(
      margin: const EdgeInsets.all(3), padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFF082B42), border: Border.all(color: borde), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: const Color(0xFF00B7FF), size: 14), const SizedBox(width: 5), Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: texto, fontWeight: FontWeight.w800, fontSize: 10)))]),
        const SizedBox(height: 5), if (expand) Expanded(child: child) else child,
      ]),
    );
    final detalle = docs.isEmpty
      ? const Center(child: Text('Sin documentos', style: TextStyle(color: textoSuave, fontSize: 10)))
      : Column(children: [for (final r in docs) Expanded(child: Row(children: [Expanded(child: Text(_s(r['documento']), style: const TextStyle(color: texto, fontSize: 9), overflow: TextOverflow.ellipsis)), Expanded(child: Text('US\$ ${money.format(_n(r['monto_factura']))}', style: const TextStyle(color: textoSuave, fontSize: 9))), Expanded(child: Text('Saldo US\$ ${money.format(_n(r['saldo']))}', style: TextStyle(color: _estadoColor(_s(r['estado'])), fontSize: 9, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis))]))]);
    final gestiones = const Center(child: Text('Las gestiones aparecerán al conectarse su registro.', textAlign: TextAlign.center, style: TextStyle(color: textoSuave, fontSize: 10)));
    final comisionWidget = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text('Total cobrado sin IGV*: US\$ ${money.format(cobrado)}', style: const TextStyle(color: textoSuave, fontSize: 10)), const SizedBox(height: 4), Text('Comisión: tasa oficial pendiente', style: const TextStyle(color: Color(0xFF75DDF2), fontWeight: FontWeight.w900, fontSize: 11))]);
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 700) {
        return SizedBox(height: 390, child: Column(children: [
          Expanded(child: panelInferior('Detalle de documentos del cliente', Icons.description_outlined, detalle)),
          Expanded(child: panelInferior('Gestiones de cobranza', Icons.history, gestiones)),
          Expanded(child: panelInferior('Cálculo de comisión (base sin IGV)', Icons.percent, comisionWidget)),
        ]));
      }
      return SizedBox(height: 112, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: panelInferior('Detalle de documentos del cliente', Icons.description_outlined, detalle)),
        Expanded(child: panelInferior('Gestiones de cobranza', Icons.history, gestiones)),
        Expanded(child: panelInferior('Cálculo de comisión (base sin IGV)', Icons.percent, comisionWidget)),
      ]));
    });
  }

  Widget _commissionCard(String title, String value, Color color) => Container(width: 205, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: panelClaro, border: Border.all(color: color.withValues(alpha:.7)), borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: color.withValues(alpha:.10), blurRadius: 10)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: textoSuave, fontSize: 11)), const SizedBox(height: 5), Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900))]));

  Widget _tablaSimple(String titulo, List<Map<String, dynamic>> data) {
    final totalSaldo = data.fold<double>(0, (sum, r) => sum + _n(r['saldo']));
    final rowsTabla = data.map((r) {
      final e = _s(r['estado']);
      final nombre = _s(r['cliente_mostrar']).isNotEmpty
          ? _s(r['cliente_mostrar'])
          : (_s(r['cliente']).isEmpty ? _s(r['codigo_cliente']) : _s(r['cliente']));
      return DataRow(cells: [
        DataCell(Text(_dt(r['fecha_factura']) == null ? '—' : date.format(_dt(r['fecha_factura'])!))),
        DataCell(SizedBox(width: 180, child: Text(nombre, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF75DDF2), fontWeight: FontWeight.w700))), onTap: () => _abrirCliente360(r)),
        DataCell(Text(_s(r['documento']), style: const TextStyle(color: Color(0xFF75DDF2), fontWeight: FontWeight.w700)), onTap: () => _abrirCliente360(r)),
        DataCell(Text(_s(r['vendedor']))),
        DataCell(Text('US\$ ${money.format(_n(r['monto_factura']))}')),
        DataCell(Text('US\$ ${money.format(_n(r['monto_pagado']))}')),
        DataCell(Text('US\$ ${money.format(_n(r['saldo']))}', style: TextStyle(color: _estadoColor(e), fontWeight: FontWeight.w800))),
        DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: _estadoColor(e).withValues(alpha: .18), borderRadius: BorderRadius.circular(16), border: Border.all(color: _estadoColor(e))), child: Text(e, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _estadoColor(e))))),
      ]);
    }).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 7, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: const TextStyle(color: texto, fontWeight: FontWeight.w900, fontSize: 13)),
            Text('Documentos: ${data.length}  ·  Saldo total: US\$ ${money.format(totalSaldo)}', style: const TextStyle(color: textoSuave, fontSize: 11)),
          ]),
          Wrap(spacing: 7, runSpacing: 6, children: [
            OutlinedButton.icon(onPressed: () => _mostrarVistaPrevia(titulo, data), icon: const Icon(Icons.preview_outlined, size: 17), label: const Text('Vista previa')),
            if (_puedeImprimirModulo) OutlinedButton.icon(onPressed: data.isEmpty ? null : () => _exportarCarteraExcel(data: data, titulo: titulo), icon: const Icon(Icons.file_download_outlined, size: 17), label: const Text('Excel')),
            if (_puedeImprimirModulo) FilledButton.icon(onPressed: data.isEmpty ? null : () => _imprimirReporte(titulo, data), icon: const Icon(Icons.print_outlined, size: 17), label: const Text('Imprimir'), style: FilledButton.styleFrom(backgroundColor: verde, foregroundColor: const Color(0xFF032D37))),
          ]),
        ]),
      ),
      if (data.isEmpty)
        const Expanded(child: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No hay registros para esta pestaña con los filtros seleccionados.', textAlign: TextAlign.center, style: TextStyle(color: textoSuave)))))
      else Expanded(child: Scrollbar(thumbVisibility: true, child: SingleChildScrollView(scrollDirection: Axis.vertical, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
        columnSpacing: 18, horizontalMargin: 12,
        columns: const [DataColumn(label: Text('FECHA')), DataColumn(label: Text('CLIENTE')), DataColumn(label: Text('DOCUMENTO')), DataColumn(label: Text('VENDEDOR')), DataColumn(label: Text('FACTURA USD')), DataColumn(label: Text('PAGADO USD')), DataColumn(label: Text('SALDO USD')), DataColumn(label: Text('ESTADO'))],
        rows: rowsTabla,
      ))))),
    ]);
  }

  Future<void> _mostrarVistaPrevia(String titulo, List<Map<String, dynamic>> data) async {
    final total = data.fold<double>(0, (sum, r) => sum + _n(r['monto_factura']));
    final pagadoTotal = data.fold<double>(0, (sum, r) => sum + _n(r['monto_pagado']));
    final saldoTotal = data.fold<double>(0, (sum, r) => sum + _n(r['saldo']));
    await showDialog<void>(context: context, builder: (dialogContext) => Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: fondo,
        dialogBackgroundColor: fondo,
        canvasColor: panel,
        dividerColor: borde,
        colorScheme: ThemeData.dark().colorScheme.copyWith(
          brightness: Brightness.dark,
          primary: const Color(0xFF12B8FF),
          secondary: verde,
          surface: fondo,
          onSurface: texto,
        ),
        textTheme: ThemeData.dark().textTheme.apply(bodyColor: texto, displayColor: texto),
        dataTableTheme: const DataTableThemeData(
          headingRowColor: WidgetStatePropertyAll(Color(0xFF104361)),
          dataRowColor: WidgetStatePropertyAll(Color(0xFF0A3550)),
          headingTextStyle: TextStyle(color: texto, fontWeight: FontWeight.w800),
          dataTextStyle: TextStyle(color: texto),
          dividerThickness: 0.7,
        ),
      ),
      child: Dialog(
      backgroundColor: fondo,
      insetPadding: const EdgeInsets.all(18),
      child: SizedBox(width: 1200, height: 760, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Expanded(child: Text('Vista previa · $titulo · $filtroAnio', style: const TextStyle(color: texto, fontSize: 18, fontWeight: FontWeight.w900))), IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close, color: texto))]),
        Wrap(spacing: 10, runSpacing: 8, children: [
          _previewKpi('Documentos', '${data.length}'), _previewKpi('Facturado', 'US\$ ${money.format(total)}'), _previewKpi('Pagado', 'US\$ ${money.format(pagadoTotal)}'), _previewKpi('Saldo', 'US\$ ${money.format(saldoTotal)}'),
        ]),
        const SizedBox(height: 12),
        Expanded(child: data.isEmpty ? const Center(child: Text('No hay documentos para mostrar con los filtros actuales.', style: TextStyle(color: textoSuave))) : Scrollbar(thumbVisibility: true, child: SingleChildScrollView(scrollDirection: Axis.vertical, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          columns: const [DataColumn(label: Text('FECHA')), DataColumn(label: Text('VENCIMIENTO')), DataColumn(label: Text('CLIENTE')), DataColumn(label: Text('DOCUMENTO')), DataColumn(label: Text('VENDEDOR')), DataColumn(label: Text('FACTURA USD')), DataColumn(label: Text('PAGADO USD')), DataColumn(label: Text('SALDO USD')), DataColumn(label: Text('ESTADO'))],
          rows: data.map((r) => DataRow(cells: [
            DataCell(Text(_dt(r['fecha_factura']) == null ? '—' : date.format(_dt(r['fecha_factura'])!))),
            DataCell(Text(_dt(r['fecha_vencimiento']) == null ? '—' : date.format(_dt(r['fecha_vencimiento'])!))),
            DataCell(SizedBox(width: 210, child: Text(_s(r['cliente_mostrar']).isNotEmpty ? _s(r['cliente_mostrar']) : _s(r['cliente']), maxLines: 2, overflow: TextOverflow.ellipsis))),
            DataCell(Text(_s(r['documento']))), DataCell(Text(_s(r['vendedor'])),),
            DataCell(Text('US\$ ${money.format(_n(r['monto_factura']))}')), DataCell(Text('US\$ ${money.format(_n(r['monto_pagado']))}')), DataCell(Text('US\$ ${money.format(_n(r['saldo']))}')), DataCell(Text(_s(r['estado']))),
          ])).toList(),
        ))))),
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [
          if (_puedeImprimirModulo) OutlinedButton.icon(onPressed: data.isEmpty ? null : () => _exportarCarteraExcel(data: data, titulo: titulo), icon: const Icon(Icons.file_download_outlined), label: const Text('Exportar Excel')),
          if (_puedeImprimirModulo) FilledButton.icon(onPressed: data.isEmpty ? null : () => _imprimirReporte(titulo, data), icon: const Icon(Icons.print_outlined), label: const Text('Imprimir reporte'), style: FilledButton.styleFrom(backgroundColor: verde, foregroundColor: const Color(0xFF032D37))),
        ]),
      ]))),
    )));
  }

  Widget _previewKpi(String label, String value) => Container(margin: const EdgeInsets.only(right: 4), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(9), border: Border.all(color: borde)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: textoSuave, fontSize: 10)), Text(value, style: const TextStyle(color: texto, fontSize: 13, fontWeight: FontWeight.w900))]));

  Future<void> _imprimirReporte(String titulo, List<Map<String, dynamic>> data) async {
    if (data.isEmpty) return;
    try {
      final pdf = pw.Document();
      final headerStyle = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(22),
        header: (_) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 10), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('ELCOPE · COBRANZA CRM', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('$titulo · Año $filtroAnio · Generado ${date.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
        ])),
        build: (_) => [
          pw.Text('Documentos: ${data.length}    Facturado: US\$ ${money.format(data.fold<double>(0, (s, r) => s + _n(r['monto_factura'])))}    Pagado: US\$ ${money.format(data.fold<double>(0, (s, r) => s + _n(r['monto_pagado'])))}    Saldo: US\$ ${money.format(data.fold<double>(0, (s, r) => s + _n(r['saldo'])))}', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headerStyle: headerStyle,
            cellStyle: const pw.TextStyle(fontSize: 7),
            headers: const ['Fecha', 'Vencimiento', 'Cliente', 'Documento', 'Vendedor', 'Factura USD', 'Pagado USD', 'Saldo USD', 'Estado'],
            data: data.map((r) => [
              _dt(r['fecha_factura']) == null ? '—' : date.format(_dt(r['fecha_factura'])!),
              _dt(r['fecha_vencimiento']) == null ? '—' : date.format(_dt(r['fecha_vencimiento'])!),
              _s(r['cliente_mostrar']).isNotEmpty ? _s(r['cliente_mostrar']) : _s(r['cliente']),
              _s(r['documento']), _s(r['vendedor']), money.format(_n(r['monto_factura'])), money.format(_n(r['monto_pagado'])), money.format(_n(r['saldo'])), _s(r['estado']),
            ]).toList(),
          ),
        ],
      ));
      await Printing.layoutPdf(onLayout: (_) async => pdf.save(), name: 'cobranza_${titulo.toLowerCase().replaceAll(' ', '_')}_$filtroAnio.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo imprimir el reporte: $e')));
    }
  }


  Future<void> _exportarCarteraExcel({List<Map<String, dynamic>>? data, String titulo = 'Cartera de cobranzas'}) async {
    final exportRows = data ?? rows;
    if (exportRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros para exportar con los filtros actuales.')),
      );
      return;
    }
    try {
      final excel = Excel.createExcel();
      final sheet = excel[titulo.length > 31 ? titulo.substring(0, 31) : titulo];
      sheet.appendRow([
        TextCellValue('Fecha factura'),
        TextCellValue('Vencimiento'),
        TextCellValue('Cliente'),
        TextCellValue('Código cliente'),
        TextCellValue('Documento'),
        TextCellValue('Vendedor'),
        TextCellValue('Canal'),
        TextCellValue('Sector'),
        TextCellValue('Punto'),
        TextCellValue('Moneda'),
        TextCellValue('Factura neta USD'),
        TextCellValue('Pagado neto USD estimado'),
        TextCellValue('Saldo neto USD estimado'),
        TextCellValue('Estado'),
        TextCellValue('Días de atraso'),
      ]);
      for (final r in exportRows) {
        final fecha = _dt(r['fecha_factura']);
        final vencimiento = _dt(r['fecha_vencimiento']);
        sheet.appendRow([
          TextCellValue(fecha == null ? '' : date.format(fecha)),
          TextCellValue(vencimiento == null ? '' : date.format(vencimiento)),
          TextCellValue(_s(r['cliente_mostrar']).isEmpty ? _s(r['cliente']) : _s(r['cliente_mostrar'])),
          TextCellValue(_s(r['codigo_cliente'])),
          TextCellValue(_s(r['documento'])),
          TextCellValue(_s(r['vendedor'])),
          TextCellValue(_s(r['canal'])),
          TextCellValue(_s(r['sector'])),
          TextCellValue(_s(r['punto_factura'])),
          TextCellValue(_s(r['moneda'])),
          DoubleCellValue(_n(r['monto_factura'])),
          DoubleCellValue(_n(r['monto_pagado'])),
          DoubleCellValue(_n(r['saldo'])),
          TextCellValue(_s(r['estado'])),
          IntCellValue((_n(r['dias_atraso'])).toInt()),
        ]);
      }
      final bytes = excel.encode();
      if (bytes == null || bytes.isEmpty) {
        throw Exception('No se pudo generar el archivo Excel.');
      }
      await FilePicker.platform.saveFile(
        dialogTitle: 'Exportar cartera de cobranzas',
        fileName: '${titulo.toLowerCase().replaceAll(' ', '_')}_$filtroAnio.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(bytes),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo exportar la cartera: $e')),
      );
    }
  }

  void _abrirCliente360(Map<String, dynamic> registro) {
    final codigo = _s(registro['codigo_cliente']);
    if (codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este documento no tiene código de cliente para abrir Cliente 360°.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CrmCliente360FacturaPage(
          codigoCliente: codigo,
          // En las pestañas secundarias la fila normalizada puede traer el
          // documento combinado (punto-número) y no el número separado.
          numeroFactura: _s(registro['numero_factura']).isNotEmpty
              ? _s(registro['numero_factura'])
              : _s(registro['documento']),
          nombreCliente: _s(registro['cliente_mostrar']).isNotEmpty
              ? _s(registro['cliente_mostrar'])
              : _s(registro['cliente']),
        ),
        settings: RouteSettings(name: 'cliente360-cobranza-$codigo'),
      ),
    );
  }

  Widget _table() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(9, 5, 9, 4),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              const Text(
                'Cartera de cobranzas',
                style: TextStyle(color: texto, fontSize: 12, fontWeight: FontWeight.w900),
              ),
              if (_puedeImprimirModulo) FilledButton.icon(
                onPressed: rows.isEmpty ? null : _exportarCarteraExcel,
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('Exportar Excel'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00C98D),
                  foregroundColor: const Color(0xFF032D37),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 42, color: Color(0xFF12B8FF)),
                        SizedBox(height: 10),
                        Text('No hay cobranzas para los filtros seleccionados.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: texto, fontWeight: FontWeight.w700, fontSize: 14)),
                        SizedBox(height: 6),
                        Text(filtroAnio < 2026
                            ? 'La carga temporal de cobranza disponible corresponde a 2026. Hay facturas históricas en el módulo de facturación, pero no hay saldos ni pagos históricos cargados en Cobranza para calcular vencidos con seguridad.'
                            : 'Verifica el año y los filtros, o importa el Excel de cobranza para visualizar los documentos.',
                            textAlign: TextAlign.center, style: TextStyle(color: textoSuave)),
                      ],
                    ),
                  ),
                )
              : Container(
                  margin: const EdgeInsets.fromLTRB(5, 0, 5, 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF082D45),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borde, width: 1.2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 38,
                            dataRowMinHeight: 44,
                            dataRowMaxHeight: 54,
                            columnSpacing: 11,
                            horizontalMargin: 10,
                            dividerThickness: 0.8,
                            headingRowColor: const WidgetStatePropertyAll(Color(0xFF15516F)),
                            dataRowColor: WidgetStateProperty.resolveWith<Color?>((states) {
                              if (states.contains(WidgetState.selected)) return const Color(0xFF15516F);
                              return Colors.transparent;
                            }),
                            columns: const [
                              DataColumn(label: Text('FECHA FACTURA')),
                              DataColumn(label: Text('VENCIMIENTO')),
                              DataColumn(label: Text('CLIENTE')),
                              DataColumn(label: Text('DOCUMENTO')),
                              DataColumn(label: Text('VENDEDOR')),
                              DataColumn(label: Text('FACTURA USD')),
                              DataColumn(label: Text('PAGADO USD')),
                              DataColumn(label: Text('SALDO USD')),
                              DataColumn(label: Text('ESTADO')),
                              DataColumn(label: Text('ACCIONES')),
                            ],
                            rows: rows.map((r) {
                              final e = _s(r['estado']);
                              final cliente = _s(r['cliente_mostrar']).isEmpty
                                  ? (_s(r['cliente']).isEmpty ? _s(r['codigo_cliente']) : _s(r['cliente']))
                                  : _s(r['cliente_mostrar']);
                              final colorEstado = _estadoColor(e);
                              return DataRow(cells: [
                                DataCell(Text(_dt(r['fecha_factura']) == null ? '—' : date.format(_dt(r['fecha_factura'])!))),
                                DataCell(Text(_dt(r['fecha_vencimiento']) == null ? '—' : date.format(_dt(r['fecha_vencimiento'])!))),
                                DataCell(
                                  SizedBox(
                                    width: 225,
                                    child: Tooltip(
                                      message: '$cliente\nCódigo: ${_s(r['codigo_cliente'])}\nAbrir historial en Cliente 360°',
                                      child: InkWell(
                                        onTap: () => _abrirCliente360(r),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 3),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(cliente, maxLines: 2, overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.w900, color: texto, fontSize: 12)),
                                              Text(_s(r['codigo_cliente']), style: const TextStyle(color: textoSuave, fontSize: 10)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  onTap: () => _abrirCliente360(r),
                                ),
                                DataCell(Text(_s(r['documento']).isEmpty ? '—' : _s(r['documento']))),
                                DataCell(Text(_s(r['vendedor']))),
                                DataCell(Text('US\$ ${money.format(_n(r['monto_factura']))}',
                                    style: const TextStyle(fontWeight: FontWeight.w700))),
                                DataCell(Text('US\$ ${money.format(_n(r['monto_pagado']))}',
                                    style: const TextStyle(color: Color(0xFF00F5D4), fontWeight: FontWeight.w700))),
                                DataCell(Text('US\$ ${money.format(_n(r['saldo']))}',
                                    style: TextStyle(fontWeight: FontWeight.w900, color: colorEstado))),
                                DataCell(Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: colorEstado.withValues(alpha: .18),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: colorEstado),
                                  ),
                                  child: Text(e, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: colorEstado)),
                                )),
                                DataCell(IconButton(
                                  tooltip: 'Ver acciones',
                                  onPressed: _puedeEditarModulo ? () => _registrarPago(r) : null,
                                  icon: const Icon(Icons.more_horiz, color: Color(0xFF12B8FF)),
                                )),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _errorView()=>Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.error_outline,size:50,color:rojo),const SizedBox(height:10),Text(error??'Error'),const SizedBox(height:12),FilledButton(onPressed:_cargar,child:const Text('Reintentar'))]));
}


class _NeonDonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  _NeonDonutPainter({required this.values, required this.colors});
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide / 2) - 12;
    final total = values.fold<double>(0, (a,b)=>a + (b > 0 ? b : 0));
    final track = Paint()..color = const Color(0xFF123F59)..style=PaintingStyle.stroke..strokeWidth=15;
    canvas.drawCircle(center, radius, track);
    if (total <= 0) return;
    var start = -1.57079632679;
    for (var i=0;i<values.length;i++) {
      if (values[i] <= 0) continue;
      final sweep = 6.28318530718 * values[i] / total;
      final paint = Paint()..color=colors[i % colors.length]..style=PaintingStyle.stroke..strokeWidth=15..strokeCap=StrokeCap.round;
      final glow = Paint()..color=colors[i % colors.length].withValues(alpha:.28)..style=PaintingStyle.stroke..strokeWidth=23..maskFilter=const MaskFilter.blur(BlurStyle.normal,7);
      canvas.drawArc(Rect.fromCircle(center:center,radius:radius),start,sweep,false,glow);
      canvas.drawArc(Rect.fromCircle(center:center,radius:radius),start,sweep,false,paint);
      start += sweep + .035;
    }
  }
  @override
  bool shouldRepaint(covariant _NeonDonutPainter oldDelegate) => oldDelegate.values != values || oldDelegate.colors != colors;
}
