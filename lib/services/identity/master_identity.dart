// lib/services/identity/master_identity.dart
//
// The user's portable master identity: a single Ed25519 key pair derived
// deterministically from a BIP-39 mnemonic (seed phrase). Unlike every other
// key in this app (the Tor onion hidden-service key, WardLinkIdentity, the
// legacy AccountManager E2E key) this one is meant to be portable — entering
// the same words on a different device regenerates the exact same key. That
// is what lets a second device be recognised as "the same account" (see
// WardLink account-pairing) and lets contacts keep recognising the same
// person across a device change, without any server ever being involved.
//
// The mnemonic itself is shown to the user exactly once, at creation (or
// on explicit request), and is never persisted in plaintext; only the
// derived 32-byte seed is written to the OS keychain, the same way
// WardLinkIdentity stores its own seed.

import 'dart:convert';

import 'package:bip39/bip39.dart' as bip39;
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as dart_crypto;
import 'package:flutter/foundation.dart' show kDebugMode;

import '../../managers/secure_store.dart';

class MasterIdentity {
  static const _seedKey = 'master_identity_seed_v1';
  static final Ed25519 _ed25519 = Ed25519();

  static SimpleKeyPair? _keyPair;
  static List<int>? _pubBytes;

  /// True once a key pair has been loaded into memory this session.
  static bool get isLoaded => _keyPair != null;

  /// Loads the persisted master key, if one exists. Does NOT create one —
  /// creation only ever happens explicitly via [createNew] or
  /// [restoreFromMnemonic], so onboarding stays a deliberate user choice
  /// rather than a silent side effect of some unrelated code path.
  static Future<bool> tryLoad() async {
    if (_keyPair != null) return true;
    final stored = await SecureStore.read(_seedKey);
    if (stored == null) return false;
    await _loadFromSeed(base64Decode(stored));
    return true;
  }

  /// Generates a brand-new mnemonic + master key pair, persists the derived
  /// seed, and returns the mnemonic for one-time display/backup. The caller
  /// is responsible for showing it to the user and confirming they saved it
  /// — this class never re-derives or re-displays it afterwards.
  static Future<String> createNew() async {
    final mnemonic = bip39.generateMnemonic(strength: 128); // 12 words
    await _restoreInternal(mnemonic);
    return mnemonic;
  }

  /// Restores the master key pair from a previously backed-up mnemonic
  /// (entered on a new/second device, or after a reinstall). Throws
  /// [FormatException] if the phrase is not a valid BIP-39 mnemonic.
  static Future<void> restoreFromMnemonic(String mnemonic) async {
    final normalized = mnemonic.trim().toLowerCase();
    if (!bip39.validateMnemonic(normalized)) {
      throw const FormatException('Invalid recovery phrase');
    }
    await _restoreInternal(normalized);
  }

  static Future<void> _restoreInternal(String mnemonic) async {
    final seed64 = bip39.mnemonicToSeed(mnemonic); // 64 bytes, PBKDF2-HMAC-SHA512
    final seed32 = seed64.sublist(0, 32);
    await SecureStore.write(_seedKey, base64Encode(seed32));
    await _loadFromSeed(seed32);
  }

  static Future<void> _loadFromSeed(List<int> seed32) async {
    final kp = await _ed25519.newKeyPairFromSeed(seed32);
    _keyPair = kp;
    _pubBytes = (await kp.extractPublicKey()).bytes;
    if (kDebugMode) print('[MasterIdentity] loaded, accountId=$accountId');
  }

  static SimpleKeyPair get keyPair {
    final kp = _keyPair;
    if (kp == null) throw StateError('MasterIdentity not loaded');
    return kp;
  }

  static List<int> get publicKeyBytes {
    final pk = _pubBytes;
    if (pk == null) throw StateError('MasterIdentity not loaded');
    return pk;
  }

  static String get publicKeyB64 => base64Encode(publicKeyBytes);

  /// Stable identifier meant to replace username everywhere the app used to
  /// key data by it: the local DB, prefs namespacing, WardLink account
  /// grouping. Full SHA-256 hex of the master public key — long enough not
  /// to collide, cheap to compare, and never changes across devices/reinstalls
  /// as long as the mnemonic is kept.
  static String get accountId =>
      dart_crypto.sha256.convert(publicKeyBytes).toString();

  /// Short, human-comparable fingerprint for display (e.g. "verify with
  /// contact"). Same construction as WardLinkCrypto.fingerprint.
  static String get fingerprint {
    final digest = dart_crypto.sha256.convert(publicKeyBytes).bytes;
    return digest
        .take(8)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(':');
  }

  /// Signs [message] with the master key — used to prove "I hold the same
  /// master key" during WardLink account pairing, replacing the old
  /// username-equality check.
  static Future<List<int>> sign(List<int> message) async {
    final sig = await _ed25519.sign(message, keyPair: keyPair);
    return sig.bytes;
  }

  /// Verifies a signature made by [sign] against a peer's claimed master
  /// public key.
  static Future<bool> verify(
    List<int> message,
    List<int> signature,
    List<int> peerPublicKeyBytes,
  ) async {
    final sig = Signature(
      signature,
      publicKey: SimplePublicKey(peerPublicKeyBytes, type: KeyPairType.ed25519),
    );
    return _ed25519.verify(message, signature: sig);
  }

  /// Wipes the persisted seed and in-memory key. Callers must be certain no
  /// un-migrated local data still depends on the current [accountId] before
  /// calling this — it is not reversible without the mnemonic.
  static Future<void> clear() async {
    await SecureStore.delete(_seedKey);
    _keyPair = null;
    _pubBytes = null;
  }
}
