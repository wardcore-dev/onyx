// lib/services/wardlink/wardlink_identity.dart
//
// The device's long-lived WardLink identity key pair (X25519). Unlike the
// ephemeral keys used by LANMessageManager (which rotate every launch), this
// key is generated once and persisted in the OS keychain / encrypted fallback
// store, so a device stays recognisably "the same trusted device" across
// restarts. Its public key is what gets pinned when two devices pair.

import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

import '../../managers/secure_store.dart';
import 'wardlink_crypto.dart';

class WardLinkIdentity {
  static const _privKey = 'wardlink_identity_priv_v1';

  static SimpleKeyPair? _keyPair;
  static List<int>? _pubBytes;

  /// Load the persisted identity, generating and storing one on first use.
  static Future<void> ensureLoaded() async {
    if (_keyPair != null) return;

    final stored = await SecureStore.read(_privKey);
    if (stored != null) {
      try {
        final seed = base64Decode(stored);
        _keyPair = await WardLinkCrypto.x25519.newKeyPairFromSeed(seed);
        _pubBytes = (await _keyPair!.extractPublicKey()).bytes;
        return;
      } catch (e) {
        if (kDebugMode) print('[WardLink] identity load failed, regenerating: $e');
      }
    }

    final kp = await WardLinkCrypto.x25519.newKeyPair();
    final seed = (await kp.extract()).bytes; // X25519 private scalar (32 bytes)
    await SecureStore.write(_privKey, base64Encode(seed));
    _keyPair = kp;
    _pubBytes = (await kp.extractPublicKey()).bytes;
    if (kDebugMode) print('[WardLink] generated new device identity');
  }

  static SimpleKeyPair get keyPair {
    final kp = _keyPair;
    if (kp == null) {
      throw StateError('WardLinkIdentity.ensureLoaded() not called yet');
    }
    return kp;
  }

  static List<int> get publicKeyBytes {
    final pk = _pubBytes;
    if (pk == null) {
      throw StateError('WardLinkIdentity.ensureLoaded() not called yet');
    }
    return pk;
  }

  static String get publicKeyB64 => base64Encode(publicKeyBytes);

  static String get deviceId => WardLinkCrypto.deviceIdFromPub(publicKeyBytes);

  static String get fingerprint => WardLinkCrypto.fingerprint(publicKeyBytes);
}
