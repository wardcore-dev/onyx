// lib/services/chat_load_optimizer.dart
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../globals.dart';
import '../managers/account_manager.dart';
import '../models/chat_message.dart';
import '../utils/sync_optimizer.dart';

class ChatLoadOptimizer {
  static final ChatLoadOptimizer _instance = ChatLoadOptimizer._internal();

  final Map<String, _ChatCache> _chatCache = {};
  final Map<String, _LoadingState> _loadingStates = {};
  
  final Map<String, Future<List<ChatMessage>>> _inFlightLoads = {};

  factory ChatLoadOptimizer() => _instance;

  ChatLoadOptimizer._internal();

  Future<List<ChatMessage>> loadChatMessages(
    String myUsername,
    String otherUsername, {
    int? limit,
    int? offset,
  }) async {
    final chatKey = _getChatKey(myUsername, otherUsername);
    final cacheKey = '$chatKey:$limit:$offset';

    if (_chatCache.containsKey(chatKey) && !_chatCache[chatKey]!.isExpired) {
      return _chatCache[chatKey]!.messages;
    }

    if (_inFlightLoads.containsKey(cacheKey)) {
      return await _inFlightLoads[cacheKey]!;
    }

    final future = _performChatLoad(myUsername, otherUsername, limit, offset);
    _inFlightLoads[cacheKey] = future;

    try {
      final messages = await future;
      
      _chatCache[chatKey] = _ChatCache(
        messages: messages,
        timestamp: DateTime.now(),
      );

      return messages;
    } finally {
      _inFlightLoads.remove(cacheKey);
    }
  }

  Future<Map<String, List<ChatMessage>>> loadMultipleChats(
    String myUsername,
    List<String> otherUsernames,
  ) async {
    final futures = <String, Future<List<ChatMessage>>>{};

    for (final username in otherUsernames) {
      futures[username] = loadChatMessages(myUsername, username, limit: 50);
    }

    final results = <String, List<ChatMessage>>{};
    
    await Future.wait(
      futures.entries.map((entry) async {
        results[entry.key] = await entry.value;
      }),
    );

    return results;
  }

  Future<void> preloadChat(
    String myUsername,
    String otherUsername,
  ) async {
    final chatKey = _getChatKey(myUsername, otherUsername);
    
    if (_chatCache.containsKey(chatKey) && !_chatCache[chatKey]!.isExpired) {
      return;
    }

    try {
      await loadChatMessages(myUsername, otherUsername, limit: 50);
    } catch (e) {
      debugPrint('[err] $e');
    }
  }

  Future<List<ChatMessage>> loadOlderMessages(
    String myUsername,
    String otherUsername,
    int lastMessageId,
  ) async {
    final token = await AccountManager.getToken(myUsername);
    if (token == null) return [];

    final url = '$serverBase/messages/before/$lastMessageId?limit=30';
    final headers = {'authorization': 'Bearer $token'};

    try {
      final response = await SyncOptimizer.deduplicatedGet(url, headers: headers);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final messages = (data['messages'] as List)
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList();
        
        return messages;
      }
    } catch (e) { debugPrint('[err] $e'); }

    return [];
  }

  Future<List<ChatMessage>> _performChatLoad(
    String myUsername,
    String otherUsername,
    int? limit,
    int? offset,
  ) async {
    final token = await AccountManager.getToken(myUsername);
    if (token == null) return [];

    final actualLimit = limit ?? 50;
    final actualOffset = offset ?? 0;

    final url = '$serverBase/messages/chat/$otherUsername'
        '?limit=$actualLimit&offset=$actualOffset';
    
    final headers = {'authorization': 'Bearer $token'};

    try {
      
      final response = await SyncOptimizer.deduplicatedGet(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final messagesList = data['messages'] as List? ?? [];
        
        return messagesList
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList();
      }
    } catch (e) { debugPrint('[err] $e'); }

    return [];
  }

  void invalidateCache(String myUsername, String otherUsername) {
    final chatKey = _getChatKey(myUsername, otherUsername);
    _chatCache.remove(chatKey);
  }

  void cleanupExpiredCache() {
    _chatCache.removeWhere((_, cache) => cache.isExpired);
  }

  bool isLoading(String myUsername, String otherUsername) {
    final chatKey = _getChatKey(myUsername, otherUsername);
    return _loadingStates[chatKey]?.isLoading ?? false;
  }

  static String _getChatKey(String myUsername, String otherUsername) {
    final ids = [myUsername, otherUsername]..sort();
    return ids.join(':');
  }

  Map<String, dynamic> getCacheStats() {
    return {
      'cachedChats': _chatCache.length,
      'inFlightLoads': _inFlightLoads.length,
      'loadingStates': _loadingStates.length,
    };
  }
}

class _ChatCache {
  final List<ChatMessage> messages;
  final DateTime timestamp;
  
  static const int _ttlMs = 5000; 

  _ChatCache({
    required this.messages,
    required this.timestamp,
  });

  bool get isExpired {
    final now = DateTime.now();
    final age = now.difference(timestamp).inMilliseconds;
    return age > _ttlMs;
  }
}

class _LoadingState {
  bool isLoading;
  DateTime? startTime;

  _LoadingState({required this.isLoading});

  bool get isTimedOut {
    if (!isLoading || startTime == null) return false;
    return DateTime.now().difference(startTime!).inSeconds > 30;
  }
}

class ChatPrefetcher {
  static final ChatPrefetcher _instance = ChatPrefetcher._internal();
  
  final ChatLoadOptimizer _optimizer = ChatLoadOptimizer();
  Timer? _prefetchTimer;
  final List<String> _usersToPreload = [];

  factory ChatPrefetcher() => _instance;

  ChatPrefetcher._internal();

  void addUserForPrefetch(String myUsername, String otherUsername) {
    final key = '${ChatLoadOptimizer._getChatKey(myUsername, otherUsername)}:$myUsername';
    if (!_usersToPreload.contains(key)) {
      _usersToPreload.add(key);
    }

    _startPrefetchTimer(myUsername);
  }

  void _startPrefetchTimer(String myUsername) {
    _prefetchTimer?.cancel();
    
    _prefetchTimer = Timer(
      const Duration(milliseconds: 500),
      () => _doPrefetch(myUsername),
    );
  }

  Future<void> _doPrefetch(String myUsername) async {
    final toPreload = List<String>.from(_usersToPreload);
    _usersToPreload.clear();

    for (final key in toPreload) {
      final parts = key.split(':');
      if (parts.length >= 2) {
        final otherUsername = parts[0].contains(':') 
            ? parts[0].split(':').last 
            : parts[0];
        try {
          await _optimizer.preloadChat(myUsername, otherUsername);
        } catch (e) { debugPrint('[err] $e'); }
      }
    }
  }

  void dispose() {
    _prefetchTimer?.cancel();
  }
}