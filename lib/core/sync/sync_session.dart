import 'sync_context.dart';
import 'sync_progress.dart';
import 'sync_result.dart';

class SyncSession {
  /// Identificador de la sesión
  final String sessionId;

  /// Usuario que ejecuta la sincronización
  final String usuario;

  /// Nombre del archivo importado
  final String archivo;

  /// Fecha de inicio
  final DateTime inicio;

  /// Fecha fin
  DateTime? fin;

  /// Estado actual
  String estado;

  /// Contexto de trabajo
  final SyncContext context;

  /// Resultado de la sincronización
  final SyncResult result;

  /// Progreso en tiempo real
  final SyncProgress progress;

  /// Registro de eventos
  final List<String> logs;

  SyncSession({
    required this.sessionId,
    required this.usuario,
    required this.archivo,
    required this.context,
    required this.progress,
    SyncResult? result,
    DateTime? inicio,
  })  : inicio = inicio ?? DateTime.now(),
        result = result ?? SyncResult(),
        estado = "INICIANDO",
        logs = [];

  //----------------------------------------------------

  Duration get duracion {

    final end = fin ?? DateTime.now();

    return end.difference(inicio);

  }

  //----------------------------------------------------

  void log(String mensaje){

    logs.add(
      "[${DateTime.now()}] $mensaje"
    );

  }

  //----------------------------------------------------

  void cambiarEstado(String nuevoEstado){

    estado = nuevoEstado;

    log(nuevoEstado);

  }

  //----------------------------------------------------

  void finalizar(){

    fin = DateTime.now();

    result.finalizar(duracion);

  }

}