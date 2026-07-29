import 'package:flutter/material.dart';

import '../../models/stock/stock_item.dart';
import '../../services/supabase/stock_query_service.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final buscarController = TextEditingController();

  final servicio = StockQueryService();

  List<StockItem> lista = [];

  bool cargando = false;

  @override
  void initState() {
    super.initState();
    buscar("");
  }

  Future<void> buscar(String texto) async {
    setState(() {
      cargando = true;
    });

    lista = await servicio.buscar(texto);

    setState(() {
      cargando = false;
    });
  }

  double get totalStock => lista.fold(0.0, (a, b) => a + b.stock);

  double get totalPeso => lista.fold(0.0, (a, b) => a + b.peso);

  double get totalValorLista =>
      lista.fold(0.0, (a, b) => a + b.valorListaPrecioDolar);

  double get totalValorFacturado =>
      lista.fold(0.0, (a, b) => a + b.valorFacturacionDolar);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("CONTROL DE STOCK ELCOPE"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            TextField(
              controller: buscarController,
              decoration: InputDecoration(
                hintText:
                    "Buscar código, descripción, cliente, vendedor o lote",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: buscar,
            ),

            const SizedBox(height: 15),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Chip(
                    avatar: const Icon(Icons.list_alt, size: 18),
                    label: Text("Resultados ${lista.length}"),
                  ),

                  const SizedBox(width: 10),

                  Chip(
                    avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: Text("Stock ${totalStock.toStringAsFixed(2)}"),
                  ),

                  const SizedBox(width: 10),

                  Chip(
                    avatar: const Icon(Icons.scale_outlined, size: 18),
                    label: Text("Peso ${totalPeso.toStringAsFixed(2)} kg"),
                  ),

                  const SizedBox(width: 10),

                  Chip(
                    avatar: const Icon(Icons.attach_money, size: 18),
                    label: Text(
                      "X facturar \$ ${totalValorLista.toStringAsFixed(2)}",
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            Expanded(
              child: cargando
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : ListView.builder(
                      itemCount: lista.length,
                      itemBuilder: (context, index) {
                        final item = lista[index];

                        return Card(
                          child: ListTile(
                            title: Text(item.descripcion),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Código : ${item.codigo}"),
                                Text("Cliente : ${item.cliente}"),
                                Text("Lote : ${item.lote}"),
                                Text("Vendedor : ${item.vendedor}"),

                                Text(
                                  "Precio Lista : US\$ ${item.listaPrecioDolar.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                Text(
                                  "Fecha Ingreso Alm. 01 : ${item.fechaIngreso}",
                                  style: const TextStyle(
                                    color: Colors.blueGrey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  item.stock.toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  "${item.peso.toStringAsFixed(2)} kg",
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
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