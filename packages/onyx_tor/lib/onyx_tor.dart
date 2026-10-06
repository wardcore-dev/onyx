// Public API. Kept byte-for-byte identical to the previous arti-client/FFI
// plugin's surface (see git history) so lib/services/onion/onion_identity.dart
// and lib/services/onion/onion_transport_service.dart -- the app-level
// callers -- needed no changes at all for this rewrite. What changed is
// entirely underneath: every call here is now backed by a real tor daemon
// (subprocess everywhere except iOS, where the sandbox forbids that and
// Tor.framework runs it in-process instead) driven over the standard
// control-port protocol, instead of an in-process arti-client Rust runtime
// competing with Flutter's own threads for CPU.
import 'dart:typed_data';

import 'src/onion_service.dart';

export 'src/onion_service.dart'
    show OnyxTorStreamReadResult, TorCircuit, TorRelayHop;

class OnyxTor {
  static final OnionService _service = OnionService();

  Future<String?> getPlatformVersion() async => 'onyx_tor (tor daemon)';

  /// No longer meaningful now that there is no embedded native library to
  /// sanity-check -- kept only so any leftover callers don't crash.
  Future<int?> ping(int value) async => value + 1;

  /// Idempotently bootstraps a tor daemon rooted at [stateDir], then
  /// launches this device's onion service listening on [port] if it isn't
  /// already running. The first call for a given [stateDir] mints this
  /// device's Ed25519 onion identity (persisted under [stateDir] from then
  /// on, so later calls/app restarts reuse the same `.onion` address);
  /// bootstrapping over the live Tor network can take up to ~60-90s.
  /// Returns 0 on success (including "was already running"), or a negative
  /// error code.
  Future<int?> startHiddenService(String stateDir, int port) {
    return _service.startHiddenService(stateDir, port);
  }

  /// Stops accepting new inbound connections and tears down the tor daemon
  /// this device started. Streams already accepted keep working until
  /// explicitly closed.
  Future<int?> stopHiddenService() {
    return _service.stopHiddenService();
  }

  /// Call when the device's network changed (Wi-Fi <-> mobile, new Wi-Fi):
  /// makes tor drop its now-dead connections and rebuild circuits and the
  /// onion service's intro points over the new network. Returns false if
  /// tor isn't running.
  Future<bool> resetNetwork() => _service.resetNetwork();

  /// This device's onion address (e.g. `"abcd...xyz.onion"`), or `null` if
  /// the hidden service isn't running (call [startHiddenService] first).
  Future<String?> hsAddress() {
    return _service.hsAddress();
  }

  /// Dials `onionAddr:port` over Tor (via the local tor daemon's SOCKS
  /// port) and returns an opaque stream handle (>= 1) for use with
  /// [streamWrite]/[streamRead]/[streamClose], or a negative error code.
  /// Streams dialed with different [isolation] tokens use different Tor
  /// circuits (see torSocksConnect).
  Future<int?> dial(String onionAddr, int port, {String? isolation}) {
    return _service.dial(onionAddr, port, isolation: isolation);
  }

  /// Writes [data] to the stream identified by [handle]. Returns bytes
  /// written, or a negative error code.
  Future<int?> streamWrite(int handle, Uint8List data) {
    return _service.streamWrite(handle, data);
  }

  /// Read of up to [maxLen] bytes from the stream identified by [handle],
  /// waiting at most [timeoutMs] milliseconds. `n == 0` means the peer
  /// closed the stream, `n == -3` means the read timed out with nothing
  /// available, any other negative `n` is a hard error.
  Future<OnyxTorStreamReadResult> streamRead(
    int handle,
    int maxLen,
    int timeoutMs,
  ) {
    return _service.streamRead(handle, maxLen, timeoutMs);
  }

  /// Closes the stream identified by [handle]. Safe to call more than once.
  Future<int?> streamClose(int handle) {
    return _service.streamClose(handle);
  }

  /// Broadcast stream of hidden-service events:
  /// `{'type': 'inbound', 'handle': <int>}` whenever a peer's stream is
  /// accepted on the running hidden service (read it with [streamRead]),
  /// and `{'type': 'log', 'message': <String>}` for bootstrap/diagnostic
  /// progress.
  Stream<Map<String, dynamic>> get events => _service.events;

  /// The local tor daemon's SOCKS5 port on 127.0.0.1, or `null` if tor isn't
  /// running yet. For routing HTTP/WebSocket traffic through Tor.
  int? get socksPort => _service.socksPort;

  /// Lists the circuits the local tor daemon currently has built, so the app
  /// can show "what your traffic is routed through" -- best-effort, returns
  /// an empty list if the hidden service (and its control connection) isn't
  /// up yet.
  Future<List<TorCircuit>> getCircuits() => _service.getCircuits();
}
