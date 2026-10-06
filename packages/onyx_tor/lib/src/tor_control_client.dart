// Minimal client for the Tor control-port protocol
// (https://spec.torproject.org/control-spec/), the same protocol Tor
// Browser/Orbot/Briar have driven their bundled tor daemons through for
// years. It is a plain line-based text protocol over a TCP socket -- no
// native code needed to speak it, which is exactly why this whole
// architecture (a real tor daemon, controlled from Dart, running as a
// subprocess everywhere except iOS) replaced the previous in-process
// arti-client/FFI design.
//
// Reply framing: each reply is one or more lines, all but the last starting
// with "<code>-", the last starting with "<code> " (space, not dash). An
// unsolicited async event (subscribed to via SETEVENTS) arrives the same
// way but with code 650 and no request preceding it, so replies and events
// are demultiplexed here by whether a request is currently awaiting one.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class TorControlException implements Exception {
  final String message;
  TorControlException(this.message);
  @override
  String toString() => 'TorControlException: $message';
}

class TorControlReply {
  final int code;
  final List<String> lines;
  const TorControlReply(this.code, this.lines);
  bool get isOk => code >= 250 && code < 300;
}

class TorControlClient {
  TorControlClient._(this._socket);

  final Socket _socket;
  final _pendingReplies = <Completer<TorControlReply>>[];
  final _eventsController = StreamController<TorControlReply>.broadcast();
  StreamSubscription<String>? _lineSub;
  bool _closed = false;

  Stream<TorControlReply> get events => _eventsController.stream;

  /// Connects to the control port at 127.0.0.1:[controlPort], retrying with
  /// backoff since the tor process may not have opened its listener yet
  /// (Process.start returning doesn't mean tor has finished parsing its own
  /// config and binding sockets).
  static Future<TorControlClient> connect(
    int controlPort, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(timeout);
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      try {
        final socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          controlPort,
          timeout: const Duration(seconds: 2),
        );
        return TorControlClient._(socket).._listen();
      } catch (e) {
        lastError = e;
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }
    throw TorControlException(
        'could not connect to control port $controlPort: $lastError');
  }

  // Set while inside a "+"-introduced multi-line data block (e.g.
  // GETINFO circuit-status's per-circuit lines): those lines carry no
  // "<code><sep>" prefix at all -- they're raw data, terminated by a lone
  // "." line -- unlike a "-"-continued reply, where every line still starts
  // with the 3-digit code. Conflating the two used to silently drop every
  // data line (int.tryParse("16 ".substring(0,3)) is null, so the whole
  // line was discarded), which is why circuit-status always came back empty.
  bool _inDataBlock = false;

  void _listen() {
    final buffer = <String>[];
    _lineSub = _socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _onLine(line, buffer),
            // tor dying mid-session surfaces as a socket error
            // ("Connection reset by peer"); without a handler that became
            // an unhandled exception instead of a failed command.
            onError: (Object _) => _failPending(),
            onDone: _failPending,
            cancelOnError: true);
  }

  void _failPending() {
    _closed = true;
    for (final c in _pendingReplies) {
      if (!c.isCompleted) {
        c.completeError(TorControlException('control connection closed'));
      }
    }
    _pendingReplies.clear();
  }

  void _onLine(String line, List<String> buffer) {
    if (_inDataBlock) {
      if (line == '.') {
        _inDataBlock = false;
        return;
      }
      // Dot-stuffing: a data line that starts with '.' is escaped as '..'.
      buffer.add(line.startsWith('..') ? line.substring(1) : line);
      return;
    }
    if (line.length < 4) return;
    final code = int.tryParse(line.substring(0, 3));
    final sep = line[3];
    final rest = line.substring(4);
    if (code == null) return;
    if (sep == '+') {
      buffer.add(rest);
      _inDataBlock = true;
      return; // data block lines follow, unprefixed, until a lone "."
    }
    buffer.add(rest);
    if (sep == '-') {
      return; // continuation line, keep buffering
    }
    // sep == ' ' -> final line of this reply.
    final reply = TorControlReply(code, List.unmodifiable(buffer));
    buffer.clear();
    if (code == 650) {
      _eventsController.add(reply);
      return;
    }
    if (_pendingReplies.isNotEmpty) {
      _pendingReplies.removeAt(0).complete(reply);
    }
  }

  Future<TorControlReply> sendCommand(String command) async {
    if (_closed) throw TorControlException('control connection closed');
    final completer = Completer<TorControlReply>();
    _pendingReplies.add(completer);
    _socket.write('$command\r\n');
    await _socket.flush();
    return completer.future;
  }

  /// Authenticates using SAFECOOKIE/COOKIE auth: reads the raw cookie bytes
  /// tor wrote to [cookieFilePath] (set via --CookieAuthFile so the path is
  /// known exactly, rather than guessed inside DataDirectory) and sends them
  /// hex-encoded, per the control-spec's cookie authentication method.
  Future<void> authenticateWithCookie(String cookieFilePath) async {
    final cookieFile = File(cookieFilePath);
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!await cookieFile.exists()) {
      if (DateTime.now().isAfter(deadline)) {
        throw TorControlException(
            'cookie file $cookieFilePath never appeared');
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    final bytes = await cookieFile.readAsBytes();
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final reply = await sendCommand('AUTHENTICATE $hex');
    if (!reply.isOk) {
      throw TorControlException('AUTHENTICATE failed: ${reply.lines}');
    }
  }

  Future<void> setEvents(List<String> eventNames) async {
    final reply = await sendCommand('SETEVENTS ${eventNames.join(' ')}');
    if (!reply.isOk) {
      throw TorControlException('SETEVENTS failed: ${reply.lines}');
    }
  }

  /// Creates (or restores, if [keyBlob] is given) a v3 onion service whose
  /// virtual port [virtualPort] forwards to 127.0.0.1:[targetPort] (our own
  /// local listener that accepts inbound onion-mode chat streams). `Detach`
  /// keeps the service alive even if this control connection later drops.
  /// Returns the service's address (without ".onion") and, on first
  /// creation, its private key blob (null when [keyBlob] was supplied, since
  /// tor doesn't echo back a key you already gave it).
  Future<({String serviceId, String? privateKeyBlob})> addOnion({
    required int virtualPort,
    required int targetPort,
    String? keyBlob,
  }) async {
    final keySpec = keyBlob ?? 'NEW:ED25519-V3';
    final reply = await sendCommand(
        'ADD_ONION $keySpec Flags=Detach Port=$virtualPort,127.0.0.1:$targetPort');
    if (!reply.isOk) {
      throw TorControlException('ADD_ONION failed: ${reply.lines}');
    }
    String? serviceId;
    String? privateKey;
    for (final line in reply.lines) {
      if (line.startsWith('ServiceID=')) {
        serviceId = line.substring('ServiceID='.length);
      } else if (line.startsWith('PrivateKey=')) {
        privateKey = line.substring('PrivateKey='.length);
      }
    }
    if (serviceId == null) {
      throw TorControlException('ADD_ONION reply missing ServiceID');
    }
    return (serviceId: serviceId, privateKeyBlob: privateKey);
  }

  Future<void> delOnion(String serviceId) async {
    await sendCommand('DEL_ONION $serviceId');
  }

  Future<void> close() async {
    _closed = true;
    await _lineSub?.cancel();
    await _eventsController.close();
    await _socket.close();
  }
}
