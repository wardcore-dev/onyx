// lib/managers/trash_manager.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../globals.dart' show serverBase;
import '../models/chat_message.dart';
import '../utils/onyx_base_dir.dart';

enum TrashedChatType { dm, group, favorite }

class TrashedChat {
  final String id;
  final String chatId;
  final String displayName;
  final TrashedChatType type;
  final List<ChatMessage> messages;
  final DateTime deletedAt;

  TrashedChat({
    required this.id,
    required this.chatId,
    required this.displayName,
    required this.type,
    required this.messages,
    required this.deletedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'chatId': chatId,
    'displayName': displayName,
    'type': type.name,
    'messages': messages.map((m) => m.toJson()).toList(),
    'deletedAt': deletedAt.toIso8601String(),
  };

  static TrashedChat fromJson(Map<String, dynamic> j) => TrashedChat(
    id: j['id']?.toString() ?? '',
    chatId: j['chatId']?.toString() ?? '',
    displayName: j['displayName']?.toString() ?? '',
    type: TrashedChatType.values.firstWhere(
      (t) => t.name == j['type'],
      orElse: () => TrashedChatType.dm,
    ),
    messages: (j['messages'] as List? ?? []).map((m) {
      try { return ChatMessage.fromJson(m as Map<String, dynamic>); }
      catch (_) { return null; }
    }).whereType<ChatMessage>().toList(),
    deletedAt: DateTime.tryParse(j['deletedAt']?.toString() ?? '') ?? DateTime.now(),
  );
}

class TrashedMessage {
  final String id;
  final String chatId;
  final String chatDisplayName;
  final ChatMessage message;
  final DateTime deletedAt;

  TrashedMessage({
    required this.id,
    required this.chatId,
    required this.chatDisplayName,
    required this.message,
    required this.deletedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'chatId': chatId,
    'chatDisplayName': chatDisplayName,
    'message': message.toJson(),
    'deletedAt': deletedAt.toIso8601String(),
  };

  static TrashedMessage fromJson(Map<String, dynamic> j) => TrashedMessage(
    id: j['id']?.toString() ?? '',
    chatId: j['chatId']?.toString() ?? '',
    chatDisplayName: j['chatDisplayName']?.toString() ?? '',
    message: ChatMessage.fromJson(j['message'] as Map<String, dynamic>? ?? {}),
    deletedAt: DateTime.tryParse(j['deletedAt']?.toString() ?? '') ?? DateTime.now(),
  );
}

class TrashManager {
  static final instance = TrashManager._();
  TrashManager._();

  static const _cleanDaysKey = 'trash_auto_clean_days';
  // If the trash JSON file on disk exceeds this size, it is wiped before
  // loading to prevent OOM crashes. 100 MB is a safe ceiling for mobile.
  static const _maxSizeMb = 100;

  // 0 = never, otherwise number of days before items are auto-deleted.
  // Default: 30 days.
  static final autoCleanDays = ValueNotifier<int>(30);

  String? _username;
  final _chats = <TrashedChat>[];
  final _messages = <TrashedMessage>[];

  final chatsNotifier = ValueNotifier<int>(0);
  final messagesNotifier = ValueNotifier<int>(0);

  List<TrashedChat> get deletedChats => List.unmodifiable(_chats);
  List<TrashedMessage> get deletedMessages => List.unmodifiable(_messages);

  // ── Settings ─────────────────────────────────────────────────────────────────

  static Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      autoCleanDays.value = prefs.getInt(_cleanDaysKey) ?? 30;
    } catch (e) {
      debugPrint('[TrashManager] loadSettings failed: $e');
    }
  }

  static Future<void> setAutoCleanDays(int days) async {
    autoCleanDays.value = days;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_cleanDaysKey, days);
    } catch (e) {
      debugPrint('[TrashManager] setAutoCleanDays failed: $e');
    }
    // Apply immediately to loaded data.
    instance._applyAutoClean();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────────

  Future<void> load(String username) async {
    _username = username;
    _chats.clear();
    _messages.clear();
    try {
      final file = await _trashFile();
      if (!await file.exists()) return;
      final fileSize = await file.length();
      if (fileSize > _maxSizeMb * 1024 * 1024) {
        debugPrint('[TrashManager] trash file ${fileSize ~/ (1024 * 1024)} MB > $_maxSizeMb MB limit – auto-clearing');
        await file.delete();
        return;
      }
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      for (final j in (json['chats'] as List? ?? [])) {
        try { _chats.add(TrashedChat.fromJson(j as Map<String, dynamic>)); } catch (_) {}
      }
      for (final j in (json['messages'] as List? ?? [])) {
        try { _messages.add(TrashedMessage.fromJson(j as Map<String, dynamic>)); } catch (_) {}
      }
      _applyAutoClean();
    } catch (e) {
      debugPrint('[TrashManager] load failed: $e');
    } finally {
      chatsNotifier.value++;
      messagesNotifier.value++;
    }
  }

  void unload() {
    _username = null;
    _chats.clear();
    _messages.clear();
    chatsNotifier.value++;
    messagesNotifier.value++;
  }

  // ── Mutations ─────────────────────────────────────────────────────────────────

  void addDeletedChat(TrashedChat item) {
    _chats.insert(0, item);
    chatsNotifier.value++;
    _save();
  }

  void addDeletedMessage(TrashedMessage item) {
    _messages.insert(0, item);
    messagesNotifier.value++;
    _save();
  }

  void permanentlyDeleteChat(String id) {
    _chats.removeWhere((c) => c.id == id);
    chatsNotifier.value++;
    _save();
  }

  void permanentlyDeleteMessage(String id) {
    _messages.removeWhere((m) => m.id == id);
    messagesNotifier.value++;
    _save();
  }

  void clearAll() {
    _chats.clear();
    _messages.clear();
    chatsNotifier.value++;
    messagesNotifier.value++;
    _save();
  }

  // ── Auto-clean ────────────────────────────────────────────────────────────────

  void _applyAutoClean() {
    final days = autoCleanDays.value;
    if (days <= 0) return;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final beforeChats = _chats.length;
    final beforeMsgs = _messages.length;
    _chats.removeWhere((c) => c.deletedAt.isBefore(cutoff));
    _messages.removeWhere((m) => m.deletedAt.isBefore(cutoff));
    final changed =
        _chats.length != beforeChats || _messages.length != beforeMsgs;
    if (changed) _save();
  }

  // ── Persistence ───────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_username == null) return;
    try {
      final file = await _trashFile();
      await file.writeAsString(jsonEncode({
        'chats': _chats.map((c) => c.toJson()).toList(),
        'messages': _messages.map((m) => m.toJson()).toList(),
      }));
    } catch (e) {
      debugPrint('[TrashManager] save failed: $e');
    }
  }

  Future<File> _trashFile() async {
    final base = await getOnyxSupportDirectory();
    return File('${base.path}/trash_${_serverHost()}_$_username.json');
  }

  static String _serverHost() {
    try {
      final uri = Uri.parse(serverBase);
      return uri.host.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    } catch (_) {
      return serverBase.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    }
  }
}
