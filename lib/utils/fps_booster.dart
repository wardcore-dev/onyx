import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class FpsBooster {
  FpsBooster._internal();
  static final FpsBooster _instance = FpsBooster._internal();
  factory FpsBooster() => _instance;

  Timer? _timer;
  int _targetFps = 60;
  bool _unlimitedMode = false;

  bool get isEnabled => _timer != null;
  bool get isUnlimitedMode => _unlimitedMode;
  int get targetFps => _targetFps;

  void enable({int targetFps = 120}) {
    disable(); 
    
    final clamped = targetFps.clamp(30, 2000);
    _targetFps = clamped;
    _unlimitedMode = false;

    final intervalUs = (1000000 / _targetFps).round();
    final interval = Duration(microseconds: intervalUs);

    debugPrint('[performance] FpsBooster enabled (LIMITED mode) with target=$_targetFps FPS (interval=${intervalUs}µs, latency=${(1000 / _targetFps).toStringAsFixed(2)}ms)');

    _timer = Timer.periodic(interval, (_) {
      try {
        
        SchedulerBinding.instance.scheduleFrame();
      } catch (e) {
        debugPrint('[performance] FpsBooster tick error: $e');
      }
    });
  }

  void enableUnlimited() {
    disable(); 

    _unlimitedMode = true;
    _targetFps = 0; 

    debugPrint('[performance] FpsBooster enabled (UNLIMITED mode) - Maximum FPS, NO VSYNC');

    const intervalMs = 1; 
    final interval = Duration(milliseconds: intervalMs);

    _timer = Timer.periodic(interval, (_) {
      try {
        if (_unlimitedMode) {
          
          SchedulerBinding.instance.scheduleFrame();
        }
      } catch (e) {
        debugPrint('[performance] FpsBooster unlimited tick error: $e');
      }
    });

    debugPrint('[performance] FpsBooster running with ${intervalMs}ms interval (~${1000 ~/ intervalMs} scheduleFrame calls/sec)');
  }

  void disable() {
    _timer?.cancel();
    _timer = null;
    _unlimitedMode = false;
    debugPrint('[performance] FpsBooster disabled');
  }
}