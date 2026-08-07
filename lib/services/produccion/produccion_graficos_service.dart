import '../../models/produccion/grafico_produccion.dart';
import '../../models/produccion/produccion_model.dart';

class ProduccionGraficosService {

  //==================================================
  // ESTADO
  //==================================================

  List<GraficoProduccion> estado(
    List<ProduccionModel> lista,
  ) {
    final Map<String, double> mapa = {};

    for (final op in lista) {
      mapa.update(
        op.estado,
        (v) => v + 1,
        ifAbsent: () => 1,
      );
    }

    return mapa.entries
        .map(
          (e) => GraficoProduccion(
            nombre: e.key,
            valor: e.value,
          ),
        )
        .toList();
  }

  //==================================================
  // CANAL
  //==================================================

  List<GraficoProduccion> canal(
    List<ProduccionModel> lista,
  ) {
    final Map<String, double> mapa = {};

    for (final op in lista) {
      final canal =
          op.canal.isEmpty ? "Sin Canal" : op.canal;

      mapa.update(
        canal,
        (v) => v + 1,
        ifAbsent: () => 1,
      );
    }

    return mapa.entries
        .map(
          (e) => GraficoProduccion(
            nombre: e.key,
            valor: e.value,
          ),
        )
        .toList();
  }

  //==================================================
  // CLASE
  //==================================================

  List<GraficoProduccion> clase(
    List<ProduccionModel> lista,
  ) {
    final Map<String, double> mapa = {};

    for (final op in lista) {
      final clase =
          (op.clase ?? "").isEmpty
              ? "Sin Clase"
              : op.clase!;

      mapa.update(
        clase,
        (v) => v + 1,
        ifAbsent: () => 1,
      );
    }

    return mapa.entries
        .map(
          (e) => GraficoProduccion(
            nombre: e.key,
            valor: e.value,
          ),
        )
        .toList();
  }

  //==================================================
  // FAMILIA (POR PESO DE COBRE)
  //==================================================

  List<GraficoProduccion> familia(
    List<ProduccionModel> lista,
  ) {
    final Map<String, double> mapa = {};

    for (final op in lista) {
      final familia =
          (op.abreviadoFamilia ?? "").isEmpty
              ? "OTROS"
              : op.abreviadoFamilia!;

      mapa.update(
        familia,
        (valor) => valor + (op.pesoCobre ?? 0),
        ifAbsent: () => op.pesoCobre ?? 0,
      );
    }

    final resultado = mapa.entries
        .map(
          (e) => GraficoProduccion(
            nombre: e.key,
            valor: e.value,
          ),
        )
        .toList();

    resultado.sort(
      (a, b) => b.valor.compareTo(a.valor),
    );

    return resultado;
  }
}