// lib/utils/lazy_image_cache.dart
import 'dart:io';
import 'package:flutter/material.dart';

class LazyImageCache {
  static final LazyImageCache _instance = LazyImageCache._internal();
  final Map<String, ImageProvider> _cache = {};
  final int _maxCacheSize;

  LazyImageCache._internal({int maxCacheSize = 50}) : _maxCacheSize = maxCacheSize;

  factory LazyImageCache() {
    return _instance;
  }

  ImageProvider getOrCreate(String key, ImageProvider Function() provider) {
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }

    final img = provider();
    _cache[key] = img;
    return img;
  }

  void clear() {
    _cache.clear();
    imageCache.clearLiveImages();
  }

  void remove(String key) {
    final provider = _cache.remove(key);
    if (provider != null) {
      try {
        
        provider.evict();
      } catch (e) { debugPrint('[err] $e'); }
    }
  }

  int get cacheSize => _cache.length;
}

class OptimizedImageFile extends StatelessWidget {
  final String filePath;
  final BoxFit fit;
  final double width;
  final double height;

  const OptimizedImageFile({
    Key? key,
    required this.filePath,
    this.fit = BoxFit.cover,
    this.width = double.infinity,
    this.height = double.infinity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cache = LazyImageCache();
    final provider = cache.getOrCreate(
      filePath,
      () => FileImage(File(filePath)),
    );

    return Image(
      image: provider,
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
    );
  }
}