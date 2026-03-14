// lib/utils/performance_profiler.dart
import 'package:flutter/foundation.dart';

class PerformanceProfiler {
  static final PerformanceProfiler _instance = PerformanceProfiler._internal();

  factory PerformanceProfiler() {
    return _instance;
  }

  PerformanceProfiler._internal();

  final Map<String, _ProfileData> _profiles = {};

  Stopwatch startMeasure(String label) {
    final sw = Stopwatch()..start();
    _profiles[label] = _ProfileData(label, sw);
    return sw;
  }

  Duration endMeasure(String label) {
    final data = _profiles[label];
    if (data != null) {
      data.stopwatch.stop();
      if (kDebugMode) {
        print('[PERF] $label: ${data.stopwatch.elapsedMilliseconds}ms');
      }
      return data.stopwatch.elapsed;
    }
    return Duration.zero;
  }

  Future<T> measure<T>(String label, Future<T> Function() fn) async {
    final sw = startMeasure(label);
    final result = await fn();
    endMeasure(label);
    return result;
  }

  T measureSync<T>(String label, T Function() fn) {
    final sw = startMeasure(label);
    final result = fn();
    endMeasure(label);
    return result;
  }

  Map<String, Duration> getAll() {
    return {
      for (var entry in _profiles.entries) entry.key: entry.value.stopwatch.elapsed,
    };
  }

  void clear() {
    _profiles.clear();
  }

  void printReport() {
    if (kDebugMode) {
      print('\n=== PERFORMANCE REPORT ===');
      for (var entry in _profiles.entries) {
        print('${entry.key}: ${entry.value.stopwatch.elapsedMilliseconds}ms');
      }
      print('==========================\n');
    }
  }
}

class _ProfileData {
  final String label;
  final Stopwatch stopwatch;

  _ProfileData(this.label, this.stopwatch);
}

PerformanceProfiler get profiler => PerformanceProfiler();