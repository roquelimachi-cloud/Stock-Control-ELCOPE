import 'package:flutter/material.dart';

class ColumnasDialog extends StatelessWidget {
  final String archivo;
  final int filas;
  final int columnas;
  final List<Map<String, String>> analisisColumnas;

  const ColumnasDialog({
    super.key,
    required this.archivo,
    required this.filas,
    required this.columnas,
    required this.analisisColumnas,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Análisis del Excel"),
      content: SizedBox(
        width: 900,
        height: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Archivo: $archivo",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text("Total de filas: $filas"),
            Text("Total de columnas: $columnas"),

            const SizedBox(height: 20),

            const Text(
              "Columnas detectadas",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const Divider(),

            Expanded(
              child: ListView.builder(
                itemCount: analisisColumnas.length,
                itemBuilder: (context, index) {
                  final columna = analisisColumnas[index];

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(columna["numero"] ?? ""),
                      ),
                      title: Text(
                        columna["columna"] ?? "",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        "Primer valor: ${columna["valor"] ?? ""}",
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text("Aceptar"),
        ),
      ],
    );
  }
}