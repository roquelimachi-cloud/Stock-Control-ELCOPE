import 'dart:convert';

import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/sesion.dart';

class ImportarClientesPage extends StatefulWidget {
  const ImportarClientesPage({super.key});

  @override
  State<ImportarClientesPage> createState() => _ImportarClientesPageState();
}

class _ImportarClientesPageState extends State<ImportarClientesPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  String _archivo = 'Ningún archivo seleccionado';
  String _hoja = '';
  String _estado = 'Seleccione un Excel o CSV de clientes.';
  bool _procesando = false;
  bool _puedeImportar = false;

  List<Map<String, dynamic>> _registros = [];
  List<Map<String, dynamic>> _todos = [];
  List<String> _columnasFaltantes = [];

  int _totalFilas = 0;
  int _totalValidos = 0;
  int _duplicados = 0;
  double _progreso = 0;

  static const Map<String, List<String>> _gruposRequeridos = {
    'codigo_vendedor': ['codigo_vendedor', 'codigo vendedor'],
    'vendedor': ['vendedor'],
    'ruc': ['ruc', 'codigo_cliente', 'codigo cliente'],
    'razon_social': [
      'razon_social',
      'descripcion_del_cliente',
      'descripcion del cliente',
      'nombre',
    ],
    'direccion': ['direccion'],
    'localidad': ['localidad'],
    'departamento': ['departamento'],
    'canal': ['canal'],
    'giro': ['giro'],
    'sector': ['sector'],
  };

  Future<void> _seleccionarArchivo() async {
    if (_procesando) return;

    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        withData: true,
      );

      if (resultado == null) return;

      final archivo = resultado.files.single;
      final bytes = archivo.bytes;

      if (bytes == null || bytes.isEmpty) {
        _mensaje('No se pudieron leer los datos del archivo.');
        return;
      }

      setState(() {
        _procesando = true;
        _archivo = archivo.name;
        _hoja = '';
        _estado = 'Preparando análisis...';
        _registros = [];
        _todos = [];
        _columnasFaltantes = [];
        _puedeImportar = false;
        _totalFilas = 0;
        _totalValidos = 0;
        _duplicados = 0;
        _progreso = 0;
      });

      final extension = archivo.name.toLowerCase().split('.').last;

      if (extension == 'csv') {
        await _analizarCsv(bytes);
      } else {
        await _analizarExcel(bytes);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _estado = 'Error al leer el archivo.';
        _puedeImportar = false;
      });

      _mensaje(
        'No se pudo leer el archivo.\n\n'
        '$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  Future<void> _analizarCsv(List<int> bytes) async {
    setState(() {
      _estado = 'Analizando CSV...';
    });

    final texto = utf8.decode(bytes, allowMalformed: true);
    final filas = _parseCsv(texto);

    if (filas.isEmpty) {
      throw Exception('El CSV no contiene registros.');
    }

    final encabezados = filas.first
        .map(_normalizar)
        .toList();

    final indices = <String, int>{};
    for (int i = 0; i < encabezados.length; i++) {
      if (encabezados[i].isNotEmpty) {
        indices[encabezados[i]] = i;
      }
    }

    final faltantes = _calcularColumnasFaltantes(indices);

    final datos = <Map<String, dynamic>>[];

    for (int i = 1; i < filas.length; i++) {
      final fila = filas[i];

      if (_filaCsvVacia(fila)) continue;

      final registro = _registroDesdeCsv(fila, indices);
      final ruc = registro['ruc'].toString().trim();
      final razon = registro['razon_social'].toString().trim();

      if (ruc.isEmpty && razon.isEmpty) continue;

      datos.add(registro);

      if (i % 1000 == 0 && mounted) {
        setState(() {
          _estado = 'Analizando CSV... $i de ${filas.length - 1} filas';
        });
        await Future<void>.delayed(Duration.zero);
      }
    }

    _finalizarAnalisis(
      datos: datos,
      totalFilas: filas.length - 1,
      faltantes: faltantes,
      hoja: 'CSV',
    );
  }

  Future<void> _analizarExcel(List<int> bytes) async {
    setState(() {
      _estado =
          'Analizando Excel... Este proceso puede tardar unos segundos.';
    });

    await Future<void>.delayed(const Duration(milliseconds: 50));

    final libro = excel.Excel.decodeBytes(bytes);

    if (libro.tables.isEmpty) {
      throw Exception('El archivo no contiene hojas de cálculo.');
    }

    excel.Sheet? hojaSeleccionada;
    String nombreHoja = '';

    for (final entry in libro.tables.entries) {
      final hoja = entry.value;
      if (hoja.rows.isEmpty) continue;

      final encabezados = _encabezadosExcel(hoja.rows.first);

      final tieneCliente = encabezados.contains('ruc') ||
          encabezados.contains('codigo_cliente') ||
          encabezados.contains('descripcion_del_cliente') ||
          encabezados.contains('razon_social');

      if (tieneCliente) {
        hojaSeleccionada = hoja;
        nombreHoja = entry.key;
        break;
      }
    }

    hojaSeleccionada ??= libro.tables.values.firstWhere(
      (hoja) => hoja.rows.isNotEmpty,
    );

    if (nombreHoja.isEmpty) {
      nombreHoja = libro.tables.keys.first;
    }

    final encabezados = _encabezadosExcel(hojaSeleccionada.rows.first);
    final indices = <String, int>{};

    for (int i = 0; i < encabezados.length; i++) {
      if (encabezados[i].isNotEmpty) {
        indices[encabezados[i]] = i;
      }
    }

    final faltantes = _calcularColumnasFaltantes(indices);
    final datos = <Map<String, dynamic>>[];

    for (int i = 1; i < hojaSeleccionada.rows.length; i++) {
      final fila = hojaSeleccionada.rows[i];

      if (_filaExcelVacia(fila)) continue;

      final registro = _registroDesdeExcel(fila, indices);
      final ruc = registro['ruc'].toString().trim();
      final razon = registro['razon_social'].toString().trim();

      if (ruc.isEmpty && razon.isEmpty) continue;

      datos.add(registro);

      if (i % 1000 == 0 && mounted) {
        setState(() {
          _estado =
              'Analizando Excel... $i de ${hojaSeleccionada!.rows.length - 1} filas';
        });
        await Future<void>.delayed(Duration.zero);
      }
    }

    _finalizarAnalisis(
      datos: datos,
      totalFilas: hojaSeleccionada.rows.length - 1,
      faltantes: faltantes,
      hoja: nombreHoja,
    );
  }

  void _finalizarAnalisis({
    required List<Map<String, dynamic>> datos,
    required int totalFilas,
    required List<String> faltantes,
    required String hoja,
  }) {
    final unicos = <String, Map<String, dynamic>>{};
    int duplicados = 0;

    for (final registro in datos) {
      final ruc = registro['ruc'].toString().trim();
      final razon = registro['razon_social'].toString().trim();
      final vendedor = registro['codigo_vendedor'].toString().trim();

      final clave = ruc.isNotEmpty
          ? 'RUC:$ruc'
          : 'SINRUC:$vendedor|$razon';

      if (unicos.containsKey(clave)) {
        duplicados++;
      }

      unicos[clave] = registro;
    }

    final registrosUnicos = unicos.values.toList();

    setState(() {
      _hoja = hoja;
      _totalFilas = totalFilas;
      _totalValidos = registrosUnicos.length;
      _duplicados = duplicados;
      _todos = registrosUnicos;
      _registros = registrosUnicos.take(100).toList();
      _columnasFaltantes = faltantes;
      _puedeImportar =
          faltantes.isEmpty && registrosUnicos.isNotEmpty;
      _estado = faltantes.isEmpty
          ? 'Archivo analizado correctamente.'
          : 'Faltan columnas requeridas.';
    });
  }

  Future<void> _importar() async {
    if (!_puedeImportar || _procesando) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Confirmar actualización de clientes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Se procesarán $_totalValidos clientes.\n\n'
          '• Los RUC existentes se actualizarán.\n'
          '• Los clientes nuevos se agregarán.\n'
          '• Los clientes que ya no aparezcan quedarán inactivos.\n'
          '• No se eliminarán registros.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ACTUALIZAR'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() {
      _procesando = true;
      _progreso = 0;
      _estado = 'Preparando actualización...';
    });

    try {
      final registros = List<Map<String, dynamic>>.from(_todos);

      // Se prepara todo antes de modificar el catálogo actual.
      final preparados = registros.map((registro) {
        final ruc = registro['ruc'].toString().trim();
        final razon = registro['razon_social'].toString().trim();

        return <String, dynamic>{
          ...registro,
          'codigo': ruc.isNotEmpty ? ruc : razon,
          'nombre': razon.isNotEmpty ? razon : 'SIN RAZÓN SOCIAL',
          'activo': true,
        };
      }).toList();

      // El RUC es la clave principal del cliente.
      final conRuc = preparados
          .where(
            (e) => e['ruc'].toString().trim().isNotEmpty,
          )
          .toList();

      final sinRuc = preparados
          .where(
            (e) => e['ruc'].toString().trim().isEmpty,
          )
          .toList();

      int procesados = 0;
      final total = preparados.length;

      // Procesamos en lotes de 500 para no enviar 29 mil filas de una vez.
      for (int inicio = 0;
          inicio < conRuc.length;
          inicio += 500) {
        final fin = (inicio + 500 < conRuc.length)
            ? inicio + 500
            : conRuc.length;

        final lote = conRuc.sublist(inicio, fin);

        await _supabase
            .from('clientes')
            .upsert(lote, onConflict: 'ruc');

        procesados += lote.length;

        if (mounted) {
          setState(() {
            _progreso = total == 0 ? 0 : procesados / total;
            _estado =
                'Actualizando clientes... $procesados de $total';
          });
        }

        await Future<void>.delayed(Duration.zero);
      }

      // Compatibilidad con archivos que no tengan RUC.
      for (int inicio = 0;
          inicio < sinRuc.length;
          inicio += 100) {
        final fin = (inicio + 100 < sinRuc.length)
            ? inicio + 100
            : sinRuc.length;

        final lote = sinRuc.sublist(inicio, fin);

        for (final registro in lote) {
          final codigo = registro['codigo'].toString().trim();

          if (codigo.isEmpty) continue;

          await _supabase
              .from('clientes')
              .upsert([registro], onConflict: 'codigo');

          procesados++;

          if (mounted) {
            setState(() {
              _progreso = total == 0 ? 0 : procesados / total;
              _estado =
                  'Actualizando clientes... $procesados de $total';
            });
          }
        }
      }

      // Solo después de completar las actualizaciones, desactivamos
      // los clientes que no quedaron presentes en la nueva lista.
      // Se consultan los IDs por páginas y luego se actualiza en lotes
      // pequeños para evitar URLs demasiado grandes en PostgREST.
      final rucsNuevos = conRuc
          .map((e) => e['ruc'].toString().trim())
          .where((ruc) => ruc.isNotEmpty)
          .toSet();

      final codigosNuevos = preparados
          .map((e) => e['codigo'].toString().trim())
          .where((codigo) => codigo.isNotEmpty)
          .toSet();

      final idsParaDesactivar = <dynamic>[];
      const tamPagina = 1000;

      for (int inicio = 0;; inicio += tamPagina) {
        final pagina = await _supabase
            .from('clientes')
            .select('id,ruc,codigo,activo')
            .eq('activo', true)
            .range(inicio, inicio + tamPagina - 1);

        if (pagina.isEmpty) break;

        for (final cliente in (pagina as List)) {
          final ruc = (cliente['ruc'] ?? '').toString().trim();
          final codigo = (cliente['codigo'] ?? '').toString().trim();

          final perteneceAlNuevoCatalogo =
              (ruc.isNotEmpty && rucsNuevos.contains(ruc)) ||
              (ruc.isEmpty && codigo.isNotEmpty && codigosNuevos.contains(codigo));

          if (!perteneceAlNuevoCatalogo && cliente['id'] != null) {
            idsParaDesactivar.add(cliente['id']);
          }

          if (pagina.length < tamPagina) break;
        }

        if (pagina.length < tamPagina) break;
        await Future<void>.delayed(Duration.zero);
      }

      for (int inicio = 0;
          inicio < idsParaDesactivar.length;
          inicio += 500) {
        final fin = (inicio + 500 < idsParaDesactivar.length)
            ? inicio + 500
            : idsParaDesactivar.length;

        final loteIds = idsParaDesactivar.sublist(inicio, fin);

        await _supabase
            .from('clientes')
            .update({'activo': false})
            .inFilter('id', loteIds);

        await Future<void>.delayed(Duration.zero);
      }

      if (!mounted) return;

      setState(() {
        _progreso = 1;
        _estado =
            'Actualización terminada: $procesados clientes procesados.';
        _puedeImportar = false;
      });

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Color(0xFF16803A),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text('Clientes actualizados'),
              ),
            ],
          ),
          content: Text(
            '$procesados clientes fueron procesados correctamente.\n\n'
            'Los existentes fueron actualizados, los nuevos fueron agregados '
            'y los que ya no aparecen quedaron inactivos.',
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

      setState(() {
        _estado = 'La actualización encontró un error.';
      });

      _mensaje(
        'No se pudo completar la actualización.\n\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  Map<String, dynamic> _registroDesdeCsv(
    List<String> fila,
    Map<String, int> indices,
  ) {
    return {
      'codigo_vendedor': _valorCsv(
        fila,
        indices,
        ['codigo_vendedor', 'codigo vendedor'],
      ),
      'vendedor': _valorCsv(
        fila,
        indices,
        ['vendedor'],
      ),
      'ruc': _valorCsv(
        fila,
        indices,
        ['ruc', 'codigo_cliente', 'codigo cliente'],
      ),
      'razon_social': _valorCsv(
        fila,
        indices,
        [
          'razon_social',
          'descripcion_del_cliente',
          'descripcion del cliente',
          'nombre',
        ],
      ),
      'direccion': _valorCsv(
        fila,
        indices,
        ['direccion'],
      ),
      'localidad': _valorCsv(
        fila,
        indices,
        ['localidad'],
      ),
      'departamento': _valorCsv(
        fila,
        indices,
        ['departamento'],
      ),
      'canal': _valorCsv(
        fila,
        indices,
        ['canal'],
      ),
      'giro': _valorCsv(
        fila,
        indices,
        ['giro'],
      ),
      'sector': _valorCsv(
        fila,
        indices,
        ['sector'],
      ),
    };
  }

  Map<String, dynamic> _registroDesdeExcel(
    List<excel.Data?> fila,
    Map<String, int> indices,
  ) {
    return {
      'codigo_vendedor': _valorExcel(
        fila,
        indices,
        ['codigo_vendedor', 'codigo vendedor'],
      ),
      'vendedor': _valorExcel(
        fila,
        indices,
        ['vendedor'],
      ),
      'ruc': _valorExcel(
        fila,
        indices,
        ['ruc', 'codigo_cliente', 'codigo cliente'],
      ),
      'razon_social': _valorExcel(
        fila,
        indices,
        [
          'razon_social',
          'descripcion_del_cliente',
          'descripcion del cliente',
          'nombre',
        ],
      ),
      'direccion': _valorExcel(
        fila,
        indices,
        ['direccion'],
      ),
      'localidad': _valorExcel(
        fila,
        indices,
        ['localidad'],
      ),
      'departamento': _valorExcel(
        fila,
        indices,
        ['departamento'],
      ),
      'canal': _valorExcel(
        fila,
        indices,
        ['canal'],
      ),
      'giro': _valorExcel(
        fila,
        indices,
        ['giro'],
      ),
      'sector': _valorExcel(
        fila,
        indices,
        ['sector'],
      ),
    };
  }

  List<String> _calcularColumnasFaltantes(
    Map<String, int> indices,
  ) {
    final faltantes = <String>[];

    for (final entrada in _gruposRequeridos.entries) {
      final existe = entrada.value.any(
        (nombre) => indices.containsKey(_normalizar(nombre)),
      );

      if (!existe) {
        faltantes.add(entrada.key);
      }
    }

    return faltantes;
  }

  List<String> _encabezadosExcel(List<excel.Data?> fila) {
    return fila
        .map(
          (celda) => _normalizar(
            celda?.value?.toString() ?? '',
          ),
        )
        .toList();
  }

  String _valorCsv(
    List<String> fila,
    Map<String, int> indices,
    List<String> nombres,
  ) {
    for (final nombre in nombres) {
      final index = indices[_normalizar(nombre)];

      if (index == null || index >= fila.length) continue;

      return fila[index].trim();
    }

    return '';
  }

  String _valorExcel(
    List<excel.Data?> fila,
    Map<String, int> indices,
    List<String> nombres,
  ) {
    for (final nombre in nombres) {
      final index = indices[_normalizar(nombre)];

      if (index == null || index >= fila.length) continue;

      return fila[index]?.value?.toString().trim() ?? '';
    }

    return '';
  }

  List<List<String>> _parseCsv(String texto) {
    final resultado = <List<String>>[];
    final fila = <String>[];
    final campo = StringBuffer();

    bool dentroComillas = false;

    for (int i = 0; i < texto.length; i++) {
      final caracter = texto[i];

      if (caracter == '"') {
        if (dentroComillas &&
            i + 1 < texto.length &&
            texto[i + 1] == '"') {
          campo.write('"');
          i++;
        } else {
          dentroComillas = !dentroComillas;
        }
        continue;
      }

      if (caracter == ',' && !dentroComillas) {
        fila.add(campo.toString());
        campo.clear();
        continue;
      }

      if ((caracter == '\n' || caracter == '\r') &&
          !dentroComillas) {
        if (caracter == '\r' &&
            i + 1 < texto.length &&
            texto[i + 1] == '\n') {
          i++;
        }

        fila.add(campo.toString());
        campo.clear();

        if (fila.any((valor) => valor.trim().isNotEmpty)) {
          resultado.add(List<String>.from(fila));
        }

        fila.clear();
        continue;
      }

      campo.write(caracter);
    }

    if (campo.isNotEmpty || fila.isNotEmpty) {
      fila.add(campo.toString());

      if (fila.any((valor) => valor.trim().isNotEmpty)) {
        resultado.add(List<String>.from(fila));
      }
    }

    if (resultado.isNotEmpty && resultado.first.isNotEmpty) {
      resultado[0][0] =
          resultado[0][0].replaceFirst('\uFEFF', '');
    }

    return resultado;
  }

  bool _filaCsvVacia(List<String> fila) {
    return !fila.any(
      (valor) => valor.trim().isNotEmpty,
    );
  }

  bool _filaExcelVacia(List<excel.Data?> fila) {
    return !fila.any(
      (celda) =>
          (celda?.value?.toString().trim() ?? '').isNotEmpty,
    );
  }

  String _normalizar(String valor) {
    return valor
        .replaceFirst('\uFEFF', '')
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[\s\-\/]+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  @override
  Widget build(BuildContext context) {
    if (!Sesion.esAdministrador) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Importar clientes'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Solo el administrador puede importar clientes.',
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
        title: const Text(
          'IMPORTAR CLIENTES',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(movil ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cabecera(movil),
            const SizedBox(height: 16),
            _seleccionArchivo(movil),
            const SizedBox(height: 16),
            _resultado(movil),
          ],
        ),
      ),
    );
  }

  Widget _cabecera(bool movil) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(movil ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFE9F7EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.upload_file_outlined,
              color: Color(0xFF16803A),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Carga de Clientes',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D2939),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Importe Excel o CSV directamente desde su equipo.',
                  style: TextStyle(
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _seleccionArchivo(bool movil) {
    return _card(
      title: 'Archivo de clientes',
      icon: Icons.description_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.table_chart_outlined,
                  color: Color(0xFF16803A),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _archivo,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_procesando)
            const LinearProgressIndicator(
              minHeight: 4,
            ),
          if (_procesando) const SizedBox(height: 10),
          if (movil)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _botonSeleccionar(),
                if (_puedeImportar) ...[
                  const SizedBox(height: 10),
                  _botonImportar(),
                ],
              ],
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _botonSeleccionar(),
                if (_puedeImportar) _botonImportar(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _botonSeleccionar() {
    return ElevatedButton.icon(
      onPressed: _procesando ? null : _seleccionarArchivo,
      icon: const Icon(Icons.folder_open_outlined),
      label: const Text('SELECCIONAR ARCHIVO'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _botonImportar() {
    return ElevatedButton.icon(
      onPressed: _procesando ? null : _importar,
      icon: const Icon(Icons.cloud_upload_outlined),
      label: const Text('ACTUALIZAR SUPABASE'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF16803A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _resultado(bool movil) {
    return _card(
      title: 'Resultado del análisis',
      icon: Icons.analytics_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _estado,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF344054),
            ),
          ),
          if (_procesando && _progreso > 0) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _progreso,
              minHeight: 7,
              borderRadius: BorderRadius.circular(8),
            ),
          ],
          if (_hoja.isNotEmpty) ...[
            const SizedBox(height: 12),
            _indicador('Origen', _hoja),
          ],
          if (_totalFilas > 0) ...[
            const SizedBox(height: 8),
            _indicador('Filas del archivo', '$_totalFilas'),
            _indicador('Clientes válidos', '$_totalValidos'),
            _indicador('Duplicados descartados', '$_duplicados'),
          ],
          if (_columnasFaltantes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: const Color(0xFFFED7AA),
                ),
              ),
              child: Text(
                'Columnas faltantes:\n'
                '${_columnasFaltantes.join(', ')}',
                style: const TextStyle(
                  color: Color(0xFF9A3412),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (_registros.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Vista previa',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ..._registros
                .take(movil ? 8 : 15)
                .map(_filaPreview),
          ],
        ],
      ),
    );
  }

  Widget _indicador(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(
              titulo,
              style: const TextStyle(
                color: Color(0xFF667085),
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D2939),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaPreview(Map<String, dynamic> cliente) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cliente['razon_social']
                        ?.toString()
                        .trim()
                        .isNotEmpty ==
                    true
                ? cliente['razon_social'].toString()
                : 'SIN RAZÓN SOCIAL',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'RUC: ${cliente['ruc']}  •  '
            'Vendedor: ${cliente['vendedor']}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF16803A),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D2939),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        duration: const Duration(seconds: 6),
      ),
    );
  }
}
