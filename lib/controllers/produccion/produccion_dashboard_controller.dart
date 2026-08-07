import 'package:flutter/material.dart';

import '../../models/produccion/top_cliente_model.dart';
import '../../services/produccion/produccion_top_cliente_service.dart';

import '../../services/produccion/produccion_graficos_service.dart';
import '../../services/produccion/produccion_mis_op_service.dart';
import '../../models/produccion/produccion_model.dart';
import '../../models/produccion/grafico_produccion.dart';
class ProduccionDashboardController extends ChangeNotifier {

  final ProduccionMisOpService _service =
      ProduccionMisOpService();

  final ProduccionGraficosService _graficos =
      ProduccionGraficosService();

  final ProduccionTopClienteService _topClienteService =
      ProduccionTopClienteService();

  bool cargando = true;

//---------------- PRODUCCIONES ----------------

List<ProduccionModel> producciones = [];

//---------------- DONAS ----------------

List<GraficoProduccion> estado = [];
List<GraficoProduccion> canal = [];
List<GraficoProduccion> clase = [];
List<GraficoProduccion> familia = [];

//---------------- TOP CLIENTES ----------------

List<TopClienteModel> topClientes = [];

  //---------------- KPIs ----------------

  int totalOp = 0;

  int clientes = 0;

  double valorNeto = 0;

  double pesoCobre = 0;

  Future cargar() async {

    cargando = true;
    notifyListeners();

    producciones =
        await _service.obtener();

    //---------------- KPIs ----------------

    totalOp = producciones.length;

    clientes = producciones
        .map((e) => e.cliente)
        .toSet()
        .length;

    valorNeto = producciones.fold(
      0.0,
      (suma, e) => suma + (e.valorNeto ?? 0),
    );

    pesoCobre = producciones.fold(
      0.0,
      (suma, e) => suma + (e.pesoCobre ?? 0),
    );

    //---------------- DONAS ----------------

    estado =
        _graficos.estado(producciones);

    canal =
        _graficos.canal(producciones);

    clase =
        _graficos.clase(producciones);

    familia =
        _graficos.familia(producciones);

    //---------------- TOP CLIENTES ----------------

    topClientes =
        _topClienteService.obtener(
          producciones,
        );

    cargando = false;

    notifyListeners();
  }
}