// lib/services/onion/onion_identity.dart
//
// This device's onion-mode identity. There is no separate keypair to
// generate/store/lose here: the Dart-level "who is this device" concept for
// pairing/session-key purposes reuses WardLinkIdentity's existing X25519
// keypair (same concept WardLink already established), domain-separated at
// the session-key layer (see OnionCrypto) rather than by minting a second
// identity.
//
// The Tor v3 onion service's own identity key (mandatorily Ed25519, per the
// Tor spec) is a *different* key that lives entirely inside the onyx_tor
// Rust plugin -- it is generated and persisted there, on first
// `startHiddenService` call, under the state directory this class points
// it at. Dart only ever sees the resulting public `.onion` address string.

import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, ValueNotifier;
import 'package:onyx_tor/onyx_tor.dart';

import '../../globals.dart' show wsConnectedNotifier;
import 'onion_account_key.dart';

class OnionIdentity {
  OnionIdentity._();

  /// Arbitrary BEGIN-cell target port used to identify onion-mode chat
  /// streams on this device's hidden service. It has no other significance
  /// (it is not a real listening socket bound anywhere) -- it only needs to
  /// be the same value on both sides of a pairing, so it's hardcoded here.
  static const int port = 9420;

  static final OnyxTor plugin = OnyxTor();

  static String? _onionAddress;
  static bool _running = false;
  static StreamSubscription<Map<String, dynamic>>? _logSub;

  /// Set by root_screen so bootstrap progress ("bootstrapping...",
  /// "connecting to the Tor network...", the exact native return code, etc.)
  /// lands in the same on-disk app log used everywhere else. Without this,
  /// a hang during [start] is a black box: the Rust side has no console to
  /// print to on a windowed build, so nothing at all would be visible about
  /// how far it got.
  static void Function(String)? onLog;

  /// Live Tor state for the UI: `ready` = hidden service is up.
  static final ValueNotifier<OnionStatus> status =
      ValueNotifier(const OnionStatus(OnionPhase.off));

  static void _setStatus(OnionPhase phase, {int? percent}) {
    status.value = OnionStatus(phase, percent: percent);
    // Tor is the app's only network link now — keep the app-wide "connected"
    // flag (tray, header dots, about dialog) truthful.
    wsConnectedNotifier.value = phase == OnionPhase.ready;
  }

  static final RegExp _pctRe = RegExp(r'bootstrap progress: (\d+)%');

  static String get publicKeyB64 => OnionAccountKey.publicKeyB64;

  static bool get isRunning => _running;

  static String get onionAddress {
    final addr = _onionAddress;
    if (addr == null) {
      throw StateError(
          'OnionIdentity.start() has not completed yet (still bootstrapping, or never called).');
    }
    return addr;
  }

  static void _log(String message) {
    final cb = onLog;
    if (cb != null) {
      cb('[onion] $message');
    } else if (kDebugMode) {
      print('[onion] $message');
    }
  }

  /// Max time to wait for a single native onyx_tor call before giving up.
  /// Generous relative to the ~30s bootstrap the plugin documents, so a
  /// healthy-but-slow bootstrap never gets cut off, but a genuinely stuck
  /// native call (e.g. Tor unreachable and arti retrying with no end in
  /// sight) now fails loudly after a bounded wait instead of leaving
  /// [start]'s caller awaiting forever.
  // Must stay comfortably above tor_bootstrap.dart's internal bootstrap
  // timeout (240s) -- this wraps that whole call, so a tighter value here
  // would cut it off with a less useful error before the inner timeout
  // ever gets a chance to fire.
  static const Duration _callTimeout = Duration(seconds: 270);

  /// Idempotently bootstraps a persistent Tor client rooted at [stateDir]
  /// and launches this device's onion service. The service's Ed25519
  /// identity key is generated on first launch and persisted under
  /// [stateDir] from then on -- calling this again with the same
  /// [stateDir] (e.g. after an app restart) reuses the same key and
  /// therefore the same `.onion` address. Bootstrapping over the live Tor
  /// network can take up to ~30s.
  static Future<void> start(String stateDir, String username) async {
    if (_running) return;
    // Attach the log forwarder before making any native call -- the Rust
    // side emits its "bootstrapping.../bootstrapped" progress events during
    // startHiddenService itself, and an EventChannel drops anything emitted
    // before a listener is attached, so subscribing after start() returns
    // (as OnionTransportService.start does for the *events* stream) would
    // silently lose exactly the messages needed to diagnose a hang here.
    _logSub ??= plugin.events.listen((event) {
      if (event['type'] == 'log') {
        final msg = '${event['message']}';
        final m = _pctRe.firstMatch(msg);
        if (m != null && !_running) {
          _setStatus(OnionPhase.bootstrapping, percent: int.parse(m.group(1)!));
        }
        _log(msg);
      }
    });
    _setStatus(OnionPhase.bootstrapping, percent: 0);
    try {
      await _startInner(stateDir, username);
    } catch (_) {
      _setStatus(OnionPhase.failed);
      rethrow;
    }
  }

  static Future<void> _startInner(String stateDir, String username) async {
    await OnionAccountKey.load(username);
    _log('calling startHiddenService($stateDir, $port)...');
    final rc = await plugin.startHiddenService(stateDir, port).timeout(
      _callTimeout,
      onTimeout: () => throw TimeoutException(
          'startHiddenService did not return within $_callTimeout'),
    );
    _log('startHiddenService returned $rc');
    if (rc != 0) {
      throw StateError('onyx_tor startHiddenService failed with code $rc');
    }
    final address = await plugin.hsAddress().timeout(
      _callTimeout,
      onTimeout: () => throw TimeoutException(
          'hsAddress did not return within $_callTimeout'),
    );
    _log('hsAddress returned ${address ?? "<null>"}');
    if (address == null || address.isEmpty) {
      throw StateError('onyx_tor hsAddress returned nothing after start');
    }
    _onionAddress = address;
    _running = true;
    _setStatus(OnionPhase.ready);
  }

  static Future<void> stop() async {
    if (!_running) return;
    await plugin.stopHiddenService();
    _running = false;
    _setStatus(OnionPhase.off);
  }
}

enum OnionPhase { off, bootstrapping, ready, failed }

class OnionStatus {
  final OnionPhase phase;
  final int? percent;
  const OnionStatus(this.phase, {this.percent});
}
