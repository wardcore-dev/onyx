// lib/utils/onyx_base_dir.dart
//
// Centralised ONYX data-directory resolver.
//
// All ONYX data lives in ONE folder — getApplicationSupportDirectory()
// (e.g. C:\Users\user\AppData\Roaming\WARDCORE\ONYX on Windows).
// Nothing is written to the user's Documents folder any more.
//
// When the user picks a custom location, BOTH docsDir() and supportDir()
// return that same directory — still one flat folder.
//
// The bootstrap config that remembers the chosen path is always stored in
// the original system location (never moves):
//   Windows : %APPDATA%\ONYX\onyx_base_dir.txt
//   macOS   : ~/Library/Application Support/ONYX/onyx_base_dir.txt
//   Linux   : ~/.config/onyx/onyx_base_dir.txt

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../managers/fallback_storage.dart';

class OnyxBaseDir {
  OnyxBaseDir._();

  static String? _customBase;
  static bool _initialized = false;

  // ── Startup ─────────────────────────────────────────────────────────────────

  /// Reads the bootstrap config from its fixed system location.
  /// Must be called once in main() before anything else.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    if (kIsWeb) return;
    try {
      final f = await _bootstrapFile();
      if (await f.exists()) {
        final raw = (await f.readAsString()).trim();
        if (raw.isNotEmpty) {
          if (await Directory(raw).exists()) {
            _customBase = raw;
            debugPrint('[OnyxBaseDir] custom base: $raw');
          } else {
            debugPrint('[OnyxBaseDir] custom dir missing, using defaults: $raw');
          }
        }
      }
    } catch (e) {
      debugPrint('[OnyxBaseDir] init error: $e');
    }
  }

  /// Scans all favorites_* keys in SharedPreferences and fixes any avatarPath
  /// values that still point to the old (pre-migration) location.
  ///
  /// Called automatically from main() on every startup when a custom base is
  /// set. Safe and idempotent: only rewrites a path when:
  ///   - the file at the stored path does NOT exist, AND
  ///   - the same filename exists under the current customBase/fav_avatars/
  static Future<void> fixOrphanedAvatarPaths() async {
    if (kIsWeb) return;
    final custom = _customBase;
    if (custom == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final favAvatarsDir = p.join(custom, 'fav_avatars');

      for (final key in prefs.getKeys()) {
        if (!key.startsWith('favorites_')) continue;
        final raw = prefs.getString(key);
        if (raw == null) continue;
        try {
          final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
          bool changed = false;
          final updated = list.map((fav) {
            final ap = fav['avatarPath'] as String?;
            if (ap == null) return fav;
            if (File(ap).existsSync()) return fav; // already valid
            final filename = p.basename(ap);
            final candidate = p.join(favAvatarsDir, filename);
            if (!File(candidate).existsSync()) return fav; // not found in new location either
            changed = true;
            debugPrint('[OnyxBaseDir] fixed avatar path: $ap → $candidate');
            return {...fav, 'avatarPath': candidate};
          }).toList();
          if (changed) {
            await prefs.setString(key, jsonEncode(updated));
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[OnyxBaseDir] fixOrphanedAvatarPaths error: $e');
    }
  }

  /// One-time consolidation: copies non-encrypted ONYX directories that were
  /// previously written to the user's Documents folder into the Support folder.
  /// A sentinel file prevents redundant work on subsequent launches.
  static Future<void> consolidateFromDocuments() async {
    if (kIsWeb) return;
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
    try {
      final support = await getApplicationSupportDirectory();
      final sentinel = File(p.join(support.path, '.onyx_docs_consolidated'));
      if (await sentinel.exists()) return;

      final docs = await getApplicationDocumentsDirectory();
      if (docs.path == support.path) {
        await sentinel.create();
        return;
      }

      // Directories to move from Documents → Support (media caches).
      const dirsToMove = ['lan_media', 'fav_media', 'voice_cache'];
      // Single files to move.
      const filesToMove = ['decoy_avatar.jpg'];

      for (final name in dirsToMove) {
        final src = Directory(p.join(docs.path, name));
        if (!await src.exists()) continue;
        final dest = Directory(p.join(support.path, name));
        final errors = <String>[];
        await _copyDir(src, dest, errors: errors);
      }
      for (final name in filesToMove) {
        final src = File(p.join(docs.path, name));
        if (!await src.exists()) continue;
        final dest = File(p.join(support.path, name));
        if (!await dest.exists()) await src.copy(dest.path);
      }

      await sentinel.create();
      debugPrint('[OnyxBaseDir] consolidateFromDocuments: done');
    } catch (e) {
      debugPrint('[OnyxBaseDir] consolidateFromDocuments error: $e');
    }
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// The currently active custom base path, or null if using system defaults.
  static String? get customBase => _customBase;

  /// The directory that holds the bootstrap config and persistent backups.
  /// This location never changes regardless of data folder moves.
  static Future<String> bootstrapDir() => _bootstrapDirPath();

  /// Saves [path] as the new custom base and updates the bootstrap config.
  /// Pass null or empty string to reset to system defaults.
  static Future<void> setCustomBase(String? path) async {
    final trimmed = path?.trim() ?? '';
    final f = await _bootstrapFile();
    await f.writeAsString(trimmed);
    _customBase = trimmed.isEmpty ? null : trimmed;
    debugPrint('[OnyxBaseDir] base → ${_customBase ?? "<system defaults>"}');
  }

  /// Copies all ONYX data from the current folder to [newBasePath] and
  /// updates the bootstrap config.  The destination is a flat directory —
  /// all files go directly into [newBasePath], no subdirectories.
  ///
  /// [onStep] receives the name of each item being processed.
  /// Returns a list of non-fatal copy errors (original files are never deleted).
  static Future<List<String>> migrate(
    String newBasePath, {
    void Function(String)? onStep,
  }) async {
    final errors = <String>[];
    final newDir = Directory(newBasePath);
    await newDir.create(recursive: true);

    final oldDir = await supportDir();

    onStep?.call('Copying data…');
    await _copyDir(oldDir, newDir, onStep: onStep, errors: errors);

    // Re-encrypt FallbackStorage files for the new directory path.
    // v2 keys are HKDF-derived from the directory path; without this step the
    // files cannot be decrypted at the new location.
    onStep?.call('Re-encrypting storage…');
    await FallbackStorage.main.relocate(newBasePath);
    await FallbackStorage.decoy.relocate(newBasePath);

    await setCustomBase(newBasePath);
    return errors;
  }

  // ── Directory accessors ─────────────────────────────────────────────────────

  /// Both docsDir() and supportDir() return the SAME single ONYX folder so
  /// that all application data lives in one place.
  ///
  /// Default  : getApplicationSupportDirectory()  (AppData\WARDCORE\ONYX on Windows)
  /// Custom   : the user-chosen directory directly (flat, no subdirs)
  static Future<Directory> docsDir() async {
    if (_customBase != null) {
      final d = Directory(_customBase!);
      await d.create(recursive: true);
      return d;
    }
    return getApplicationSupportDirectory();
  }

  static Future<Directory> supportDir() async {
    if (_customBase != null) {
      final d = Directory(_customBase!);
      await d.create(recursive: true);
      return d;
    }
    return getApplicationSupportDirectory();
  }

  // ── Bootstrap config helpers ────────────────────────────────────────────────

  static Future<File> _bootstrapFile() async {
    final dir = await _bootstrapDirPath();
    await Directory(dir).create(recursive: true);
    return File(p.join(dir, 'onyx_base_dir.txt'));
  }

  static Future<String> _bootstrapDirPath() async {
    if (!kIsWeb) {
      if (Platform.isWindows) {
        return p.join(Platform.environment['APPDATA'] ?? '', 'ONYX');
      } else if (Platform.isMacOS) {
        return '${Platform.environment['HOME']}/Library/Application Support/ONYX';
      } else if (Platform.isLinux) {
        return '${Platform.environment['HOME']}/.config/onyx';
      }
    }
    final d = await getApplicationSupportDirectory();
    return d.path;
  }

  static Future<void> _copyDir(
    Directory src,
    Directory dest, {
    void Function(String)? onStep,
    required List<String> errors,
  }) async {
    if (!await src.exists()) return;
    await dest.create(recursive: true);
    await for (final entity in src.list(recursive: false)) {
      final name = p.basename(entity.path);
      final destPath = p.join(dest.path, name);
      try {
        if (entity is File) {
          onStep?.call(name);
          await entity.copy(destPath);
        } else if (entity is Directory) {
          await _copyDir(
            entity,
            Directory(destPath),
            onStep: onStep,
            errors: errors,
          );
        }
      } catch (e) {
        errors.add('$name: $e');
        debugPrint('[OnyxBaseDir] copy error $name: $e');
      }
    }
  }
}

// ── Top-level drop-in replacements ─────────────────────────────────────────────

/// Drop-in replacement for getApplicationDocumentsDirectory().
Future<Directory> getOnyxDocumentsDirectory() => OnyxBaseDir.docsDir();

/// Drop-in replacement for getApplicationSupportDirectory().
Future<Directory> getOnyxSupportDirectory() => OnyxBaseDir.supportDir();
