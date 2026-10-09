import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/supabase/supabase_service.dart';
import '../../../services/sesion.dart';

class CrmCliente360Page extends StatefulWidget {
  const CrmCliente360Page({
    super.key,
    this.codigoInicial,
    this.onAbrirActividades,
  });

  final String? codigoInicial;

  /// El Shell abre el módulo oficial de Actividades y recibe el cliente seleccionado.
  final ValueChanged<String>? onAbrirActividades;

  @override
  State<CrmCliente360Page> createState() => _CrmCliente360PageState();
}

class _CrmCliente360PageState extends State<CrmCliente360Page> {
  static const _azul = Color(0xFF0B3B63);
  static const _azulClaro = Color(0xFF1468A8);
  static const _verde = Color(0xFF0A9B61);
  static const _azulSuave = Color(0xFFEAF4FB);
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
  List<Map<String, dynamic>> _contactosData = [];
  List<Map<String, dynamic>> _actividadesData = [];

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
        await _buscarClientes('', seleccionarPrimero: true);
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
    var rows = List<Map<String, dynamic>>.from(result as List);

    // Fallback: si la búsqueda por RUC/código no devuelve resultados desde
    // la consulta de facturación, buscar el cliente directamente en cartera.
    final termino = texto.trim();
    if (rows.isEmpty && termino.isNotEmpty) {
      final clientes = await _db
          .from('clientes')
          .select(
            'codigo,nombre,razon_social,ruc,direccion,localidad,departamento,'
            'canal,giro,sector,codigo_vendedor,vendedor,activo',
          )
          .or('codigo.eq.$termino,ruc.eq.$termino')
          .limit(10);

      rows = (clientes as List).map((item) {
        final c = Map<String, dynamic>.from(item as Map);
        return <String, dynamic>{
          'codigo': c['codigo']?.toString() ?? '',
          'nombre': c['nombre'] ?? '',
          'razon_social': c['razon_social'] ?? c['nombre'] ?? '',
          'ruc': c['ruc']?.toString() ?? '',
          'direccion': c['direccion'],
          'localidad': c['localidad'],
          'departamento': c['departamento'],
          'canal': c['canal'],
          'giro': c['giro'],
          'sector': c['sector'],
          'codigo_vendedor': c['codigo_vendedor'],
          'vendedor': c['vendedor'],
          'activo': c['activo'] ?? true,
          'facturacion': 0,
          'cantidad_facturas': 0,
        };
      }).toList();

      // Mantener las restricciones de cartera de la sesión.
      if (_vendedoresPermitidos != null) {
        rows = rows.where((r) =>
          _vendedoresPermitidos!.contains(_s(r['vendedor']))).toList();
      }
      if (_esJefeLima) {
        rows = rows.where((r) =>
          _s(r['departamento']).trim().toUpperCase() == 'LIMA').toList();
      }
    }

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
    });

    try {
      final params = {
        'p_codigo_cliente': codigo,
        'p_vendedores_permitidos': _vendedoresPermitidos,
        'p_departamento': _esJefeLima ? 'LIMA' : _departamento,
        'p_anio': _anio,
      };

      final resumenRaw = await _db.rpc(
        'crm_obtener_cliente_360_resumen',
        params: params,
      );
      final resumen = List<Map<String, dynamic>>.from(resumenRaw as List);
      if (resumen.isEmpty) {
        throw Exception('El cliente no pertenece a la cartera autorizada.');
      }

      final facturasRaw = await _db.rpc(
        'crm_obtener_cliente_360_facturas',
        params: params,
      );
      final productosRaw = await _db.rpc(
        'crm_obtener_cliente_360_productos',
        params: params,
      );

      if (!mounted) return;
      setState(() {
        _cliente = resumen.first;
        _facturas = List<Map<String, dynamic>>.from(facturasRaw as List);
        _productos = List<Map<String, dynamic>>.from(productosRaw as List);
        _loadingDetail = false;
      });
      await _cargarContactosYActividades(codigo);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDetail = false;
        _error = e.toString();
      });
    }
  }



  Future<void> _cargarContactosYActividades(String codigo) async {
    try {
      final contactos = await _db.rpc(
        'crm_obtener_cliente_contactos',
        params: {'p_codigo_cliente': codigo},
      );
      final actividades = await _db.rpc(
        'crm_obtener_cliente_actividades',
        params: {'p_codigo_cliente': codigo},
      );
      if (!mounted) return;
      setState(() {
        _contactosData = List<Map<String, dynamic>>.from(contactos as List);
        _actividadesData = List<Map<String, dynamic>>.from(actividades as List);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _contactosData = [];
        _actividadesData = [];
      });
    }
  }

  Future<void> _guardarContacto({
    Map<String, dynamic>? existente,
  }) async {
    final nombre = TextEditingController(text: _s(existente?['nombre']));
    final cargo = TextEditingController(text: _s(existente?['cargo']));
    final celular = TextEditingController(text: _s(existente?['celular']));
    final telefono = TextEditingController(text: _s(existente?['telefono']));
    final whatsapp = TextEditingController(
      text: _s(existente?['whatsapp']).isEmpty
          ? _s(existente?['celular'])
          : _s(existente?['whatsapp']),
    );
    final email = TextEditingController(text: _s(existente?['email']));
    final notas = TextEditingController(text: _s(existente?['notas']));
    bool principal = existente?['es_principal'] == true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _panel,
              title: Text(
                existente == null ? 'Nuevo contacto' : 'Editar contacto',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _dialogField(nombre, 'Nombre completo *', Icons.person_outline),
                      _dialogField(cargo, 'Cargo', Icons.badge_outlined),
                      _dialogField(celular, 'Celular', Icons.phone_android_outlined,
                          keyboard: TextInputType.phone),
                      _dialogField(telefono, 'Teléfono fijo', Icons.phone_outlined,
                          keyboard: TextInputType.phone),
                      _dialogField(whatsapp, 'WhatsApp', Icons.chat_outlined,
                          keyboard: TextInputType.phone),
                      _dialogField(email, 'Correo electrónico', Icons.email_outlined,
                          keyboard: TextInputType.emailAddress),
                      _dialogField(notas, 'Notas', Icons.notes_outlined, maxLines: 3),
                      CheckboxListTile(
                        value: principal,
                        onChanged: (v) => setDialogState(() => principal = v ?? false),
                        title: const Text('Contacto principal',
                            style: TextStyle(color: Colors.white)),
                        activeColor: _green,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    if (nombre.text.trim().isEmpty) return;
                    try {
                      await _db.rpc(
                        'crm_guardar_cliente_contacto',
                        params: {
                          'p_id': existente?['id'],
                          'p_codigo_cliente': _s(_cliente?['codigo_cliente']),
                          'p_nombre': nombre.text.trim(),
                          'p_cargo': cargo.text.trim(),
                          'p_celular': celular.text.trim(),
                          'p_telefono': telefono.text.trim(),
                          'p_whatsapp': whatsapp.text.trim(),
                          'p_email': email.text.trim(),
                          'p_es_principal': principal,
                          'p_notas': notas.text.trim(),
                          'p_usuario_id': Sesion.idUsuario,
                          'p_vendedor': Sesion.vendedor.trim(),
                        },
                      );
                      if (context.mounted) Navigator.pop(dialogContext, true);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('No se pudo guardar: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    nombre.dispose();
    cargo.dispose();
    celular.dispose();
    telefono.dispose();
    whatsapp.dispose();
    email.dispose();
    notas.dispose();

    if (ok == true && mounted) {
      await _cargarContactosYActividades(_s(_cliente?['codigo_cliente']));
      _mensaje('Contacto guardado correctamente.');
    }
  }

  void _registrarActividad() {
    final codigo = _s(_cliente?['codigo_cliente']);
    if (codigo.isEmpty) {
      _mensaje('Selecciona primero un cliente.');
      return;
    }

    if (widget.onAbrirActividades != null) {
      widget.onAbrirActividades!(codigo);
      return;
    }

    _mensaje('El módulo Actividades no está conectado al Shell.');
  }



  InputDecoration _dialogDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _whiteMute),
      filled: true,
      fillColor: const Color(0xFF073956),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _line),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _cyan),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: _dialogDecoration(label).copyWith(
          prefixIcon: Icon(icon, color: _cyan, size: 19),
        ),
      ),
    );
  }

  // ===== CLIENTE 360° V4 — ESTILO ELCOPE INICIO =====

  static const _navy = Color(0xFF062C49);
  static const _blue = Color(0xFF0A5F96);
  static const _blue2 = Color(0xFF0C7FC7);
  static const _cyan = Color(0xFF22A7E8);
  static const _green = Color(0xFF11B875);
  static const _gold = Color(0xFFF4B23E);
  static const _page = Color(0xFF062F4D);
  static const _panel = Color(0xFF0A4267);
  static const _panel2 = Color(0xFF0D527E);
  static const _line = Color(0xFF286484);
  static const _whiteSoft = Color(0xFFD8E7F0);
  static const _whiteMute = Color(0xFF9CB6C7);

  Widget _glass({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
    Color? color,
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x35000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(
    IconData icon,
    String title,
    String subtitle, {
    Widget? action,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _blue2.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _blue2.withValues(alpha: .35)),
          ),
          child: Icon(icon, color: _cyan, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: _whiteMute, fontSize: 11),
              ),
            ],
          ),
        ),
        if (action != null) action,
      ],
    );
  }

  Widget _miniButton({
    required IconData icon,
    required String text,
    required VoidCallback onPressed,
    Color color = Colors.white,
    bool filled = false,
  }) {
    return SizedBox(
      height: 38,
      child: filled
          ? FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(text),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: _navy,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(text),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: .42)),
                padding: const EdgeInsets.symmetric(horizontal: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
    );
  }

  Widget _tag(String text, IconData icon, {bool active = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? _green.withValues(alpha: .18)
            : Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? _green.withValues(alpha: .55) : Colors.white24,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: active ? Colors.greenAccent : _whiteSoft,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: active ? Colors.white : _whiteSoft,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _clienteHero(Map<String, dynamic> c) {
    final nombre = _clienteNombre(c);
    final activo = c['activo'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_blue, _blue2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF3E9CD0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 20,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 17,
                ),
                label: const Text('Volver a Clientes'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'CLIENTE 360°',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .72),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.business_rounded,
                  color: Colors.white,
                  size: 31,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre.isEmpty ? 'Cliente' : nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'RUC ${_s(c['ruc']).isEmpty ? _s(c['codigo_cliente']) : _s(c['ruc'])}   •   Código ${_s(c['codigo_cliente'])}   •   Vendedor ${_s(c['vendedor']).isEmpty ? '-' : _s(c['vendedor'])}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: [
                        _tag(
                          _s(c['sector']).isEmpty ? 'Sin sector' : _s(c['sector']),
                          Icons.category_outlined,
                        ),
                        _tag(
                          _s(c['giro']).isEmpty ? 'Sin giro' : _s(c['giro']),
                          Icons.work_outline,
                        ),
                        _tag(
                          activo ? 'CLIENTE ACTIVO' : 'INACTIVO',
                          activo
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          active: activo,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _cargar,
                color: Colors.white,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: _miniButton(
                  icon: Icons.phone_outlined,
                  text: 'Llamar',
                  onPressed: () => _mensaje(
                    'Registra el celular del contacto para activar esta acción.',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniButton(
                  icon: Icons.chat_outlined,
                  text: 'WhatsApp',
                  color: _green,
                  onPressed: () => _mensaje(
                    'Registra el celular del contacto para activar WhatsApp.',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniButton(
                  icon: Icons.email_outlined,
                  text: 'Correo',
                  onPressed: () => _mensaje(
                    'Registra el correo del contacto para activar esta acción.',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniButton(
                  icon: Icons.add_comment_outlined,
                  text: 'Registrar actividad',
                  color: _green,
                  filled: true,
                  onPressed: _registrarActividad,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchBar(bool mobile) {
    return _glass(
      color: const Color(0xFF073956),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      child: Row(
        children: [
          // Regresa a la lista de Clientes conservando los filtros anteriores.
          if (Navigator.of(context).canPop())
            IconButton(
              tooltip: 'Regresar a la lista de clientes',
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.arrow_back_rounded, color: _cyan),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
            ),
          const Icon(Icons.search_rounded, color: _cyan, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: _search,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: (v) {
                if (v.trim().length >= 2 || v.trim().isEmpty) {
                  _buscarClientes(v);
                }
              },
              decoration: const InputDecoration(
                hintText: 'Buscar otro cliente por razón social, RUC o código...',
                hintStyle: TextStyle(color: _whiteMute),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (!mobile)
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                dropdownColor: _panel,
                value: _anio?.toString() ?? 'TODOS',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                items: ['TODOS', '2026', '2025', '2024', '2023', '2022']
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text('Año: $e'),
                      ),
                    )
                    .toList(),
                onChanged: (v) async {
                  setState(
                    () => _anio =
                        v == null || v == 'TODOS' ? null : int.tryParse(v),
                  );
                  await _buscarClientes(_search.text);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _clientesRapidos() {
    if (_resultados.isEmpty) return const SizedBox.shrink();

    return _glass(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF073956),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_outlined, color: _cyan, size: 19),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Clientes de tu cartera',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '${_resultados.length} resultados',
                style: const TextStyle(color: _whiteMute, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 138,
            child: ListView.separated(
              itemCount: _resultados.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Colors.white12),
              itemBuilder: (_, i) {
                final r = _resultados[i];
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 5),
                  leading: const Icon(
                    Icons.business_outlined,
                    color: _cyan,
                  ),
                  title: Text(
                    _s(r['razon_social']).isEmpty
                        ? _s(r['nombre'])
                        : _s(r['razon_social']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${_s(r['ruc']).isEmpty ? _s(r['codigo']) : _s(r['ruc'])}  •  ${_s(r['vendedor'])}',
                    style: const TextStyle(color: _whiteMute, fontSize: 10),
                  ),
                  trailing: Text(
                    _moneyValue(r['facturacion']),
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                  onTap: () => _seleccionar(r),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: .095),
              Colors.white.withValues(alpha: .045),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _whiteMute,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _moneyValue(dynamic value) => 'US\$ ${_money.format(_n(value))}';

  String _clienteNombre(Map<String, dynamic> c) =>
      _s(c['razon_social']).isEmpty ? _s(c['nombre']) : _s(c['razon_social']);

  void _mensaje(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _contactos() {
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.contacts_outlined,
            'CONTACTOS',
            '${_contactosData.length} contacto(s) registrado(s)',
            action: _miniButton(
              icon: Icons.person_add_alt_1,
              text: 'Agregar contacto',
              onPressed: () => _guardarContacto(),
            ),
          ),
          const SizedBox(height: 14),
          if (_contactosData.isEmpty)
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF073956),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _line),
              ),
              child: const Row(
                children: [
                  Icon(Icons.person_outline, color: _cyan, size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sin contacto registrado. Agrega nombre, cargo, celular, WhatsApp y correo.',
                      style: TextStyle(color: _whiteMute, fontSize: 11),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._contactosData.map(
              (c) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF073956),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _line),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _blue2.withValues(alpha: .18),
                      child: const Icon(Icons.person, color: _cyan),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 8,
                        children: [
                          _contactData('NOMBRE', _s(c['nombre'])),
                          _contactData('CARGO', _s(c['cargo'])),
                          _contactData('CELULAR', _s(c['celular'])),
                          _contactData('WHATSAPP', _s(c['whatsapp'])),
                          _contactData('CORREO', _s(c['email'])),
                        ],
                      ),
                    ),
                    if (c['es_principal'] == true)
                      _tag('PRINCIPAL', Icons.star_outline, active: true),
                    IconButton(
                      tooltip: 'Editar',
                      onPressed: () => _guardarContacto(existente: c),
                      color: _whiteSoft,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _contactData(String label, String value) {
    return SizedBox(
      width: 145,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _whiteMute, fontSize: 8, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '-' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }


  Widget _infoEmpresarial(Map<String, dynamic> c) {
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.apartment_outlined,
            'INFORMACIÓN EMPRESARIAL',
            'Datos generales y comerciales',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 28,
            runSpacing: 18,
            children: [
              _dato('Dirección', _s(c['direccion'])),
              _dato('Localidad', _s(c['localidad'])),
              _dato('Departamento', _s(c['departamento'])),
              _dato('Canal', _s(c['canal'])),
              _dato('Primera compra', _dateText(c['primera_compra'])),
              _dato('Última compra', _dateText(c['ultima_compra'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dato(String label, String value) {
    return SizedBox(
      width: 205,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: _whiteMute,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value.isEmpty ? '-' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _dateText(dynamic value) {
    final d = _dt(value);
    return d == null ? '-' : _date.format(d);
  }

  Widget _facturacion() {
    final total = _facturas.fold<double>(
      0,
      (sum, f) => sum + _n(f['monto_calculado']),
    );

    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.receipt_long_outlined,
            'HISTORIAL DE FACTURACIÓN',
            '${_facturas.length} documentos · ${_moneyValue(total)}',
          ),
          const SizedBox(height: 13),
          if (_facturas.isEmpty)
            const Padding(
              padding: EdgeInsets.all(25),
              child: Center(
                child: Text(
                  'No hay facturas para los filtros seleccionados.',
                  style: TextStyle(color: _whiteMute),
                ),
              ),
            )
          else
            SizedBox(
              height: 300,
              child: Scrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 42,
                    headingTextStyle: const TextStyle(
                      color: _whiteMute,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                    dataTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                    columns: const [
                      DataColumn(label: Text('FECHA')),
                      DataColumn(label: Text('DOCUMENTO')),
                      DataColumn(label: Text('VENDEDOR')),
                      DataColumn(label: Text('MONTO USD')),
                      DataColumn(label: Text('PESO KG')),
                      DataColumn(label: Text('ESTADO')),
                    ],
                    rows: _facturas.map((f) {
                      return DataRow(
                        cells: [
                          DataCell(Text(_dateText(f['fecha_factura']))),
                          DataCell(
                            Text(
                              '${_s(f['punto_factura'])}-${_s(f['numero_factura'])}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          DataCell(Text(_s(f['vendedor']))),
                          DataCell(
                            Text(
                              _moneyValue(f['monto_calculado']),
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              _money.format(_n(f['peso_calculado'])),
                            ),
                          ),
                          DataCell(Text(_s(f['estado']))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _productosWidget() {
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.inventory_2_outlined,
            'PRODUCTOS COMPRADOS',
            '${_productos.length} productos consolidados',
          ),
          const SizedBox(height: 13),
          if (_productos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(25),
              child: Center(
                child: Text(
                  'No hay productos para los filtros seleccionados.',
                  style: TextStyle(color: _whiteMute),
                ),
              ),
            )
          else
            SizedBox(
              height: 280,
              child: Scrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 42,
                    headingTextStyle: const TextStyle(
                      color: _whiteMute,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                    dataTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                    columns: const [
                      DataColumn(label: Text('CÓDIGO')),
                      DataColumn(label: Text('PRODUCTO')),
                      DataColumn(label: Text('CANTIDAD')),
                      DataColumn(label: Text('VENTA USD')),
                      DataColumn(label: Text('PESO KG')),
                    ],
                    rows: _productos.map((p) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              _s(p['codigo']).isEmpty ? '-' : _s(p['codigo']),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 380,
                              child: Text(
                                _s(p['descripcion']),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text(_money.format(_n(p['cantidad'])))),
                          DataCell(
                            Text(
                              _moneyValue(p['monto']),
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          DataCell(Text(_money.format(_n(p['peso'])))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actividad() {
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.timeline_rounded,
            'ACTIVIDAD COMERCIAL',
            '${_actividadesData.length} actividad(es) registradas',
            action: _miniButton(
              icon: Icons.add,
              text: 'Registrar actividad',
              color: _green,
              filled: true,
              onPressed: _registrarActividad,
            ),
          ),
          const SizedBox(height: 14),
          if (_actividadesData.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF073956),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _line),
              ),
              child: const Text(
                'Todavía no hay actividades registradas para este cliente.',
                style: TextStyle(color: _whiteMute, fontSize: 11),
              ),
            )
          else
            ..._actividadesData.map(
              (a) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFF073956),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _line),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _cyan.withValues(alpha: .12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconoActividad(_s(a['tipo'])),
                        color: _cyan,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _s(a['asunto']),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Text(
                                _dateText(a['fecha']),
                                style: const TextStyle(
                                  color: _whiteMute,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_s(a['tipo'])} · ${_s(a['resultado']).isEmpty ? 'Sin resultado' : _s(a['resultado'])}',
                            style: const TextStyle(
                              color: _cyan,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (_s(a['descripcion']).isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _s(a['descripcion']),
                              style: const TextStyle(
                                color: _whiteMute,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          if (_s(a['proxima_accion']).isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              'Próxima acción: ${_s(a['proxima_accion'])}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconoActividad(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'LLAMADA':
        return Icons.phone_outlined;
      case 'WHATSAPP':
        return Icons.chat_outlined;
      case 'CORREO':
        return Icons.email_outlined;
      case 'VISITA':
        return Icons.location_on_outlined;
      case 'REUNION':
        return Icons.groups_outlined;
      default:
        return Icons.event_note_outlined;
    }
  }


  Widget _empty() {
    return _glass(
      child: const Padding(
        padding: EdgeInsets.all(45),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.person_search_outlined,
                size: 52,
                color: _whiteMute,
              ),
              SizedBox(height: 10),
              Text(
                'Selecciona un cliente',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Busca por razón social, RUC o código.',
                style: TextStyle(color: _whiteMute),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _glass(
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 45),
              const SizedBox(height: 10),
              const Text(
                'No se pudo cargar Cliente 360°',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Error desconocido',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _whiteMute),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detalle() {
    final c = _cliente!;
    final fact = _n(c['facturacion_total']);
    final peso = _n(c['peso_total_kg']);
    final facturas = _s(c['cantidad_facturas']);

    final kpis = [
      _kpi('FACTURACIÓN', _moneyValue(fact), Icons.attach_money, _green),
      _kpi('PESO VENDIDO', '${_money.format(peso)} kg', Icons.scale_outlined, _cyan),
      _kpi('FACTURAS', facturas, Icons.receipt_long_outlined, _cyan),
      _kpi('TICKET PROMEDIO', _moneyValue(c['ticket_promedio']), Icons.analytics_outlined, _gold),
    ];

    return Column(
      children: [
        Row(
          children: [
            kpis[0],
            const SizedBox(width: 9),
            kpis[1],
            const SizedBox(width: 9),
            kpis[2],
            const SizedBox(width: 9),
            kpis[3],
          ],
        ),
        const SizedBox(height: 12),
        _infoEmpresarial(c),
        const SizedBox(height: 12),
        _facturacion(),
        const SizedBox(height: 12),
        _productosWidget(),
        const SizedBox(height: 12),
        _actividad(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 850;

    return Scaffold(
      backgroundColor: _page,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _cyan),
            )
          : _error != null && _cliente == null
              ? _errorView()
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    mobile ? 12 : 22,
                    mobile ? 12 : 14,
                    mobile ? 12 : 22,
                    30,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_cliente == null) ...[
                        _searchBar(mobile),
                        const SizedBox(height: 10),
                        _clientesRapidos(),
                        const SizedBox(height: 12),
                        _empty(),
                      ] else ...[
                        _clienteHero(_cliente!),
                        const SizedBox(height: 10),
                        _searchBar(mobile),
                        const SizedBox(height: 10),
                        _clientesRapidos(),
                        const SizedBox(height: 12),
                        _contactos(),
                        const SizedBox(height: 12),
                        _detalle(),
                      ],
                    ],
                  ),
                ),
    );
  }
}
