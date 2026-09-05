import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/dashboard/cliente_top.dart';
import '../../models/dashboard/producto_cliente.dart';
import '../../services/pdf/cliente_pdf_service.dart';
import '../../services/supabase/dashboard_service.dart';

class ClienteStockPreviewPage extends StatefulWidget {
  final ClienteTop cliente;

  const ClienteStockPreviewPage({
    super.key,
    required this.cliente,
  });

  @override
  State<ClienteStockPreviewPage> createState() =>
      _ClienteStockPreviewPageState();
}

class _ClienteStockPreviewPageState
    extends State<ClienteStockPreviewPage> {
  final DashboardService _service = DashboardService();

  List<ProductoCliente> productos = [];

  bool cargando = true;
  String? error;

  final NumberFormat moneda = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'US\$ ',
    decimalDigits: 2,
  );

  final NumberFormat cantidadFormat = NumberFormat(
    '#,##0.##',
    'en_US',
  );

  final NumberFormat pesoFormat = NumberFormat(
    '#,##0.00',
    'en_US',
  );

  static const Color verdeElcope = Color(0xff08783B);
  static const Color verdeClaro = Color(0xffEAF5EE);
  static const Color azulAnalitico = Color(0xff1565D8);
  static const Color naranja = Color(0xffF59E0B);

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    try {
      setState(() {
        cargando = true;
        error = null;
      });

      final resultado = await _service.obtenerProductosCliente(
        widget.cliente.cliente,
      );

      if (!mounted) return;

      setState(() {
        productos = resultado;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        cargando = false;
        error = e.toString();
      });
    }
  }

  double get totalCantidad {
    return productos.fold(
      0,
      (total, producto) => total + producto.stock,
    );
  }

  double get totalValor {
    return productos.fold(
      0,
      (total, producto) => total + producto.valor,
    );
  }

  double get totalPeso {
    return productos.fold(
      0,
      (total, producto) => total + producto.peso,
    );
  }

  Future<void> _imprimir() async {
    if (productos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El cliente no tiene artículos para imprimir.',
          ),
        ),
      );
      return;
    }

    await ClientePdfService.imprimirReporteStock(
      context: context,
      cliente: widget.cliente.cliente,
      productos: productos,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: verdeElcope,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        centerTitle: true,
        title: const Text(
          'DETALLE DEL CLIENTE',
          style: TextStyle(
            color: verdeElcope,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: 14,
              top: 8,
              bottom: 8,
            ),
            child: ElevatedButton.icon(
              onPressed: cargando ? null : _imprimir,
              icon: const Icon(
                Icons.print,
                size: 18,
              ),
              label: const Text(
                'IMPRIMIR',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: verdeElcope,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: cargando
            ? const Center(
                child: CircularProgressIndicator(
                  color: verdeElcope,
                ),
              )
            : error != null
                ? _errorView()
                : _contenido(),
      ),
    );
  }

  Widget _contenido() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final esMovil = constraints.maxWidth < 800;

        return SingleChildScrollView(
          padding: EdgeInsets.all(
            esMovil ? 14 : 28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _encabezado(esMovil),
              const SizedBox(height: 20),
              _kpis(esMovil),
              const SizedBox(height: 24),
              _tituloArticulos(),
              const SizedBox(height: 12),
              esMovil
                  ? _listaMovil()
                  : _tablaDesktop(),
            ],
          ),
        );
      },
    );
  }

  Widget _encabezado(bool esMovil) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        esMovil ? 18 : 26,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xffDDE5E0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: esMovil ? 54 : 66,
            height: esMovil ? 54 : 66,
            decoration: BoxDecoration(
              color: verdeClaro,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.business,
              color: verdeElcope,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'REPORTE DE STOCK',
                  style: TextStyle(
                    color: verdeElcope,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.cliente.cliente,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: esMovil ? 16 : 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Detalle de artículos disponibles',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpis(bool esMovil) {
    if (esMovil) {
      return Column(
        children: [
          _kpi(
            titulo: 'ARTÍCULOS',
            valor: cantidadFormat.format(
              productos.length,
            ),
            icono: Icons.inventory_2_outlined,
            color: verdeElcope,
          ),
          const SizedBox(height: 12),
          _kpi(
            titulo: 'CANTIDAD TOTAL',
            valor: cantidadFormat.format(
              totalCantidad,
            ),
            icono: Icons.numbers,
            color: azulAnalitico,
          ),
          const SizedBox(height: 12),
          _kpi(
            titulo: 'VALOR TOTAL',
            valor: moneda.format(totalValor),
            icono: Icons.attach_money,
            color: verdeElcope,
          ),
          const SizedBox(height: 12),
          _kpi(
            titulo: 'PESO COBRE',
            valor: '${pesoFormat.format(totalPeso)} t',
            icono: Icons.scale_outlined,
            color: naranja,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _kpi(
            titulo: 'ARTÍCULOS',
            valor: cantidadFormat.format(
              productos.length,
            ),
            icono: Icons.inventory_2_outlined,
            color: verdeElcope,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _kpi(
            titulo: 'CANTIDAD TOTAL',
            valor: cantidadFormat.format(
              totalCantidad,
            ),
            icono: Icons.numbers,
            color: azulAnalitico,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _kpi(
            titulo: 'VALOR TOTAL',
            valor: moneda.format(totalValor),
            icono: Icons.attach_money,
            color: verdeElcope,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _kpi(
            titulo: 'PESO COBRE',
            valor: '${pesoFormat.format(totalPeso)} t',
            icono: Icons.scale_outlined,
            color: naranja,
          ),
        ),
      ],
    );
  }

  Widget _kpi({
    required String titulo,
    required String valor,
    required IconData icono,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xffDDE5E0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icono,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  valor,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tituloArticulos() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 15,
      ),
      decoration: BoxDecoration(
        color: verdeClaro,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.inventory_2,
            color: verdeElcope,
            size: 23,
          ),
          SizedBox(width: 10),
          Text(
            'ARTÍCULOS DEL CLIENTE',
            style: TextStyle(
              color: verdeElcope,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tablaDesktop() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xffDDE5E0),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DataTable(
          headingRowHeight: 52,
          dataRowMinHeight: 54,
          dataRowMaxHeight: 70,
          headingRowColor:
              MaterialStateProperty.all(
            verdeElcope,
          ),
          columns: const [
            DataColumn(
              label: Text(
                'N°',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'ARTÍCULO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DataColumn(
              numeric: true,
              label: Text(
                'CANTIDAD',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DataColumn(
              numeric: true,
              label: Text(
                'PRECIO US\$',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DataColumn(
              numeric: true,
              label: Text(
                'PESO COBRE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          rows: List.generate(
            productos.length,
            (index) {
              final producto = productos[index];

              return DataRow(
                color: MaterialStateProperty.resolveWith(
                  (states) {
                    if (index.isEven) {
                      return const Color(0xffF8FAF9);
                    }

                    return Colors.white;
                  },
                ),
                cells: [
                  DataCell(
                    Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: azulAnalitico,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 360,
                      child: Text(
                        producto.descripcion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      cantidadFormat.format(
                        producto.stock,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      moneda.format(
                        producto.valor,
                      ),
                      style: const TextStyle(
                        color: verdeElcope,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${pesoFormat.format(producto.peso)} t',
                      style: const TextStyle(
                        color: naranja,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _listaMovil() {
    return Column(
      children: List.generate(
        productos.length,
        (index) {
          final producto = productos[index];

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(
              bottom: 12,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xffDDE5E0),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: azulAnalitico,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        producto.descripcion,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 8),
                _datoMovil(
                  'CANTIDAD',
                  cantidadFormat.format(
                    producto.stock,
                  ),
                  azulAnalitico,
                ),
                _datoMovil(
                  'PRECIO',
                  moneda.format(
                    producto.valor,
                  ),
                  verdeElcope,
                ),
                _datoMovil(
                  'PESO COBRE',
                  '${pesoFormat.format(producto.peso)} t',
                  naranja,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _datoMovil(
    String titulo,
    String valor,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              titulo,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
              size: 55,
            ),
            const SizedBox(height: 15),
            const Text(
              'No se pudieron cargar los artículos.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _cargarProductos,
              icon: const Icon(Icons.refresh),
              label: const Text('REINTENTAR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: verdeElcope,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}