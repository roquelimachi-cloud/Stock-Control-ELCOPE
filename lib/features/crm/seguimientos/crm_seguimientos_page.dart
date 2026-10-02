import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/sesion.dart';
import '../../../services/supabase/supabase_service.dart';

class CrmSeguimientosPage extends StatefulWidget {
  const CrmSeguimientosPage({super.key});

  @override
  State<CrmSeguimientosPage> createState() => _CrmSeguimientosPageState();
}

class _CrmSeguimientosPageState extends State<CrmSeguimientosPage> {
  static const Color azul = Color(0xFF063B63);
  static const Color azul2 = Color(0xFF1686E8);
  static const Color fondo = Color(0xFFF4F7FA);
  static const Color borde = Color(0xFFE0E7EF);
  static const Color verde = Color(0xFF13B77A);
  static const Color naranja = Color(0xFFFFA726);
  static const Color rojo = Color(0xFFFF4D57);
  static const Color morado = Color(0xFF8E5CF6);

  final _db = SupabaseService.client;
  final _buscar = TextEditingController();

  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _clientes = [];
  List<String> _vendedoresPermitidos = [];

  String _vendedor = 'TODOS';
  String _estado = 'TODOS';
  String _tipo = 'TODOS';

  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  String _s(dynamic value) => value?.toString().trim() ?? '';

  bool get _esJefatura {
    final rol = Sesion.rol.trim().toLowerCase();
    return rol == 'jefe lima' || rol == 'jefe provincia';
  }

  bool get _esGerencia {
    final rol = Sesion.rol.trim().toLowerCase();
    return rol.contains('gerencia') || rol.contains('gerente');
  }

  String _cliente(Map<String, dynamic> row) {
    final directos = [
      'cliente_nombre',
      'nombre_cliente',
      'razon_social',
      'cliente',
    ];

    for (final key in directos) {
      final value = _s(row[key]);
      if (value.isNotEmpty &&
          !RegExp(r'^\d{8,15}$').hasMatch(value)) {
        return value;
      }
    }

    final codigo = _s(row['codigo_cliente']).isNotEmpty
        ? _s(row['codigo_cliente'])
        : _s(row['cliente']);

    for (final c in _clientes) {
      final codigoCliente = _codigoCliente(c);
      if (codigoCliente == codigo) {
        return _nombreCliente(c);
      }
    }

    return codigo.isEmpty ? 'Cliente no identificado' : codigo;
  }

  String _codigoCliente(Map<String, dynamic> row) {
    for (final key in ['codigo_cliente', 'codigo', 'ruc', 'dni']) {
      final value = _s(row[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _nombreCliente(Map<String, dynamic> row) {
    for (final key in ['razon_social', 'nombre', 'cliente', 'nombre_cliente']) {
      final value = _s(row[key]);
      if (value.isNotEmpty) return value;
    }
    return 'Cliente sin nombre';
  }

  String _fecha(dynamic value) {
    final date = DateTime.tryParse(_s(value));
    if (date == null) return '-';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  bool _cerrado(Map<String, dynamic> row) {
    const cierres = {
      'completada',
      'completado',
      'realizada',
      'realizado',
      'cerrada',
      'cerrado',
      'finalizada',
      'finalizado',
      'cliente confirmó',
      'cliente confirmo',
      'compra confirmada',
      'venta confirmada',
    };

    return cierres.contains(_s(row['resultado']).toLowerCase());
  }

  String _estadoCalculado(Map<String, dynamic> row) {
    if (_cerrado(row)) return 'CERRADO';

    final next = DateTime.tryParse(_s(row['fecha_proxima_accion']));
    if (next != null) {
      final today = DateTime.now();
      final day = DateTime(next.year, next.month, next.day);
      final todayOnly = DateTime(today.year, today.month, today.day);

      if (day.isBefore(todayOnly)) return 'VENCIDO';
      if (_s(row['resultado']).isNotEmpty) return 'EN PROCESO';
      return 'PENDIENTE';
    }

    if (_s(row['resultado']).isNotEmpty) return 'EN PROCESO';
    return 'PENDIENTE';
  }

  Future<void> _cargarPermisos() async {
    if (_esGerencia) {
      _vendedoresPermitidos = [];
      return;
    }

    if (_esJefatura) {
      try {
        final data = await _db
            .from('usuario_permisos')
            .select('vendedor, ver_produccion')
            .eq('usuario_jefe_id', Sesion.idUsuario)
            .eq('ver_produccion', true);

        final nombres = <String>{};
        for (final item in data as List) {
          final name = _s(item['vendedor']);
          if (name.isNotEmpty) nombres.add(name);
        }

        if (Sesion.vendedor.trim().isNotEmpty) {
          nombres.add(Sesion.vendedor.trim());
        }

        _vendedoresPermitidos = nombres.toList()..sort();
        return;
      } catch (_) {}
    }

    if (Sesion.vendedor.trim().isNotEmpty) {
      _vendedoresPermitidos = [Sesion.vendedor.trim()];
    }
  }

  Future<void> _cargarClientes() async {
    try {
      final data = await _db.rpc(
        'crm_obtener_clientes_pagina_v6',
        params: {
          'p_busqueda': '',
          'p_vendedor': 'TODOS',
          'p_sector': 'TODOS',
          'p_giro': 'TODOS',
          'p_departamento':
              _esJefatura &&
                      Sesion.rol.trim().toLowerCase() == 'jefe lima'
                  ? 'LIMA'
                  : 'TODOS',
          'p_solo_activos': true,
          'p_limit': 500,
          'p_offset': 0,
          'p_orden': 'CLIENTE_ASC',
          'p_anio': null,
          'p_vendedores_permitidos':
              _vendedoresPermitidos.isEmpty ? null : _vendedoresPermitidos,
        },
      );

      _clientes = List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      debugPrint('Seguimientos: no se pudo cargar clientes: $e');
    }
  }

  Future<void> _cargar() async {
    if (mounted) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }

    try {
      final data = await _db.rpc(
        'crm_obtener_actividades',
        params: {
          'p_vendedores_permitidos':
              _vendedoresPermitidos.isEmpty ? null : _vendedoresPermitidos,
          'p_tipo': _tipo,
          'p_vendedor': _vendedor,
          'p_busqueda': _buscar.text.trim(),
          'p_desde': null,
          'p_hasta': null,
          'p_limit': 500,
        },
      );

      final all = List<Map<String, dynamic>>.from(data as List);

      setState(() {
        _rows = all.where((row) {
          if (_estado == 'TODOS') return true;
          return _estadoCalculado(row) == _estado;
        }).toList();
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString();
        _rows = [];
      });
    }
  }

  Future<void> _inicializar() async {
    try {
      await _cargarPermisos();
      await _cargarClientes();
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString();
      });
    }
  }

  int _count(String estado) {
    return _rows.where((row) => _estadoCalculado(row) == estado).length;
  }

  String _tipoLabel(String value) {
    final v = value.toUpperCase();
    switch (v) {
      case 'LLAMADA':
        return 'Llamada';
      case 'CORREO':
        return 'Correo';
      case 'VISITA':
        return 'Visita';
      case 'REUNION':
      case 'REUNIÓN':
        return 'Reunión';
      case 'WHATSAPP':
        return 'WhatsApp';
      case 'SEGUIMIENTO':
        return 'Seguimiento';
      default:
        return value.isEmpty ? 'Actividad' : value;
    }
  }

  IconData _tipoIcon(String value) {
    switch (value.toUpperCase()) {
      case 'LLAMADA':
        return Icons.phone_outlined;
      case 'CORREO':
        return Icons.mail_outline;
      case 'VISITA':
        return Icons.groups_outlined;
      case 'REUNION':
      case 'REUNIÓN':
        return Icons.groups_2_outlined;
      case 'WHATSAPP':
        return Icons.chat_outlined;
      default:
        return Icons.fact_check_outlined;
    }
  }

  Color _tipoColor(String value) {
    switch (value.toUpperCase()) {
      case 'LLAMADA':
        return azul2;
      case 'CORREO':
        return morado;
      case 'VISITA':
        return rojo;
      case 'REUNION':
      case 'REUNIÓN':
        return naranja;
      default:
        return verde;
    }
  }

  Widget _statusChip(Map<String, dynamic> row) {
    final status = _estadoCalculado(row);

    Color color;
    Color background;
    switch (status) {
      case 'CERRADO':
        color = verde;
        background = const Color(0xFFE4F7EF);
        break;
      case 'VENCIDO':
        color = rojo;
        background = const Color(0xFFFFE7EA);
        break;
      case 'EN PROCESO':
        color = azul2;
        background = const Color(0xFFE4F1FF);
        break;
      default:
        color = naranja;
        background = const Color(0xFFFFF1D9);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _typeChip(String value) {
    final color = _tipoColor(value);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_tipoIcon(value), size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            _tipoLabel(value),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _nav(IconData icon, String title, {bool selected = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF0877E6) : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: Colors.white, size: 20),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        onTap: selected ? null : () => Navigator.maybePop(context),
      ),
    );
  }

  Widget _sidebar() {
    return Container(
      width: 235,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF063B63), Color(0xFF052C4B)],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 18),
          const Text(
            'ELECTRO CONDUCTORES',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Text(
            'PERUANOS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Text(
            'ELCOPE',
            style: TextStyle(
              color: Color(0xFF63D98D),
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Divider(color: Colors.white24),
          ),
          Expanded(
            child: ListView(
              children: [
                _nav(Icons.home_outlined, 'Inicio CRM'),
                _nav(Icons.people_alt_outlined, 'Clientes'),
                _nav(Icons.person_search_outlined, 'Cliente 360°'),
                _nav(Icons.fact_check_outlined, 'Actividades'),
                _nav(
                  Icons.track_changes_outlined,
                  'Seguimientos',
                  selected: true,
                ),
                _nav(Icons.business_center_outlined, 'Oportunidades'),
                _nav(Icons.task_alt_outlined, 'Tareas'),
                _nav(Icons.receipt_long_outlined, 'Facturación'),
                _nav(Icons.account_balance_wallet_outlined, 'Cobranza'),
                _nav(Icons.percent_outlined, 'Comisiones'),
                _nav(Icons.bar_chart_outlined, 'Reportes'),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              children: [
                Text(
                  'CABLES QUE CONECTAN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'TU PROGRESO',
                  style: TextStyle(
                    color: Color(0xFF63D98D),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Centro de Mando Comercial',
                  style: TextStyle(color: Colors.white70, fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: azul),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seguimientos',
                  style: TextStyle(
                    color: azul,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Registra y da seguimiento a tus gestiones comerciales con los clientes.',
                  style: TextStyle(
                    color: Color(0xFF6B7E93),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 290,
            height: 40,
            child: TextField(
              controller: _buscar,
              onSubmitted: (_) => _cargar(),
              decoration: InputDecoration(
                hintText: 'Buscar cliente, proyecto, seguimiento...',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: borde),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: borde),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargar,
            icon: const Icon(Icons.refresh_rounded, color: azul2),
          ),
          const CircleAvatar(
            radius: 18,
            backgroundColor: azul,
            child: Text(
              'MR',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            Sesion.nombre.trim().isEmpty ? 'Michael Roque' : Sesion.nombre,
            style: const TextStyle(
              color: azul,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const Icon(Icons.keyboard_arrow_down, color: azul),
        ],
      ),
    );
  }

  Widget _kpi({
    required IconData icon,
    required String title,
    required int value,
    required Color color,
    String? footer,
  }) {
    return Expanded(
      child: Container(
        height: 86,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borde),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF6C8299),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$value',
                    style: const TextStyle(
                      color: azul,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (footer != null)
                    Text(
                      footer,
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
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

  Widget _filters() {
    final vendedores = ['TODOS', ..._vendedoresPermitidos.toSet()];
    const tipos = [
      'TODOS',
      'LLAMADA',
      'CORREO',
      'REUNION',
      'VISITA',
      'WHATSAPP',
      'SEGUIMIENTO',
    ];
    const estados = [
      'TODOS',
      'PENDIENTE',
      'EN PROCESO',
      'VENCIDO',
      'CERRADO',
    ];

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: borde),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              height: 40,
              child: TextField(
                controller: _buscar,
                onSubmitted: (_) => _cargar(),
                decoration: InputDecoration(
                  hintText: 'Buscar seguimiento...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  filled: true,
                  fillColor: const Color(0xFFF7F9FC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            _select(
              'Asesor',
              _vendedor,
              vendedores,
              (value) {
                _vendedor = value;
                _cargar();
              },
            ),
            _select(
              'Estado',
              _estado,
              estados,
              (value) {
                setState(() => _estado = value);
                _cargar();
              },
            ),
            _select(
              'Tipo',
              _tipo,
              tipos,
              (value) {
                _tipo = value;
                _cargar();
              },
            ),
            FilledButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.filter_alt_outlined, size: 17),
              label: const Text('Aplicar'),
              style: FilledButton.styleFrom(
                backgroundColor: azul2,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                _buscar.clear();
                setState(() {
                  _vendedor = 'TODOS';
                  _estado = 'TODOS';
                  _tipo = 'TODOS';
                });
                _cargar();
              },
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Limpiar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: azul,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _select(
    String label,
    String value,
    List<String> items,
    ValueChanged<String> onChanged,
  ) {
    final safeValue = items.contains(value) ? value : items.first;

    return SizedBox(
      width: 145,
      height: 58,
      child: DropdownButtonFormField<String>(
        value: safeValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: borde),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: borde),
          ),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item == 'TODOS' ? 'Todos' : item,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }

  Widget _table() {
    if (_cargando) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borde),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: rojo, size: 42),
            const SizedBox(height: 8),
            const Text(
              'No se pudo cargar Seguimientos',
              style: TextStyle(
                color: azul,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _cargar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borde),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.list_alt_outlined, color: azul2, size: 21),
                const SizedBox(width: 7),
                Text(
                  'Lista de seguimientos (${_rows.length})',
                  style: const TextStyle(
                    color: azul,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _nuevoSeguimiento,
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('Nuevo seguimiento'),
                  style: FilledButton.styleFrom(
                    backgroundColor: verde,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: const WidgetStatePropertyAll(
                  Color(0xFFF7F9FC),
                ),
                columnSpacing: 18,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 62,
                headingTextStyle: const TextStyle(
                  color: azul,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
                columns: const [
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Cliente')),
                  DataColumn(label: Text('Tipo')),
                  DataColumn(label: Text('Asunto')),
                  DataColumn(label: Text('Resultado')),
                  DataColumn(label: Text('Próxima acción')),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('Asesor')),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: _rows.map((row) {
                  final vendedor = _s(row['vendedor']).isEmpty
                      ? Sesion.vendedor
                      : _s(row['vendedor']);

                  return DataRow(
                    cells: [
                      DataCell(Text(
                        _fecha(row['fecha']),
                        style: const TextStyle(fontSize: 10),
                      )),
                      DataCell(
                        SizedBox(
                          width: 160,
                          child: Text(
                            _cliente(row),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: azul,
                            ),
                          ),
                        ),
                      ),
                      DataCell(_typeChip(_s(row['tipo']))),
                      DataCell(
                        SizedBox(
                          width: 145,
                          child: Text(
                            _s(row['asunto']).isEmpty
                                ? '-'
                                : _s(row['asunto']),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          _s(row['resultado']).isEmpty
                              ? '-'
                              : _s(row['resultado']),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      DataCell(
                        Text(
                          _fecha(row['fecha_proxima_accion']),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      DataCell(_statusChip(row)),
                      DataCell(
                        Text(
                          vendedor,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: azul,
                          ),
                        ),
                      ),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Editar',
                              onPressed: () => _editar(row),
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 17,
                                color: azul2,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Ver detalle',
                              onPressed: () => _detalle(row),
                              icon: const Icon(
                                Icons.more_horiz,
                                size: 18,
                                color: azul,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Mostrando 1 - ${_rows.length} de ${_rows.length} registros',
              style: const TextStyle(
                color: Color(0xFF7890A5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _upcoming() {
    final items = List<Map<String, dynamic>>.from(_rows)
      ..sort((a, b) {
        final da = DateTime.tryParse(_s(a['fecha_proxima_accion']));
        final db = DateTime.tryParse(_s(b['fecha_proxima_accion']));
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });

    final visible = items.take(5).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                color: azul2,
                size: 19,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Próximas acciones',
                  style: TextStyle(
                    color: azul,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: _cargar,
                child: const Text('Ver todas'),
              ),
            ],
          ),
          const Divider(height: 18),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 35),
              child: Center(
                child: Text(
                  'No hay próximas acciones.',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ),
            ),
          for (final row in visible) _upcomingItem(row),
        ],
      ),
    );
  }

  Widget _upcomingItem(Map<String, dynamic> row) {
    final color = _tipoColor(_s(row['tipo']));

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              shape: BoxShape.circle,
            ),
            child: Icon(_tipoIcon(_s(row['tipo'])), color: color, size: 17),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fecha(row['fecha_proxima_accion']),
                  style: const TextStyle(
                    color: azul2,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _cliente(row),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: azul,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  _s(row['asunto']).isEmpty
                      ? _tipoLabel(_s(row['tipo']))
                      : _s(row['asunto']),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6C8299),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1180;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 28,
            12,
            compact ? 16 : 28,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 10),
              Row(
                children: [
                  _kpi(
                    icon: Icons.description_outlined,
                    title: 'Total seguimientos',
                    value: _rows.length,
                    color: azul2,
                    footer: 'Este mes',
                  ),
                  const SizedBox(width: 10),
                  _kpi(
                    icon: Icons.access_time_rounded,
                    title: 'Pendientes',
                    value: _count('PENDIENTE'),
                    color: naranja,
                    footer: 'Por ejecutar',
                  ),
                  const SizedBox(width: 10),
                  _kpi(
                    icon: Icons.sync_alt_rounded,
                    title: 'En proceso',
                    value: _count('EN PROCESO'),
                    color: azul2,
                    footer: 'En seguimiento',
                  ),
                  const SizedBox(width: 10),
                  _kpi(
                    icon: Icons.check_circle_outline,
                    title: 'Cerrados',
                    value: _count('CERRADO'),
                    color: verde,
                    footer: 'Completados',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _filters(),
              const SizedBox(height: 12),
              if (compact)
                Column(
                  children: [
                    _table(),
                    const SizedBox(height: 12),
                    _upcoming(),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _table()),
                    const SizedBox(width: 12),
                    SizedBox(width: 275, child: _upcoming()),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      body: SafeArea(
        child: Row(
          children: [
            _sidebar(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Future<void> _nuevoSeguimiento() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _NuevaSeguimientoDialog(
        db: _db,
        clientes: _clientes,
        vendedores: _vendedoresPermitidos,
        vendedorActual: Sesion.vendedor,
        usuarioId: Sesion.idUsuario,
      ),
    );

    if (result == true) await _cargar();
  }

  Future<void> _editar(Map<String, dynamic> row) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditarSeguimientoDialog(
        db: _db,
        row: row,
        vendedores: _vendedoresPermitidos,
      ),
    );

    if (result == true) await _cargar();
  }

  void _detalle(Map<String, dynamic> row) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          _cliente(row),
          style: const TextStyle(color: azul, fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailLine('Tipo', _tipoLabel(_s(row['tipo']))),
              _detailLine('Fecha', _fecha(row['fecha'])),
              _detailLine('Asunto', _s(row['asunto'])),
              _detailLine('Resultado', _s(row['resultado']).isEmpty ? '-' : _s(row['resultado'])),
              _detailLine('Próxima acción', _s(row['proxima_accion']).isEmpty ? '-' : _s(row['proxima_accion'])),
              _detailLine('Fecha próxima', _fecha(row['fecha_proxima_accion'])),
              _detailLine('Estado', _estadoCalculado(row)),
              _detailLine(
                'Asesor',
                _s(row['vendedor']).isEmpty ? Sesion.vendedor : _s(row['vendedor']),
              ),
              _detailLine('Descripción', _s(row['descripcion']).isEmpty ? '-' : _s(row['descripcion'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _editar(row);
            },
            icon: const Icon(Icons.edit_outlined, size: 17),
            label: const Text('Editar'),
          ),
        ],
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF71869A),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: azul,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NuevaSeguimientoDialog extends StatefulWidget {
  const _NuevaSeguimientoDialog({
    required this.db,
    required this.clientes,
    required this.vendedores,
    required this.vendedorActual,
    required this.usuarioId,
  });

  final dynamic db;
  final List<Map<String, dynamic>> clientes;
  final List<String> vendedores;
  final String vendedorActual;
  final dynamic usuarioId;

  @override
  State<_NuevaSeguimientoDialog> createState() =>
      _NuevaSeguimientoDialogState();
}

class _NuevaSeguimientoDialogState extends State<_NuevaSeguimientoDialog> {
  static const Color azul = Color(0xFF063B63);

  final _asunto = TextEditingController();
  final _descripcion = TextEditingController();
  final _resultado = TextEditingController();
  final _proxima = TextEditingController();

  String _tipo = 'LLAMADA';
  String _cliente = '';
  String _vendedor = '';
  DateTime? _fechaProxima;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _vendedor = widget.vendedorActual.isNotEmpty
        ? widget.vendedorActual
        : (widget.vendedores.isNotEmpty ? widget.vendedores.first : '');
  }

  @override
  void dispose() {
    _asunto.dispose();
    _descripcion.dispose();
    _resultado.dispose();
    _proxima.dispose();
    super.dispose();
  }

  String _s(dynamic value) => value?.toString().trim() ?? '';

  String _codigo(Map<String, dynamic> row) {
    for (final key in ['codigo_cliente', 'codigo', 'ruc', 'dni']) {
      final value = _s(row[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _nombre(Map<String, dynamic> row) {
    for (final key in ['razon_social', 'nombre', 'cliente', 'nombre_cliente']) {
      final value = _s(row[key]);
      if (value.isNotEmpty) return value;
    }
    return 'Cliente sin nombre';
  }

  Future<void> _guardar() async {
    if (_cliente.isEmpty || _asunto.text.trim().isEmpty || _vendedor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa cliente, vendedor y asunto.'),
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      await widget.db.rpc(
        'crm_registrar_actividad',
        params: {
          'p_codigo_cliente': _cliente,
          'p_tipo': _tipo,
          'p_asunto': _asunto.text.trim(),
          'p_descripcion': _descripcion.text.trim().isEmpty
              ? null
              : _descripcion.text.trim(),
          'p_resultado': _resultado.text.trim().isEmpty
              ? null
              : _resultado.text.trim(),
          'p_proxima_accion': _proxima.text.trim().isEmpty
              ? null
              : _proxima.text.trim(),
          'p_fecha_proxima_accion':
              _fechaProxima?.toIso8601String().substring(0, 10),
          'p_usuario_id': widget.usuarioId,
          'p_vendedor': _vendedor,
        },
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendedores = widget.vendedores.isEmpty
        ? <String>[_vendedor]
        : widget.vendedores;

    return AlertDialog(
      title: const Text(
        'Nuevo seguimiento',
        style: TextStyle(color: azul, fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  'LLAMADA',
                  'WHATSAPP',
                  'CORREO',
                  'VISITA',
                  'REUNION',
                  'SEGUIMIENTO',
                ]
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e),
                      ),
                    )
                    .toList(),
                onChanged: _guardando
                    ? null
                    : (value) => setState(() => _tipo = value ?? 'LLAMADA'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _cliente.isEmpty ? null : _cliente,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Cliente'),
                items: widget.clientes
                    .map(
                      (row) => DropdownMenuItem(
                        value: _codigo(row),
                        child: Text(
                          '${_nombre(row)} · ${_codigo(row)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .where((item) => item.value!.isNotEmpty)
                    .toList(),
                onChanged: _guardando
                    ? null
                    : (value) => setState(() => _cliente = value ?? ''),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: vendedores.contains(_vendedor) ? _vendedor : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Asesor'),
                items: vendedores
                    .where((item) => item.isNotEmpty)
                    .toSet()
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: _guardando
                    ? null
                    : (value) => setState(() => _vendedor = value ?? ''),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _asunto,
                decoration: const InputDecoration(
                  labelText: 'Asunto',
                  hintText: 'Ej. Revisión de cotización',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _resultado,
                decoration: const InputDecoration(
                  labelText: 'Resultado',
                  hintText: 'Ej. Interesado / En evaluación',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _proxima,
                decoration: const InputDecoration(
                  labelText: 'Próxima acción',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descripcion,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _fechaProxima == null
                      ? 'Seleccionar fecha próxima'
                      : DateFormat('dd/MM/yyyy').format(_fechaProxima!),
                ),
                leading: const Icon(
                  Icons.calendar_today_outlined,
                  color: azul,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _guardando
                    ? null
                    : () async {
                        final date = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2035),
                          initialDate: _fechaProxima ?? DateTime.now(),
                        );
                        if (date != null && mounted) {
                          setState(() => _fechaProxima = date);
                        }
                      },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _EditarSeguimientoDialog extends StatefulWidget {
  const _EditarSeguimientoDialog({
    required this.db,
    required this.row,
    required this.vendedores,
  });

  final dynamic db;
  final Map<String, dynamic> row;
  final List<String> vendedores;

  @override
  State<_EditarSeguimientoDialog> createState() =>
      _EditarSeguimientoDialogState();
}

class _EditarSeguimientoDialogState extends State<_EditarSeguimientoDialog> {
  static const Color azul = Color(0xFF063B63);

  final _asunto = TextEditingController();
  final _descripcion = TextEditingController();
  final _resultado = TextEditingController();
  final _proxima = TextEditingController();

  late String _tipo;
  late String _vendedor;
  DateTime? _fechaProxima;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _tipo = _s(widget.row['tipo']).isEmpty
        ? 'LLAMADA'
        : _s(widget.row['tipo']);
    _vendedor = _s(widget.row['vendedor']);
    _asunto.text = _s(widget.row['asunto']);
    _descripcion.text = _s(widget.row['descripcion']);
    _resultado.text = _s(widget.row['resultado']);
    _proxima.text = _s(widget.row['proxima_accion']);

    final date = _s(widget.row['fecha_proxima_accion']);
    if (date.isNotEmpty) _fechaProxima = DateTime.tryParse(date);
  }

  String _s(dynamic value) => value?.toString().trim() ?? '';

  @override
  void dispose() {
    _asunto.dispose();
    _descripcion.dispose();
    _resultado.dispose();
    _proxima.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_asunto.text.trim().isEmpty || _vendedor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa vendedor y asunto.')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      await widget.db.rpc(
        'crm_actualizar_actividad',
        params: {
          'p_id': widget.row['id'],
          'p_tipo': _tipo,
          'p_asunto': _asunto.text.trim(),
          'p_descripcion': _descripcion.text.trim().isEmpty
              ? null
              : _descripcion.text.trim(),
          'p_resultado': _resultado.text.trim().isEmpty
              ? null
              : _resultado.text.trim(),
          'p_proxima_accion': _proxima.text.trim().isEmpty
              ? null
              : _proxima.text.trim(),
          'p_fecha_proxima_accion':
              _fechaProxima?.toIso8601String().substring(0, 10),
          'p_vendedor': _vendedor,
        },
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendedores = widget.vendedores.toSet().toList();
    if (_vendedor.isNotEmpty && !vendedores.contains(_vendedor)) {
      vendedores.add(_vendedor);
    }

    return AlertDialog(
      title: const Text(
        'Editar seguimiento',
        style: TextStyle(color: azul, fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: vendedores.contains(_vendedor) ? _vendedor : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Asesor'),
                items: vendedores
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: _guardando
                    ? null
                    : (value) => setState(
                          () => _vendedor = value ?? _vendedor,
                        ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  'LLAMADA',
                  'WHATSAPP',
                  'CORREO',
                  'VISITA',
                  'REUNION',
                  'SEGUIMIENTO',
                ]
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e),
                      ),
                    )
                    .toList(),
                onChanged: _guardando
                    ? null
                    : (value) => setState(() => _tipo = value ?? _tipo),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _asunto,
                decoration: const InputDecoration(labelText: 'Asunto'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _resultado,
                decoration: const InputDecoration(labelText: 'Resultado'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _proxima,
                decoration: const InputDecoration(labelText: 'Próxima acción'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descripcion,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined, color: azul),
                title: Text(
                  _fechaProxima == null
                      ? 'Seleccionar fecha próxima'
                      : DateFormat('dd/MM/yyyy').format(_fechaProxima!),
                ),
                onTap: _guardando
                    ? null
                    : () async {
                        final date = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime(2035),
                          initialDate: _fechaProxima ?? DateTime.now(),
                        );
                        if (date != null && mounted) {
                          setState(() => _fechaProxima = date);
                        }
                      },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
