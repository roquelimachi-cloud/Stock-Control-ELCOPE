import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../catalogos/crm_catalogos_service.dart';

class CrmOportunidadesPage extends StatefulWidget {
  const CrmOportunidadesPage({super.key});

  @override
  State<CrmOportunidadesPage> createState() => _CrmOportunidadesPageState();
}

class _CrmOportunidadesPageState extends State<CrmOportunidadesPage> {
  static const Color azul = Color(0xFF063B63);
  static const Color azul2 = Color(0xFF1686E8);
  static const Color fondo = Color(0xFFF4F7FA);
  static const Color borde = Color(0xFFE0E7EF);
  static const Color verde = Color(0xFF13B77A);
  static const Color naranja = Color(0xFFFFA726);
  static const Color rojo = Color(0xFFFF4D57);
  static const Color morado = Color(0xFF8E5CF6);

  final _buscar = TextEditingController();

  final List<Map<String, dynamic>> _oportunidades = [
    {
      'cliente': 'ESPARQ CONSTRUCCION SAC',
      'proyecto': 'Sparq 140',
      'monto': 85000.0,
      'etapa': 'Propuesta enviada',
      'probabilidad': 70,
      'cierre': '15/10/2026',
      'asesor': 'Michael Roque',
    },
    {
      'cliente': 'Delcrosa S.A.C.',
      'proyecto': 'Proyecto Medina',
      'monto': 120000.0,
      'etapa': 'En evaluación',
      'probabilidad': 50,
      'cierre': '30/10/2026',
      'asesor': 'Michael Roque',
    },
    {
      'cliente': 'Quimpac S.A.',
      'proyecto': 'Planta Quimpac',
      'monto': 250000.0,
      'etapa': 'Negociación',
      'probabilidad': 60,
      'cierre': '15/11/2026',
      'asesor': 'Michael Roque',
    },
    {
      'cliente': 'V & V BRAVO S.A.C.',
      'proyecto': 'Vista Tower',
      'monto': 180000.0,
      'etapa': 'Propuesta enviada',
      'probabilidad': 40,
      'cierre': '10/11/2026',
      'asesor': 'Michael Roque',
    },
  ];

  String _etapa = 'TODAS';
  List<String> _etapasFiltro = const ['TODAS'];

  @override
  void initState() {
    super.initState();
    _cargarEtapasFiltro();
  }

  Future<void> _cargarEtapasFiltro() async {
    try {
      final etapas = await CrmCatalogosService.obtenerNombres('etapas_oportunidad');
      if (!mounted || etapas.isEmpty) return;
      setState(() {
        _etapasFiltro = ['TODAS', ...etapas];
        if (!_etapasFiltro.contains(_etapa)) _etapa = 'TODAS';
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtradas {
    final q = _buscar.text.trim().toLowerCase();

    return _oportunidades.where((row) {
      final matchEtapa =
          _etapa == 'TODAS' || row['etapa'] == _etapa;

      final text = [
        row['cliente'],
        row['proyecto'],
        row['etapa'],
        row['asesor'],
      ].join(' ').toString().toLowerCase();

      return matchEtapa && (q.isEmpty || text.contains(q));
    }).toList();
  }

  String _money(dynamic value) {
    final number = value is num ? value.toDouble() : 0.0;
    return NumberFormat.currency(
      locale: 'en_US',
      symbol: 'US\$ ',
      decimalDigits: 0,
    ).format(number);
  }

  Color _etapaColor(String etapa) {
    switch (etapa) {
      case 'En evaluación':
        return naranja;
      case 'Propuesta enviada':
        return azul2;
      case 'Negociación':
        return morado;
      case 'Ganada':
        return verde;
      case 'Perdida':
        return rojo;
      default:
        return azul2;
    }
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

  Widget _header() {
    return Row(
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
                'Oportunidades',
                style: TextStyle(
                  color: azul,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Gestiona tus oportunidades de venta y convierte más proyectos.',
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
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar cliente, proyecto, oportunidad...',
              prefixIcon: const Icon(Icons.search, size: 18),
              filled: true,
              fillColor: Colors.white,
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
        const SizedBox(width: 10),
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
        const Text(
          'Michael Roque',
          style: TextStyle(
            color: azul,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const Icon(Icons.keyboard_arrow_down, color: azul),
      ],
    );
  }

  Widget _kpi({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? footer,
  }) {
    return Expanded(
      child: Container(
        height: 104,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    value,
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

  int _countByStage(String stage) {
    return _oportunidades.where((row) => row['etapa'] == stage).length;
  }

  Widget _filters() {
    final stages = _etapasFiltro;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borde),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 225,
            height: 40,
            child: TextField(
              controller: _buscar,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar oportunidad...',
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
          SizedBox(
            width: 190,
            height: 58,
            child: DropdownButtonFormField<String>(
              value: _etapa,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Etapa',
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: borde),
                ),
              ),
              items: stages
                  .map(
                    (stage) => DropdownMenuItem(
                      value: stage,
                      child: Text(
                        stage == 'TODAS' ? 'Todas' : stage,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _etapa = value);
                }
              },
            ),
          ),
          FilledButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.filter_alt_outlined, size: 17),
            label: const Text('Aplicar'),
            style: FilledButton.styleFrom(
              backgroundColor: azul2,
              foregroundColor: Colors.white,
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              _buscar.clear();
              setState(() => _etapa = 'TODAS');
            },
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Limpiar'),
          ),
          FilledButton.icon(
            onPressed: _nuevaOportunidad,
            icon: const Icon(Icons.add, size: 17),
            label: const Text('Nueva oportunidad'),
            style: FilledButton.styleFrom(
              backgroundColor: verde,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageChip(String stage) {
    final color = _etapaColor(stage);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        stage,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _probability(int value) {
    return SizedBox(
      width: 110,
      child: Row(
        children: [
          Text(
            '$value%',
            style: const TextStyle(
              color: azul,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value / 100,
                minHeight: 7,
                backgroundColor: const Color(0xFFE3EBF3),
                valueColor: const AlwaysStoppedAnimation<Color>(verde),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _table() {
    final rows = _filtradas;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borde),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.business_center_outlined,
                color: azul2,
                size: 21,
              ),
              const SizedBox(width: 7),
              Text(
                'Oportunidades Comerciales (${rows.length})',
                style: const TextStyle(
                  color: azul,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
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
              columnSpacing: 22,
              dataRowMinHeight: 55,
              dataRowMaxHeight: 65,
              headingTextStyle: const TextStyle(
                color: azul,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
              columns: const [
                DataColumn(label: Text('Cliente')),
                DataColumn(label: Text('Proyecto / Oportunidad')),
                DataColumn(label: Text('Valor estimado')),
                DataColumn(label: Text('Etapa')),
                DataColumn(label: Text('Probabilidad')),
                DataColumn(label: Text('Cierre estimado')),
                DataColumn(label: Text('Asesor')),
                DataColumn(label: Text('Acciones')),
              ],
              rows: rows.map((row) {
                final probability =
                    (row['probabilidad'] as num?)?.toInt() ?? 0;

                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 170,
                        child: Text(
                          row['cliente'].toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: azul,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 155,
                        child: Text(
                          row['proyecto'].toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        _money(row['monto']),
                        style: const TextStyle(
                          color: azul,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    DataCell(_stageChip(row['etapa'].toString())),
                    DataCell(_probability(probability)),
                    DataCell(
                      Text(
                        row['cierre'].toString(),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    DataCell(
                      Text(
                        row['asesor'].toString(),
                        style: const TextStyle(
                          color: azul,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Editar',
                            onPressed: () => _editarOportunidad(row),
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: azul2,
                              size: 17,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            onPressed: () => _eliminar(row),
                            icon: const Icon(
                              Icons.more_horiz,
                              color: azul,
                              size: 18,
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
        ],
      ),
    );
  }

  Widget _sidePanel() {
    final top = List<Map<String, dynamic>>.from(_oportunidades)
      ..sort(
        (a, b) => (b['monto'] as num).compareTo(a['monto'] as num),
      );

    return Column(
      children: [
        Container(
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
              const Row(
                children: [
                  Icon(Icons.emoji_events_outlined, color: naranja, size: 19),
                  SizedBox(width: 6),
                  Text(
                    'Top 5 oportunidades',
                    style: TextStyle(
                      color: azul,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const Divider(height: 18),
              for (int i = 0; i < top.length && i < 5; i++)
                _topRow(i + 1, top[i]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borde),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.event_note_outlined,
                    color: azul2,
                    size: 19,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Actividades próximas',
                    style: TextStyle(
                      color: azul,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Divider(height: 18),
              _ActivityPreview(
                time: '09:00',
                title: 'Llamada de seguimiento',
                client: 'Quimpac S.A.',
              ),
              _ActivityPreview(
                time: '11:00',
                title: 'Reunión técnica',
                client: 'Delcrosa S.A.C.',
              ),
              _ActivityPreview(
                time: '14:30',
                title: 'Enviar propuesta',
                client: 'V & V BRAVO S.A.C.',
              ),
              _ActivityPreview(
                time: '16:00',
                title: 'Seguimiento comercial',
                client: 'Shoogang',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _topRow(int index, Map<String, dynamic> row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: index == 1
                  ? naranja.withValues(alpha: .15)
                  : const Color(0xFFF0F5FA),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: azul,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row['cliente'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: azul,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  row['proyecto'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF71869A),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _money(row['monto']),
            style: const TextStyle(
              color: azul,
              fontSize: 9,
              fontWeight: FontWeight.w900,
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
                    icon: Icons.gps_fixed_outlined,
                    title: 'Total oportunidades',
                    value: '${_oportunidades.length}',
                    color: azul2,
                    footer: 'Este mes',
                  ),
                  const SizedBox(width: 10),
                  _kpi(
                    icon: Icons.access_time_rounded,
                    title: 'En evaluación',
                    value: '${_countByStage('En evaluación')}',
                    color: naranja,
                    footer: 'En análisis',
                  ),
                  const SizedBox(width: 10),
                  _kpi(
                    icon: Icons.description_outlined,
                    title: 'Propuesta enviada',
                    value: '${_countByStage('Propuesta enviada')}',
                    color: morado,
                    footer: 'Cotizaciones',
                  ),
                  const SizedBox(width: 10),
                  _kpi(
                    icon: Icons.handshake_outlined,
                    title: 'Negociación',
                    value: '${_countByStage('Negociación')}',
                    color: naranja,
                    footer: 'En negociación',
                  ),
                  const SizedBox(width: 10),
                  _kpi(
                    icon: Icons.emoji_events_outlined,
                    title: 'Ganadas',
                    value: '${_countByStage('Ganada')}',
                    color: verde,
                    footer: 'Este mes',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _filters(),
              const SizedBox(height: 12),
              if (compact)
                _table()
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _table()),
                    const SizedBox(width: 12),
                    SizedBox(width: 285, child: _sidePanel()),
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
        child: _body(),
      ),
    );
  }

  Future<void> _nuevaOportunidad() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _OportunidadDialog(clientes: _oportunidades.map((e) => {'nombre': e['cliente'], 'codigo': ''}).toList()),
    );

    if (result == null) return;

    setState(() {
      _oportunidades.add(result);
    });
  }

  Future<void> _editarOportunidad(Map<String, dynamic> row) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _OportunidadDialog(initial: row, clientes: _oportunidades.map((e) => {'nombre': e['cliente'], 'codigo': ''}).toList()),
    );

    if (result == null) return;

    final index = _oportunidades.indexOf(row);
    if (index < 0) return;

    setState(() {
      _oportunidades[index] = result;
    });
  }

  void _eliminar(Map<String, dynamic> row) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Oportunidad',
          style: TextStyle(color: azul, fontWeight: FontWeight.w900),
        ),
        content: Text(
          '¿Qué deseas hacer con "${row['proyecto']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _oportunidades.remove(row));
            },
            style: FilledButton.styleFrom(backgroundColor: rojo),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _ActivityPreview extends StatelessWidget {
  const _ActivityPreview({
    required this.time,
    required this.title,
    required this.client,
  });

  final String time;
  final String title;
  final String client;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Text(
              time,
              style: const TextStyle(
                color: Color(0xFF1686E8),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Icon(
            Icons.event_note_outlined,
            size: 16,
            color: Color(0xFF1686E8),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF063B63),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  client,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF71869A),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OportunidadDialog extends StatefulWidget {
  const _OportunidadDialog({this.initial, required this.clientes});

  final Map<String, dynamic>? initial;
  final List<Map<String, dynamic>> clientes;

  @override
  State<_OportunidadDialog> createState() => _OportunidadDialogState();
}

class _OportunidadDialogState extends State<_OportunidadDialog> {
  static const Color azul = Color(0xFF063B63);
  static const Color borde = Color(0xFFE0E7EF);
  final _cliente = TextEditingController();
  final _proyecto = TextEditingController();
  final _monto = TextEditingController();
  final _probabilidad = TextEditingController();
  final _cierre = TextEditingController();

  String _etapa = 'En evaluación';
  List<String> _etapasCatalogo = const ['En evaluación'];
  String _asesor = 'Michael Roque';
  String _clienteSeleccionado = '';

  @override
  void initState() {
    super.initState();
    _cargarEtapas();
    final row = widget.initial;
    if (row != null) {
      _cliente.text = row['cliente']?.toString() ?? '';
      _clienteSeleccionado = _cliente.text;
      _proyecto.text = row['proyecto']?.toString() ?? '';
      _monto.text = row['monto']?.toString() ?? '';
      _probabilidad.text = row['probabilidad']?.toString() ?? '50';
      _cierre.text = row['cierre']?.toString() ?? '';
      _etapa = row['etapa']?.toString() ?? _etapa;
      _asesor = row['asesor']?.toString() ?? _asesor;
    }
  }

  Future<void> _cargarEtapas() async {
    try {
      final etapas = await CrmCatalogosService.obtenerNombres('etapas_oportunidad');
      if (!mounted || etapas.isEmpty) return;
      setState(() {
        _etapasCatalogo = etapas;
        if (!_etapasCatalogo.contains(_etapa)) _etapa = _etapasCatalogo.first;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _cliente.dispose();
    _proyecto.dispose();
    _monto.dispose();
    _probabilidad.dispose();
    _cierre.dispose();
    super.dispose();
  }

  String _nombre(Map<String, dynamic> c) => c['nombre']?.toString() ?? '';
  String _codigo(Map<String, dynamic> c) => c['codigo']?.toString() ?? '';

  InputDecoration _campo({required String label, required String hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, color: azul),
      filled: true,
      fillColor: const Color(0xFFF9FBFD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borde)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borde)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: azul, width: 1.5)),
    );
  }

  Future<void> _seleccionarCierre() async {
    final base = DateTime.tryParse(_cierre.text);
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
      initialDate: base ?? DateTime.now(),
    );
    if (date != null && mounted) {
      setState(() => _cierre.text = DateFormat('dd/MM/yyyy').format(date));
    }
  }

  void _guardar() {
    final cliente = _cliente.text.trim();
    final proyecto = _proyecto.text.trim();
    final monto = double.tryParse(_monto.text.trim().replaceAll(',', ''));
    final prob = int.tryParse(_probabilidad.text.trim());
    if (cliente.isEmpty || proyecto.isEmpty || monto == null || prob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa cliente, proyecto, monto y probabilidad.')),
      );
      return;
    }
    Navigator.pop(context, {
      'cliente': cliente,
      'proyecto': proyecto,
      'monto': monto,
      'etapa': _etapa,
      'probabilidad': prob.clamp(0, 100),
      'cierre': _cierre.text.trim().isEmpty ? '-' : _cierre.text.trim(),
      'asesor': _asesor,
    });
  }

  @override
  Widget build(BuildContext context) {
    const etapas = ['En evaluación', 'Propuesta enviada', 'Negociación', 'Ganada', 'Perdida'];
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 930, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 18, 18, 18),
              decoration: const BoxDecoration(
                color: azul,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(13)),
                    child: const Icon(Icons.business_center_outlined, color: Colors.white, size: 25),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.initial == null ? 'Nueva oportunidad' : 'Editar oportunidad',
                        style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      const Text('Registra un proyecto comercial y define su probabilidad de cierre.',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  children: [
                    Autocomplete<Map<String, dynamic>>(
                      displayStringForOption: (c) => _nombre(c),
                      optionsBuilder: (value) {
                        final q = value.text.trim().toLowerCase();
                        if (q.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
                        return widget.clientes.where((c) {
                          final n = _nombre(c).toLowerCase();
                          final code = _codigo(c).toLowerCase();
                          return n.contains(q) || code.contains(q);
                        }).take(20);
                      },
                      onSelected: (c) {
                        setState(() {
                          _clienteSeleccionado = _nombre(c);
                          _cliente.text = _nombre(c);
                        });
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        if (_cliente.text.isNotEmpty && controller.text.isEmpty) controller.text = _cliente.text;
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          onChanged: (v) {
                            _cliente.text = v;
                            if (_clienteSeleccionado.isNotEmpty) setState(() => _clienteSeleccionado = '');
                          },
                          decoration: _campo(label: 'Cliente *', hint: 'Escribe nombre, RUC o código', icon: Icons.business_outlined).copyWith(
                            suffixIcon: const Icon(Icons.search, color: Color(0xFF6C8299)),
                            helperText: _clienteSeleccionado.isEmpty ? 'Busca y selecciona un cliente' : 'Cliente seleccionado',
                            helperStyle: TextStyle(color: _clienteSeleccionado.isEmpty ? const Color(0xFF71869A) : Colors.green),
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        final lista = options.toList();
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 10,
                            borderRadius: BorderRadius.circular(14),
                            clipBehavior: Clip.antiAlias,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 880, maxHeight: 280),
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                shrinkWrap: true,
                                itemCount: lista.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final c = lista[i];
                                  return ListTile(
                                    leading: const CircleAvatar(backgroundColor: Color(0xFFEAF3FA), child: Icon(Icons.business_outlined, color: azul)),
                                    title: Text(_nombre(c), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                                    subtitle: Text(_codigo(c).isEmpty ? 'Cliente registrado' : 'RUC / Código: ${_codigo(c)}'),
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                                    onTap: () => onSelected(c),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(controller: _proyecto, decoration: _campo(label: 'Proyecto / Oportunidad *', hint: 'Ej. Sparq 140', icon: Icons.work_outline)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _monto, keyboardType: TextInputType.number, decoration: _campo(label: 'Valor estimado US\$ *', hint: 'Ej. 85000', icon: Icons.attach_money))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: _probabilidad, keyboardType: TextInputType.number, decoration: _campo(label: 'Probabilidad % *', hint: '0 - 100', icon: Icons.percent))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _etapasCatalogo.contains(_etapa) ? _etapa : (_etapasCatalogo.isEmpty ? null : _etapasCatalogo.first),
                      isExpanded: true,
                      decoration: _campo(label: 'Etapa', hint: 'Selecciona etapa', icon: Icons.flag_outlined),
                      items: _etapasCatalogo.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) { if (v != null) setState(() => _etapa = v); },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _seleccionarCierre,
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: _campo(label: 'Cierre estimado', hint: '', icon: Icons.calendar_today_outlined),
                              child: Text(_cierre.text.isEmpty ? 'Seleccionar fecha' : _cierre.text,
                                style: TextStyle(color: _cierre.text.isEmpty ? const Color(0xFF71869A) : azul, fontWeight: _cierre.text.isEmpty ? FontWeight.w400 : FontWeight.w800)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: TextEditingController(text: _asesor),
                            readOnly: true,
                            decoration: _campo(label: 'Asesor', hint: '', icon: Icons.person_outline),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              decoration: const BoxDecoration(color: Color(0xFFF7F9FC), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _guardar,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar oportunidad'),
                    style: FilledButton.styleFrom(backgroundColor: azul, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
