import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/produccion/produccion_model.dart';

class ProduccionImportService {
  final supabase = Supabase.instance.client;

  Future<int> importar(
      List<ProduccionModel> lista) async {

    if (lista.isEmpty) return 0;
final mapa = <String, Map<String, dynamic>>{};

for (final item in lista) {
  final registro = item.toMap();

  final llave =
      "${item.numeroProduccion}_${item.codigoArticulo ?? ''}";

  mapa[llave] = registro;
}

final registros =
    lista.map((e) => e.toMap()).toList();

await supabase
    .from('produccion_pendiente')
    .delete()
    .not('id', 'is', null);

await supabase
    .from('produccion_pendiente')
    .insert(registros);

    // Elimina la información anterior
    await supabase
    .from('produccion_pendiente')
    .delete()
    .not('id', 'is', null);
    // Inserta la nueva información
    await supabase
        .from('produccion_pendiente')
        .insert(registros);

    return registros.length;
  }
}