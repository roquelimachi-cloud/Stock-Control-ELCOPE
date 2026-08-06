import 'package:flutter/material.dart';

import '../../models/produccion/produccion_model.dart';
import '../../services/produccion/produccion_mis_op_service.dart';

class MisProduccionesPage extends StatefulWidget {
  const MisProduccionesPage({super.key});

  @override
  State<MisProduccionesPage> createState() =>
      _MisProduccionesPageState();
}

class _MisProduccionesPageState
    extends State<MisProduccionesPage> {

  final service = ProduccionMisOpService();

  late Future<List<ProduccionModel>> future;

  @override
  void initState() {
    super.initState();

    future = service.obtener();
  }

  @override
  Widget build(BuildContext context) {

    return FutureBuilder<List<ProduccionModel>>(
      future: future,
      builder: (context, snapshot) {

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              snapshot.error.toString(),
            ),
          );
        }

        final lista = snapshot.data!;

        return ListView.builder(

          itemCount: lista.length,

          itemBuilder: (context, index) {

            final op = lista[index];

            return ListTile(

              leading: const Icon(Icons.factory),

              title: Text(op.numeroProduccion),

              subtitle: Text(op.cliente),

              trailing: Text(
                op.fechaEntregaEstimada == null
                    ? "-"
                    : op.fechaEntregaEstimada
                        .toString()
                        .substring(0, 10),
              ),

            );
          },
        );
      },
    );
  }
}