import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/produccion/top_cliente_model.dart';

class TopClientesWidget extends StatelessWidget {
  final List<TopClienteModel> clientes;

  const TopClientesWidget({
    super.key,
    required this.clientes,
  });

  // ==========================================================
  // FORMATO MONEDA
  // ==========================================================

  String _formatearValor(double valor) {
    return NumberFormat(
      '#,##0',
      'en_US',
    ).format(valor);
  }

  // ==========================================================
  // FORMATO PESO
  // ==========================================================

  String _formatearPeso(double peso) {
    return NumberFormat(
      '#,##0.00',
      'en_US',
    ).format(peso);
  }

  // ==========================================================
  // COLOR POR POSICIÓN
  // ==========================================================

  Color _colorPorIndice(int index) {
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

  // ==========================================================
  // MEDALLA
  // ==========================================================

  Widget _ranking(int index) {
    if (index == 0) {
      return const Text(
        '🥇',
        style: TextStyle(fontSize: 19),
      );
    }

    if (index == 1) {
      return const Text(
        '🥈',
        style: TextStyle(fontSize: 19),
      );
    }

    if (index == 2) {
      return const Text(
        '🥉',
        style: TextStyle(fontSize: 19),
      );
    }

    return SizedBox(
      width: 26,
      child: Text(
        '${index + 1}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  // ==========================================================
  // ITEM CLIENTE
  // ==========================================================

  Widget _clienteItem({
    required BuildContext context,
    required TopClienteModel item,
    required int index,
    required double total,
    required double maximo,
  }) {
    final color = _colorPorIndice(index);

    final porcentaje =
        total == 0
            ? 0.0
            : item.valor / total;

    final progreso =
        maximo == 0
            ? 0.0
            : item.valor / maximo;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 18,
      ),
      child: Column(
        children: [
          // ======================================================
          // CLIENTE + VALOR
          // ======================================================

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // --------------------------------------------------
              // RANKING
              // --------------------------------------------------

              SizedBox(
                width: 38,
                child: _ranking(index),
              ),

              const SizedBox(width: 8),

              // --------------------------------------------------
              // CLIENTE
              // --------------------------------------------------

              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.only(
                    top: 3,
                  ),
                  child: Text(
                    item.cliente,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // --------------------------------------------------
              // VALOR + AVANCE + PESO
              // --------------------------------------------------

              SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                    // VALOR NETO
                    Text(
                      'US\$ ${_formatearValor(item.valor)}',
                      textAlign:
                          TextAlign.right,
                      style:
                          const TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    // AVANCE
                    Text(
                      '${(porcentaje * 100).toStringAsFixed(1)} %',
                      textAlign:
                          TextAlign.right,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    // PESO COBRE
                    Text(
                      '${_formatearPeso(item.pesoCobre)} Kg',
                      textAlign:
                          TextAlign.right,
                      style:
                          const TextStyle(
                        color:
                            Colors.black87,
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ======================================================
          // BARRA
          // ======================================================

          Padding(
            padding:
                const EdgeInsets.only(
              left: 46,
            ),
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(30),
              child:
                  LinearProgressIndicator(
                minHeight: 14,
                value: progreso.clamp(
                  0.0,
                  1.0,
                ),
                backgroundColor:
                    Colors.grey.shade300,
                valueColor:
                    AlwaysStoppedAnimation<
                        Color>(
                  color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // VER TODOS
  // ==========================================================

  void _mostrarTodos(
    BuildContext context,
  ) {
    if (clientes.isEmpty) {
      return;
    }

    final total = clientes.fold<double>(
      0,
      (suma, item) =>
          suma + item.valor,
    );

    final maximo =
        clientes.first.valor;

    showDialog(
      context: context,
      builder: (dialogContext) {
        final ancho =
            MediaQuery.of(
          dialogContext,
        ).size.width;

        final alto =
            MediaQuery.of(
          dialogContext,
        ).size.height;

        return Dialog(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              20,
            ),
          ),
          child: SizedBox(
            width:
                ancho > 900
                    ? 850
                    : ancho * .92,
            height:
                alto > 750
                    ? 680
                    : alto * .85,
            child: Padding(
              padding:
                  const EdgeInsets.all(
                22,
              ),
              child: Column(
                children: [
                  // ==============================================
                  // ENCABEZADO
                  // ==============================================

                  Row(
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color:
                            Colors.amber,
                        size: 30,
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      const Expanded(
                        child: Text(
                          'Todos los Clientes',
                          style:
                              TextStyle(
                            fontSize: 22,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ),

                      // ------------------------------------------
                      // IMPRIMIR
                      // ------------------------------------------

                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(
                            dialogContext,
                          ).pop();

                          _imprimirPdf(
                            context,
                          );
                        },
                        icon:
                            const Icon(
                          Icons.print,
                          size: 18,
                        ),
                        label:
                            const Text(
                          'Imprimir',
                        ),
                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              const Color(
                            0xff2855C5,
                          ),
                          foregroundColor:
                              Colors.white,
                          elevation: 0,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              10,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () {
                          Navigator.of(
                            dialogContext,
                          ).pop();
                        },
                        icon:
                            const Icon(
                          Icons.close,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  const Divider(),

                  const SizedBox(
                    height: 10,
                  ),

                  // ==============================================
                  // LISTA
                  // ==============================================

                  Expanded(
                    child:
                        ListView.builder(
                      itemCount:
                          clientes.length,
                      itemBuilder:
                          (context, index) {
                        return _clienteItem(
                          context:
                              context,
                          item:
                              clientes[
                                  index],
                          index:
                              index,
                          total:
                              total,
                          maximo:
                              maximo,
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

  // ==========================================================
  // GENERAR PDF
  // ==========================================================

  Future<void> _imprimirPdf(
    BuildContext context,
  ) async {
    if (clientes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text(
              'No hay clientes para imprimir.',
            ),
          ),
        );
      }

      return;
    }

    try {
      // ========================================================
      // LOGO
      // ========================================================

      pw.MemoryImage? logo;

      try {
        final data =
            await rootBundle.load(
          'assets/images/logo_elcope.png',
        );

        logo = pw.MemoryImage(
          data.buffer.asUint8List(),
        );
      } catch (_) {
        logo = null;
      }

      // ========================================================
      // TOTAL
      // ========================================================

      final total =
          clientes.fold<double>(
        0,
        (suma, item) =>
            suma + item.valor,
      );

      final pesoTotal =
          clientes.fold<double>(
        0,
        (suma, item) =>
            suma + item.pesoCobre,
      );

      final fecha =
          DateFormat(
        'dd/MM/yyyy',
      ).format(
        DateTime.now(),
      );

      final moneda =
          NumberFormat(
        '#,##0',
        'en_US',
      );

      final pesoFormat =
          NumberFormat(
        '#,##0.00',
        'en_US',
      );

      // ========================================================
      // DOCUMENTO
      // ========================================================

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat:
              PdfPageFormat.a4,
          margin:
              const pw.EdgeInsets
                  .fromLTRB(
            28,
            28,
            28,
            35,
          ),

          // ====================================================
          // ENCABEZADO
          // ====================================================

          header: (context) {
            return pw.Column(
              children: [
                pw.Row(
                  crossAxisAlignment:
                      pw.CrossAxisAlignment
                          .center,
                  children: [
                    if (logo != null)
                      pw.Container(
                        width: 65,
                        height: 45,
                        child: pw.Image(
                          logo!,
                          fit:
                              pw.BoxFit
                                  .contain,
                        ),
                      ),

                    pw.SizedBox(
                      width: 12,
                    ),

                    pw.Expanded(
                      child:
                          pw.Column(
                        crossAxisAlignment:
                            pw.CrossAxisAlignment
                                .start,
                        children: [
                          pw.Text(
                            'REPORTE DE PRODUCCIÓN',
                            style:
                                pw.TextStyle(
                              fontSize:
                                  17,
                              fontWeight:
                                  pw.FontWeight
                                      .bold,
                              color:
                                  PdfColors
                                      .blue900,
                            ),
                          ),
                          pw.SizedBox(
                            height: 3,
                          ),
                          pw.Text(
                            'TOP CLIENTES',
                            style:
                                pw.TextStyle(
                              fontSize:
                                  11,
                              fontWeight:
                                  pw.FontWeight
                                      .bold,
                              color:
                                  PdfColors
                                      .grey700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    pw.Text(
                      fecha,
                      style:
                          const pw.TextStyle(
                        fontSize: 9,
                        color:
                            PdfColors.grey600,
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(
                  height: 12,
                ),

                pw.Divider(
                  color:
                      PdfColors.blue800,
                  thickness: 1.5,
                ),
              ],
            );
          },

          // ====================================================
          // CONTENIDO
          // ====================================================

          build: (context) {
            return [
              // -----------------------------------------------
              // RESUMEN
              // -----------------------------------------------

              pw.Container(
                padding:
                    const pw.EdgeInsets
                        .all(
                  12,
                ),
                decoration:
                    pw.BoxDecoration(
                  color:
                      PdfColors.grey100,
                  borderRadius:
                      pw.BorderRadius
                          .circular(
                    8,
                  ),
                  border:
                      pw.Border.all(
                    color:
                        PdfColors.grey300,
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment:
                      pw.MainAxisAlignment
                          .spaceAround,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text(
                          'Clientes',
                          style:
                              const pw.TextStyle(
                            fontSize: 9,
                            color:
                                PdfColors
                                    .grey600,
                          ),
                        ),
                        pw.SizedBox(
                          height: 3,
                        ),
                        pw.Text(
                          '${clientes.length}',
                          style:
                              pw.TextStyle(
                            fontSize: 14,
                            fontWeight:
                                pw.FontWeight
                                    .bold,
                          ),
                        ),
                      ],
                    ),

                    pw.Column(
                      children: [
                        pw.Text(
                          'Valor Neto',
                          style:
                              const pw.TextStyle(
                            fontSize: 9,
                            color:
                                PdfColors
                                    .grey600,
                          ),
                        ),
                        pw.SizedBox(
                          height: 3,
                        ),
                        pw.Text(
                          'US\$ ${moneda.format(total)}',
                          style:
                              pw.TextStyle(
                            fontSize: 14,
                            fontWeight:
                                pw.FontWeight
                                    .bold,
                            color:
                                PdfColors
                                    .green800,
                          ),
                        ),
                      ],
                    ),

                    pw.Column(
                      children: [
                        pw.Text(
                          'Peso Cobre',
                          style:
                              const pw.TextStyle(
                            fontSize: 9,
                            color:
                                PdfColors
                                    .grey600,
                          ),
                        ),
                        pw.SizedBox(
                          height: 3,
                        ),
                        pw.Text(
                          '${pesoFormat.format(pesoTotal)} Kg',
                          style:
                              pw.TextStyle(
                            fontSize: 14,
                            fontWeight:
                                pw.FontWeight
                                    .bold,
                            color:
                                PdfColors
                                    .orange800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(
                height: 18,
              ),

              // -----------------------------------------------
              // TABLA
              // -----------------------------------------------

              pw.Text(
                'DETALLE DE CLIENTES',
                style:
                    pw.TextStyle(
                  fontSize: 11,
                  fontWeight:
                      pw.FontWeight
                          .bold,
                  color:
                      PdfColors.blue900,
                ),
              ),

              pw.SizedBox(
                height: 8,
              ),

              pw.TableHelper.fromTextArray(
                headers: [
                  'N°',
                  'Cliente',
                  'Valor Neto',
                  'Avance',
                  'Peso Cobre',
                ],
                data: List.generate(
                  clientes.length,
                  (index) {
                    final item =
                        clientes[index];

                    final avance =
                        total == 0
                            ? 0.0
                            : item.valor /
                                total *
                                100;

                    return [
                      '${index + 1}',
                      item.cliente,
                      'US\$ ${moneda.format(item.valor)}',
                      '${avance.toStringAsFixed(1)} %',
                      '${pesoFormat.format(item.pesoCobre)} Kg',
                    ];
                  },
                ),
                headerStyle:
                    pw.TextStyle(
                  fontSize: 8,
                  fontWeight:
                      pw.FontWeight.bold,
                  color:
                      PdfColors.white,
                ),
                headerDecoration:
                    const pw.BoxDecoration(
                  color:
                      PdfColors.blue800,
                ),
                cellStyle:
                    const pw.TextStyle(
                  fontSize: 7.5,
                ),
                cellPadding:
                    const pw.EdgeInsets
                        .symmetric(
                  horizontal: 5,
                  vertical: 5,
                ),
                border:
                    pw.TableBorder.all(
                  color:
                      PdfColors.grey300,
                  width: .5,
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(
                    25,
                  ),
                  1: const pw.FlexColumnWidth(
                    3.5,
                  ),
                  2: const pw.FixedColumnWidth(
                    90,
                  ),
                  3: const pw.FixedColumnWidth(
                    55,
                  ),
                  4: const pw.FixedColumnWidth(
                    80,
                  ),
                },
                cellAlignment: pw.Alignment.centerLeft,
              ),

              pw.SizedBox(
                height: 18,
              ),

              // -----------------------------------------------
              // TOTAL
              // -----------------------------------------------

              pw.Align(
                alignment:
                    pw.Alignment.centerRight,
                child: pw.Container(
                  width: 260,
                  padding:
                      const pw.EdgeInsets
                          .all(
                    12,
                  ),
                  decoration:
                      pw.BoxDecoration(
                    border:
                        pw.Border.all(
                      color:
                          PdfColors.blue800,
                    ),
                    borderRadius:
                        pw.BorderRadius
                            .circular(
                      7,
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment
                            .start,
                    children: [
                      pw.Text(
                        'TOTAL',
                        style:
                            pw.TextStyle(
                          fontSize: 11,
                          fontWeight:
                              pw.FontWeight
                                  .bold,
                          color:
                              PdfColors
                                  .blue900,
                        ),
                      ),

                      pw.SizedBox(
                        height: 5,
                      ),

                      pw.Text(
                        'Clientes: ${clientes.length}',
                        style:
                            const pw.TextStyle(
                          fontSize: 9,
                        ),
                      ),

                      pw.Text(
                        'Valor Neto: US\$ ${moneda.format(total)}',
                        style:
                            const pw.TextStyle(
                          fontSize: 9,
                        ),
                      ),

                      pw.Text(
                        'Peso Cobre: ${pesoFormat.format(pesoTotal)} Kg',
                        style:
                            const pw.TextStyle(
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ];
          },

          // ====================================================
          // PIE
          // ====================================================

          footer: (context) {
            return pw.Container(
              alignment:
                  pw.Alignment.center,
              margin:
                  const pw.EdgeInsets
                      .only(
                top: 10,
              ),
              child: pw.Text(
                'Reporte de Producción Pendiente',
                style:
                    const pw.TextStyle(
                  fontSize: 8,
                  color:
                      PdfColors.grey600,
                ),
              ),
            );
          },
        ),
      );

      // ========================================================
      // IMPRIMIR
      // ========================================================

      await Printing.layoutPdf(
        onLayout: (format) async {
          return pdf.save();
        },
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          backgroundColor:
              Colors.red,
          content: Text(
            'Error al generar PDF: $e',
          ),
        ),
      );
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    if (clientes.isEmpty) {
      return Card(
        elevation: 8,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            22,
          ),
        ),
        child: const Center(
          child: Padding(
            padding:
                EdgeInsets.all(30),
            child: Text(
              'No existen clientes.',
            ),
          ),
        ),
      );
    }

    // ========================================================
    // SOLO TOP 10 EN LA TARJETA
    // ========================================================

    final top10 =
        clientes.take(10).toList();

    // ========================================================
    // TOTAL GENERAL
    // ========================================================

    final total =
        clientes.fold<double>(
      0,
      (suma, item) =>
          suma + item.valor,
    );

    // ========================================================
    // MÁXIMO PARA LA BARRA
    // ========================================================

    final maximo =
        clientes.first.valor;

    return Card(
      elevation: 8,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          22,
        ),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // ==================================================
            // ENCABEZADO
            // ==================================================

            Row(
              children: [
                const Icon(
                  Icons.emoji_events,
                  color: Colors.amber,
                  size: 30,
                ),

                const SizedBox(
                  width: 10,
                ),

                const Expanded(
                  child: Text(
                    'Top 10 Clientes',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                // ==============================================
                // VER TODOS
                // ==============================================

                TextButton.icon(
                  onPressed: () {
                    _mostrarTodos(
                      context,
                    );
                  },
                  icon:
                      const Icon(
                    Icons
                        .arrow_forward,
                    size: 18,
                  ),
                  label:
                      const Text(
                    'Ver todos',
                  ),
                  style:
                      TextButton.styleFrom(
                    foregroundColor:
                        const Color(
                      0xff1976D2,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 5,
                ),

                // ==============================================
                // IMPRIMIR
                // ==============================================

                ElevatedButton.icon(
                  onPressed: () {
                    _imprimirPdf(
                      context,
                    );
                  },
                  icon:
                      const Icon(
                    Icons.print,
                    size: 18,
                  ),
                  label:
                      const Text(
                    'Imprimir',
                  ),
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        const Color(
                      0xff2855C5,
                    ),
                    foregroundColor:
                        Colors.white,
                    elevation: 0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        10,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 25,
            ),

            // ==================================================
            // TOP 10
            // ==================================================

            Expanded(
              child:
                  ListView.builder(
                itemCount:
                    top10.length,
                itemBuilder:
                    (context, index) {
                  return _clienteItem(
                    context: context,
                    item:
                        top10[index],
                    index: index,
                    total: total,
                    maximo: maximo,
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