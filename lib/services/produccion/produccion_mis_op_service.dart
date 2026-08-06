import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/produccion/produccion_model.dart';
import '../sesion.dart';

class ProduccionMisOpService {
  final supabase = Supabase.instance.client;

  Future<List<ProduccionModel>> obtener() async {
    final response = await supabase
        .from('produccion_pendiente')
        .select();

    List<dynamic> datos = response;

    // Solo mostrar las OP del usuario logueado
    datos = datos.where((e) {
      return e["representante"] == Sesion.vendedor;
    }).toList();

    datos.sort((a, b) {
      final fechaA = DateTime.tryParse(
            a["fecha_entrega_estimada"]?.toString() ?? "",
          ) ??
          DateTime(2100);

      final fechaB = DateTime.tryParse(
            b["fecha_entrega_estimada"]?.toString() ?? "",
          ) ??
          DateTime(2100);

      return fechaA.compareTo(fechaB);
    });

    return datos
        .map((e) => ProduccionModel.fromMap(e))
        .toList();
  }
}