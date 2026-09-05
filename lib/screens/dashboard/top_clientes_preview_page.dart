import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'cliente_stock_preview_page.dart';

import '../../models/dashboard/cliente_top.dart';
import '../../services/pdf/top_clientes_stock_pdf_service.dart';

class TopClientesPreviewPage extends StatelessWidget {
  final List<ClienteTop> clientes;

  const TopClientesPreviewPage({
    super.key,
    required this.clientes,
  });

  // ==========================================================
  // COLORES
  // ==========================================================

  static const Color verdeElcope = Color(0xFF087A45);
  static const Color verdeSuave = Color(0xFFEAF6EF);
  static const Color azulAnalitico = Color(0xFF1565D8);

  // ==========================================================
  // FORMATOS
  // ==========================================================

  String _moneda(double valor) {
    return 'US\$ ${NumberFormat(
      '#,##0.00',
      'en_US',
    ).format(valor)}';
  }

  String _numero(double valor) {
    return NumberFormat(
      '#,##0.00',
      'en_US',
    ).format(valor);
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final data = [...clientes]
      ..sort(
        (a, b) => b.valorStock.compareTo(
          a.valorStock,
        ),
      );

    final totalClientes = data.length;

    final totalValor = data.fold<double>(
      0,
      (suma, cliente) =>
          suma + cliente.valorStock,
    );

    final totalPeso = data.fold<double>(
      0,
      (suma, cliente) =>
          suma + cliente.pesoCobre,
    );

    return Scaffold(
      backgroundColor: Colors.white,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: verdeElcope,
        elevation: 0,

        leading: const BackButton(),

        title: const Text(
          'TOP CLIENTES',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),

        centerTitle: true,

        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: 12,
            ),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: verdeElcope,
                foregroundColor: Colors.white,
              ),

              onPressed: () async {
                final servicio =
                    TopClientesStockPdfService();

                await servicio.imprimirReporte(
                  clientes: data,
                  context: context,
                );
              },

              icon: const Icon(
                Icons.print_outlined,
              ),

              label: const Text(
                'IMPRIMIR',
              ),
            ),
          ),
        ],
      ),

      // ========================================================
      // CONTENIDO
      // ========================================================

      body: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          final movil =
              constraints.maxWidth < 760;

          final tablet =
              constraints.maxWidth >= 760 &&
                  constraints.maxWidth < 1150;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              movil ? 12 : 28,
              8,
              movil ? 12 : 28,
              24,
            ),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,

              children: [
                // ==================================================
                // ENCABEZADO
                // ==================================================

                _cabecera(
                  movil: movil,
                ),

                const SizedBox(
                  height: 18,
                ),

                // ==================================================
                // KPI
                // ==================================================

                _kpis(
                  movil: movil,
                  tablet: tablet,
                  totalClientes: totalClientes,
                  totalValor: totalValor,
                  totalPeso: totalPeso,
                ),

                const SizedBox(
                  height: 18,
                ),

                // ==================================================
                // RANKING
                // ==================================================

                _ranking(
                  context,
                  data,
                  movil,
                ),

                const SizedBox(
                  height: 18,
                ),

                // ==================================================
                // DETALLE
                // ==================================================

                _detalle(
                  data,
                  totalValor,
                  totalPeso,
                  movil,
                ),

                const SizedBox(
                  height: 14,
                ),

                // ==================================================
                // PIE INFORMATIVO
                // ==================================================

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),

                  decoration:
                      const BoxDecoration(
                    color: verdeSuave,
                    border: Border(
                      top: BorderSide(
                        color: verdeElcope,
                        width: 2,
                      ),
                    ),
                  ),

                  child: const Text(
                    'Vista preliminar del reporte Top Clientes.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF075C36),
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // CABECERA
  // ==========================================================

  Widget _cabecera({
    required bool movil,
  }) {
    return Container(
      padding: EdgeInsets.all(
        movil ? 16 : 22,
      ),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(16),

        border: Border.all(
          color: const Color(0xFFD9E2DC),
        ),

        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: movil ? 48 : 58,
            height: movil ? 48 : 58,

            decoration: BoxDecoration(
              color: verdeSuave,
              borderRadius:
                  BorderRadius.circular(14),
            ),

            child: const Icon(
              Icons.emoji_events,
              color: verdeElcope,
              size: 32,
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  'TOP CLIENTES',
                  style: TextStyle(
                    fontSize:
                        movil ? 20 : 25,
                    fontWeight:
                        FontWeight.w900,
                    color: verdeElcope,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  'Ranking de clientes por valor de stock',
                  style: TextStyle(
                    fontSize:
                        movil ? 12 : 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // KPI
  // ==========================================================

  Widget _kpis({
    required bool movil,
    required bool tablet,
    required int totalClientes,
    required double totalValor,
    required double totalPeso,
  }) {
    final cards = [
      _kpiCard(
        icon: Icons.people_alt_outlined,
        titulo: 'CLIENTES',
        valor: totalClientes.toString(),
        color: verdeElcope,
      ),

      _kpiCard(
        icon: Icons.attach_money,
        titulo: 'VALOR TOTAL',
        valor: _moneda(totalValor),
        color: azulAnalitico,
      ),

      _kpiCard(
        icon: Icons.scale_outlined,
        titulo: 'PESO COBRE',
        valor:
            '${_numero(totalPeso / 1000)} t',
        color: Colors.orange,
      ),
    ];

    if (movil) {
      return Column(
        children: [
          cards[0],
          const SizedBox(height: 10),
          cards[1],
          const SizedBox(height: 10),
          cards[2],
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: cards[0],
        ),

        const SizedBox(
          width: 12,
        ),

        Expanded(
          child: cards[1],
        ),

        const SizedBox(
          width: 12,
        ),

        Expanded(
          child: cards[2],
        ),
      ],
    );
  }

  // ==========================================================
  // KPI CARD
  // ==========================================================

  Widget _kpiCard({
    required IconData icon,
    required String titulo,
    required String valor,
    required Color color,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(14),

        border: Border.all(
          color: const Color(0xFFE1E7E3),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,

            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              shape: BoxShape.circle,
            ),

            child: Icon(
              icon,
              color: color,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  valor,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,

                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // RANKING
  // ==========================================================

  Widget _ranking(
    BuildContext context,
    List<ClienteTop> data,
    bool movil,
  ) {
    final top10 = data;

    final maximo =
        top10.isEmpty
            ? 0.0
            : top10.first.valorStock;

    return Container(
      padding:
          const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(16),

        border: Border.all(
          color: const Color(0xFFD9E2DC),
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              const Icon(
                Icons.bar_chart_rounded,
                color: azulAnalitico,
              ),

              const SizedBox(
                width: 8,
              ),

              const Expanded(
                child: Text(
                  'RANKING DE CLIENTES',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 18,
          ),

          if (top10.isEmpty)
            const Center(
              child: Padding(
                padding:
                    EdgeInsets.all(30),
                child: Text(
                  'No existen clientes.',
                ),
              ),
            ),

          for (
            int index = 0;
            index < top10.length;
            index++
          )
            _rankingItem(
              context: context,
              cliente: top10[index],
              index: index,
              maximo: maximo,
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // RANKING ITEM
  // ==========================================================

  Widget _rankingItem({
    required BuildContext context,
    required ClienteTop cliente,
    required int index,
    required double maximo,
  }) {
    final progreso =
        maximo == 0
            ? 0.0
            : cliente.valorStock / maximo;

    final porcentaje =
        maximo == 0
            ? 0.0
            : progreso * 100;

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 14,
      ),

      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        mouseCursor: SystemMouseCursors.click,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClienteStockPreviewPage(
                cliente: cliente,
              ),
            ),
          );
        },
        child: Column(
          children: [
            Row(
            children: [
              Container(
                width: 30,
                height: 30,

                alignment:
                    Alignment.center,

                decoration:
                    const BoxDecoration(
                  color: azulAnalitico,
                  shape: BoxShape.circle,
                ),

                child: Text(
                  '${index + 1}',
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Text(
                  cliente.cliente,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              Text(
                _moneda(
                  cliente.valorStock,
                ),

                style:
                    const TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w900,
                  color: verdeElcope,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 6,
          ),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(8),

            child:
                LinearProgressIndicator(
              value: progreso,
              minHeight: 10,

              backgroundColor:
                  const Color(0xFFE7ECF0),

              color: azulAnalitico,
            ),
          ),

          const SizedBox(
            height: 3,
          ),

          Align(
            alignment:
                Alignment.centerRight,

            child: Text(
              '${porcentaje.toStringAsFixed(1)} % del líder',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.black54,
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // DETALLE
  // ==========================================================

  Widget _detalle(
    List<ClienteTop> data,
    double totalValor,
    double totalPeso,
    bool movil,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(16),

        border: Border.all(
          color: const Color(0xFFD9E2DC),
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              const Icon(
                Icons.table_chart_outlined,
                color: verdeElcope,
              ),

              const SizedBox(
                width: 8,
              ),

              const Expanded(
                child: Text(
                  'DETALLE DE CLIENTES',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          if (movil)
            _detalleMovil(data)
          else
            _detalleDesktop(
              data,
              totalValor,
              totalPeso,
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // DETALLE DESKTOP
  // ==========================================================

  Widget _detalleDesktop(
    List<ClienteTop> data,
    double totalValor,
    double totalPeso,
  ) {
    return SingleChildScrollView(
      scrollDirection:
          Axis.horizontal,

      child: DataTable(
        headingRowColor:
            MaterialStateProperty.all(
          verdeElcope,
        ),

        headingTextStyle:
            const TextStyle(
          color: Colors.white,
          fontWeight:
              FontWeight.w800,
        ),

        columns: const [
          DataColumn(
            label: Text('#'),
          ),

          DataColumn(
            label: Text('Cliente'),
          ),

          DataColumn(
            label: Text('Valor'),
          ),

          DataColumn(
            label: Text('Peso cobre'),
          ),

          DataColumn(
            label: Text('%'),
          ),
        ],

        rows: [
          for (
            int index = 0;
            index < data.length;
            index++
          )
            DataRow(
              cells: [
                DataCell(
                  Text(
                    '${index + 1}',
                  ),
                ),

                DataCell(
                  SizedBox(
                    width: 260,
                    child: Text(
                      data[index].cliente,
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                  ),
                ),

                DataCell(
                  Text(
                    _moneda(
                      data[index]
                          .valorStock,
                    ),
                  ),
                ),

                DataCell(
                  Text(
                    '${_numero(data[index].pesoCobre / 1000)} t',
                  ),
                ),

                DataCell(
                  Text(
                    totalValor == 0
                        ? '0.0 %'
                        : '${((data[index].valorStock / totalValor) * 100).toStringAsFixed(1)} %',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // DETALLE MOVIL
  // ==========================================================

  Widget _detalleMovil(
    List<ClienteTop> data,
  ) {
    return Column(
      children: [
        for (
          int index = 0;
          index < data.length;
          index++
        )
          Container(
            margin:
                const EdgeInsets.only(
              bottom: 8,
            ),

            padding:
                const EdgeInsets.all(12),

            decoration: BoxDecoration(
              color:
                  const Color(0xFFF8FAF9),

              borderRadius:
                  BorderRadius.circular(10),

              border: Border.all(
                color:
                    const Color(
                  0xFFE1E7E3,
                ),
              ),
            ),

            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,

                  alignment:
                      Alignment.center,

                  decoration:
                      const BoxDecoration(
                    color:
                        azulAnalitico,
                    shape:
                        BoxShape.circle,
                  ),

                  child: Text(
                    '${index + 1}',
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w900,
                    ),
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
                        data[index]
                            .cliente,
                        maxLines: 2,
                        overflow:
                            TextOverflow
                                .ellipsis,

                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        '${_numero(data[index].pesoCobre / 1000)} t',
                        style:
                            const TextStyle(
                          fontSize: 11,
                          color:
                              Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                Text(
                  _moneda(
                    data[index]
                        .valorStock,
                  ),

                  style:
                      const TextStyle(
                    color:
                        verdeElcope,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}