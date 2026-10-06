// lib/services/onion/onion_account_key.dart
//
// This device's X25519 key for onion-mode chat encryption (per username).
// Despite the name it is per DEVICE: older builds shared it between linked
// devices together with the onion address, which made the two devices
// indistinguishable to contacts (see onion_account.dart). Linking now hands
// over only the account signing key; each device keeps its own key here.

import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../managers/secure_store.dart';
import '../wardlink/wardlink_crypto.dart';

class OnionAccountKey {
  OnionAccountKey._();

  static SimpleKeyPair? _kp;
  static List<int>? _pub;
  static String? _user;

  static String _slot(String username) => 'onion_account_priv_v1_$username';

  static Future<void> load(String username) async {
    if (_kp != null && _user == username) return;
    _kp = null;
    _pub = null;
    _user = null;

    final stored = await SecureStore.read(_slot(username));
    if (stored != null) {
      try {
        final kp = await WardLinkCrypto.x25519
            .newKeyPairFromSeed(base64Decode(stored));
        _kp = kp;
        _pub = (await kp.extractPublicKey()).bytes;
        _user = username;
        return;
      } catch (_) {
        // fall through and regenerate
      }
    }
    final kp = await WardLinkCrypto.x25519.newKeyPair();
    await SecureStore.write(
        _slot(username), base64Encode((await kp.extract()).bytes));
    _kp = kp;
    _pub = (await kp.extractPublicKey()).bytes;
    _user = username;
  }

  static SimpleKeyPair get keyPair {
    final kp = _kp;
    if (kp == null) {
      throw StateError('OnionAccountKey.load() not called yet');
    }
    return kp;
  }

  static String get publicKeyB64 {
    final pk = _pub;
    if (pk == null) {
      throw StateError('OnionAccountKey.load() not called yet');
    }
    return base64Encode(pk);
  }

  /// This device's public key for [username] as stored, without loading it
  /// (null if it has none yet).
  static Future<String?> peekPublicKeyB64(String username) async {
    final stored = await SecureStore.read(_slot(username));
    if (stored == null) return null;
    try {
      final kp =
          await WardLinkCrypto.x25519.newKeyPairFromSeed(base64Decode(stored));
      return base64Encode((await kp.extractPublicKey()).bytes);
    } catch (_) {
      return null;
    }
  }

  static String? get publicKeyB64OrNull {
    final pk = _pub;
    return pk == null ? null : base64Encode(pk);
  }

  /// Private seed (base64). Only used to derive the account signing key of
  /// an account that predates it (see OnionAccount.load) -- never sent.
  static Future<String> exportSeedB64(String username) async {
    await load(username);
    return base64Encode((await keyPair.extract()).bytes);
  }

  /// Forgets this device's key for [username] -- a device being linked to an
  /// account must come up with a key of its own, not one it may have copied
  /// from another device under an older build.
  static Future<void> discard(String username) async {
    await SecureStore.delete(_slot(username));
    if (_user == username) {
      _kp = null;
      _pub = null;
      _user = null;
    }
  }
}
