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
    return completer.future;
  }

  // ── Worker isolate ──────────────────────────────────────────────────────────

  static void _workerEntry(SendPort mainPort) {
    final jobPort = ReceivePort();
    mainPort.send(jobPort.sendPort);
    jobPort.listen((msg) async {
      if (msg is _DecryptJob) {
        final result = await _decryptInIsolate(msg);
        mainPort.send([msg.id, result]);
      }
    });
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
