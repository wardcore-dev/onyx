// lib/utils/decrypt_worker.dart
//
// A small POOL of long-lived isolates for XChaCha20-Poly1305 media decryption.
//
// Why this exists: media used to be decrypted via `compute(...)`, which spawns
// (and tears down) a brand-new isolate on EVERY image. Opening a chat or an
// album fires many decrypts at once, so the per-call isolate spawn cost (tens of
// ms each, plus copying the bytes in and out) dominated and made images crawl in.
//
// Here we spawn a fixed pool once and reuse it for every decrypt: jobs are sent
// round-robin to a worker over its SendPort and the plaintext comes back over a
// shared ReceivePort. The pool keeps multiple cores busy (the crypto is pure
// Dart, so it's CPU-bound) without paying the spawn cost per image.
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as dart_crypto;
import 'package:flutter/foundation.dart' show debugPrint;

/// A single decrypt request handed to a worker isolate.
class _DecryptJob {
  final int id;
  final Uint8List cipherData;
  final Uint8List aeadKey;
  final int prefixLen;
  const _DecryptJob({
    required this.id,
    required this.cipherData,
    required this.aeadKey,
    required this.prefixLen,
  });
}

/// A full E2EE chat-message decrypt request: X25519 ECDH + HKDF-SHA256 key
/// derivation + XChaCha20-Poly1305, all done off the UI thread. Text-message
/// decryption was previously inlined on the main isolate per message, which
/// is fine for one message but stalls the UI for several ms per message when
/// a burst arrives (e.g. many messages synced or sent in quick succession).
class _MsgDecryptJob {
  final int id;
  final Uint8List ownPrivateKey;
  final Uint8List ownPublicKey;
  final Uint8List remotePublicKey;
  final Uint8List info;
  final Uint8List nonce;
  final Uint8List cipherText;
  final Uint8List tag;
  const _MsgDecryptJob({
    required this.id,
    required this.ownPrivateKey,
    required this.ownPublicKey,
    required this.remotePublicKey,
    required this.info,
    required this.nonce,
    required this.cipherText,
    required this.tag,
  });
}

class DecryptWorker {
  DecryptWorker._();
  static final DecryptWorker instance = DecryptWorker._();

  // Number of worker isolates. Small enough not to oversubscribe the device,
  // large enough to overlap several simultaneous image decrypts.
  static const int _poolSize = 3;

  final List<SendPort> _workers = [];
  ReceivePort? _mainReceive;
  Completer<void>? _readyCompleter;
  Future<void>? _starting;

  int _rr = 0; // round-robin cursor
  int _nextId = 0;
  final Map<int, Completer<Uint8List?>> _pending = {};

  Future<void> _ensureStarted() {
    if (_workers.length == _poolSize) return Future.value();
    return _starting ??= _start();
  }

  Future<void> _start() async {
    _mainReceive = ReceivePort();
    _readyCompleter = Completer<void>();
    _mainReceive!.listen(_onMessage);
    for (int i = 0; i < _poolSize; i++) {
      await Isolate.spawn(_workerEntry, _mainReceive!.sendPort);
    }
    await _readyCompleter!.future;
  }

  void _onMessage(dynamic msg) {
    if (msg is SendPort) {
      // Handshake: a worker reporting its job port.
      _workers.add(msg);
      if (_workers.length == _poolSize &&
          !(_readyCompleter?.isCompleted ?? true)) {
        _readyCompleter!.complete();
      }
    } else if (msg is List && msg.length == 2) {
      // Result: [jobId, plaintextOrNull].
      final id = msg[0] as int;
      final result = msg[1] as Uint8List?;
      _pending.remove(id)?.complete(result);
    }
  }

  /// Decrypts one XChaCha20-Poly1305 blob on a pooled isolate. Returns the
  /// plaintext, or null on failure. Never throws — falls back to an in-process
  /// decrypt if the pool can't be started for any reason.
  Future<Uint8List?> decrypt({
    required Uint8List cipherData,
    required Uint8List aeadKey,
    required int prefixLen,
  }) async {
    try {
      await _ensureStarted();
    } catch (_) {
      // Pool unavailable — decrypt inline so the caller still gets a result.
      return _decryptInIsolate(_DecryptJob(
        id: -1,
        cipherData: cipherData,
        aeadKey: aeadKey,
        prefixLen: prefixLen,
      ));
    }

    final id = _nextId++;
    final completer = Completer<Uint8List?>();
    _pending[id] = completer;
    final worker = _workers[_rr % _workers.length];
    _rr++;
    worker.send(_DecryptJob(
      id: id,
      cipherData: cipherData,
      aeadKey: aeadKey,
      prefixLen: prefixLen,
    ));
    return completer.future.timeout(_jobTimeout, onTimeout: () {
      // If this job's worker never replies, its round-robin slot would
      // otherwise be lost forever -- every later call routed to the same
      // index hangs identically, silently taking down 1-in-[_poolSize] of
      // *all* media/message decrypts app-wide. Dropping the completer here
      // (and letting the caller's existing "null = failed" handling take
      // over) turns that into a bounded, recoverable failure instead.
      _pending.remove(id);
      debugPrint(
          '[DecryptWorker] job $id (media) timed out after $_jobTimeout -- worker ${id % _poolSize} may be stuck/dead');
      return null;
    });
  }

  /// Generous relative to how long a single XChaCha20-Poly1305/X25519 job
  /// should ever realistically take (well under a second even for large
  /// media on a slow device) -- this only exists to bound the damage from a
  /// stuck or dead worker isolate, not to cut off legitimately slow work.
  static const Duration _jobTimeout = Duration(seconds: 20);

  /// Decrypts one E2EE chat message (X25519 ECDH + HKDF-SHA256 +
  /// XChaCha20-Poly1305) on a pooled isolate. Returns the plaintext bytes, or
  /// null on failure. Never throws — falls back to an in-process decrypt if
  /// the pool can't be started for any reason.
  Future<Uint8List?> decryptMessage({
    required Uint8List ownPrivateKey,
    required Uint8List ownPublicKey,
    required Uint8List remotePublicKey,
    required Uint8List info,
    required Uint8List nonce,
    required Uint8List cipherText,
    required Uint8List tag,
  }) async {
    try {
      await _ensureStarted();
    } catch (_) {
      return _decryptMessageInIsolate(_MsgDecryptJob(
        id: -1,
        ownPrivateKey: ownPrivateKey,
        ownPublicKey: ownPublicKey,
        remotePublicKey: remotePublicKey,
        info: info,
        nonce: nonce,
        cipherText: cipherText,
        tag: tag,
      ));
    }

    final id = _nextId++;
    final completer = Completer<Uint8List?>();
    _pending[id] = completer;
    final worker = _workers[_rr % _workers.length];
    _rr++;
    worker.send(_MsgDecryptJob(
      id: id,
      ownPrivateKey: ownPrivateKey,
      ownPublicKey: ownPublicKey,
      remotePublicKey: remotePublicKey,
      info: info,
      nonce: nonce,
      cipherText: cipherText,
      tag: tag,
    ));
    return completer.future.timeout(_jobTimeout, onTimeout: () {
      _pending.remove(id);
      debugPrint(
          '[DecryptWorker] job $id (message) timed out after $_jobTimeout -- worker ${id % _poolSize} may be stuck/dead');
      return null;
    });
  }

  // ── Worker isolate ──────────────────────────────────────────────────────────

  static void _workerEntry(SendPort mainPort) {
    final jobPort = ReceivePort();
    mainPort.send(jobPort.sendPort);
    jobPort.listen((msg) async {
      if (msg is _DecryptJob) {
        final result = await _decryptInIsolate(msg);
        mainPort.send([msg.id, result]);
      } else if (msg is _MsgDecryptJob) {
        final result = await _decryptMessageInIsolate(msg);
        mainPort.send([msg.id, result]);
      }
    });
  }

  static Future<Uint8List?> _decryptMessageInIsolate(
      _MsgDecryptJob job) async {
    try {
      final x25519 = X25519();
      final keyPair = SimpleKeyPairData(
        job.ownPrivateKey,
        publicKey: SimplePublicKey(job.ownPublicKey, type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );
      final remotePublicKey =
          SimplePublicKey(job.remotePublicKey, type: KeyPairType.x25519);
      final sharedSecret = await x25519.sharedSecretKey(
        keyPair: keyPair,
        remotePublicKey: remotePublicKey,
      );
      final sharedBytes = Uint8List.fromList(await sharedSecret.extractBytes());
      final aeadKey = _hkdfSha256(sharedBytes, job.info, 32);

      final xchacha = Xchacha20.poly1305Aead();
      final secretKey = SecretKey(aeadKey);
      final box = SecretBox(
        job.cipherText,
        nonce: job.nonce,
        mac: Mac(job.tag),
      );
      final plain =
          await xchacha.decrypt(box, secretKey: secretKey, aad: const <int>[]);
      return Uint8List.fromList(plain);
    } catch (_) {
      return null;
    }
  }

  static Uint8List _hkdfSha256(List<int> ikm, List<int> info, int length) {
    final salt = List<int>.filled(32, 0);
    final mac1 = dart_crypto.Hmac(dart_crypto.sha256, salt);
    final prk = mac1.convert(ikm).bytes;
    List<int> okm = [];
    List<int> previous = [];
    int counter = 1;
    while (okm.length < length) {
      final data = <int>[...previous, ...info, counter];
      final mac = dart_crypto.Hmac(dart_crypto.sha256, prk);
      final t = mac.convert(data).bytes;
      okm.addAll(t);
      previous = t;
      counter++;
    }
    return Uint8List.fromList(okm.sublist(0, length));
  }

  static Future<Uint8List?> _decryptInIsolate(_DecryptJob job) async {
    try {
      final data = job.cipherData;
      final offset = job.prefixLen;

      final nonce = data.sublist(offset, offset + 24);
      final ctAndTag = data.sublist(offset + 24);
      if (ctAndTag.length < 16) return null;

      final cipherText = ctAndTag.sublist(0, ctAndTag.length - 16);
      final tag = ctAndTag.sublist(ctAndTag.length - 16);

      final xchacha = Xchacha20.poly1305Aead();
      final secretKey = SecretKey(job.aeadKey);
      final box = SecretBox(
        Uint8List.fromList(cipherText),
        nonce: Uint8List.fromList(nonce),
        mac: Mac(Uint8List.fromList(tag)),
      );
      final plain =
          await xchacha.decrypt(box, secretKey: secretKey, aad: const <int>[]);
      return Uint8List.fromList(plain);
    } catch (_) {
      return null;
    }
  }
}
