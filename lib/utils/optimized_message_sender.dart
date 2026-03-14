// lib/utils/optimized_message_sender.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ONYX/models/chat_message.dart';
import 'package:ONYX/utils/message_cache.dart';

class MessageListNotifier extends ChangeNotifier {
  final Map<String, List<ChatMessage>> _chats = {};
  final MessageCache _cache = MessageCache();

  List<ChatMessage> getMessages(String chatId) {
    return _cache.getMessages(chatId);
  }

  void addMessageOptimized(String chatId, ChatMessage message) {
    
    _cache.addMessage(chatId, message);
    
    if (!_chats.containsKey(chatId)) {
      _chats[chatId] = [];
    }
    _chats[chatId]!.add(message);

    notifyListeners();
  }

  void addMessagesOptimized(String chatId, List<ChatMessage> messages) {
    _cache.setMessages(chatId, messages);
    _chats[chatId] = messages;
    notifyListeners();
  }

  void clearChat(String chatId) {
    _cache.clearChat(chatId);
    _chats.remove(chatId);
    notifyListeners();
  }

  void clear() {
    _cache.clear();
    _chats.clear();
    notifyListeners();
  }
}

final messageListNotifier = MessageListNotifier();