import 'package:flutter/material.dart';

import '../../models/produccion/produccion_model.dart';
import '../../screens/produccion/produccion_vendedor_dashboard.dart';

class ProduccionVendedorWidget extends StatelessWidget {
  final List<ProduccionModel> producciones;

  const ProduccionVendedorWidget({
    super.key,
    required this.producciones,
  });

  static const Color verdeElcope = Color(0xFF08783B);
  static const Color verdeClaro = Color(0xFFEAF5EE);
  static const Color azulAnalitico = Color(0xFF1565D8);

  List<Map<String, dynamic>> _agruparPorVendedor() {
    final Map<String, Map<String, double>> mapa = {};

    for (final produccion in producciones) {
      final vendedor = produccion.representante.trim();

      if (vendedor.isEmpty) continue;

      final valor = _toDouble(produccion.valorNeto);
      final peso = _toDouble(produccion.pesoCobre);

      mapa.putIfAbsent(
        vendedor,
        () => {'valor': 0.0, 'peso': 0.0},
      );

      mapa[vendedor]!['valor'] =
          mapa[vendedor]!['valor']! + valor;
      mapa[vendedor]!['peso'] =
          mapa[vendedor]!['peso']! + peso;
    }

    final resultado = mapa.entries.map((e) {
      return {
        'vendedor': e.key,
        'valor': e.value['valor'] ?? 0.0,
        'peso': e.value['peso'] ?? 0.0,
      };
    }).toList();

    resultado.sort(
      (a, b) =>
          (b['valor'] as double).compareTo(a['valor'] as double),
    );

    return resultado;
  }

  double _toDouble(dynamic valor) {
    if (valor == null) return 0.0;
    if (valor is num) return valor.toDouble();

    return double.tryParse(
          valor.toString().replaceAll(',', '').trim(),
        ) ??
        0.0;
  }

  String _moneda(double valor) {
    return 'US\$ ${valor.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
        )}';
  }

  String _peso(double valor) {
    return valor.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
        );
  }

  void _abrirDashboard(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProduccionVendedorDashboard(
          producciones: producciones,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final datos = _agruparPorVendedor();

    if (datos.isEmpty) {
      return Card(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Padding(
          padding: EdgeInsets.all(25),
          child: Center(
            child: Text(
              'No hay producción pendiente por vendedor.',
            ),
          ),
        ),
      );
    }

    final maximo = datos.first['valor'] as double;

    return LayoutBuilder(
      builder: (context, constraints) {
        final esMovil = constraints.maxWidth < 700;
        final cantidadVisible = datos.length > 8 ? 8 : datos.length;

        return Card(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: verdeElcope.withOpacity(.28),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _abrirDashboard(context),
            child: Padding(
              padding: EdgeInsets.all(esMovil ? 16 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: verdeClaro,
                          border: Border.all(
                            color: verdeElcope.withOpacity(.35),
                          ),
                        ),
                        child: const Icon(
                          Icons.factory_outlined,
                          color: verdeElcope,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Producción por Vendedor',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF202124),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _abrirDashboard(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: verdeElcope,
                          side: const BorderSide(
                            color: verdeElcope,
                          ),
                        ),
                        icon: const Icon(
                          Icons.open_in_new,
                          size: 18,
                        ),
                        label: const Text('Vista preliminar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: const BoxDecoration(
                      color: verdeElcope,
                    ),
                    child: const Text(
                      'PRODUCCIÓN POR VENDEDOR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(
                    cantidadVisible,
                    (index) {
                      final item = datos[index];
                      final valor = item['valor'] as double;
                      final peso = item['peso'] as double;
                      final porcentaje = maximo <= 0
                          ? 0.0
                          : (valor / maximo).clamp(0.0, 1.0);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 13),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: azulAnalitico,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item['vendedor'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _moneda(valor),
                                      style: const TextStyle(
                                        color: verdeElcope,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '${_peso(peso)} Kg',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Stack(
                                children: [
                                  Container(
                                    height: 9,
                                    width: double.infinity,
                                    color: Colors.grey.shade200,
                                  ),
                                  FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: porcentaje,
                                    child: Container(
                                      height: 9,
                                      color: azulAnalitico,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (datos.length > 8)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _abrirDashboard(context),
                        style: TextButton.styleFrom(
                          foregroundColor: verdeElcope,
                        ),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Ver todos'),
                      ),
                    ),
                  const SizedBox(height: 2),
                  const Text(
                    'Haz clic para abrir la vista preliminar completa.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black45,
                      fontStyle: FontStyle.italic,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
