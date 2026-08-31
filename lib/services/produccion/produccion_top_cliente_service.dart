import '../../models/produccion/produccion_model.dart';
import '../../models/produccion/top_cliente_model.dart';

class ProduccionTopClienteService {
  List<TopClienteModel> obtener(
    List<ProduccionModel> lista,
  ) {
    // ==========================================================
    // AGRUPAR POR CLIENTE
    // ==========================================================

    final Map<String, Map<String, double>> mapa = {};

    for (final item in lista) {
      final cliente = item.cliente.trim();

      if (cliente.isEmpty) {
        continue;
      }

      final valor =
          (item.valorNeto ?? 0).toDouble();

      final peso =
          (item.pesoCobre ?? 0).toDouble();

      // ========================================================
      // CREAR CLIENTE
      // ========================================================

      if (!mapa.containsKey(cliente)) {
        mapa[cliente] = {
          'valor': 0.0,
          'peso': 0.0,
        };
      }

      // ========================================================
      // SUMAR VALOR NETO
      // ========================================================

      mapa[cliente]!['valor'] =
          mapa[cliente]!['valor']! + valor;

      // ========================================================
      // SUMAR PESO COBRE
      // ========================================================

      mapa[cliente]!['peso'] =
          mapa[cliente]!['peso']! + peso;
    }

    // ==========================================================
    // CREAR MODELOS
    // ==========================================================

    final resultado = mapa.entries
        .map(
          (e) => TopClienteModel(
            cliente: e.key,
            valor: e.value['valor'] ?? 0.0,
            pesoCobre: e.value['peso'] ?? 0.0,
          ),
        )
        .toList();

    // ==========================================================
    // ORDENAR DE MAYOR A MENOR
    // ==========================================================

    resultado.sort(
      (a, b) => b.valor.compareTo(a.valor),
    );

    // ==========================================================
    // IMPORTANTE
    //
    // YA NO HACEMOS take(10)
    //
    // El widget mostrará los primeros 10,
    // pero "Ver todos" podrá mostrar todos.
    // ==========================================================

    return resultado;
  }
}