import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/produccion/produccion_resumen.dart';
import '../sesion.dart';

class ProduccionDashboardService {

  final supabase = Supabase.instance.client;

  Future<ProduccionResumen> obtenerResumen() async {

    final response = await supabase
        .from('vw_produccion_resumen_usuario')
        .select()
        .eq(
          'representante',
          Sesion.vendedor,
        )
        .single();

    return ProduccionResumen.fromMap(response);
  }
}