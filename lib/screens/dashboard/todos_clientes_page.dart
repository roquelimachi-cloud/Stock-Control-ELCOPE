import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/dashboard/cliente_top.dart';

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

  final NumberFormat moneda = NumberFormat(
    '#,##0',
    'en_US',
  );

  @override
  void initState() {
    super.initState();

    _buscarController.addListener(() {
      setState(() {
        busqueda =
            _buscarController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _buscarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todosLosClientes = widget.clientes;

    // =========================================================
    // FILTRAR CLIENTES
    // =========================================================

    final clientesFiltrados =
        todosLosClientes.where((cliente) {
      if (busqueda.isEmpty) {
        return true;
      }

      return cliente.cliente
          .toLowerCase()
          .contains(busqueda);
    }).toList();

    // =========================================================
    // TOTAL GENERAL
    // =========================================================

    final total = todosLosClientes.fold<double>(
      0,
      (suma, cliente) =>
          suma + cliente.valorStock,
    );

    return Scaffold(
      backgroundColor:
          const Color(0xffF5F7FB),

      // =======================================================
      // APP BAR
      // =======================================================

      appBar: AppBar(
        backgroundColor:
            const Color(0xff4056B4),

        foregroundColor: Colors.white,

        elevation: 0,

        title: const Text(
          'Todos los Clientes',
          style: TextStyle(
            fontWeight: FontWeight.bold,
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

      // =======================================================
      // CONTENIDO
      // =======================================================

      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.all(20),

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
                      color:
                          Colors.amber
                              .withOpacity(
                        0.15,
                      ),
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
              // RESUMEN
              // =================================================

              Row(
                children: [

                  Expanded(
                    child: _ResumenCard(
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
                    child: _ResumenCard(
                      titulo:
                          'Valor total',
                      valor:
                          'US\$ ${moneda.format(total)}',
                      icono:
                          Icons.attach_money,
                      color:
                          Colors.green,
                    ),
                  ),
                ],
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
                              onPressed: () {
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
                        BorderRadius.circular(
                      14,
                    ),

                    borderSide:
                        BorderSide.none,
                  ),

                  enabledBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
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
                height: 18,
              ),

              // =================================================
              // CANTIDAD ENCONTRADA
              // =================================================

              Text(
                busqueda.isEmpty
                    ? 'Todos los clientes'
                    : '${clientesFiltrados.length} clientes encontrados',

                style:
                    TextStyle(
                  color:
                      Colors.grey.shade700,

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

              Expanded(
                child:
                    clientesFiltrados.isEmpty
                        ? const Center(
                            child: Text(
                              'No se encontraron clientes.',
                              style:
                                  TextStyle(
                                color:
                                    Colors.grey,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount:
                                clientesFiltrados
                                    .length,

                            itemBuilder:
                                (
                              context,
                              index,
                            ) {
                              final cliente =
                                  clientesFiltrados[
                                      index];

                              final porcentaje =
                                  total == 0
                                      ? 0.0
                                      : (cliente
                                                  .valorStock /
                                              total) *
                                          100;

                              final progreso =
                                  total == 0
                                      ? 0.0
                                      : cliente
                                              .valorStock /
                                          total;

                              return _ClienteItem(
                                numero:
                                    index + 1,

                                cliente:
                                    cliente
                                        .cliente,

                                valor:
                                    cliente
                                        .valorStock,

                                porcentaje:
                                    porcentaje,

                                progreso:
                                    progreso,

                                moneda:
                                    moneda,
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// RESUMEN
// =============================================================

class _ResumenCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(15),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(15),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.05,
            ),
            blurRadius: 8,
            offset:
                const Offset(0, 3),
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
              color: color,
              size: 21,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(
                  titulo,
                  style:
                      TextStyle(
                    fontSize: 11,
                    color:
                        Colors.grey.shade600,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  valor,
                  overflow:
                      TextOverflow.ellipsis,

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
// CLIENTE
// =============================================================

class _ClienteItem extends StatelessWidget {
  final int numero;
  final String cliente;
  final double valor;
  final double porcentaje;
  final double progreso;
  final NumberFormat moneda;

  const _ClienteItem({
    required this.numero,
    required this.cliente,
    required this.valor,
    required this.porcentaje,
    required this.progreso,
    required this.moneda,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),

      padding:
          const EdgeInsets.all(14),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          14,
        ),

        border:
            Border.all(
          color:
              Colors.grey.shade200,
        ),
      ),

      child: Column(
        children: [

          Row(
            children: [

              // =================================================
              // NUMERO
              // =================================================

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

              // =================================================
              // CLIENTE
              // =================================================

              Expanded(
                child: Text(
                  cliente,

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

              // =================================================
              // VALOR + %
              // =================================================

              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,

                children: [

                  Text(
                    'US\$ ${moneda.format(valor)}',

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
                ],
              ),
            ],
          ),

          const SizedBox(
            height: 9,
          ),

          // =================================================
          // BARRA
          // =================================================

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
    );
  }
}