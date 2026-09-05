import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/supabase/supabase_service.dart';
import '../../services/sesion.dart';
import '../../services/pdf/stock_antiguo_pdf_service.dart';
class StockAntiguoPage extends StatefulWidget {
  const StockAntiguoPage({super.key});

  @override
  State<StockAntiguoPage> createState() => _StockAntiguoPageState();
}

class _StockAntiguoPageState extends State<StockAntiguoPage> {
  static const verde = Color(0xFF08783B);
  static const verdeSuave = Color(0xFFEAF5EE);
  static const azul = Color(0xFF1565D8);
  static const naranja = Color(0xFFF59E0B);
  static const rojo = Color(0xFFEF4444);
  static const amarillo = Color(0xFFF4C430);

  final _busquedaController = TextEditingController();
  final _fechaFormat = DateFormat('dd/MM/yyyy');
  final _numeroFormat = NumberFormat('#,##0.##', 'en_US');
  final _monedaFormat = NumberFormat('#,##0.00', 'en_US');

  List<_StockAntiguoItem> _todos = [];
  List<_StockAntiguoItem> _filtrados = [];
  List<String> _clientes = [];

  String _cliente = 'Todos';
  String _estado = 'Todos';
  int _diasMinimos = 30;
  bool _cargando = true;
  String? _error;

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

      if (pagina.length < tamanoPagina) {
        break;
      }

      inicio += tamanoPagina;
    }

    // Gerencia ve todo.
    if (Sesion.rol == 'Gerencia') {
      return datos;
    }

    // Jefaturas: vendedores autorizados.
    if (Sesion.rol == 'Jefe Lima' || Sesion.rol == 'Jefe Provincia') {
      final respuesta = await db
          .from('usuario_permisos')
          .select('vendedor, ver_produccion')
          .eq('usuario_jefe_id', Sesion.idUsuario)
          .eq('ver_produccion', true);

      final permitidos = (respuesta as List)
          .map(
            (e) => e['vendedor']?.toString().trim().toLowerCase() ?? '',
          )
          .where((e) => e.isNotEmpty)
          .toSet();

      return datos.where((fila) {
        final vendedor =
            fila['vendedor']?.toString().trim().toLowerCase() ?? '';
        return permitidos.contains(vendedor);
      }).toList();
    }

    // Usuario con vendedor asignado: solo su vendedor.
    final vendedorSesion = Sesion.vendedor.trim().toLowerCase();

    if (vendedorSesion.isNotEmpty) {
      return datos.where((fila) {
        final vendedor =
            fila['vendedor']?.toString().trim().toLowerCase() ?? '';
        return vendedor == vendedorSesion;
      }).toList();
    }

    return [];
  }

  double _double(dynamic valor) {
    if (valor == null) return 0;
    if (valor is num) return valor.toDouble();

    return double.tryParse(
          valor.toString().replaceAll(',', '').trim(),
        ) ??
        0;
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

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final datos = await _obtenerStockPermitido();
      final hoy = DateTime.now();

      final lista = <_StockAntiguoItem>[];

      for (final fila in datos) {
        final fechaIngreso = _fecha(fila['fecha_ingreso']);

        if (fechaIngreso == null) {
          continue;
        }

        final fechaBase = DateTime(
          fechaIngreso.year,
          fechaIngreso.month,
          fechaIngreso.day,
        );

        final hoyBase = DateTime(hoy.year, hoy.month, hoy.day);
        final dias = hoyBase.difference(fechaBase).inDays;

        if (dias < 0) {
          continue;
        }

        lista.add(
          _StockAntiguoItem(
            codigo: _texto(fila, ['codigo_articulo', 'codigoArticulo']),
            descripcion: _texto(
              fila,
              ['descripcion', 'articulo'],
              fallback: 'SIN DESCRIPCIÓN',
            ),
            cliente: _texto(
              fila,
              ['cliente'],
              fallback: 'SIN CLIENTE',
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

      lista.sort((a, b) => b.dias.compareTo(a.dias));

      final clientes = lista
          .map((e) => e.cliente.trim())
          .where((e) => e.isNotEmpty && e != 'SIN CLIENTE')
          .toSet()
          .toList()
        ..sort();

      if (!mounted) return;

      setState(() {
        _todos = lista;
        _clientes = clientes;
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

  void _aplicarFiltros() {
    final texto = _busquedaController.text.trim().toLowerCase();

    final resultado = _todos.where((item) {
      final coincideTexto = texto.isEmpty ||
          item.descripcion.toLowerCase().contains(texto) ||
          item.codigo.toLowerCase().contains(texto) ||
          item.cliente.toLowerCase().contains(texto);

      final coincideCliente =
          _cliente == 'Todos' || item.cliente == _cliente;

      final coincideDias = item.dias >= _diasMinimos;

      final coincideEstado =
          _estado == 'Todos' || item.estado == _estado;

      return coincideTexto &&
          coincideCliente &&
          coincideDias &&
          coincideEstado;
    }).toList();

    resultado.sort((a, b) => b.dias.compareTo(a.dias));

    setState(() {
      _filtrados = resultado;
    });
  }

  void _limpiar() {
    _busquedaController.clear();

    setState(() {
      _cliente = 'Todos';
      _estado = 'Todos';
      _diasMinimos = 30;
    });

    _aplicarFiltros();
  }

  String _rango(int dias) {
    if (dias > 90) return '> 90 días';
    if (dias >= 61) return '61 - 90 días';
    if (dias >= 31) return '31 - 60 días';
    return '30 días';
  }

  Color _colorDias(int dias) {
    if (dias > 90) return rojo;
    if (dias >= 61) return Colors.deepOrange;
    if (dias >= 31) return amarillo;
    return verde;
  }

  String _estadoItem(int dias) {
    if (dias > 90) return 'Crítico';
    if (dias >= 61) return 'Antiguo';
    if (dias >= 31) return 'Atención';
    return 'Normal';
  }

  double get _valorTotal =>
      _filtrados.fold(0, (suma, item) => suma + item.valorTotal);

  double get _pesoTotal =>
      _filtrados.fold(0, (suma, item) => suma + item.peso);

  double get _promedioDias => _filtrados.isEmpty
      ? 0
      : _filtrados.fold<int>(0, (suma, item) => suma + item.dias) /
          _filtrados.length;

  Map<String, int> get _rangos {
    return {
      '> 90 días': _filtrados.where((e) => e.dias > 90).length,
      '61 - 90 días':
          _filtrados.where((e) => e.dias >= 61 && e.dias <= 90).length,
      '31 - 60 días':
          _filtrados.where((e) => e.dias >= 31 && e.dias <= 60).length,
      '30 días': _filtrados.where((e) => e.dias == 30).length,
    };
  }

  Map<String, double> get _clientesAntiguos {
    final mapa = <String, double>{};

    for (final item in _filtrados) {
      mapa.update(
        item.cliente,
        (valor) => valor + item.valorTotal,
        ifAbsent: () => item.valorTotal,
      );
    }

    return mapa;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF243238),
        titleSpacing: 18,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: verdeSuave,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.calendar_month_outlined,
                color: verde,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'STOCK ANTIGUO',
              style: TextStyle(
                color: verde,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: ElevatedButton.icon(
              onPressed: _filtrados.isEmpty
                  ? null
                  : () async {
                      await StockAntiguoPdfService.imprimir(
                        context: context,
                        items: _filtrados
                            .map(
                              (item) => StockAntiguoPdfItem(
                                codigo: item.codigo,
                                descripcion: item.descripcion,
                                cliente: item.cliente,
                                fechaIngreso: item.fechaIngreso,
                                dias: item.dias,
                                stock: item.stock,
                                precio: item.precio,
                                valorTotal: item.valorTotal,
                                peso: item.peso,
                              ),
                            )
                            .toList(),
                      );
                    },
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
          ? const Center(
              child: CircularProgressIndicator(color: verde),
            )
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
                            _kpis(movil),
                            const SizedBox(height: 10),
                            _filtros(movil),
                            const SizedBox(height: 10),
                            movil
                                ? Column(
                                    children: [
                                      _tabla(movil),
                                      const SizedBox(height: 10),
                                      _distribucion(),
                                      const SizedBox(height: 10),
                                      _topClientes(),
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 7,
                                        child: _tabla(movil),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          children: [
                                            _distribucion(),
                                            const SizedBox(height: 12),
                                            _topClientes(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: verdeSuave,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.event_available_outlined,
              color: verde,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STOCK ANTIGUO',
                  style: TextStyle(
                    color: verde,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Artículos con más de 30 días desde su ingreso',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Permite identificar productos con mayor tiempo de permanencia en almacén.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
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

  Widget _kpis(bool movil) {
    final cards = [
      _KpiData(
        'ARTÍCULOS',
        _numeroFormat.format(_filtrados.length),
        'con más de 30 días',
        Icons.inventory_2_outlined,
        verde,
      ),
      _KpiData(
        'VALOR TOTAL',
        'US\$ ${_monedaFormat.format(_valorTotal)}',
        'en stock antiguo',
        Icons.attach_money,
        azul,
      ),
      _KpiData(
        'PESO COBRE',
        '${_monedaFormat.format(_pesoTotal)} t',
        'en stock antiguo',
        Icons.scale_outlined,
        naranja,
      ),
      _KpiData(
        'DÍAS PROMEDIO',
        '${_promedioDias.round()} días',
        'de permanencia',
        Icons.access_time,
        azul,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: movil ? 2 : 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: movil ? 1.8 : 3.0,
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
                    Text(
                      item.titulo,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.grey,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.valor,
                        style: TextStyle(
                          color: item.color,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      item.subtitulo,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 8,
                      ),
                    ),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _decoracion(),
      child: movil
          ? Column(
              children: [
                _campoBusqueda(),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(child: _clienteFiltro()),
                    const SizedBox(width: 8),
                    Expanded(child: _diasFiltro()),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(child: _estadoFiltro()),
                    const SizedBox(width: 8),
                    Expanded(child: _botonesFiltro()),
                  ],
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(flex: 3, child: _campoBusqueda()),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: _clienteFiltro()),
                const SizedBox(width: 8),
                Expanded(flex: 1, child: _diasFiltro()),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: _estadoFiltro()),
                const SizedBox(width: 8),
                _botonesFiltro(),
              ],
            ),
    );
  }

  Widget _campoBusqueda() {
    return _campoBase(
      titulo: 'Buscar artículo o cliente',
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
  }

  Widget _clienteFiltro() {
    return _campoBase(
      titulo: 'Cliente',
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _clientes.contains(_cliente) ? _cliente : 'Todos',
          isExpanded: true,
          items: [
            const DropdownMenuItem(
              value: 'Todos',
              child: Text('Todos'),
            ),
            ..._clientes.map(
              (cliente) => DropdownMenuItem(
                value: cliente,
                child: Text(
                  cliente,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _cliente = value);
            _aplicarFiltros();
          },
        ),
      ),
    );
  }

  Widget _diasFiltro() {
    return _campoBase(
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
          onChanged: (value) {
            if (value == null) return;
            setState(() => _diasMinimos = value);
            _aplicarFiltros();
          },
        ),
      ),
    );
  }

  Widget _estadoFiltro() {
    return _campoBase(
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
          onChanged: (value) {
            if (value == null) return;
            setState(() => _estado = value);
            _aplicarFiltros();
          },
        ),
      ),
    );
  }

  Widget _botonesFiltro() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _aplicarFiltros,
          icon: const Icon(Icons.search, size: 16),
          label: const Text('BUSCAR'),
          style: ElevatedButton.styleFrom(
            backgroundColor: verde,
            foregroundColor: Colors.white,
            minimumSize: const Size(98, 42),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ),
        const SizedBox(width: 7),
        OutlinedButton.icon(
          onPressed: _limpiar,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('LIMPIAR'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey.shade700,
            minimumSize: const Size(98, 42),
            side: BorderSide.none,
            backgroundColor: Colors.grey.shade100,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _campoBase({
    required String titulo,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Color(0xFF455A64),
          ),
        ),
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

  Widget _tabla(bool movil) {
    return Container(
      decoration: _decoracion(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 9),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month,
                  color: verde,
                  size: 18,
                ),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'ARTÍCULOS CON MÁS DE 30 DÍAS',
                    style: TextStyle(
                      color: verde,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  'Total: ${_filtrados.length} artículos',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_filtrados.isEmpty)
            const Padding(
              padding: EdgeInsets.all(35),
              child: Center(
                child: Text(
                  'No se encontraron artículos con los filtros seleccionados.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            movil ? _tablaMovil() : _tablaDesktop(),
        ],
      ),
    );
  }

  Widget _tablaDesktop() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(10),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 30,
          dataRowMinHeight: 32,
          dataRowMaxHeight: 42,
          columnSpacing: 12,
          horizontalMargin: 10,
          headingRowColor: WidgetStateProperty.all(verde),
          headingTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
          columns: const [
            DataColumn(label: Text('N°')),
            DataColumn(label: Text('Código')),
            DataColumn(label: Text('Descripción')),
            DataColumn(label: Text('Cliente')),
            DataColumn(label: Text('Ingreso')),
            DataColumn(label: Text('Días')),
            DataColumn(label: Text('Stock')),
            DataColumn(label: Text('Precio US\$')),
            DataColumn(label: Text('Valor Total')),
            DataColumn(label: Text('Peso Cobre')),
          ],
          rows: List.generate(_filtrados.length, (index) {
            final item = _filtrados[index];

            return DataRow(
              cells: [
                DataCell(Text('${index + 1}', style: _textoTabla())),
                DataCell(Text(item.codigo, style: _textoTabla())),
             DataCell(
  SizedBox(
    width: 360,
    child: Text(
      item.descripcion,
      softWrap: false,
      style: _textoTabla(),
    ),
  ),
),
                DataCell(
                  SizedBox(
                    width: 150,
                    child: Text(
                      item.cliente,
                      overflow: TextOverflow.ellipsis,
                      style: _textoTabla(),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _fechaFormat.format(item.fechaIngreso),
                    style: _textoTabla(),
                  ),
                ),
                DataCell(_badgeDias(item.dias)),
                DataCell(
                  Text(
                    _numeroFormat.format(item.stock),
                    style: _textoTabla(),
                  ),
                ),
                DataCell(
                  Text(
                    _monedaFormat.format(item.precio),
                    style: _textoTabla(),
                  ),
                ),
                DataCell(
                  Text(
                    'US\$ ${_monedaFormat.format(item.valorTotal)}',
                    style: _textoTabla(fontWeight: FontWeight.w700),
                  ),
                ),
                DataCell(
                  Text(
                    '${_monedaFormat.format(item.peso)} t',
                    style: _textoTabla(),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  TextStyle _textoTabla({
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return TextStyle(
      fontSize: 9,
      color: const Color(0xFF263238),
      fontWeight: fontWeight,
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
            border: Border.all(color: const Color(0xFFE3E8EA)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${index + 1}. ${item.codigo}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: verde,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  _badgeDias(item.dias),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                item.descripcion,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              Text(
                item.cliente,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 12,
                runSpacing: 5,
                children: [
                  Text('Ingreso: ${_fechaFormat.format(item.fechaIngreso)}'),
                  Text('Stock: ${_numeroFormat.format(item.stock)}'),
                  Text('US\$ ${_monedaFormat.format(item.valorTotal)}'),
                  Text('${_monedaFormat.format(item.peso)} t'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _badgeDias(int dias) {
    final color = _colorDias(dias);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '$dias',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _distribucion() {
    final rangos = _rangos;
    final maximo =
        rangos.values.fold<int>(0, (a, b) => a > b ? a : b).toDouble();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _decoracion(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.calendar_view_week_outlined,
                color: verde,
                size: 17,
              ),
              SizedBox(width: 7),
              Text(
                'DISTRIBUCIÓN POR RANGO DE DÍAS',
                style: TextStyle(
                  color: verde,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: rangos.entries.map((entry) {
                final valor = entry.value.toDouble();
                final alto = maximo == 0
                    ? 2.0
                    : 105 * (valor / maximo).clamp(.03, 1.0);

                final color = entry.key == '> 90 días'
                    ? rojo
                    : entry.key == '61 - 90 días'
                        ? Colors.deepOrange
                        : entry.key == '31 - 60 días'
                            ? amarillo
                            : verde;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${entry.value}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: alto,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          entry.key,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 8,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topClientes() {
    final datos = _clientesAntiguos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = datos.take(5).toList();
    final maximo = top.isEmpty ? 0.0 : top.first.value;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _decoracion(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.people_alt_outlined,
                color: verde,
                size: 17,
              ),
              SizedBox(width: 7),
              Text(
                'TOP 5 CLIENTES CON STOCK ANTIGUO',
                style: TextStyle(
                  color: verde,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          if (top.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Sin información',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...List.generate(top.length, (index) {
              final item = top[index];
              final proporcion =
                  maximo == 0 ? 0.0 : item.value / maximo;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 21,
                      height: 21,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: index == 0
                            ? verde
                            : azul.withOpacity(.12),
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
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                'US\$ ${_monedaFormat.format(item.value)}',
                                style: const TextStyle(
                                  color: verde,
                                  fontSize: 8,
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
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(azul),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'No se pudo cargar Stock Antiguo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text('REINTENTAR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: verde,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _decoracion() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0xFFE1E7E9)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    );
  }
}

class _StockAntiguoItem {
  final String codigo;
  final String descripcion;
  final String cliente;
  final DateTime fechaIngreso;
  final int dias;
  final double stock;
  final double precio;
  final double valorTotal;
  final double peso;

  const _StockAntiguoItem({
    required this.codigo,
    required this.descripcion,
    required this.cliente,
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

class _KpiData {
  final String titulo;
  final String valor;
  final String subtitulo;
  final IconData icon;
  final Color color;

  const _KpiData(
    this.titulo,
    this.valor,
    this.subtitulo,
    this.icon,
    this.color,
  );
}
