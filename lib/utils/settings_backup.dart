// lib/utils/settings_backup.dart
//
// Writes a JSON snapshot of all SharedPreferences keys to the bootstrap config
// directory (e.g. %APPDATA%\ONYX\settings_backup.json). That directory is
// separate from the main ONYX data folder and survives accidental deletion.
//
// On the next cold-start:
//   - All static settings are restored if SharedPreferences is empty.
//   - favorites_* / fav_structure_* keys are always restored if missing,
//     even when other settings are intact.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'onyx_base_dir.dart';

// Keys that must NOT be backed up (security-sensitive; PIN data lives in
// SecureStore / FallbackStorage and is meaningless without the encrypted store).
const _kExcludedKeys = <String>{
  'pin_lock_enabled',
  'biometric_lock_enabled',
  'pin_lock_code',
  'biometric_lock_code',
  'biometric_unlock_pin',
};

class SettingsBackup {
  SettingsBackup._();

  static Future<File> _file() async {
    final dir = await OnyxBaseDir.bootstrapDir();
    await Directory(dir).create(recursive: true);
    return File(p.join(dir, 'settings_backup.json'));
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  /// Writes all SharedPreferences keys (except security-sensitive ones) to the
  /// snapshot file. Safe to call fire-and-forget; errors are silently logged.
  static Future<void> save(SharedPreferences prefs) async {
    if (kIsWeb) return;
    try {
      final snapshot = <String, dynamic>{};
      for (final key in prefs.getKeys()) {
        if (_kExcludedKeys.contains(key)) continue;
        final v = prefs.get(key);
        if (v == null) continue;
        // SharedPreferences can return List<Object?> for StringList — convert
        // it to List<String> so jsonEncode handles it correctly.
        if (v is List) {
          snapshot[key] = v.map((e) => e.toString()).toList();
        } else {
          snapshot[key] = v;
        }
      }
      final f = await _file();
      await f.writeAsString(jsonEncode(snapshot), flush: true);
      debugPrint('[SettingsBackup] saved ${snapshot.length} keys');
    } catch (e) {
      debugPrint('[SettingsBackup] save error: $e');
    }
  }

  // ── Restore ─────────────────────────────────────────────────────────────────

  /// Restores settings from the snapshot.
  ///
  /// - All static settings are restored when SharedPreferences appears fresh
  ///   (sentinel keys absent — folder was just deleted or app is newly installed
  ///   on a machine that already has a bootstrap file).
  /// - favorites_* and fav_structure_* keys are always restored if missing in
  ///   prefs but present in the snapshot, so they survive accidental deletion
  ///   even when other settings are intact.
  ///
  /// Returns true if any key was restored.
  static Future<bool> restoreIfEmpty(SharedPreferences prefs) async {
    if (kIsWeb) return false;

    try {
      final f = await _file();
      if (!await f.exists()) return false;

      final Map<String, dynamic> snap =
          jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      if (snap.isEmpty) return false;

      final prefsEmpty = !prefs.containsKey('app_theme_name') &&
          !prefs.containsKey('nav_bar_style') &&
          !prefs.containsKey('app_locale');

      int restored = 0;

      Future<void> restoreKey(String key, dynamic val) async {
        if (_kExcludedKeys.contains(key)) return;
        try {
          if (val is bool)         { await prefs.setBool(key, val);                                    restored++; }
          else if (val is int)     { await prefs.setInt(key, val);                                     restored++; }
          else if (val is double)  { await prefs.setDouble(key, val);                                  restored++; }
          else if (val is String)  { await prefs.setString(key, val);                                  restored++; }
          else if (val is List)    { await prefs.setStringList(key, val.map((e) => e.toString()).toList()); restored++; }
        } catch (_) {}
      }

      for (final entry in snap.entries) {
        final key = entry.key;
        final val = entry.value;
        if (key.startsWith('favorites_') || key.startsWith('fav_structure_')) {
          // Always restore these if missing — favorites must survive folder deletion
          // even when other settings are intact.
          if (!prefs.containsKey(key)) await restoreKey(key, val);
        } else if (prefsEmpty) {
          await restoreKey(key, val);
        }
      }

      debugPrint('[SettingsBackup] restored $restored keys');
      return restored > 0;
    } catch (e) {
      debugPrint('[SettingsBackup] restore error: $e');
      return false;
    }
  }
}
