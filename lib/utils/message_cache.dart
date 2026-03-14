// lib/utils/message_cache.dart
import 'dart:collection';
import 'package:ONYX/models/chat_message.dart';

class MessageCache {
  static final MessageCache _instance = MessageCache._internal();

  factory MessageCache() {
    return _instance;
  }

  MessageCache._internal();

  final Map<String, List<ChatMessage>> _messageCache = {};

  final Map<String, String> _decryptedCache = {};

  final int _maxCacheSize = 5000; 
  int _totalMessages = 0;

  List<ChatMessage> getMessages(String chatId) {
    return _messageCache[chatId] ?? [];
  }

  void setMessages(String chatId, List<ChatMessage> messages) {
    _messageCache[chatId] = messages;
    _updateTotalSize();
  }

  void addMessage(String chatId, ChatMessage message) {
    if (!_messageCache.containsKey(chatId)) {
      _messageCache[chatId] = [];
    }
    _messageCache[chatId]!.add(message);
    _totalMessages++;
    _evictIfNeeded();
  }

  void prependMessage(String chatId, ChatMessage message) {
    if (!_messageCache.containsKey(chatId)) {
      _messageCache[chatId] = [];
    }
    _messageCache[chatId]!.insert(0, message);
    _totalMessages++;
    _evictIfNeeded();
  }

  void clearChat(String chatId) {
    final removed = _messageCache.remove(chatId);
    if (removed != null) {
      _totalMessages -= removed.length;
    }
  }

  void clear() {
    _messageCache.clear();
    _decryptedCache.clear();
    _totalMessages = 0;
  }

  String? getDecrypted(String messageId) => _decryptedCache[messageId];

  void setDecrypted(String messageId, String plaintext) {
    _decryptedCache[messageId] = plaintext;
  }

  void _evictIfNeeded() {
    if (_totalMessages > _maxCacheSize) {
      
      if (_messageCache.isNotEmpty) {
        final firstKey = _messageCache.keys.first;
        final removed = _messageCache.remove(firstKey);
        _totalMessages -= removed?.length ?? 0;
      }
    }
  }

  void _updateTotalSize() {
    _totalMessages = _messageCache.values.fold(0, (sum, list) => sum + list.length);
  }

  Map<String, dynamic> getStats() {
    return {
      'totalMessages': _totalMessages,
      'chatsCount': _messageCache.length,
      'decryptedCacheSize': _decryptedCache.length,
      'memoryUsage': _totalMessages * 200, 
    };
  }
}