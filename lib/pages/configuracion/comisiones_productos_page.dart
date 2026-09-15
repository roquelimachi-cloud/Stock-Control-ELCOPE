import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/sesion.dart';
import '../../services/supabase/supabase_service.dart';

class ComisionesProductosPage extends StatefulWidget {
  const ComisionesProductosPage({super.key});

  @override
  State<ComisionesProductosPage> createState() =>
      _ComisionesProductosPageState();
}

class _ComisionesProductosPageState extends State<ComisionesProductosPage> {
  final _searchController = TextEditingController();
  final _dateFormat = DateFormat('dd/MM/yyyy');

  List<Map<String, dynamic>> _items = [];
  bool _cargando = true;
  String _filtroEstado = 'Todos';

  bool get _esAdministrador =>
      Sesion.esAdministrador ||
      Sesion.rol.trim().toLowerCase() == 'administrador';

  SupabaseClient get _client => SupabaseService.client;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (mounted) {
      setState(() => _cargando = true);
    }

    try {
      final data = await _client
          .from('comisiones_productos')
          .select()
          .order('codigo_producto');

      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(data);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      _mostrarError('No se pudieron cargar las comisiones: $e');
    }
  }

  List<Map<String, dynamic>> get _itemsFiltrados {
    final texto = _searchController.text.trim().toLowerCase();

    return _items.where((item) {
      final activo = item['activo'] == true;
      final codigo = '${item['codigo_producto'] ?? ''}'.toLowerCase();
      final descripcion = '${item['descripcion'] ?? ''}'.toLowerCase();

      final coincideTexto = texto.isEmpty ||
          codigo.contains(texto) ||
          descripcion.contains(texto);

      final coincideEstado = _filtroEstado == 'Todos' ||
          (_filtroEstado == 'Activos' && activo) ||
          (_filtroEstado == 'Inactivos' && !activo);

      return coincideTexto && coincideEstado;
    }).toList();
  }

  Future<void> _guardar({Map<String, dynamic>? existente}) async {
    if (!_esAdministrador) {
      _mostrarError('Solo un administrador puede gestionar las comisiones.');
      return;
    }

    final resultado = await showDialog<_ComisionFormResult>(
      context: context,
      builder: (_) => _ComisionFormDialog(
        client: _client,
        dateFormat: _dateFormat,
        existente: existente,
      ),
    );

    if (resultado == null) return;

    try {
      final producto = await _buscarProducto(resultado.codigo);
      final descripcion = resultado.descripcion.trim().isEmpty
          ? '${producto?['descripcion'] ?? ''}'
          : resultado.descripcion.trim();

      final datos = <String, dynamic>{
        'producto_id': producto?['id'],
        'codigo_producto': resultado.codigo,
        'descripcion': descripcion,
        'porcentaje': resultado.porcentaje,
        'vigente_desde': resultado.vigenteDesde.toIso8601String().split('T').first,
        'vigente_hasta': resultado.vigenteHasta?.toIso8601String().split('T').first,
        'activo': resultado.activo,
        'created_by': existente == null ? Sesion.idUsuario : existente['created_by'],
      };

      if (existente == null) {
        await _client.from('comisiones_productos').insert(datos);
      } else {
        await _client
            .from('comisiones_productos')
            .update(datos)
            .eq('id', existente['id']);
      }

      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comisión guardada correctamente.')),
        );
      }
    } catch (e) {
      _mostrarError('No se pudo guardar la comisión: $e');
    }
  }

  Future<Map<String, dynamic>?> _buscarProducto(String codigo) async {
    final resultado = await _client
        .from('productos')
        .select('id, codigo, descripcion')
        .ilike('codigo', codigo)
        .limit(1)
        .maybeSingle();

    return resultado;
  }

  Future<void> _cambiarEstado(Map<String, dynamic> item) async {
    if (!_esAdministrador) {
      _mostrarError('Solo un administrador puede cambiar el estado.');
      return;
    }

    final activo = item['activo'] == true;

    try {
      await _client
          .from('comisiones_productos')
          .update({'activo': !activo})
          .eq('id', item['id']);
      await _cargar();
    } catch (e) {
      _mostrarError('No se pudo cambiar el estado: $e');
    }
  }

  Future<void> _verHistorial(Map<String, dynamic> item) async {
    try {
      final codigo = '${item['codigo_producto'] ?? ''}';
      final data = await _client
          .from('comisiones_productos')
          .select()
          .eq('codigo_producto', codigo)
          .order('vigente_desde', ascending: false);

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Historial · $codigo'),
          content: SizedBox(
            width: 700,
            child: data.isEmpty
                ? const Text('No hay historial disponible.')
                : SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Desde')),
                        DataColumn(label: Text('Hasta')),
                        DataColumn(label: Text('%')),
                        DataColumn(label: Text('Estado')),
                      ],
                      rows: List<DataRow>.from(
                        data.map<DataRow>((row) {
                          return DataRow(
                            cells: [
                              DataCell(Text(_fecha(row['vigente_desde']))),
                              DataCell(Text(_fecha(row['vigente_hasta']))),
                              DataCell(Text('${row['porcentaje']}%')),
                              DataCell(Text(
                                row['activo'] == true ? 'Activo' : 'Inactivo',
                              )),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      _mostrarError('No se pudo consultar el historial: $e');
    }
  }

  String _fecha(dynamic value) {
    if (value == null || '$value'.trim().isEmpty) return '—';
    final date = DateTime.tryParse('$value');
    if (date == null) return '$value';
    return _dateFormat.format(date);
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF087A4A),
        foregroundColor: Colors.white,
        title: const Text('Comisiones por producto'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargando ? null : _cargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildToolbar(),
            const SizedBox(height: 16),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _itemsFiltrados.isEmpty
                      ? _buildEmpty()
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 700) {
                              return _buildMobileList();
                            }
                            return _buildDesktopTable();
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: _esAdministrador
          ? FloatingActionButton.extended(
              onPressed: () => _guardar(),
              backgroundColor: const Color(0xFF087A4A),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Nueva comisión'),
            )
          : null,
    );
  }

  Widget _buildToolbar() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 360,
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Buscar producto',
              hintText: 'Código o descripción',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            initialValue: _filtroEstado,
            decoration: const InputDecoration(
              labelText: 'Estado',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'Todos', child: Text('Todos')),
              DropdownMenuItem(value: 'Activos', child: Text('Activos')),
              DropdownMenuItem(value: 'Inactivos', child: Text('Inactivos')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _filtroEstado = value);
              }
            },
          ),
        ),
        if (_esAdministrador)
          FilledButton.icon(
            onPressed: () => _guardar(),
            icon: const Icon(Icons.add),
            label: const Text('Nueva comisión'),
          ),
      ],
    );
  }

  Widget _buildDesktopTable() {
    return Card(
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Código')),
                DataColumn(label: Text('Descripción')),
                DataColumn(label: Text('% Comisión')),
                DataColumn(label: Text('Desde')),
                DataColumn(label: Text('Hasta')),
                DataColumn(label: Text('Estado')),
                DataColumn(label: Text('Acciones')),
              ],
              rows: _itemsFiltrados.map((item) {
                final activo = item['activo'] == true;
                return DataRow(
                  cells: [
                    DataCell(Text('${item['codigo_producto'] ?? ''}')),
                    DataCell(
                      SizedBox(
                        width: 280,
                        child: Text(
                          '${item['descripcion'] ?? '—'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text('${item['porcentaje'] ?? 0}%')),
                    DataCell(Text(_fecha(item['vigente_desde']))),
                    DataCell(Text(_fecha(item['vigente_hasta']))),
                    DataCell(_EstadoChip(activo: activo)),
                    DataCell(_buildActions(item)),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList() {
    return ListView.separated(
      itemCount: _itemsFiltrados.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _itemsFiltrados[index];
        final activo = item['activo'] == true;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item['codigo_producto'] ?? ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    _EstadoChip(activo: activo),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${item['descripcion'] ?? '—'}'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    Text('Comisión: ${item['porcentaje'] ?? 0}%'),
                    Text('Desde: ${_fecha(item['vigente_desde'])}'),
                    Text('Hasta: ${_fecha(item['vigente_hasta'])}'),
                  ],
                ),
                const SizedBox(height: 8),
                _buildActions(item),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActions(Map<String, dynamic> item) {
    return Wrap(
      spacing: 2,
      children: [
        IconButton(
          tooltip: 'Historial',
          onPressed: () => _verHistorial(item),
          icon: const Icon(Icons.history),
        ),
        if (_esAdministrador)
          IconButton(
            tooltip: 'Editar',
            onPressed: () => _guardar(existente: item),
            icon: const Icon(Icons.edit),
          ),
        if (_esAdministrador)
          IconButton(
            tooltip: item['activo'] == true ? 'Desactivar' : 'Activar',
            onPressed: () => _cambiarEstado(item),
            icon: Icon(
              item['activo'] == true ? Icons.toggle_on : Icons.toggle_off,
            ),
          ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.percent, size: 64, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          const Text(
            'No hay comisiones para mostrar.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (_esAdministrador)
            FilledButton.icon(
              onPressed: () => _guardar(),
              icon: const Icon(Icons.add),
              label: const Text('Registrar primera comisión'),
            ),
        ],
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  final bool activo;

  const _EstadoChip({required this.activo});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        activo ? Icons.check_circle : Icons.cancel,
        size: 18,
      ),
      label: Text(activo ? 'Activo' : 'Inactivo'),
    );
  }
}

class _ComisionFormResult {
  final String codigo;
  final String descripcion;
  final double porcentaje;
  final DateTime vigenteDesde;
  final DateTime? vigenteHasta;
  final bool activo;

  const _ComisionFormResult({
    required this.codigo,
    required this.descripcion,
    required this.porcentaje,
    required this.vigenteDesde,
    required this.vigenteHasta,
    required this.activo,
  });
}

class _ComisionFormDialog extends StatefulWidget {
  final SupabaseClient client;
  final DateFormat dateFormat;
  final Map<String, dynamic>? existente;

  const _ComisionFormDialog({
    required this.client,
    required this.dateFormat,
    this.existente,
  });

  @override
  State<_ComisionFormDialog> createState() => _ComisionFormDialogState();
}

class _ComisionFormDialogState extends State<_ComisionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codigoController;
  late final TextEditingController _descripcionController;
  late final TextEditingController _porcentajeController;

  late DateTime _vigenteDesde;
  DateTime? _vigenteHasta;
  late bool _activo;
  bool _buscandoProducto = false;

  @override
  void initState() {
    super.initState();
    final item = widget.existente;

    _codigoController = TextEditingController(
      text: '${item?['codigo_producto'] ?? ''}',
    );
    _descripcionController = TextEditingController(
      text: '${item?['descripcion'] ?? ''}',
    );
    _porcentajeController = TextEditingController(
      text: '${item?['porcentaje'] ?? ''}',
    );

    _vigenteDesde =
        DateTime.tryParse('${item?['vigente_desde']}') ?? DateTime.now();
    _vigenteHasta = item?['vigente_hasta'] == null
        ? null
        : DateTime.tryParse('${item?['vigente_hasta']}');
    _activo = item?['activo'] != false;
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _descripcionController.dispose();
    _porcentajeController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha({required bool desde}) async {
    final inicial = desde ? _vigenteDesde : (_vigenteHasta ?? _vigenteDesde);
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (seleccionada == null) return;

    setState(() {
      if (desde) {
        _vigenteDesde = seleccionada;
      } else {
        _vigenteHasta = seleccionada;
      }
    });
  }

  Future<void> _buscarProducto() async {
    final codigo = _codigoController.text.trim();
    if (codigo.isEmpty) return;

    setState(() => _buscandoProducto = true);

    try {
      final producto = await widget.client
          .from('productos')
          .select('id, codigo, descripcion')
          .ilike('codigo', codigo)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;

      if (producto == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró ese producto.')),
        );
      } else {
        _codigoController.text = '${producto['codigo'] ?? codigo}';
        _descripcionController.text = '${producto['descripcion'] ?? ''}';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al buscar producto: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _buscandoProducto = false);
      }
    }
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;

    if (_vigenteHasta != null && _vigenteHasta!.isBefore(_vigenteDesde)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fecha hasta no puede ser anterior a la fecha desde.'),
        ),
      );
      return;
    }

    final porcentaje = double.tryParse(
      _porcentajeController.text.trim().replaceAll(',', '.'),
    );

    if (porcentaje == null || porcentaje < 0 || porcentaje > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un porcentaje entre 0 y 100.')),
      );
      return;
    }

    Navigator.pop(
      context,
      _ComisionFormResult(
        codigo: _codigoController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        porcentaje: porcentaje,
        vigenteDesde: _vigenteDesde,
        vigenteHasta: _vigenteHasta,
        activo: _activo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.existente != null;

    return AlertDialog(
      title: Text(esEdicion ? 'Editar comisión' : 'Nueva comisión'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _codigoController,
                        decoration: const InputDecoration(
                          labelText: 'Código del producto *',
                          hintText: 'Ej. WS2/0',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa el código';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _buscandoProducto ? null : _buscarProducto,
                        child: _buscandoProducto
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.search),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descripcionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _porcentajeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Porcentaje de comisión *',
                    hintText: 'Ej. 1.00',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final numero = double.tryParse(
                      (value ?? '').trim().replaceAll(',', '.'),
                    );
                    if (numero == null || numero < 0 || numero > 100) {
                      return 'Entre 0 y 100';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final vertical = constraints.maxWidth < 450;
                    final desde = _FechaSelector(
                      label: 'Vigente desde',
                      fecha: _vigenteDesde,
                      dateFormat: widget.dateFormat,
                      onTap: () => _seleccionarFecha(desde: true),
                    );
                    final hasta = _FechaSelector(
                      label: 'Vigente hasta',
                      fecha: _vigenteHasta,
                      dateFormat: widget.dateFormat,
                      onTap: () => _seleccionarFecha(desde: false),
                      onClear: _vigenteHasta == null
                          ? null
                          : () => setState(() => _vigenteHasta = null),
                    );

                    if (vertical) {
                      return Column(
                        children: [desde, const SizedBox(height: 12), hasta],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: desde),
                        const SizedBox(width: 12),
                        Expanded(child: hasta),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Comisión activa'),
                  value: _activo,
                  onChanged: (value) => setState(() => _activo = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _guardar,
          icon: const Icon(Icons.save),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _FechaSelector extends StatelessWidget {
  final String label;
  final DateTime? fecha;
  final DateFormat dateFormat;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FechaSelector({
    required this.label,
    required this.fecha,
    required this.dateFormat,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: onClear == null
              ? const Icon(Icons.calendar_month)
              : IconButton(
                  tooltip: 'Limpiar',
                  onPressed: onClear,
                  icon: const Icon(Icons.clear),
                ),
        ),
        child: Text(
          fecha == null ? 'Sin fecha' : dateFormat.format(fecha!),
        ),
      ),
    );
  }
}
