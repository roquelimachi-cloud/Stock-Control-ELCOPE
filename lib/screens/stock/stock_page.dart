import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  Timer? _temporizadorBusqueda;
  int _idBusqueda = 0;
  bool _mostrarAyudaBusqueda = false;

  final Map<String, String> _nombresClientes = {};
  final Map<String, String> _nombresVendedores = {};
  bool _mapasCargados = false;
  Future<void>? _cargaNombresEnCurso;

  String _clave(String valor) => valor.trim().toUpperCase();

  Future<void> _cargarNombres() {
    if (_mapasCargados) return Future<void>.value();
    return _cargaNombresEnCurso ??= _consultarNombres();
  }

  Future<void> _consultarNombres() async {
    try {
      final supabase = Supabase.instance.client;
      const tamanoPagina = 1000;
      var inicio = 0;
      while (true) {
        final respuesta = await supabase
            .from('clientes')
            .select('codigo, ruc, razon_social, codigo_vendedor, vendedor')
            .range(inicio, inicio + tamanoPagina - 1);

        final filas = List<Map<String, dynamic>>.from(respuesta);
        for (final fila in filas) {
          final nombreCliente =
              (fila['razon_social'] ?? '').toString().trim();
          if (nombreCliente.isNotEmpty) {
            final codigo = (fila['codigo'] ?? '').toString().trim();
            final ruc = (fila['ruc'] ?? '').toString().trim();
            if (codigo.isNotEmpty) _nombresClientes[_clave(codigo)] = nombreCliente;
            if (ruc.isNotEmpty) _nombresClientes[_clave(ruc)] = nombreCliente;
          }

          final codigoVendedor =
              (fila['codigo_vendedor'] ?? '').toString().trim();
          final nombreVendedor = (fila['vendedor'] ?? '').toString().trim();
          if (codigoVendedor.isNotEmpty && nombreVendedor.isNotEmpty) {
            _nombresVendedores.putIfAbsent(
              _clave(codigoVendedor),
              () => nombreVendedor,
            );
          }
        }

        if (filas.length < tamanoPagina) break;
        inicio += tamanoPagina;
      }
      _mapasCargados = true;
    } catch (_) {
      // Si falla la consulta de nombres, la pantalla de stock sigue funcionando.
    } finally {
      _mapasCargados = true;
    }
  }

  String _clienteVisible(String cliente) {
    final original = cliente.trim();
    if (original.isEmpty || original.toUpperCase() == 'SIN CLIENTE') {
      return 'SIN CLIENTE';
    }
    return _nombresClientes[_clave(original)] ?? original;
  }

  String _vendedorVisible(String vendedor) {
    final original = vendedor.trim();
    if (original.isEmpty) return 'SIN VENDEDOR';
    return _nombresVendedores[_clave(original)] ?? original;
  }

  @override
  void initState() {
    super.initState();
    // No consultar stock ni clientes al abrir la pantalla.
    // Los resultados aparecen únicamente después de escribir una búsqueda.
  }

  void _programarBusqueda(String texto) {
    _temporizadorBusqueda?.cancel();
    final entrada = texto.trim();

    if (entrada.isEmpty) {
      _idBusqueda++;
      if (!mounted) return;
      setState(() {
        lista = [];
        cargando = false;
      });
      return;
    }

    setState(() {
      _mostrarAyudaBusqueda = false;
      cargando = true;
    });

    // Espera brevemente a que el usuario termine de escribir para evitar
    // disparar una consulta a Supabase por cada tecla.
    _temporizadorBusqueda = Timer(
      const Duration(milliseconds: 300),
      () => buscar(entrada),
    );
  }

  Future<void> buscar(String texto) async {
    final entrada = texto.trim();
    if (entrada.isEmpty) {
      if (!mounted) return;
      setState(() {
        lista = [];
        cargando = false;
      });
      return;
    }

    final idActual = ++_idBusqueda;
    if (mounted) {
      setState(() {
        cargando = true;
      });
    }

    try {
      final resultados = await servicio.buscar(entrada);
      if (!mounted || idActual != _idBusqueda) return;

      setState(() {
        lista = resultados;
        cargando = false;
      });

      // La consulta principal de stock no espera a cargar todos los clientes.
      unawaited(_cargarNombres());
    } catch (_) {
      if (!mounted || idActual != _idBusqueda) return;
      setState(() {
        lista = [];
        cargando = false;
      });
    }
  }

  double get totalStock => lista.fold(0.0, (a, b) => a + b.stock);

  double get totalPeso => lista.fold(0.0, (a, b) => a + b.peso);

  double get totalValorLista =>
      lista.fold(0.0, (a, b) => a + b.valorListaPrecioDolar);

  double get totalValorFacturado =>
      lista.fold(0.0, (a, b) => a + b.valorFacturacionDolar);

  @override
  void dispose() {
    _temporizadorBusqueda?.cancel();
    buscarController.dispose();
    super.dispose();
  }

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
                    "Buscar código, descripción, cliente, vendedor, lote o modelo",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onTap: () {
                if (buscarController.text.trim().isEmpty &&
                    !_mostrarAyudaBusqueda) {
                  setState(() => _mostrarAyudaBusqueda = true);
                }
              },
              onChanged: _programarBusqueda,
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
                  : lista.isEmpty
                      ? Center(
                          child: _mostrarAyudaBusqueda
                              ? const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.manage_search,
                                      size: 52,
                                      color: Colors.indigo,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Escribe un código, descripción, cliente, vendedor, lote o modelo para consultar el stock.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
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
                                Text("Cliente : ${_clienteVisible(item.cliente)}"),
                                Text("Lote : ${item.lote}"),
                                Text("Vendedor : ${_vendedorVisible(item.vendedor)}"),

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