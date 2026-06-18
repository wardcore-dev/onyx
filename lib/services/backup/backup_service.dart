// lib/services/backup/backup_service.dart
//
// Local, file-based backup of ONYX user data. Produces a single .zip the user
// can store anywhere, and restores from one. Nothing leaves the device — this
// is intentionally NOT a cloud backup.
//
// Archive layout:
//   manifest.json                      { version, createdAt, username, scope }
//   prefs.json                         non-sensitive SharedPreferences snapshot
//   chats/<encodedChatId>.json         messages for the selected chat scope
//   fav_avatars/<file>                 favourite avatars (favorites scope)
//   media/<type>/<basename>            referenced media (when enabled, by type)
//
// Restore writes chats back via AccountManager.saveSingleChat and media via
// WardLinkMedia.saveTarget, so files land where the message widgets look for
// them regardless of the machine.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../managers/account_manager.dart';
import '../../models/chat_message.dart';
import '../../utils/onyx_base_dir.dart';
import '../lan_fav_sync_service.dart';
import '../wardlink/wardlink_media.dart';

enum BackupFrequency { off, daily, weekly, monthly }

class BackupCancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class BackupCancelledException implements Exception {
  const BackupCancelledException();
}

extension BackupFrequencyX on BackupFrequency {
  Duration? get interval => switch (this) {
        BackupFrequency.off => null,
        BackupFrequency.daily => const Duration(days: 1),
        BackupFrequency.weekly => const Duration(days: 7),
        BackupFrequency.monthly => const Duration(days: 30),
      };
  String get storageValue => name;
  static BackupFrequency parse(String? v) =>
      BackupFrequency.values.firstWhere((e) => e.name == v,
          orElse: () => BackupFrequency.monthly);
}

/// What to put in a backup. Defaults mirror the catastrophic-loss case: both
/// chat categories, no media (fast/compact); media is opt-in per type.
class BackupOptions {
  final bool favorites;
  final bool personal;
  final bool includeMedia;
  final bool mediaImages;
  final bool mediaVideos;
  final bool mediaVoice;
  final bool mediaOther;

  const BackupOptions({
    this.favorites = true,
    this.personal = true,
    this.includeMedia = false,
    this.mediaImages = true,
    this.mediaVideos = true,
    this.mediaVoice = true,
    this.mediaOther = true,
  });

  bool typeSelected(String type) {
    if (!includeMedia) return false;
    switch (type) {
      case 'image':
        return mediaImages;
      case 'video':
        return mediaVideos;
      case 'voice':
      case 'audio':
        return mediaVoice;
      default: // file, document, archive, data
        return mediaOther;
    }
  }
}

class BackupImportResult {
  final int chats;
  final int messages;
  final int mediaFiles;
  final int settings;
  const BackupImportResult(
      this.chats, this.messages, this.mediaFiles, this.settings);
}

class BackupService {
  BackupService._();

  static const _schemaVersion = 1;

  // Same security-sensitive keys SettingsBackup refuses to touch.
  static const _excludedPrefKeys = <String>{
    'pin_lock_enabled',
    'biometric_lock_enabled',
    'pin_lock_code',
    'biometric_lock_code',
    'biometric_unlock_pin',
  };

  // ── Config (persisted in SharedPreferences) ───────────────────────────────

  static const _kFreq = 'backup_frequency';
  static const _kLastAuto = 'backup_last_auto_ms';
  static const _kDir = 'backup_dir';
  static const _kScopeFav = 'backup_scope_favorites';
  static const _kScopePersonal = 'backup_scope_personal';
  static const _kMedia = 'backup_include_media';
  static const _kMediaImg = 'backup_media_images';
  static const _kMediaVid = 'backup_media_videos';
  static const _kMediaVoice = 'backup_media_voice';
  static const _kMediaOther = 'backup_media_other';

  static Future<BackupOptions> loadOptions() async {
    final pr = await SharedPreferences.getInstance();
    return BackupOptions(
      favorites: pr.getBool(_kScopeFav) ?? true,
      personal: pr.getBool(_kScopePersonal) ?? true,
      includeMedia: pr.getBool(_kMedia) ?? false,
      mediaImages: pr.getBool(_kMediaImg) ?? true,
      mediaVideos: pr.getBool(_kMediaVid) ?? true,
      mediaVoice: pr.getBool(_kMediaVoice) ?? true,
      mediaOther: pr.getBool(_kMediaOther) ?? true,
    );
  }

  static Future<void> saveOptions(BackupOptions o) async {
    final pr = await SharedPreferences.getInstance();
    await pr.setBool(_kScopeFav, o.favorites);
    await pr.setBool(_kScopePersonal, o.personal);
    await pr.setBool(_kMedia, o.includeMedia);
    await pr.setBool(_kMediaImg, o.mediaImages);
    await pr.setBool(_kMediaVid, o.mediaVideos);
    await pr.setBool(_kMediaVoice, o.mediaVoice);
    await pr.setBool(_kMediaOther, o.mediaOther);
  }

  static Future<BackupFrequency> loadFrequency() async {
    final pr = await SharedPreferences.getInstance();
    return BackupFrequencyX.parse(pr.getString(_kFreq));
  }

  static Future<void> saveFrequency(BackupFrequency f) async {
    final pr = await SharedPreferences.getInstance();
    await pr.setString(_kFreq, f.storageValue);
  }

  static Future<String> backupDir() async {
    final pr = await SharedPreferences.getInstance();
    final custom = pr.getString(_kDir);
    if (custom != null && custom.trim().isNotEmpty) return custom.trim();
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Download/OnyxBackups';
    }
    final boot = await OnyxBaseDir.bootstrapDir();
    return p.join(boot, 'backups');
  }

  static Future<void> setBackupDir(String? path) async {
    final pr = await SharedPreferences.getInstance();
    if (path == null || path.trim().isEmpty) {
      await pr.remove(_kDir);
    } else {
      await pr.setString(_kDir, path.trim());
    }
  }

  static Future<DateTime?> lastAutoBackup() async {
    final pr = await SharedPreferences.getInstance();
    final ms = pr.getInt(_kLastAuto);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  // ── Export ────────────────────────────────────────────────────────────────

  /// Writes a backup .zip to [destPath]. [chats] is the in-memory chat map
  /// (keys: 'fav:<id>' for favourites, otherwise personal). Returns the file.
  static Future<File> export({
    required String username,
    required Map<String, List<ChatMessage>> chats,
    required BackupOptions opts,
    required String destPath,
    void Function(double progress, String label)? onProgress,
    BackupCancelToken? cancelToken,
  }) async {
    final encoder = ZipFileEncoder();
    encoder.create(destPath);
    try {
      // Which chats are in scope.
      final selectedIds = chats.keys.where((id) {
        final isFav = id.startsWith('fav:');
        return isFav ? opts.favorites : opts.personal;
      }).toList();

      onProgress?.call(0.02, 'Preparing…');
      if (cancelToken?.isCancelled == true) throw const BackupCancelledException();

      // 1) manifest
      final manifest = {
        'schema': _schemaVersion,
        'app': 'onyx',
        'createdAt': DateTime.now().toIso8601String(),
        'username': username,
        'scope': {
          'favorites': opts.favorites,
          'personal': opts.personal,
          'media': opts.includeMedia,
        },
        'chatCount': selectedIds.length,
      };
      _addJson(encoder, 'manifest.json', manifest);

      // 2) prefs snapshot (non-sensitive)
      final pr = await SharedPreferences.getInstance();
      final snap = <String, dynamic>{};
      for (final k in pr.getKeys()) {
        if (_excludedPrefKeys.contains(k)) continue;
        final v = pr.get(k);
        if (v == null) continue;
        snap[k] = v is List ? v.map((e) => e.toString()).toList() : v;
      }
      _addJson(encoder, 'prefs.json', snap);

      // 3) chat message files (in scope)
      for (var i = 0; i < selectedIds.length; i++) {
        if (cancelToken?.isCancelled == true) throw const BackupCancelledException();
        final id = selectedIds[i];
        final msgs = chats[id] ?? const <ChatMessage>[];
        final json = jsonEncode(msgs.map((m) => m.toJson()).toList());
        _addString(encoder, 'chats/${_encodeChatId(id)}.json', json);
        onProgress?.call(
            0.05 + 0.35 * (i + 1) / (selectedIds.length == 0 ? 1 : selectedIds.length),
            'Chats ${i + 1}/${selectedIds.length}');
      }

      // 4) favourite avatars
      if (opts.favorites) {
        final sup = (await getOnyxSupportDirectory()).path;
        final avDir = Directory(p.join(sup, 'fav_avatars'));
        if (await avDir.exists()) {
          await for (final e in avDir.list()) {
            if (cancelToken?.isCancelled == true) throw const BackupCancelledException();
            if (e is File) {
              await encoder.addFile(e, 'fav_avatars/${p.basename(e.path)}');
            }
          }
        }
      }

      // 5) media referenced by the in-scope chats, filtered by type
      if (opts.includeMedia) {
        final added = <String>{};
        final refs = <({String key, String type})>[];
        for (final id in selectedIds) {
          for (final m in chats[id] ?? const <ChatMessage>[]) {
            for (final r in LanFavSyncService.referencedKeys(m.content)) {
              if (opts.typeSelected(r.type)) refs.add(r);
            }
          }
        }
        for (var i = 0; i < refs.length; i++) {
          if (cancelToken?.isCancelled == true) throw const BackupCancelledException();
          final r = refs[i];
          final base = p.basename(r.key);
          if (base.isEmpty || !added.add(base)) continue;
          final local = await WardLinkMedia.resolveLocal(r.key);
          if (local == null) continue;
          final f = File(local);
          if (await f.exists()) {
            await encoder.addFile(f, 'media/${r.type}/$base');
          }
          onProgress?.call(
              0.45 + 0.5 * (i + 1) / (refs.length == 0 ? 1 : refs.length),
              'Media ${i + 1}/${refs.length}');
        }
      }

      onProgress?.call(0.98, 'Finalising…');
    } finally {
      await encoder.close();
    }
    onProgress?.call(1.0, 'Done');
    return File(destPath);
  }

  // ── Import / restore ────────────────────────────────────────────────────────

  static Future<BackupImportResult> import(
    String zipPath, {
    required String username,
    void Function(double progress, String label)? onProgress,
  }) async {
    final input = InputFileStream(zipPath);
    final archive = ZipDecoder().decodeBuffer(input);
    try {
      int chatCount = 0, msgCount = 0, mediaCount = 0, settingCount = 0;
      final files = archive.files.where((f) => f.isFile).toList();
      final sup = (await getOnyxSupportDirectory()).path;

      for (var i = 0; i < files.length; i++) {
        final f = files[i];
        final name = f.name;
        onProgress?.call((i + 1) / files.length, 'Restoring ${i + 1}/${files.length}');

        if (name == 'prefs.json') {
          settingCount += await _restorePrefs(f);
        } else if (name.startsWith('chats/') && name.endsWith('.json')) {
          final encoded = p.basenameWithoutExtension(name);
          final chatId = _decodeChatId(encoded);
          final list = (jsonDecode(_readString(f)) as List)
              .cast<Map<String, dynamic>>()
              .map(ChatMessage.fromJson)
              .toList();
          await AccountManager.saveSingleChat(username, chatId, list);
          chatCount++;
          msgCount += list.length;
        } else if (name.startsWith('fav_avatars/')) {
          final dest = p.join(sup, 'fav_avatars', p.basename(name));
          await _writeFileEntry(f, dest);
        } else if (name.startsWith('media/')) {
          // media/<type>/<basename>
          final parts = name.split('/');
          if (parts.length >= 3) {
            final type = parts[1];
            final base = parts.last;
            final dest = await WardLinkMedia.saveTarget(base, type);
            await _writeFileEntry(f, dest);
            mediaCount++;
          }
        }
      }
      return BackupImportResult(chatCount, msgCount, mediaCount, settingCount);
    } finally {
      input.closeSync();
    }
  }

  /// Reads basic info (createdAt, username, counts) from a backup without
  /// restoring it — used to confirm before overwriting.
  static Future<Map<String, dynamic>?> peekManifest(String zipPath) async {
    final input = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeBuffer(input);
      for (final f in archive.files) {
        if (f.name == 'manifest.json') {
          return jsonDecode(_readString(f)) as Map<String, dynamic>;
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      input.closeSync();
    }
  }

  static Future<int> _restorePrefs(ArchiveFile f) async {
    final pr = await SharedPreferences.getInstance();
    final map = jsonDecode(_readString(f)) as Map<String, dynamic>;
    int n = 0;
    for (final e in map.entries) {
      if (_excludedPrefKeys.contains(e.key)) continue;
      final v = e.value;
      try {
        if (v is bool) {
          await pr.setBool(e.key, v);
        } else if (v is int) {
          await pr.setInt(e.key, v);
        } else if (v is double) {
          await pr.setDouble(e.key, v);
        } else if (v is String) {
          await pr.setString(e.key, v);
        } else if (v is List) {
          await pr.setStringList(e.key, v.map((x) => x.toString()).toList());
        } else {
          continue;
        }
        n++;
      } catch (_) {}
    }
    return n;
  }

  // ── Scheduled auto-backup ───────────────────────────────────────────────────

  /// Runs an automatic backup to the configured folder if the chosen interval
  /// has elapsed. Safe to call on every app start / resume; no-ops otherwise.
  static Future<void> runScheduledIfDue({
    required String username,
    required Map<String, List<ChatMessage>> chats,
  }) async {
    try {
      final freq = await loadFrequency();
      final interval = freq.interval;
      if (interval == null) return; // off
      final last = await lastAutoBackup();
      if (last != null && DateTime.now().difference(last) < interval) return;

      final dir = await backupDir();
      await Directory(dir).create(recursive: true);
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '')
          .replaceAll('.', '')
          .replaceAll('-', '');
      final dest = p.join(dir, 'onyx_backup_auto_$stamp.zip');

      final opts = await loadOptions();
      await export(
          username: username, chats: chats, opts: opts, destPath: dest);

      final pr = await SharedPreferences.getInstance();
      await pr.setInt(_kLastAuto, DateTime.now().millisecondsSinceEpoch);
      await _rotate(dir, keep: 7);
      debugPrint('[BackupService] auto-backup written: $dest');
    } catch (e) {
      debugPrint('[BackupService] auto-backup error: $e');
    }
  }

  static Future<void> _rotate(String dir, {required int keep}) async {
    try {
      final d = Directory(dir);
      final autos = (await d.list().toList())
          .whereType<File>()
          .where((f) => p.basename(f.path).startsWith('onyx_backup_auto_'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path)); // newest first by name
      for (var i = keep; i < autos.length; i++) {
        try {
          await autos[i].delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static void _addJson(
      ZipFileEncoder enc, String name, Map<String, dynamic> data) {
    _addString(enc, name, jsonEncode(data));
  }

  static void _addString(ZipFileEncoder enc, String name, String content) {
    final bytes = utf8.encode(content);
    enc.addArchiveFile(ArchiveFile(name, bytes.length, bytes));
  }

  static String _readString(ArchiveFile f) {
    final content = f.content as List<int>;
    return utf8.decode(content);
  }

  static Future<void> _writeFileEntry(ArchiveFile f, String destPath) async {
    await Directory(p.dirname(destPath)).create(recursive: true);
    final out = OutputFileStream(destPath);
    try {
      f.writeContent(out);
    } finally {
      out.closeSync();
    }
  }

  // Mirror AccountManager's chat-id ↔ filename encoding.
  static String _encodeChatId(String chatId) =>
      chatId.replaceAll('%', '%25').replaceAll(':', '%3A');
  static String _decodeChatId(String encoded) =>
      encoded.replaceAll('%3A', ':').replaceAll('%25', '%');
}
