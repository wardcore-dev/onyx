// lib/utils/global_log_collector.dart
import 'dart:async';

class GlobalLogCollector {
  static final GlobalLogCollector _instance = GlobalLogCollector._internal();

  final List<String> _logs = [];
  final List<StreamController<String>> _listeners = [];
  static const int _maxLogs = 2000;

  factory GlobalLogCollector() {
    return _instance;
  }

  GlobalLogCollector._internal();

  void log(String message, {String category = 'APP'}) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final fullLog = '[$timestamp] [$category] $message';

    _logs.add(fullLog);

    if (_logs.length > _maxLogs) {
      _logs.removeRange(0, _logs.length - _maxLogs);
    }

    for (final listener in _listeners) {
      if (!listener.isClosed) {
        listener.add(fullLog);
      }
    }
  }

  List<String> getLogs() => List.from(_logs);

  void clear() {
    _logs.clear();
  }

  Stream<String> subscribe() {
    final controller = StreamController<String>();
    _listeners.add(controller);
    return controller.stream;
  }

  List<String> getLastN(int n) {
    return _logs.skip((_logs.length - n).clamp(0, _logs.length)).toList();
  }
}

final globalLogs = GlobalLogCollector();