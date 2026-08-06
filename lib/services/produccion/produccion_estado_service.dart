import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/produccion/produccion_estado.dart';
import '../sesion.dart';

class ProduccionEstadoService {

  final supabase = Supabase.instance.client;

  Future<List<ProduccionEstado>> obtener() async {

    var consulta = supabase
        .from("produccion_pendiente")
        .select();

    consulta = consulta.eq(
      "representante",
      Sesion.vendedor,
    );

    final response = await consulta;

    int rojo = 0;
    int naranja = 0;
    int amarillo = 0;
    int verde = 0;

    for (final e in response) {

      final dias = e["dias_retraso"] ?? 0;

      if (dias <= -30) {
        rojo++;
      } else if (dias <= -8) {
        naranja++;
      } else if (dias < 0) {
        amarillo++;
      } else {
        verde++;
      }

    }

    return [

      ProduccionEstado(
        estado: "Retraso >30",
        cantidad: rojo,
      ),

      ProduccionEstado(
        estado: "Retraso 8-30",
        cantidad: naranja,
      ),

      ProduccionEstado(
        estado: "Retraso 1-7",
        cantidad: amarillo,
      ),

      ProduccionEstado(
        estado: "En tiempo",
        cantidad: verde,
      ),

    ];
  }
}