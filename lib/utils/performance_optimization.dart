// lib/utils/performance_optimization.dart
class PerformanceOptimization {
  
  static const Map<String, dynamic> renderingConfig = {
    
    'listViewCacheExtent': 250, 
    'itemExtentOverride': true, 
    'listViewPreloadPages': 1,
    'chatListCacheExtent': 300, 
    'messageListCacheExtent': 250, 
    
    'imageCacheSizeInMb': 80, 
    'imageCompressionQuality': 55, 
    'imageResizeOnDownload': true,
    'useAdaptiveBlur': false, 
    
    'animationDuration': 100, 
    'reduceAnimationDuration': 0.3, 
    'useGPUAcceleration': true,
    'disableListAnimations': true, 
    
    'disableBackdropFilter': true, 
    'shadowQuality': 'disabled', 
    'reduceElevation': true,
    'disableMaterialSurface': true,
    
    'useRepaintBoundary': true,
    'repaintBoundaryThreshold': 2, 
    
    'limitFrameRate': 60, 
    
    'chatListOptimization': true,
    'batchUserProfileLoading': true, 
    'maxConcurrentProfileRequests': 4,
    'deduplicateRequests': true,
    
    'messageLoadingOptimization': true,
    'lazyLoadMessages': true,
    'preloadMessageThreshold': 10,
  };

  static const Map<String, dynamic> lowEndConfig = {
    'listViewCacheExtent': 150, 
    'chatListCacheExtent': 200,
    'messageListCacheExtent': 150,
    'itemExtentOverride': true,
    'imageCacheSizeInMb': 50, 
    'imageCompressionQuality': 40, 
    'animationDuration': 75, 
    'disableListAnimations': true,
    'disableBackdropFilter': true,
    'shadowQuality': 'disabled', 
    'limitFrameRate': 60,
    'batchUserProfileLoading': true,
    'maxConcurrentProfileRequests': 2,
    'lazyLoadMessages': true,
    'preloadMessageThreshold': 5,
  };

  static const Map<String, dynamic> telegramLikeConfig = {
    
    'listViewCacheExtent': 350,
    'chatListCacheExtent': 400, 
    'messageListCacheExtent': 350,
    
    'itemExtentOverride': true, 
    'useRepaintBoundary': true,
    'repaintBoundaryThreshold': 3,
    
    'imageCacheSizeInMb': 120, 
    'imageCompressionQuality': 60,
    'imageResizeOnDownload': true,
    'imagePrecachingEnabled': true,
    
    'animationDuration': 50, 
    'reduceAnimationDuration': 0.15,
    'disableListAnimations': true,
    'disableBackdropFilter': true,
    'shadowQuality': 'disabled',
    'disableMaterialSurface': true,
    'reduceElevation': true,
    
    'chatListOptimization': true,
    'batchUserProfileLoading': true,
    'maxConcurrentProfileRequests': 8,
    'deduplicateRequests': true,
    'enableSyncOptimizer': true,
    'enableMessageCacheManager': true,
    
    'messageLoadingOptimization': true,
    'lazyLoadMessages': true,
    'preloadMessageThreshold': 20,
    'virtualMessageListSize': 100,
    
    'enableWebSocketOptimizer': true,
    'webSocketMessageBatchSize': 50,
    'webSocketBatchDelayMs': 50,
    
    'limitFrameRate': 60,
    'preferredRefreshRate': 60,
  };

  static Map<String, dynamic> getOptimalConfig({
    bool isLowEndDevice = false,
    bool useTelegramOptimization = true,
  }) {
    if (useTelegramOptimization) return telegramLikeConfig;
    return isLowEndDevice ? lowEndConfig : renderingConfig;
  }
}