import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/produccion/produccion_model.dart';
import '../../services/pdf/pdf_canal_dashboard_service.dart';
import '../../services/sesion.dart';

class CanalResumen {
  final String canal;
  final int producciones;
  final double monto;
  final double peso;

  const CanalResumen({
    required this.canal,
    required this.producciones,
    required this.monto,
    required this.peso,
  });
}

class ProduccionCanalDashboard extends StatelessWidget {
  final List<ProduccionModel> producciones;

  const ProduccionCanalDashboard({
    super.key,
    required this.producciones,
  });

  static const Color verdeElcope = Color(0xFF08783B);
  static const Color verdeClaro = Color(0xFFEAF5EE);

  static const List<String> _ordenCanales = [
    'LIMA',
    'PROVINCIA',
    'LICITACION',
    'CADENAS',
  ];

  List<CanalResumen> _resumen() {
    final mapa = <String, _Acumulador>{};

    for (final op in producciones) {
      final canal = op.canal.trim().toUpperCase().isEmpty
          ? 'SIN CANAL'
          : op.canal.trim().toUpperCase();

      final item = mapa.putIfAbsent(canal, _Acumulador.new);
      item.producciones++;
      item.monto += op.valorNeto ?? 0;
      item.peso += op.pesoCobre ?? 0;
    }

    final resultado = mapa.entries
        .map(
          (e) => CanalResumen(
            canal: e.key,
            producciones: e.value.producciones,
            monto: e.value.monto,
            peso: e.value.peso,
          ),
        )
        .toList();

    resultado.sort((a, b) {
      final ia = _ordenCanales.indexOf(a.canal);
      final ib = _ordenCanales.indexOf(b.canal);

      if (ia != -1 && ib != -1) return ia.compareTo(ib);
      if (ia != -1) return -1;
      if (ib != -1) return 1;

      return b.monto.compareTo(a.monto);
    });

    return resultado;
  }

  String _moneda(double valor) =>
      'US\$ ${NumberFormat('#,##0.00', 'en_US').format(valor)}';

  String _numero(double valor) =>
      NumberFormat('#,##0.00', 'en_US').format(valor);

  @override
  Widget build(BuildContext context) {
    final data = _resumen();

    final totalProducciones = producciones.length;
    final totalMonto = producciones.fold<double>(
      0,
      (suma, op) => suma + (op.valorNeto ?? 0),
    );
    final totalPeso = producciones.fold<double>(
      0,
      (suma, op) => suma + (op.pesoCobre ?? 0),
    );

    final nombre = Sesion.nombre.trim().isEmpty ? 'USUARIO' : Sesion.nombre;
    final rol = Sesion.rol.trim().isEmpty ? 'USUARIO' : Sesion.rol;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: verdeElcope,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: const BackButton(),
        title: const Text(
          'PRODUCCIÓN POR CANAL',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: .3,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Imprimir reporte',
            icon: const Icon(Icons.print_outlined),
            onPressed: () async {
              final servicio = PdfCanalDashboardService();

              await servicio.imprimir(
                canales: data
                    .map(
                      (e) => CanalResumenPdf(
                        canal: e.canal,
                        producciones: e.producciones,
                        monto: e.monto,
                        peso: e.peso,
                      ),
                    )
                    .toList(),
                totalProducciones: totalProducciones,
                totalMonto: totalMonto,
                totalPeso: totalPeso,
                usuario: nombre,
                rol: rol,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final ancho = constraints.maxWidth;
          final movil = ancho < 760;
          final tablet = ancho >= 760 && ancho < 1150;

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
                  nombre: nombre,
                  rol: rol,
                ),
                const SizedBox(height: 18),
                _kpis(
                  movil: movil,
                  tablet: tablet,
                  totalProducciones: totalProducciones,
                  totalMonto: totalMonto,
                  totalPeso: totalPeso,
                  canales: data.length,
                ),
                const SizedBox(height: 18),
                if (movil)
                  Column(
                    children: [
                      _panelBarras(
                        titulo: 'MONTO POR CANAL',
                        canales: data,
                        maximo: data.isEmpty
                            ? 0
                            : data
                                .map((e) => e.monto)
                                .reduce((a, b) => a > b ? a : b),
                        obtenerValor: (e) => e.monto,
                        formatear: (e) => _moneda(e),
                      ),
                      const SizedBox(height: 14),
                      _panelBarras(
                        titulo: 'PESO POR CANAL',
                        canales: data,
                        maximo: data.isEmpty
                            ? 0
                            : data
                                .map((e) => e.peso)
                                .reduce((a, b) => a > b ? a : b),
                        obtenerValor: (e) => e.peso,
                        formatear: (e) => '${_numero(e)} Kg',
                      ),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _panelBarras(
                          titulo: 'MONTO POR CANAL',
                          canales: data,
                          maximo: data.isEmpty
                              ? 0
                              : data
                                  .map((e) => e.monto)
                                  .reduce((a, b) => a > b ? a : b),
                          obtenerValor: (e) => e.monto,
                          formatear: (e) => _moneda(e),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _panelBarras(
                          titulo: 'PESO POR CANAL',
                          canales: data,
                          maximo: data.isEmpty
                              ? 0
                              : data
                                  .map((e) => e.peso)
                                  .reduce((a, b) => a > b ? a : b),
                          obtenerValor: (e) => e.peso,
                          formatear: (e) => '${_numero(e)} Kg',
                        ),
                      ),
                    ],
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
                  child: const Text(
                    'Los datos mostrados son preliminares y pueden variar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: verdeElcope,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                    ),
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
    required String nombre,
    required String rol,
  }) {
    if (movil) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _logoElcope(size: 48),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ELCOPE',
                      style: TextStyle(
                        color: verdeElcope,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .5,
                      ),
                    ),
                    Text(
                      'EXCELENCIA EN CONDUCTORES ELÉCTRICOS',
                      style: TextStyle(
                        color: verdeElcope,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'PRODUCCIÓN POR CANAL',
            style: TextStyle(
              color: verdeElcope,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'Dashboard preliminar',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Usuario: $nombre  •  Rol: $rol',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 3, color: verdeElcope),
        ],
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _logoElcope(size: 62),
            const SizedBox(width: 14),
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
                      letterSpacing: .7,
                    ),
                  ),
                  Text(
                    'EXCELENCIA EN CONDUCTORES ELÉCTRICOS',
                    style: TextStyle(
                      color: verdeElcope,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .3,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Usuario: $nombre',
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
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'PRODUCCIÓN POR CANAL',
            style: TextStyle(
              color: verdeElcope,
              fontSize: 29,
              fontWeight: FontWeight.w900,
              letterSpacing: .4,
            ),
          ),
        ),
        const Center(
          child: Text(
            'Dashboard preliminar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(height: 3, color: verdeElcope),
      ],
    );
  }

  Widget _logoElcope({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: verdeElcope,
        borderRadius: BorderRadius.circular(size * .08),
      ),
      alignment: Alignment.center,
      child: Text(
        'E',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * .62,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _kpis({
    required bool movil,
    required bool tablet,
    required int totalProducciones,
    required double totalMonto,
    required double totalPeso,
    required int canales,
  }) {
    final items = [
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
      _KpiData(
        Icons.pie_chart_outline,
        'Canales',
        '$canales',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnas = movil ? 1 : (tablet ? 2 : 4);
        final espacio = 14.0;
        final ancho =
            (constraints.maxWidth - ((columnas - 1) * espacio)) / columnas;

        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: items.map((item) {
            return SizedBox(
              width: ancho,
              child: _kpiCard(item),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _kpiCard(_KpiData item) {
    return Container(
      height: 106,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: verdeElcope.withOpacity(.30),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: verdeClaro,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.icon,
              color: verdeElcope,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.valor,
                    style: const TextStyle(
                      color: verdeElcope,
                      fontSize: 22,
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

  Widget _panelBarras({
    required String titulo,
    required List<CanalResumen> canales,
    required double maximo,
    required double Function(CanalResumen) obtenerValor,
    required String Function(double) formatear,
  }) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: verdeElcope.withOpacity(.45),
          width: 1.1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            color: verdeElcope,
            child: Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: .2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 2),
            child: Column(
              children: canales.map((e) {
                final valor = obtenerValor(e);
                final proporcion = maximo <= 0
                    ? 0.0
                    : (valor / maximo).clamp(0.0, 1.0);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 110,
                            child: Text(
                              e.canal,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              formatear(valor),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Stack(
                          children: [
                            Container(
                              height: 12,
                              color: Colors.grey.shade200,
                            ),
                            FractionallySizedBox(
                              widthFactor: proporcion,
                              child: Container(
                                height: 12,
                                color: verdeElcope,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detalle({
    required List<CanalResumen> data,
    required double totalMonto,
    required double totalPeso,
    required bool movil,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: verdeElcope.withOpacity(.45),
          width: 1.1,
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
              horizontal: 14,
              vertical: 10,
            ),
            child: const Text(
              'DETALLE POR CANAL',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (movil)
            _detalleMovil(
              data: data,
              totalMonto: totalMonto,
              totalPeso: totalPeso,
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(verdeClaro),
                dataRowMinHeight: 42,
                dataRowMaxHeight: 48,
                columnSpacing: 28,
                headingTextStyle: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
                columns: const [
                  DataColumn(label: Text('Canal')),
                  DataColumn(label: Text('OP')),
                  DataColumn(label: Text('Monto')),
                  DataColumn(label: Text('% Monto')),
                  DataColumn(label: Text('Peso')),
                  DataColumn(label: Text('% Peso')),
                ],
                rows: data.map((e) {
                  final porcentajeMonto =
                      totalMonto == 0 ? 0 : e.monto / totalMonto * 100;
                  final porcentajePeso =
                      totalPeso == 0 ? 0 : e.peso / totalPeso * 100;

                  return DataRow(
                    cells: [
                      DataCell(Text(
                        e.canal,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      )),
                      DataCell(Text('${e.producciones}')),
                      DataCell(Text(_moneda(e.monto))),
                      DataCell(Text('${porcentajeMonto.toStringAsFixed(1)}%')),
                      DataCell(Text('${_numero(e.peso)} Kg')),
                      DataCell(Text('${porcentajePeso.toStringAsFixed(1)}%')),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _detalleMovil({
    required List<CanalResumen> data,
    required double totalMonto,
    required double totalPeso,
  }) {
    return Column(
      children: data.map((e) {
        final porcentajeMonto =
            totalMonto == 0 ? 0 : e.monto / totalMonto * 100;
        final porcentajePeso =
            totalPeso == 0 ? 0 : e.peso / totalPeso * 100;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFE0E0E0)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.canal,
                style: const TextStyle(
                  color: verdeElcope,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              _datoMovil('OP', '${e.producciones}'),
              _datoMovil('Monto', _moneda(e.monto)),
              _datoMovil(
                '% Monto',
                '${porcentajeMonto.toStringAsFixed(1)}%',
              ),
              _datoMovil('Peso', '${_numero(e.peso)} Kg'),
              _datoMovil(
                '% Peso',
                '${porcentajePeso.toStringAsFixed(1)}%',
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _datoMovil(String titulo, String valor) {
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

  const _KpiData(this.icon, this.titulo, this.valor);
}
