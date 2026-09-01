import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/produccion/produccion_model.dart';

class MisProduccionesPdfService {
  // ==========================================================
  // COLORES ELCOPE
  // ==========================================================

  static const PdfColor verdeElcope =
      PdfColor.fromInt(0xFF007A45);

  static const PdfColor verdeOscuro =
      PdfColor.fromInt(0xFF005C35);

  static const PdfColor verdeClaro =
      PdfColor.fromInt(0xFFEAF7F0);

  static const PdfColor grisLinea =
      PdfColor.fromInt(0xFFD9E1DC);

  static const PdfColor grisTexto =
      PdfColor.fromInt(0xFF374151);

  // ==========================================================
  // GENERAR PDF
  // ==========================================================

  Future<Uint8List> generar({
    required List<ProduccionModel> producciones,
  }) async {
    final pdf = pw.Document();

    // ========================================================
    // LOGO
    // ========================================================

    pw.MemoryImage? logo;

    try {
      final bytes = await rootBundle.load(
        'assets/images/logo_elcope.png',
      );

      logo = pw.MemoryImage(
        bytes.buffer.asUint8List(),
      );
    } catch (_) {
      logo = null;
    }

    // ========================================================
    // FORMATOS
    // ========================================================

    final formatoMoneda =
        NumberFormat("#,##0.00", "en_US");

    final formatoNumero =
        NumberFormat("#,##0.00", "en_US");

    final formatoFecha =
        DateFormat("dd/MM/yyyy");

    final ahora = DateTime.now();

    // ========================================================
    // TOTALES
    // ========================================================

    final int totalProducciones =
        producciones.length;

    final double valorNeto =
        producciones.fold<double>(
      0,
      (suma, item) =>
          suma + (item.valorNeto ?? 0),
    );

    final double pesoCobre =
        producciones.fold<double>(
      0,
      (suma, item) =>
          suma + (item.pesoCobre ?? 0),
    );

    final double cantidad =
        producciones.fold<double>(
      0,
      (suma, item) =>
          suma + (item.cantidadTotal ?? 0),
    );

    final double promedioRetraso =
        producciones.isEmpty
            ? 0
            : producciones.fold<double>(
                  0,
                  (suma, item) =>
                      suma +
                      (item.diasRetraso ?? 0),
                ) /
                producciones.length;

    final int clientes =
        producciones
            .map(
              (e) => e.cliente.trim(),
            )
            .where(
              (e) => e.isNotEmpty,
            )
            .toSet()
            .length;

    // ========================================================
    // CLIENTES TOP 10
    // ========================================================

    final Map<String, double> clientesMapa = {};

    for (final item in producciones) {
      final cliente =
          item.cliente.trim();

      if (cliente.isEmpty) continue;

      clientesMapa.update(
        cliente,
        (valor) =>
            valor + (item.valorNeto ?? 0),
        ifAbsent: () =>
            item.valorNeto ?? 0,
      );
    }

    final clientesOrdenados =
        clientesMapa.entries.toList()
          ..sort(
            (a, b) =>
                b.value.compareTo(a.value),
          );

    final top10 =
        clientesOrdenados.take(10).toList();

    // ========================================================
    // AGREGAR PÁGINAS
    // ========================================================

    pdf.addPage(
      pw.MultiPage(
        pageFormat:
            PdfPageFormat.a4.landscape,

        margin: const pw.EdgeInsets.fromLTRB(
          25,
          20,
          25,
          25,
        ),

        header: (context) {
          return _crearEncabezado(
            logo: logo,
            fecha: formatoFecha.format(ahora),
            hora: DateFormat(
              "hh:mm a",
            ).format(ahora),
          );
        },

        footer: (context) {
          return _crearPie(
            context,
          );
        },

        build: (context) {
          return [
            // ==================================================
            // RESUMEN
            // ==================================================

            _crearResumen(
              totalProducciones:
                  totalProducciones,
              valorNeto:
                  valorNeto,
              pesoCobre:
                  pesoCobre,
              cantidad:
                  cantidad,
              promedioRetraso:
                  promedioRetraso,
              clientes:
                  clientes,
              formatoMoneda:
                  formatoMoneda,
              formatoNumero:
                  formatoNumero,
            ),

            pw.SizedBox(height: 18),

            // ==================================================
            // DETALLE
            // ==================================================

            pw.Text(
              "DETALLE DE PRODUCCIONES",
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight:
                    pw.FontWeight.bold,
                color: verdeOscuro,
              ),
            ),

            pw.SizedBox(height: 8),

            _crearTabla(
              producciones:
                  producciones,
              formatoMoneda:
                  formatoMoneda,
              formatoNumero:
                  formatoNumero,
              formatoFecha:
                  formatoFecha,
            ),

            pw.SizedBox(height: 20),

            // ==================================================
            // DISTRIBUCIÓN + RESUMEN
            // ==================================================

            pw.Row(
              crossAxisAlignment:
                  pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 6,
                  child:
                      _crearDistribucion(
                    top10: top10,
                    total:
                        valorNeto,
                    formatoMoneda:
                        formatoMoneda,
                  ),
                ),

                pw.SizedBox(width: 18),

                pw.Expanded(
                  flex: 4,
                  child:
                      _crearResumenGeneral(
                    totalProducciones:
                        totalProducciones,
                    valorNeto:
                        valorNeto,
                    pesoCobre:
                        pesoCobre,
                    cantidad:
                        cantidad,
                    promedioRetraso:
                        promedioRetraso,
                    clientes:
                        clientes,
                    formatoMoneda:
                        formatoMoneda,
                    formatoNumero:
                        formatoNumero,
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ==========================================================
  // ENCABEZADO
  // ==========================================================

  pw.Widget _crearEncabezado({
    required pw.MemoryImage? logo,
    required String fecha,
    required String hora,
  }) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment:
              pw.CrossAxisAlignment.center,
          children: [
            if (logo != null)
              pw.Container(
                width: 105,
                height: 60,
                alignment:
                    pw.Alignment.centerLeft,
                child: pw.Image(
                  logo,
                  fit: pw.BoxFit.contain,
                ),
              )
            else
              pw.SizedBox(width: 105),

            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Text(
                    "REPORTE DE PRODUCCIÓN",
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight:
                          pw.FontWeight.bold,
                      color: verdeOscuro,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    "MIS PRODUCCIONES",
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight:
                          pw.FontWeight.bold,
                      color: verdeElcope,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(
              width: 145,
              child: pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Fecha: $fecha",
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: grisTexto,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    "Hora: $hora",
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: grisTexto,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    "Reporte: RP-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}",
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: grisTexto,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 8),

        pw.Row(
          children: [
            pw.Container(
              width: 55,
              height: 4,
              color: PdfColors.orange,
            ),
            pw.Expanded(
              child: pw.Container(
                height: 4,
                color: verdeElcope,
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 12),
      ],
    );
  }

  // ==========================================================
  // RESUMEN SUPERIOR
  // ==========================================================

  pw.Widget _crearResumen({
    required int totalProducciones,
    required double valorNeto,
    required double pesoCobre,
    required double cantidad,
    required double promedioRetraso,
    required int clientes,
    required NumberFormat formatoMoneda,
    required NumberFormat formatoNumero,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: grisLinea,
          width: 0.7,
        ),
        borderRadius:
            pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          _kpi(
            titulo: "PRODUCCIONES",
            valor:
                NumberFormat("#,##0", "en_US")
                    .format(
              totalProducciones,
            ),
            color: verdeElcope,
          ),
          _kpi(
            titulo: "VALOR NETO TOTAL",
            valor:
                "US\$ ${formatoMoneda.format(valorNeto)}",
            color: PdfColors.blue,
          ),
          _kpi(
            titulo: "PESO COBRE TOTAL",
            valor:
                "${formatoNumero.format(pesoCobre)} Kg",
            color: PdfColors.orange,
          ),
          _kpi(
            titulo: "CANTIDAD TOTAL",
            valor:
                formatoNumero.format(cantidad),
            color: verdeElcope,
          ),
          _kpi(
            titulo: "PROMEDIO RETRASO",
            valor:
                "${promedioRetraso.toStringAsFixed(0)} días",
            color: PdfColors.teal,
          ),
        ],
      ),
    );
  }

  pw.Widget _kpi({
    required String titulo,
    required String valor,
    required PdfColor color,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            right: pw.BorderSide(
              color: grisLinea,
              width: 0.5,
            ),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment:
              pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              titulo,
              style: pw.TextStyle(
                fontSize: 7,
                fontWeight:
                    pw.FontWeight.bold,
                color: grisTexto,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              valor,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight:
                    pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // TABLA
  // ==========================================================

  pw.Widget _crearTabla({
    required List<ProduccionModel> producciones,
    required NumberFormat formatoMoneda,
    required NumberFormat formatoNumero,
    required DateFormat formatoFecha,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(
        color: grisLinea,
        width: 0.45,
      ),

    columnWidths: {
  0: const pw.FixedColumnWidth(24),   // N°
  1: const pw.FlexColumnWidth(1.5),   // OP
  2: const pw.FlexColumnWidth(2.3),   // CLIENTE
  3: const pw.FlexColumnWidth(3.5),   // ARTÍCULO
  4: const pw.FlexColumnWidth(1.3),   // FECHA
  5: const pw.FlexColumnWidth(1.8),   // VENDEDOR
  6: const pw.FixedColumnWidth(45),   // RETRASO
  7: const pw.FixedColumnWidth(55),   // CANTIDAD
  8: const pw.FlexColumnWidth(1.5),   // VALOR
  9: const pw.FlexColumnWidth(1.5),   // COBRE
},
      children: [
        pw.TableRow(
          repeat: true,
          decoration:
              const pw.BoxDecoration(
            color: verdeElcope,
          ),
          children: [
          _header("N°"),
_header("OP"),
_header("CLIENTE"),
_header("ARTÍCULO"),
_header("FECHA PROD."),
_header("VENDEDOR"),
_header("RETRASO"),
_header("CANTIDAD"),
_header("VALOR NETO"),
_header("PESO COBRE"),
          ],
        ),

        ...List.generate(
          producciones.length,
          (index) {
            final item =
                producciones[index];

            final fecha =
                item.fechaProduccion == null
                    ? "-"
                    : formatoFecha.format(
                        item.fechaProduccion!,
                      );

            return pw.TableRow(
              decoration:
                  pw.BoxDecoration(
                color: index.isEven
                    ? PdfColors.white
                    : verdeClaro,
              ),
              children: [
                _celda(
                  "${index + 1}",
                  align:
                      pw.TextAlign.center,
                ),

                _celda(
                  item.numeroProduccion,
                ),

                _celda(
                  item.cliente,
                ),

                _celda(
                  item.articulo ?? "",
                ),

               _celda(
  fecha,
  align: pw.TextAlign.center,
),

_celda(
  item.representante ?? "-",
  align: pw.TextAlign.left,
),

_celda(
  "${item.diasRetraso ?? 0}",
  align: pw.TextAlign.center,
),

                _celda(
                  formatoNumero.format(
                    item.cantidadTotal ?? 0,
                  ),
                  align:
                      pw.TextAlign.right,
                ),

                _celda(
                  "US\$ ${formatoMoneda.format(item.valorNeto ?? 0)}",
                  align:
                      pw.TextAlign.right,
                ),

                _celda(
                  "${formatoNumero.format(item.pesoCobre ?? 0)} Kg",
                  align:
                      pw.TextAlign.right,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  pw.Widget _header(String texto) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 6,
      ),
      alignment: pw.Alignment.center,
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 7,
          fontWeight:
              pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _celda(
    String texto, {
    pw.TextAlign align =
        pw.TextAlign.left,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 5,
      ),
      child: pw.Text(
        texto,
        textAlign: align,
        style: const pw.TextStyle(
          fontSize: 6.5,
          color: grisTexto,
        ),
      ),
    );
  }

  // ==========================================================
  // DISTRIBUCIÓN
  // ==========================================================

  pw.Widget _crearDistribucion({
    required List<MapEntry<String, double>>
        top10,
    required double total,
    required NumberFormat formatoMoneda,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: grisLinea,
        ),
        borderRadius:
            pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "DISTRIBUCIÓN POR CLIENTES - TOP 10",
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight:
                  pw.FontWeight.bold,
              color: verdeOscuro,
            ),
          ),

          pw.SizedBox(height: 8),

          ...List.generate(
            top10.length,
            (index) {
              final item =
                  top10[index];

              final porcentaje =
                  total == 0
                      ? 0
                      : item.value /
                          total *
                          100;

              return pw.Padding(
                padding:
                    const pw.EdgeInsets.only(
                  bottom: 5,
                ),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 8,
                      height: 8,
                      color:
                          _colorCliente(
                        index,
                      ),
                    ),

                    pw.SizedBox(width: 5),

                    pw.Expanded(
                      child: pw.Text(
                        item.key,
                        maxLines: 1,
                        style:
                            const pw.TextStyle(
                          fontSize: 6.5,
                        ),
                      ),
                    ),

                    pw.Text(
                      "${porcentaje.toStringAsFixed(1)} %",
                      style: pw.TextStyle(
                        fontSize: 6.5,
                        fontWeight:
                            pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  PdfColor _colorCliente(int index) {
    const colores = [
      PdfColors.green,
      PdfColors.blue,
      PdfColors.orange,
      PdfColors.purple,
      PdfColors.red,
      PdfColors.cyan,
      PdfColors.lime,
      PdfColors.amber,
      PdfColors.pink,
      PdfColors.indigo,
    ];

    return colores[
        index % colores.length];
  }

  // ==========================================================
  // RESUMEN GENERAL
  // ==========================================================

  pw.Widget _crearResumenGeneral({
    required int totalProducciones,
    required double valorNeto,
    required double pesoCobre,
    required double cantidad,
    required double promedioRetraso,
    required int clientes,
    required NumberFormat formatoMoneda,
    required NumberFormat formatoNumero,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: verdeElcope,
          width: 1,
        ),
        borderRadius:
            pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "RESUMEN GENERAL",
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight:
                  pw.FontWeight.bold,
              color: verdeOscuro,
            ),
          ),

          pw.SizedBox(height: 10),

          _resumenLinea(
            "Producciones",
            NumberFormat(
              "#,##0",
              "en_US",
            ).format(
              totalProducciones,
            ),
          ),

          _resumenLinea(
            "Clientes atendidos",
            NumberFormat(
              "#,##0",
              "en_US",
            ).format(clientes),
          ),

          _resumenLinea(
            "Cantidad Total",
            formatoNumero.format(
              cantidad,
            ),
          ),

          _resumenLinea(
            "Valor Neto Total",
            "US\$ ${formatoMoneda.format(valorNeto)}",
          ),

          _resumenLinea(
            "Peso Cobre Total",
            "${formatoNumero.format(pesoCobre)} Kg",
          ),

          _resumenLinea(
            "Promedio Retraso",
            "${promedioRetraso.toStringAsFixed(0)} días",
          ),
        ],
      ),
    );
  }

  pw.Widget _resumenLinea(
    String titulo,
    String valor,
  ) {
    return pw.Container(
      padding:
          const pw.EdgeInsets.symmetric(
        vertical: 5,
      ),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: grisLinea,
            width: 0.5,
          ),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment:
            pw.MainAxisAlignment
                .spaceBetween,
        children: [
          pw.Text(
            titulo,
            style: const pw.TextStyle(
              fontSize: 7,
            ),
          ),
          pw.Text(
            valor,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight:
                  pw.FontWeight.bold,
              color: verdeOscuro,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // PIE
  // ==========================================================

  pw.Widget _crearPie(
    pw.Context context,
  ) {
    return pw.Container(
      padding:
          const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            color: verdeElcope,
            width: 1.5,
          ),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment:
            pw.MainAxisAlignment
                .spaceBetween,
        children: [
          pw.Text(
            "ELCOPE - Reporte de Producción",
            style: const pw.TextStyle(
              fontSize: 7,
              color: grisTexto,
            ),
          ),
          pw.Text(
            "Página ${context.pageNumber} de ${context.pagesCount}",
            style: const pw.TextStyle(
              fontSize: 7,
              color: grisTexto,
            ),
          ),
        ],
      ),
    );
  }
}