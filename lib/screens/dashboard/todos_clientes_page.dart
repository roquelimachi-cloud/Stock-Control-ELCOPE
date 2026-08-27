import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/dashboard/cliente_top.dart';
import '../../services/pdf/cliente_pdf_service.dart';
import '../../widgets/dashboard/productos_cliente_section.dart';
class TodosClientesPage extends StatefulWidget {
  final List<ClienteTop> clientes;

  const TodosClientesPage({
    super.key,
    required this.clientes,
  });

  @override
  State<TodosClientesPage> createState() =>
      _TodosClientesPageState();
}

class _TodosClientesPageState
    extends State<TodosClientesPage> {
  final TextEditingController _buscarController =
      TextEditingController();

  String busqueda = '';

  ClienteTop? clienteSeleccionado;

  final NumberFormat moneda = NumberFormat(
    '#,##0',
    'en_US',
  );

  // =========================================================
  // INICIO
  // =========================================================

// =========================================================
// INICIALIZAR
// =========================================================

@override
void initState() {
  super.initState();

  _buscarController.addListener(() {
    setState(() {
      busqueda =
          _buscarController.text.trim().toLowerCase();

      // =====================================================
      // IMPORTANTE:
      // Buscar NO selecciona automáticamente al cliente.
      //
      // El cliente solamente se selecciona cuando el usuario
      // hace clic sobre él.
      // =====================================================

      clienteSeleccionado = null;
    });
  });
}

// =========================================================
// CERRAR
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
    final todosLosClientes = widget.clientes;

    // =======================================================
    // FILTRAR
    // =======================================================

    final clientesFiltrados =
        todosLosClientes.where((cliente) {
      if (busqueda.isEmpty) {
        return true;
      }

      return cliente.cliente
          .toLowerCase()
          .contains(busqueda);
    }).toList();

// =======================================================
// TOTALES SEGÚN LA BÚSQUEDA
// =======================================================
//
// Si no hay búsqueda:
//   → suma todos los clientes.
//
// Si hay búsqueda:
//   → suma solamente los clientes encontrados.
//
// Esto hace que:
// - Valor total
// - Peso total
// - Cantidad de clientes
//
// correspondan siempre a lo que se está mostrando.
// =======================================================

final total = clientesFiltrados.fold<double>(
  0,
  (suma, cliente) =>
      suma + cliente.valorStock,
);

final totalPeso = clientesFiltrados.fold<double>(
  0,
  (suma, cliente) =>
      suma + cliente.pesoCobre,
);
    return Scaffold(
      backgroundColor:
          const Color(0xffF5F7FB),

      // =====================================================
      // APP BAR
      // =====================================================

      appBar: AppBar(
        backgroundColor:
            const Color(0xff4056B4),

        foregroundColor:
            Colors.white,

        elevation: 0,

        title: const Text(
          'Todos los Clientes',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),

      // =====================================================
      // CONTENIDO
      // =====================================================

      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.all(20),

          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
              // =================================================
              // ENCABEZADO
              // =================================================

              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,

                    decoration:
                        BoxDecoration(
                      color: Colors.amber
                          .withOpacity(0.15),

                      shape:
                          BoxShape.circle,
                    ),

                    child: const Icon(
                      Icons
                          .emoji_events,
                      color:
                          Colors.amber,
                      size: 27,
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  const Expanded(
                    child: Text(
                      'Todos los Clientes',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 18,
              ),

              // =================================================
              // RESUMEN GENERAL
              // =================================================

              LayoutBuilder(
                builder:
                    (context, constraints) {
                  final ancho =
                      constraints.maxWidth;

                  final compacto =
                      ancho < 700;

                  if (compacto) {
                    return Column(
                      children: [
                        _ResumenCard(
                          titulo:
                              'Clientes',
                          valor:
                              '${todosLosClientes.length}',
                          icono:
                              Icons.people,
                          color:
                              Colors.blue,
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        _ResumenCard(
                          titulo:
                              'Valor total',
                          valor:
                              'US\$ ${moneda.format(total)}',
                          icono:
                              Icons
                                  .attach_money,
                          color:
                              Colors.green,
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        _ResumenCard(
                          titulo:
                              'Peso total',
                          valor:
                              '${(totalPeso / 1000).toStringAsFixed(2)} t',
                          icono:
                              Icons
                                  .scale,
                          color:
                              Colors.orange,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child:
                            _ResumenCard(
                          titulo:
                              'Clientes',
                          valor:
                              '${todosLosClientes.length}',
                          icono:
                              Icons.people,
                          color:
                              Colors.blue,
                        ),
                      ),

                      const SizedBox(
                        width: 12,
                      ),

                      Expanded(
                        child:
                            _ResumenCard(
                          titulo:
                              'Valor total',
                          valor:
                              'US\$ ${moneda.format(total)}',
                          icono:
                              Icons
                                  .attach_money,
                          color:
                              Colors.green,
                        ),
                      ),

                      const SizedBox(
                        width: 12,
                      ),

                      Expanded(
                        child:
                            _ResumenCard(
                          titulo:
                              'Peso total',
                          valor:
                              '${(totalPeso / 1000).toStringAsFixed(2)} t',
                          icono:
                              Icons
                                  .scale,
                          color:
                              Colors.orange,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(
                height: 18,
              ),

              // =================================================
              // BUSCADOR
              // =================================================

              TextField(
                controller:
                    _buscarController,

                decoration:
                    InputDecoration(
                  hintText:
                      'Buscar cliente...',

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
                              onPressed:
                                  () {
                                _buscarController
                                    .clear();
                              },
                            )
                          : null,

                  filled: true,

                  fillColor:
                      Colors.white,

                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      14,
                    ),
                    borderSide:
                        BorderSide.none,
                  ),

                  enabledBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      14,
                    ),
                    borderSide:
                        BorderSide(
                      color: Colors
                          .grey
                          .shade200,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 15,
              ),

              // =================================================
              // CLIENTE SELECCIONADO
              // =================================================

              if (clienteSeleccionado !=
                  null)
                _ClienteSeleccionadoCard(
                  cliente:
                      clienteSeleccionado!,
                  total:
                      total,
                  moneda:
                      moneda,
                  onCerrar:
                      () {
                    setState(() {
                      clienteSeleccionado =
                          null;
                    });
                  },
                ),

              if (clienteSeleccionado !=
                  null)
                const SizedBox(
                  height: 15,
                ),

              // =================================================
              // RESULTADOS
              // =================================================

              Text(
                busqueda.isEmpty
                    ? 'Todos los clientes'
                    : '${clientesFiltrados.length} clientes encontrados',

                style:
                    TextStyle(
                  color: Colors
                      .grey
                      .shade700,

                  fontSize: 13,

                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              // =================================================
              // LISTA
              // =================================================

              clientesFiltrados.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No se encontraron clientes.',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      itemCount:
                          clientesFiltrados.length,
                      itemBuilder: (context, index) {
                        final cliente =
                            clientesFiltrados[index];

                        final porcentaje =
                            total == 0
                                ? 0.0
                                : (cliente.valorStock / total) * 100;

                        final progreso =
                            total == 0
                                ? 0.0
                                : cliente.valorStock / total;

                        return _ClienteItem(
                          numero: index + 1,
                          cliente: cliente,
                          porcentaje: porcentaje,
                          progreso: progreso,
                          moneda: moneda,
                          seleccionado:
                              clienteSeleccionado?.cliente ==
                                  cliente.cliente,
                          onTap: () {
                            setState(() {
                              clienteSeleccionado = cliente;
                            });
                          },
                        );
                      },
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================
// TARJETA RESUMEN GENERAL
// =============================================================

class _ResumenCard
    extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;

  const _ResumenCard({
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.color,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(15),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          15,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withOpacity(
              0.05,
            ),
            blurRadius: 8,
            offset:
                const Offset(
              0,
              3,
            ),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,

            decoration:
                BoxDecoration(
              color:
                  color.withOpacity(
                0.10,
              ),
              shape:
                  BoxShape.circle,
            ),

            child: Icon(
              icono,
              color:
                  color,
              size: 21,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [
                Text(
                  titulo,
                  style:
                      TextStyle(
                    fontSize: 11,
                    color: Colors
                        .grey
                        .shade600,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  valor,
                  overflow:
                      TextOverflow
                          .ellipsis,

                  style:
                      const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.bold,
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

// =============================================================
// CLIENTE SELECCIONADO
// =============================================================

class _ClienteSeleccionadoCard extends StatelessWidget {
  final ClienteTop cliente;
  final double total;
  final NumberFormat moneda;
  final VoidCallback onCerrar;

  const _ClienteSeleccionadoCard({
    required this.cliente,
    required this.total,
    required this.moneda,
    required this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    final porcentaje = total == 0
        ? 0.0
        : (cliente.valorStock / total) * 100;

    final toneladas = cliente.pesoCobre / 1000;

    final progreso = total == 0
        ? 0.0
        : cliente.valorStock / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xffEEF4FF),
            Color(0xffF8FAFF),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xffBFDBFE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // =====================================================
          // CABECERA
          // =====================================================

          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xffDBEAFE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.business,
                  color: Color(0xff2563EB),
                  size: 22,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  cliente.cliente,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              IconButton(
                tooltip: 'Cerrar cliente',
                icon: const Icon(Icons.close),
                onPressed: onCerrar,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // =====================================================
          // RESUMEN DEL CLIENTE
          // =====================================================

          LayoutBuilder(
            builder: (context, constraints) {
              final compacto = constraints.maxWidth < 650;

              if (compacto) {
                return Column(
                  children: [
                    _DatoCliente(
                      titulo: 'Valor Stock',
                      valor: moneda.format(
                        cliente.valorStock,
                      ),
                      color: Colors.green,
                      icono: Icons.attach_money,
                    ),

                    const SizedBox(height: 10),

                    _DatoCliente(
                      titulo: 'Participación',
                      valor:
                          '${porcentaje.toStringAsFixed(1)} %',
                      color: Colors.blue,
                      icono: Icons.percent,
                    ),

                    const SizedBox(height: 10),

                    _DatoCliente(
                      titulo: 'Peso de Cobre',
                      valor:
                          '${toneladas.toStringAsFixed(2)} t',
                      color: Colors.orange,
                      icono: Icons.scale,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _DatoCliente(
                      titulo: 'Valor Stock',
                      valor: moneda.format(
                        cliente.valorStock,
                      ),
                      color: Colors.green,
                      icono: Icons.attach_money,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _DatoCliente(
                      titulo: 'Participación',
                      valor:
                          '${porcentaje.toStringAsFixed(1)} %',
                      color: Colors.blue,
                      icono: Icons.percent,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _DatoCliente(
                      titulo: 'Peso de Cobre',
                      valor:
                          '${toneladas.toStringAsFixed(2)} t',
                      color: Colors.orange,
                      icono: Icons.scale,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // =====================================================
          // BARRA DE PARTICIPACIÓN
          // =====================================================

          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 11,
              backgroundColor:
                  const Color(0xffE5E7EB),
              color: const Color(0xff4056B4),
            ),
          ),

          const SizedBox(height: 12),



// =====================================================
// CLIENTE SELECCIONADO
// =====================================================

const Row(
  children: [
    Icon(
      Icons.check_circle,
      size: 15,
      color: Color(0xff4056B4),
    ),

    SizedBox(width: 6),

    Text(
      'Cliente seleccionado',
      style: TextStyle(
        color: Color(0xff4056B4),
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    ),
  ],
),

const SizedBox(height: 14),

// =====================================================
// ARTÍCULOS DEL CLIENTE
// =====================================================

ProductosClienteSection(
  cliente: cliente.cliente,
),
        ],
      ),
    );
  }
}
// =============================================================
// DATO CLIENTE
// =============================================================

class _DatoCliente extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color color;
  final IconData icono;

  const _DatoCliente({
    required this.titulo,
    required this.valor,
    required this.color,
    required this.icono,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(12),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

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

      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,

            decoration:
                BoxDecoration(
              color:
                  color.withOpacity(
                0.10,
              ),
              shape:
                  BoxShape.circle,
            ),

            child: Icon(
              icono,
              color:
                  color,
              size: 18,
            ),
          ),

          const SizedBox(
            width: 9,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [
                Text(
                  titulo,
                  style:
                      TextStyle(
                    fontSize: 10,
                    color: Colors
                        .grey
                        .shade600,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  valor,
                  overflow:
                      TextOverflow
                          .ellipsis,

                  style:
                      TextStyle(
                    color:
                        color,
                    fontSize: 14,
                    fontWeight:
                        FontWeight.bold,
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

// =============================================================
// ITEM CLIENTE
// =============================================================

class _ClienteItem
    extends StatelessWidget {
  final int numero;
  final ClienteTop cliente;
  final double porcentaje;
  final double progreso;
  final NumberFormat moneda;
  final bool seleccionado;
  final VoidCallback onTap;

  const _ClienteItem({
    required this.numero,
    required this.cliente,
    required this.porcentaje,
    required this.progreso,
    required this.moneda,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final toneladas =
        cliente.pesoCobre / 1000;

    return InkWell(
      onTap: onTap,

      borderRadius:
          BorderRadius.circular(
        14,
      ),

      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 10,
        ),

        padding:
            const EdgeInsets.all(
          14,
        ),

        decoration:
            BoxDecoration(
          color: seleccionado
              ? const Color(
                  0xffEEF4FF,
                )
              : Colors.white,

          borderRadius:
              BorderRadius.circular(
            14,
          ),

          border:
              Border.all(
            color: seleccionado
                ? const Color(
                    0xff60A5FA,
                  )
                : Colors.grey
                    .shade200,
            width:
                seleccionado
                    ? 1.5
                    : 1,
          ),
        ),

        child: Column(
          children: [
            Row(
              children: [
                // ===============================================
                // NUMERO
                // ===============================================

                Container(
                  width: 32,
                  height: 32,

                  alignment:
                      Alignment.center,

                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xff2563EB,
                    ).withOpacity(
                      0.08,
                    ),

                    shape:
                        BoxShape.circle,

                    border:
                        Border.all(
                      color:
                          const Color(
                        0xff2563EB,
                      ).withOpacity(
                        0.35,
                      ),
                    ),
                  ),

                  child: Text(
                    '$numero',

                    style:
                        const TextStyle(
                      color:
                          Color(
                        0xff2563EB,
                      ),

                      fontWeight:
                          FontWeight.bold,

                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                // ===============================================
                // CLIENTE
                // ===============================================

                Expanded(
                  child: Text(
                    cliente.cliente,

                    maxLines: 2,

                    overflow:
                        TextOverflow.ellipsis,

                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w600,

                      fontSize: 14,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                // ===============================================
                // DATOS
                // ===============================================

                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.end,

                  children: [
                    Text(
                      'US\$ ${moneda.format(cliente.valorStock)}',

                      style:
                          const TextStyle(
                        color:
                            Colors.green,

                        fontWeight:
                            FontWeight.bold,

                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      '${porcentaje.toStringAsFixed(1)} %',

                      style:
                          const TextStyle(
                        color:
                            Colors.blue,

                        fontWeight:
                            FontWeight.bold,

                        fontSize: 11,
                      ),
                    ),

                    const SizedBox(
                      height: 2,
                    ),

                    Text(
                      '${toneladas.toStringAsFixed(2)} t',

                      style:
                          const TextStyle(
                        color:
                            Colors.orange,

                        fontWeight:
                            FontWeight.bold,

                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(
              height: 9,
            ),

            // ===============================================
            // BARRA
            // ===============================================

            ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                8,
              ),

              child:
                  LinearProgressIndicator(
                value:
                    progreso,

                minHeight: 10,

                backgroundColor:
                    const Color(
                  0xffE5E7EB,
                ),

                color:
                    const Color(
                  0xff4056B4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}