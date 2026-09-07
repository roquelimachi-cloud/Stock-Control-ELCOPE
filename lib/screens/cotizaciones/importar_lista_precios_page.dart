import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/sesion.dart';

class ImportarListaPreciosPage extends StatefulWidget {
  const ImportarListaPreciosPage({super.key});

  @override
  State<ImportarListaPreciosPage> createState() => _ImportarListaPreciosPageState();
}

class _ImportarListaPreciosPageState extends State<ImportarListaPreciosPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  String _archivo = 'Ningún archivo seleccionado';
  String _hoja = '';
  String _estado = 'Seleccione el Excel de la lista de precios.';
  bool _procesando = false;
  bool _puedeImportar = false;
  bool _reemplazarActual = true;

  List<Map<String, dynamic>> _todos = [];
  List<Map<String, dynamic>> _registros = [];
  List<String> _columnasFaltantes = [];
  int _totalFilasExcel = 0;
  int _totalValidos = 0;
  int _totalDuplicados = 0;

  Future<void> _seleccionarExcel() async {
    if (_procesando) return;

    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );
      if (resultado == null) return;

      final archivo = resultado.files.single;
      if (archivo.bytes == null || archivo.bytes!.isEmpty) {
        _mensaje('No se pudieron leer los datos del archivo.');
        return;
      }

      setState(() {
        _procesando = true;
        _archivo = archivo.name;
        _hoja = '';
        _estado = 'Analizando Excel...';
        _todos = [];
        _registros = [];
        _columnasFaltantes = [];
        _puedeImportar = false;
        _totalDuplicados = 0;
      });

      final libro = excel.Excel.decodeBytes(archivo.bytes!);
      if (libro.tables.isEmpty) {
        throw Exception('El archivo no contiene hojas de cálculo.');
      }

      excel.Sheet? hoja;

      // Hoja2 es la fuente confirmada para la lista de precios. Si cambia
      // el nombre, buscamos automáticamente la hoja que tenga las columnas.
      if (libro.tables.containsKey('Hoja2')) {
        final candidata = libro.tables['Hoja2'];
        if (candidata != null && candidata.rows.isNotEmpty) hoja = candidata;
        if (hoja != null) _hoja = 'Hoja2';
      }

      if (hoja == null) {
        for (final entry in libro.tables.entries) {
          if (entry.value.rows.isEmpty) continue;
          final encabezados = _encabezados(entry.value.rows.first);
          final tieneCodigo = encabezados.any((e) =>
              ['codigo', 'codigo_producto', 'codigo_articulo', 'cod_articulo'].contains(e));
          final tienePrecio = encabezados.any((e) =>
              ['precio_de_venta', 'precio venta', 'precio', 'precio_venta'].contains(e));
          if (tieneCodigo && tienePrecio) {
            hoja = entry.value;
            _hoja = entry.key;
            break;
          }
        }
      }

      hoja ??= libro.tables.values.firstWhere((e) => e.rows.isNotEmpty);
      if (_hoja.isEmpty) _hoja = libro.tables.keys.first;

      final encabezados = _encabezados(hoja.rows.first);
      final indices = <String, int>{};
      for (int i = 0; i < encabezados.length; i++) {
        indices[encabezados[i]] = i;
      }

      final codigoIndex = _buscarIndice(indices, [
        'codigo',
        'codigo_producto',
        'codigo_articulo',
        'cod_articulo',
      ]);
      final descripcionIndex = _buscarIndice(indices, [
        'descripcion',
        'descripcion_producto',
        'producto',
      ]);
      final precioIndex = _buscarIndice(indices, [
        'precio_de_venta',
        'precio venta',
        'precio',
        'precio_venta',
      ]);

      final faltantes = <String>[];
      if (codigoIndex == null) faltantes.add('Código');
      if (descripcionIndex == null) faltantes.add('Descripción');
      if (precioIndex == null) faltantes.add('Precio De Venta');

      final porCodigo = <String, Map<String, dynamic>>{};
      int filasValidas = 0;
      int duplicados = 0;

      if (faltantes.isEmpty) {
        for (int i = 1; i < hoja.rows.length; i++) {
          final fila = hoja.rows[i];
          if (_filaVacia(fila)) continue;

          final codigo = _celda(fila, codigoIndex).trim();
          final descripcion = _celda(fila, descripcionIndex).trim();
          final precioTexto = _celda(fila, precioIndex).trim();

          if (codigo.isEmpty || descripcion.isEmpty) continue;

          final precio = _numero(precioTexto);
          final registro = <String, dynamic>{
            'codigo': codigo,
            'descripcion': descripcion,
            'familia': null,
            'clase': null,
            'color': null,
            'unidad': null,
            'calibre': null,
            'presentacion': null,
            'modelo': null,
            'lista_precio_dolar': precio,
            'valor_lista_dolar': precio,
            'precio_vigente_dolar': precio,
            'activo': true,
          };

          filasValidas++;
          final clave = _normalizarCodigo(codigo);
          final anterior = porCodigo[clave];
          if (anterior != null) {
            duplicados++;
            final precioAnterior = (anterior['precio_vigente_dolar'] as num?)?.toDouble() ?? 0;
            // Si el mismo código aparece dos veces y una versión tiene precio
            // distinto de cero, conservamos la versión con precio.
            if (precioAnterior != 0 && precio == 0) continue;
            if (precioAnterior == 0 && precio != 0) {
              porCodigo[clave] = registro;
            }
            continue;
          }
          porCodigo[clave] = registro;
        }
      }

      final filas = porCodigo.values.toList();
      filas.sort((a, b) =>
          a['codigo'].toString().compareTo(b['codigo'].toString()));

      setState(() {
        _totalFilasExcel = hoja!.rows.length - 1;
        _totalValidos = filasValidas;
        _totalDuplicados = duplicados;
        _todos = filas;
        _registros = filas.take(100).toList();
        _columnasFaltantes = faltantes;
        _puedeImportar = faltantes.isEmpty && filas.isNotEmpty;
        _estado = faltantes.isEmpty
            ? 'Excel analizado correctamente.'
            : 'Faltan columnas requeridas.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _estado = 'Error al leer el Excel.';
          _puedeImportar = false;
        });
        _mensaje('No se pudo leer el archivo.\n$e');
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _importar() async {
    if (!_puedeImportar || _procesando || _todos.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Confirmar actualización de lista de precios',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Se procesarán ${_todos.length} códigos únicos.\n\n'
          'La lista actual será reemplazada como lista vigente. '
          'Los códigos que ya existan se actualizarán, los códigos nuevos se agregarán '
          'y los códigos que ya no estén en el nuevo Excel quedarán inactivos.\n\n'
          'Los precios usados posteriormente en cotizaciones se guardarán como valor histórico de la cotización.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ACTUALIZAR LISTA'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() {
      _procesando = true;
      _estado = 'Creando versión de lista...';
    });

    try {
      // La nueva importación se registra primero como no vigente.
      await _supabase
          .from('importaciones_lista_precios')
          .update({'vigente': false})
          .eq('vigente', true);

      final importacion = await _supabase
          .from('importaciones_lista_precios')
          .insert({
            'archivo': _archivo,
            'vigente': false,
            'registros': _todos.length,
            'observacion': 'Importación desde módulo de Cotizaciones.',
          })
          .select('id')
          .single();

      final importacionId = importacion['id'];

      // La lista nueva pasa a ser la única lista activa. No borramos filas
      // antiguas porque pueden ser necesarias para trazabilidad.
      await _supabase.from('productos').update({'activo': false}).gt('id', 0);

      int procesados = 0;
      for (int inicio = 0; inicio < _todos.length; inicio += 500) {
        final fin = (inicio + 500 < _todos.length)
            ? inicio + 500
            : _todos.length;
        final loteOriginal = _todos.sublist(inicio, fin);
        final lote = loteOriginal.map((e) => {
              ...e,
              'lista_precio_version': importacionId,
              'importacion_precio_id': importacionId,
              'activo': true,
            }).toList();

        await _supabase.from('productos').upsert(
              lote,
              onConflict: 'codigo',
            );

        procesados += lote.length;
        if (mounted) {
          setState(() {
            _estado = 'Actualizando precios... $procesados de ${_todos.length}';
          });
        }
      }

      await _supabase
          .from('importaciones_lista_precios')
          .update({'vigente': true, 'registros': _todos.length})
          .eq('id', importacionId);

      if (!mounted) return;
      setState(() {
        _estado = 'Lista vigente actualizada: $procesados códigos.';
        _puedeImportar = false;
      });

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF16803A)),
              SizedBox(width: 8),
              Text('Lista de precios actualizada'),
            ],
          ),
          content: Text(
            '$procesados códigos fueron procesados correctamente.\n\n'
            'Los existentes fueron actualizados, los nuevos fueron agregados y '
            'los códigos que ya no aparecen quedaron inactivos.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ACEPTAR'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _estado = 'La importación encontró un error.');
      _mensaje(
        'No se pudo completar la actualización de precios.\n\n$e',
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  List<String> _encabezados(List<excel.Data?> fila) =>
      fila.map((c) => _normalizar(c?.value?.toString() ?? '')).toList();

  String _normalizar(String valor) => valor
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[\s\-/]+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_]'), '');

  String _normalizarCodigo(String valor) => valor.trim().toUpperCase();

  int? _buscarIndice(Map<String, int> indices, List<String> opciones) {
    for (final opcion in opciones) {
      final normalizada = _normalizar(opcion);
      final index = indices[normalizada];
      if (index != null) return index;
    }
    return null;
  }

  String _celda(List<excel.Data?> fila, int? index) {
    if (index == null || index >= fila.length) return '';
    return fila[index]?.value?.toString().trim() ?? '';
  }

  double _numero(String valor) {
    var s = valor.trim().replaceAll(' ', '');
    if (s.isEmpty) return 0;
    // Excel puede entregar 12,345.67 o 12.345,67.
    if (s.contains(',') && s.contains('.')) {
      if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
        s = s.replaceAll('.', '').replaceAll(',', '.');
      } else {
        s = s.replaceAll(',', '');
      }
    } else if (s.contains(',')) {
      s = s.replaceAll(',', '.');
    }
    return double.tryParse(s) ?? 0;
  }

  bool _filaVacia(List<excel.Data?> fila) =>
      fila.every((c) => (c?.value?.toString().trim() ?? '').isEmpty);

  Widget _card({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF16803A)),
              const SizedBox(width: 9),
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _indicador(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(width: 165, child: Text(titulo, style: const TextStyle(color: Color(0xFF667085)))),
          Expanded(child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _filaPreview(Map<String, dynamic> p) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['codigo'].toString(), style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF16803A))),
                const SizedBox(height: 3),
                Text(p['descripcion'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('US\$ ${(p['precio_vigente_dolar'] as num).toDouble().toStringAsFixed(4)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _botonSeleccionar() => ElevatedButton.icon(
        onPressed: _procesando ? null : _seleccionarExcel,
        icon: const Icon(Icons.folder_open_outlined),
        label: const Text('SELECCIONAR EXCEL'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1D4ED8),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      );

  Widget _botonImportar() => ElevatedButton.icon(
        onPressed: _procesando ? null : _importar,
        icon: const Icon(Icons.cloud_upload_outlined),
        label: const Text('ACTUALIZAR LISTA EN SUPABASE'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16803A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!Sesion.esAdministrador) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Importar lista de precios'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Solo el administrador puede importar la lista de precios.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    final movil = MediaQuery.of(context).size.width < 760;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF16803A),
        elevation: 1,
        title: const Text('IMPORTAR LISTA DE PRECIOS', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(movil ? 12 : 20),
        child: Column(
          children: [
            _card(
              title: 'Carga de Lista de Precios',
              icon: Icons.price_change_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_archivo, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('Hoja detectada: ${_hoja.isEmpty ? '-' : _hoja}', style: const TextStyle(color: Color(0xFF667085))),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [_botonSeleccionar(), if (_puedeImportar) _botonImportar()],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _card(
              title: 'Resultado del análisis',
              icon: Icons.analytics_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_estado, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (_totalFilasExcel > 0) ...[
                    const SizedBox(height: 12),
                    _indicador('Filas del Excel', '$_totalFilasExcel'),
                    _indicador('Registros válidos', '$_totalValidos'),
                    _indicador('Códigos únicos', '${_todos.length}'),
                    _indicador('Duplicados resueltos', '$_totalDuplicados'),
                  ],
                  if (_columnasFaltantes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Columnas faltantes: ${_columnasFaltantes.join(', ')}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                  ],
                  if (_registros.isNotEmpty) ...[
                    const SizedBox(height: 15),
                    const Text('Vista previa', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 9),
                    ..._registros.take(movil ? 8 : 15).map(_filaPreview),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }
}
