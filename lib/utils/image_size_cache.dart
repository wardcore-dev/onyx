// lib/utils/image_size_cache.dart
//
// Reads only the image header (24–65536 bytes) to extract dimensions.
// Avoids full image decode, which was the source of 3-5s lag when many
// images scrolled into view simultaneously.
//
// Persistence: aspect ratios are written to image_size_cache.json after each
// new computation (debounced 5 s). On next app start they are loaded by
// AppPaths.ensureInit() so no file-header reads are needed for known images.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ImageSizeCache {
  static final ImageSizeCache _instance = ImageSizeCache._internal();
  factory ImageSizeCache() => _instance;
  ImageSizeCache._internal();

  final Map<String, double> _cache = {};
  static const int _maxCacheSize = 500;

  double? getCachedAspectRatio(String filePath) => _cache[filePath];

  void cacheAspectRatio(String filePath, double aspectRatio) {
    if (_cache.length >= _maxCacheSize) {
      final toRemove = _cache.keys.take(_cache.length - _maxCacheSize + 100).toList();
      for (final k in toRemove) { _cache.remove(k); }
    }
    _cache[filePath] = aspectRatio;
    _scheduleSave();
  }

  Future<double> getOrComputeAspectRatio(File file) async {
    final path = file.path;
    final cached = getCachedAspectRatio(path);
    if (cached != null) return cached;

    final ratio = await _readAspectRatio(file);
    cacheAspectRatio(path, ratio);
    return ratio;
  }

  void clear() => _cache.clear();

  // ── Persistence ────────────────────────────────────────────────────────────

  String? _persistPath;
  Timer? _saveTimer;

  /// Load previously persisted aspect ratios from [path].
  /// Called once by AppPaths.ensureInit() after paths are resolved.
  Future<void> loadFromDisk(String path) async {
    _persistPath = path;
    try {
      final file = File(path);
      if (!file.existsSync()) return;
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      map.forEach((k, v) {
        if (v is num) _cache[k] = v.toDouble();
      });
    } catch (_) {}
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

Future<double> _readAspectRatio(File file) async {
  RandomAccessFile? raf;
  try {
    raf = await file.open();

    // Read first 30 bytes — enough to identify PNG, GIF, WebP
    final head = Uint8List(30);
    final headRead = await raf.readInto(head);
    if (headRead < 4) return 4 / 3;

    // ── PNG ──────────────────────────────────────────────────────────────────
    // Signature: 89 50 4E 47 0D 0A 1A 0A
    // IHDR chunk: 4 bytes length + 4 bytes "IHDR" + 4 bytes width + 4 bytes height
    // Width starts at byte 16, height at byte 20
    if (head[0] == 0x89 && head[1] == 0x50 &&
        head[2] == 0x4E && head[3] == 0x47) {
      if (headRead >= 24) {
        final w = _u32be(head, 16);
        final h = _u32be(head, 20);
        if (w > 0 && h > 0) return w / h;
      }
      return 4 / 3;
    }

    // ── GIF ──────────────────────────────────────────────────────────────────
    // Bytes 6-7: width (LE), bytes 8-9: height (LE)
    if (head[0] == 0x47 && head[1] == 0x49 && head[2] == 0x46) {
      if (headRead >= 10) {
        final w = head[6] | (head[7] << 8);
        final h = head[8] | (head[9] << 8);
        if (w > 0 && h > 0) return w / h;
      }
      return 4 / 3;
    }

    // ── WebP ─────────────────────────────────────────────────────────────────
    // RIFF????WEBP at bytes 0-11
    if (head[0] == 0x52 && head[1] == 0x49 &&   // RI
        head[2] == 0x46 && head[3] == 0x46 &&   // FF
        headRead >= 30 &&
        head[8] == 0x57 && head[9] == 0x45 &&   // WE
        head[10] == 0x42 && head[11] == 0x50) { // BP
      // VP8 (lossy): chunk at offset 12 = "VP8 "
      if (head[12] == 0x56 && head[13] == 0x50 &&
          head[14] == 0x38 && head[15] == 0x20) {
        // Width/height at bytes 26-29 (14-bit fields, little-endian)
        final w = (head[26] | (head[27] << 8)) & 0x3FFF;
        final h = (head[28] | (head[29] << 8)) & 0x3FFF;
        if (w > 0 && h > 0) return w / h;
      }
      // VP8X: chunk at offset 12 = "VP8X", canvas width/height at bytes 24-29
      if (head[12] == 0x56 && head[13] == 0x50 &&
          head[14] == 0x38 && head[15] == 0x58) {
        final w = (head[24] | (head[25] << 8) | (head[26] << 16)) + 1;
        final h = (head[27] | (head[28] << 8) | (head[29] << 16)) + 1;
        if (w > 0 && h > 0) return w / h;
      }
      return 4 / 3;
    }

    // ── JPEG ─────────────────────────────────────────────────────────────────
    // SOF marker (C0/C1/C2/C3/C5/C6/C7) contains height and width.
    // Skip EXIF and other APP segments (can be up to ~64KB).
    if (head[0] == 0xFF && head[1] == 0xD8) {
      return await _parseJpeg(raf);
    }

    return 4 / 3;
  } catch (e) {
    debugPrint('[ImageSizeCache] Failed to read dimensions: $e');
    return 4 / 3;
  } finally {
    await raf?.close();
  }
}

Future<double> _parseJpeg(RandomAccessFile raf) async {
  // Scan up to 64KB after the SOI marker to find SOF
  await raf.setPosition(2);
  final buf = Uint8List(65536);
  final read = await raf.readInto(buf);

  int i = 0;
  while (i + 4 <= read) {
    if (buf[i] != 0xFF) break;
    final marker = buf[i + 1];

    // SOF markers that carry dimensions
    if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2 ||
        marker == 0xC3 || marker == 0xC5 || marker == 0xC6 || marker == 0xC7) {
      if (i + 9 <= read) {
        final h = (buf[i + 5] << 8) | buf[i + 6];
        final w = (buf[i + 7] << 8) | buf[i + 8];
        if (w > 0 && h > 0) return w / h;
      }
      break;
    }

    if (marker == 0xD9 || marker == 0xDA) break; // EOI / SOS
    if (i + 3 >= read) break;
    final segLen = (buf[i + 2] << 8) | buf[i + 3];
    if (segLen < 2) break;
    i += 2 + segLen;
  }
  return 4 / 3;
}

int _u32be(Uint8List b, int o) =>
    (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
