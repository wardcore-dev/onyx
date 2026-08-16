// lib/managers/profile_preset_manager.dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/profile_preset.dart';
import 'account_manager.dart';
import 'secure_store.dart';

/// Manages saved username/password profile presets used to speed up
/// registering/logging in on external group/channel servers.
class ProfilePresetManager {
  static const _presetsKey = 'profile_presets';

  static final ValueNotifier<List<ProfilePreset>> presets = ValueNotifier([]);

  static Future<void> loadPresets() async {
    final username = await AccountManager.getCurrentAccount();
    if (username == null) {
      presets.value = [];
      return;
    }
    final key = '${_presetsKey}_$username';
    String? json;
    try {
      json = await SecureStore.read(key);
    } catch (e) {
      debugPrint('[profile-presets] read failed: $e');
    }
    if (json != null && json.isNotEmpty) {
      try {
        presets.value = ProfilePreset.decodeList(json);
      } catch (e) {
        debugPrint('[profile-presets] decode failed: $e');
        presets.value = [];
      }
    } else {
      presets.value = [];
    }
  }

  static Future<void> _save() async {
    final username = await AccountManager.getCurrentAccount();
    if (username == null) return;
    final key = '${_presetsKey}_$username';
    try {
      await SecureStore.write(key, ProfilePreset.encodeList(presets.value));
    } catch (e) {
      debugPrint('[profile-presets] write failed: $e');
    }
  }

  static Future<ProfilePreset> addPreset({
    required String label,
    required int colorIndex,
    String note = '',
    required String username,
    required String password,
  }) async {
    final preset = ProfilePreset(
      id: _generateId(),
      label: label,
      colorIndex: colorIndex,
      note: note,
      username: username,
      password: password,
      createdAt: DateTime.now(),
    );
    presets.value = [...presets.value, preset];
    await _save();
    return preset;
  }

  static Future<void> updatePreset(ProfilePreset updated) async {
    presets.value =
        presets.value.map((p) => p.id == updated.id ? updated : p).toList();
    await _save();
  }

  static Future<void> removePreset(String id) async {
    presets.value = presets.value.where((p) => p.id != id).toList();
    await _save();
  }

  static String _generateId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
