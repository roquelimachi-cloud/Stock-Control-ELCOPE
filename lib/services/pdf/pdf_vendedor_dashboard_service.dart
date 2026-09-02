import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class VendedorResumenPdf {
  final String vendedor;
  final int producciones;
  final double monto;
  final double peso;

  const VendedorResumenPdf({
    required this.vendedor,
    required this.producciones,
    required this.monto,
    required this.peso,
  });
}

class PdfVendedorDashboardService {
  static const PdfColor verdeElcope =
      PdfColor.fromInt(0xFF08783B);

  static const PdfColor verdeClaro =
      PdfColor.fromInt(0xFFEAF5EE);

  Future<void> imprimir({
    required List<VendedorResumenPdf> vendedores,
    required int totalVendedores,
    required int totalProducciones,
    required double totalMonto,
    required double totalPeso,
    String usuario = '',
    String rol = '',
  }) async {
    final pdf = pw.Document();

    final money = NumberFormat('#,##0.00', 'en_US');
    final number = NumberFormat('#,##0.00', 'en_US');

    double maxMonto = 0;

    for (final vendedor in vendedores) {
      if (vendedor.monto > maxMonto) {
        maxMonto = vendedor.monto;
      }
    }

    final fecha =
        DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(22),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _encabezado(
                fecha: fecha,
                usuario: usuario,
                rol: rol,
              ),
              pw.SizedBox(height: 11),
              pw.Row(
                children: [
                  _kpi(
                    icon: '●',
                    titulo: 'Total Vendedores',
                    valor: totalVendedores.toString(),
                  ),
                  pw.SizedBox(width: 10),
                  _kpi(
                    icon: '▣',
                    titulo: 'Total Producciones',
                    valor: totalProducciones.toString(),
                  ),
                  pw.SizedBox(width: 10),
                  _kpi(
                    icon: '\$',
                    titulo: 'Monto Total',
                    valor: 'US\$ ${money.format(totalMonto)}',
                  ),
                  pw.SizedBox(width: 10),
                  _kpi(
                    icon: '⚖',
                    titulo: 'Peso Total',
                    valor: '${number.format(totalPeso)} Kg',
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              _ranking(
                vendedores: vendedores,
                maxMonto: maxMonto,
                money: money,
                number: number,
              ),
              pw.SizedBox(height: 12),
              _tabla(
                vendedores: vendedores,
                totalMonto: totalMonto,
                totalPeso: totalPeso,
                money: money,
                number: number,
              ),
              pw.Spacer(),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: const pw.BoxDecoration(
                  color: verdeClaro,
                  border: pw.Border(
                    top: pw.BorderSide(
                      color: verdeElcope,
                      width: 1,
                    ),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment:
                      pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Los datos mostrados son preliminares y pueden variar.',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: verdeElcope,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                    pw.Text(
                      'www.elcope.com.pe',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: verdeElcope,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
    );
  }

  pw.Widget _encabezado({
    required String fecha,
    required String usuario,
    required String rol,
  }) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _logo(),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ELCOPE',
                    style: pw.TextStyle(
                      color: verdeElcope,
                      fontSize: 25,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'EXCELENCIA EN CONDUCTORES ELÉCTRICOS',
                    style: pw.TextStyle(
                      color: verdeElcope,
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  fecha,
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Usuario: ${usuario.isEmpty ? 'USUARIO' : usuario}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.Text(
                  'Rol: ${rol.isEmpty ? 'USUARIO' : rol}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'PRODUCCIÓN POR VENDEDOR',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            color: verdeElcope,
            fontSize: 19,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Vista preliminar',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          height: 2,
          color: verdeElcope,
        ),
      ],
    );
  }

  pw.Widget _logo() {
    return pw.Container(
      width: 45,
      height: 45,
      decoration: pw.BoxDecoration(
        color: verdeElcope,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      alignment: pw.Alignment.center,
      child: pw.Text(
        'E',
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 28,
          fontWeight: pw.FontWeight.bold,
          fontStyle: pw.FontStyle.italic,
        ),
      ),
    );
  }

  pw.Widget _kpi({
    required String icon,
    required String titulo,
    required String valor,
  }) {
    return pw.Expanded(
      child: pw.Container(
        height: 53,
        padding: const pw.EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 7,
        ),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(
            color: verdeElcope,
            width: .6,
          ),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Row(
          children: [
            pw.Container(
              width: 30,
              height: 30,
              decoration: pw.BoxDecoration(
                color: verdeClaro,
                borderRadius: pw.BorderRadius.circular(5),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text(
                icon,
                style: pw.TextStyle(
                  color: verdeElcope,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(width: 7),
            pw.Expanded(
              child: pw.Column(
                mainAxisAlignment:
                    pw.MainAxisAlignment.center,
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    titulo,
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    valor,
                    maxLines: 1,
                    style: pw.TextStyle(
                      color: verdeElcope,
                      fontSize: 10.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _ranking({
    required List<VendedorResumenPdf> vendedores,
    required double maxMonto,
    required NumberFormat money,
    required NumberFormat number,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: verdeElcope,
          width: .7,
        ),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 7),
            color: verdeElcope,
            child: pw.Text(
              'PRODUCCIÓN POR VENDEDOR',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(12, 9, 12, 4),
            child: pw.Column(
              children: List.generate(vendedores.length, (index) {
                final e = vendedores[index];
                final proporcion = maxMonto <= 0
                    ? 0.0
                    : (e.monto / maxMonto).clamp(0.0, 1.0);

                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 18,
                        height: 18,
                        decoration: const pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          color: verdeElcope,
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          '${index + 1}',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      pw.SizedBox(
                        width: 88,
                        child: pw.Text(
                          e.vendedor,
                          maxLines: 1,
                          overflow: pw.TextOverflow.clip,
                          style: const pw.TextStyle(fontSize: 7.5),
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Expanded(
                        child: pw.Container(
                          height: 7,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey200,
                            borderRadius:
                                pw.BorderRadius.circular(3),
                          ),
                          child: pw.Align(
                            alignment: pw.Alignment.centerLeft,
                            child: pw.Container(
                              width: 250 * proporcion,
                              height: 7,
                              decoration: pw.BoxDecoration(
                                color: verdeElcope,
                                borderRadius:
                                    pw.BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.SizedBox(
                        width: 75,
                        child: pw.Text(
                          'US\$ ${money.format(e.monto)}',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            color: verdeElcope,
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 7),
                      pw.SizedBox(
                        width: 60,
                        child: pw.Text(
                          '${number.format(e.peso)} Kg',
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(
                            fontSize: 7,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ),
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

  pw.Widget _tabla({
    required List<VendedorResumenPdf> vendedores,
    required double totalMonto,
    required double totalPeso,
    required NumberFormat money,
    required NumberFormat number,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: verdeElcope,
          width: .7,
        ),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 7),
            color: verdeElcope,
            child: pw.Text(
              'DETALLE POR VENDEDOR',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(
              color: PdfColors.grey400,
              width: .5,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: verdeClaro,
            ),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 7.3,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7.1),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 4.5,
            ),
            headers: const [
              '#',
              'Vendedor',
              'Producciones',
              'Monto (US\$)',
              '% Monto',
              'Peso (Kg)',
              '% Peso',
            ],
            data: List.generate(vendedores.length, (index) {
              final e = vendedores[index];

              final porcentajeMonto = totalMonto == 0
                  ? 0.0
                  : e.monto / totalMonto * 100;

              final porcentajePeso = totalPeso == 0
                  ? 0.0
                  : e.peso / totalPeso * 100;

              return [
                '${index + 1}',
                e.vendedor,
                e.producciones.toString(),
                'US\$ ${money.format(e.monto)}',
                '${porcentajeMonto.toStringAsFixed(2)}%',
                '${number.format(e.peso)} Kg',
                '${porcentajePeso.toStringAsFixed(2)}%',
              ];
            }),
          ),
        ],
      ),
    );
  }
}
