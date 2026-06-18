// lib/utils/blurhash_cache.dart
//
// Receiver-side BlurHash cache keyed by message filename.
//
// Messages sent before the BlurHash feature (or that failed to encode one)
// carry no blur data, so the recipient has nothing to show while such an image
// loads from cache → a blank placeholder. To fix that we compute a BlurHash the
// first time we successfully decode an image and remember it here, persisted to
// disk. On every later display — including loads straight from the on-disk
// cache or after an app restart — the blurred preview is available instantly.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'blurhash_util.dart';

class BlurHashCache {
  BlurHashCache._();
  static final BlurHashCache instance = BlurHashCache._();

  // filename → blurhash. Aspect ratio lives in ImageSizeCache already.
  final Map<String, String> _cache = {};
  // Filenames already queued/processed (avoid duplicate work).
  final Set<String> _seen = {};

  // Bounded encode queue — encoding decodes the full image in an isolate, so
  // we run exactly ONE at a time and never touch the visible-image pipeline.
  static const int _maxConcurrent = 1;
  // Skip large originals: decoding a multi-MB photo just for a ~30 char hash is
  // not worth the CPU/IO. Big images load fast enough without a blur preview.
  static const int _maxBytes = 2 * 1024 * 1024;
  int _running = 0;
  final List<({String filename, File file})> _queue = [];

  String? _persistPath;
  Timer? _saveTimer;

  /// Returns the cached hash for [filename], or null if unknown.
  String? get(String filename) => _cache[filename];

  /// Computes and stores a BlurHash from raw [bytes] (e.g. a captured video
  /// poster frame) if we don't already have one. Fire-and-forget; never throws.
  void ensureForBytes(String filename, Uint8List bytes) {
    if (filename.isEmpty) return;
    if (_cache.containsKey(filename) || _seen.contains(filename)) return;
    _seen.add(filename);
    () async {
      try {
        final blur = await computeBlurHash(bytes);
        if (blur != null) {
          _cache[filename] = blur.hash;
          _scheduleSave();
        }
      } catch (_) {}
    }();
  }

  /// Loads the persisted cache. Called once from AppPaths.ensureInit().
  Future<void> loadFromDisk(String path) async {
    _persistPath = path;
    try {
      final file = File(path);
      if (!file.existsSync()) return;
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      map.forEach((k, v) {
        if (v is String && v.isNotEmpty) _cache[k] = v;
      });
    } catch (_) {}
  }

  /// Computes and stores a BlurHash for [filename] from [file] if we don't
  /// already have one. Fire-and-forget; never throws. Work is queued so at most
  /// [_maxConcurrent] encodes run at a time.
  void ensureFor(String filename, File file) {
    if (filename.isEmpty) return;
    if (_cache.containsKey(filename) || _seen.contains(filename)) return;
    _seen.add(filename);
    _queue.add((filename: filename, file: file));
    _pump();
  }

  void _pump() {
    while (_running < _maxConcurrent && _queue.isNotEmpty) {
      final job = _queue.removeAt(0);
      _running++;
      () async {
        try {
          if (await job.file.length() > _maxBytes) return;
          final bytes = await job.file.readAsBytes();
          final blur = await computeBlurHash(bytes);
          if (blur != null) {
            _cache[job.filename] = blur.hash;
            _scheduleSave();
          }
        } catch (_) {
        } finally {
          _running--;
          _pump();
        }
      }();
    }
  }

  void _scheduleSave() {
    if (_persistPath == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 5), _saveToDisk);
  }

  Future<void> _saveToDisk() async {
    final path = _persistPath;
    if (path == null) return;
    try {
      await File(path).writeAsString(jsonEncode(_cache));
    } catch (_) {}
  }
}
