import '../../models/produccion/produccion_model.dart';
import '../../models/produccion/top_cliente_model.dart';

class ProduccionTopClienteService {

  List<TopClienteModel> obtener(
      List<ProduccionModel> lista) {

    final Map<String, double> mapa = {};

    for (final item in lista) {

      mapa.update(
        item.cliente,
        (valor) => valor + (item.valorNeto ?? 0),
        ifAbsent: () => item.valorNeto ?? 0,
      );
    }

    final resultado = mapa.entries
        .map(
          (e) => TopClienteModel(
            cliente: e.key,
            valor: e.value,
          ),
        )
        .toList();

    resultado.sort(
      (a, b) => b.valor.compareTo(a.valor),
    );

    return resultado.take(10).toList();
  }
}