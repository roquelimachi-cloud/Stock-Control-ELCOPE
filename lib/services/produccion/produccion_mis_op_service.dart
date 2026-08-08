import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/produccion/produccion_model.dart';
import '../sesion.dart';

class ProduccionMisOpService {
  final SupabaseClient supabase = Supabase.instance.client;

  // ============================================================
  // OBTENER VENDEDORES PERMITIDOS PARA PRODUCCIÓN
  // ============================================================
  //
  // null:
  //     Gerencia → puede ver todo.
  //
  // Set<String>:
  //     Lista de vendedores que puede visualizar.
  //
  // ============================================================

  Future<Set<String>?> _obtenerVendedoresPermitidos() async {
    // ==========================================================
    // 1. GERENCIA
    // ==========================================================
    //
    // SOLO GERENCIA puede visualizar toda la producción.
    //
    // IMPORTANTE:
    // Administrador NO significa automáticamente "ver todo".
    // ==========================================================

    if (Sesion.rol == 'Gerencia') {
      return null;
    }

    // ==========================================================
    // 2. JEFE LIMA / JEFE PROVINCIA
    // ==========================================================
    //
    // Obtienen los vendedores desde usuario_permisos.
    //
    // No hay nombres escritos manualmente.
    //
    // Además, el jefe puede visualizar su propia producción.
    // ==========================================================

    if (Sesion.rol == 'Jefe Lima' ||
        Sesion.rol == 'Jefe Provincia') {
      final permisos = await supabase
          .from('usuario_permisos')
          .select('vendedor, ver_produccion')
          .eq(
            'usuario_jefe_id',
            Sesion.idUsuario,
          )
          .eq(
            'ver_produccion',
            true,
          );

      final vendedoresPermitidos = (permisos as List)
          .map(
            (e) => e['vendedor']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '',
          )
          .where(
            (vendedor) => vendedor.isNotEmpty,
          )
          .toSet();

      // --------------------------------------------------------
      // Agregar vendedor propio del jefe
      // --------------------------------------------------------

      final vendedorPropio =
          Sesion.vendedor.trim().toLowerCase();

      if (vendedorPropio.isNotEmpty) {
        vendedoresPermitidos.add(vendedorPropio);
      }

      return vendedoresPermitidos;
    }

    // ==========================================================
    // 3. ADMINISTRADOR CON VENDEDOR
    // ==========================================================
    //
    // Ejemplo:
    //
    // Usuario: mroque
    // Rol: Administrador
    // Vendedor: Michael Roque
    //
    // Resultado:
    //
    //     { "michael roque" }
    //
    // Por lo tanto NO verá toda la producción.
    // ==========================================================

    final vendedorAdministrador =
        Sesion.vendedor.trim().toLowerCase();

    if (vendedorAdministrador.isNotEmpty) {
      return {
        vendedorAdministrador,
      };
    }

    // ==========================================================
    // 4. USUARIO SIN VENDEDOR
    // ==========================================================

    return <String>{};
  }

  // ============================================================
  // OBTENER PRODUCCIÓN PENDIENTE
  // ============================================================

  Future<List<ProduccionModel>> obtener() async {
    // ==========================================================
    // 1. OBTENER PRODUCCIÓN
    // ==========================================================

    final response = await supabase
        .from('produccion_pendiente')
        .select();

    List<Map<String, dynamic>> datos =
        (response as List)
            .map(
              (e) => Map<String, dynamic>.from(e),
            )
            .toList();

    // ==========================================================
    // 2. OBTENER VENDEDORES PERMITIDOS
    // ==========================================================

    final vendedoresPermitidos =
        await _obtenerVendedoresPermitidos();

    // ==========================================================
    // 3. GERENCIA
    // ==========================================================
    //
    // null = puede ver todo.
    // ==========================================================

    if (vendedoresPermitidos == null) {
      // No aplicar filtro.
    }

    // ==========================================================
    // 4. USUARIO SIN PERMISOS
    // ==========================================================

    else if (vendedoresPermitidos.isEmpty) {
      datos = [];
    }

    // ==========================================================
    // 5. FILTRAR PRODUCCIÓN
    // ==========================================================

    else {
      datos = datos.where((registro) {
        final representante =
            registro['representante']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

        return vendedoresPermitidos.contains(
          representante,
        );
      }).toList();
    }

    // ==========================================================
    // 6. ORDENAR POR FECHA DE ENTREGA
    // ==========================================================

    datos.sort(
      (a, b) {
        final fechaA = DateTime.tryParse(
              a['fecha_entrega_estimada']
                      ?.toString() ??
                  '',
            ) ??
            DateTime(2100);

        final fechaB = DateTime.tryParse(
              b['fecha_entrega_estimada']
                      ?.toString() ??
                  '',
            ) ??
            DateTime(2100);

        return fechaA.compareTo(
          fechaB,
        );
      },
    );

    // ==========================================================
    // 7. CONVERTIR A MODELO
    // ==========================================================

    return datos
        .map<ProduccionModel>(
          (e) => ProduccionModel.fromMap(e),
        )
        .toList();
  }
}