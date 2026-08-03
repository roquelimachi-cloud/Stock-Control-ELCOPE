import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/dashboard/dashboard_summary.dart';
import '../../models/dashboard/cliente_top.dart';
import '../../models/dashboard/clase_resumen.dart';
import '../../models/dashboard/producto_cliente.dart';
import '../../models/dashboard/producto_top.dart';
import '../sesion.dart';
import 'supabase_service.dart';

class DashboardService {
  final SupabaseClient db = SupabaseService.client;

  //=========================================================
  // RESUMEN GENERAL
  //=========================================================

  Future<DashboardSummary> obtenerResumen() async {
    var consulta = db.from('stock').select();

    if (Sesion.vendedor.trim().isNotEmpty) {
      consulta = consulta.eq(
        'vendedor',
        Sesion.vendedor.trim(),
      );
    }

    final datos = await consulta;

    double stockTotal = 0;
    double pesoTotal = 0;
    double valorTotal = 0;

    final clientes = <String>{};

    for (final fila in datos) {
      stockTotal += (fila['stock'] ?? 0).toDouble();
      pesoTotal += (fila['peso'] ?? 0).toDouble();
      valorTotal +=
          (fila['valor_lista_precio_dolar'] ?? 0).toDouble();

      final cliente = fila['cliente'];

      if (cliente != null &&
          cliente.toString().trim().isNotEmpty) {
        clientes.add(cliente.toString());
      }
    }

    return DashboardSummary(
      asesor: Sesion.nombre,
      stockTotal: stockTotal,
      pesoTotal: pesoTotal,
      valorStock: valorTotal,
      clientes: clientes.length,
    );
  }

  //=========================================================
  // RESUMEN POR CLASE
  //=========================================================

  Future<List<ClaseResumen>> obtenerResumenClases() async {
    var consulta = db.from('stock').select();

    if (Sesion.vendedor.trim().isNotEmpty) {
      consulta = consulta.eq(
        'vendedor',
        Sesion.vendedor.trim(),
      );
    }

    final datos = await consulta;

    final Map<String, double> clases = {};

    for (final fila in datos) {
      final clase =
          (fila['clase'] ?? 'SIN CLASE').toString();

      final monto =
          (fila['valor_lista_precio_dolar'] ?? 0)
              .toDouble();

      clases.update(
        clase,
        (value) => value + monto,
        ifAbsent: () => monto,
      );
    }

    final resultado = clases.entries
        .map(
          (e) => ClaseResumen(
            clase: e.key,
            monto: e.value,
          ),
        )
        .toList();

    resultado.sort(
      (a, b) => b.monto.compareTo(a.monto),
    );

    return resultado;
  }

  //=========================================================
  // TOP CLIENTES
  //=========================================================

  Future<List<ClienteTop>> obtenerTopClientes() async {
    var consulta = db.from('stock').select();

    if (Sesion.vendedor.trim().isNotEmpty) {
      consulta = consulta.eq(
        'vendedor',
        Sesion.vendedor.trim(),
      );
    }

    final datos = await consulta;

    final Map<String, double> clientes = {};

    for (final fila in datos) {
      final cliente =
          (fila['cliente'] ?? 'SIN CLIENTE').toString();

      final valor =
          (fila['valor_lista_precio_dolar'] ?? 0)
              .toDouble();

      clientes.update(
        cliente,
        (actual) => actual + valor,
        ifAbsent: () => valor,
      );
    }

    final resultado = clientes.entries
        .map(
          (e) => ClienteTop(
            cliente: e.key,
            valorStock: e.value,
          ),
        )
        .toList();

    resultado.sort(
      (a, b) => b.valorStock.compareTo(a.valorStock),
    );

    return resultado.take(10).toList();
  }

  //=========================================================
  // PRODUCTOS POR CLIENTE
  //=========================================================

  Future<List<ProductoCliente>> obtenerProductosCliente(
      String cliente) async {
    var consulta = db
        .from('stock')
        .select()
        .eq('cliente', cliente);

    if (Sesion.vendedor.trim().isNotEmpty) {
      consulta = consulta.eq(
        'vendedor',
        Sesion.vendedor.trim(),
      );
    }

    final datos = await consulta;

    final List<ProductoCliente> productos = [];

    for (final fila in datos) {
      productos.add(
        ProductoCliente(
          descripcion:
              fila['descripcion']?.toString() ?? '',
          stock:
              (fila['stock'] ?? 0).toDouble(),
          peso:
              (fila['peso'] ?? 0).toDouble(),
          valor:
              (fila['valor_lista_precio_dolar'] ?? 0)
                  .toDouble(),
        ),
      );
    }

    productos.sort(
      (a, b) => b.valor.compareTo(a.valor),
    );

    return productos.take(10).toList();
  }

  //=========================================================
// TOP PRODUCTOS
//=========================================================

Future<List<ProductoTop>> obtenerTopProductos() async {
  var consulta = db.from('stock').select();

  if (Sesion.vendedor.trim().isNotEmpty) {
    consulta = consulta.eq(
      'vendedor',
      Sesion.vendedor.trim(),
    );
  }

  final datos = await consulta;

  final Map<String, double> productos = {};

  for (final fila in datos) {
    final descripcion =
        (fila['descripcion'] ?? 'SIN DESCRIPCIÓN')
            .toString();

    final valor =
        (fila['valor_lista_precio_dolar'] ?? 0)
            .toDouble();

    productos.update(
      descripcion,
      (actual) => actual + valor,
      ifAbsent: () => valor,
    );
  }

  final resultado = productos.entries
      .map(
        (e) => ProductoTop(
          descripcion: e.key,
          valor: e.value,
        ),
      )
      .toList();

  resultado.sort(
    (a, b) => b.valor.compareTo(a.valor),
  );

  return resultado.take(10).toList();
}
}