import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/produccion/produccion_model.dart';
import '../../services/pdf/pdf_vendedor_dashboard_service.dart';
import '../../services/sesion.dart';

class VendedorResumen {
  final String vendedor;
  final int producciones;
  final double monto;
  final double peso;

  const VendedorResumen({
    required this.vendedor,
    required this.producciones,
    required this.monto,
    required this.peso,
  });
}

class ProduccionVendedorDashboard extends StatelessWidget {
  final List<ProduccionModel> producciones;

  const ProduccionVendedorDashboard({
    super.key,
    required this.producciones,
  });

  static const Color verdeElcope = Color(0xFF08783B);
  static const Color verdeClaro = Color(0xFFEAF5EE);

  List<VendedorResumen> _resumen() {
    final mapa = <String, _Acumulador>{};

    for (final op in producciones) {
      final vendedor = op.representante.trim();

      if (vendedor.isEmpty) continue;

      final item = mapa.putIfAbsent(
        vendedor,
        _Acumulador.new,
      );

      item.producciones++;
      item.monto += _toDouble(op.valorNeto);
      item.peso += _toDouble(op.pesoCobre);
    }

    final resultado = mapa.entries
        .map(
          (e) => VendedorResumen(
            vendedor: e.key,
            producciones: e.value.producciones,
            monto: e.value.monto,
            peso: e.value.peso,
          ),
        )
        .toList();

    resultado.sort(
      (a, b) => b.monto.compareTo(a.monto),
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
    return 'US\$ ${NumberFormat('#,##0.00', 'en_US').format(valor)}';
  }

  String _numero(double valor) {
    return NumberFormat('#,##0.00', 'en_US').format(valor);
  }

  @override
  Widget build(BuildContext context) {
    final data = _resumen();

    final totalProducciones = producciones.length;
    final totalMonto = producciones.fold<double>(
      0,
      (suma, op) => suma + _toDouble(op.valorNeto),
    );
    final totalPeso = producciones.fold<double>(
      0,
      (suma, op) => suma + _toDouble(op.pesoCobre),
    );

    final nombre = Sesion.nombre.trim().isEmpty
        ? 'USUARIO'
        : Sesion.nombre;

    final rol = Sesion.rol.trim().isEmpty
        ? 'USUARIO'
        : Sesion.rol;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: verdeElcope,
        elevation: 0,
        leading: const BackButton(),
        title: const Text(
          'PRODUCCIÓN POR VENDEDOR',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: verdeElcope,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await PdfVendedorDashboardService().imprimir(
                  vendedores: data
                      .map(
                        (e) => VendedorResumenPdf(
                          vendedor: e.vendedor,
                          producciones: e.producciones,
                          monto: e.monto,
                          peso: e.peso,
                        ),
                      )
                      .toList(),
                  totalVendedores: data.length,
                  totalProducciones: totalProducciones,
                  totalMonto: totalMonto,
                  totalPeso: totalPeso,
                  usuario: nombre,
                  rol: rol,
                );
              },
              icon: const Icon(Icons.print_outlined),
              label: const Text('IMPRIMIR'),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final movil = constraints.maxWidth < 760;
          final tablet =
              constraints.maxWidth >= 760 &&
              constraints.maxWidth < 1150;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              movil ? 12 : 28,
              8,
              movil ? 12 : 28,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cabecera(
                  movil: movil,
                  usuario: nombre,
                  rol: rol,
                ),
                const SizedBox(height: 18),
                _kpis(
                  movil: movil,
                  tablet: tablet,
                  totalVendedores: data.length,
                  totalProducciones: totalProducciones,
                  totalMonto: totalMonto,
                  totalPeso: totalPeso,
                ),
                const SizedBox(height: 18),
                _ranking(
                  data: data,
                  movil: movil,
                ),
                const SizedBox(height: 18),
                _detalle(
                  data: data,
                  totalMonto: totalMonto,
                  totalPeso: totalPeso,
                  movil: movil,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: const BoxDecoration(
                    color: verdeClaro,
                    border: Border(
                      top: BorderSide(
                        color: verdeElcope,
                        width: 1.2,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: verdeElcope,
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Los datos mostrados son preliminares y pueden variar.',
                          style: TextStyle(
                            color: verdeElcope,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!movil)
                        const Text(
                          'www.elcope.com.pe',
                          style: TextStyle(
                            color: verdeElcope,
                            fontWeight: FontWeight.w900,
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
    );
  }

  Widget _cabecera({
    required bool movil,
    required String usuario,
    required String rol,
  }) {
    if (movil) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _logo(),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'ELCOPE',
                  style: TextStyle(
                    color: verdeElcope,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'PRODUCCIÓN POR VENDEDOR',
            style: TextStyle(
              color: verdeElcope,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'Vista preliminar',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Usuario: $usuario  •  Rol: $rol',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Container(height: 3, color: verdeElcope),
        ],
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _logo(),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ELCOPE',
                    style: TextStyle(
                      color: verdeElcope,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'EXCELENCIA EN CONDUCTORES ELÉCTRICOS',
                    style: TextStyle(
                      color: verdeElcope,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(
                    DateTime.now(),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  'Usuario: $usuario',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Rol: $rol',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 5),
        const Text(
          'PRODUCCIÓN POR VENDEDOR',
          style: TextStyle(
            color: verdeElcope,
            fontSize: 29,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Text(
          'Vista preliminar',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(height: 3, color: verdeElcope),
      ],
    );
  }

  Widget _logo() {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: verdeElcope,
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.center,
      child: const Text(
        'E',
        style: TextStyle(
          color: Colors.white,
          fontSize: 39,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _kpis({
    required bool movil,
    required bool tablet,
    required int totalVendedores,
    required int totalProducciones,
    required double totalMonto,
    required double totalPeso,
  }) {
    final items = [
      _KpiData(
        Icons.groups_outlined,
        'Total Vendedores',
        '$totalVendedores',
      ),
      _KpiData(
        Icons.inventory_2_outlined,
        'Total Producciones',
        '$totalProducciones',
      ),
      _KpiData(
        Icons.attach_money,
        'Monto Total',
        _moneda(totalMonto),
      ),
      _KpiData(
        Icons.scale_outlined,
        'Peso Total',
        '${_numero(totalPeso)} Kg',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnas = movil ? 1 : (tablet ? 2 : 4);
        final gap = 14.0;
        final ancho =
            (constraints.maxWidth - ((columnas - 1) * gap)) /
                columnas;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map(
                (e) => SizedBox(
                  width: ancho,
                  child: _kpiCard(e),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _kpiCard(_KpiData item) {
    return Container(
      height: 94,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: verdeElcope.withOpacity(.30),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: verdeClaro,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.icon,
              color: verdeElcope,
              size: 29,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.titulo,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.valor,
                    style: const TextStyle(
                      color: verdeElcope,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ranking({
    required List<VendedorResumen> data,
    required bool movil,
  }) {
    final maximo = data.isEmpty
        ? 0.0
        : data.first.monto;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: verdeElcope.withOpacity(.45),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: verdeElcope,
            padding: const EdgeInsets.symmetric(
              vertical: 10,
              horizontal: 12,
            ),
            child: const Text(
              'PRODUCCIÓN POR VENDEDOR',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              movil ? 12 : 24,
              15,
              movil ? 12 : 24,
              8,
            ),
            child: Column(
              children: List.generate(data.length, (index) {
                final e = data[index];
                final porcentaje = maximo <= 0
                    ? 0.0
                    : (e.monto / maximo).clamp(0.0, 1.0);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: verdeElcope,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: movil ? 110 : 180,
                        child: Text(
                          e.vendedor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Stack(
                            children: [
                              Container(
                                height: 13,
                                color: Colors.grey.shade200,
                              ),
                              FractionallySizedBox(
                                widthFactor: porcentaje,
                                child: Container(
                                  height: 13,
                                  color: verdeElcope,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: movil ? 92 : 115,
                        child: Text(
                          _moneda(e.monto),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: verdeElcope,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (!movil) ...[
                        const SizedBox(width: 14),
                        SizedBox(
                          width: 95,
                          child: Text(
                            '${_numero(e.peso)} Kg',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detalle({
    required List<VendedorResumen> data,
    required double totalMonto,
    required double totalPeso,
    required bool movil,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: verdeElcope.withOpacity(.45),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: verdeElcope,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: const Text(
              'DETALLE POR VENDEDOR',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ),
          if (movil)
            ...data.map(
              (e) => _detalleMovil(
                e,
                totalMonto,
                totalPeso,
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(verdeClaro),
                dataRowMinHeight: 42,
                dataRowMaxHeight: 48,
                columnSpacing: 25,
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Vendedor')),
                  DataColumn(label: Text('Producciones')),
                  DataColumn(label: Text('Monto (US\$)')),
                  DataColumn(label: Text('% Monto')),
                  DataColumn(label: Text('Peso (Kg)')),
                  DataColumn(label: Text('% Peso')),
                ],
                rows: List.generate(data.length, (index) {
                  final e = data[index];
                  final pm = totalMonto == 0
                      ? 0.0
                      : e.monto / totalMonto * 100;
                  final pp = totalPeso == 0
                      ? 0.0
                      : e.peso / totalPeso * 100;

                  return DataRow(
                    cells: [
                      DataCell(Text('${index + 1}')),
                      DataCell(
                        Text(
                          e.vendedor,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      DataCell(Text('${e.producciones}')),
                      DataCell(Text(_moneda(e.monto))),
                      DataCell(
                        Text('${pm.toStringAsFixed(2)}%'),
                      ),
                      DataCell(
                        Text('${_numero(e.peso)} Kg'),
                      ),
                      DataCell(
                        Text('${pp.toStringAsFixed(2)}%'),
                      ),
                    ],
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _detalleMovil(
    VendedorResumen e,
    double totalMonto,
    double totalPeso,
  ) {
    final pm = totalMonto == 0
        ? 0.0
        : e.monto / totalMonto * 100;
    final pp = totalPeso == 0
        ? 0.0
        : e.peso / totalPeso * 100;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            e.vendedor,
            style: const TextStyle(
              color: verdeElcope,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          _linea('Producciones', '${e.producciones}'),
          _linea('Monto', _moneda(e.monto)),
          _linea('% Monto', '${pm.toStringAsFixed(2)}%'),
          _linea('Peso', '${_numero(e.peso)} Kg'),
          _linea('% Peso', '${pp.toStringAsFixed(2)}%'),
        ],
      ),
    );
  }

  Widget _linea(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            titulo,
            style: const TextStyle(color: Colors.black54),
          ),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Acumulador {
  int producciones = 0;
  double monto = 0;
  double peso = 0;
}

class _KpiData {
  final IconData icon;
  final String titulo;
  final String valor;

  const _KpiData(
    this.icon,
    this.titulo,
    this.valor,
  );
}
