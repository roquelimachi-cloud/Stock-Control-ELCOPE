import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/produccion/produccion_model.dart';
import '../sesion.dart';

class ProduccionMisOpService {
  final SupabaseClient supabase = Supabase.instance.client;

  // ============================================================
  // REGLA DE VISIBILIDAD
  // ============================================================
  //
  // GERENCIA
  //   -> toda la producción.
  //
  // JEFE LIMA
  //   -> únicamente OP120*
  //
  // JEFE PROVINCIA
  //   -> únicamente OP220*
  //
  // ADMINISTRADOR / VENDEDOR
  //   -> producción de su vendedor.
  //
  // USUARIO SIN VENDEDOR
  //   -> sin registros.
  //
  // IMPORTANTE:
  // Las jefaturas se filtran por NÚMERO DE OP, igual que Stock.
  // No dependen de usuario_permisos para determinar el área.
  // ============================================================

  bool get _esGerencia =>
      Sesion.rol.trim().toLowerCase() == 'gerencia';

  bool get _esJefeLima =>
      Sesion.rol.trim().toLowerCase() == 'jefe lima';

  bool get _esJefeProvincia =>
      Sesion.rol.trim().toLowerCase() == 'jefe provincia';

  bool get _esJefatura =>
      _esJefeLima || _esJefeProvincia;

  String get _prefijoOpJefatura {
    if (_esJefeLima) return 'OP120';
    if (_esJefeProvincia) return 'OP220';
    return '';
  }

  String _normalizar(dynamic valor) {
    return valor?.toString().trim().toLowerCase() ?? '';
  }

  String _op(Map<String, dynamic> registro) {
    return registro['numero_produccion']?.toString().trim() ??
        registro['produccion']?.toString().trim() ??
        registro['orden_produccion']?.toString().trim() ??
        '';
  }

  // ============================================================
  // OBTENER PRODUCCIÓN
  // ============================================================

  Future<List<ProduccionModel>> obtener() async {
    List<Map<String, dynamic>> datos = [];

    // ==========================================================
    // 1. GERENCIA
    // ==========================================================
    //
    // Gerencia puede visualizar toda la producción.
    // ==========================================================

    if (_esGerencia) {
      final response = await supabase
          .from('produccion_pendiente')
          .select();

      datos = (response as List)
          .map(
            (e) => Map<String, dynamic>.from(e),
          )
          .toList();
    }

    // ==========================================================
    // 2. JEFE LIMA / JEFE PROVINCIA
    // ==========================================================
    //
    // MISMA REGLA QUE STOCK:
    //
    // Jefe Lima     -> OP120*
    // Jefe Provincia -> OP220*
    //
    // El filtro se realiza en Supabase para no descargar
    // producción que el usuario no puede visualizar.
    // ==========================================================

    else if (_esJefatura) {
      final prefijo = _prefijoOpJefatura;

      if (prefijo.isEmpty) {
        return <ProduccionModel>[];
      }

      final response = await supabase
          .from('produccion_pendiente')
          .select()
          .ilike('numero_produccion', '$prefijo%');

      datos = (response as List)
          .map(
            (e) => Map<String, dynamic>.from(e),
          )
          .toList();

      // --------------------------------------------------------
      // Segunda capa local de seguridad.
      // --------------------------------------------------------

      datos = datos.where((registro) {
        return _op(registro).toUpperCase().startsWith(prefijo);
      }).toList();
    }

    // ==========================================================
    // 3. ADMINISTRADOR / VENDEDOR / USUARIO
    // ==========================================================
    //
    // Mantiene el comportamiento existente:
    // si tiene vendedor asignado, solo ve sus producciones.
    // ==========================================================

    else {
      final vendedorActual =
          Sesion.vendedor.trim().toLowerCase();

      if (vendedorActual.isEmpty) {
        return <ProduccionModel>[];
      }

      final response = await supabase
          .from('produccion_pendiente')
          .select()
          .ilike('representante', Sesion.vendedor.trim());

      datos = (response as List)
          .map(
            (e) => Map<String, dynamic>.from(e),
          )
          .toList();

      // --------------------------------------------------------
      // Segunda capa local de seguridad.
      // --------------------------------------------------------

      datos = datos.where((registro) {
        return _normalizar(
              registro['representante'],
            ) ==
            vendedorActual;
      }).toList();
    }

    // ============================================================
    // ORDENAR POR FECHA DE ENTREGA
    // ============================================================

    datos.sort(
      (a, b) {
        final fechaA = DateTime.tryParse(
              a['fecha_entrega_estimada']?.toString() ?? '',
            ) ??
            DateTime(2100);

        final fechaB = DateTime.tryParse(
              b['fecha_entrega_estimada']?.toString() ?? '',
            ) ??
            DateTime(2100);

        return fechaA.compareTo(fechaB);
      },
    );

    // ============================================================
    // CONVERTIR A MODELO
    // ============================================================

    return datos
        .map<ProduccionModel>(
          (e) => ProduccionModel.fromMap(e),
        )
        .toList();
  }
}
