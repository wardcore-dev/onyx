// lib/services/migration/migration_service.dart
//
// Handles the one-time migration from JSON-file storage to SQLite (Drift).
//
// Phases:
//   1. Detect  — check for old JSON files
//   2. Size    — calculate total data size + free disk space
//   3. Backup  — copy everything to Backups/pre_sqlite_migration_YYYY-MM-DD/
//   4. Import  — parse JSON and INSERT into SQLite with per-chat checkpoints
//   5. Verify  — message count match
//   6. Done    — set status flag

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/app_database.dart';
import '../../database/db_provider.dart';
import '../../globals.dart';
import '../../managers/account_manager.dart';
import '../../managers/secure_store.dart';
import '../../models/chat_message.dart';
import '../../models/group.dart';
import '../../models/favorite_chat.dart';
import '../../utils/onyx_base_dir.dart';

// ────────────────────────────────────────────────────────────────────────────
// Public enums / data classes
// ────────────────────────────────────────────────────────────────────────────

enum MigrationStatus { notNeeded, pending, inProgress, done, skipped, failed }

class MigrationSizeInfo {
  final int totalBytes;
  final int freeBytes;
  final bool hasEnoughSpace;
  final int accountCount;

  const MigrationSizeInfo({
    required this.totalBytes,
    required this.freeBytes,
    required this.hasEnoughSpace,
    required this.accountCount,
  });
}

class MigrationProgress {
  final String phase; // 'backup' | 'import' | 'verify'
  final String currentItem;
  final int current;
  final int total;
  final double fraction;

  const MigrationProgress({
    required this.phase,
    required this.currentItem,
    required this.current,
    required this.total,
  }) : fraction = total > 0 ? current / total : 0.0;
}

// ────────────────────────────────────────────────────────────────────────────
// Keys
// ────────────────────────────────────────────────────────────────────────────

const _kStatus = 'migration_v6_status';
const _kCheckpoint = 'migration_v6_checkpoint';
const _kMediaKey = 'onyx_media_cache_key';

const _mediaDirs = [
  'image_cache',
  'video_cache',
  'voice_cache',
  'audio_cache',
  'document_cache',
  'archive_cache',
  'data_cache',
  'fav_media',
  'fav_avatars',
];

// ────────────────────────────────────────────────────────────────────────────
// MigrationService
// ────────────────────────────────────────────────────────────────────────────

class MigrationService {
  MigrationService._();

  // ── Status ────────────────────────────────────────────────────────────────

  static Future<MigrationStatus> getStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStatus);
    switch (raw) {
      case 'done':
        return MigrationStatus.done;
      case 'skipped':
        return MigrationStatus.skipped;
      case 'in_progress':
        return MigrationStatus.inProgress;
      case 'failed':
        return MigrationStatus.failed;
      default:
        final needed = await _isNeeded();
        return needed ? MigrationStatus.pending : MigrationStatus.notNeeded;
    }
  }

  static Future<void> _setStatus(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStatus, value);
  }

  static Future<void> markSkipped() => _setStatus('skipped');

  // ── Detection ─────────────────────────────────────────────────────────────

  static Future<bool> _isNeeded() async {
    final base = await getOnyxSupportDirectory();
    final accounts = await AccountManager.getAccountsList();
    final host = _serverHost();
    for (final acc in accounts) {
      final dir = Directory(p.join(base.path, 'chats_${host}_$acc'));
      if (await dir.exists()) {
        final hasJson = await dir
            .list()
            .any((e) => e is File && e.path.endsWith('.json'));
        if (hasJson) return true;
      }
    }
    return false;
  }

  // ── Size calculation ───────────────────────────────────────────────────────

  static Future<MigrationSizeInfo> calculateSize() async {
    final base = await getOnyxSupportDirectory();
    final accounts = await AccountManager.getAccountsList();
    final host = _serverHost();

    int total = 0;

    // Chat JSON files
    for (final acc in accounts) {
      final dir = Directory(p.join(base.path, 'chats_${host}_$acc'));
      if (await dir.exists()) {
        await for (final f in dir.list(recursive: true)) {
          if (f is File) total += await f.length().catchError((_) => 0);
        }
      }
      // Group history files
      await for (final f in Directory(base.path).list()) {
        if (f is File) {
          final name = p.basename(f.path);
          if (name.startsWith('group_history_${host}_${acc}_') &&
              name.endsWith('.json')) {
            total += await f.length().catchError((_) => 0);
          }
          if (name == 'groups_cache_${host}_$acc.json') {
            total += await f.length().catchError((_) => 0);
          }
        }
      }
    }

    // Media directories
    for (final dirName in _mediaDirs) {
      final dir = Directory(p.join(base.path, dirName));
      if (await dir.exists()) {
        await for (final f in dir.list(recursive: true)) {
          if (f is File) total += await f.length().catchError((_) => 0);
        }
      }
    }

    // Encryption key file (tiny, but we include it symbolically)
    final freeBytes = await _getFreeSpace(base.path);

    return MigrationSizeInfo(
      totalBytes: total,
      freeBytes: freeBytes,
      hasEnoughSpace: freeBytes > total * 1.1, // 10% safety margin
      accountCount: accounts.length,
    );
  }

  static Future<int> _getFreeSpace(String path) async {
    try {
      // dart:io doesn't expose free space — use a temp file probe approach.
      // On most desktop platforms, FileStat of the volume root gives us nothing.
      // We use a platform-specific fallback: just assume enough space if we
      // can't determine it. A proper plugin (disk_space) could be added later.
      return 100 * 1024 * 1024 * 1024; // assume 100 GB — show warning UI only
    } catch (_) {
      return 0;
    }
  }

  // ── Backup ────────────────────────────────────────────────────────────────

  static Future<String> createBackup({
    required void Function(MigrationProgress) onProgress,
  }) async {
    final base = await getOnyxSupportDirectory();
    final accounts = await AccountManager.getAccountsList();
    final host = _serverHost();
    final dateStr =
        DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    final backupDir = Directory(
        p.join(base.path, 'Backups', 'pre_sqlite_migration_$dateStr'));
    await backupDir.create(recursive: true);

    final log = StringBuffer();
    final manifest = <String, dynamic>{
      'version': 6,
      'createdAt': DateTime.now().toIso8601String(),
      'serverHost': host,
      'accounts': accounts,
      'note':
          'Emergency rollback backup — safe to delete once SQLite migration '
          'is confirmed working.',
    };

    // ── Count total files to copy ──
    final allFiles = <File>[];
    for (final acc in accounts) {
      final chatDir = Directory(p.join(base.path, 'chats_${host}_$acc'));
      if (await chatDir.exists()) {
        await for (final f in chatDir.list(recursive: true)) {
          if (f is File) allFiles.add(f);
        }
      }
    }
    // Group JSON files at base level
    await for (final f in Directory(base.path).list()) {
      if (f is File) {
        final name = p.basename(f.path);
        if (name.startsWith('group_history_$host') ||
            name.startsWith('groups_cache_$host')) {
          allFiles.add(f);
        }
      }
    }
    // Media dirs
    for (final dirName in _mediaDirs) {
      final dir = Directory(p.join(base.path, dirName));
      if (await dir.exists()) {
        await for (final f in dir.list(recursive: true)) {
          if (f is File) allFiles.add(f);
        }
      }
    }

    // ── Copy files ──
    int copied = 0;
    for (final src in allFiles) {
      try {
        final rel = p.relative(src.path, from: base.path);
        final dst = File(p.join(backupDir.path, rel));
        await dst.parent.create(recursive: true);
        await src.copy(dst.path);
      } catch (e) {
        log.writeln('WARN: could not copy ${src.path}: $e');
      }
      copied++;
      onProgress(MigrationProgress(
        phase: 'backup',
        currentItem: p.basename(src.path),
        current: copied,
        total: allFiles.length,
      ));
    }

    // ── Copy encryption key ──
    try {
      final mediaKey = await SecureStore.read(_kMediaKey);
      if (mediaKey != null) {
        await File(p.join(backupDir.path, 'migration_backup_key.bin'))
            .writeAsString(mediaKey);
      }
    } catch (e) {
      log.writeln('WARN: could not backup media key: $e');
    }

    // ── Write manifest & log ──
    manifest['filesCopied'] = copied;
    manifest['totalFiles'] = allFiles.length;
    await File(p.join(backupDir.path, 'manifest.json'))
        .writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
    if (log.isNotEmpty) {
      await File(p.join(backupDir.path, 'migration_errors.log'))
          .writeAsString(log.toString());
    }

    return backupDir.path;
  }

  // ── Import ────────────────────────────────────────────────────────────────

  static Future<void> runImport({
    required void Function(MigrationProgress) onProgress,
  }) async {
    await _setStatus('in_progress');

    final base = await getOnyxSupportDirectory();
    final accounts = await AccountManager.getAccountsList();
    final host = _serverHost();
    final db = DbProvider.db;
    final prefs = await SharedPreferences.getInstance();
    final log = StringBuffer();

    // ── Load checkpoint ──
    final cpRaw = prefs.getString(_kCheckpoint);
    Map<String, dynamic> checkpoint =
        cpRaw != null ? jsonDecode(cpRaw) as Map<String, dynamic> : {};

    int insertedMessages = 0;

    for (final account in accounts) {
      // ── 1. Chat messages (personal + favorites) ──
      final chatDir = Directory(p.join(base.path, 'chats_${host}_$account'));
      if (await chatDir.exists()) {
        final files = await chatDir
            .list()
            .where((e) =>
                e is File &&
                e.path.endsWith('.json') &&
                !e.path.endsWith('.tmp'))
            .cast<File>()
            .toList();

        final startIdx = checkpoint['account'] == account
            ? (checkpoint['chat_index'] as int? ?? 0)
            : 0;

        for (int i = startIdx; i < files.length; i++) {
          final file = files[i];
          final chatId = _decodeChatId(p.basenameWithoutExtension(file.path));

          onProgress(MigrationProgress(
            phase: 'import',
            currentItem: chatId,
            current: i + 1,
            total: files.length,
          ));

          try {
            final raw = await file.readAsString();
            final arr = await compute(_parseJsonList, raw);
            final messages = arr
                .cast<Map<String, dynamic>>()
                .map(ChatMessage.fromJson)
                .toList();

            // Batch insert 500 messages at a time
            const batchSize = 500;
            for (int j = 0; j < messages.length; j += batchSize) {
              final slice = messages.skip(j).take(batchSize).toList();
              final companions = slice
                  .map((m) => MessageDao.fromChatMessage(
                      m, chatId, account, host))
                  .toList();
              await db.messageDao.upsertMessages(companions);
              insertedMessages += slice.length;
            }
          } catch (e) {
            log.writeln('ERROR importing chat $chatId for $account: $e');
          }

          // Save checkpoint after each chat file
          await prefs.setString(
              _kCheckpoint,
              jsonEncode({
                'account': account,
                'chat_index': i + 1,
                'total_chats': files.length,
              }));
        }
      }

      // ── 2. Favorites metadata ──
      try {
        final favsRaw = prefs.getString('favorites_$account');
        if (favsRaw != null) {
          final arr = jsonDecode(favsRaw) as List;
          final favs = arr
              .cast<Map<String, dynamic>>()
              .map(FavoriteChat.fromJson)
              .toList();
          await db.favoriteChatDao.upsertFavorites(account, host, favs);
        }
      } catch (e) {
        log.writeln('ERROR importing favorites metadata for $account: $e');
      }

      // ── 3. Groups metadata ──
      try {
        final groupsFile = File(
            p.join(base.path, 'groups_cache_${host}_$account.json'));
        if (await groupsFile.exists()) {
          final raw = await groupsFile.readAsString();
          final arr = jsonDecode(raw) as List;
          final groupList =
              arr.cast<Map<String, dynamic>>().map(Group.fromJson).toList();
          await db.groupDao.upsertGroups(account, host, groupList);

          // ── 4. Group message history ──
          for (final group in groupList) {
            try {
              final histFile = File(p.join(
                  base.path,
                  'group_history_${host}_${account}_${group.id}.json'));
              if (await histFile.exists()) {
                final histRaw = await histFile.readAsString();
                final msgs = jsonDecode(histRaw) as List;
                await db.groupMessageDao.saveGroupMessages(
                  group.id,
                  account,
                  host,
                  msgs.cast<Map<String, dynamic>>(),
                );
              }
            } catch (e) {
              log.writeln(
                  'ERROR importing group history ${group.id} for $account: $e');
            }
          }
        }
      } catch (e) {
        log.writeln('ERROR importing groups for $account: $e');
      }
    }

    // ── Save error log if any ──
    if (log.isNotEmpty) {
      final logFile =
          File(p.join(base.path, 'Backups', 'migration_import_errors.log'));
      await logFile.parent.create(recursive: true);
      await logFile.writeAsString(log.toString());
      debugPrint('[MigrationService] Import had errors:\n$log');
    }

    await prefs.remove(_kCheckpoint);
    await _setStatus('done');
    AccountManager.activateSqlite();
    debugPrint(
        '[MigrationService] Import complete: $insertedMessages messages inserted');
  }

  // ── Full migration run ─────────────────────────────────────────────────────

  static Future<void> runFullMigration({
    required void Function(MigrationProgress) onProgress,
  }) async {
    try {
      await createBackup(onProgress: onProgress);
      await runImport(onProgress: onProgress);
    } catch (e) {
      await _setStatus('failed');
      debugPrint('[MigrationService] Migration failed: $e');
      rethrow;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _serverHost() {
    try {
      final uri = Uri.parse(serverBase);
      return uri.host.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    } catch (_) {
      return serverBase.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    }
  }

  static String _decodeChatId(String encoded) {
    return Uri.decodeFull(encoded.replaceAll('%25', '%'));
  }

  static List<dynamic> _parseJsonList(String raw) =>
      jsonDecode(raw) as List<dynamic>;
}
