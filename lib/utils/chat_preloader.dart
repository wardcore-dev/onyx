// lib/utils/chat_preloader.dart
import 'package:flutter/material.dart';
import '../services/message_sync_service.dart';
import '../services/chat_load_optimizer.dart';

class ChatPreloader {
  static final _prefetcher = ChatPrefetcher();

  static Future<void> preloadVisibleChats({
    required String myUsername,
    required List<String> visibleChatUsernames,
  }) async {
    
    await MessageSyncService.loadMultipleChats(
      myUsername,
      visibleChatUsernames,
    );
  }

  static void prefetchChat({
    required String myUsername,
    required String otherUsername,
  }) {
    _prefetcher.addUserForPrefetch(myUsername, otherUsername);
  }

  static void onScroll({
    required String myUsername,
    required List<String> newVisibleChats,
  }) {
    for (final username in newVisibleChats) {
      prefetchChat(
        myUsername: myUsername,
        otherUsername: username,
      );
    }
  }

  static void dispose() {
    _prefetcher.dispose();
  }
}