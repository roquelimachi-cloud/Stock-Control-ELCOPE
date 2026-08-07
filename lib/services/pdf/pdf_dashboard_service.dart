import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/produccion/produccion_model.dart';
import '../../models/produccion/top_cliente_model.dart';

class PdfDashboardService {

  Future<void> generar({

    required int totalOp,
    required int clientes,
    required double valorNeto,
    required double pesoCobre,

    required List<TopClienteModel> topClientes,

    required List<ProduccionModel> producciones,

  }) async {

    final pdf = pw.Document();

    final money = NumberFormat("#,##0.00");
    final kg = NumberFormat("#,##0.00");

    pdf.addPage(

      pw.MultiPage(

        pageFormat: PdfPageFormat.a4.landscape,

        build: (context) {

          return [

            pw.Text(
              "ELCOPE",
              style: pw.TextStyle(
                fontSize: 26,
                fontWeight: pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(height: 8),

            pw.Text(
              "Dashboard Producción Pendiente",
              style: const pw.TextStyle(fontSize: 18),
            ),

            pw.SizedBox(height: 20),

            pw.Row(

              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,

              children: [

                _kpi("Total OP", totalOp.toString()),

                _kpi("Clientes", clientes.toString()),

                _kpi(
                  "Valor Neto",
                  "US\$ ${money.format(valorNeto)}",
                ),

                _kpi(
                  "Peso Cobre",
                  "${kg.format(pesoCobre)} Kg",
                ),

              ],

            ),

            pw.SizedBox(height: 25),

            pw.Text(
              "Top Clientes",
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 18,
              ),
            ),

            pw.SizedBox(height: 10),

            pw.Table.fromTextArray(

              headers: const [

                "Cliente",
                "Valor"

              ],

              data: topClientes.map((e)=>[

                e.cliente,

                "US\$ ${money.format(e.valor)}"

              ]).toList(),

            ),

            pw.SizedBox(height: 25),

            pw.Text(

              "Mis Producciones",

              style: pw.TextStyle(

                fontSize: 18,

                fontWeight: pw.FontWeight.bold,

              ),

            ),

            pw.SizedBox(height: 10),

            pw.Table.fromTextArray(

              headers: const [

                "OP",

                "Cliente",

                "Estado",

                "Entrega",

                "Valor",

                "Cobre"

              ],
data: producciones.map((e) => [

  e.numeroProduccion,

  e.cliente,

  e.estado,

  DateFormat('dd/MM/yyyy').format(
    e.fechaEntregaEstimada ?? DateTime.now(),
  ),

  money.format(e.valorNeto ?? 0),

  kg.format(e.pesoCobre ?? 0),

]).toList(),

            ),

          ];

        },

      ),

    );

    await Printing.layoutPdf(

      onLayout: (_) async => pdf.save(),

    );

  }

}

pw.Widget _kpi(

  String titulo,

  String valor,

){

  return pw.Container(

    width: 160,

    padding: const pw.EdgeInsets.all(12),

    decoration: pw.BoxDecoration(

      border: pw.Border.all(),

      borderRadius: pw.BorderRadius.circular(6),

    ),

    child: pw.Column(

      children: [

        pw.Text(titulo),

        pw.SizedBox(height:8),

        pw.Text(

          valor,

          style: pw.TextStyle(

            fontWeight: pw.FontWeight.bold,

            fontSize:18,

          ),

        )

      ],

    ),

  );

}