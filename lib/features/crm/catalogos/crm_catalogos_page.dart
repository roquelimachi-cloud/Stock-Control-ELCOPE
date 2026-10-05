import 'package:flutter/material.dart';

import '../../../services/sesion.dart';
import '../../../services/supabase/supabase_service.dart';

class CrmCatalogosPage extends StatefulWidget {
  const CrmCatalogosPage({super.key});

  @override
  State<CrmCatalogosPage> createState() => _CrmCatalogosPageState();
}

class _CatalogoDef {
  final String codigo;
  final String nombre;
  final String descripcion;
  final IconData icono;
  const _CatalogoDef(this.codigo, this.nombre, this.descripcion, this.icono);
}

class _CrmCatalogosPageState extends State<CrmCatalogosPage> {
  static const azul = Color(0xFF0B3B63);
  static const azulClaro = Color(0xFF1468A8);
  static const verde = Color(0xFF0A9B61);
  static const fondo = Color(0xFFF4F7FA);
  static const borde = Color(0xFFDCE4EA);

  final db = SupabaseService.client;
  final buscar = TextEditingController();

  static const catalogos = <_CatalogoDef>[
    _CatalogoDef('tipos_gestion', 'Tipos de gestión',
        'Botones que aparecen en Actividades y Seguimientos.', Icons.touch_app_outlined),
    _CatalogoDef('tipos_actividad', 'Tipos de actividad',
        'Tipos utilizados para registrar actividades.', Icons.fact_check_outlined),
    _CatalogoDef('resultados_actividad', 'Resultados de actividad',
        'Resultados disponibles al registrar una actividad.', Icons.check_circle_outline),
    _CatalogoDef('proximas_acciones', 'Próximas acciones',
        'Acciones comerciales posteriores a una gestión.', Icons.next_plan_outlined),
    _CatalogoDef('etapas_oportunidad', 'Etapas de oportunidad',
        'Etapas del embudo comercial.', Icons.stacked_bar_chart_outlined),
    _CatalogoDef('estados_oportunidad', 'Estados de oportunidad',
        'Estados finales de las oportunidades.', Icons.flag_outlined),
    _CatalogoDef('fuentes_oportunidad', 'Fuentes de oportunidad',
        'Origen comercial de la oportunidad.', Icons.source_outlined),
    _CatalogoDef('motivos_perdida', 'Motivos de pérdida',
        'Razones por las que una oportunidad se pierde.', Icons.cancel_outlined),
    _CatalogoDef('tipos_tarea', 'Tipos de tarea',
        'Clasificación de tareas comerciales.', Icons.task_alt_outlined),
    _CatalogoDef('estados_tarea', 'Estados de tarea',
        'Estados disponibles para las tareas.', Icons.pending_actions_outlined),
    _CatalogoDef('prioridades_tarea', 'Prioridades de tarea',
        'Nivel de prioridad de las tareas.', Icons.priority_high_outlined),
    _CatalogoDef('motivos_tarea', 'Tipos de tarea detallados',
        'Motivos y objetivos de las tareas comerciales.', Icons.assignment_outlined),
    _CatalogoDef('motivos_visita', 'Motivos de visita',
        'Motivos al programar una visita.', Icons.location_on_outlined),
    _CatalogoDef('resultados_visita', 'Resultados de visita',
        'Resultados al finalizar una visita.', Icons.fact_check_outlined),
    _CatalogoDef('objetivos_visita', 'Objetivos de visita',
        'Objetivos comerciales de la visita.', Icons.flag_circle_outlined),
    _CatalogoDef('estados_seguimiento', 'Estados de seguimiento',
        'Estados de los seguimientos comerciales.', Icons.track_changes_outlined),
    _CatalogoDef('resultados_seguimiento', 'Resultados de seguimiento',
        'Resultados de los seguimientos.', Icons.task_alt_outlined),
    _CatalogoDef('vendedores', 'Vendedores',
        'Maestro de asesores comerciales.', Icons.badge_outlined),
    _CatalogoDef('sectores', 'Sectores',
        'Clasificación comercial de clientes.', Icons.business_outlined),
    _CatalogoDef('giros', 'Giros',
        'Actividad económica de clientes.', Icons.category_outlined),
    _CatalogoDef('familias', 'Familias',
        'Familias de productos.', Icons.account_tree_outlined),
    _CatalogoDef('clases', 'Clases',
        'Clases de producto.', Icons.layers_outlined),
    _CatalogoDef('colores', 'Colores',
        'Colores utilizados en productos.', Icons.palette_outlined),
    _CatalogoDef('presentaciones', 'Presentaciones',
        'Presentaciones comerciales.', Icons.inventory_2_outlined),
    _CatalogoDef('productos', 'Productos',
        'Maestro de productos.', Icons.category_outlined),
  ];

  int _seleccionado = 0;
  bool _cargando = true;
  bool _guardando = false;
  String? _error;
  List<Map<String, dynamic>> _filas = [];
  int _total = 0;

  _CatalogoDef get actual => catalogos[_seleccionado];

  bool get _esAdministrador {
    final rol = Sesion.rol.trim().toLowerCase();
    return rol == 'administrador' || rol == 'admin' || rol.contains('administrador');
  }

  // Los maestros existentes se consultan, pero no se editan desde este panel.
  bool get _esCatalogoEditable => !const {
        'vendedores',
        'familias',
        'clases',
        'colores',
        'presentaciones',
        'productos',
      }.contains(actual.codigo);

  @override
  void initState() {
    super.initState();
    buscar.addListener(_refrescarFiltro);
    _cargar();
  }

  @override
  void dispose() {
    buscar.dispose();
    super.dispose();
  }

  void _refrescarFiltro() => setState(() {});

  String _s(dynamic v) => v?.toString().trim() ?? '';

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final List<dynamic> data;
      if (_esCatalogoEditable) {
        data = await db
            .from('crm_catalogos')
            .select()
            .eq('categoria', actual.codigo)
            .order('orden')
            .order('nombre')
            .limit(500);
      } else {
        data = await db.from(actual.codigo).select().limit(500);
      }

      if (!mounted) return;
      setState(() {
        _filas = List<Map<String, dynamic>>.from(data);
        _total = _filas.length;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString();
        _filas = [];
        _total = 0;
      });
    }
  }

  List<Map<String, dynamic>> get _filtradas {
    final q = buscar.text.trim().toLowerCase();
    if (q.isEmpty) return _filas;
    return _filas.where((row) =>
        row.values.any((v) => _s(v).toLowerCase().contains(q))).toList();
  }

  String _principal(Map<String, dynamic> row) {
    for (final k in ['nombre', 'descripcion', 'razon_social', 'nombre_comercial', 'codigo']) {
      if (_s(row[k]).isNotEmpty) return _s(row[k]);
    }
    return row.values.isEmpty ? '-' : _s(row.values.first);
  }

  String _secundario(Map<String, dynamic> row) {
    for (final k in ['codigo', 'codigo_vendedor', 'ruc', 'descripcion', 'unidad']) {
      if (_s(row[k]).isNotEmpty) return _s(row[k]);
    }
    return '';
  }

  Widget _tarjeta(int index, _CatalogoDef c) {
    final selected = index == _seleccionado;
    return InkWell(
      onTap: () {
        setState(() {
          _seleccionado = index;
          buscar.clear();
        });
        _cargar();
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? azul : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? azul : borde),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected ? Colors.white24 : const Color(0xFFEAF6EF),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(c.icono, color: selected ? Colors.white : verde),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(c.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: selected ? Colors.white : azul,
                      fontWeight: FontWeight.w900)),
            ),
            if (selected)
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Future<void> _nuevo() async {
    if (!_esAdministrador || !_esCatalogoEditable) return;

    final nombre = TextEditingController();
    final descripcion = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Nuevo ${actual.nombre.toLowerCase()}'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombre,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  hintText: actual.codigo == 'tipos_gestion'
                      ? 'Ej. Videollamada'
                      : 'Nombre del elemento',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descripcion,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar')),
        ],
      ),
    );

    if (ok != true || nombre.text.trim().isEmpty) {
      nombre.dispose();
      descripcion.dispose();
      return;
    }

    try {
      setState(() => _guardando = true);
      final orden = _filas.fold<int>(0, (m, r) {
        final n = (r['orden'] as num?)?.toInt() ?? 0;
        return n > m ? n : m;
      });

      await db.from('crm_catalogos').insert({
        'categoria': actual.codigo,
        'nombre': nombre.text.trim(),
        'descripcion': descripcion.text.trim(),
        'orden': orden + 1,
        'activo': true,
      });
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    } finally {
      nombre.dispose();
      descripcion.dispose();
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _editar(Map<String, dynamic> row) async {
    if (!_esAdministrador || !_esCatalogoEditable) return;

    final nombre = TextEditingController(text: _s(row['nombre']));
    final descripcion = TextEditingController(text: _s(row['descripcion']));

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Editar ${actual.nombre.toLowerCase()}'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nombre,
                  decoration: const InputDecoration(
                      labelText: 'Nombre', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: descripcion,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Descripción', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar')),
        ],
      ),
    );

    if (ok != true || nombre.text.trim().isEmpty) {
      nombre.dispose();
      descripcion.dispose();
      return;
    }

    try {
      await db.from('crm_catalogos').update({
        'nombre': nombre.text.trim(),
        'descripcion': descripcion.text.trim(),
      }).eq('id', row['id']);
      await _cargar();
    } finally {
      nombre.dispose();
      descripcion.dispose();
    }
  }

  Future<void> _toggle(Map<String, dynamic> row) async {
    if (!_esAdministrador || !_esCatalogoEditable) return;
    await db.from('crm_catalogos')
        .update({'activo': row['activo'] != true}).eq('id', row['id']);
    await _cargar();
  }

  Future<void> _eliminar(Map<String, dynamic> row) async {
    if (!_esAdministrador || !_esCatalogoEditable) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar elemento'),
        content: Text('¿Eliminar "${_principal(row)}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    await db.from('crm_catalogos').delete().eq('id', row['id']);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final filas = _filtradas;

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: azul,
        elevation: 0,
        leading: IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded)),
        title: const Text('Catálogos CRM',
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (_esAdministrador && _esCatalogoEditable)
            FilledButton.icon(
                onPressed: _guardando ? null : _nuevo,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Agregar')),
          IconButton(
              onPressed: _cargando ? null : _cargar,
              icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(builder: (context, c) {
        final compact = c.maxWidth < 1000;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [azul, azulClaro]),
                    borderRadius: BorderRadius.circular(18)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Catálogos del CRM',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900)),
                    SizedBox(height: 6),
                    Text(
                        'Configura los valores que alimentan actividades, seguimientos, oportunidades, tareas y visitas.',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (compact)
                SizedBox(
                  height: 115,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: catalogos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) =>
                        SizedBox(width: 240, child: _tarjeta(i, catalogos[i])),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisExtent: 72,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10),
                  itemCount: catalogos.length,
                  itemBuilder: (_, i) => _tarjeta(i, catalogos[i]),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borde)),
                child: Row(children: [
                  Expanded(
                      child: Text(actual.nombre.toUpperCase(),
                          style: const TextStyle(
                              color: azul,
                              fontWeight: FontWeight.w900,
                              fontSize: 15))),
                  SizedBox(
                    width: compact ? 230 : 320,
                    height: 42,
                    child: TextField(
                      controller: buscar,
                      decoration: InputDecoration(
                          hintText:
                              'Buscar en ${actual.nombre.toLowerCase()}...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: fondo,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none)),
                    ),
                  )
                ]),
              ),
              const SizedBox(height: 12),
              if (_cargando)
                const SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    color: Colors.white,
                    child: Text(_error!))
              else
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borde)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Registros: ${filas.length}${filas.length != _total ? ' de $_total' : ''}',
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 12)),
                          const SizedBox(height: 8),
                          if (filas.isEmpty)
                            const Padding(
                                padding: EdgeInsets.all(36),
                                child: Center(
                                    child:
                                        Text('No hay registros para mostrar.')))
                          else
                            ...filas.take(200).map((row) => ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                      backgroundColor:
                                          const Color(0xFFEAF6EF),
                                      child: Icon(actual.icono,
                                          color: verde, size: 18)),
                                  title: Text(_principal(row),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: azul)),
                                  subtitle: Text(_secundario(row)),
                                  trailing: _esAdministrador &&
                                          _esCatalogoEditable
                                      ? Wrap(children: [
                                          IconButton(
                                              tooltip: 'Editar',
                                              onPressed: () => _editar(row),
                                              icon: const Icon(
                                                  Icons.edit_outlined)),
                                          IconButton(
                                              tooltip: row['activo'] == true
                                                  ? 'Desactivar'
                                                  : 'Activar',
                                              onPressed: () => _toggle(row),
                                              icon: Icon(row['activo'] == true
                                                  ? Icons.toggle_on_outlined
                                                  : Icons
                                                      .toggle_off_outlined)),
                                          IconButton(
                                              tooltip: 'Eliminar',
                                              onPressed: () => _eliminar(row),
                                              icon: const Icon(
                                                  Icons.delete_outline)),
                                        ])
                                      : null)),
                        ]),
                  ),
                )
            ],
          ),
        );
      }),
    );
  }
}
