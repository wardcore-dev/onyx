// lib/services/wardlink/wardlink_crypto.dart
//
// Shared cryptography for WardLink passive LAN sync.
//
// Identity model: every device owns a long-lived X25519 identity key pair
// (see WardLinkIdentity). A WardLink session key is derived by static-static
// ECDH between the two devices' identity keys + HKDF-SHA256. Because only
// *paired* devices know each other's identity public key (exchanged once via
// QR), deriving the same key both authenticates the peer (it must be in the
// trusted list) and encrypts the channel — without needing TLS.
//
// Two encodings are provided:
//   • JSON envelopes  — for small control messages (manifests, requests).
//   • Streaming frames — for large media files, so a 2–4 GB file never has to
//     be fully held in memory or base64-expanded. Each frame is independently
//     AES-256-GCM sealed and length-prefixed on the wire.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as dart_crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show compute;

class WardLinkCrypto {
  static final X25519 x25519 = X25519();
  static final AesGcm _aesGcm = AesGcm.with256bits();

  /// Plaintext bytes carried per streaming frame (256 KiB). Encryption adds a
  /// 12-byte nonce + 16-byte tag of overhead per frame, which is negligible.
  static const int frameSize = 256 * 1024;

  // ── HKDF-SHA256 (identical construction to the rest of the app) ─────────────
  static List<int> hkdf(List<int> ikm, List<int> info, int length) {
    final zeroes = List<int>.filled(32, 0);
    final prk = dart_crypto.Hmac(dart_crypto.sha256, zeroes).convert(ikm).bytes;
    final okm = <int>[];
    var previous = <int>[];
    var counter = 1;
    while (okm.length < length) {
      final t = dart_crypto.Hmac(dart_crypto.sha256, prk)
          .convert([...previous, ...info, counter]).bytes;
      okm.addAll(t);
      previous = t;
      counter++;
    }
    return okm.sublist(0, length);
  }

  /// Derive the shared AES-256 session key from our key pair and the peer's
  /// identity public key.
  static Future<SecretKey> deriveSessionKey(
    SimpleKeyPair myKeyPair,
    List<int> peerIdentityPub,
  ) async {
    final remote = SimplePublicKey(peerIdentityPub, type: KeyPairType.x25519);
    final shared =
        await x25519.sharedSecretKey(keyPair: myKeyPair, remotePublicKey: remote);
    final sharedBytes = await shared.extractBytes();
    return SecretKey(hkdf(sharedBytes, utf8.encode('onyx-wardlink-v1'), 32));
  }

  // ── JSON envelopes (small control messages) ─────────────────────────────────

  // Manifests can carry every favourite's full message-id/timestamp list, so
  // jsonEncode + AES-GCM over that payload is run in a background isolate via
  // `compute` — doing it inline on the UI isolate is what froze the app for a
  // moment every time a paired peer pulled right after a favourite message
  // was sent. Small control payloads pay a few ms of isolate-spawn overhead,
  // which is unnoticeable since WardLink control traffic is infrequent/debounced.
  static Future<String> encryptJson(
      Map<String, dynamic> payload, SecretKey key) async {
    final keyBytes = await key.extractBytes();
    return compute(_encryptJsonWorker, {'payload': payload, 'keyBytes': keyBytes});
  }

  static Future<String> _encryptJsonWorker(Map<String, dynamic> args) async {
    final payload = args['payload'] as Map<String, dynamic>;
    final keyBytes = (args['keyBytes'] as List).cast<int>();
    final key = SecretKey(keyBytes);
    final plain = utf8.encode(jsonEncode(payload));
    final box = await _aesGcm.encrypt(plain, secretKey: key);
    return jsonEncode({
      'cn': base64Encode(box.nonce),
      'cipher': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  static Future<Map<String, dynamic>?> decryptJson(
      String body, SecretKey key) async {
    try {
      final keyBytes = await key.extractBytes();
      return await compute(
          _decryptJsonWorker, {'body': body, 'keyBytes': keyBytes});
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _decryptJsonWorker(
      Map<String, dynamic> args) async {
    try {
      final body = args['body'] as String;
      final keyBytes = (args['keyBytes'] as List).cast<int>();
      final key = SecretKey(keyBytes);
      final j = jsonDecode(body) as Map<String, dynamic>;
      final box = SecretBox(
        base64Decode(j['cipher'] as String),
        nonce: base64Decode(j['cn'] as String),
        mac: Mac(base64Decode(j['mac'] as String)),
      );
      final plain = await _aesGcm.decrypt(box, secretKey: key);
      return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Streaming frames (large files) ──────────────────────────────────────────
  //
  // Wire layout, repeated until a terminating zero-length frame:
  //   [4-byte big-endian sealed-length L][L bytes sealed frame]
  // A sealed frame is: [12-byte nonce][ciphertext][16-byte GCM tag].
  // The terminating frame has L == 0.

  /// Seal one plaintext chunk into a length-prefixed wire frame.
  static Future<Uint8List> sealFrame(List<int> plain, SecretKey key) async {
    final box = await _aesGcm.encrypt(plain, secretKey: key);
    final sealed = BytesBuilder()
      ..add(box.nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    final body = sealed.toBytes();
    final out = BytesBuilder()
      ..add(_u32(body.length))
      ..add(body);
    return out.toBytes();
  }

  /// The 4-byte big-endian terminator frame (length 0).
  static Uint8List terminatorFrame() => _u32(0);

  /// Open a sealed frame body (without the 4-byte length prefix).
  static Future<Uint8List> openFrame(Uint8List sealed, SecretKey key) async {
    const nonceLen = 12, macLen = 16;
    if (sealed.length < nonceLen + macLen) {
      throw const FormatException('WardLink: frame too short');
    }
    final nonce = sealed.sublist(0, nonceLen);
    final mac = Mac(sealed.sublist(sealed.length - macLen));
    final cipher = sealed.sublist(nonceLen, sealed.length - macLen);
    final box = SecretBox(cipher, nonce: nonce, mac: mac);
    final plain = await _aesGcm.decrypt(box, secretKey: key);
    return Uint8List.fromList(plain);
  }

  static Uint8List _u32(int v) {
    final b = ByteData(4)..setUint32(0, v, Endian.big);
    return b.buffer.asUint8List();
  }

  // ── Hash helpers ────────────────────────────────────────────────────────────

  static String sha256hex(List<int> bytes) =>
      dart_crypto.sha256.convert(bytes).toString();

  /// Short colon-separated fingerprint of an identity public key, for display
  /// and for matching during pairing confirmation.
  static String fingerprint(List<int> pubKey) {
    final digest = dart_crypto.sha256.convert(pubKey).bytes;
    return digest
        .take(8)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(':');
  }

  /// A stable device id derived from the full identity public key.
  static String deviceIdFromPub(List<int> pubKey) =>
      dart_crypto.sha256.convert(pubKey).toString().substring(0, 16);
}

/// Backpressured streaming reader for the WardLink length-prefixed frame
/// protocol. Reads exact byte counts from any [Stream<List<int>>] (e.g. an
/// HTTP response or request body) and pauses the source when the buffer grows
/// past the high-water mark to avoid unbounded memory use on fast networks.
///
/// Used by both [WardLinkSyncService] (for WardLink passive sync downloads)
/// and [LanFavSyncService] (for large-file streaming over the legacy fav-sync
/// protocol).
class WardLinkFrameReader {
  static const int _highWater = 4 * 1024 * 1024; // 4 MB
  static const int _lowWater = 1 * 1024 * 1024;  // 1 MB

  late final StreamSubscription<List<int>> _sub;
  final Queue<Uint8List> _chunks = Queue<Uint8List>();
  int _buffered = 0;
  int _headOffset = 0;
  bool _done = false;
  Object? _error;
  Completer<void>? _waiter;
  bool _paused = false;

  WardLinkFrameReader(Stream<List<int>> stream) {
    _sub = stream.listen(_onData, onError: _onError, onDone: _onDone);
  }

  void _onData(List<int> chunk) {
    _chunks.add(chunk is Uint8List ? chunk : Uint8List.fromList(chunk));
    _buffered += chunk.length;
    if (_buffered >= _highWater && !_paused) {
      _paused = true;
      _sub.pause();
    }
    _wake();
  }

  void _onError(Object e) {
    _error = e;
    _wake();
  }

  void _onDone() {
    _done = true;
    _wake();
  }

  void _wake() {
    final w = _waiter;
    _waiter = null;
    w?.complete();
  }

  /// Reads exactly [n] bytes from the stream, blocking until enough data is
  /// available. Returns null when the stream ends before [n] bytes arrive.
  Future<Uint8List?> readExact(int n) async {
    while (_buffered < n) {
      if (_error != null) throw _error!;
      if (_done) return null;
      _waiter = Completer<void>();
      await _waiter!.future;
    }
    final out = Uint8List(n);
    int got = 0;
    while (got < n) {
      final head = _chunks.first;
      final avail = head.length - _headOffset;
      final take = (n - got) < avail ? (n - got) : avail;
      out.setRange(got, got + take, head, _headOffset);
      got += take;
      _headOffset += take;
      _buffered -= take;
      if (_headOffset >= head.length) {
        _chunks.removeFirst();
        _headOffset = 0;
      }
    }
    if (_paused && _buffered <= _lowWater) {
      _paused = false;
      _sub.resume();
    }
    return out;
  }

  Future<void> cancel() => _sub.cancel();
}
