import 'package:flutter/material.dart';

import '../../models/produccion/top_cliente_model.dart';
import '../../services/produccion/top_clientes_pdf_service.dart';

class TopClientesWidget extends StatelessWidget {
  final List<TopClienteModel> clientes;

  const TopClientesWidget({
    super.key,
    required this.clientes,
  });

  String _valor(double valor) {
    final valorRedondeado = valor.round();

    return valorRedondeado
        .toString()
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match.group(1)},',
        );
  }

  String _peso(double peso) {
    final partes = peso.toStringAsFixed(2).split('.');

    final entero = partes[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match.group(1)},',
    );

    return '$entero.${partes[1]}';
  }

  Color _color(int index) {
    return switch (index) {
      0 => const Color(0xff00E676),
      1 => const Color(0xff00B0FF),
      2 => const Color(0xffFF9100),
      3 => const Color(0xffD500F9),
      4 => const Color(0xffFF1744),
      5 => const Color(0xff00E5FF),
      6 => const Color(0xff76FF03),
      7 => const Color(0xffFFD600),
      8 => const Color(0xffFF4081),
      _ => const Color(0xff7C4DFF),
    };
  }

  Widget _ranking(int index) {
    if (index == 0) {
      return const Text(
        '🥇',
        style: TextStyle(fontSize: 20),
      );
    }

    if (index == 1) {
      return const Text(
        '🥈',
        style: TextStyle(fontSize: 20),
      );
    }

    if (index == 2) {
      return const Text(
        '🥉',
        style: TextStyle(fontSize: 20),
      );
    }

    return Text(
      '${index + 1}',
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _item({
    required TopClienteModel item,
    required int index,
    required double total,
    required double maximo,
    required bool mobile,
  }) {
    final color = _color(index);

    final porcentaje = total == 0
        ? 0.0
        : item.valor / total;

    final progreso = maximo == 0
        ? 0.0
        : item.valor / maximo;

    final double metricWidth = mobile ? 128 : 155;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: mobile ? 34 : 38,
                child: _ranking(index),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    item.cliente,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: mobile ? 14 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              SizedBox(
                width: metricWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'US\$ ${_valor(item.valor)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: mobile ? 13 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(porcentaje * 100).toStringAsFixed(1)} %',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_peso(item.pesoCobre)} Kg',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Padding(
            padding: EdgeInsets.only(
              left: mobile ? 42 : 46,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: LinearProgressIndicator(
                minHeight: mobile ? 12 : 14,
                value: progreso.clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade300,
                valueColor:
                    AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _verTodos(BuildContext context) {
    if (clientes.isEmpty) return;

    final total = clientes.fold<double>(
      0,
      (suma, item) => suma + item.valor,
    );

    final maximo = clientes.first.valor;

    final size = MediaQuery.sizeOf(context);
    final mobile = size.width < 650;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: EdgeInsets.all(
            mobile ? 10 : 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SizedBox(
            width: mobile
                ? size.width - 20
                : 900,
            height: mobile
                ? size.height - 80
                : 700,
            child: Padding(
              padding: EdgeInsets.all(
                mobile ? 14 : 22,
              ),
              child: Column(
                children: [
                  if (mobile)
                    Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.emoji_events,
                              color: Colors.amber,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Todos los Clientes',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Cerrar',
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _imprimir(dialogContext);
                            },
                            icon: const Icon(
                              Icons.print,
                              size: 18,
                            ),
                            label: const Text(
                              'Imprimir',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xff2855C5),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Colors.amber,
                          size: 30,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Todos los Clientes',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            _imprimir(dialogContext);
                          },
                          icon: const Icon(
                            Icons.print,
                            size: 18,
                          ),
                          label: const Text('Imprimir'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xff2855C5),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Cerrar',
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),

                  const Divider(),
                  const SizedBox(height: 8),

                  Expanded(
                    child: ListView.builder(
                      itemCount: clientes.length,
                      itemBuilder: (context, index) {
                        return _item(
                          item: clientes[index],
                          index: index,
                          total: total,
                          maximo: maximo,
                          mobile: mobile,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _imprimir(BuildContext context) async {
    if (clientes.isEmpty) return;

    final TopClientesPdfService servicio =
        TopClientesPdfService();

    await servicio.imprimirReporte(
      clientes: clientes,
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (clientes.isEmpty) {
      return Card(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Text('No existen clientes.'),
          ),
        ),
      );
    }

    final size = MediaQuery.sizeOf(context);
    final mobile = size.width < 650;

    final top10 = clientes.take(10).toList();

    final total = clientes.fold<double>(
      0,
      (suma, item) => suma + item.valor,
    );

    final maximo = clientes.first.valor;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: EdgeInsets.all(
          mobile ? 14 : 22,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ====================================================
            // CABECERA RESPONSIVE
            // ====================================================

            if (mobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: Colors.amber,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Top 10 Clientes',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () {
                            _verTodos(context);
                          },
                          icon: const Icon(
                            Icons.visibility,
                            size: 18,
                          ),
                          label: const Text(
                            'Ver todos',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _imprimir(context);
                          },
                          icon: const Icon(
                            Icons.print,
                            size: 18,
                          ),
                          label: const Text(
                            'Imprimir',
                            overflow: TextOverflow.ellipsis,
                          ),
                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xff2855C5),
                            foregroundColor:
                                Colors.white,
                            elevation: 0,
                            padding:
                                const EdgeInsets.symmetric(
                              vertical: 11,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: Colors.amber,
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Top 10 Clientes',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      _verTodos(context);
                    },
                    icon: const Icon(
                      Icons.visibility,
                      size: 18,
                    ),
                    label: const Text('Ver todos'),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    onPressed: () {
                      _imprimir(context);
                    },
                    icon: const Icon(
                      Icons.print,
                      size: 18,
                    ),
                    label: const Text('Imprimir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xff2855C5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 20),

            Expanded(
              child: ListView.builder(
                itemCount: top10.length,
                itemBuilder: (context, index) {
                  return _item(
                    item: top10[index],
                    index: index,
                    total: total,
                    maximo: maximo,
                    mobile: mobile,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
