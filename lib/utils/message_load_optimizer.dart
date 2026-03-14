// lib/utils/message_load_optimizer.dart
import 'dart:async';

class MessageLoadOptimizer {
  static final MessageLoadOptimizer _instance = MessageLoadOptimizer._internal();

  static const _DefaultConfig defaultConfig = _DefaultConfig(
    
    initialMessageCount: 30, 
    cacheBufferSize: 50, 
    
    enableLazyLoading: true,
    lazyLoadThreshold: 10, 
    batchSizeForLazyLoad: 20, 
    
    preloadMediaThreshold: 5, 
    enableMediaPreload: true,
    
    maxMessagesInMemory: 200, 
    enableMessageCache: true,
    messageCacheTtl: Duration(minutes: 5),
    
    batchApiRequests: true,
    apiBatchSize: 30,
    apiBatchDelayMs: 100,
  );

  factory MessageLoadOptimizer() => _instance;

  MessageLoadOptimizer._internal();

  static List<int> calculateVisibleRange(
    int totalMessages,
    int scrollOffset,
    int viewportHeight,
    int messageHeight,
  ) {
    
    final messagesPerViewport = (viewportHeight / messageHeight).ceil();
    final startIndex = (scrollOffset / messageHeight).floor();
    final endIndex = (startIndex + messagesPerViewport).clamp(0, totalMessages - 1);

    final buffer = defaultConfig.cacheBufferSize;
    final rangeStart = (startIndex - buffer).clamp(0, totalMessages - 1);
    final rangeEnd = (endIndex + buffer).clamp(0, totalMessages - 1);

    return List<int>.generate(rangeEnd - rangeStart + 1, (i) => rangeStart + i);
  }

  static bool shouldLoadOlderMessages(
    int visibleStartIndex,
    int totalMessages,
  ) {
    final threshold = defaultConfig.lazyLoadThreshold;
    return visibleStartIndex < threshold && totalMessages > 0;
  }

  static List<int> getMediaPreloadIndices(
    List<int> visibleIndices,
    List<bool> hasMediaInMessage,
  ) {
    final threshold = defaultConfig.preloadMediaThreshold;
    final mediaMsgs = <int>[];

    for (final idx in visibleIndices) {
      if (idx < hasMediaInMessage.length && hasMediaInMessage[idx]) {
        mediaMsgs.add(idx);
        if (mediaMsgs.length >= threshold) break;
      }
    }

    return mediaMsgs;
  }
}

class _DefaultConfig {
  
  final int initialMessageCount;
  final int cacheBufferSize;

  final bool enableLazyLoading;
  final int lazyLoadThreshold;
  final int batchSizeForLazyLoad;

  final int preloadMediaThreshold;
  final bool enableMediaPreload;

  final int maxMessagesInMemory;
  final bool enableMessageCache;
  final Duration messageCacheTtl;

  final bool batchApiRequests;
  final int apiBatchSize;
  final int apiBatchDelayMs;

  const _DefaultConfig({
    required this.initialMessageCount,
    required this.cacheBufferSize,
    required this.enableLazyLoading,
    required this.lazyLoadThreshold,
    required this.batchSizeForLazyLoad,
    required this.preloadMediaThreshold,
    required this.enableMediaPreload,
    required this.maxMessagesInMemory,
    required this.enableMessageCache,
    required this.messageCacheTtl,
    required this.batchApiRequests,
    required this.apiBatchSize,
    required this.apiBatchDelayMs,
  });
}

class MessageCacheManager {
  static final MessageCacheManager _instance = MessageCacheManager._internal();

  final Map<String, _MessageCacheEntry> _cache = {};
  Timer? _cleanupTimer;

  factory MessageCacheManager() => _instance;

  MessageCacheManager._internal();

  List<dynamic>? getMessages(String chatKey) {
    final entry = _cache[chatKey];
    if (entry != null && !entry.isExpired) {
      return entry.messages;
    }
    return null;
  }

  void cacheMessages(String chatKey, List<dynamic> messages) {
    _cache[chatKey] = _MessageCacheEntry(
      messages: messages,
      timestamp: DateTime.now(),
    );

    _startCleanupTimer();
  }

  void invalidate(String chatKey) {
    _cache.remove(chatKey);
  }

  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer(
      const Duration(minutes: 1),
      _cleanup,
    );
  }

  void _cleanup() {
    _cache.removeWhere((_, entry) => entry.isExpired);
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _cache.clear();
  }
}

class _MessageCacheEntry {
  final List<dynamic> messages;
  final DateTime timestamp;

  _MessageCacheEntry({
    required this.messages,
    required this.timestamp,
  });

  bool get isExpired {
    final ttl = MessageLoadOptimizer.defaultConfig.messageCacheTtl;
    return DateTime.now().difference(timestamp) > ttl;
  }
}