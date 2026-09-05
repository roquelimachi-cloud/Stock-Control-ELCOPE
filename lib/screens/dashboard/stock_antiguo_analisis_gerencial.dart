import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/supabase/supabase_service.dart';
import '../../services/sesion.dart';
import '../../services/pdf/stock_antiguo_analisis_visual_pdf_service.dart';
import 'stock_antiguo_analisis_preview_page.dart';

class StockAntiguoAnalisisGerencialPage extends StatefulWidget {
  const StockAntiguoAnalisisGerencialPage({super.key});

  @override
  State<StockAntiguoAnalisisGerencialPage> createState() =>
      _StockAntiguoAnalisisGerencialPageState();
}

class _StockAntiguoAnalisisGerencialPageState
    extends State<StockAntiguoAnalisisGerencialPage> {
  static const verde = Color(0xFF08783B);
  static const verdeSuave = Color(0xFFEAF5EE);
  static const azul = Color(0xFF1565D8);
  static const naranja = Color(0xFFF59E0B);
  static const rojo = Color(0xFFEF4444);
  static const amarillo = Color(0xFFF4C430);
  static const grisFondo = Color(0xFFF7F9FA);

  final _busquedaController = TextEditingController();
  final _fechaFormat = DateFormat('dd/MM/yyyy');
  final _numeroFormat = NumberFormat('#,##0.##', 'en_US');
  final _monedaFormat = NumberFormat('#,##0.00', 'en_US');

  List<_StockGerencialItem> _todos = [];
  List<_StockGerencialItem> _filtrados = [];
  List<String> _clientes = [];
  List<String> _asesores = [];
  List<String> _clases = [];
  List<String> _almacenes = [];

  String _cliente = 'Todos';
  String _asesor = 'Todos';
  String _clase = 'Todos';
  String _almacen = 'Todos';
  String _estado = 'Todos';
  int _diasMinimos = 30;
  int _tab = 0;
  bool _cargando = true;
  String? _error;

  bool get _esGerencia => Sesion.rol == 'Gerencia';
  bool get _esJefatura =>
      Sesion.rol == 'Jefe Lima' || Sesion.rol == 'Jefe Provincia';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _obtenerStockPermitido() async {
    final db = SupabaseService.client;
    const tamanoPagina = 1000;
    final datos = <Map<String, dynamic>>[];
    var inicio = 0;

    while (true) {
      final respuesta = await db
          .from('stock')
          .select()
          .range(inicio, inicio + tamanoPagina - 1);

      final pagina = (respuesta as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      datos.addAll(pagina);

      if (pagina.length < tamanoPagina) break;
      inicio += tamanoPagina;
    }

    if (_esGerencia) return datos;

    if (_esJefatura) {
      final respuesta = await db
          .from('usuario_permisos')
          .select('vendedor, ver_produccion')
          .eq('usuario_jefe_id', Sesion.idUsuario)
          .eq('ver_produccion', true);

      final permitidos = (respuesta as List)
          .map((e) => e['vendedor']?.toString().trim().toLowerCase() ?? '')
          .where((e) => e.isNotEmpty)
          .toSet();

      return datos.where((fila) {
        final vendedor = _texto(fila, [
          'vendedor',
          'asesor',
          'representante',
        ]).trim().toLowerCase();
        return permitidos.contains(vendedor);
      }).toList();
    }

    final vendedorSesion = Sesion.vendedor.trim().toLowerCase();
    if (vendedorSesion.isNotEmpty) {
      return datos.where((fila) {
        final vendedor = _texto(fila, [
          'vendedor',
          'asesor',
          'representante',
        ]).trim().toLowerCase();
        return vendedor == vendedorSesion;
      }).toList();
    }

    return [];
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final datos = await _obtenerStockPermitido();
      final hoy = DateTime.now();
      final lista = <_StockGerencialItem>[];

      for (final fila in datos) {
        final fechaIngreso = _fecha(fila['fecha_ingreso']);
        if (fechaIngreso == null) continue;

        final fechaBase = DateTime(
          fechaIngreso.year,
          fechaIngreso.month,
          fechaIngreso.day,
        );
        final hoyBase = DateTime(hoy.year, hoy.month, hoy.day);
        final dias = hoyBase.difference(fechaBase).inDays;
        if (dias < 0 || dias < 30) continue;

        lista.add(
          _StockGerencialItem(
            codigo: _texto(fila, ['codigo_articulo', 'codigoArticulo']),
            descripcion: _texto(
              fila,
              ['descripcion', 'articulo'],
              fallback: 'SIN DESCRIPCIÓN',
            ),
            cliente: _texto(fila, ['cliente'], fallback: 'SIN CLIENTE'),
            asesor: _texto(
              fila,
              ['vendedor', 'asesor', 'representante'],
              fallback: 'SIN ASESOR',
            ),
            clase: _texto(
              fila,
              [
                'clase',
                'clase_producto',
                'claseProducto',
                'familia',
                'tipo_producto',
                'categoria',
              ],
              fallback: 'SIN CLASE',
            ),
            almacen: _texto(
              fila,
              [
                'almacen',
                'almacén',
                'almacen_nombre',
                'almacenNombre',
                'ubicacion',
              ],
              fallback: 'SIN ALMACÉN',
            ),
            fechaIngreso: fechaIngreso,
            dias: dias,
            stock: _double(fila['stock']),
            precio: _double(
              fila['lista_precio_dolar'] ??
                  fila['precio_lista_dolar'] ??
                  fila['ultimo_precio_facturado_dolar'] ??
                  fila['precio'],
            ),
            valorTotal: _double(fila['valor_lista_precio_dolar']),
            peso: _double(fila['peso']),
          ),
        );
      }

      lista.sort((a, b) => b.valorTotal.compareTo(a.valorTotal));

      String ordenar(String valor) => valor.trim();
      final clientes = lista.map((e) => ordenar(e.cliente)).toSet().toList()
        ..sort();
      final asesores = lista.map((e) => ordenar(e.asesor)).toSet().toList()
        ..sort();
      final clases = lista.map((e) => ordenar(e.clase)).toSet().toList()
        ..sort();
      final almacenes = lista.map((e) => ordenar(e.almacen)).toSet().toList()
        ..sort();

      if (!mounted) return;
      setState(() {
        _todos = lista;
        _filtrados = lista;
        _clientes = clientes;
        _asesores = asesores;
        _clases = clases;
        _almacenes = almacenes;
        _cargando = false;
      });
      _aplicarFiltros();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString();
      });
    }
  }

  String _texto(
    Map<String, dynamic> fila,
    List<String> campos, {
    String fallback = '',
  }) {
    for (final campo in campos) {
      final valor = fila[campo]?.toString().trim() ?? '';
      if (valor.isNotEmpty) return valor;
    }
    return fallback;
  }

  double _double(dynamic valor) {
    if (valor == null) return 0;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString().replaceAll(',', '').trim()) ?? 0;
  }

  DateTime? _fecha(dynamic valor) {
    if (valor == null) return null;
    if (valor is DateTime) return valor;
    final texto = valor.toString().trim();
    if (texto.isEmpty) return null;
    final iso = DateTime.tryParse(texto);
    if (iso != null) return iso;
    for (final formato in ['dd/MM/yyyy', 'dd-MM-yyyy']) {
      try {
        return DateFormat(formato).parseStrict(texto);
      } catch (_) {}
    }
    return null;
  }

  void _aplicarFiltros() {
    final texto = _busquedaController.text.trim().toLowerCase();
    final resultado = _todos.where((item) {
      final coincideTexto = texto.isEmpty ||
          item.descripcion.toLowerCase().contains(texto) ||
          item.codigo.toLowerCase().contains(texto) ||
          item.cliente.toLowerCase().contains(texto) ||
          item.asesor.toLowerCase().contains(texto);
      return coincideTexto &&
          (_cliente == 'Todos' || item.cliente == _cliente) &&
          (_asesor == 'Todos' || item.asesor == _asesor) &&
          (_clase == 'Todos' || item.clase == _clase) &&
          (_almacen == 'Todos' || item.almacen == _almacen) &&
          item.dias >= _diasMinimos &&
          (_estado == 'Todos' || item.estado == _estado);
    }).toList();

    resultado.sort((a, b) => b.valorTotal.compareTo(a.valorTotal));
    if (!mounted) return;
    setState(() => _filtrados = resultado);
  }

  void _limpiar() {
    _busquedaController.clear();
    setState(() {
      _cliente = 'Todos';
      _asesor = 'Todos';
      _clase = 'Todos';
      _almacen = 'Todos';
      _estado = 'Todos';
      _diasMinimos = 30;
    });
    _aplicarFiltros();
  }

  String _estadoItem(int dias) {
    if (dias > 90) return 'Crítico';
    if (dias >= 61) return 'Antiguo';
    if (dias >= 31) return 'Atención';
    return 'Normal';
  }

  Color _colorDias(int dias) {
    if (dias > 90) return rojo;
    if (dias >= 61) return Colors.deepOrange;
    if (dias >= 31) return amarillo;
    return verde;
  }

  double get _valorTotal =>
      _filtrados.fold(0, (sum, e) => sum + e.valorTotal);
  double get _pesoTotal => _filtrados.fold(0, (sum, e) => sum + e.peso);
  double get _promedioDias => _filtrados.isEmpty
      ? 0
      : _filtrados.fold<int>(0, (sum, e) => sum + e.dias) /
          _filtrados.length;

  Map<String, _ResumenGrupo> _agrupar(
    String Function(_StockGerencialItem) clave,
  ) {
    final mapa = <String, _ResumenGrupo>{};
    for (final item in _filtrados) {
      final nombre = clave(item).trim().isEmpty ? 'SIN DATO' : clave(item);
      mapa.putIfAbsent(nombre, () => _ResumenGrupo());
      mapa[nombre]!.articulos++;
      mapa[nombre]!.valor += item.valorTotal;
      mapa[nombre]!.peso += item.peso;
      mapa[nombre]!.dias += item.dias;
    }
    return mapa;
  }

  Future<void> _imprimir() async {
    if (_filtrados.isEmpty) return;

    final vista = switch (_tab) {
      1 => 'POR ASESOR (VENDEDOR)',
      2 => 'POR CLIENTE',
      3 => 'POR CLASE DE PRODUCTO',
      4 => 'POR ALMACÉN',
      5 => 'EVOLUCIÓN',
      _ => 'RESUMEN GENERAL',
    };

    final titulo = switch (_tab) {
      1 => 'STOCK ANTIGUO POR ASESOR',
      2 => 'STOCK ANTIGUO POR CLIENTE',
      3 => 'STOCK ANTIGUO POR CLASE DE PRODUCTO',
      4 => 'STOCK ANTIGUO POR ALMACÉN',
      5 => 'EVOLUCIÓN DEL STOCK ANTIGUO',
      _ => 'STOCK ANTIGUO - ANÁLISIS GERENCIAL',
    };

    await StockAntiguoAnalisisVisualPdfService.imprimir(
      context: context,
      titulo: titulo,
      vista: vista,
      filtroBusqueda: _busquedaController.text.trim(),
      cliente: _cliente,
      asesor: _asesor,
      clase: _clase,
      almacen: _almacen,
      diasMinimos: _diasMinimos,
      estado: _estado,
      items: _filtrados
          .map(
            (e) => StockAntiguoAnalisisVisualPdfItem(
              codigo: e.codigo,
              descripcion: e.descripcion,
              cliente: e.cliente,
              asesor: e.asesor,
              clase: e.clase,
              almacen: e.almacen,
              fechaIngreso: e.fechaIngreso,
              dias: e.dias,
              stock: e.stock,
              precio: e.precio,
              valorTotal: e.valorTotal,
              peso: e.peso,
            ),
          )
          .toList(),
    );
  }

  void _abrirDetalle({
    required String tipo,
    required String valor,
    required IconData icono,
  }) {
    final detalle = _filtrados.where((item) {
      switch (tipo) {
        case 'asesor':
          return item.asesor == valor;
        case 'cliente':
          return item.cliente == valor;
        case 'clase':
          return item.clase == valor;
        case 'almacen':
          return item.almacen == valor;
        default:
          return false;
      }
    }).toList()
      ..sort((a, b) => b.valorTotal.compareTo(a.valorTotal));

    if (detalle.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockAntiguoDetalleGerencialPage(
          tipo: tipo,
          valorFiltro: valor,
          icono: icono,
          items: detalle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_esGerencia && !_esJefatura) {
      return Scaffold(
        backgroundColor: grisFondo,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('ANÁLISIS NO DISPONIBLE', style: TextStyle(color: verde, fontWeight: FontWeight.w800)),
        ),
        body: const Center(
          child: Text(
            'Este análisis está disponible únicamente para Gerencia y Jefaturas.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: grisFondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF263238),
        elevation: 0,
        titleSpacing: 18,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: verdeSuave,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.analytics_outlined, color: verde),
            ),
            const SizedBox(width: 12),
            const Text(
              'STOCK ANTIGUO - ANÁLISIS',
              style: TextStyle(
                color: verde,
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: ElevatedButton.icon(
              onPressed: _filtrados.isEmpty ? null : _imprimir,
              icon: const Icon(Icons.print, size: 18),
              label: const Text('IMPRIMIR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: verde,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: verde))
          : _error != null
              ? _errorView()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final movil = constraints.maxWidth < 900;
                    return RefreshIndicator(
                      onRefresh: _cargar,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.all(movil ? 12 : 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _cabecera(movil),
                            const SizedBox(height: 10),
                            _tabs(movil),
                            const SizedBox(height: 10),
                            _kpis(movil),
                            const SizedBox(height: 10),
                            _filtros(movil),
                            const SizedBox(height: 10),
                            _analisis(movil),
                            const SizedBox(height: 10),
                            _tabla(movil),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _cabecera(bool movil) {
    return Container(
      padding: EdgeInsets.all(movil ? 14 : 16),
      decoration: _decoracion(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: verdeSuave,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.calendar_month_outlined,
                color: verde, size: 27),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STOCK ANTIGUO - ANÁLISIS GERENCIAL',
                  style: TextStyle(
                    color: verde,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Análisis del stock con mayor tiempo de permanencia por asesor, cliente, clase y almacén.',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          if (!movil)
            Text(
              _fechaFormat.format(DateTime.now()),
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabs(bool movil) {
    final tabs = [
      ('Resumen General', Icons.dashboard_outlined),
      ('Por Asesor', Icons.person_outline),
      ('Por Cliente', Icons.groups_outlined),
      ('Por Clase', Icons.category_outlined),
      ('Por Almacén', Icons.warehouse_outlined),
      ('Evolución', Icons.show_chart),
    ];

    return SizedBox(
      height: movil ? 46 : 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, index) {
          final activo = _tab == index;
          return InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: () => setState(() => _tab = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: activo ? verde : const Color(0xFFEFF2F5),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  Icon(
                    tabs[index].$2,
                    size: 17,
                    color: activo ? Colors.white : const Color(0xFF455A64),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    tabs[index].$1,
                    style: TextStyle(
                      color: activo ? Colors.white : const Color(0xFF37474F),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _kpis(bool movil) {
    final cards = [
      _KpiData('ARTÍCULOS', _numeroFormat.format(_filtrados.length),
          'con más de 30 días', Icons.inventory_2_outlined, verde),
      _KpiData('VALOR TOTAL', 'US\$ ${_monedaFormat.format(_valorTotal)}',
          'en stock antiguo', Icons.attach_money, azul),
      _KpiData('PESO COBRE', '${_monedaFormat.format(_pesoTotal)} t',
          'en stock antiguo', Icons.scale_outlined, naranja),
      _KpiData('DÍAS PROMEDIO', '${_promedioDias.round()} días',
          'de permanencia', Icons.access_time, azul),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: movil ? 2 : 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: movil ? 1.75 : 3.0,
      ),
      itemBuilder: (_, index) {
        final item = cards[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: _decoracion(),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.titulo,
                        style: const TextStyle(
                            fontSize: 9,
                            color: Colors.grey,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(item.valor,
                          style: TextStyle(
                              color: item.color,
                              fontSize: 17,
                              fontWeight: FontWeight.w800)),
                    ),
                    Text(item.subtitulo,
                        style: const TextStyle(color: Colors.grey, fontSize: 8)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filtros(bool movil) {
    final campos = [
      Expanded(flex: 3, child: _campoBusqueda()),
      Expanded(flex: 2, child: _clienteFiltro()),
      Expanded(flex: 2, child: _asesorFiltro()),
      Expanded(flex: 2, child: _claseFiltro()),
      Expanded(flex: 2, child: _almacenFiltro()),
      Expanded(flex: 1, child: _diasFiltro()),
      Expanded(flex: 1, child: _estadoFiltro()),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _decoracion(),
      child: movil
          ? Column(
              children: [
                _campoBusqueda(),
                const SizedBox(height: 9),
                Row(children: [
                  Expanded(child: _clienteFiltro()),
                  const SizedBox(width: 8),
                  Expanded(child: _asesorFiltro()),
                ]),
                const SizedBox(height: 9),
                Row(children: [
                  Expanded(child: _claseFiltro()),
                  const SizedBox(width: 8),
                  Expanded(child: _almacenFiltro()),
                ]),
                const SizedBox(height: 9),
                Row(children: [
                  Expanded(child: _diasFiltro()),
                  const SizedBox(width: 8),
                  Expanded(child: _estadoFiltro()),
                ]),
                const SizedBox(height: 9),
                Row(children: [
                  Expanded(child: _botonBuscar()),
                  const SizedBox(width: 8),
                  Expanded(child: _botonLimpiar()),
                ]),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ..._conSeparadores(campos),
                const SizedBox(width: 8),
                _botonBuscar(),
                const SizedBox(width: 7),
                _botonLimpiar(),
              ],
            ),
    );
  }

  List<Widget> _conSeparadores(List<Widget> widgets) {
    final resultado = <Widget>[];
    for (var i = 0; i < widgets.length; i++) {
      if (i > 0) resultado.add(const SizedBox(width: 8));
      resultado.add(widgets[i]);
    }
    return resultado;
  }

  Widget _campoBase({required String titulo, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Color(0xFF455A64))),
        const SizedBox(height: 4),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE0E6E9)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _campoBusqueda() => _campoBase(
        titulo: 'Buscar artículo, cliente o asesor',
        child: TextField(
          controller: _busquedaController,
          onChanged: (_) => _aplicarFiltros(),
          decoration: const InputDecoration(
            hintText: 'Buscar...',
            prefixIcon: Icon(Icons.search, size: 18),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 10),
          ),
        ),
      );

  Widget _clienteFiltro() => _dropdown('Cliente', _cliente, _clientes,
      (v) => setState(() => _cliente = v));
  Widget _asesorFiltro() => _dropdown('Asesor (Vendedor)', _asesor, _asesores,
      (v) => setState(() => _asesor = v));
  Widget _claseFiltro() => _dropdown('Clase de Producto', _clase, _clases,
      (v) => setState(() => _clase = v));
  Widget _almacenFiltro() => _dropdown('Almacén', _almacen, _almacenes,
      (v) => setState(() => _almacen = v));

  Widget _dropdown(
    String titulo,
    String valor,
    List<String> opciones,
    ValueChanged<String> onChanged,
  ) {
    return _campoBase(
      titulo: titulo,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: opciones.contains(valor) ? valor : 'Todos',
          isExpanded: true,
          items: [
            const DropdownMenuItem(value: 'Todos', child: Text('Todos')),
            ...opciones.where((e) => e != 'Todos').map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, overflow: TextOverflow.ellipsis),
                  ),
                ),
          ],
          onChanged: (v) {
            if (v != null) {
              onChanged(v);
              _aplicarFiltros();
            }
          },
        ),
      ),
    );
  }

  Widget _diasFiltro() => _campoBase(
        titulo: 'Días mínimos',
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _diasMinimos,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 30, child: Text('30')),
              DropdownMenuItem(value: 60, child: Text('60')),
              DropdownMenuItem(value: 90, child: Text('90')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _diasMinimos = v);
              _aplicarFiltros();
            },
          ),
        ),
      );

  Widget _estadoFiltro() => _campoBase(
        titulo: 'Estado',
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _estado,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'Todos', child: Text('Todos')),
              DropdownMenuItem(value: 'Crítico', child: Text('Crítico')),
              DropdownMenuItem(value: 'Antiguo', child: Text('Antiguo')),
              DropdownMenuItem(value: 'Atención', child: Text('Atención')),
              DropdownMenuItem(value: 'Normal', child: Text('Normal')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _estado = v);
              _aplicarFiltros();
            },
          ),
        ),
      );

  Widget _botonBuscar() => ElevatedButton.icon(
        onPressed: _aplicarFiltros,
        icon: const Icon(Icons.search, size: 16),
        label: const Text('BUSCAR'),
        style: ElevatedButton.styleFrom(
          backgroundColor: verde,
          foregroundColor: Colors.white,
          minimumSize: const Size(98, 42),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      );

  Widget _botonLimpiar() => OutlinedButton.icon(
        onPressed: _limpiar,
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('LIMPIAR'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey.shade700,
          minimumSize: const Size(98, 42),
          side: BorderSide.none,
          backgroundColor: Colors.grey.shade100,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      );

  Widget _analisis(bool movil) {
    if (_tab == 1) {
      return _panelUnico('STOCK ANTIGUO POR ASESOR', Icons.person_outline,
          _agrupar((e) => e.asesor), tipo: 'asesor');
    }
    if (_tab == 2) {
      return _panelUnico('STOCK ANTIGUO POR CLIENTE', Icons.groups_outlined,
          _agrupar((e) => e.cliente), tipo: 'cliente');
    }
    if (_tab == 3) {
      return _panelUnico('STOCK ANTIGUO POR CLASE', Icons.category_outlined,
          _agrupar((e) => e.clase), tipo: 'clase');
    }
    if (_tab == 4) {
      return _panelUnico('STOCK ANTIGUO POR ALMACÉN', Icons.warehouse_outlined,
          _agrupar((e) => e.almacen), tipo: 'almacen');
    }
    if (_tab == 5) return _evolucion();

    final asesor = _agrupar((e) => e.asesor);
    final clase = _agrupar((e) => e.clase);
    return movil
        ? Column(
            children: [
              _panelUnico('STOCK ANTIGUO POR ASESOR', Icons.person_outline,
                  asesor, tipo: 'asesor'),
              const SizedBox(height: 10),
              _panelUnico('STOCK ANTIGUO POR CLASE', Icons.category_outlined,
                  clase, tipo: 'clase'),
              const SizedBox(height: 10),
              _rangosPanel(),
              const SizedBox(height: 10),
              _topClientesPanel(),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _panelUnico('STOCK ANTIGUO POR ASESOR', Icons.person_outline, asesor, tipo: 'asesor')),
              const SizedBox(width: 10),
              Expanded(child: _panelUnico('STOCK ANTIGUO POR CLASE', Icons.category_outlined, clase, tipo: 'clase')),
              const SizedBox(width: 10),
              Expanded(child: _rangosPanel()),
              const SizedBox(width: 10),
              Expanded(child: _topClientesPanel()),
            ],
          );
  }

  Widget _panelUnico(String titulo, IconData icono, Map<String, _ResumenGrupo> mapa, {String? tipo}) {
    final entries = mapa.entries.toList()
      ..sort((a, b) => b.value.valor.compareTo(a.value.valor));
    final visibles = entries.take(7).toList();
    final maximo = visibles.isEmpty ? 0.0 : visibles.first.value.valor;

    return _panel(
      titulo,
      icono,
      Column(
        children: [
          if (visibles.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Sin información', style: TextStyle(color: Colors.grey)),
            )
          else
            ...visibles.map((entry) {
              final proporcion = maximo == 0 ? 0.0 : entry.value.valor / maximo;
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: InkWell(
                  borderRadius: BorderRadius.circular(7),
                  onTap: tipo == null
                      ? null
                      : () => _abrirDetalle(
                            tipo: tipo,
                            valor: entry.key,
                            icono: icono,
                          ),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Column(
                      children: [
                        Row(
                          children: [
                        Expanded(
                          child: Text(entry.key,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 9, fontWeight: FontWeight.w700)),
                        ),
                        Text('US\$ ${_monedaFormat.format(entry.value.valor)}',
                            style: const TextStyle(
                                color: verde,
                                fontSize: 8,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: proporcion.clamp(0, 1),
                        backgroundColor: const Color(0xFFE7ECEF),
                        valueColor: const AlwaysStoppedAnimation<Color>(azul),
                      ),
                    ),
                    const SizedBox(height: 2),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${entry.value.articulos} artículos · ${_monedaFormat.format(entry.value.peso)} t cobre',
                                  style: const TextStyle(color: Colors.grey, fontSize: 7),
                                ),
                              ),
                              if (tipo != null)
                                const Icon(Icons.open_in_new, size: 11, color: azul),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _rangosPanel() {
    final rangos = <String, int>{
      '> 90 días': _filtrados.where((e) => e.dias > 90).length,
      '61 - 90 días': _filtrados.where((e) => e.dias >= 61 && e.dias <= 90).length,
      '31 - 60 días': _filtrados.where((e) => e.dias >= 31 && e.dias <= 60).length,
      '30 días': _filtrados.where((e) => e.dias == 30).length,
    };
    final maximo = rangos.values.fold<int>(0, (a, b) => a > b ? a : b);
    final colores = [rojo, Colors.deepOrange, amarillo, verde];

    return _panel(
      'DISTRIBUCIÓN POR RANGO DE DÍAS',
      Icons.calendar_month_outlined,
      SizedBox(
        height: 168,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(rangos.length, (index) {
            final entry = rangos.entries.elementAt(index);
            final alto = maximo == 0 ? 2.0 : 105 * entry.value / maximo;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${entry.value}',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Container(
                      height: alto.clamp(2, 105),
                      decoration: BoxDecoration(
                        color: colores[index],
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(entry.key,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, fontSize: 7)),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _topClientesPanel() {
    final mapa = _agrupar((e) => e.cliente);
    final entries = mapa.entries.toList()
      ..sort((a, b) => b.value.valor.compareTo(a.value.valor));
    final top = entries.take(5).toList();
    final maximo = top.isEmpty ? 0.0 : top.first.value.valor;

    return _panel(
      'TOP 5 CLIENTES CON STOCK ANTIGUO',
      Icons.people_alt_outlined,
      Column(
        children: top.isEmpty
            ? [
                const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Sin información', style: TextStyle(color: Colors.grey)))
              ]
            : List.generate(top.length, (index) {
                final item = top[index];
                final proporcion = maximo == 0 ? 0.0 : item.value.valor / maximo;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(7),
                    onTap: () => _abrirDetalle(
                      tipo: 'cliente',
                      valor: item.key,
                      icono: Icons.people_alt_outlined,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Row(
                        children: [
                          Container(
                            width: 21,
                            height: 21,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: index == 0 ? verde : azul.withOpacity(.12),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: index == 0 ? Colors.white : azul,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.key,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'US\$ ${_monedaFormat.format(item.value.valor)}',
                                      style: const TextStyle(
                                        color: verde,
                                        fontSize: 7,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    minHeight: 5,
                                    value: proporcion.clamp(0, 1),
                                    backgroundColor: const Color(0xFFE8EDF0),
                                    valueColor: const AlwaysStoppedAnimation<Color>(azul),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
      ),
    );
  }

  Widget _evolucion() {
    final rangos = <String, int>{
      '30': _filtrados.where((e) => e.dias == 30).length,
      '31-60': _filtrados.where((e) => e.dias >= 31 && e.dias <= 60).length,
      '61-90': _filtrados.where((e) => e.dias >= 61 && e.dias <= 90).length,
      '>90': _filtrados.where((e) => e.dias > 90).length,
    };
    return _panel(
      'ANTIGÜEDAD DEL STOCK',
      Icons.show_chart,
      Column(
        children: rangos.entries.map((e) {
          final maximo = rangos.values.fold<int>(0, (a, b) => a > b ? a : b);
          final p = maximo == 0 ? 0.0 : e.value / maximo;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(width: 55, child: Text(e.key, style: const TextStyle(fontSize: 9))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      minHeight: 14,
                      value: p,
                      backgroundColor: const Color(0xFFE8EDF0),
                      valueColor: const AlwaysStoppedAnimation<Color>(azul),
                    ),
                  ),
                ),
                SizedBox(
                    width: 45,
                    child: Text('${e.value}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 9))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _panel(String titulo, IconData icono, Widget child) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _decoracion(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: verde, size: 17),
              const SizedBox(width: 7),
              Expanded(
                child: Text(titulo,
                    style: const TextStyle(
                        color: verde,
                        fontWeight: FontWeight.w800,
                        fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _tabla(bool movil) {
    return Container(
      decoration: _decoracion(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 9),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: verde, size: 18),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text('DETALLE DEL STOCK ANTIGUO',
                      style: TextStyle(
                          color: verde,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ),
                Text('Total: ${_filtrados.length} artículos',
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_filtrados.isEmpty)
            const Padding(
              padding: EdgeInsets.all(35),
              child: Text('No se encontraron artículos con los filtros seleccionados.',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            movil ? _tablaMovil() : _tablaDesktop(),
        ],
      ),
    );
  }

  Widget _tablaDesktop() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 31,
          dataRowMinHeight: 32,
          dataRowMaxHeight: 42,
          columnSpacing: 12,
          horizontalMargin: 10,
          headingRowColor: WidgetStateProperty.all(verde),
          headingTextStyle: const TextStyle(
              color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
          columns: const [
            DataColumn(label: Text('N°')),
            DataColumn(label: Text('Código')),
            DataColumn(label: Text('Descripción (Artículo)')),
            DataColumn(label: Text('Cliente')),
            DataColumn(label: Text('Asesor')),
            DataColumn(label: Text('Clase')),
            DataColumn(label: Text('Almacén')),
            DataColumn(label: Text('Ingreso')),
            DataColumn(label: Text('Días')),
            DataColumn(label: Text('Stock')),
            DataColumn(label: Text('Precio US\$')),
            DataColumn(label: Text('Valor Total')),
            DataColumn(label: Text('Peso Cobre')),
          ],
          rows: List.generate(_filtrados.length, (index) {
            final item = _filtrados[index];
            return DataRow(cells: [
              DataCell(Text('${index + 1}', style: _textoTabla())),
              DataCell(Text(item.codigo, style: _textoTabla())),
              DataCell(SizedBox(
                  width: 360,
                  child: Text(item.descripcion,
                      softWrap: false, style: _textoTabla()))),
              DataCell(SizedBox(
                  width: 155,
                  child: Text(item.cliente,
                      overflow: TextOverflow.ellipsis, style: _textoTabla()))),
              DataCell(SizedBox(
                  width: 125,
                  child: Text(item.asesor,
                      overflow: TextOverflow.ellipsis, style: _textoTabla()))),
              DataCell(Text(item.clase, style: _textoTabla())),
              DataCell(Text(item.almacen, style: _textoTabla())),
              DataCell(Text(_fechaFormat.format(item.fechaIngreso), style: _textoTabla())),
              DataCell(_badgeDias(item.dias)),
              DataCell(Text(_numeroFormat.format(item.stock), style: _textoTabla())),
              DataCell(Text(_monedaFormat.format(item.precio), style: _textoTabla())),
              DataCell(Text('US\$ ${_monedaFormat.format(item.valorTotal)}',
                  style: _textoTabla(fontWeight: FontWeight.w700))),
              DataCell(Text('${_monedaFormat.format(item.peso)} t', style: _textoTabla())),
            ]);
          }),
        ),
      ),
    );
  }

  TextStyle _textoTabla({FontWeight fontWeight = FontWeight.w500}) => TextStyle(
        fontSize: 9,
        color: const Color(0xFF263238),
        fontWeight: fontWeight,
      );

  Widget _badgeDias(int dias) {
    final color = _colorDias(dias);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$dias',
          style: const TextStyle(
              color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }

  Widget _tablaMovil() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      itemCount: _filtrados.length,
      separatorBuilder: (_, __) => const SizedBox(height: 7),
      itemBuilder: (_, index) {
        final item = _filtrados[index];
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE1E7E9)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('${index + 1}.', style: const TextStyle(color: verde, fontWeight: FontWeight.w800)),
                const SizedBox(width: 6),
                Expanded(child: Text(item.codigo, style: const TextStyle(fontSize: 9, color: Colors.grey))),
                _badgeDias(item.dias),
              ]),
              const SizedBox(height: 6),
              Text(item.descripcion,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
              const SizedBox(height: 5),
              Text(item.cliente, style: const TextStyle(fontSize: 9)),
              const SizedBox(height: 2),
              Text('Asesor: ${item.asesor} · Clase: ${item.clase}',
                  style: const TextStyle(fontSize: 8, color: Colors.grey)),
              Text('Almacén: ${item.almacen} · Ingreso: ${_fechaFormat.format(item.fechaIngreso)}',
                  style: const TextStyle(fontSize: 8, color: Colors.grey)),
              const Divider(height: 14),
              Row(
                children: [
                  Expanded(child: _miniDato('Stock', _numeroFormat.format(item.stock))),
                  Expanded(child: _miniDato('Valor', 'US\$ ${_monedaFormat.format(item.valorTotal)}')),
                  Expanded(child: _miniDato('Cobre', '${_monedaFormat.format(item.peso)} t')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniDato(String titulo, String valor) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 7, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(valor, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
        ],
      );

  BoxDecoration _decoracion() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E6E9)),
      );

  Widget _errorView() => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(20),
          decoration: _decoracion(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: rojo, size: 42),
              const SizedBox(height: 10),
              const Text('No se pudo cargar el análisis.',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              Text(_error ?? '', textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('REINTENTAR'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: verde, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
}


class StockAntiguoDetalleGerencialPage extends StatelessWidget {
  final String tipo;
  final String valorFiltro;
  final IconData icono;
  final List<_StockGerencialItem> items;

  const StockAntiguoDetalleGerencialPage({
    super.key,
    required this.tipo,
    required this.valorFiltro,
    required this.icono,
    required this.items,
  });

  static const verde = Color(0xFF08783B);
  static const verdeSuave = Color(0xFFEAF5EE);
  static const azul = Color(0xFF1565D8);
  static const naranja = Color(0xFFF59E0B);
  static const rojo = Color(0xFFEF4444);
  static const grisFondo = Color(0xFFF7F9FA);

  String get _nombreTipo {
    switch (tipo) {
      case 'asesor':
        return 'ASESOR';
      case 'cliente':
        return 'CLIENTE';
      case 'clase':
        return 'CLASE';
      case 'almacen':
        return 'ALMACÉN';
      default:
        return 'FILTRO';
    }
  }

  double get _valor => items.fold(0, (s, e) => s + e.valorTotal);
  double get _peso => items.fold(0, (s, e) => s + e.peso);
  double get _promedio => items.isEmpty
      ? 0
      : items.fold<int>(0, (s, e) => s + e.dias) / items.length;

  Color _colorDias(int dias) {
    if (dias > 90) return rojo;
    if (dias >= 61) return Colors.deepOrange;
    if (dias >= 31) return const Color(0xFFF4C430);
    return verde;
  }

  void _imprimir(BuildContext context) {
    if (items.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockAntiguoAnalisisPreviewPage(
          titulo: 'DETALLE POR $_nombreTipo: $valorFiltro',
          items: items
              .map(
                (e) => StockAntiguoAnalisisPreviewItem(
                  codigo: e.codigo,
                  descripcion: e.descripcion,
                  cliente: e.cliente,
                  asesor: e.asesor,
                  clase: e.clase,
                  almacen: e.almacen,
                  fechaIngreso: e.fechaIngreso,
                  dias: e.dias,
                  stock: e.stock,
                  precio: e.precio,
                  valorTotal: e.valorTotal,
                  peso: e.peso,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: grisFondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF263238),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: verdeSuave,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icono, color: verde, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'DETALLE POR $_nombreTipo',
                style: const TextStyle(
                  color: verde,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: items.isEmpty ? null : () => _imprimir(context),
              icon: const Icon(Icons.print, size: 17),
              label: const Text('IMPRIMIR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: verde,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final movil = constraints.maxWidth < 900;
          final moneda = NumberFormat('#,##0.00', 'en_US');
          final numero = NumberFormat('#,##0.##', 'en_US');
          final fecha = DateFormat('dd/MM/yyyy');

          return SingleChildScrollView(
            padding: EdgeInsets.all(movil ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE0E6E9)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: verdeSuave,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icono, color: verde, size: 25),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              valorFiltro,
                              style: const TextStyle(
                                color: verde,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Detalle de stock antiguo por $_nombreTipo · 30 días o más de permanencia',
                              style: const TextStyle(color: Colors.grey, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: movil ? 2 : 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: movil ? 1.8 : 3.2,
                  children: [
                    _kpi('ARTÍCULOS', '${items.length}', verde, Icons.inventory_2_outlined),
                    _kpi('VALOR TOTAL', 'US\$ ${moneda.format(_valor)}', azul, Icons.attach_money),
                    _kpi('PESO COBRE', '${moneda.format(_peso)} t', naranja, Icons.scale_outlined),
                    _kpi('DÍAS PROMEDIO', '${_promedio.round()} días', azul, Icons.access_time),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE0E6E9)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 11, 12, 9),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, color: verde, size: 18),
                            const SizedBox(width: 7),
                            const Expanded(
                              child: Text(
                                'DETALLE DEL STOCK',
                                style: TextStyle(color: verde, fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                            ),
                            Text(
                              '${items.length} artículos',
                              style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      if (movil)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: List.generate(items.length, (index) {
                              final e = items[index];
                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 7),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFE1E7E9)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text('${index + 1}.', style: const TextStyle(color: verde, fontWeight: FontWeight.w800)),
                                        const SizedBox(width: 6),
                                        Expanded(child: Text(e.codigo, style: const TextStyle(fontSize: 9, color: Colors.grey))),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                          decoration: BoxDecoration(color: _colorDias(e.dias), borderRadius: BorderRadius.circular(5)),
                                          child: Text('${e.dias} días', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(e.descripcion, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                                    const SizedBox(height: 5),
                                    Text('Cliente: ${e.cliente}', style: const TextStyle(fontSize: 9)),
                                    Text('Asesor: ${e.asesor} · Clase: ${e.clase}', style: const TextStyle(fontSize: 8, color: Colors.grey)),
                                    Text('Almacén: ${e.almacen} · Ingreso: ${fecha.format(e.fechaIngreso)}', style: const TextStyle(fontSize: 8, color: Colors.grey)),
                                    const Divider(height: 14),
                                    Row(
                                      children: [
                                        Expanded(child: _dato('Stock', numero.format(e.stock))),
                                        Expanded(child: _dato('Valor', 'US\$ ${moneda.format(e.valorTotal)}')),
                                        Expanded(child: _dato('Cobre', '${moneda.format(e.peso)} t')),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 31,
                            dataRowMinHeight: 32,
                            dataRowMaxHeight: 48,
                            columnSpacing: 12,
                            horizontalMargin: 10,
                            headingRowColor: WidgetStateProperty.all(verde),
                            headingTextStyle: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                            columns: const [
                              DataColumn(label: Text('N°')),
                              DataColumn(label: Text('Código')),
                              DataColumn(label: Text('Descripción (Artículo)')),
                              DataColumn(label: Text('Cliente')),
                              DataColumn(label: Text('Asesor')),
                              DataColumn(label: Text('Clase')),
                              DataColumn(label: Text('Almacén')),
                              DataColumn(label: Text('Ingreso')),
                              DataColumn(label: Text('Días')),
                              DataColumn(label: Text('Stock')),
                              DataColumn(label: Text('Precio US\$')),
                              DataColumn(label: Text('Valor Total')),
                              DataColumn(label: Text('Peso Cobre')),
                            ],
                            rows: List.generate(items.length, (index) {
                              final e = items[index];
                              return DataRow(cells: [
                                DataCell(Text('${index + 1}', style: const TextStyle(fontSize: 9))),
                                DataCell(Text(e.codigo, style: const TextStyle(fontSize: 9))),
                                DataCell(SizedBox(width: 360, child: Text(e.descripcion, softWrap: false, style: const TextStyle(fontSize: 9)))),
                                DataCell(SizedBox(width: 155, child: Text(e.cliente, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9)))),
                                DataCell(SizedBox(width: 125, child: Text(e.asesor, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9)))),
                                DataCell(Text(e.clase, style: const TextStyle(fontSize: 9))),
                                DataCell(Text(e.almacen, style: const TextStyle(fontSize: 9))),
                                DataCell(Text(fecha.format(e.fechaIngreso), style: const TextStyle(fontSize: 9))),
                                DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5), decoration: BoxDecoration(color: _colorDias(e.dias), borderRadius: BorderRadius.circular(5)), child: Text('${e.dias}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)))),
                                DataCell(Text(numero.format(e.stock), style: const TextStyle(fontSize: 9))),
                                DataCell(Text(moneda.format(e.precio), style: const TextStyle(fontSize: 9))),
                                DataCell(Text('US\$ ${moneda.format(e.valorTotal)}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700))),
                                DataCell(Text('${moneda.format(e.peso)} t', style: const TextStyle(fontSize: 9))),
                              ]);
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _kpi(String titulo, String valor, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E6E9)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(.10), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(valor, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dato(String titulo, String valor) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 7, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(valor, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
        ],
      );
}

class _StockGerencialItem {
  final String codigo;
  final String descripcion;
  final String cliente;
  final String asesor;
  final String clase;
  final String almacen;
  final DateTime fechaIngreso;
  final int dias;
  final double stock;
  final double precio;
  final double valorTotal;
  final double peso;

  const _StockGerencialItem({
    required this.codigo,
    required this.descripcion,
    required this.cliente,
    required this.asesor,
    required this.clase,
    required this.almacen,
    required this.fechaIngreso,
    required this.dias,
    required this.stock,
    required this.precio,
    required this.valorTotal,
    required this.peso,
  });

  String get estado {
    if (dias > 90) return 'Crítico';
    if (dias >= 61) return 'Antiguo';
    if (dias >= 31) return 'Atención';
    return 'Normal';
  }
}

class _ResumenGrupo {
  int articulos = 0;
  double valor = 0;
  double peso = 0;
  int dias = 0;
}

class _KpiData {
  final String titulo;
  final String valor;
  final String subtitulo;
  final IconData icon;
  final Color color;

  const _KpiData(this.titulo, this.valor, this.subtitulo, this.icon, this.color);
}
