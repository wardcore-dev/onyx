import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LockManager {
  static const _chatsKey = 'locked_chats';
  static const _pinKeyPrefix = 'lock_pin_';
  static final _localAuth = LocalAuthentication();

  static final ValueNotifier<Set<String>> lockedChats =
      ValueNotifier<Set<String>>({});

  static final _sessionUnlocked = <String>{};
  static final Map<String, String> _cachedPinHashes = {};

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_chatsKey) ?? [];
    lockedChats.value = Set<String>.from(list);

    for (final key in prefs.getKeys()) {
      if (key.startsWith(_pinKeyPrefix)) {
        final value = prefs.getString(key);
        if (value != null && value.isNotEmpty) {
          _cachedPinHashes[key.substring(_pinKeyPrefix.length)] = value;
        }
      }
    }

    // If a chat is marked locked but its PIN was lost (e.g. prefs cleared),
    // remove the stale lock so the user isn't permanently locked out.
    final orphaned = lockedChats.value
        .where((id) => !_cachedPinHashes.containsKey(id))
        .toList();
    if (orphaned.isNotEmpty) {
      final updated = Set<String>.from(lockedChats.value)..removeAll(orphaned);
      lockedChats.value = updated;
      await prefs.setStringList(_chatsKey, updated.toList());
    }
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_chatsKey, lockedChats.value.toList());
  }

  // ── Lock state ─────────────────────────────────────────────────────────────

  static bool isLocked(String chatId) => lockedChats.value.contains(chatId);

  static Future<void> lock(String chatId) async {
    final updated = Set<String>.from(lockedChats.value)..add(chatId);
    lockedChats.value = updated;
    await _save();
  }

  static Future<void> removeLock(String chatId) async {
    final updated = Set<String>.from(lockedChats.value)..remove(chatId);
    lockedChats.value = updated;
    _sessionUnlocked.remove(chatId);
    _cachedPinHashes.remove(chatId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_pinKeyPrefix$chatId');
    await _save();
  }

  // ── Session unlock (stays open until app restart) ──────────────────────────

  static bool isSessionUnlocked(String chatId) =>
      _sessionUnlocked.contains(chatId);

  static void sessionUnlock(String chatId) => _sessionUnlocked.add(chatId);

  static void clearSession() => _sessionUnlocked.clear();

  // Re-locks a single id (e.g. a favorites folder) without touching every
  // other session-unlocked chat — used when the user leaves a locked folder,
  // so its PIN is required again next time instead of staying open for the
  // rest of the app session like a regular locked chat does.
  static void relock(String chatId) => _sessionUnlocked.remove(chatId);

  // ── PIN ────────────────────────────────────────────────────────────────────

  static bool hasPin(String chatId) =>
      _cachedPinHashes.containsKey(chatId) &&
      _cachedPinHashes[chatId]!.isNotEmpty;

  static String _hash(String pin) {
    final bytes = utf8.encode('onyx_lock_$pin');
    return crypto.sha256.convert(bytes).toString();
  }

  static Future<void> setPin(String chatId, String pin) async {
    final h = _hash(pin);
    _cachedPinHashes[chatId] = h;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_pinKeyPrefix$chatId', h);
  }

  static bool verifyPin(String chatId, String pin) {
    final hash = _cachedPinHashes[chatId];
    if (hash == null) return false;
    return _hash(pin) == hash;
  }

  // ── Biometrics ─────────────────────────────────────────────────────────────

  static Future<bool> biometricsAvailable() async {
    try {
      if (kIsWeb) return false;
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock chat',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
