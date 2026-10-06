// lib/call/local_turn_server.dart
//
// A tiny TURN server (RFC 5766, UDP only) that runs inside the app for
// Tor calls. WebRTC is pointed at it like at any TURN relay, but nothing it
// relays ever touches the real network: every relayed address is a made-up
// "virtual" address in 198.18.0.0/15 (a range reserved for benchmarking,
// never routed on the internet), and packets addressed to such an address
// are handed to [onRelayOut] -- the call layer ships them to the other
// party over the Tor channel, where their own LocalTurnServer delivers them
// to their WebRTC via [deliverFromTunnel]. From WebRTC's point of view the
// two sides simply talk through a TURN relay; in reality the "relay" is
// Tor. Neither side learns the other's IP, and no server exists anywhere.
//
// Only what libwebrtc's TURN client actually uses is implemented:
// Allocate (with the 401 long-term-credential handshake), Refresh,
// CreatePermission, ChannelBind, Send/Data indications and ChannelData.
// Permissions aren't enforced (the only possible peer is the other side of
// the current call, over an already authenticated channel).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// A transport address as a plain value (virtual addresses never become
/// real sockets, so InternetAddress is overkill here).
class TurnAddr {
  final String ip; // dotted IPv4
  final int port;
  const TurnAddr(this.ip, this.port);

  @override
  String toString() => '$ip:$port';

  static TurnAddr? parse(String s) {
    final i = s.lastIndexOf(':');
    if (i <= 0) return null;
    final port = int.tryParse(s.substring(i + 1));
    if (port == null) return null;
    return TurnAddr(s.substring(0, i), port);
  }

  /// True for 198.18.0.0/15 -- the only addresses this server relays to.
  bool get isVirtual {
    final p = ip.split('.');
    if (p.length != 4) return false;
    final a = int.tryParse(p[0]), b = int.tryParse(p[1]);
    return a == 198 && (b == 18 || b == 19);
  }

  @override
  bool operator ==(Object other) =>
      other is TurnAddr && other.ip == ip && other.port == port;

  @override
  int get hashCode => Object.hash(ip, port);
}

class _Allocation {
  final InternetAddress clientIp;
  final int clientPort;
  final TurnAddr relayed;
  final Map<int, TurnAddr> channels = {};
  final Map<TurnAddr, int> channelOf = {};
  DateTime expires;
  _Allocation(this.clientIp, this.clientPort, this.relayed, this.expires);
}

class LocalTurnServer {
  LocalTurnServer({required this.onRelayOut});

  /// Called for every packet WebRTC sends to a virtual peer address.
  final void Function(TurnAddr from, TurnAddr to, Uint8List data) onRelayOut;

  static const int _magic = 0x2112A442;
  static const String realm = 'onyx';

  // Methods (with class bits for request / indication / success / error).
  static const int _binding = 0x0001;
  static const int _allocate = 0x0003;
  static const int _refresh = 0x0004;
  static const int _send = 0x0006;
  static const int _data = 0x0007;
  static const int _createPermission = 0x0008;
  static const int _channelBind = 0x0009;

  // Attributes.
  static const int _aUsername = 0x0006;
  static const int _aMessageIntegrity = 0x0008;
  static const int _aErrorCode = 0x0009;
  static const int _aChannelNumber = 0x000C;
  static const int _aLifetime = 0x000D;
  static const int _aXorPeerAddress = 0x0012;
  static const int _aData = 0x0013;
  static const int _aRealm = 0x0014;
  static const int _aNonce = 0x0015;
  static const int _aXorRelayedAddress = 0x0016;
  static const int _aXorMappedAddress = 0x0020;

  final Random _rand = Random.secure();
  RawDatagramSocket? _socket;
  late final String username;
  late final String password;
  late final String _nonce;
  late final List<int> _key; // MD5(username:realm:password)
  final Map<String, _Allocation> _byClient = {};
  final Map<TurnAddr, _Allocation> _byRelayed = {};
  Timer? _gc;

  /// The address WebRTC should use as its TURN server (ip:port).
  String? url;

  String _randomToken(int bytes) => base64Url
      .encode(List<int>.generate(bytes, (_) => _rand.nextInt(256)))
      .replaceAll('=', '');

  Future<void> start() async {
    username = _randomToken(12);
    password = _randomToken(18);
    _nonce = _randomToken(12);
    _key = md5.convert(utf8.encode('$username:$realm:$password')).bytes;
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      Datagram? d;
      while ((d = _socket?.receive()) != null) {
        try {
          _onDatagram(d!);
        } catch (_) {
          // A malformed packet must never take the server down.
        }
      }
    });
    // Advertise a real interface address rather than 127.0.0.1: WebRTC
    // gathers from its non-loopback network sockets, and sending from one
    // of those to our own interface address is always deliverable.
    final host = await _pickHostAddress();
    url = 'turn:$host:${_socket!.port}?transport=udp';
    _gc = Timer.periodic(const Duration(seconds: 30), (_) => _expire());
  }

  Future<String> _pickHostAddress() async {
    try {
      final ifaces = await NetworkInterface.list(
          includeLoopback: false, type: InternetAddressType.IPv4);
      for (final i in ifaces) {
        for (final a in i.addresses) {
          if (!a.isLoopback && !a.isLinkLocal) return a.address;
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  void stop() {
    _gc?.cancel();
    _gc = null;
    _socket?.close();
    _socket = null;
    _byClient.clear();
    _byRelayed.clear();
  }

  /// A packet that arrived over Tor from the other side's relayed address
  /// [from], addressed to our relayed address [to].
  void deliverFromTunnel(TurnAddr from, TurnAddr to, Uint8List data) {
    final alloc = _byRelayed[to];
    final sock = _socket;
    if (alloc == null || sock == null) return;
    final ch = alloc.channelOf[from];
    Uint8List out;
    if (ch != null) {
      out = Uint8List(4 + data.length);
      final bd = ByteData.sublistView(out);
      bd.setUint16(0, ch);
      bd.setUint16(2, data.length);
      out.setRange(4, 4 + data.length, data);
    } else {
      out = _build(_data | 0x0010, _newTid(), [
        _attr(_aXorPeerAddress, _xorAddr(from, null)),
        _attr(_aData, data),
      ]);
    }
    sock.send(out, alloc.clientIp, alloc.clientPort);
  }

  void _expire() {
    final now = DateTime.now();
    for (final e in _byClient.entries.toList()) {
      if (e.value.expires.isBefore(now)) {
        _byClient.remove(e.key);
        _byRelayed.remove(e.value.relayed);
      }
    }
  }

  // ───────────────────────────── receive ───────────────────────────────────

  void _onDatagram(Datagram d) {
    final b = d.data;
    if (b.length < 4) return;
    final clientKey = '${d.address.address}:${d.port}';
    final first = b[0];
    if (first >= 0x40 && first <= 0x7F) {
      // ChannelData.
      final bd = ByteData.sublistView(b);
      final ch = bd.getUint16(0);
      final len = bd.getUint16(2);
      if (b.length < 4 + len) return;
      final alloc = _byClient[clientKey];
      final peer = alloc?.channels[ch];
      if (alloc == null || peer == null) return;
      _relayOut(alloc, peer, Uint8List.sublistView(b, 4, 4 + len));
      return;
    }
    if (b.length < 20) return;
    final bd = ByteData.sublistView(b);
    final type = bd.getUint16(0);
    final len = bd.getUint16(2);
    if (bd.getUint32(4) != _magic || b.length < 20 + len) return;
    final tid = Uint8List.sublistView(b, 8, 20);
    final attrs = <int, Uint8List>{};
    int? miOffset;
    var off = 20;
    while (off + 4 <= 20 + len) {
      final t = bd.getUint16(off);
      final l = bd.getUint16(off + 2);
      if (off + 4 + l > b.length) return;
      attrs.putIfAbsent(t, () => Uint8List.sublistView(b, off + 4, off + 4 + l));
      if (t == _aMessageIntegrity) miOffset = off;
      off += 4 + ((l + 3) & ~3);
    }

    final method = type & 0x3EEF;
    final cls = type & 0x0110;

    if (cls == 0x0010) {
      // Indication.
      if (method == _send) {
        final alloc = _byClient[clientKey];
        final peerRaw = attrs[_aXorPeerAddress];
        final data = attrs[_aData];
        if (alloc == null || peerRaw == null || data == null) return;
        final peer = _parseXorAddr(peerRaw, tid);
        if (peer != null) _relayOut(alloc, peer, data);
      }
      return;
    }
    if (cls != 0x0000) return; // we never receive responses

    if (method == _binding) {
      _reply(d, _build(_binding | 0x0100, tid, [
        _attr(_aXorMappedAddress, _xorAddr(_fakeMapped, tid)),
      ]));
      return;
    }

    // Everything else needs long-term credentials.
    final user = attrs[_aUsername];
    if (miOffset == null || user == null) {
      _reply(d, _build(method | 0x0110, tid, [
        _attr(_aErrorCode, _errorCode(401, 'Unauthorized')),
        _attr(_aRealm, utf8.encode(realm)),
        _attr(_aNonce, utf8.encode(_nonce)),
      ]));
      return;
    }
    if (utf8.decode(user, allowMalformed: true) != username ||
        !_checkIntegrity(b, miOffset)) {
      _reply(d, _build(method | 0x0110, tid, [
        _attr(_aErrorCode, _errorCode(401, 'Unauthorized')),
        _attr(_aRealm, utf8.encode(realm)),
        _attr(_aNonce, utf8.encode(_nonce)),
      ]));
      return;
    }

    switch (method) {
      case _allocate:
        var alloc = _byClient[clientKey];
        if (alloc == null) {
          final relayed = _newVirtualAddr();
          alloc = _Allocation(d.address, d.port, relayed,
              DateTime.now().add(const Duration(seconds: 600)));
          _byClient[clientKey] = alloc;
          _byRelayed[relayed] = alloc;
        }
        _replySigned(d, _allocate | 0x0100, tid, [
          _attr(_aXorRelayedAddress, _xorAddr(alloc.relayed, tid)),
          // A fake mapped address: libwebrtc puts it into the relay
          // candidate's "raddr", which is sent to the other side -- the
          // real LAN address must not end up there.
          _attr(_aXorMappedAddress, _xorAddr(_fakeMapped, tid)),
          _attr(_aLifetime, _u32(600)),
        ]);
        return;
      case _refresh:
        final alloc = _byClient[clientKey];
        final lt = attrs[_aLifetime];
        final lifetime =
            lt != null && lt.length >= 4 ? ByteData.sublistView(lt).getUint32(0) : 600;
        if (alloc != null) {
          if (lifetime == 0) {
            _byClient.remove(clientKey);
            _byRelayed.remove(alloc.relayed);
          } else {
            alloc.expires =
                DateTime.now().add(Duration(seconds: min(lifetime, 3600)));
          }
        }
        _replySigned(d, _refresh | 0x0100, tid,
            [_attr(_aLifetime, _u32(lifetime == 0 ? 0 : min(lifetime, 3600)))]);
        return;
      case _createPermission:
        _replySigned(d, _createPermission | 0x0100, tid, const []);
        return;
      case _channelBind:
        final alloc = _byClient[clientKey];
        final chRaw = attrs[_aChannelNumber];
        final peerRaw = attrs[_aXorPeerAddress];
        if (alloc == null || chRaw == null || peerRaw == null || chRaw.length < 2) {
          _replySigned(d, _channelBind | 0x0110, tid,
              [_attr(_aErrorCode, _errorCode(400, 'Bad Request'))]);
          return;
        }
        final ch = ByteData.sublistView(chRaw).getUint16(0);
        final peer = _parseXorAddr(peerRaw, tid);
        if (peer == null || ch < 0x4000 || ch > 0x7FFE) {
          _replySigned(d, _channelBind | 0x0110, tid,
              [_attr(_aErrorCode, _errorCode(400, 'Bad Request'))]);
          return;
        }
        alloc.channels[ch] = peer;
        alloc.channelOf[peer] = ch;
        _replySigned(d, _channelBind | 0x0100, tid, const []);
        return;
    }
  }

  void _relayOut(_Allocation alloc, TurnAddr peer, Uint8List data) {
    // Never onto the real network: only the other party's virtual
    // relayed addresses are reachable, and only through Tor.
    if (!peer.isVirtual) return;
    onRelayOut(alloc.relayed, peer, Uint8List.fromList(data));
  }

  // ───────────────────────────── helpers ───────────────────────────────────

  static const TurnAddr _fakeMapped = TurnAddr('198.18.0.1', 9);

  TurnAddr _newVirtualAddr() {
    while (true) {
      final a = TurnAddr(
          '198.${18 + _rand.nextInt(2)}.${_rand.nextInt(256)}.'
          '${1 + _rand.nextInt(254)}',
          10000 + _rand.nextInt(50000));
      if (!_byRelayed.containsKey(a) && a != _fakeMapped) return a;
    }
  }

  Uint8List _newTid() =>
      Uint8List.fromList(List<int>.generate(12, (_) => _rand.nextInt(256)));

  void _reply(Datagram d, Uint8List msg) =>
      _socket?.send(msg, d.address, d.port);

  void _replySigned(
      Datagram d, int type, Uint8List tid, List<Uint8List> attrs) {
    _reply(d, _signed(type, tid, attrs));
  }

  /// Builds a message with a MESSAGE-INTEGRITY attribute appended.
  Uint8List _signed(int type, Uint8List tid, List<Uint8List> attrs) {
    final body = _build(type, tid, attrs);
    // Length must already count the 24-byte MI attribute when hashing.
    final withLen = Uint8List.fromList(body);
    ByteData.sublistView(withLen).setUint16(2, body.length - 20 + 24);
    final mac = Hmac(sha1, _key).convert(withLen).bytes;
    final out = BytesBuilder()
      ..add(withLen)
      ..add(_attr(_aMessageIntegrity, mac));
    return out.toBytes();
  }

  bool _checkIntegrity(Uint8List msg, int miOffset) {
    if (miOffset + 24 > msg.length) return false;
    final copy = Uint8List.fromList(msg.sublist(0, miOffset));
    // Length as if the message ended right after MESSAGE-INTEGRITY.
    ByteData.sublistView(copy).setUint16(2, miOffset + 24 - 20);
    final mac = Hmac(sha1, _key).convert(copy).bytes;
    final got = msg.sublist(miOffset + 4, miOffset + 24);
    var diff = 0;
    for (var i = 0; i < 20; i++) {
      diff |= mac[i] ^ got[i];
    }
    return diff == 0;
  }

  static Uint8List _build(int type, Uint8List tid, List<Uint8List> attrs) {
    final attrLen = attrs.fold<int>(0, (s, a) => s + a.length);
    final out = Uint8List(20 + attrLen);
    final bd = ByteData.sublistView(out);
    bd.setUint16(0, type);
    bd.setUint16(2, attrLen);
    bd.setUint32(4, _magic);
    out.setRange(8, 20, tid);
    var off = 20;
    for (final a in attrs) {
      out.setRange(off, off + a.length, a);
      off += a.length;
    }
    return out;
  }

  /// One TLV attribute, zero-padded to a 4-byte boundary.
  static Uint8List _attr(int type, List<int> value) {
    final padded = (value.length + 3) & ~3;
    final out = Uint8List(4 + padded);
    final bd = ByteData.sublistView(out);
    bd.setUint16(0, type);
    bd.setUint16(2, value.length);
    out.setRange(4, 4 + value.length, value);
    return out;
  }

  static Uint8List _u32(int v) {
    final out = Uint8List(4);
    ByteData.sublistView(out).setUint32(0, v);
    return out;
  }

  static Uint8List _errorCode(int code, String reason) {
    final r = utf8.encode(reason);
    final out = Uint8List(4 + r.length);
    out[2] = code ~/ 100;
    out[3] = code % 100;
    out.setRange(4, 4 + r.length, r);
    return out;
  }

  static Uint8List _xorAddr(TurnAddr a, Uint8List? tid) {
    final out = Uint8List(8);
    final bd = ByteData.sublistView(out);
    out[1] = 0x01; // IPv4
    bd.setUint16(2, a.port ^ (_magic >> 16));
    final p = a.ip.split('.').map(int.parse).toList();
    final ip = (p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3];
    bd.setUint32(4, ip ^ _magic);
    return out;
  }

  static TurnAddr? _parseXorAddr(Uint8List v, Uint8List tid) {
    if (v.length < 8 || v[1] != 0x01) return null; // IPv4 only
    final bd = ByteData.sublistView(v);
    final port = bd.getUint16(2) ^ (_magic >> 16);
    final ip = bd.getUint32(4) ^ _magic;
    return TurnAddr(
        '${(ip >> 24) & 0xFF}.${(ip >> 16) & 0xFF}.${(ip >> 8) & 0xFF}.'
        '${ip & 0xFF}',
        port);
  }
}
