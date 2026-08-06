import 'package:flutter/material.dart';

class ProduccionImportPage extends StatelessWidget {
  const ProduccionImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Importar Producción"),
      ),
      body: const Center(
        child: Text("Importador Excel"),
      ),
    );
  }
}