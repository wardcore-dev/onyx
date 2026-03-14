// lib/managers/fallback_storage.dart
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' as dart_crypto;
import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class FallbackStorage {
  static final FallbackStorage _instance = FallbackStorage._internal();

  factory FallbackStorage() => _instance;
  FallbackStorage._internal();

  Map<String, String> _memoryCache = {};
  File? _storageFile;
  SecretKey? _aesKey;
  bool _initialized = false;

  final _aesGcm = AesGcm.with256bits();

  String get _machineId {
    final user = Platform.environment['USERNAME'] ??
                 Platform.environment['USER'] ??
                 Platform.environment['LOGNAME'] ??
                 'onyx_user';
    final host = Platform.environment['COMPUTERNAME'] ??
                 Platform.environment['HOSTNAME'] ??
                 Platform.localHostname;
    return '$user|$host';
  }

  SecretKey _deriveKeyWithSalt(String appDirPath, List<int> salt) {
    final ikm  = utf8.encode('$_machineId|$appDirPath');
    final info = utf8.encode('onyx-fallback-storage-v3');
    final prk  = dart_crypto.Hmac(dart_crypto.sha256, salt).convert(ikm).bytes;
    final okm  = dart_crypto.Hmac(dart_crypto.sha256, prk).convert([...info, 1]).bytes;
    return SecretKey(okm.sublist(0, 32));
  }

  SecretKey _deriveKeyLegacy(String appDirPath) {
    final ikm  = utf8.encode('$_machineId|$appDirPath');
    final info = utf8.encode('onyx-fallback-storage-v2');
    final zeroes = List<int>.filled(32, 0);
    final prk  = dart_crypto.Hmac(dart_crypto.sha256, zeroes).convert(ikm).bytes;
    final okm  = dart_crypto.Hmac(dart_crypto.sha256, prk).convert([...info, 1]).bytes;
    return SecretKey(okm.sublist(0, 32));
  }

  Future<List<int>> _loadOrCreateSalt(String appDirPath) async {
    final saltFile = File('$appDirPath/.onyx_storage.salt');
    if (await saltFile.exists()) {
      try {
        final b64   = (await saltFile.readAsString()).trim();
        final bytes = base64Decode(b64);
        if (bytes.length == 32) return bytes;
      } catch (e) { debugPrint('[err] $e'); }
    }
    
    final rng      = Random.secure();
    final saltBytes = List<int>.generate(32, (_) => rng.nextInt(256));
    await saltFile.writeAsString(base64Encode(saltBytes));
    return saltBytes;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _storageFile = File('${dir.path}/.onyx_storage.enc');

      final salt = await _loadOrCreateSalt(dir.path);
      _aesKey = _deriveKeyWithSalt(dir.path, salt);

      final oldFile = File('${dir.path}/.onyx_storage.json');
      if (await oldFile.exists()) {
        await _migrateFromPlaintext(oldFile);
      } else {
        
        final loaded = await _tryLoadFromDisk();
        if (!loaded && await _storageFile!.exists()) {
          
          await _migrateFromLegacyKey(dir.path, salt);
        }
      }

      _initialized = true;
    } catch (e) {
      debugPrint('[FallbackStorage] Init failed: $e');
      _initialized = true; 
    }
  }

  Future<void> _migrateFromLegacyKey(String appDirPath, List<int> salt) async {
    try {
      final legacyKey = _deriveKeyLegacy(appDirPath);
      final raw  = await _storageFile!.readAsString();
      final data = await _decryptFromStringWithKey(raw, legacyKey);
      _memoryCache = data;
      await _saveToDisk(); 
      debugPrint('[FallbackStorage] Migrated legacy key → salt-based key');
    } catch (e) {
      debugPrint('[FallbackStorage] Legacy migration failed ($e) — starting fresh');
      _memoryCache = {};
    }
  }

  Future<void> _migrateFromPlaintext(File oldFile) async {
    try {
      final content = await oldFile.readAsString();
      final json    = jsonDecode(content) as Map<String, dynamic>;
      _memoryCache  = json.cast<String, String>();
      await _saveToDisk();
      await oldFile.delete();
      debugPrint('[FallbackStorage] Migrated plaintext storage → encrypted');
    } catch (e) {
      debugPrint('[FallbackStorage] Migration failed: $e — starting fresh');
      _memoryCache = {};
    }
  }

  Future<Map<String, String>> _decryptFromStringWithKey(
      String raw, SecretKey key) async {
    final wrapper    = jsonDecode(raw) as Map<String, dynamic>;
    final nonce      = base64Decode(wrapper['nonce'] as String);
    final ctWithMac  = base64Decode(wrapper['ct'] as String);
    final macBytes   = ctWithMac.sublist(ctWithMac.length - 16);
    final cipherText = ctWithMac.sublist(0, ctWithMac.length - 16);
    final secretBox  = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
    final plainBytes = await _aesGcm.decrypt(secretBox, secretKey: key);
    final inner      = jsonDecode(utf8.decode(plainBytes)) as Map<String, dynamic>;
    return inner.cast<String, String>();
  }

  Future<Map<String, String>> _decryptFromString(String raw) =>
      _decryptFromStringWithKey(raw, _aesKey!);

  Future<String> _encryptToString() async {
    final plainBytes = utf8.encode(jsonEncode(_memoryCache));
    final secretBox  = await _aesGcm.encrypt(plainBytes, secretKey: _aesKey!);
    final ctWithMac  = secretBox.cipherText + secretBox.mac.bytes;
    return jsonEncode({
      'v':     2,
      'nonce': base64Encode(secretBox.nonce),
      'ct':    base64Encode(ctWithMac),
    });
  }

  Future<bool> _tryLoadFromDisk() async {
    
    if (_storageFile != null && await _storageFile!.exists()) {
      try {
        final raw = await _storageFile!.readAsString();
        _memoryCache = await _decryptFromString(raw);
        
        final bak = File('${_storageFile!.path}.bak');
        try { await bak.writeAsString(raw); } catch (e) { debugPrint('[err] $e'); }
        return true;
      } catch (e) {
        debugPrint('[FallbackStorage] Main file corrupt ($e) — trying backup');
      }
    }

    if (_storageFile != null) {
      final bak = File('${_storageFile!.path}.bak');
      if (await bak.exists()) {
        try {
          final raw = await bak.readAsString();
          _memoryCache = await _decryptFromString(raw);
          debugPrint('[FallbackStorage] Recovered from backup — re-saving main file');
          await _saveToDisk();
          return true;
        } catch (e) {
          debugPrint('[FallbackStorage] Backup also corrupt ($e)');
        }
      }
    }

    return false;
  }

  Future<void> _saveToDisk() async {
    if (_storageFile == null || _aesKey == null) return;
    try {
      final content = await _encryptToString();
      final tmpFile = File('${_storageFile!.path}.tmp');
      await tmpFile.writeAsString(content);
      await tmpFile.rename(_storageFile!.path);
    } catch (e) {
      debugPrint('[FallbackStorage] Save failed: $e');
    }
  }

  Future<void> write(String key, String value) async {
    await _ensureInitialized();
    _memoryCache[key] = value;
    await _saveToDisk();
  }

  Future<String?> read(String key) async {
    await _ensureInitialized();
    return _memoryCache[key];
  }

  Future<void> delete(String key) async {
    await _ensureInitialized();
    _memoryCache.remove(key);
    await _saveToDisk();
  }

  Future<void> clear() async {
    await _ensureInitialized();
    _memoryCache.clear();
    await _saveToDisk();
  }
}

final fallbackStorage = FallbackStorage();