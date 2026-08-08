import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/dashboard/dashboard_summary.dart';

class DashboardService {
  DashboardService._();

  static final SupabaseClient _supabase =
      Supabase.instance.client;

  // =========================================================
  // CONVERSIÓN SEGURA DE VALORES
  // =========================================================

  static double _toDouble(dynamic valor) {
    if (valor == null) {
      return 0;
    }

    if (valor is num) {
      return valor.toDouble();
    }

    String texto = valor.toString().trim();

    if (texto.isEmpty) {
      return 0;
    }

    texto = texto
        .replaceAll('US\$', '')
        .replaceAll('\$', '')
        .replaceAll(' ', '');

    // Soporta:
    // 1250.50
    // 1,250.50
    // 1250,50
    // 1.250,50

    if (texto.contains(',') && texto.contains('.')) {
      final ultimaComa = texto.lastIndexOf(',');
      final ultimoPunto = texto.lastIndexOf('.');

      if (ultimaComa > ultimoPunto) {
        // 1.250,50
        texto = texto
            .replaceAll('.', '')
            .replaceAll(',', '.');
      } else {
        // 1,250.50
        texto = texto.replaceAll(',', '');
      }
    } else if (texto.contains(',')) {
      // 1250,50
      texto = texto.replaceAll(',', '.');
    }

    return double.tryParse(texto) ?? 0;
  }

  // =========================================================
  // RESUMEN
  // =========================================================

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
      stockTotal += _toDouble(row['stock']);

      pesoTotal += _toDouble(row['peso']);

      valorStock += _toDouble(
        row['valor_lista_precio_dolar'],
      );

      final cliente = row['cliente']?.toString();

      if (cliente != null &&
          cliente.trim().isNotEmpty) {
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