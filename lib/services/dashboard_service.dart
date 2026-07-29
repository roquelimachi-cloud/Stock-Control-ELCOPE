import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/dashboard/dashboard_summary.dart';

class DashboardService {
  DashboardService._();

  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<DashboardSummary> obtenerResumen({
    required String vendedor,
  }) async {
    final data = await _supabase
        .from('stock')
        .select(
          'cliente, stock, peso, valor_lista_precio_dolar',
        )
        .eq('vendedor', vendedor);

    double stockTotal = 0;
    double pesoTotal = 0;
    double valorStock = 0;

    final clientes = <String>{};

    for (final row in data) {
      stockTotal += (row['stock'] as num?)?.toDouble() ?? 0;

      pesoTotal += (row['peso'] as num?)?.toDouble() ?? 0;

      valorStock +=
          (row['valor_lista_precio_dolar'] as num?)?.toDouble() ?? 0;

      final cliente = row['cliente']?.toString();

      if (cliente != null && cliente.trim().isNotEmpty) {
        clientes.add(cliente.trim());
      }
    }

    return DashboardSummary(
      asesor: vendedor,
      stockTotal: stockTotal,
      pesoTotal: pesoTotal,
      valorStock: valorStock,
      clientes: clientes.length,
    );
  }
}