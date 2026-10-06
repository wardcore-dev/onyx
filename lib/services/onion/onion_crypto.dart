// lib/services/onion/onion_crypto.dart
//
// Onion-mode session crypto. Deliberately thin: the actual cryptography
// (X25519 ECDH, HKDF-SHA256, AES-256-GCM, the length-prefixed streaming
// frame codec) already lives in WardLinkCrypto and is fully
// transport-agnostic. This class only re-derives the session key with a
// different HKDF info string so onion-mode sessions are cryptographically
// domain-separated from WardLink LAN-sync sessions, even though both reuse
// the same underlying X25519 identity (see OnionIdentity).

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show compute;

import '../wardlink/wardlink_crypto.dart';

class OnionCrypto {
  OnionCrypto._();

  static Future<SecretKey> deriveSessionKey(
    SimpleKeyPair myKeyPair,
    List<int> peerIdentityPub,
  ) async {
    final remote =
        SimplePublicKey(peerIdentityPub, type: KeyPairType.x25519);
    final shared = await WardLinkCrypto.x25519
        .sharedSecretKey(keyPair: myKeyPair, remotePublicKey: remote);
    final sharedBytes = await shared.extractBytes();
    return SecretKey(
        WardLinkCrypto.hkdf(sharedBytes, utf8.encode('onyx-onion-v1'), 32));
  }

  static Future<Uint8List> sealFrame(List<int> plain, SecretKey key) =>
      WardLinkCrypto.sealFrame(plain, key);

  static Future<Uint8List> openFrame(Uint8List sealed, SecretKey key) =>
      WardLinkCrypto.openFrame(sealed, key);

  /// Above this size AES-GCM runs in a background isolate: on desktop it's
  /// pure Dart, and doing half a megabyte of it per file chunk on the UI
  /// isolate stalls the whole app (and every other message) during a big
  /// transfer. Small frames stay inline -- an isolate hop costs more than
  /// they do.
  static const int _backgroundThreshold = 64 * 1024;

  /// [sealFrame] with the work moved off the UI isolate for big payloads.
  static Future<Uint8List> sealFrameFast(
      Uint8List plain, SecretKey key, List<int> keyBytes) {
    if (plain.length < _backgroundThreshold) return sealFrame(plain, key);
    return compute(_sealWorker, [plain, Uint8List.fromList(keyBytes)]);
  }

  /// [openFrame] with the work moved off the UI isolate for big payloads.
  static Future<Uint8List> openFrameFast(
      Uint8List sealed, SecretKey key, List<int> keyBytes) {
    if (sealed.length < _backgroundThreshold) return openFrame(sealed, key);
    return compute(_openWorker, [sealed, Uint8List.fromList(keyBytes)]);
  }

  static Future<Uint8List> _sealWorker(List<Uint8List> args) =>
      WardLinkCrypto.sealFrame(args[0], SecretKey(args[1]));

  static Future<Uint8List> _openWorker(List<Uint8List> args) =>
      WardLinkCrypto.openFrame(args[0], SecretKey(args[1]));
}
