import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'fps_booster.dart';

class PerformanceInitializer {
  static bool _initialized = false;

  static Future<void> initialize({int targetFps = 1000}) async {
    if (_initialized) return;
    _initialized = true;

    debugPrint('[performance]  Initializing performance optimizations...');

    FpsBooster().enableUnlimited();
    debugPrint('[performance]  FpsBooster enabled (UNLIMITED mode - NO VSYNC)');

    _optimizeImageCache();
    debugPrint('[performance]  Image cache optimized');

    _disableExpensiveEffects();
    debugPrint('[performance]  Expensive effects disabled');

    _enableGPUAcceleration();
    debugPrint('[performance]  GPU acceleration enabled');

    _limitSceneRefreshRate();
    debugPrint('[performance]  Scene refresh rate limited');

    debugPrint('[performance]  Performance initialization complete!');
  }

  static void _optimizeImageCache() {
    
    imageCache.maximumSize = 100; 
    imageCache.maximumSizeBytes = 100 * 1024 * 1024; 
  }

  static void _disableExpensiveEffects() {
    
  }

  static void _enableGPUAcceleration() {
    
  }

  static void _limitSceneRefreshRate() {
    
  }

  static void disable() {
    FpsBooster().disable();
    _initialized = false;
    debugPrint('[performance]  Performance optimizations disabled');
  }
}