import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/dashboard/producto_cliente.dart';
import '../../services/supabase/dashboard_service.dart';
import '../../services/pdf/cliente_pdf_service.dart';

class ProductosClienteSection extends StatefulWidget {
  final String cliente;

  const ProductosClienteSection({
    super.key,
    required this.cliente,
  });

  @override
  State<ProductosClienteSection> createState() =>
      _ProductosClienteSectionState();
}

class _ProductosClienteSectionState
    extends State<ProductosClienteSection> {
  final DashboardService _service =
      DashboardService();

  final TextEditingController _buscarController =
      TextEditingController();

  String busqueda = '';

  // =========================================================
  // PRODUCTOS COMPLETOS DEL CLIENTE SELECCIONADO
  // =========================================================

  List<ProductoCliente> productos = [];

  bool cargando = true;

  String? error;

  final NumberFormat moneda = NumberFormat(
    '#,##0',
    'en_US',
  );

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();

    _buscarController.addListener(() {
      if (!mounted) {
        return;
      }

      setState(() {
        busqueda =
            _buscarController.text
                .trim()
                .toLowerCase();
      });
    });

    _cargarProductos();
  }

  // =========================================================
  // CARGAR PRODUCTOS DEL CLIENTE
  // =========================================================

  Future<void> _cargarProductos() async {
    try {
      setState(() {
        cargando = true;
        error = null;
      });

      final resultado =
          await _service.obtenerProductosCliente(
        widget.cliente,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        productos = resultado;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        cargando = false;
        error = e.toString();
      });
    }
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _buscarController.dispose();
    super.dispose();
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    // =======================================================
    // FILTRO PARA LA PANTALLA
    // =======================================================

    final productosFiltrados =
        productos.where((producto) {
      if (busqueda.isEmpty) {
        return true;
      }

      final texto =
          '${producto.descripcion} '
          '${producto.fechaIngreso}'
              .toLowerCase();

      return texto.contains(busqueda);
    }).toList();

    // =======================================================
    // CARGANDO
    // =======================================================

    if (cargando) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(25),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // =======================================================
    // ERROR
    // =======================================================

    if (error != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.06),
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: Text(
          'Error al cargar artículos:\n$error',
          style: const TextStyle(
            color: Colors.red,
          ),
        ),
      );
    }

    // =======================================================
    // TOTALES DE LA VISTA
    // =======================================================

    double totalCantidad = 0;
    double totalPeso = 0;
    double totalValor = 0;

    for (final producto in productosFiltrados) {
      totalCantidad += producto.stock;
      totalPeso += producto.peso;
      totalValor += producto.valor;
    }

    // =======================================================
    // CONTENEDOR PRINCIPAL
    // =======================================================

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(16),

        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          // ===================================================
          // TITULO
          // ===================================================

          Row(
            children: [
              const Icon(
                Icons.inventory_2,
                color: Colors.indigo,
                size: 22,
              ),

              const SizedBox(width: 8),

              const Expanded(
                child: Text(
                  'Artículos del cliente',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              Text(
                '${productos.length} artículos',
                style: TextStyle(
                  color:
                      Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ===================================================
          // BOTÓN REPORTE PDF
          // ===================================================
          //
          // IMPORTANTE:
          //
          // Se envía "productos", NO "productosFiltrados".
          //
          // Así el PDF contiene TODO el stock del cliente,
          // aunque se esté utilizando el buscador.
          //
          // ===================================================

          SizedBox(
            width: double.infinity,

            child: ElevatedButton.icon(
              icon: const Icon(
                Icons.picture_as_pdf_outlined,
              ),

              label: const Text(
                'Generar reporte PDF',
              ),

              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                  0xff4056B4,
                ),

                foregroundColor:
                    Colors.white,

                padding:
                    const EdgeInsets.symmetric(
                  vertical: 13,
                ),

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
              ),

              onPressed: () async {
                await ClientePdfService
                    .imprimirReporteStock(
                  context: context,

                  // Cliente seleccionado
                  cliente: widget.cliente,

                  // TODOS los productos
                  // de ese cliente
                  productos: productos,
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // ===================================================
          // BUSCADOR DE ARTÍCULOS
          // ===================================================

          TextField(
            controller:
                _buscarController,

            decoration:
                InputDecoration(
              hintText:
                  'Buscar artículo...',

              prefixIcon:
                  const Icon(
                Icons.search,
              ),

              suffixIcon:
                  busqueda.isNotEmpty
                      ? IconButton(
                          icon:
                              const Icon(
                            Icons.clear,
                          ),
                          onPressed: () {
                            _buscarController
                                .clear();
                          },
                        )
                      : null,

              filled: true,

              fillColor:
                  const Color(
                0xffF5F7FB,
              ),

              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),

                borderSide:
                    BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ===================================================
          // LISTA
          // ===================================================

          if (productosFiltrados.isEmpty)
            const Padding(
              padding:
                  EdgeInsets.all(20),

              child: Center(
                child: Text(
                  'No se encontraron artículos.',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,

              physics:
                  const NeverScrollableScrollPhysics(),

              itemCount:
                  productosFiltrados.length,

              itemBuilder:
                  (context, index) {
                final producto =
                    productosFiltrados[
                        index];

                return _ProductoItem(
                  numero: index + 1,

                  producto: producto,

                  moneda: moneda,
                );
              },
            ),

          const SizedBox(height: 10),

          // ===================================================
          // TOTALES
          // ===================================================

          Container(
            width: double.infinity,

            padding:
                const EdgeInsets.all(
              14,
            ),

            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xffF5F7FB,
              ),

              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),

            child: Wrap(
              spacing: 20,
              runSpacing: 10,

              children: [
                _TotalItem(
                  titulo:
                      'Artículos',

                  valor:
                      '${productosFiltrados.length}',

                  color:
                      Colors.indigo,
                ),

                _TotalItem(
                  titulo:
                      'Cantidad',

                  valor:
                      totalCantidad
                          .toStringAsFixed(
                    0,
                  ),

                  color:
                      Colors.blue,
                ),

                _TotalItem(
                  titulo:
                      'Monto',

                  valor:
                      'US\$ ${moneda.format(totalValor)}',

                  color:
                      Colors.green,
                ),

                _TotalItem(
                  titulo:
                      'Peso',

                  valor:
                      '${(totalPeso / 1000).toStringAsFixed(2)} t',

                  color:
                      Colors.orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// ITEM PRODUCTO
// =============================================================

class _ProductoItem
    extends StatelessWidget {
  final int numero;

  final ProductoCliente producto;

  final NumberFormat moneda;

  const _ProductoItem({
    required this.numero,
    required this.producto,
    required this.moneda,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),

      padding:
          const EdgeInsets.all(
        12,
      ),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          12,
        ),

        border:
            Border.all(
          color:
              Colors.grey.shade200,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          // ===================================================
          // DESCRIPCIÓN
          // ===================================================

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Container(
                width: 28,
                height: 28,

                alignment:
                    Alignment.center,

                decoration:
                    BoxDecoration(
                  color:
                      Colors.indigo
                          .withOpacity(
                    0.08,
                  ),

                  shape:
                      BoxShape.circle,
                ),

                child: Text(
                  '$numero',

                  style:
                      const TextStyle(
                    color:
                        Colors.indigo,

                    fontWeight:
                        FontWeight.bold,

                    fontSize: 11,
                  ),
                ),
              ),

              const SizedBox(
                width: 9,
              ),

              Expanded(
                child: Text(
                  producto.descripcion,

                  maxLines: 3,

                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w600,

                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          // ===================================================
          // DATOS
          // ===================================================

          Wrap(
            spacing: 15,
            runSpacing: 8,

            children: [
              _DatoProducto(
                titulo:
                    'Fecha ingreso',

                valor:
                    _formatearFecha(
                  producto.fechaIngreso,
                ),
              ),

              _DatoProducto(
                titulo:
                    'Cantidad',

                valor:
                    producto.stock
                        .toStringAsFixed(
                  0,
                ),
              ),

              _DatoProducto(
                titulo:
                    'Monto',

                valor:
                    'US\$ ${moneda.format(producto.valor)}',
              ),

              _DatoProducto(
                titulo:
                    'Peso',

                valor:
                    '${producto.peso.toStringAsFixed(2)} Kg',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // FORMATEAR FECHA
  // ===========================================================

  String _formatearFecha(
    String fecha,
  ) {
    if (fecha.trim().isEmpty) {
      return '-';
    }

    try {
      final date =
          DateTime.parse(fecha);

      return DateFormat(
        'dd/MM/yyyy',
      ).format(date);
    } catch (_) {
      return fecha;
    }
  }
}

// =============================================================
// DATO PRODUCTO
// =============================================================

class _DatoProducto
    extends StatelessWidget {
  final String titulo;

  final String valor;

  const _DatoProducto({
    required this.titulo,
    required this.valor,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      width: 125,

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Text(
            titulo,

            style: TextStyle(
              color:
                  Colors.grey.shade600,

              fontSize: 10,
            ),
          ),

          const SizedBox(
            height: 2,
          ),

          Text(
            valor,

            style:
                const TextStyle(
              fontSize: 12,

              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// TOTAL
// =============================================================

class _TotalItem
    extends StatelessWidget {
  final String titulo;

  final String valor;

  final Color color;

  const _TotalItem({
    required this.titulo,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Text(
          titulo,

          style: TextStyle(
            color:
                Colors.grey.shade600,

            fontSize: 10,
          ),
        ),

        const SizedBox(
          height: 2,
        ),

        Text(
          valor,

          style:
              TextStyle(
            color: color,

            fontWeight:
                FontWeight.bold,

            fontSize: 14,
          ),
        ),
      ],
    );
  }
}