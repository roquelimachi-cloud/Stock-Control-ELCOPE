import 'sync_session.dart';

abstract class SyncStage {
  String get name;

  Future<void> execute(SyncSession session);
}