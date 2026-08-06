import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../models/produccion/produccion_model.dart';

class ProduccionMisOpDataSource extends DataGridSource {
  ProduccionMisOpDataSource(List<ProduccionModel> lista) {
    dataGridRows = lista.map((e) {
      return DataGridRow(
        cells: [
          DataGridCell(
            columnName: 'op',
            value: e.numeroProduccion,
          ),

          DataGridCell(
            columnName: 'cliente',
            value: e.cliente,
          ),

          DataGridCell(
            columnName: 'articulo',
            value: e.articulo ?? "",
          ),

          DataGridCell(
            columnName: 'entrega',
            value: e.fechaProduccion,
          ),

          DataGridCell(
            columnName: 'retraso',
            value: e.diasRetraso ?? 0,
          ),

          DataGridCell(
            columnName: 'cantidad',
            value: e.cantidadTotal ?? 0,
          ),

          DataGridCell(
            columnName: 'valor',
            value: e.valorNeto ?? 0,
          ),

          DataGridCell(
            columnName: 'cobre',
            value: e.pesoCobre ?? 0,
          ),

          DataGridCell(
            columnName: 'canal',
            value: e.canal,
          ),

          DataGridCell(
            columnName: 'clase',
            value: e.clase ?? "",
          ),

          DataGridCell(
            columnName: 'familia',
            value: e.abreviadoFamilia ?? "",
          ),

          DataGridCell(
            columnName: 'estado',
            value: e.estado,
          ),
        ],
      );
    }).toList();
  }

  late List<DataGridRow> dataGridRows;

  @override
  List<DataGridRow> get rows => dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final formatoDecimal = NumberFormat("#,##0.00", "en_US");

    return DataGridRowAdapter(
      cells: row.getCells().map((cell) {
        String texto = "";

        switch (cell.columnName) {
          case "entrega":
            if (cell.value != null && cell.value is DateTime) {
              texto = DateFormat("dd/MM/yyyy")
                  .format(cell.value as DateTime);
            }
            break;

          case "cantidad":
            texto = formatoDecimal.format(
              (cell.value as num).toDouble(),
            );
            break;

          case "valor":
            texto =
                "US\$ ${formatoDecimal.format((cell.value as num).toDouble())}";
            break;

          case "cobre":
            texto =
                "${formatoDecimal.format((cell.value as num).toDouble())} Kg";
            break;

          default:
            texto = cell.value?.toString() ?? "";
        }

        //==============================
        // ESTADO CON COLORES
        //==============================

        if (cell.columnName == "estado") {
          Color color = Colors.green;

          switch (cell.value) {
            case "En Tiempo":
              color = Colors.green;
              break;

            case "Próximo":
              color = Colors.amber;
              break;

            case "Retrasado":
              color = Colors.orange;
              break;

            case "Crítico":
              color = Colors.red;
              break;

            case "Sin Fecha":
              color = Colors.grey;
              break;
          }

          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                cell.value.toString(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }

        return Container(
          alignment: switch (cell.columnName) {
            "cantidad" => Alignment.centerRight,
            "valor" => Alignment.centerRight,
            "cobre" => Alignment.centerRight,
            "retraso" => Alignment.center,
            "entrega" => Alignment.center,
            _ => Alignment.centerLeft,
          },
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            texto,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }
}