// lib/utils/performance_config.dart
class PerformanceConfig {
  
  static const bool disableBackdropFilter = true;
  static const bool disableComplexShaders = true;

  static const int cacheExtent = 100; 
  static const int itemExtent = 72; 

  static const int imageCacheSize = 100 * 1024 * 1024; 
  static const int imageMemoryCacheCount = 100; 
  static const double maxImageResolutionScale = 1.5; 
  static const int imageCompressionQuality = 60; 

  static const int defaultAnimationDuration = 100; 
  static const int reducedAnimationDuration = 50; 
  static const bool useReducedAnimations = true; 

  static const int targetFrameRate = 60; 

  static const bool enablePerformanceOptimizations = true;
  static const bool useRepaintBoundary = true; 
}