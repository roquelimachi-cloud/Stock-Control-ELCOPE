import 'package:flutter/material.dart';

import '../../models/produccion/produccion_model.dart';
import '../../services/produccion/produccion_mis_op_service.dart';
import '../../services/sesion.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import 'produccion_mis_op_datasource.dart';
import 'mis_producciones_preview.dart';

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

  // ==========================================================
  // ACTUALIZAR
  // ==========================================================

  Future<void> _actualizar() async {
    setState(() {
      future = service.obtener();
    });

    await future;
  }

  // ==========================================================
  // ABRIR VISTA PRELIMINAR DE LA ORDEN SELECCIONADA
  // ==========================================================

  void _abrirOrden(
    BuildContext context,
    List<ProduccionModel> lista,
    DataGridCellTapDetails details,
  ) {
    // La fila 0 corresponde al encabezado.
    final int fila = details.rowColumnIndex.rowIndex;

    if (fila <= 0) {
      return;
    }

    final int indice = fila - 1;

    if (indice < 0 || indice >= lista.length) {
      return;
    }

    // ----------------------------------------------------------
    // IMPORTANTE:
    // Una OP puede tener varias líneas/artículos.
    // Por eso buscamos TODAS las líneas que pertenezcan
    // a la misma orden de producción.
    // ----------------------------------------------------------

    final String numeroOP =
        lista[indice].numeroProduccion;

    final List<ProduccionModel> orden =
        lista.where(
      (item) =>
          item.numeroProduccion == numeroOP,
    ).toList();

    if (orden.isEmpty) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MisProduccionesPreview(
          producciones: orden,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProduccionModel>>(
      future: future,
      builder: (context, snapshot) {
        // ======================================================
        // CARGANDO
        // ======================================================

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

        // ======================================================
        // ERROR
        // ======================================================

        if (snapshot.hasError) {
          return Card(
            child: SizedBox(
              height: 500,
              child: Center(
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final lista = snapshot.data ?? [];

        // ======================================================
        // DEBUG
        // ======================================================

        debugPrint(
          "=================================",
        );

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

        debugPrint(
          "=================================",
        );

        for (final op in lista) {
          debugPrint(
            "${op.numeroProduccion} - ${op.representante}",
          );
        }

        // ======================================================
        // TARJETA
        // ======================================================

        final mobile =
            MediaQuery.sizeOf(context).width < 650;

        return Card(
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: SizedBox(
            // En celular necesitamos más espacio para que
            // encabezado + botón no se compriman.
            height: mobile ? 620 : 500,
            child: Column(
              children: [
                SizedBox(height: mobile ? 12 : 15),

                // ==================================================
                // ENCABEZADO RESPONSIVE
                // ==================================================

                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: mobile ? 14 : 20,
                  ),
                  child: mobile
                      ? Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            // ------------------------------------------
                            // FILA SUPERIOR
                            // ------------------------------------------

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

                            // ------------------------------------------
                            // BOTÓN EN SU PROPIA FILA
                            // ------------------------------------------

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style:
                                    ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFF007A45),
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
                                    const Color(0xFF007A45),
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

                // ==================================================
                // TABLA
                //
                // CLICK / TOUCH EN CUALQUIER FILA:
                // abre solamente esa OP.
                // ==================================================

                Expanded(
                  child: SfDataGrid(
                    source:
                        ProduccionMisOpDataSource(
                      lista,
                    ),

                    columnWidthMode:
                        ColumnWidthMode.none,

                    // =================================================
                    // CLICK / TOUCH
                    // =================================================

                    onCellTap: (details) {
                      _abrirOrden(
                        context,
                        lista,
                        details,
                      );
                    },

                    columns: [
                      // ==============================================
                      // OP
                      // ==============================================

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

                      // ==============================================
                      // CLIENTE
                      // ==============================================

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

                      // ==============================================
                      // ARTÍCULO
                      // ==============================================

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

                      // ==============================================
                      // FECHA PRODUCCIÓN
                      // ==============================================

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

                      // ==============================================
                      // RETRASO
                      // ==============================================

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

                      // ==============================================
                      // CANTIDAD
                      // ==============================================

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

                      // ==============================================
                      // VALOR NETO
                      // ==============================================

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

                      // ==============================================
                      // PESO COBRE
                      // ==============================================

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

                      // ==============================================
                      // CANAL
                      // ==============================================

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

                      // ==============================================
                      // CLASE
                      // ==============================================

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

                      // ==============================================
                      // FAMILIA
                      // ==============================================

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

                      // ==============================================
                      // ESTADO
                      // ==============================================

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
