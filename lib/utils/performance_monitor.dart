// lib/utils/performance_monitor.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  
  final List<PerformanceLog> _logs = [];
  final int _maxLogs = 1000;
  bool _isEnabled = false;
  
  int _widgetBuildCount = 0;
  int _frameDropCount = 0;
  DateTime? _lastFrameTime;

  factory PerformanceMonitor() {
    return _instance;
  }

  PerformanceMonitor._internal();

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (enabled) {
      _clearLogs();
      _log('Performance monitoring enabled');
    } else {
      _log('Performance monitoring disabled');
    }
  }

  bool get isEnabled => _isEnabled;

  void log(String message, {String category = 'general', Duration? duration}) {
    if (!_isEnabled) return;
    _log('[${category.toUpperCase()}] $message', duration: duration);
  }

  void logWidgetBuild(String widgetName, {Duration? buildTime}) {
    if (!_isEnabled) return;
    _widgetBuildCount++;
    _log('BUILD: $widgetName', duration: buildTime);
  }

  Future<T> measure<T>(
    String operation,
    Future<T> Function() callback, {
    String category = 'operation',
  }) async {
    if (!_isEnabled) {
      return callback();
    }

    final stopwatch = Stopwatch()..start();
    try {
      final result = await callback();
      stopwatch.stop();
      log('$operation completed', category: category, duration: stopwatch.elapsed);
      return result;
    } catch (e) {
      stopwatch.stop();
      log('$operation FAILED: $e', category: 'ERROR', duration: stopwatch.elapsed);
      rethrow;
    }
  }

  T measureSync<T>(
    String operation,
    T Function() callback, {
    String category = 'operation',
  }) {
    if (!_isEnabled) {
      return callback();
    }

    final stopwatch = Stopwatch()..start();
    try {
      final result = callback();
      stopwatch.stop();
      log('$operation completed', category: category, duration: stopwatch.elapsed);
      return result;
    } catch (e) {
      stopwatch.stop();
      log('$operation FAILED: $e', category: 'ERROR', duration: stopwatch.elapsed);
      rethrow;
    }
  }

  void recordFrame() {
    if (!_isEnabled) return;

    final now = DateTime.now();
    if (_lastFrameTime != null) {
      final frameDelta = now.difference(_lastFrameTime!).inMilliseconds;
      
      if (frameDelta > 33) {
        _frameDropCount++;
        _log('FRAME DROP: ${frameDelta}ms');
      }
    }
    _lastFrameTime = now;
  }

  List<PerformanceLog> getLogs() => List.unmodifiable(_logs);

  PerformanceStats getStats() {
    return PerformanceStats(
      totalLogs: _logs.length,
      totalBuilds: _widgetBuildCount,
      frameDrops: _frameDropCount,
      logs: _logs,
    );
  }

  void _clearLogs() {
    _logs.clear();
    _widgetBuildCount = 0;
    _frameDropCount = 0;
  }

  void clear() {
    _clearLogs();
    _log('Logs cleared');
  }

  String exportAsText() {
    final buffer = StringBuffer();
    buffer.writeln('=== Performance Report ===');
    buffer.writeln('Time: ${DateTime.now()}');
    buffer.writeln('Total Logs: ${_logs.length}');
    buffer.writeln('Widget Builds: $_widgetBuildCount');
    buffer.writeln('Frame Drops: $_frameDropCount');
    buffer.writeln('');
    buffer.writeln('--- Logs ---');
    
    for (final log in _logs) {
      buffer.writeln(log.toString());
    }
    
    return buffer.toString();
  }

  void _log(String message, {Duration? duration}) {
    final log = PerformanceLog(
      timestamp: DateTime.now(),
      message: message,
      duration: duration,
    );
    
    _logs.add(log);
    
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }

    if (kDebugMode) {
      print('[PERF] $log');
    }
  }
}

class PerformanceLog {
  final DateTime timestamp;
  final String message;
  final Duration? duration;

  PerformanceLog({
    required this.timestamp,
    required this.message,
    this.duration,
  });

  @override
  String toString() {
    final time = '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
    final durStr = duration != null ? ' [${duration!.inMilliseconds}ms]' : '';
    return '$time | $message$durStr';
  }
}

class PerformanceStats {
  final int totalLogs;
  final int totalBuilds;
  final int frameDrops;
  final List<PerformanceLog> logs;

  PerformanceStats({
    required this.totalLogs,
    required this.totalBuilds,
    required this.frameDrops,
    required this.logs,
  });

  double get avgBuildTime {
    if (logs.isEmpty) return 0;
    final buildLogs = logs.where((l) => l.duration != null && l.message.startsWith('BUILD'));
    if (buildLogs.isEmpty) return 0;
    final total = buildLogs.fold<int>(0, (sum, log) => sum + (log.duration?.inMilliseconds ?? 0));
    return total / buildLogs.length;
  }

  @override
  String toString() {
    return '''
PerformanceStats:
  Total Logs: $totalLogs
  Widget Builds: $totalBuilds
  Frame Drops: $frameDrops
  Avg Build Time: ${avgBuildTime.toStringAsFixed(2)}ms
''';
  }
}