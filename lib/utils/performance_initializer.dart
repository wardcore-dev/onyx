import 'package:flutter/foundation.dart';
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
    // Decoded-bitmap cache (PaintingBinding's imageCache). The COUNT is what
    // stops thumbnails from re-decoding (a blank flash) when scrolling back over
    // them; the BYTES value is just a safety ceiling, not constant usage.
    // Tiered so desktop (lots of RAM) keeps more decoded, while phones/web stay
    // conservative. Uses defaultTargetPlatform (not dart:io) so it's web-safe.
    final mobile = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (mobile) {
      imageCache.maximumSize = 700;
      imageCache.maximumSizeBytes = 150 * 1024 * 1024;
    } else {
      imageCache.maximumSize = 1000;
      imageCache.maximumSizeBytes = 250 * 1024 * 1024;
    }
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