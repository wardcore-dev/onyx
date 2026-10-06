// Bare-minimum SOCKS5 client for dialing a .onion address through tor's
// own SocksPort (RFC 1928's CONNECT command, domain-name address type only
// -- tor resolves .onion addresses itself when handed the hostname this
// way, it never needs a real DNS lookup). This is the entire client-side
// "dial" primitive the rest of the plugin needs; tor does all the actual
// Tor-network circuit building on the other end of this local socket.
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

class TorSocksException implements Exception {
  final String message;
  TorSocksException(this.message);
  @override
  String toString() => 'TorSocksException: $message';
}

/// A connected TCP byte stream (post-SOCKS-handshake, or a plain accepted
/// inbound socket) with a poll-with-timeout read primitive, since that's
/// what the handle-based dial/streamRead/streamWrite/streamClose API this
/// plugin exposes to Dart needs -- a `Socket` can only ever be `.listen()`ed
/// once, so this wraps that single subscription and buffers/dispatches on
/// its consumer's behalf instead of exposing the raw stream.
class TorByteConnection {
  TorByteConnection(this._socket) {
    // Small frames (call audio, pings, acks) must leave immediately. With
    // Nagle on, a small write waits for the previous one's ACK -- tens to
    // hundreds of ms per hop on top of Tor's own latency, for nothing.
    try {
      _socket.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}
    _sub = _socket.listen(_onData, onError: _onError, onDone: _onDone);
  }

  final Socket _socket;
  late final StreamSubscription<Uint8List> _sub;

  // Received-but-unread bytes, as the socket's own chunks. (This used to be
  // one growable List<int> that every read shifted down with removeRange --
  // byte-by-byte copies that got quadratic with a backlog, which throttled
  // large transfers.)
  final ListQueue<Uint8List> _chunks = ListQueue<Uint8List>();
  int _buffered = 0;
  bool _eof = false;
  Object? _error;
  Completer<List<int>?>? _waiter;
  int _waiterMaxLen = 0;

  void _onData(Uint8List chunk) {
    if (chunk.isEmpty) return;
    _chunks.add(chunk);
    _buffered += chunk.length;
    _deliverIfWaiting();
  }

  /// Removes and returns up to [maxLen] buffered bytes.
  Uint8List _take(int maxLen) {
    final first = _chunks.first;
    if (first.length <= maxLen && (_chunks.length == 1 || first.length == maxLen)) {
      _chunks.removeFirst();
      _buffered -= first.length;
      return first;
    }
    final n = min(maxLen, _buffered);
    final out = Uint8List(n);
    var off = 0;
    while (off < n) {
      final c = _chunks.removeFirst();
      final need = n - off;
      if (c.length <= need) {
        out.setRange(off, off + c.length, c);
        off += c.length;
      } else {
        out.setRange(off, n, c);
        _chunks.addFirst(Uint8List.sublistView(c, need));
        off = n;
      }
    }
    _buffered -= n;
    return out;
  }

  void _onError(Object e) {
    _error = e;
    _deliverIfWaiting();
  }

  void _onDone() {
    _eof = true;
    _deliverIfWaiting();
  }

  void _deliverIfWaiting() {
    final w = _waiter;
    if (w == null || w.isCompleted) return;
    if (_buffered > 0) {
      _waiter = null;
      w.complete(_take(_waiterMaxLen));
    } else if (_error != null) {
      _waiter = null;
      w.completeError(_error!);
    } else if (_eof) {
      _waiter = null;
      w.complete(const []);
    }
  }

  /// Returns up to [maxLen] bytes, `null` on timeout, or `[]` (empty list)
  /// once the peer has closed the connection and no more data is buffered.
  Future<List<int>?> read(int maxLen, Duration timeout) async {
    if (_buffered > 0) return _take(maxLen);
    if (_error != null) throw _error!;
    if (_eof) return const [];

    final completer = Completer<List<int>?>();
    _waiter = completer;
    _waiterMaxLen = maxLen;
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        _waiter = null;
        completer.complete(null);
      }
    });
    try {
      return await completer.future;
    } finally {
      timer.cancel();
    }
  }

  /// Reads exactly [n] bytes, used only during the SOCKS handshake (where
  /// reply sizes are fixed/known), distinct from [read]'s "whatever's
  /// available" semantics that the chat-frame layer wants afterwards.
  Future<List<int>> readExact(int n, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    final out = <int>[];
    while (out.length < n) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining.isNegative) {
        throw TorSocksException('timed out waiting for SOCKS reply');
      }
      final chunk = await read(n - out.length, remaining);
      if (chunk == null) {
        throw TorSocksException('timed out waiting for SOCKS reply');
      }
      if (chunk.isEmpty) {
        throw TorSocksException('socket closed during SOCKS handshake');
      }
      out.addAll(chunk);
    }
    return out;
  }

  void write(List<int> data) => _socket.add(data);
  Future<void> flush() => _socket.flush();

  Future<void> close() async {
    await _sub.cancel();
    try {
      await _socket.close();
    } catch (_) {
      // A write/flush still in flight (e.g. the stream died mid-transfer)
      // makes a graceful close throw "StreamSink is bound to a stream" --
      // just drop the socket then.
      _socket.destroy();
    }
  }
}

/// Opens a SOCKS5 CONNECT to `host:port` via the SOCKS proxy at
/// 127.0.0.1:[socksPort] and returns the resulting [TorByteConnection] once
/// the handshake succeeds, or throws [TorSocksException].
///
/// [isolation], when given, is sent as the SOCKS username. tor's SocksPort
/// isolates by SOCKS auth by default (IsolateSOCKSAuth), so streams with
/// different [isolation] values ride different circuits -- which is how a
/// big transfer spreads over several circuits in parallel instead of being
/// capped by one circuit's flow-control window.
Future<TorByteConnection> torSocksConnect({
  required int socksPort,
  required String host,
  required int port,
  String? isolation,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final socket = await Socket.connect(
    InternetAddress.loopbackIPv4,
    socksPort,
    timeout: const Duration(seconds: 5),
  );
  final conn = TorByteConnection(socket);
  try {
    if (isolation == null) {
      // Greeting: version 5, 1 auth method, "no auth".
      conn.write([0x05, 0x01, 0x00]);
      await conn.flush();
      final greetingReply = await conn.readExact(2, timeout);
      if (greetingReply[0] != 0x05 || greetingReply[1] != 0x00) {
        throw TorSocksException(
            'unexpected SOCKS greeting reply: $greetingReply');
      }
    } else {
      // Greeting: version 5, 1 auth method, "username/password" (RFC 1929).
      conn.write([0x05, 0x01, 0x02]);
      await conn.flush();
      final greetingReply = await conn.readExact(2, timeout);
      if (greetingReply[0] != 0x05 || greetingReply[1] != 0x02) {
        throw TorSocksException(
            'unexpected SOCKS greeting reply: $greetingReply');
      }
      final user = utf8.encode(isolation);
      if (user.isEmpty || user.length > 255) {
        throw TorSocksException('bad isolation token length');
      }
      conn.write([0x01, user.length, ...user, 0x01, 0x78]); // password "x"
      await conn.flush();
      final authReply = await conn.readExact(2, timeout);
      if (authReply[1] != 0x00) {
        throw TorSocksException('SOCKS auth rejected: $authReply');
      }
    }

    // CONNECT request, ATYP=0x03 (domain name).
    final hostBytes = host.codeUnits;
    final req = BytesBuilder()
      ..addByte(0x05)
      ..addByte(0x01) // CONNECT
      ..addByte(0x00) // reserved
      ..addByte(0x03) // domain name
      ..addByte(hostBytes.length)
      ..add(hostBytes)
      ..add([(port >> 8) & 0xff, port & 0xff]);
    conn.write(req.toBytes());
    await conn.flush();

    final head = await conn.readExact(4, timeout);
    if (head[0] != 0x05) {
      throw TorSocksException('unexpected SOCKS reply version: ${head[0]}');
    }
    if (head[1] != 0x00) {
      throw TorSocksException(
          'SOCKS CONNECT failed with reply code ${head[1]}');
    }
    final atyp = head[3];
    switch (atyp) {
      case 0x01: // IPv4
        await conn.readExact(4 + 2, timeout);
        break;
      case 0x03: // domain
        final len = (await conn.readExact(1, timeout))[0];
        await conn.readExact(len + 2, timeout);
        break;
      case 0x04: // IPv6
        await conn.readExact(16 + 2, timeout);
        break;
      default:
        throw TorSocksException('unexpected SOCKS address type: $atyp');
    }
    return conn;
  } catch (e) {
    await conn.close();
    rethrow;
  }
}
