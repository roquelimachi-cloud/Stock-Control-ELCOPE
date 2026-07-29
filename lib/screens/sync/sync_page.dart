import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:stock_control_elcope/services/excel/excel_service.dart';
import 'package:stock_control_elcope/services/import/import_excel_service.dart';
import 'package:stock_control_elcope/services/supabase/stock_service.dart';
import 'package:stock_control_elcope/widgets/columnas_dialog.dart';
import 'dart:typed_data';
class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  final ExcelService excelService = ExcelService();
  final ImportExcelService importExcelService = ImportExcelService();
final StockService stockService = StockService();

  String archivo = "No seleccionado";
  String rutaArchivo = "";
  Uint8List? archivoBytes;
  String estado = "Esperando sincronización...";
  String ultima = "Nunca";

  int totalFilas = 0;
  int totalColumnas = 0;

Future<void> seleccionarArchivo() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xlsx', 'xls'],
    withData: true,
  );

  if (result == null) return;

  final file = result.files.single;

  setState(() {
    archivo = file.name;
    rutaArchivo = file.path ?? "";
    archivoBytes = file.bytes;

    estado = "Archivo seleccionado correctamente.";
  });
}


Future<void> sincronizar() async {
if (rutaArchivo.isEmpty && archivoBytes == null) {
  setState(() {
    estado = "Debe seleccionar un archivo Excel.";
  });
  return;
}

  try {
    setState(() {
      estado = "Leyendo Excel...";
    });
final resultado = await excelService.leerExcel(
  bytes: archivoBytes!,
);

    totalFilas = resultado["filas"];
    totalColumnas = resultado["columnas"];

    final analisisColumnas = List<Map<String, String>>.from(
      (resultado["analisisColumnas"] ?? []).map(
        (e) => Map<String, String>.from(e),
      ),
    );
final rows = await importExcelService.importar(
  bytes: archivoBytes!,
);
    setState(() {
      estado = "Sincronizando ${rows.length} registros...";
    });

    await stockService.sincronizar(rows);

    setState(() {
      estado = "Sincronización completada correctamente.";
      ultima =
          "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} "
          "${DateTime.now().hour}:${DateTime.now().minute}";
    });

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => ColumnasDialog(
        archivo: archivo,
        filas: totalFilas,
        columnas: totalColumnas,
        analisisColumnas: analisisColumnas,
      ),
    );
  } catch (e) {
    setState(() {
      estado = e.toString();
    });

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(e.toString()),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Aceptar"),
          ),
        ],
      ),
    );
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sincronizar Excel"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "CONTROL DE STOCK ELCOPE",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            const Text("Última sincronización",
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(ultima),
            const Divider(height: 40),
            const Text("Archivo seleccionado",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(archivo),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: seleccionarArchivo,
                icon: const Icon(Icons.folder_open),
                label: const Text("Seleccionar Excel"),
              ),
            ),
            const Divider(height: 40),
            const Text("Estado",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              estado,
              style: const TextStyle(
                  color: Colors.blue, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton.icon(
                onPressed: sincronizar,
                icon: const Icon(Icons.sync),
                label: const Text("SINCRONIZAR",
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
