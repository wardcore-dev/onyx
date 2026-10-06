// Incoming-call alerts:
//  - computers: a looping ringtone while it rings;
//  - phones: no sound or vibration at all (product decision). In the
//    foreground the in-app call screen is the alert; in the background
//    (Android) a silent system call notification -- big Accept / Decline
//    buttons, full screen over the lock screen (CallNotifications.kt).
//    Accept opens the app straight into the call, Decline rejects it
//    without opening anything.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import '../managers/settings_manager.dart';
import '../widgets/avatar_widget.dart' show getAvatarCachedBytes;
import 'call_manager.dart';

class CallNotification {
  CallNotification._();

  static const _ch = MethodChannel('onyx/call_notification');
  static final AudioPlayer _ring = AudioPlayer();
  static AppLifecycleListener? _life;
  static bool _ringing = false;
  static bool _notified = false;
  static bool _overLock = false;

  static bool get _android => !kIsWeb && Platform.isAndroid;

  /// Ringtones only on computers; phones stay silent (no ringtone, no
  /// vibration -- the call notification's channel is silent too).
  static bool get _desktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static bool get _foreground {
    final s = WidgetsBinding.instance.lifecycleState;
    return s == null || s == AppLifecycleState.resumed;
  }

  /// Called once from RootScreen.
  static void init() {
    if (_life != null) return;
    _life = AppLifecycleListener(onStateChange: (_) => _sync());
    callManager.isIncomingCall.addListener(_sync);
    callManager.isInCall.addListener(_sync);
    if (_android) {
      _ch.setMethodCallHandler(_onNative);
      unawaited(_takePending());
    }
  }

  static Future<dynamic> _onNative(MethodCall call) async {
    await _handle(call.method);
    return true;
  }

  /// An Accept/Decline/tap that came in before Dart was listening.
  static Future<void> _takePending() async {
    try {
      final p = await _ch.invokeMapMethod<String, dynamic>('takePending');
      final action = p?['action'] as String?;
      if (action != null) await _handle(action);
    } catch (_) {}
  }

  static Future<void> _handle(String action) async {
    debugPrint('[call-notif] $action');
    switch (action) {
      case 'accept':
        if (callManager.isIncomingCall.value) {
          await callManager.acceptCall();
        }
        break;
      case 'decline':
        if (callManager.isIncomingCall.value) callManager.rejectCall();
        break;
      case 'open':
        // The app is up now; the in-app incoming screen takes over.
        break;
    }
    _sync();
  }

  static void _sync() {
    final ringing = callManager.isIncomingCall.value;
    final inCall = callManager.isInCall.value;

    // Ringtone: desktop only, while ringing (on a computer the window may
    // well be in the background, and the sound is the only cue).
    final wantRing = ringing && _desktop;
    if (wantRing != _ringing) {
      _ringing = wantRing;
      unawaited(wantRing ? _startRing() : _stopRing());
    }

    if (_android) {
      // System notification: only while we're in the background.
      final wantNotif = ringing && !_foreground;
      if (wantNotif && !_notified) {
        _notified = true;
        unawaited(_showNotification());
      } else if (!wantNotif && _notified) {
        _notified = false;
        unawaited(_ch.invokeMethod('cancel').catchError((_) {}));
      }
      // Call screen over the lock screen while ringing / in a call.
      final wantOverLock = ringing || inCall;
      if (wantOverLock != _overLock) {
        _overLock = wantOverLock;
        unawaited(_ch
            .invokeMethod('setShowOverLock', {'on': wantOverLock})
            .catchError((_) {}));
      }
    }
  }

  static Future<void> _startRing() async {
    try {
      await _ring.setReleaseMode(ReleaseMode.loop);
      await _ring.play(AssetSource('onyxringtone0.wav'));
    } catch (e) {
      debugPrint('[call-notif] ringtone failed: $e');
    }
  }

  static Future<void> _stopRing() async {
    try {
      await _ring.stop();
    } catch (_) {}
  }

  static Future<void> _showNotification() async {
    final peer = callManager.incomingPeer ?? '?';
    // Same rule as message notifications: "hide content" hides who it is.
    final hide = SettingsManager.notifHideContent.value;
    final l = lookupAppLocalizations(SettingsManager.appLocale.value);
    final subtitle = callManager.incomingIsOnion
        ? '${l.callIncomingTitle} · ${l.callPathTor}'
        : l.callIncomingTitle;
    Uint8List? avatar;
    if (!hide) {
      try {
        avatar = await getAvatarCachedBytes(peer);
      } catch (_) {}
    }
    // Gone already (answered/declined while we fetched the avatar)?
    if (!_notified) return;
    try {
      await _ch.invokeMethod('show', {
        'callId': peer,
        'name': hide ? 'ONYX' : peer,
        'subtitle': subtitle,
        'avatar': avatar,
      });
    } catch (e) {
      debugPrint('[call-notif] show failed: $e');
    }
  }
}
