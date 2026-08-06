import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/produccion/produccion_familia.dart';

class ProduccionFamiliaService {

  final supabase =
      Supabase.instance.client;

  Future<List<ProduccionFamilia>>
      obtenerFamilias() async {

    final response = await supabase
        .from('vw_produccion_familia')
        .select();

    return response
        .map(
          (e) => ProduccionFamilia.fromMap(e),
        )
        .toList();
  }
}