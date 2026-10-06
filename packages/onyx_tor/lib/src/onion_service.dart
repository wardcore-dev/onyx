// The actual hidden-service implementation backing OnyxTor's public API
// (see ../onyx_tor.dart). Everything here talks to a real tor daemon over
// the standard control-port protocol and a local loopback listener/SOCKS
// dial -- no FFI, no arti-client, no in-process Tor client competing with
// Flutter's own threads for CPU.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'tor_bootstrap.dart';
import 'tor_control_client.dart';
import 'tor_socks_client.dart';

class OnyxTorStreamReadResult {
  const OnyxTorStreamReadResult(this.n, this.data);
  final int n;
  final Uint8List? data;
}

/// One relay hop of a Tor circuit, as reported by the control port.
class TorRelayHop {
  final String fingerprint;
  final String? nickname;
  final String? address;

  /// Two-letter ISO country code (e.g. "LU"), from tor's own bundled GeoIP
  /// database via the control port -- null if unknown/unavailable.
  final String? countryCode;
  const TorRelayHop(
      {required this.fingerprint,
      this.nickname,
      this.address,
      this.countryCode});
}

/// One circuit currently known to the local tor daemon.
class TorCircuit {
  final String id;
  final String status;
  final String purpose;
  final List<TorRelayHop> hops;

  /// The .onion address this circuit is for, when it's an onion-service
  /// circuit that names one (REND_QUERY) -- null for a plain GENERAL circuit.
  final String? rendQuery;
  const TorCircuit(
      {required this.id,
      required this.status,
      required this.purpose,
      required this.hops,
      this.rendQuery});
}

class OnionService {
  TorBootstrapResult? _bootstrap;
  ServerSocket? _inboundListener;
  StreamSubscription<Socket>? _inboundSub;
  String? _onionServiceId;
  bool _accepting = false;

  final _events = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _events.stream;

  final _handles = <int, TorByteConnection>{};
  int _nextHandle = 1;

  void _log(String message) {
    _events.add({'type': 'log', 'message': message});
  }

  bool get isRunning => _bootstrap != null && _onionServiceId != null;

  /// Local SOCKS5 port of the running tor daemon (null while it isn't up).
  /// Lets the app route plain HTTP/WebSocket clients through Tor too.
  int? get socksPort => _bootstrap?.socksPort;

  // Guards against two overlapping startHiddenService() calls (e.g. the
  // owning widget getting initialized twice in one app launch) racing to
  // spawn two tor processes against the same stateDir -- the second one
  // always loses ("another Tor process is running with the same data
  // directory... Dying.") and used to surface as a confusing false failure
  // even though the first instance came up fine.
  Future<int>? _startInFlight;

  Future<int> startHiddenService(String stateDir, int virtualPort) {
    if (isRunning) return Future.value(0);
    return _startInFlight ??=
        _startHiddenServiceImpl(stateDir, virtualPort).whenComplete(() {
      _startInFlight = null;
    });
  }

  Future<int> _startHiddenServiceImpl(String stateDir, int virtualPort) async {
    try {
      // Bootstrap fires progress roughly every 1-5%, i.e. 20-100 calls
      // across one bootstrap -- logging (and therefore debugPrint-ing on
      // the UI isolate) every single one visibly stutters frame scheduling
      // even though no individual call is slow. Only surface it in tens.
      var lastLoggedDecile = -1;
      _bootstrap = await TorBootstrap.start(
        dataDir: stateDir,
        onBootstrapProgress: (pct) {
          final decile = pct ~/ 10;
          if (decile != lastLoggedDecile) {
            lastLoggedDecile = decile;
            _log('bootstrap progress: $pct%');
          }
        },
        onLog: _log,
      );

      _inboundListener =
          await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      _accepting = true;
      _inboundSub = _inboundListener!.listen((socket) {
        if (!_accepting) {
          socket.destroy();
          return;
        }
        final handle = _nextHandle++;
        _handles[handle] = TorByteConnection(socket);
        _events.add({'type': 'inbound', 'handle': handle});
      });

      final keyFile = File(p.join(stateDir, 'hs_ed25519_key_blob'));
      final existingKey =
          await keyFile.exists() ? await keyFile.readAsString() : null;

      final onion = await _bootstrap!.control.addOnion(
        virtualPort: virtualPort,
        targetPort: _inboundListener!.port,
        keyBlob: existingKey?.trim().isEmpty == true ? null : existingKey,
      );
      if (onion.privateKeyBlob != null) {
        await keyFile.writeAsString(onion.privateKeyBlob!);
      }
      _onionServiceId = onion.serviceId;
      _log('hidden service ready: ${onion.serviceId}.onion');
      return 0;
    } catch (e) {
      _log('startHiddenService failed: $e');
      await stopHiddenService();
      return -1;
    }
  }

  Future<int> stopHiddenService() async {
    _accepting = false;
    try {
      if (_onionServiceId != null) {
        await _bootstrap?.control.delOnion(_onionServiceId!);
      }
    } catch (_) {}
    await _inboundSub?.cancel();
    _inboundSub = null;
    await _inboundListener?.close();
    _inboundListener = null;
    for (final conn in _handles.values) {
      await conn.close();
    }
    _handles.clear();
    try {
      await _bootstrap?.control.close();
    } catch (_) {}
    await _killAndWait(_bootstrap?.process);
    _bootstrap = null;
    _onionServiceId = null;
    return 0;
  }

  /// Sends SIGTERM and actually waits for the process to exit (escalating to
  /// SIGKILL if it doesn't within 5s) before returning -- [Process.kill]
  /// alone only *requests* termination and returns immediately, it doesn't
  /// wait for the OS to reap the process. The previous code returned right
  /// after calling it, so a caller doing stop() then start() again (e.g. the
  /// "Restart Tor" button) could spawn a new tor pointed at the same
  /// DataDirectory while the old one was still mid-shutdown, or -- worse, if
  /// it hung on the way out -- alive indefinitely as an orphan holding onto
  /// the directory lock file, permanently reproducing "another Tor process
  /// is running with the same data directory ... Dying." However this
  /// method exited, we'd already dropped our only handle to that process by
  /// nulling [_bootstrap], so nothing could ever kill it again from within
  /// the app afterwards -- only a full app kill (which tears down its whole
  /// process tree) would free the lock.
  Future<void> _killAndWait(Process? process) async {
    if (process == null) return;
    try {
      process.kill();
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      try {
        process.kill(ProcessSignal.sigkill);
        await process.exitCode.timeout(const Duration(seconds: 3));
      } catch (_) {}
    } catch (_) {}
  }

  /// Tells tor the device's network changed (Wi-Fi <-> mobile etc.). Without
  /// this, tor keeps its guard connections bound to the old interface, which
  /// are silently dead now -- no RST ever arrives, so it only notices after
  /// its own keepalive (~5 min+). Until then every outgoing dial hangs and,
  /// worse, our onion service's intro circuits are dead too, so nobody can
  /// reach us either. Toggling DisableNetwork drops every OR connection and
  /// circuit at once and makes tor rebuild them (and re-publish the onion
  /// service descriptor) over the new network -- the same thing Orbot does
  /// on a connectivity change. Returns false if tor isn't running.
  Future<bool> resetNetwork() async {
    final control = _bootstrap?.control;
    if (control == null) return false;
    try {
      await control.sendCommand('SETCONF DisableNetwork=1');
      final reply = await control.sendCommand('SETCONF DisableNetwork=0');
      // Wakes tor if it went dormant while the network was down.
      await control.sendCommand('SIGNAL ACTIVE');
      if (!reply.isOk) {
        _log('network reset: ${reply.lines}');
        return false;
      }
      // Return as soon as tor has a working circuit again (usually 1-3s),
      // so the caller can redial right then instead of guessing a delay.
      final sw = Stopwatch()..start();
      while (sw.elapsed < const Duration(seconds: 20)) {
        await Future.delayed(const Duration(milliseconds: 200));
        final st = await control.sendCommand('GETINFO status/circuit-established');
        if (st.lines.any((l) => l.contains('circuit-established=1'))) break;
      }
      _log('network reset: tor ready in ${sw.elapsedMilliseconds}ms');
      return true;
    } catch (e) {
      _log('network reset failed: $e');
      return false;
    }
  }

  Future<String?> hsAddress() async {
    final id = _onionServiceId;
    return id == null ? null : '$id.onion';
  }

  Future<int?> dial(String onionAddr, int port, {String? isolation}) async {
    final bootstrap = _bootstrap;
    if (bootstrap == null) return -1;
    try {
      final conn = await torSocksConnect(
        socksPort: bootstrap.socksPort,
        host: onionAddr,
        port: port,
        isolation: isolation,
      );
      final handle = _nextHandle++;
      _handles[handle] = conn;
      return handle;
    } catch (e) {
      _log('dial $onionAddr:$port failed: $e');
      return -2;
    }
  }

  Future<int?> streamWrite(int handle, Uint8List data) async {
    final conn = _handles[handle];
    if (conn == null) return -1;
    try {
      conn.write(data);
      await conn.flush();
      return data.length;
    } catch (e) {
      _log('streamWrite($handle) failed: $e');
      return -2;
    }
  }

  Future<OnyxTorStreamReadResult> streamRead(
    int handle,
    int maxLen,
    int timeoutMs,
  ) async {
    final conn = _handles[handle];
    if (conn == null) return const OnyxTorStreamReadResult(-1, null);
    try {
      final chunk =
          await conn.read(maxLen, Duration(milliseconds: timeoutMs));
      if (chunk == null) return const OnyxTorStreamReadResult(-3, null);
      if (chunk.isEmpty) return const OnyxTorStreamReadResult(0, null);
      return OnyxTorStreamReadResult(chunk.length,
          chunk is Uint8List ? chunk : Uint8List.fromList(chunk));
    } catch (e) {
      _log('streamRead($handle) failed: $e');
      return const OnyxTorStreamReadResult(-2, null);
    }
  }

  Future<int?> streamClose(int handle) async {
    final conn = _handles.remove(handle);
    if (conn == null) return 0;
    try {
      await conn.close();
    } catch (e) {
      _log('streamClose($handle) failed: $e');
    }
    return 0;
  }

  /// Lists the circuits the local tor daemon currently has built, each with
  /// its relay path -- "what your traffic is routed through" for the
  /// in-app circuit viewer. Best-effort: returns an empty list if the
  /// control connection isn't up (e.g. hidden service not started yet).
  Future<List<TorCircuit>> getCircuits() async {
    final control = _bootstrap?.control;
    if (control == null) return [];
    try {
      final reply = await control.sendCommand('GETINFO circuit-status');
      if (!reply.isOk) return [];
      final circuits = <TorCircuit>[];
      for (final raw in reply.lines) {
        final line = raw.startsWith('circuit-status=')
            ? raw.substring('circuit-status='.length)
            : raw;
        if (line.isEmpty || line == 'OK') continue;
        final parts = line.split(' ');
        if (parts.length < 3) continue;
        final id = parts[0];
        final status = parts[1];
        final path = parts[2];
        String purpose = 'GENERAL';
        String? rendQuery;
        for (final field in parts.skip(3)) {
          if (field.startsWith('PURPOSE=')) {
            purpose = field.substring('PURPOSE='.length);
          } else if (field.startsWith('REND_QUERY=')) {
            rendQuery = field.substring('REND_QUERY='.length);
          }
        }
        final hops = path.split(',').where((h) => h.isNotEmpty).map((h) {
          final noDollar = h.startsWith('\$') ? h.substring(1) : h;
          final tildeIdx = noDollar.indexOf('~');
          if (tildeIdx == -1) {
            return TorRelayHop(fingerprint: noDollar);
          }
          return TorRelayHop(
            fingerprint: noDollar.substring(0, tildeIdx),
            nickname: noDollar.substring(tildeIdx + 1),
          );
        }).toList();
        circuits.add(TorCircuit(
            id: id,
            status: status,
            purpose: purpose,
            hops: hops,
            rendQuery: rendQuery));
      }
      await _fillHopAddresses(control, circuits);
      return circuits;
    } catch (_) {
      return [];
    }
  }

  /// Best-effort: looks up each hop's advertised IP via the relay's network
  /// status document (GETINFO ns/id/<fingerprint>), and its country from
  /// tor's own bundled GeoIP database (GETINFO ip-to-country/<ip>) -- no
  /// separate GeoIP file needed, tor already ships one for its own use.
  /// Failures are silently skipped -- both are a bonus, not something the
  /// viewer depends on.
  Future<void> _fillHopAddresses(
      TorControlClient control, List<TorCircuit> circuits) async {
    final addrByFp = <String, String?>{};
    for (final c in circuits) {
      for (final h in c.hops) {
        if (addrByFp.containsKey(h.fingerprint)) continue;
        addrByFp[h.fingerprint] =
            await _lookupRelayAddress(control, h.fingerprint);
      }
    }
    final countryByAddr = <String, String?>{};
    for (final addr in addrByFp.values) {
      if (addr == null || countryByAddr.containsKey(addr)) continue;
      countryByAddr[addr] = await _lookupCountry(control, addr);
    }
    for (var ci = 0; ci < circuits.length; ci++) {
      final c = circuits[ci];
      final newHops = c.hops.map((h) {
        final addr = addrByFp[h.fingerprint];
        return TorRelayHop(
          fingerprint: h.fingerprint,
          nickname: h.nickname,
          address: addr,
          countryCode: addr == null ? null : countryByAddr[addr],
        );
      }).toList();
      circuits[ci] = TorCircuit(
          id: c.id,
          status: c.status,
          purpose: c.purpose,
          hops: newHops,
          rendQuery: c.rendQuery);
    }
  }

  /// Two-letter ISO country code for [address] per tor's bundled GeoIP
  /// database, or null if tor has no GeoIPFile configured or the address
  /// isn't in it (common for IPv6 unless a GeoIPv6File is also set).
  Future<String?> _lookupCountry(TorControlClient control, String address) async {
    try {
      final reply = await control.sendCommand('GETINFO ip-to-country/$address');
      if (!reply.isOk) return null;
      final prefix = 'ip-to-country/$address=';
      for (final raw in reply.lines) {
        if (!raw.startsWith(prefix)) continue;
        final code = raw.substring(prefix.length).trim().toUpperCase();
        if (code.isEmpty || code == '??') return null;
        return code;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _lookupRelayAddress(
      TorControlClient control, String fp) async {
    try {
      final reply = await control.sendCommand('GETINFO ns/id/$fp');
      if (!reply.isOk) return null;
      for (final raw in reply.lines) {
        final line = raw.startsWith('ns/id/$fp=')
            ? raw.substring('ns/id/$fp='.length)
            : raw;
        if (!line.startsWith('r ')) continue;
        final fields = line.split(' ');
        // r nickname identity digest date time IP ORPort DirPort
        if (fields.length >= 7) return fields[6];
      }
    } catch (_) {}
    return null;
  }
}
