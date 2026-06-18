// lib/managers/fallback_storage.dart
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' as dart_crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/onyx_base_dir.dart';

// Storage format versions:
//   v2 — AES-256-GCM, key derived from machine identity via HKDF-SHA256
//   v3 — AES-256-GCM, key derived from user PIN via Argon2id
//
// Downgrade path: disable PIN in the app → re-encrypts back to v2.

class FallbackStorage {
  // Two singletons: one for real data, one for the decoy partition.
  static final FallbackStorage main  = FallbackStorage._internal('main');
  static final FallbackStorage decoy = FallbackStorage._internal('decoy');

  final String _id;
  FallbackStorage._internal(this._id);

  Map<String, String> _memoryCache = {};
  File? _storageFile;
  SecretKey? _aesKey;
  List<int>? _argon2Salt; // non-null ↔ v3 mode
  String? _unlockedPin;   // kept in memory for mid-session verifyPin()
  bool _initialized = false;
  bool _needsPin    = false; // v3 file detected, waiting for PIN

  final _aesGcm = AesGcm.with256bits();

  // Serialises concurrent _saveToDisk() calls so they don't race on the
  // temp file (which previously caused "rename: No such file" errors).
  Future<void> _saveChain = Future.value();
  int _tmpCounter = 0;

  // ── File names ─────────────────────────────────────────────────────────────

  String get _encFileName  => _id == 'main' ? '.onyx_storage.enc'
                                             : '.onyx_storage_$_id.enc';
  String get _saltFileName => '.onyx_${_id}_storage.salt';

  // ── Public state ───────────────────────────────────────────────────────────

  /// True when a v3 file exists but PIN has not been entered yet.
  bool get isLocked => _initialized && _needsPin && _aesKey == null;

  /// True when storage is operating in v3 (PIN-derived) mode.
  bool get isV3 => _argon2Salt != null || _needsPin;

  // ── HKDF key derivation (v2, machine-derived) ──────────────────────────────

  String get _machineId {
    final user = Platform.environment['USERNAME'] ??
                 Platform.environment['USER']     ??
                 Platform.environment['LOGNAME']  ??
                 'onyx_user';
    final host = Platform.environment['COMPUTERNAME'] ??
                 Platform.environment['HOSTNAME']     ??
                 Platform.localHostname;
    return '$user|$host';
  }

  SecretKey _hkdfKey(String appDirPath, List<int> salt) {
    final ikm  = utf8.encode('$_machineId|$appDirPath');
    final info = utf8.encode('onyx-fallback-storage-v3');
    final prk  = dart_crypto.Hmac(dart_crypto.sha256, salt).convert(ikm).bytes;
    final okm  = dart_crypto.Hmac(dart_crypto.sha256, prk).convert([...info, 1]).bytes;
    return SecretKey(okm.sublist(0, 32));
  }

  SecretKey _hkdfKeyLegacy(String appDirPath) {
    final ikm    = utf8.encode('$_machineId|$appDirPath');
    final info   = utf8.encode('onyx-fallback-storage-v2');
    final zeroes = List<int>.filled(32, 0);
    final prk    = dart_crypto.Hmac(dart_crypto.sha256, zeroes).convert(ikm).bytes;
    final okm    = dart_crypto.Hmac(dart_crypto.sha256, prk).convert([...info, 1]).bytes;
    return SecretKey(okm.sublist(0, 32));
  }

  Future<List<int>> _loadOrCreateHkdfSalt(String appDirPath) async {
    final saltFile = File('$appDirPath/$_saltFileName');
    if (await saltFile.exists()) {
      try {
        final bytes = base64Decode((await saltFile.readAsString()).trim());
        if (bytes.length == 32) return bytes;
      } catch (_) {}
    }
    final salt = _randomBytes(32);
    await saltFile.writeAsString(base64Encode(salt));
    return salt;
  }

  // ── Argon2id key derivation (v3, PIN-derived) ──────────────────────────────

  // Parameters chosen for ~1-3 s in pure-Dart on desktop.
  // TODO: add cryptography_flutter for native speed.
  static const _a2Memory = 8 * 1024; // 8 MB
  static const _a2Iter   = 2;
  static const _a2Par    = 1;

  Future<SecretKey> _argon2Key(String pin, List<int> salt) {
    return Argon2id(
      parallelism: _a2Par,
      memory:      _a2Memory,
      iterations:  _a2Iter,
      hashLength:  32,
    ).deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce:     salt,
    );
  }

  List<int> _randomBytes(int len) {
    final rng = Random.secure();
    return List<int>.generate(len, (_) => rng.nextInt(256));
  }

  // ── Auto-initialization (v2 mode, no PIN required) ─────────────────────────

  Future<void> initialize() => _ensureInitialized();

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      final dir = await getOnyxDocumentsDirectory();
      _storageFile = File('${dir.path}/$_encFileName');

      // Non-main partitions (decoy): only PIN-based, no machine-key fallback.
      if (_id != 'main') {
        if (!await _storageFile!.exists()) {
          // One-time migration: file may still be in legacy Documents folder.
          await _tryCopyDecoyFromDocuments(dir.path);
        }
        if (await _storageFile!.exists()) _needsPin = true;
        _initialized = true;
        return;
      }

      // Main partition: if the file is missing here, attempt one-time migration
      // from the legacy Documents folder (pre-consolidation builds wrote there).
      if (!await _storageFile!.exists()) {
        final migrated = await _tryMigrateMainFromDocuments(dir.path);
        if (migrated) return; // _initialized set inside
      }

      // Main partition: check file version.
      if (await _storageFile!.exists()) {
        try {
          final wrapper = jsonDecode(await _storageFile!.readAsString())
              as Map<String, dynamic>;
          if ((wrapper['v'] as int? ?? 2) >= 3) {
            _needsPin    = true;
            _initialized = true;
            return;
          }
        } catch (_) {}
      }

      // v2 or no file: unlock with machine-derived key.
      final hkdfSalt = await _loadOrCreateHkdfSalt(dir.path);
      _aesKey = _hkdfKey(dir.path, hkdfSalt);

      final oldJson = File('${dir.path}/.onyx_storage.json');
      if (await oldJson.exists()) {
        await _migrateFromPlaintext(oldJson);
      } else {
        final loaded = await _tryLoadFromDisk();
        if (!loaded && await _storageFile!.exists()) {
          await _migrateFromLegacyKey(dir.path);
        }
      }

      // Windows / Linux: carry over data from flutter_secure_storage.
      if (!Platform.isMacOS && _memoryCache.isEmpty) {
        await _migrateFromFlutterSecureStorage();
      }

      _initialized = true;
    } catch (e) {
      debugPrint('[FallbackStorage:$_id] init error: $e');
      _initialized = true;
    }
  }

  /// Looks for the main partition's .enc file in the legacy Documents folder
  /// (where pre-consolidation builds placed it).  If found:
  ///   • v3 (PIN-derived key) – just copies the file; normal flow sets _needsPin.
  ///   • v2 (HKDF path-key)   – decrypts with the Documents-path key and
  ///     re-encrypts at the new Support-path location so the file is readable
  ///     on all future launches without user interaction.
  /// Returns true if v2 migration was completed (caller should return early).
  Future<bool> _tryMigrateMainFromDocuments(String newDirPath) async {
    try {
      final legacyDir = await getApplicationDocumentsDirectory();
      if (legacyDir.path == newDirPath) return false;

      final oldFile = File('${legacyDir.path}/$_encFileName');
      if (!await oldFile.exists()) return false;

      debugPrint('[FallbackStorage:$_id] one-time migration from Documents…');

      final raw     = await oldFile.readAsString();
      final wrapper = jsonDecode(raw) as Map<String, dynamic>;
      final version = wrapper['v'] as int? ?? 2;

      if (version >= 3) {
        // v3: PIN-derived key is path-independent → just copy, let normal
        // flow detect the v3 marker and set _needsPin = true.
        await oldFile.copy(_storageFile!.path);
        final oldSaltFile = File('${legacyDir.path}/$_saltFileName');
        if (await oldSaltFile.exists()) {
          await oldSaltFile.copy('$newDirPath/$_saltFileName');
        }
        debugPrint('[FallbackStorage:$_id] Documents→Support: copied v3 (will need PIN)');
        return false; // caller continues → detects v3 → _needsPin = true
      }

      // v2: key = HKDF(machineId | dirPath, salt) → must re-derive for new path.
      final oldSalt = await _loadOrCreateHkdfSalt(legacyDir.path);
      Map<String, String> data;
      try {
        data = await _decryptPayload(wrapper, _hkdfKey(legacyDir.path, oldSalt));
      } catch (_) {
        data = await _decryptPayload(wrapper, _hkdfKeyLegacy(legacyDir.path));
      }

      _memoryCache = data;
      final newSalt = await _loadOrCreateHkdfSalt(newDirPath);
      _aesKey       = _hkdfKey(newDirPath, newSalt);
      await _saveToDiskNow(); // writes to _storageFile (new path)

      if (!Platform.isMacOS && _memoryCache.isEmpty) {
        await _migrateFromFlutterSecureStorage();
      }
      _initialized = true;
      debugPrint('[FallbackStorage:$_id] Documents→Support: v2 migration done');
      return true;
    } catch (e) {
      debugPrint('[FallbackStorage:$_id] Documents→Support migration failed: $e');
      _aesKey       = null;
      _memoryCache  = {};
      return false;
    }
  }

  /// Copies the decoy partition file from the legacy Documents folder if it
  /// is not yet present in the new Support folder.  Decoy is always v3
  /// (PIN-derived), so a plain copy is sufficient.
  Future<void> _tryCopyDecoyFromDocuments(String newDirPath) async {
    try {
      final legacyDir = await getApplicationDocumentsDirectory();
      if (legacyDir.path == newDirPath) return;
      final oldFile = File('${legacyDir.path}/$_encFileName');
      if (!await oldFile.exists()) return;
      await oldFile.copy(_storageFile!.path);
      debugPrint('[FallbackStorage:decoy] copied from Documents');
    } catch (e) {
      debugPrint('[FallbackStorage:decoy] copy from Documents failed: $e');
    }
  }

  // ── PIN-based unlock ───────────────────────────────────────────────────────

  /// Attempt to unlock a v3 partition with [pin].
  /// Also handles transparent v2→v3 migration on first successful unlock.
  /// Returns true on success.
  Future<bool> unlockWithPin(String pin) async {
    try {
      final dir = await getOnyxDocumentsDirectory();
      _storageFile ??= File('${dir.path}/$_encFileName');

      if (!await _storageFile!.exists()) return false;

      final raw     = await _storageFile!.readAsString();
      final wrapper = jsonDecode(raw) as Map<String, dynamic>;
      final version = wrapper['v'] as int? ?? 2;

      if (version < 3) {
        // v2 file on first update: migrate to v3 now.
        return _migrateV2toV3(pin, dir.path, wrapper);
      }

      // v3: try to decrypt.
      final a2Salt   = base64Decode(wrapper['argon2_salt'] as String);
      final candidate = await _argon2Key(pin, a2Salt);
      final data     = await _decryptPayload(wrapper, candidate);

      _memoryCache  = data;
      _aesKey       = candidate;
      _argon2Salt   = a2Salt;
      _needsPin     = false;
      _initialized  = true;
      _unlockedPin  = pin;
      return true;
    } catch (e) {
      debugPrint('[FallbackStorage:$_id] unlockWithPin failed: $e');
      return false;
    }
  }

  /// Verify [pin] against the currently-unlocked v3 partition (mid-session).
  /// Returns true if the PIN matches the one used to unlock this session.
  bool verifyPin(String pin) => _unlockedPin != null && _unlockedPin == pin;

  /// PIN used to unlock the current session, if any. Needed to stash the PIN
  /// behind biometrics (the v3 file itself no longer stores the PIN).
  String? get currentPin => _unlockedPin;

  /// Create a new v3 partition encrypted with [pin] (used for decoy setup).
  Future<void> createWithPin(String pin) async {
    final dir = await getOnyxDocumentsDirectory();
    _storageFile  = File('${dir.path}/$_encFileName');
    final salt    = _randomBytes(32);
    _aesKey       = await _argon2Key(pin, salt);
    _argon2Salt   = salt;
    _memoryCache  = {};
    _needsPin     = false;
    _initialized  = true;
    _unlockedPin  = pin;
    await _saveToDisk();
    debugPrint('[FallbackStorage:$_id] created v3 partition');
  }

  /// Migrate currently-unlocked v3 storage back to v2 (called on PIN disable).
  Future<void> migrateToV2() async {
    if (_aesKey == null || _argon2Salt == null) return;
    try {
      final dir      = await getOnyxDocumentsDirectory();
      _storageFile ??= File('${dir.path}/$_encFileName');
      final hkdfSalt = await _loadOrCreateHkdfSalt(dir.path);
      _aesKey        = _hkdfKey(dir.path, hkdfSalt);
      _argon2Salt    = null;
      _needsPin      = false;
      await _saveToDisk();
      debugPrint('[FallbackStorage:$_id] migrated v3→v2');
    } catch (e) {
      debugPrint('[FallbackStorage:$_id] migrateToV2 failed: $e');
    }
  }

  /// Migrate currently-unlocked v2 storage to v3 (called on PIN setup).
  Future<void> migrateToV3(String pin) async {
    if (_argon2Salt != null) return; // already v3
    if (_aesKey == null) return;     // not unlocked
    try {
      final salt  = _randomBytes(32);
      _aesKey     = await _argon2Key(pin, salt);
      _argon2Salt = salt;
      _unlockedPin = pin;
      // Stored PIN value no longer needed — PIN IS the key now.
      _memoryCache.remove('pin_lock_code');
      await _saveToDisk();
      debugPrint('[FallbackStorage:$_id] migrated v2→v3');
    } catch (e) {
      debugPrint('[FallbackStorage:$_id] migrateToV3 failed: $e');
    }
  }

  /// Delete the partition file entirely (used when decoy is disabled).
  Future<void> deleteStorage() async {
    final dir  = await getOnyxDocumentsDirectory();
    final file = File('${dir.path}/$_encFileName');
    if (await file.exists()) await file.delete();
    _memoryCache = {};
    _aesKey      = null;
    _argon2Salt  = null;
    _needsPin    = false;
    _initialized = false;
  }

  /// Re-encrypts the in-memory cache into [newDirPath] so the storage is
  /// readable from the new location on the next app launch.
  ///
  /// v2 (no PIN): the HKDF key is derived from the directory path, so we
  ///   re-derive it for [newDirPath] and write a new .enc file there.
  /// v3 (PIN-derived): key is path-independent; just writes a copy.
  ///
  /// The current session is unaffected — internal state is restored after the
  /// write so ongoing saves still target the old location until restart.
  Future<void> relocate(String newDirPath) async {
    if (_aesKey == null) return;
    final oldFile = _storageFile;
    final oldKey  = _aesKey;
    try {
      final newFile = File(p.join(newDirPath, _encFileName));
      _storageFile  = newFile;
      if (_argon2Salt == null) {
        // v2: key is path-derived → re-derive for the new path.
        final newSalt = await _loadOrCreateHkdfSalt(newDirPath);
        _aesKey = _hkdfKey(newDirPath, newSalt);
      }
      // For v3 _aesKey is PIN-derived and already correct; just write.
      await _saveToDiskNow();
      debugPrint('[FallbackStorage:$_id] relocated to $newDirPath');
    } catch (e) {
      debugPrint('[FallbackStorage:$_id] relocate failed: $e');
      rethrow;
    } finally {
      _storageFile = oldFile;
      _aesKey      = oldKey;
    }
  }

  /// Lock in-memory cache. User must call [unlockWithPin] again to access data.
  void lock() {
    _aesKey      = null;
    _argon2Salt  = null;
    _unlockedPin = null;
    _memoryCache = {};
    _needsPin    = true;
  }

  // ── v2 → v3 migration (transparent, triggered by first unlock after update) ─

  Future<bool> _migrateV2toV3(
      String pin, String dirPath, Map<String, dynamic> wrapper) async {
    try {
      final hkdfSalt = await _loadOrCreateHkdfSalt(dirPath);
      Map<String, String> data;
      try {
        data = await _decryptPayload(wrapper, _hkdfKey(dirPath, hkdfSalt));
      } catch (_) {
        data = await _decryptPayload(wrapper, _hkdfKeyLegacy(dirPath));
      }

      data.remove('pin_lock_code');

      // If decoy was configured in v2, migrate it to its own v3 partition.
      if (_id == 'main') {
        final decoyPin = data.remove('decoy_pin_code');
        if (decoyPin != null) {
          await FallbackStorage.decoy.createWithPin(decoyPin);
        }
      }

      final a2Salt  = _randomBytes(32);
      final pinKey  = await _argon2Key(pin, a2Salt);
      _memoryCache  = data;
      _aesKey       = pinKey;
      _argon2Salt   = a2Salt;
      _needsPin     = false;
      _initialized  = true;
      _unlockedPin  = pin;
      await _saveToDisk();

      // Clean up old HKDF salt file.
      try {
        final sf = File('$dirPath/$_saltFileName');
        if (await sf.exists()) await sf.delete();
      } catch (_) {}

      debugPrint('[FallbackStorage:$_id] migrated v2→v3 (transparent)');
      return true;
    } catch (e) {
      debugPrint('[FallbackStorage:$_id] v2→v3 migration failed: $e');
      return false;
    }
  }

  // ── Encryption helpers ─────────────────────────────────────────────────────

  Future<Map<String, String>> _decryptPayload(
      Map<String, dynamic> wrapper, SecretKey key) async {
    final nonce      = base64Decode(wrapper['nonce'] as String);
    final ctWithMac  = base64Decode(wrapper['ct'] as String);
    final macBytes   = ctWithMac.sublist(ctWithMac.length - 16);
    final cipherText = ctWithMac.sublist(0, ctWithMac.length - 16);
    final secretBox  = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
    final plain      = await _aesGcm.decrypt(secretBox, secretKey: key);
    return (jsonDecode(utf8.decode(plain)) as Map<String, dynamic>)
        .cast<String, String>();
  }

  // Serialise saves: each call chains onto the previous so two writes never
  // race on the temp file or the destination.
  Future<void> _saveToDisk() {
    final next = _saveChain.then((_) => _saveToDiskNow());
    // Swallow errors on the chain so one failure doesn't poison later saves.
    _saveChain = next.catchError((_) {});
    return next;
  }

  Future<void> _saveToDiskNow() async {
    if (_storageFile == null || _aesKey == null) return;
    try {
      final plain      = utf8.encode(jsonEncode(_memoryCache));
      final box        = await _aesGcm.encrypt(plain, secretKey: _aesKey!);
      final ctWithMac  = box.cipherText + box.mac.bytes;
      final payload    = <String, dynamic>{
        'nonce': base64Encode(box.nonce),
        'ct':    base64Encode(ctWithMac),
      };
      if (_argon2Salt != null) {
        payload['v']           = 3;
        payload['argon2_salt'] = base64Encode(_argon2Salt!);
      } else {
        payload['v'] = 2;
      }
      final data = jsonEncode(payload);

      // Make sure the destination directory exists (it can be missing on a
      // fresh profile or if ~/Documents was never created).
      final parent = _storageFile!.parent;
      if (!await parent.exists()) await parent.create(recursive: true);

      // Unique temp name per write avoids collisions between concurrent saves.
      final tmp = File(
          '${_storageFile!.path}.${pid}_${_tmpCounter++}.tmp');
      await tmp.writeAsString(data, flush: true);
      try {
        await tmp.rename(_storageFile!.path);
      } catch (_) {
        // Rename can fail (race, cross-volume, or vanished tmp). Fall back to
        // writing the destination directly so data is never lost.
        await _storageFile!.writeAsString(data, flush: true);
        if (await tmp.exists()) {
          try { await tmp.delete(); } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[FallbackStorage:$_id] save failed: $e');
    }
  }

  // ── Load helpers ───────────────────────────────────────────────────────────

  Future<bool> _tryLoadFromDisk() async {
    if (_storageFile == null || !await _storageFile!.exists()) return false;
    try {
      final raw     = await _storageFile!.readAsString();
      _memoryCache  = await _decryptPayload(
          jsonDecode(raw) as Map<String, dynamic>, _aesKey!);
      final bak = File('${_storageFile!.path}.bak');
      try { await bak.writeAsString(raw); } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('[FallbackStorage:$_id] load failed ($e), trying backup');
    }
    final bak = File('${_storageFile!.path}.bak');
    if (await bak.exists()) {
      try {
        final raw = await bak.readAsString();
        _memoryCache = await _decryptPayload(
            jsonDecode(raw) as Map<String, dynamic>, _aesKey!);
        await _saveToDisk();
        return true;
      } catch (e) {
        debugPrint('[FallbackStorage:$_id] backup also corrupt: $e');
      }
    }
    return false;
  }

  Future<void> _migrateFromLegacyKey(String appDirPath) async {
    try {
      final legacyKey = _hkdfKeyLegacy(appDirPath);
      final raw       = await _storageFile!.readAsString();
      _memoryCache    = await _decryptPayload(
          jsonDecode(raw) as Map<String, dynamic>, legacyKey);
      await _saveToDisk();
      debugPrint('[FallbackStorage:$_id] migrated legacy HKDF key');
    } catch (e) {
      debugPrint('[FallbackStorage:$_id] legacy key migration failed: $e');
      _memoryCache = {};
    }
  }

  Future<void> _migrateFromPlaintext(File oldFile) async {
    try {
      _memoryCache = (jsonDecode(await oldFile.readAsString())
              as Map<String, dynamic>)
          .cast<String, String>();
      await _saveToDisk();
      await oldFile.delete();
      debugPrint('[FallbackStorage:$_id] migrated from plaintext');
    } catch (e) {
      debugPrint('[FallbackStorage:$_id] plaintext migration failed: $e');
      _memoryCache = {};
    }
  }

  // Carries over credentials stored in flutter_secure_storage on Windows/Linux.
  Future<void> _migrateFromFlutterSecureStorage() async {
    try {
      const old = FlutterSecureStorage();
      final all = await old.readAll();
      if (all.isNotEmpty) {
        _memoryCache = Map<String, String>.from(all);
        await _saveToDisk();
        await old.deleteAll();
        debugPrint('[FallbackStorage:$_id] migrated from flutter_secure_storage');
      }
    } catch (e) {
      debugPrint('[FallbackStorage:$_id] flutter_secure_storage migration: $e');
    }
  }

  // ── Public key-value API ───────────────────────────────────────────────────

  Future<void> write(String key, String value) async {
    await _ensureInitialized();
    if (isLocked) return;
    _memoryCache[key] = value;
    await _saveToDisk();
  }

  Future<String?> read(String key) async {
    await _ensureInitialized();
    if (isLocked) return null;
    return _memoryCache[key];
  }

  Future<void> delete(String key) async {
    await _ensureInitialized();
    if (isLocked) return;
    _memoryCache.remove(key);
    await _saveToDisk();
  }

  Future<void> clear() async {
    await _ensureInitialized();
    if (isLocked) return;
    _memoryCache.clear();
    await _saveToDisk();
  }
}

// Backward-compat alias used by legacy call sites.
final fallbackStorage = FallbackStorage.main;
