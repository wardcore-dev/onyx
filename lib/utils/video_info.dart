// lib/utils/video_info.dart
//
// Extracts aspect ratio and an optional blurHash poster from a local video
// file using a temporary headless media_kit Player. Called at video send time
// so recipients see a proportional blurred preview before downloading.
import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'blurhash_util.dart';

/// Returns `({String? hash, double ar})` for [filePath], or null on failure.
/// [hash] is null when screenshot is unsupported (e.g. mobile without display).
Future<({String? hash, double ar})?> extractVideoInfo(String filePath) async {
  final player = Player();
  try {
    await player.open(Media(filePath), play: false);

    // Wait for video dimensions from the stream.
    VideoParams? params;
    try {
      params = await player.stream.videoParams
          .firstWhere((p) => (p.dw ?? 0) > 0)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Also check current state (may already be set on some platforms).
      final s = player.state.videoParams;
      if ((s.dw ?? 0) > 0) params = s;
    }

    if (params == null) return null;
    final w = params.dw ?? 0;
    final h = params.dh ?? 0;
    if (w <= 0 || h <= 0) return null;
    final ar = w / h;

    // Capture poster blurHash — works on desktop (libmpv), silently fails on
    // mobile. Callers omit 'blur' from metadata when hash is null.
    String? hash;
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      final bytes = await player.screenshot();
      if (bytes != null && bytes.isNotEmpty) {
        final blur = await computeBlurHash(bytes);
        hash = blur?.hash;
      }
    } catch (_) {}

    return (hash: hash, ar: ar);
  } catch (_) {
    return null;
  } finally {
    try {
      player.dispose();
    } catch (_) {}
  }
}
