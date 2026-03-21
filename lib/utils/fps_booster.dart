import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Keeps Flutter rendering at the display refresh rate.
///
/// Strategy:
///  1. [addPersistentFrameCallback] maintains a self-perpetuating render loop
///     while Flutter is already producing frames.
///  2. A low-frequency [Timer.periodic] acts as a heartbeat to restart the
///     loop if Flutter went idle (no dirty widgets → persistent callback stops
///     firing → without the timer FPS would drop to near-zero on Windows).
///
/// The timer fires at most [_heartbeatMs] times per second (default 8 ms →
/// 125/s), compared to the previous 1 ms → 1000/s implementation.
/// [scheduleFrame] is idempotent when a frame is already pending, so the
/// extra calls are essentially free.
class FpsBooster {
  FpsBooster._internal();
  static final FpsBooster _instance = FpsBooster._internal();
  factory FpsBooster() => _instance;

  Timer? _timer;
  bool _active = false;
  bool _unlimitedMode = false;
  int _targetFps = 60;
  bool _callbackRegistered = false;

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
    if (_active) SchedulerBinding.instance.scheduleFrame();
  }

  // ── public API ─────────────────────────────────────────────────────────────

  /// Render continuously at [targetFps].
  /// Heartbeat timer fires at the same interval so idle gaps are ≤ one frame.
  void enable({int targetFps = 120}) {
    disable();
    _targetFps = targetFps.clamp(30, 240);
    _unlimitedMode = false;
    _active = true;
    _ensureCallbackRegistered();

    final intervalMs = (1000 / _targetFps).ceil();
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (_active) SchedulerBinding.instance.scheduleFrame();
    });

    SchedulerBinding.instance.scheduleFrame();
    debugPrint('[performance] FpsBooster enabled (target=$_targetFps FPS, heartbeat=${intervalMs}ms)');
  }

  /// Render at the display's maximum refresh rate.
  /// Heartbeat fires every 8 ms (≤ 125/s), enough for up to ~120 Hz displays
  /// without the thermal pressure of the previous 1 ms / 1000/s approach.
  void enableUnlimited() {
    disable();
    _unlimitedMode = true;
    _targetFps = 0;
    _active = true;
    _ensureCallbackRegistered();

    const heartbeatMs = 8;
    _timer = Timer.periodic(const Duration(milliseconds: heartbeatMs), (_) {
      if (_active) SchedulerBinding.instance.scheduleFrame();
    });

    SchedulerBinding.instance.scheduleFrame();
    debugPrint('[performance] FpsBooster enabled (unlimited, heartbeat=${heartbeatMs}ms)');
  }

  void disable() {
    _active = false;
    _timer?.cancel();
    _timer = null;
    debugPrint('[performance] FpsBooster disabled');
  }
}
