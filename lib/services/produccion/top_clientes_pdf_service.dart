import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/produccion/top_cliente_model.dart';

class TopClientesPdfService {
  // ==========================================================
  // COLORES CORPORATIVOS ELCOPE
  // ==========================================================

  static const PdfColor verdeElcope =
      PdfColor.fromInt(0xFF087A45);

  static const PdfColor verdeOscuro =
      PdfColor.fromInt(0xFF075C36);

  static const PdfColor verdeClaro =
      PdfColor.fromInt(0xFF18A85B);

  static const PdfColor verdeSuave =
      PdfColor.fromInt(0xFFEAF6EF);

  static const PdfColor azulApoyo =
      PdfColor.fromInt(0xFF123F7A);

  static const PdfColor naranja =
      PdfColor.fromInt(0xFFF58220);

  static const PdfColor grisLinea =
      PdfColor.fromInt(0xFFD9E2DC);

  static const PdfColor grisFondo =
      PdfColor.fromInt(0xFFF7FAF8);

  // ==========================================================
  // IMPRIMIR REPORTE
  // ==========================================================

  Future<void> imprimirReporte({
    required List<TopClienteModel> clientes,
    required BuildContext context,
  }) async {
    if (clientes.isEmpty) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No existen clientes para generar el reporte.',
          ),
        ),
      );

      return;
    }

    try {
      // ========================================================
      // FUENTES
      // ========================================================

      final pw.Font fuenteNormal =
          await PdfGoogleFonts.notoSansRegular();

      final pw.Font fuenteNegrita =
          await PdfGoogleFonts.notoSansBold();

      // ========================================================
      // LOGO
      // ========================================================

      pw.MemoryImage? logo;

      try {
        final ByteData data = await rootBundle.load(
          'assets/images/logo_elcope.png',
        );

        logo = pw.MemoryImage(
          data.buffer.asUint8List(),
        );
      } catch (e) {
        debugPrint(
          'No se pudo cargar el logo ELCOPE: $e',
        );
      }

      // ========================================================
      // FORMATOS
      // ========================================================

      final NumberFormat moneda =
          NumberFormat('#,##0', 'en_US');

      final NumberFormat peso =
          NumberFormat('#,##0.00', 'en_US');

      final DateTime ahora = DateTime.now();

      final String fecha =
          DateFormat('dd/MM/yyyy').format(ahora);

      final String hora =
          DateFormat('hh:mm a').format(ahora);

      final String numeroReporte =
          'RP-${DateFormat('yyyyMMdd-HHmm').format(ahora)}';

      // ========================================================
      // TOTALES
      // ========================================================

      final double totalValor =
          clientes.fold<double>(
        0.0,
        (double suma, TopClienteModel item) {
          return suma + item.valor;
        },
      );

      final double totalPeso =
          clientes.fold<double>(
        0.0,
        (double suma, TopClienteModel item) {
          return suma + item.pesoCobre;
        },
      );

      // ========================================================
      // DATOS ADICIONALES SOLO PARA EL REPORTE IMPRESO
      // ========================================================
      // El TopClienteModel actual contiene cliente, valor y peso.
      // Para no modificar la pantalla ni el modelo, la impresión
      // consulta aquí Representante y FechaProd directamente.

      final Map<String, Map<String, String>> datosReporte = {};

      try {
        final nombresClientes = clientes
            .map((e) => e.cliente.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();

        if (nombresClientes.isNotEmpty) {
          final respuesta = await Supabase.instance.client
              .from('produccion_pendiente')
              .select('cliente, representante, fecha_produccion')
              .inFilter('cliente', nombresClientes);

          final Map<String, Set<String>> representantes = {};
          final Map<String, Set<String>> fechasProduccion = {};

          for (final registro in (respuesta as List)) {
            final clienteRegistro =
                registro['cliente']?.toString().trim() ?? '';

            if (clienteRegistro.isEmpty) continue;

            final representante =
                registro['representante']?.toString().trim() ?? '';

            final fechaProduccion =
                registro['fecha_produccion']?.toString().trim() ?? '';

            representantes.putIfAbsent(
              clienteRegistro,
              () => <String>{},
            );

            fechasProduccion.putIfAbsent(
              clienteRegistro,
              () => <String>{},
            );

            if (representante.isNotEmpty) {
              representantes[clienteRegistro]!.add(representante);
            }

            if (fechaProduccion.isNotEmpty) {
              final fecha = DateTime.tryParse(fechaProduccion);

              if (fecha != null) {
                fechasProduccion[clienteRegistro]!.add(
                  DateFormat('dd/MM/yyyy').format(fecha),
                );
              } else {
                fechasProduccion[clienteRegistro]!.add(
                  fechaProduccion,
                );
              }
            }
          }

          for (final cliente in nombresClientes) {
            final reps = representantes[cliente] ?? <String>{};
            final fechas = fechasProduccion[cliente] ?? <String>{};

            // Si un cliente tiene varias OP, puede tener varias fechas
            // de producción. Antes se mostraba simplemente "Varias",
            // ocultando las fechas reales. Ahora mostramos las fechas
            // distintas disponibles, ordenadas cronológicamente.
            final fechasOrdenadas = fechas.toList()..sort((a, b) {
              DateTime convertirFecha(String texto) {
                final partes = texto.split('/');
                if (partes.length == 3) {
                  return DateTime(
                    int.tryParse(partes[2]) ?? 2100,
                    int.tryParse(partes[1]) ?? 1,
                    int.tryParse(partes[0]) ?? 1,
                  );
                }
                return DateTime(2100);
              }

              return convertirFecha(a).compareTo(convertirFecha(b));
            });

            final representantesOrdenados = reps.toList()..sort();

            datosReporte[cliente] = {
              'representante': representantesOrdenados.isEmpty
                  ? '-'
                  : representantesOrdenados.join('\n'),
              'fechaProduccion': fechasOrdenadas.isEmpty
                  ? '-'
                  : fechasOrdenadas.join('\n'),
            };
          }
        }
      } catch (e) {
        debugPrint(
          'No se pudieron cargar Representante/FechaProd para el PDF: $e',
        );

        for (final cliente in clientes) {
          datosReporte[cliente.cliente.trim()] = {
            'representante': '-',
            'fechaProduccion': '-',
          };
        }
      }

      // ========================================================
      // PDF
      // ========================================================

      final pw.Document pdf = pw.Document(
        title: 'Reporte de Producción - Top Clientes',
        author: 'ELCOPE',
      );

      // ========================================================
      // PÁGINAS
      // ========================================================

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,

          margin: const pw.EdgeInsets.fromLTRB(
            24,
            18,
            24,
            25,
          ),

          theme: pw.ThemeData.withFont(
            base: fuenteNormal,
            bold: fuenteNegrita,
          ),

          // ====================================================
          // ENCABEZADO
          // ====================================================

          header: (pw.Context context) {
            return pw.Column(
              children: [
                pw.SizedBox(
                  height: 76,
                  child: pw.Row(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment.center,
                    children: [
                      // ==========================================
                      // LOGO
                      // ==========================================

                      pw.SizedBox(
                        width: 145,
                        height: 70,
                        child: logo != null
                            ? pw.Image(
                                logo,
                                fit: pw.BoxFit.contain,
                              )
                            : pw.Text(
                                'ELCOPE',
                                style: pw.TextStyle(
                                  font: fuenteNegrita,
                                  fontSize: 23,
                                  color: verdeElcope,
                                ),
                              ),
                      ),

                      // ==========================================
                      // TITULO CENTRAL
                      // ==========================================

                      pw.Expanded(
                        child: pw.Column(
                          mainAxisAlignment:
                              pw.MainAxisAlignment.center,
                          children: [
                            pw.Text(
                              'REPORTE DE PRODUCCIÓN',
                              textAlign:
                                  pw.TextAlign.center,
                              style: pw.TextStyle(
                                font: fuenteNegrita,
                                fontSize: 20,
                                color: verdeOscuro,
                              ),
                            ),

                            pw.SizedBox(height: 3),

                            pw.Text(
                              'TOP CLIENTES',
                              textAlign:
                                  pw.TextAlign.center,
                              style: pw.TextStyle(
                                font: fuenteNormal,
                                fontSize: 11,
                                color: verdeElcope,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ==========================================
                      // INFORMACIÓN DEL REPORTE
                      // ==========================================

                      pw.SizedBox(
                        width: 125,
                        child: pw.Column(
                          crossAxisAlignment:
                              pw.CrossAxisAlignment.start,
                          mainAxisAlignment:
                              pw.MainAxisAlignment.center,
                          children: [
                            _datoHeader(
                              'Fecha:',
                              fecha,
                              fuenteNormal,
                              fuenteNegrita,
                            ),

                            pw.SizedBox(height: 5),

                            _datoHeader(
                              'Hora:',
                              hora,
                              fuenteNormal,
                              fuenteNegrita,
                            ),

                            pw.SizedBox(height: 5),

                            _datoHeader(
                              'Reporte N°:',
                              numeroReporte,
                              fuenteNormal,
                              fuenteNegrita,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ================================================
                // LINEA CORPORATIVA
                // ================================================

                pw.Row(
                  children: [
                    pw.Container(
                      width: 50,
                      height: 4,
                      color: naranja,
                    ),

                    pw.Expanded(
                      child: pw.Container(
                        height: 4,
                        color: verdeElcope,
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 14),
              ],
            );
          },

          // ====================================================
          // PIE DE PAGINA
          // ====================================================

          footer: (pw.Context context) {
            return pw.Container(
              padding:
                  const pw.EdgeInsets.only(top: 7),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(
                    color: grisLinea,
                    width: .5,
                  ),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'ELCOPE - Reporte de Producción',
                    style: pw.TextStyle(
                      font: fuenteNormal,
                      fontSize: 6.5,
                      color: PdfColors.grey600,
                    ),
                  ),

                  pw.Text(
                    'Página ${context.pageNumber}',
                    style: pw.TextStyle(
                      font: fuenteNormal,
                      fontSize: 6.5,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            );
          },

          // ====================================================
          // CONTENIDO
          // ====================================================

          build: (pw.Context context) {
            return [
              // ================================================
              // INDICADORES
              // ================================================

              _indicadores(
                cantidad: clientes.length,
                totalValor: totalValor,
                totalPeso: totalPeso,
                moneda: moneda,
                peso: peso,
                fuenteNormal: fuenteNormal,
                fuenteNegrita: fuenteNegrita,
              ),

              pw.SizedBox(height: 16),

              // ================================================
              // TITULO
              // ================================================

              pw.Text(
                'DETALLE DE CLIENTES',
                style: pw.TextStyle(
                  font: fuenteNegrita,
                  fontSize: 11,
                  color: verdeOscuro,
                ),
              ),

              pw.SizedBox(height: 6),

              // ================================================
              // TABLA
              // ================================================

              _tablaClientes(
                clientes: clientes,
                totalValor: totalValor,
                moneda: moneda,
                peso: peso,
                datosReporte: datosReporte,
                fuenteNormal: fuenteNormal,
                fuenteNegrita: fuenteNegrita,
              ),

              pw.SizedBox(height: 16),

              // ================================================
              // PARTE INFERIOR
              // ================================================

              pw.Row(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 6,
                    child: _distribucionTop10(
                      clientes: clientes,
                      totalValor: totalValor,
                      fuenteNormal: fuenteNormal,
                      fuenteNegrita: fuenteNegrita,
                    ),
                  ),

                  pw.SizedBox(width: 12),

                  pw.Expanded(
                    flex: 4,
                    child: _resumenGeneral(
                      cantidad: clientes.length,
                      totalValor: totalValor,
                      totalPeso: totalPeso,
                      moneda: moneda,
                      peso: peso,
                      fuenteNormal: fuenteNormal,
                      fuenteNegrita: fuenteNegrita,
                    ),
                  ),
                ],
              ),
            ];
          },
        ),
      );

      // ========================================================
      // GUARDAR
      // ========================================================

      final Uint8List bytes =
          await pdf.save();

      // ========================================================
      // IMPRESIÓN
      // ========================================================

      await Printing.layoutPdf(
        name:
            'Reporte_Top_Clientes_ELCOPE.pdf',
        onLayout:
            (PdfPageFormat format) async {
          return bytes;
        },
      );
    } catch (e, stackTrace) {
      debugPrint(
        '========================================',
      );

      debugPrint(
        'ERROR GENERANDO PDF TOP CLIENTES',
      );

      debugPrint(e.toString());

      debugPrint(stackTrace.toString());

      debugPrint(
        '========================================',
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Error al generar el PDF: $e',
          ),
        ),
      );
    }
  }

  // ==========================================================
  // INDICADORES
  // ==========================================================

  pw.Widget _indicadores({
    required int cantidad,
    required double totalValor,
    required double totalPeso,
    required NumberFormat moneda,
    required NumberFormat peso,
    required pw.Font fuenteNormal,
    required pw.Font fuenteNegrita,
  }) {
    return pw.Container(
      height: 68,

      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: grisLinea,
          width: .8,
        ),
        borderRadius:
            pw.BorderRadius.circular(7),
      ),

      child: pw.Row(
        children: [
          _indicador(
            titulo: 'CLIENTES',
            valor: '$cantidad',
            color: verdeElcope,
            simbolo: 'C',
            fuenteNormal: fuenteNormal,
            fuenteNegrita: fuenteNegrita,
          ),

          _indicador(
            titulo: 'VALOR NETO TOTAL',
            valor:
                'US\$ ${moneda.format(totalValor)}',
            color: azulApoyo,
            simbolo: '\$',
            fuenteNormal: fuenteNormal,
            fuenteNegrita: fuenteNegrita,
          ),

          _indicador(
            titulo: 'PESO COBRE TOTAL',
            valor:
                '${peso.format(totalPeso)} Kg',
            color: naranja,
            simbolo: 'Kg',
            fuenteNormal: fuenteNormal,
            fuenteNegrita: fuenteNegrita,
          ),

          _indicador(
            titulo: 'PORCENTAJE TOTAL',
            valor: '100 %',
            color: verdeClaro,
            simbolo: '%',
            fuenteNormal: fuenteNormal,
            fuenteNegrita: fuenteNegrita,
            ultimo: true,
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // INDICADOR INDIVIDUAL
  // ==========================================================

  pw.Widget _indicador({
    required String titulo,
    required String valor,
    required PdfColor color,
    required String simbolo,
    required pw.Font fuenteNormal,
    required pw.Font fuenteNegrita,
    bool ultimo = false,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 7,
        ),

        decoration: ultimo
            ? null
            : pw.BoxDecoration(
                border: pw.Border(
                  right: pw.BorderSide(
                    color: grisLinea,
                    width: .6,
                  ),
                ),
              ),

        child: pw.Row(
          children: [
            pw.Container(
              width: 31,
              height: 31,

              decoration: pw.BoxDecoration(
                color: color,
                shape: pw.BoxShape.circle,
              ),

              alignment:
                  pw.Alignment.center,

              child: pw.Text(
                simbolo,
                style: pw.TextStyle(
                  font: fuenteNegrita,
                  fontSize:
                      simbolo == 'Kg'
                          ? 6
                          : 12,
                  color:
                      PdfColors.white,
                ),
              ),
            ),

            pw.SizedBox(width: 7),

            pw.Expanded(
              child: pw.Column(
                mainAxisAlignment:
                    pw.MainAxisAlignment.center,

                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,

                children: [
                  pw.Text(
                    titulo,
                    maxLines: 1,
                    style: pw.TextStyle(
                      font: fuenteNormal,
                      fontSize: 6.2,
                      color:
                          PdfColors.grey700,
                    ),
                  ),

                  pw.SizedBox(height: 3),

                  pw.Text(
                    valor,
                    maxLines: 1,
                    style: pw.TextStyle(
                      font: fuenteNegrita,
                      fontSize: 9.3,
                      color:
                          verdeOscuro,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // TABLA DE CLIENTES
  // ==========================================================

  pw.Widget _tablaClientes({
    required List<TopClienteModel> clientes,
    required double totalValor,
    required NumberFormat moneda,
    required NumberFormat peso,
    required Map<String, Map<String, String>> datosReporte,
    required pw.Font fuenteNormal,
    required pw.Font fuenteNegrita,
  }) {
    return pw.Table(
      // Repetir la primera fila (encabezados) automáticamente
      // cuando la tabla continúa en una nueva página.
   

      border: pw.TableBorder.all(
        color: grisLinea,
        width: .45,
      ),

      // ========================================================
      // COLUMNAS DEL REPORTE IMPRESO
      // ========================================================

      columnWidths: {
        0: const pw.FixedColumnWidth(24),
        1: const pw.FlexColumnWidth(3.8),
        2: const pw.FlexColumnWidth(1.65),
        3: const pw.FlexColumnWidth(1.30),
        4: const pw.FlexColumnWidth(1.55),
        5: const pw.FlexColumnWidth(1.25),
        6: const pw.FlexColumnWidth(1.55),
      },

      children: [
        // ======================================================
        // CABECERA VERDE
        // ======================================================

       pw.TableRow(
  repeat: true,
  decoration: const pw.BoxDecoration(
    color: verdeElcope,
  ),
          children: [
            _celdaHeader('N°', fuenteNegrita),
            _celdaHeader('CLIENTE', fuenteNegrita),
            _celdaHeader('REPRESENTANTE', fuenteNegrita),
            _celdaHeader('FECHA PROD.', fuenteNegrita),
            _celdaHeader('VALOR NETO', fuenteNegrita),
            _celdaHeader('AVANCE (%)', fuenteNegrita),
            _celdaHeader('PESO COBRE (Kg)', fuenteNegrita),
          ],
        ),

        // ======================================================
        // FILAS
        // ======================================================

        ...List.generate(
          clientes.length,
          (int index) {
            final TopClienteModel item = clientes[index];

            final double porcentaje = totalValor == 0
                ? 0
                : (item.valor / totalValor) * 100;

            final datos =
                datosReporte[item.cliente.trim()] ??
                    const <String, String>{};

            final representante =
                datos['representante'] ?? '-';

            final fechaProduccion =
                datos['fechaProduccion'] ?? '-';

            return pw.TableRow(
              decoration: pw.BoxDecoration(
                color: index.isEven
                    ? PdfColors.white
                    : grisFondo,
              ),

              children: [
                _celda(
                  '${index + 1}',
                  fuenteNormal,
                  align: pw.TextAlign.center,
                ),

                _celda(
                  item.cliente,
                  fuenteNormal,
                ),

                _celda(
                  representante,
                  fuenteNormal,
                  align: pw.TextAlign.center,
                  maxLines: 3,
                ),

                _celda(
                  fechaProduccion,
                  fuenteNormal,
                  align: pw.TextAlign.center,
                  maxLines: 4,
                ),

                _celda(
                  'US\$ ${moneda.format(item.valor)}',
                  fuenteNormal,
                  align: pw.TextAlign.right,
                ),

                _celda(
                  '${porcentaje.toStringAsFixed(1)} %',
                  fuenteNormal,
                  align: pw.TextAlign.right,
                ),

                _celda(
                  peso.format(item.pesoCobre),
                  fuenteNormal,
                  align: pw.TextAlign.right,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ==========================================================
  // DISTRIBUCIÓN TOP 10
  // ==========================================================

  pw.Widget _distribucionTop10({
    required List<TopClienteModel> clientes,
    required double totalValor,
    required pw.Font fuenteNormal,
    required pw.Font fuenteNegrita,
  }) {
    final List<TopClienteModel> top10 =
        clientes.take(10).toList();

    if (top10.isEmpty) {
      return pw.SizedBox();
    }

    double totalTop10 = 0;

    for (final TopClienteModel item
        in top10) {
      totalTop10 += item.valor;
    }

    final double otros =
        totalValor > totalTop10
            ? totalValor - totalTop10
            : 0;

    final List<double> valores = [
      ...top10.map(
        (TopClienteModel e) => e.valor,
      ),
      if (otros > 0) otros,
    ];

    final List<String> nombres = [
      ...top10.map(
        (TopClienteModel e) => e.cliente,
      ),
      if (otros > 0) 'OTROS CLIENTES',
    ];

    // ========================================================
    // COLORES VERDES / CORPORATIVOS
    // ========================================================

    final List<PdfColor> colores = [
      verdeElcope,
      verdeClaro,
      const PdfColor.fromInt(0xFF21B573),
      const PdfColor.fromInt(0xFF38C987),
      const PdfColor.fromInt(0xFF65D39E),
      const PdfColor.fromInt(0xFF0A8F52),
      const PdfColor.fromInt(0xFF0B6E42),
      const PdfColor.fromInt(0xFF49B77C),
      const PdfColor.fromInt(0xFF8ACFAD),
      azulApoyo,
      const PdfColor.fromInt(0xFFB7B7B7),
    ];

    final List<double> porcentajes =
        valores.map(
      (double valor) {
        if (totalValor == 0) {
          return 0.0;
        }

        return (valor / totalValor) * 100;
      },
    ).toList();

    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,
      children: [
        // ======================================================
        // TITULO
        // ======================================================

        pw.Text(
          'DISTRIBUCIÓN PORCENTUAL - TOP 10 CLIENTES',
          style: pw.TextStyle(
            font: fuenteNegrita,
            fontSize: 8.5,
            color: verdeOscuro,
          ),
        ),

        pw.SizedBox(height: 7),

        // ======================================================
        // GRAFICO + LEYENDA
        // ======================================================

        pw.Row(
          crossAxisAlignment:
              pw.CrossAxisAlignment.center,
          children: [
            pw.SizedBox(
              width: 145,
              height: 145,
              child: pw.SvgImage(
                svg: _crearDonutSvg(
                  valores: valores,
                  colores: colores,
                ),
              ),
            ),

            pw.SizedBox(width: 7),

            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children:
                    List.generate(
                  nombres.length,
                  (int index) {
                    return pw.Padding(
                      padding:
                          const pw.EdgeInsets.only(
                        bottom: 3,
                      ),

                      child: pw.Row(
                        children: [
                          pw.Container(
                            width: 7,
                            height: 7,
                            color:
                                colores[index],
                          ),

                          pw.SizedBox(
                            width: 4,
                          ),

                          pw.Expanded(
                            child: pw.Text(
                              nombres[index],
                              maxLines: 1,
                              style:
                                  pw.TextStyle(
                                font:
                                    fuenteNormal,
                                fontSize: 5.7,
                              ),
                            ),
                          ),

                          pw.SizedBox(
                            width: 3,
                          ),

                          pw.Text(
                            '${porcentajes[index].toStringAsFixed(1)} %',
                            style:
                                pw.TextStyle(
                              font:
                                  fuenteNegrita,
                              fontSize: 5.7,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================================
  // DONUT
  // ==========================================================

  String _crearDonutSvg({
    required List<double> valores,
    required List<PdfColor> colores,
  }) {
    double total = 0;

    for (final double valor in valores) {
      total += valor;
    }

    if (total <= 0) {
      return '''
<svg width="145" height="145"
     viewBox="0 0 145 145"
     xmlns="http://www.w3.org/2000/svg">

  <circle
    cx="72.5"
    cy="72.5"
    r="55"
    fill="#D9E2DC"/>

  <circle
    cx="72.5"
    cy="72.5"
    r="30"
    fill="#FFFFFF"/>

</svg>
''';
    }

    const double cx = 72.5;
    const double cy = 72.5;
    const double radioExterior = 55;
    const double radioInterior = 30;

    double inicio = -math.pi / 2;

    final StringBuffer svg =
        StringBuffer();

    svg.write('''
<svg width="145" height="145"
     viewBox="0 0 145 145"
     xmlns="http://www.w3.org/2000/svg">
''');

    for (int i = 0;
        i < valores.length;
        i++) {
      final double proporcion =
          valores[i] / total;

      final double angulo =
          proporcion *
              2 *
              math.pi;

      final double fin =
          inicio + angulo;

      if (angulo >=
          (2 * math.pi - 0.0001)) {
        svg.write('''
<circle
  cx="$cx"
  cy="$cy"
  r="$radioExterior"
  fill="${_colorHex(colores[i])}"/>
''');
      } else {
        final double x1 =
            cx +
                radioExterior *
                    math.cos(inicio);

        final double y1 =
            cy +
                radioExterior *
                    math.sin(inicio);

        final double x2 =
            cx +
                radioExterior *
                    math.cos(fin);

        final double y2 =
            cy +
                radioExterior *
                    math.sin(fin);

        final int largeArc =
            angulo > math.pi
                ? 1
                : 0;

        svg.write('''
<path
  d="M $cx $cy
     L $x1 $y1
     A $radioExterior $radioExterior
       0 $largeArc 1
       $x2 $y2
     Z"
  fill="${_colorHex(colores[i])}"
  stroke="#FFFFFF"
  stroke-width="1"/>
''');
      }

      inicio = fin;
    }

    // ========================================================
    // CENTRO BLANCO
    // ========================================================

    svg.write('''
<circle
  cx="$cx"
  cy="$cy"
  r="$radioInterior"
  fill="#FFFFFF"/>
''');

    svg.write('</svg>');

    return svg.toString();
  }

  // ==========================================================
  // COLOR PDF -> HEX
  // ==========================================================

  String _colorHex(PdfColor color) {
    final int valor = color.toInt();

    final int rgb =
        valor & 0xFFFFFF;

    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }

  // ==========================================================
  // RESUMEN GENERAL
  // ==========================================================

  pw.Widget _resumenGeneral({
    required int cantidad,
    required double totalValor,
    required double totalPeso,
    required NumberFormat moneda,
    required NumberFormat peso,
    required pw.Font fuenteNormal,
    required pw.Font fuenteNegrita,
  }) {
    return pw.Container(
      padding:
          const pw.EdgeInsets.all(10),

      decoration: pw.BoxDecoration(
        color: PdfColors.white,

        border: pw.Border.all(
          color: verdeElcope,
          width: 1,
        ),

        borderRadius:
            pw.BorderRadius.circular(7),
      ),

      child: pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: [
          // ====================================================
          // TITULO
          // ====================================================

          pw.Row(
            children: [
              pw.Container(
                width: 27,
                height: 27,

                decoration:
                    const pw.BoxDecoration(
                  color: verdeElcope,
                  shape: pw.BoxShape.circle,
                ),

                alignment:
                    pw.Alignment.center,

                child: pw.Text(
                  'R',
                  style: pw.TextStyle(
                    font: fuenteNegrita,
                    fontSize: 11,
                    color:
                        PdfColors.white,
                  ),
                ),
              ),

              pw.SizedBox(width: 6),

              pw.Text(
                'RESUMEN GENERAL',
                style: pw.TextStyle(
                  font: fuenteNegrita,
                  fontSize: 9,
                  color: verdeOscuro,
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 10),

          // ====================================================
          // CLIENTES
          // ====================================================

          _lineaResumen(
            'Clientes:',
            '$cantidad',
            fuenteNormal,
            fuenteNegrita,
          ),

          pw.Divider(
            color: grisLinea,
            thickness: .5,
          ),

          // ====================================================
          // VALOR
          // ====================================================

          _lineaResumen(
            'Valor Neto Total:',
            'US\$ ${moneda.format(totalValor)}',
            fuenteNormal,
            fuenteNegrita,
          ),

          pw.Divider(
            color: grisLinea,
            thickness: .5,
          ),

          // ====================================================
          // PESO
          // ====================================================

          _lineaResumen(
            'Peso Cobre Total:',
            '${peso.format(totalPeso)} Kg',
            fuenteNormal,
            fuenteNegrita,
          ),

          pw.Divider(
            color: grisLinea,
            thickness: .5,
          ),

          // ====================================================
          // PORCENTAJE
          // ====================================================

          _lineaResumen(
            'Porcentaje Total:',
            '100 %',
            fuenteNormal,
            fuenteNegrita,
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // LINEA RESUMEN
  // ==========================================================

  pw.Widget _lineaResumen(
    String titulo,
    String valor,
    pw.Font fuenteNormal,
    pw.Font fuenteNegrita,
  ) {
    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          titulo,
          style: pw.TextStyle(
            font: fuenteNormal,
            fontSize: 7.5,
            color: verdeOscuro,
          ),
        ),

        pw.SizedBox(height: 2),

        pw.Text(
          valor,
          style: pw.TextStyle(
            font: fuenteNegrita,
            fontSize: 9,
            color: verdeElcope,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // INFORMACIÓN HEADER
  // ==========================================================

  pw.Widget _datoHeader(
    String titulo,
    String valor,
    pw.Font fuenteNormal,
    pw.Font fuenteNegrita,
  ) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$titulo ',
            style: pw.TextStyle(
              font: fuenteNegrita,
              fontSize: 6.3,
              color: verdeOscuro,
            ),
          ),

          pw.TextSpan(
            text: valor,
            style: pw.TextStyle(
              font: fuenteNormal,
              fontSize: 6.3,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // HEADER DE TABLA
  // ==========================================================

  pw.Widget _celdaHeader(
    String texto,
    pw.Font fuente,
  ) {
    return pw.Container(
      padding:
          const pw.EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 5,
      ),

      alignment:
          pw.Alignment.center,

      child: pw.Text(
        texto,
        textAlign:
            pw.TextAlign.center,
        style: pw.TextStyle(
          font: fuente,
          fontSize: 6.5,
          color:
              PdfColors.white,
        ),
      ),
    );
  }

  // ==========================================================
  // CELDA
  // ==========================================================

  pw.Widget _celda(
    String texto,
    pw.Font fuente, {
    pw.TextAlign align =
        pw.TextAlign.left,
    int maxLines = 2,
  }) {
    final pw.Alignment alineacion =
        align == pw.TextAlign.right
            ? pw.Alignment.centerRight
            : align == pw.TextAlign.center
                ? pw.Alignment.center
                : pw.Alignment.centerLeft;

    return pw.Container(
      padding:
          const pw.EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 4,
      ),

      alignment: alineacion,

      child: pw.Text(
        texto,
        textAlign: align,
        maxLines: maxLines,
        overflow:
            pw.TextOverflow.clip,
        style: pw.TextStyle(
          font: fuente,
          fontSize: 6.4,
          color: PdfColors.black,
        ),
      ),
    );
  }
}