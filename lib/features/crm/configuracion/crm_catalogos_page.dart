import 'package:flutter/material.dart';

import '../../../services/sesion.dart';
import '../../../services/supabase/supabase_service.dart';

class CrmCatalogosPage extends StatefulWidget {
  const CrmCatalogosPage({super.key});

  @override
  State<CrmCatalogosPage> createState() => _CrmCatalogosPageState();
}

class _CrmCatalogosPageState extends State<CrmCatalogosPage> {
  static const _fondo = Color(0xFF071F35);
  static const _panel = Color(0xFF0A3049);
  static const _azul = Color(0xFF0B4268);
  static const _borde = Color(0xFF12658A);
  static const _cian = Color(0xFF11B9F5);
  static const _verde = Color(0xFF00D6A3);
  static const _texto = Color(0xFFF3F8FC);
  static const _suave = Color(0xFFAAC6D8);

  final _buscar = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _cargando = true;
  bool _guardando = false;
  String _categoria = 'TODAS';
  String? _error;

  bool get _esAdmin {
    final usuario = Sesion.usuario.trim().toLowerCase();
    final rol = Sesion.rol.trim().toLowerCase();
    return usuario == 'mroque';
  }

  @override
  void initState() {
    super.initState();
    _buscar.addListener(_refrescar);
    _cargar();
  }

  @override
  void dispose() {
    _buscar.removeListener(_refrescar);
    _buscar.dispose();
    super.dispose();
  }

  void _refrescar() {
    if (mounted) setState(() {});
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  Future<void> _cargar() async {
    if (!_esAdmin) {
      setState(() {
        _cargando = false;
        _error = 'Acceso restringido. Solo el administrador puede gestionar catálogos.';
      });
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final raw = await SupabaseService.client.rpc(
        'crm_catalogos_admin_listar',
        params: {'p_usuario_id': Sesion.idUsuario},
      );
      final filas = (raw as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = filas;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString();
      });
    }
  }

  List<String> get _categorias {
    final values = _items.map((e) => _s(e['categoria'])).where((e) => e.isNotEmpty).toSet().toList()..sort();
    return ['TODAS', ...values];
  }

  List<Map<String, dynamic>> get _filtrados {
    final q = _buscar.text.trim().toLowerCase();
    return _items.where((e) {
      if (_categoria != 'TODAS' && _s(e['categoria']) != _categoria) return false;
      if (q.isEmpty) return true;
      return '${e['categoria']} ${e['nombre']} ${e['descripcion']}'.toLowerCase().contains(q);
    }).toList();
  }

  void _aviso(String mensaje, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensaje),
      backgroundColor: error ? const Color(0xFFB4234B) : const Color(0xFF087C67),
    ));
  }

  Future<void> _editar([Map<String, dynamic>? item]) async {
    final formKey = GlobalKey<FormState>();
    final categoriaCtrl = TextEditingController(text: _s(item?['categoria']));
    final nombreCtrl = TextEditingController(text: _s(item?['nombre']));
    final descripcionCtrl = TextEditingController(text: _s(item?['descripcion']));
    final ordenCtrl = TextEditingController(text: _s(item?['orden'] ?? 0));
    bool activo = item?['activo'] != false;
    final categoriasExistentes = _items.map((e) => _s(e['categoria'])).where((e) => e.isNotEmpty).toSet().toList()..sort();
    String? categoriaSeleccionada = categoriaCtrl.text.isEmpty ? null : categoriaCtrl.text;
    final nuevo = item == null;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          backgroundColor: _panel,
          surfaceTintColor: Colors.transparent,
          title: Row(children: [
            Icon(nuevo ? Icons.add_circle_outline : Icons.edit_note, color: _cian),
            const SizedBox(width: 10),
            Expanded(child: Text(nuevo ? 'Nuevo elemento de catálogo' : 'Editar catálogo', style: const TextStyle(color: _texto, fontWeight: FontWeight.w800))),
          ]),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  DropdownButtonFormField<String>(
                    value: categoriaSeleccionada,
                    dropdownColor: _panel,
                    decoration: _decoracion('Categoría *', Icons.category_outlined),
                    items: [
                      ...categoriasExistentes.map((v) => DropdownMenuItem(value: v, child: Text(v))),
                      if (categoriaSeleccionada != null && !categoriasExistentes.contains(categoriaSeleccionada))
                        DropdownMenuItem(value: categoriaSeleccionada, child: Text(categoriaSeleccionada!)),
                    ],
                    onChanged: (v) => setDialog(() {
                      categoriaSeleccionada = v;
                      categoriaCtrl.text = v ?? '';
                    }),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Selecciona una categoría' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: categoriaCtrl,
                    style: const TextStyle(color: _texto),
                    decoration: _decoracion('O escribir nueva categoría', Icons.create_outlined),
                    onChanged: (v) => setDialog(() => categoriaSeleccionada = v.trim().isEmpty ? null : v.trim()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'La categoría es obligatoria' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nombreCtrl,
                    style: const TextStyle(color: _texto),
                    decoration: _decoracion('Nombre de la opción *', Icons.label_outline),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descripcionCtrl,
                    style: const TextStyle(color: _texto),
                    maxLines: 3,
                    decoration: _decoracion('Descripción (opcional)', Icons.notes_rounded),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: ordenCtrl,
                    style: const TextStyle(color: _texto),
                    keyboardType: TextInputType.number,
                    decoration: _decoracion('Orden de aparición', Icons.sort),
                    validator: (v) => int.tryParse((v ?? '').trim()) == null ? 'Ingresa un número' : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Opción activa', style: TextStyle(color: _texto)),
                    subtitle: const Text('Las opciones inactivas no deben aparecer en nuevos registros.', style: TextStyle(color: _suave, fontSize: 12)),
                    value: activo,
                    activeColor: _verde,
                    onChanged: (v) => setDialog(() => activo = v),
                  ),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _cian, foregroundColor: _fondo),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      try {
        setState(() => _guardando = true);
        await SupabaseService.client.rpc('crm_catalogos_admin_guardar', params: {
          'p_usuario_id': Sesion.idUsuario,
          'p_id': item?['id'],
          'p_categoria': categoriaCtrl.text.trim(),
          'p_nombre': nombreCtrl.text.trim(),
          'p_descripcion': descripcionCtrl.text.trim(),
          'p_orden': int.tryParse(ordenCtrl.text.trim()) ?? 0,
          'p_activo': activo,
        });
        _aviso(nuevo ? 'Opción agregada al catálogo.' : 'Catálogo actualizado.');
        await _cargar();
      } catch (e) {
        _aviso('No se pudo guardar: $e', error: true);
      } finally {
        if (mounted) setState(() => _guardando = false);
      }
    }
    categoriaCtrl.dispose();
    nombreCtrl.dispose();
    descripcionCtrl.dispose();
    ordenCtrl.dispose();
  }

  InputDecoration _decoracion(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: _suave),
    prefixIcon: Icon(icon, color: _cian),
    filled: true,
    fillColor: const Color(0xFF082940),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borde)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borde)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cian, width: 1.5)),
  );

  @override
  Widget build(BuildContext context) {
    if (!_esAdmin) {
      return const Scaffold(backgroundColor: _fondo, body: Center(child: Text('Acceso restringido al administrador.', style: TextStyle(color: _texto))));
    }
    final visibles = _filtrados;
    final categorias = _items.map((e) => _s(e['categoria'])).toSet().length;
    final activos = _items.where((e) => e['activo'] == true).length;
    return Scaffold(
      backgroundColor: _fondo,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: _azul, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.tune_rounded, color: _cian, size: 27)),
              const SizedBox(width: 13),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Catálogos del CRM', style: TextStyle(color: _texto, fontSize: 25, fontWeight: FontWeight.w900)),
                SizedBox(height: 3),
                Text('Administra las opciones de todos los módulos desde un solo lugar.', style: TextStyle(color: _suave, fontSize: 13)),
              ])),
              OutlinedButton.icon(onPressed: _cargando || _guardando ? null : _cargar, icon: const Icon(Icons.refresh), label: const Text('Actualizar')),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _verde, foregroundColor: _fondo, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                onPressed: _guardando ? null : () => _editar(),
                icon: const Icon(Icons.add),
                label: const Text('Nueva opción', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              _resumen('Opciones', '${_items.length}', Icons.list_alt, _cian),
              const SizedBox(width: 10),
              _resumen('Categorías', '$categorias', Icons.category_outlined, const Color(0xFFAA83FF)),
              const SizedBox(width: 10),
              _resumen('Activas', '$activos', Icons.check_circle_outline, _verde),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: _borde)),
              child: Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                SizedBox(width: 300, child: TextField(
                  controller: _buscar,
                  style: const TextStyle(color: _texto),
                  decoration: _decoracion('Buscar categoría u opción', Icons.search),
                )),
                SizedBox(width: 250, child: DropdownButtonFormField<String>(
                  value: _categorias.contains(_categoria) ? _categoria : 'TODAS',
                  dropdownColor: _panel,
                  style: const TextStyle(color: _texto),
                  decoration: _decoracion('Filtrar categoría', Icons.filter_list),
                  items: _categorias.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => _categoria = v ?? 'TODAS'),
                )),
              ]),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(15), border: Border.all(color: _borde)),
                child: _cargando
                  ? const Center(child: CircularProgressIndicator(color: _cian))
                  : _error != null
                    ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.error_outline, color: Color(0xFFFF5277), size: 40),
                        const SizedBox(height: 10),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _texto)),
                        const SizedBox(height: 12),
                        FilledButton.icon(onPressed: _cargar, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
                      ])))
                    : visibles.isEmpty
                      ? const Center(child: Text('No hay opciones para los filtros seleccionados.', style: TextStyle(color: _suave)))
                      : Column(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                            decoration: const BoxDecoration(color: Color(0xFF124D6A), borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
                            child: const Row(children: [
                              Expanded(flex: 2, child: Text('CATEGORÍA', style: TextStyle(color: _texto, fontWeight: FontWeight.w900, fontSize: 11))),
                              Expanded(flex: 3, child: Text('OPCIÓN', style: TextStyle(color: _texto, fontWeight: FontWeight.w900, fontSize: 11))),
                              Expanded(flex: 3, child: Text('DESCRIPCIÓN', style: TextStyle(color: _texto, fontWeight: FontWeight.w900, fontSize: 11))),
                              SizedBox(width: 68, child: Text('ORDEN', textAlign: TextAlign.center, style: TextStyle(color: _texto, fontWeight: FontWeight.w900, fontSize: 11))),
                              SizedBox(width: 82, child: Text('ESTADO', textAlign: TextAlign.center, style: TextStyle(color: _texto, fontWeight: FontWeight.w900, fontSize: 11))),
                              SizedBox(width: 52),
                            ]),
                          ),
                          Expanded(child: ListView.separated(
                            itemCount: visibles.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: _borde.withValues(alpha: .7)),
                            itemBuilder: (_, i) {
                              final e = visibles[i];
                              final activo = e['activo'] == true;
                              return InkWell(
                                onTap: () => _editar(e),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(children: [
                                    Expanded(flex: 2, child: Text(_s(e['categoria']), style: const TextStyle(color: _cian, fontWeight: FontWeight.w800, fontSize: 12))),
                                    Expanded(flex: 3, child: Text(_s(e['nombre']), style: const TextStyle(color: _texto, fontWeight: FontWeight.w700, fontSize: 13))),
                                    Expanded(flex: 3, child: Text(_s(e['descripcion']).isEmpty ? '—' : _s(e['descripcion']), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _suave, fontSize: 12))),
                                    SizedBox(width: 68, child: Text(_s(e['orden']), textAlign: TextAlign.center, style: const TextStyle(color: _texto))),
                                    SizedBox(width: 82, child: Center(child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                      decoration: BoxDecoration(color: activo ? _verde.withValues(alpha: .12) : const Color(0xFFFF5277).withValues(alpha: .12), borderRadius: BorderRadius.circular(20), border: Border.all(color: activo ? _verde : const Color(0xFFFF5277).withValues(alpha: .7))),
                                      child: Text(activo ? 'ACTIVA' : 'INACTIVA', style: TextStyle(color: activo ? _verde : const Color(0xFFFF5277), fontSize: 9, fontWeight: FontWeight.w900)),
                                    ))),
                                    SizedBox(width: 52, child: IconButton(tooltip: 'Editar', onPressed: _guardando ? null : () => _editar(e), icon: const Icon(Icons.edit_outlined, color: _cian))),
                                  ]),
                                ),
                              );
                            },
                          )),
                        ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _resumen(String titulo, String valor, IconData icono, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(13), border: Border.all(color: _borde)),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(11)), child: Icon(icono, color: color)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: const TextStyle(color: _suave, fontSize: 12)),
          Text(valor, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
        ])),
      ]),
    ),
  );
}
