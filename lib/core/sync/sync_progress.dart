import 'package:flutter/foundation.dart';

enum SyncStatus {
  idle,
  readingExcel,
  validating,
  preparingContext,
  syncingCatalogs,
  syncingProducts,
  syncingClients,
  syncingVendors,
  syncingStock,
  updatingViews,
  savingHistory,
  auditing,
  completed,
  failed,
}

class SyncProgress extends ChangeNotifier {
  SyncStatus _status = SyncStatus.idle;

  double _progress = 0;

  String _message = "";

  int _current = 0;

  int _total = 0;

  DateTime? _startTime;

  DateTime? _endTime;

  SyncStatus get status => _status;

  double get progress => _progress;

  String get message => _message;

  int get current => _current;

  int get total => _total;

  DateTime? get startTime => _startTime;

  DateTime? get endTime => _endTime;

  Duration get elapsed {
    if (_startTime == null) return Duration.zero;

    final end = _endTime ?? DateTime.now();

    return end.difference(_startTime!);
  }

  void start() {
    _startTime = DateTime.now();
    _endTime = null;
    _progress = 0;
    _current = 0;
    _total = 0;
    _status = SyncStatus.idle;
    _message = "";
    notifyListeners();
  }

  void update({
    required SyncStatus status,
    required String message,
    required int current,
    required int total,
  }) {
    _status = status;
    _message = message;
    _current = current;
    _total = total;

    if (total > 0) {
      _progress = current / total;
    }

    notifyListeners();
  }

  void complete() {
    _status = SyncStatus.completed;
    _progress = 1;
    _endTime = DateTime.now();
    notifyListeners();
  }

  void fail(String error) {
    _status = SyncStatus.failed;
    _message = error;
    _endTime = DateTime.now();
    notifyListeners();
  }
}