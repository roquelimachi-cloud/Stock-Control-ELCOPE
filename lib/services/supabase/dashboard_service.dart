import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/dashboard/dashboard_summary.dart';
import '../../models/dashboard/cliente_top.dart';
import '../sesion.dart';
import 'supabase_service.dart';

class DashboardService {
  final SupabaseClient db = SupabaseService.client;

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

    for (final item in datos) {
      final cliente =
          (item['cliente'] ?? 'SIN CLIENTE').toString();

      final valor = double.tryParse(
            item['valor_lista_precio_dolar'].toString(),
          ) ??
          0;

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
}