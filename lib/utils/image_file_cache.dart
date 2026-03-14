// lib/utils/image_file_cache.dart
import 'dart:io';

typedef ImageFileCacheEntry = ({File file, int size, double? aspectRatio});

final Map<String, ImageFileCacheEntry> imageFileCache = {};