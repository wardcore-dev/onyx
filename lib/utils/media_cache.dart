// lib/utils/media_cache.dart
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import '../managers/secure_store.dart';
import 'package:path_provider/path_provider.dart';

class MediaCache {
  static final MediaCache instance = MediaCache._();
  MediaCache._();

  SecretKey? _key;
  final _aesGcm = AesGcm.with256bits();
  bool _initialized = false;

  static const _keyStorageKey = 'onyx_media_cache_key';
  static const _nonceLen = 12;
  static const _macLen = 16;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      String? keyHex = await SecureStore.read(_keyStorageKey);

      if (keyHex == null || keyHex.length != 64) {
        
        final rand = Random.secure();
        final keyBytes = Uint8List.fromList(
            List.generate(32, (_) => rand.nextInt(256)));
        keyHex =
            keyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        await SecureStore.write(_keyStorageKey, keyHex);
      }

      final keyBytes = Uint8List.fromList(List.generate(
          32,
          (i) => int.parse(
              keyHex!.substring(i * 2, i * 2 + 2),
              radix: 16)));
      _key = SecretKey(keyBytes);
    } catch (e) {
      debugPrint('[MediaCache] init failed: $e — using ephemeral key');
      
      final rand = Random.secure();
      final keyBytes =
          Uint8List.fromList(List.generate(32, (_) => rand.nextInt(256)));
      _key = SecretKey(keyBytes);
    }
  }

  Future<Uint8List> encrypt(Uint8List plain) async {
    await init();
    final rand = Random.secure();
    final nonce = List.generate(_nonceLen, (_) => rand.nextInt(256));
    final secretBox =
        await _aesGcm.encrypt(plain, secretKey: _key!, nonce: nonce);

    final result = Uint8List(_nonceLen + secretBox.cipherText.length + _macLen);
    result.setRange(0, _nonceLen, secretBox.nonce);
    result.setRange(_nonceLen, _nonceLen + secretBox.cipherText.length,
        secretBox.cipherText);
    result.setRange(
        _nonceLen + secretBox.cipherText.length, result.length, secretBox.mac.bytes);
    return result;
  }

  Future<Uint8List> decrypt(Uint8List encrypted) async {
    await init();
    if (encrypted.length < _nonceLen + _macLen) {
      throw Exception('[MediaCache] Invalid encrypted data (too short: ${encrypted.length} bytes)');
    }
    final nonce = encrypted.sublist(0, _nonceLen);
    final mac = encrypted.sublist(encrypted.length - _macLen);
    final ct = encrypted.sublist(_nonceLen, encrypted.length - _macLen);

    final secretBox = SecretBox(ct, nonce: nonce, mac: Mac(mac));
    final plain = await _aesGcm.decrypt(secretBox, secretKey: _key!);
    return Uint8List.fromList(plain);
  }

  Future<File> writeEncrypted(
      Directory cacheDir, String basename, Uint8List plainBytes) async {
    await cacheDir.create(recursive: true);
    final encBytes = await encrypt(plainBytes);
    final encFile = File('${cacheDir.path}/$basename.enc');
    await encFile.writeAsBytes(encBytes, flush: true);
    return encFile;
  }

  Future<File?> findCachedDisplay(
      Directory cacheDir, List<String> basenames, Directory displayDir) async {
    await displayDir.create(recursive: true);
    for (final name in basenames) {
      
      final displayFile = File('${displayDir.path}/$name');
      if (await displayFile.exists()) return displayFile;

      final encFile = File('${cacheDir.path}/$name.enc');
      if (await encFile.exists()) {
        return await _decryptToDisplay(encFile, displayDir, name);
      }
    }
    return null;
  }

  Future<File> decryptToDisplay(
      File encFile, Directory displayDir, String displayName) async {
    return _decryptToDisplay(encFile, displayDir, displayName);
  }

  Future<File> _decryptToDisplay(
      File encFile, Directory displayDir, String name) async {
    await displayDir.create(recursive: true);
    final encBytes = await encFile.readAsBytes();
    final plainBytes = await decrypt(encBytes);
    final displayFile = File('${displayDir.path}/$name');
    await displayFile.writeAsBytes(plainBytes, flush: true);
    return displayFile;
  }

  Future<Directory> displayDirFor(String type) async {
    final tempDir = await getTemporaryDirectory();
    final dir = Directory('${tempDir.path}/onyx_display/$type');
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> clearDisplayCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final displayRoot = Directory('${tempDir.path}/onyx_display');
      if (await displayRoot.exists()) {
        await displayRoot.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('[MediaCache] clearDisplayCache failed: $e');
    }
  }
}