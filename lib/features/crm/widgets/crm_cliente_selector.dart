import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/sesion.dart';
import '../../../services/supabase/supabase_service.dart';

/// Selector reutilizable de clientes para CRM.
///
/// Permite buscar por RUC/código o razón social y, al seleccionar,
/// devuelve el registro completo del cliente. El valor escrito en el
/// controller queda como codigo_cliente para guardar en las tablas CRM.
class CrmClienteSelector extends StatefulWidget {
  const CrmClienteSelector({
    super.key,
    required this.controller,
    this.onSelected,
    this.enabled = true,
    this.label = 'Cliente',
  });

  final TextEditingController controller;
  final ValueChanged<Map<String, dynamic>>? onSelected;
  final bool enabled;
  final String label;

  @override
  State<CrmClienteSelector> createState() => _CrmClienteSelectorState();
}

class _CrmClienteSelectorState extends State<CrmClienteSelector> {
  final _db = SupabaseService.client;
  final _focusNode = FocusNode();
  Timer? _debounce;

  List<Map<String, dynamic>> _resultados = [];
  Map<String, dynamic>? _seleccionado;
  bool _buscando = false;
  bool _mostrarResultados = false;

  String _s(dynamic value) => value?.toString().trim() ?? '';

  bool get _esGerencia => Sesion.rol.trim().toLowerCase() == 'gerencia';
  bool get _esJefatura {
    final rol = Sesion.rol.trim().toLowerCase();
    return rol == 'jefe lima' || rol == 'jefe provincia';
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_controllerChanged);
    _cargarInicial();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_controllerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _controllerChanged() {
    if (!mounted) return;
    if (_seleccionado != null &&
        widget.controller.text.trim() != _codigo(_seleccionado!)) {
      setState(() => _seleccionado = null);
    }
  }

  String _codigo(Map<String, dynamic> c) {
    final ruc = _s(c['ruc']);
    final codigo = _s(c['codigo']);
    return ruc.isNotEmpty ? ruc : codigo;
  }

  String _nombre(Map<String, dynamic> c) {
    final razon = _s(c['razon_social']);
    return razon.isNotEmpty ? razon : _s(c['nombre']);
  }

  Future<List<String>?> _vendedoresPermitidos() async {
    if (_esGerencia) return null;

    if (_esJefatura) {
      final rows = await _db
          .from('usuario_permisos')
          .select('vendedor,ver_produccion')
          .eq('usuario_jefe_id', Sesion.idUsuario)
          .eq('ver_produccion', true);

      final values = <String>{};
      for (final row in rows as List) {
        final vendedor = _s(row['vendedor']);
        if (vendedor.isNotEmpty) values.add(vendedor);
      }
      if (Sesion.vendedor.trim().isNotEmpty) {
        values.add(Sesion.vendedor.trim());
      }
      return values.toList();
    }

    final vendedor = Sesion.vendedor.trim();
    return vendedor.isEmpty ? <String>[] : <String>[vendedor];
  }

  Future<void> _cargarInicial() async {
    final codigo = widget.controller.text.trim();
    if (codigo.isEmpty) return;

    try {
      final data = await _db
          .from('clientes')
          .select('codigo,ruc,razon_social,nombre,vendedor,departamento,sector,giro')
          .or('codigo.eq.$codigo,ruc.eq.$codigo')
          .limit(1);

      if (!mounted || (data as List).isEmpty) return;
      setState(() => _seleccionado = Map<String, dynamic>.from(data.first));
    } catch (_) {
      // Si no se puede resolver el nombre inicial, el código sigue siendo editable.
    }
  }

  void _programarBusqueda(String value) {
    _debounce?.cancel();
    final texto = value.trim();

    if (texto.length < 2) {
      setState(() {
        _resultados = [];
        _mostrarResultados = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _buscar(texto);
    });
  }

  Future<void> _buscar(String texto) async {
    if (!mounted) return;
    setState(() {
      _buscando = true;
      _mostrarResultados = true;
    });

    try {
      final permitidos = await _vendedoresPermitidos();

      var query = _db
          .from('clientes')
          .select('codigo,ruc,razon_social,nombre,vendedor,departamento,sector,giro')
          .eq('activo', true);

      if (permitidos != null) {
        if (permitidos.isEmpty) {
          if (mounted) {
            setState(() {
              _resultados = [];
              _buscando = false;
            });
          }
          return;
        }
        query = query.inFilter('vendedor', permitidos);
      }

      final q = texto.replaceAll('%', '').replaceAll(',', ' ').trim();
      final response = await query
          .or('razon_social.ilike.%$q%,nombre.ilike.%$q%,ruc.ilike.%$q%,codigo.ilike.%$q%')
          .order('razon_social')
          .limit(20);

      if (!mounted) return;
      setState(() {
        _resultados = List<Map<String, dynamic>>.from(response as List);
        _buscando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resultados = [];
        _buscando = false;
      });
    }
  }

  void _seleccionar(Map<String, dynamic> cliente) {
    final codigo = _codigo(cliente);
    widget.controller.text = codigo;
    widget.controller.selection = TextSelection.collapsed(offset: codigo.length);

    setState(() {
      _seleccionado = cliente;
      _mostrarResultados = false;
      _resultados = [];
    });

    widget.onSelected?.call(cliente);
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _seleccionado == null ? '' : _nombre(_seleccionado!);
    final vendedor = _seleccionado == null ? '' : _s(_seleccionado!['vendedor']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          onChanged: _programarBusqueda,
          decoration: InputDecoration(
            labelText: '${widget.label} / RUC',
            hintText: 'Escribe nombre, RUC o código...',
            prefixIcon: const Icon(Icons.business_outlined),
            suffixIcon: _buscando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : widget.controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar cliente',
                        onPressed: () {
                          widget.controller.clear();
                          setState(() {
                            _seleccionado = null;
                            _resultados = [];
                            _mostrarResultados = false;
                          });
                        },
                        icon: const Icon(Icons.clear),
                      ),
            border: const OutlineInputBorder(),
          ),
        ),
        if (nombre.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, size: 18, color: Color(0xFF1468A8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$nombre${vendedor.isEmpty ? '' : ' · $vendedor'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_mostrarResultados && _resultados.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD9E1E8)),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 8,
                  color: Color(0x22000000),
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _resultados.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final c = _resultados[index];
                final nombreCliente = _nombre(c);
                final codigo = _codigo(c);
                final vendedorCliente = _s(c['vendedor']);
                final departamento = _s(c['departamento']);

                return ListTile(
                  dense: true,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEAF5FF),
                    child: Icon(Icons.business_outlined, color: Color(0xFF1468A8)),
                  ),
                  title: Text(
                    nombreCliente.isEmpty ? codigo : nombreCliente,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    [codigo, vendedorCliente, departamento]
                        .where((e) => e.isNotEmpty)
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _seleccionar(c),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
