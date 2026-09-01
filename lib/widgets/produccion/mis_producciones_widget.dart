import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../models/produccion/produccion_model.dart';
import '../../services/produccion/produccion_mis_op_service.dart';
import '../../services/sesion.dart';
import 'produccion_mis_op_datasource.dart';
import 'mis_producciones_preview.dart';

class MisProduccionesWidget extends StatefulWidget {
  const MisProduccionesWidget({
    super.key,
  });

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

  Future<void> _actualizar() async {
    setState(() {
      future = service.obtener();
    });

    await future;
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
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }

        final lista = snapshot.data ?? [];

        debugPrint(
          "Usuario   : ${Sesion.usuario}",
        );
        debugPrint(
          "Nombre    : ${Sesion.nombre}",
        );
        debugPrint(
          "Rol       : ${Sesion.rol}",
        );
        debugPrint(
          "Vendedor  : ${Sesion.vendedor}",
        );
        debugPrint(
          "Cantidad OP: ${lista.length}",
        );

        final mobile =
            MediaQuery.sizeOf(context).width < 650;

        return Card(
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: SizedBox(
            height: mobile ? 560 : 500,
            child: Column(
              children: [
                SizedBox(height: mobile ? 12 : 15),

                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: mobile ? 14 : 20,
                  ),
                  child: mobile
                      ? Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.factory_outlined,
                                  color: Colors.indigo,
                                  size: 27,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Mis Producciones (${lista.length})",
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: "Actualizar",
                                  onPressed: _actualizar,
                                  icon: const Icon(
                                    Icons.refresh,
                                    color: Colors.indigo,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            SizedBox(
                              width: double.infinity,
                              child:
                                  ElevatedButton.icon(
                                style:
                                    ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(
                                    0xFF007A45,
                                  ),
                                  foregroundColor:
                                      Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(
                                      10,
                                    ),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 20,
                                ),
                                label: const Text(
                                  "Vista preliminar",
                                  style: TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                                onPressed: lista.isEmpty
                                    ? null
                                    : () {
                                        Navigator.of(
                                          context,
                                        ).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                MisProduccionesPreview(
                                              producciones:
                                                  lista,
                                            ),
                                          ),
                                        );
                                      },
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            const Icon(
                              Icons.factory_outlined,
                              color: Colors.indigo,
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Mis Producciones (${lista.length})",
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              style:
                                  ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(
                                  0xFF007A45,
                                ),
                                foregroundColor:
                                    Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                    10,
                                  ),
                                ),
                              ),
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 20,
                              ),
                              label: const Text(
                                "Vista preliminar",
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              onPressed: lista.isEmpty
                                  ? null
                                  : () {
                                      Navigator.of(
                                        context,
                                      ).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              MisProduccionesPreview(
                                            producciones:
                                                lista,
                                          ),
                                        ),
                                      );
                                    },
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: "Actualizar",
                              onPressed: _actualizar,
                              icon: const Icon(
                                Icons.refresh,
                                color: Colors.indigo,
                              ),
                            ),
                          ],
                        ),
                ),

                const Divider(),

                Expanded(
                  child: SfDataGrid(
                    source:
                        ProduccionMisOpDataSource(
                      lista,
                    ),
                    columnWidthMode:
                        ColumnWidthMode.none,
                    columns: [
                      GridColumn(
                        width: 150,
                        columnName: 'op',
                        label: const Center(
                          child: Text(
                            "OP",
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        width: 280,
                        columnName: 'cliente',
                        label: const Center(
                          child: Text(
                            "Cliente",
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        width: 450,
                        columnName: 'articulo',
                        label: const Center(
                          child: Text(
                            "Artículo",
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        width: 120,
                        columnName: 'entrega',
                        label: const Center(
                          child: Text(
                            "Fecha Prod",
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        width: 90,
                        columnName: 'retraso',
                        label: const Center(
                          child: Text(
                            "Retraso",
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        width: 120,
                        columnName: 'cantidad',
                        label: const Center(
                          child: Text(
                            "Cantidad",
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        width: 140,
                        columnName: 'valor',
                        label: const Center(
                          child: Text(
                            "Valor Neto",
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        width: 130,
                        columnName: 'cobre',
                        label: const Center(
                          child: Text(
                            "Peso Cobre",
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        width: 120,
                        columnName: 'canal',
                        label: const Center(
                          child: Text(
                            "Canal",
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        width: 90,
                        columnName: 'clase',
                        label: const Center(
                          child: Text(
                            "Clase",
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        width: 150,
                        columnName: 'familia',
                        label: const Center(
                          child: Text(
                            "Familia",
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        width: 130,
                        columnName: 'estado',
                        label: const Center(
                          child: Text(
                            "Estado",
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
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
