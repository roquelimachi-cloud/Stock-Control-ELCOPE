import 'sync_session.dart';
import 'sync_stage.dart';

class SyncPipeline {
  final List<SyncStage> _stages = [];

  /// Agrega una etapa al pipeline
  void addStage(SyncStage stage) {
    _stages.add(stage);
  }

  /// Ejecuta todas las etapas
  Future<void> execute(SyncSession session) async {
    session.cambiarEstado("Iniciando sincronización");

    try {
      for (final stage in _stages) {
        session.log("Iniciando etapa: ${stage.name}");

        await stage.execute(session);

        session.log("Etapa finalizada: ${stage.name}");
      }

      session.finalizar();
    } catch (e) {
      session.log("Error durante la sincronización: $e");

      session.result.addError(e.toString());

      session.finalizar();

      rethrow;
    }
  }
}