// lib/utils/image_size_cache.dart
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/foundation.dart';

class ImageSizeCache {
  static final ImageSizeCache _instance = ImageSizeCache._internal();
  factory ImageSizeCache() => _instance;
  ImageSizeCache._internal();

  final Map<String, double> _cache = {};

  static const int _maxCacheSize = 500;

  double? getCachedAspectRatio(String filePath) {
    return _cache[filePath];
  }

  void cacheAspectRatio(String filePath, double aspectRatio) {
    
    if (_cache.length >= _maxCacheSize) {
      
      final keysToRemove = _cache.keys.take(_cache.length - _maxCacheSize + 100).toList();
      for (final key in keysToRemove) {
        _cache.remove(key);
      }
    }
    _cache[filePath] = aspectRatio;
  }

  Future<double> getOrComputeAspectRatio(File file) async {
    final path = file.path;

    final cached = getCachedAspectRatio(path);
    if (cached != null) {
      return cached;
    }

    double aspectRatio = 4 / 3; 
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      if (image.width > 0 && image.height > 0) {
        aspectRatio = image.width / image.height;
      }
      image.dispose();
      codec.dispose();
    } catch (e) {
      debugPrint('[ImageSizeCache] Failed to compute aspect ratio: $e');
    }

    cacheAspectRatio(path, aspectRatio);
    return aspectRatio;
  }

  void clear() {
    _cache.clear();
  }
}