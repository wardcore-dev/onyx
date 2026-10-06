// lib/utils/app_paths.dart
//
// Single-initialisation path cache.
// Resolves platform directories exactly once via path_provider, then exposes
// them as synchronous getters so every widget/service can read paths without
// a platform-channel round-trip.
//
// Call AppPaths.ensureInit() early (e.g. RootScreen.initState or main()).
// All repeated calls return the already-resolved Future immediately.
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../utils/onyx_base_dir.dart';
import '../utils/image_size_cache.dart';
import '../utils/blurhash_cache.dart';

class AppPaths {
  static String? _docs;
  static String? _support;
  static String? _temp;
  static Future<void>? _init;

  /// Resolves platform directories and pre-creates image_cache/.
  /// Safe to call many times — only the first call does real work.
  static Future<void> ensureInit() => _init ??= _doInit();

  static Future<void> _doInit() async {
    final results = await Future.wait([
      getOnyxDocumentsDirectory(),
      getOnyxSupportDirectory(),
      getTemporaryDirectory(),
    ]);
    _docs = results[0].path;
    _support = results[1].path;
    _temp = results[2].path;
    // Pre-create all frequently used directories so individual downloads
    // never need to call create() or platform channels.
    await Future.wait([
      Directory('$_support/image_cache').create(recursive: true),
      Directory('$_temp/onyx_display/image').create(recursive: true),
      Directory('$_temp/onyx_display/voice').create(recursive: true),
      Directory('$_temp/onyx_display/video').create(recursive: true),
      Directory('$_temp/onyx_display/file').create(recursive: true),
    ]);
    // Load persisted aspect-ratio cache so headers aren't re-read after restart.
    await ImageSizeCache().loadFromDisk('$_support/image_size_cache.json');
    // Load persisted receiver-side BlurHash cache so old images (sent without
    // an embedded hash) still show a blurred preview while loading from cache.
    await BlurHashCache.instance.loadFromDisk('$_support/blurhash_cache.json');
  }

  /// True after the first ensureInit() has resolved.
  static bool get isReady => _docs != null;

  static String get docs => _docs!;
  static String get support => _support!;
  static String get temp => _temp!;
  static String get imageCache => '$_support/image_cache';
  static String get favMedia => '$_docs/fav_media';
  static String get lanMedia => '$_docs/lan_media';
  static String get onionMedia => '$_docs/onion_media';

  // Display dirs — temp, cleaned by OS; always check .enc fallback.
  static String get imageDisplay => '$_temp/onyx_display/image';
  static String get voiceDisplay => '$_temp/onyx_display/voice';
  static String get videoDisplay => '$_temp/onyx_display/video';
  static String get fileDisplay  => '$_temp/onyx_display/file';
}
