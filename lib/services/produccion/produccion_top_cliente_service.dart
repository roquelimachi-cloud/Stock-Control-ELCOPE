import '../../models/produccion/produccion_model.dart';
import '../../models/produccion/top_cliente_model.dart';

class ProduccionTopClienteService {
  // ==========================================================
  // OBTENER CLIENTES
  // ==========================================================
  //
  // IMPORTANTE:
  // Este método devuelve TODOS los clientes.
  //
  // NO usar take(10) aquí.
  //
  // El TOP 10 se controla únicamente en el Widget.
  // Así "Ver todos" puede mostrar la lista completa.
  // ==========================================================

  List<TopClienteModel> obtener(
    List<ProduccionModel> lista,
  ) {
    final Map<String, double> mapaValor = {};
    final Map<String, double> mapaPeso = {};

    for (final item in lista) {
      final String cliente =
          item.cliente.trim();

      if (cliente.isEmpty) {
        continue;
      }

      final double valor =
          (item.valorNeto ?? 0).toDouble();

      final double peso =
          (item.pesoCobre ?? 0).toDouble();

      // --------------------------------------------------------
      // VALOR NETO
      // --------------------------------------------------------

      mapaValor.update(
        cliente,
        (valorAnterior) =>
            valorAnterior + valor,
        ifAbsent: () => valor,
      );

      // --------------------------------------------------------
      // PESO COBRE
      // --------------------------------------------------------

      mapaPeso.update(
        cliente,
        (pesoAnterior) =>
            pesoAnterior + peso,
        ifAbsent: () => peso,
      );
    }

    // ==========================================================
    // CREAR RESULTADO
    // ==========================================================

    final List<TopClienteModel> resultado =
        mapaValor.entries.map(
      (entry) {
        final String cliente =
            entry.key;

        return TopClienteModel(
          cliente: cliente,
          valor: entry.value,
          pesoCobre:
              mapaPeso[cliente] ?? 0.0,
        );
      },
    ).toList();

    // ==========================================================
    // ORDENAR DE MAYOR A MENOR
    // ==========================================================

    resultado.sort(
      (a, b) =>
          b.valor.compareTo(a.valor),
    );

    // ==========================================================
    // MUY IMPORTANTE
    // ==========================================================
    //
    // NO HACER:
    //
    // return resultado.take(10).toList();
    //
    // Debemos devolver TODOS.
    // ==========================================================

    return resultado;
  }
}