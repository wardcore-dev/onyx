import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Keeps Flutter rendering at the display refresh rate even when the window
/// is minimized or otherwise not receiving OS vsync signals.
///
/// Strategy:
///  1. [addPersistentFrameCallback] maintains a self-perpetuating render loop
///     and records the timestamp of each delivered frame.
///  2. A heartbeat [Timer.periodic] calls [scheduleFrame] normally.
///  3. When the heartbeat detects that no frames have been delivered for more
///     than [_stallThresholdMs] (i.e. the OS stopped sending vsync — window
///     minimized, hidden, etc.), it falls back to [scheduleWarmUpFrame] which
///     bypasses the OS vsync gate and drives [handleBeginFrame] /
///     [handleDrawFrame] directly, keeping the engine fully active.
class FpsBooster {
  FpsBooster._internal();
  static final FpsBooster _instance = FpsBooster._internal();
  factory FpsBooster() => _instance;

  Timer? _timer;
  bool _active = false;
  bool _unlimitedMode = false;
  int _targetFps = 60;
  bool _callbackRegistered = false;

  /// Timestamp of the last frame actually delivered by the engine.
  int _lastFrameMs = 0;

  bool get isEnabled => _active;
  bool get isUnlimitedMode => _active && _unlimitedMode;
  int get targetFps => _targetFps;

  // ── persistent frame callback ──────────────────────────────────────────────

  void _ensureCallbackRegistered() {
    if (_callbackRegistered) return;
    _callbackRegistered = true;
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
  }

  void _onFrame(Duration _) {
    _lastFrameMs = DateTime.now().millisecondsSinceEpoch;
    if (_active) SchedulerBinding.instance.scheduleFrame();
  }

  // ── public API ─────────────────────────────────────────────────────────────

  /// Render continuously at [targetFps].
  void enable({int targetFps = 120}) {
    disable();
    _targetFps = targetFps.clamp(30, 240);
    _unlimitedMode = false;
    _active = true;
    _ensureCallbackRegistered();

    final intervalMs = (1000 / _targetFps).ceil();
    // Stall threshold: if no frame for 3× interval → engine is vsync-starved.
    final stallMs = intervalMs * 3;

    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (!_active) return;
      _tickHeartbeat(stallMs);
    });

    _lastFrameMs = DateTime.now().millisecondsSinceEpoch;
    SchedulerBinding.instance.scheduleFrame();
    debugPrint('[performance] FpsBooster enabled (target=$_targetFps FPS, heartbeat=${intervalMs}ms)');
  }

  /// Render at the display's maximum refresh rate.
  void enableUnlimited() {
    disable();
    _unlimitedMode = true;
    _targetFps = 0;
    _active = true;
    _ensureCallbackRegistered();

    const heartbeatMs = 8;
    const stallMs = heartbeatMs * 3;

    _timer = Timer.periodic(const Duration(milliseconds: heartbeatMs), (_) {
      if (!_active) return;
      _tickHeartbeat(stallMs);
    });

    _lastFrameMs = DateTime.now().millisecondsSinceEpoch;
    SchedulerBinding.instance.scheduleFrame();
    debugPrint('[performance] FpsBooster enabled (unlimited, heartbeat=${heartbeatMs}ms)');
  }

  void disable() {
    _active = false;
    _timer?.cancel();
    _timer = null;
    debugPrint('[performance] FpsBooster disabled');
  }

  // ── internal ───────────────────────────────────────────────────────────────

  void _tickHeartbeat(int stallMs) {
    final elapsed = DateTime.now().millisecondsSinceEpoch - _lastFrameMs;
    if (elapsed > stallMs) {
      // OS vsync has stopped (window minimized / hidden).
      // Drive the frame pipeline directly, bypassing vsync.
      SchedulerBinding.instance.scheduleWarmUpFrame();
    } else {
      SchedulerBinding.instance.scheduleFrame();
    }
  }
}
