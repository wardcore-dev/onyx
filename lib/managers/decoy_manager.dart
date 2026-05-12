// lib/managers/decoy_manager.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'secure_store.dart';

class DecoyManager {
  DecoyManager._();

  static const _pinKey = 'decoy_pin_code';
  static const _enabledKey = 'decoy_pin_enabled';
  static const _usernameKey = 'decoy_username';
  static const _displayNameKey = 'decoy_display_name';
  static const _avatarPathKey = 'decoy_avatar_path';

  static final ValueNotifier<bool> isActive = ValueNotifier(false);

  static String username = 'user';
  static String displayName = 'User';
  static String? avatarPath;
  static VoidCallback? onLockRequest;

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  static Future<void> setEnabled(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, val);
  }

  static Future<String?> getPin() => SecureStore.read(_pinKey);
  static Future<void> setPin(String pin) => SecureStore.write(_pinKey, pin);
  static Future<void> clearPin() => SecureStore.delete(_pinKey);

  static Future<void> disable() async {
    await clearPin();
    await setEnabled(false);
    isActive.value = false;
  }

  static Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString(_usernameKey) ?? 'user';
    displayName = prefs.getString(_displayNameKey) ?? 'User';
    avatarPath = prefs.getString(_avatarPathKey);
  }

  static Future<void> saveConfig({
    required String newUsername,
    required String newDisplayName,
    String? newAvatarPath,
    bool clearAvatar = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, newUsername);
    await prefs.setString(_displayNameKey, newDisplayName);
    if (clearAvatar) {
      await prefs.remove(_avatarPathKey);
      avatarPath = null;
    } else if (newAvatarPath != null) {
      await prefs.setString(_avatarPathKey, newAvatarPath);
      avatarPath = newAvatarPath;
    }
    username = newUsername;
    displayName = newDisplayName;
  }

  static Future<void> activate() async {
    await loadConfig();
    isActive.value = true;
  }

  static void deactivate() {
    isActive.value = false;
  }
}
