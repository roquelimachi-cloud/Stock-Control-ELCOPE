import 'package:flutter/material.dart';

import '../../models/produccion/produccion_model.dart';
import '../../services/produccion/produccion_mis_op_service.dart';
import '../../services/sesion.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import 'produccion_mis_op_datasource.dart';
class MisProduccionesWidget extends StatefulWidget {
  const MisProduccionesWidget({super.key});

  @override
  State<MisProduccionesWidget> createState() =>
      _MisProduccionesWidgetState();
}

class _MisProduccionesWidgetState
    extends State<MisProduccionesWidget> {

  final service = ProduccionMisOpService();

  late Future<List<ProduccionModel>> future;

  @override
  void initState() {
    super.initState();

    future = service.obtener();
  }

  @override
  Widget build(BuildContext context) {

    return FutureBuilder<List<ProduccionModel>>(
      future: future,
      builder: (context, snapshot) {

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Card(
            child: SizedBox(
              height: 500,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: SizedBox(
              height: 500,
              child: Center(
                child: Text(snapshot.error.toString()),
              ),
            ),
          );
        }

        final lista = snapshot.data!;
 debugPrint("=================================");
debugPrint("Usuario   : ${Sesion.usuario}");
debugPrint("Nombre    : ${Sesion.nombre}");
debugPrint("Rol       : ${Sesion.rol}");
debugPrint("Vendedor  : ${Sesion.vendedor}");
debugPrint("Cantidad OP: ${lista.length}");
debugPrint("=================================");

for (final op in lista) {
  debugPrint("${op.numeroProduccion} - ${op.representante}");
}
debugPrint("OP encontradas: ${lista.length}");

for (final op in lista) {
  debugPrint("${op.numeroProduccion} - ${op.representante}");
}
        return Card(
          child: SizedBox(
            height: 500,
            child: Column(
              children: [

                const SizedBox(height: 15),

                Text(
                  "Mis Producciones (${lista.length})",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const Divider(),

       Expanded(
  child: SfDataGrid(
    source: ProduccionMisOpDataSource(lista),

    columnWidthMode: ColumnWidthMode.none,

    columns: [

      GridColumn(
        width: 150,
        columnName: 'op',
        label: const Center(
          child: Text(
            "OP",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),

      GridColumn(
        width: 280,
        columnName: 'cliente',
        label: const Center(
          child: Text(
            "Cliente",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),

      GridColumn(
        width: 450,
        columnName: 'articulo',
        label: const Center(
          child: Text(
            "Artículo",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),

      GridColumn(
        width: 120,
        columnName: 'entrega',
        label: const Center(
          child: Text(
            "Fecha Prod",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),

      GridColumn(
        width: 90,
        columnName: 'retraso',
        label: const Center(
          child: Text(
            "Retraso",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),

      GridColumn(
        width: 120,
        columnName: 'cantidad',
        label: const Center(
          child: Text(
            "Cantidad",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),

      GridColumn(
        width: 130,
        columnName: 'valor',
        label: const Center(
          child: Text(
            "Valor Neto",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),

      GridColumn(
        width: 120,
        columnName: 'cobre',
        label: const Center(
          child: Text(
            "Peso Cobre",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    ],
  ),
),
              ],
            ),
          ),
        );
      },
    );
  }
}