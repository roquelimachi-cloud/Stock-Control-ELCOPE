import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'services/facturacion_importacion_service.dart';

class FacturacionImportacionPage extends StatefulWidget {
  const FacturacionImportacionPage({super.key});

  @override
  State<FacturacionImportacionPage> createState() =>
      _FacturacionImportacionPageState();
}

class _FacturacionImportacionPageState
    extends State<FacturacionImportacionPage> {
  final _service = FacturacionImportacionService();

  PlatformFile? _archivo;
  Map<String, dynamic>? _lectura;

  bool _cargando = false;
  int _cargadas = 0;
  String? _mensaje;
  String? _error;

  Future<void> _seleccionar() async {
    setState(() {
      _cargando = true;
      _error = null;
      _mensaje = null;
    });

    try {
      final archivo = await _service.seleccionarExcel();
      if (archivo == null) return;

      final lectura = await _service.leerExcel(archivo);

      if (!mounted) return;
      setState(() {
        _archivo = archivo;
        _lectura = lectura;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargar() async {
    final lectura = _lectura;
    if (lectura == null) return;

    setState(() {
      _cargando = true;
      _cargadas = 0;
      _error = null;
      _mensaje = null;
    });

    try {
      final importacionId = await _service.crearImportacion(
        nombreArchivo: lectura['archivo'].toString(),
        totalFilas: lectura['total_filas'] as int,
        periodoDesde: lectura['periodo_desde']?.toString(),
        periodoHasta: lectura['periodo_hasta']?.toString(),
      );

      final filas =
          (lectura['filas'] as List).cast<Map<String, dynamic>>();

      await _service.cargarStaging(
        importacionId: importacionId,
        filas: filas,
        onProgress: (cargadas, total) {
          if (!mounted) return;
          setState(() => _cargadas = cargadas);
        },
      );

      final resultado = await _service.procesarImportacion(importacionId);

      if (!mounted) return;

      setState(() {
        _mensaje =
            'Importación $importacionId procesada. '
            'Facturas: ${resultado['facturas'] ?? 0}. '
            'Detalles: ${resultado['detalles'] ?? 0}.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lectura = _lectura;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Facturación CRM'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Carga de facturación',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'El Excel se carga primero a staging y recién después '
                          'se procesa a facturas y detalles.',
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _cargando ? null : _seleccionar,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Seleccionar Excel'),
                        ),
                        if (_archivo != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _archivo!.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (lectura != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 16,
                        children: [
                          _dato('Filas', '${lectura['total_filas']}'),
                          _dato('Facturas', '${lectura['facturas']}'),
                          _dato('Clientes', '${lectura['clientes']}'),
                          _dato('Vendedores', '${lectura['vendedores']}'),
                          _dato(
                            'Desde',
                            '${lectura['periodo_desde'] ?? '-'}',
                          ),
                          _dato(
                            'Hasta',
                            '${lectura['periodo_hasta'] ?? '-'}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _cargando ? null : _cargar,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(
                      _cargando && _cargadas > 0
                          ? 'Cargando $_cargadas/${lectura['total_filas']}...'
                          : 'Cargar y procesar',
                    ),
                  ),
                ],
                if (_mensaje != null) ...[
                  const SizedBox(height: 16),
                  _mensajeBox(_mensaje!, false),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _mensajeBox(_error!, true),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dato(String titulo, String valor) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mensajeBox(String mensaje, bool error) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: error ? Colors.red.shade50 : Colors.green.shade50,
      ),
      child: Text(mensaje),
    );
  }
}
