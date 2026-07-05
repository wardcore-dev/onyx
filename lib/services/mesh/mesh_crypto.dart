// lib/services/mesh/mesh_crypto.dart
//
// Криптография для BLE Mesh транспорта.
// Алгоритм: X25519 ECDH + HKDF-SHA256 + XChaCha20-Poly1305.
// Использует тот же WardLinkIdentity keypair что и WardLink — одна identity на устройство.
// Промежуточные узлы видят только recipient_hash и зашифрованный blob.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as dart_crypto;
import 'package:cryptography/cryptography.dart';

import '../wardlink/wardlink_identity.dart';

class MeshCrypto {
  static final X25519 _x25519 = X25519();
  static final Cipher _xchacha = Xchacha20.poly1305Aead();

  // ── Identity helpers ───────────────────────────────────────────────────────

  /// 16-байтный усечённый SHA-256 от публичного ключа.
  /// Используется как broadcaster UUID в BLE и как recipient_hash в пакете.
  static Uint8List keyHashFromPub(List<int> pubBytes) {
    final digest = dart_crypto.sha256.convert(pubBytes).bytes;
    return Uint8List.fromList(digest.sublist(0, 16));
  }

  /// Хэш собственного публичного ключа (загруженного из WardLinkIdentity).
  static Uint8List get myKeyHash =>
      keyHashFromPub(WardLinkIdentity.publicKeyBytes);

  /// Публичный ключ в виде Uint8List.
  static Uint8List get myPublicKeyBytes =>
      Uint8List.fromList(WardLinkIdentity.publicKeyBytes);

  // ── Уникальный цвет пользователя по хэшу публичного ключа ──────────────

  /// Детерминированный цвет из первых 3 байт хэша.
  /// Один и тот же человек — всегда один цвет на всех устройствах.
  static int colorFromPub(List<int> pubBytes) {
    final hash = dart_crypto.sha256.convert(pubBytes).bytes;
    final h = (hash[0] / 255.0) * 360.0;
    final s = 0.55 + (hash[1] / 255.0) * 0.30;
    final l = 0.45 + (hash[2] / 255.0) * 0.15;
    return _hslToArgb(h, s, l);
  }

  static int _hslToArgb(double h, double s, double l) {
    final c = (1 - (2 * l - 1).abs()) * s;
    final x = c * (1 - ((h / 60) % 2 - 1).abs());
    final m = l - c / 2;
    double r, g, b;
    if (h < 60) { r = c; g = x; b = 0; }
    else if (h < 120) { r = x; g = c; b = 0; }
    else if (h < 180) { r = 0; g = c; b = x; }
    else if (h < 240) { r = 0; g = x; b = c; }
    else if (h < 300) { r = x; g = 0; b = c; }
    else { r = c; g = 0; b = x; }
    final ri = ((r + m) * 255).round();
    final gi = ((g + m) * 255).round();
    final bi = ((b + m) * 255).round();
    return 0xFF000000 | (ri << 16) | (gi << 8) | bi;
  }

  // ── HKDF-SHA256 (идентичен WardLinkCrypto) ────────────────────────────────

  static List<int> _hkdf(List<int> ikm, List<int> info, int length) {
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

  /// Общий ключ XChaCha20 из ECDH: мой постоянный приватный + публичный собеседника.
  static Future<SecretKey> deriveSharedKey(List<int> peerPubBytes) async {
    final remote = SimplePublicKey(peerPubBytes, type: KeyPairType.x25519);
    final shared = await _x25519.sharedSecretKey(
      keyPair: WardLinkIdentity.keyPair,
      remotePublicKey: remote,
    );
    final sharedBytes = await shared.extractBytes();
    return SecretKey(_hkdf(sharedBytes, utf8.encode('onyx-mesh-v1'), 32));
  }

  /// Генерирует одноразовую X25519 keypair для использования в качестве
  /// эфемерного ключа отправителя. Вызывается один раз на каждый исходящий пакет.
  static Future<SimpleKeyPair> generateEphemeralKeyPair() =>
      _x25519.newKeyPair();

  /// Общий ключ из произвольной keypair (не постоянного ключа устройства).
  /// Используется отправителем с ephKeyPair и получателем с постоянным ключом.
  static Future<SecretKey> deriveSharedKeyFrom(
    SimpleKeyPair keyPair,
    List<int> peerPubBytes,
  ) async {
    final remote = SimplePublicKey(peerPubBytes, type: KeyPairType.x25519);
    final shared = await _x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: remote,
    );
    final sharedBytes = await shared.extractBytes();
    return SecretKey(_hkdf(sharedBytes, utf8.encode('onyx-mesh-v1'), 32));
  }

  // ── XChaCha20-Poly1305 шифрование/дешифрование ────────────────────────────

  /// Шифрует plaintext. Возвращает: [24-byte nonce][ciphertext][16-byte MAC].
  static Future<Uint8List> encrypt(SecretKey key, List<int> plaintext) async {
    final box = await _xchacha.encrypt(plaintext, secretKey: key);
    return Uint8List.fromList([
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  /// Расшифровывает blob формата [24 nonce][cipher][16 MAC]. Возвращает null при ошибке.
  static Future<Uint8List?> decrypt(SecretKey key, Uint8List blob) async {
    if (blob.length < 40) return null;
    try {
      final nonce = blob.sublist(0, 24);
      final mac = blob.sublist(blob.length - 16);
      final cipher = blob.sublist(24, blob.length - 16);
      final box = SecretBox(cipher, nonce: nonce, mac: Mac(mac));
      final plain = await _xchacha.decrypt(box, secretKey: key);
      return Uint8List.fromList(plain);
    } catch (_) {
      return null;
    }
  }
}
