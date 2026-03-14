// lib/services/message_sync_service.dart
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../globals.dart';
import '../managers/account_manager.dart';
import '../utils/sync_optimizer.dart';
import 'chat_load_optimizer.dart';

class MessageSyncService {
  static const int _maxMessages = 5;

  static Future<SyncResult> checkForNewMessages() async {
    final username = await AccountManager.getCurrentAccount();
    if (username == null) return SyncResult.noMessages();

    final token = await AccountManager.getToken(username);
    if (token == null) return SyncResult.noMessages();

    try {
      final url = '$serverBase/messages/unread/summary';
      final headers = {'authorization': 'Bearer $token'};
      
      final res = await SyncOptimizer.deduplicatedGet(url, headers: headers);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final messages = data['messages'] as List;
        if (messages.isNotEmpty) {
          final first = messages[0] as Map<String, dynamic>;
          return SyncResult(
            hasNewMessages: true,
            sender: first['sender'] as String,
            preview: first['preview'] as String,
          );
        }
      }
    } catch (e) {
      debugPrint('[err] $e');
    }

    return SyncResult.noMessages();
  }

  static Future<List<dynamic>> loadChatMessages(
    String myUsername,
    String otherUsername, {
    int? limit,
    int? offset,
  }) async {
    final optimizer = ChatLoadOptimizer();
    try {
      final messages = await optimizer.loadChatMessages(
        myUsername,
        otherUsername,
        limit: limit,
        offset: offset,
      );
      return messages;
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, List<dynamic>>> loadMultipleChats(
    String myUsername,
    List<String> otherUsernames,
  ) async {
    final optimizer = ChatLoadOptimizer();
    try {
      final chats = await optimizer.loadMultipleChats(myUsername, otherUsernames);
      return chats.cast<String, List<dynamic>>();
    } catch (e) {
      return {};
    }
  }

  static Future<List<dynamic>> loadOlderMessages(
    String myUsername,
    String otherUsername,
    int lastMessageId,
  ) async {
    final optimizer = ChatLoadOptimizer();
    try {
      final messages = await optimizer.loadOlderMessages(
        myUsername,
        otherUsername,
        lastMessageId,
      );
      return messages;
    } catch (e) {
      return [];
    }
  }

  static Future<void> prefetchChat(
    String myUsername,
    String otherUsername,
  ) async {
    final optimizer = ChatLoadOptimizer();
    try {
      await optimizer.preloadChat(myUsername, otherUsername);
    } catch (e) { debugPrint('[err] $e'); }
  }
}

class SyncResult {
  final bool hasNewMessages;
  final String? sender;
  final String? preview;

  SyncResult({
    required this.hasNewMessages,
    this.sender,
    this.preview,
  });

  factory SyncResult.noMessages() => SyncResult(hasNewMessages: false);
}