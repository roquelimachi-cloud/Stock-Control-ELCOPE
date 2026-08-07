import '../produccion/grafico_produccion.dart';
import '../produccion/top_cliente_model.dart';
import '../produccion/produccion_model.dart';

class PdfDashboardModel {

  final int totalOp;

  final int clientes;

  final double valorNeto;

  final double pesoCobre;

  final List<GraficoProduccion> estado;

  final List<GraficoProduccion> canal;

  final List<GraficoProduccion> clase;

  final List<GraficoProduccion> familia;

  final List<TopClienteModel> topClientes;

  final List<ProduccionModel> producciones;

  PdfDashboardModel({

    required this.totalOp,
    required this.clientes,
    required this.valorNeto,
    required this.pesoCobre,

    required this.estado,
    required this.canal,
    required this.clase,
    required this.familia,

    required this.topClientes,

    required this.producciones,

  });

}