// lib/utils/blurhash_util.dart
//
// Computes a compact BlurHash string + aspect ratio from encoded image bytes.
// The hash is embedded in IMAGEv1/ALBUMv1 message metadata so the receiver can
// render a blurred placeholder instantly — before the full image is downloaded
// (Telegram-style preview).
//
// Encoding runs in a background isolate via compute() so decoding a full-size
// photo never blocks the UI thread.
import 'package:flutter/foundation.dart';
import 'package:blurhash_dart/blurhash_dart.dart';
import 'package:image/image.dart' as img;

typedef BlurResult = ({String hash, double aspectRatio});

/// Returns a BlurHash + aspect ratio for [bytes] (an encoded JPEG/PNG/etc.),
/// or null if the image can't be decoded.
Future<BlurResult?> computeBlurHash(Uint8List bytes) {
  return compute(_encode, bytes);
}

BlurResult? _encode(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.width == 0 || decoded.height == 0) {
      return null;
    }
    final aspectRatio = decoded.width / decoded.height;

    // BlurHash only needs a tiny image — downscale the long edge to 32px so
    // encoding stays cheap regardless of the original resolution.
    final img.Image small;
    if (decoded.width >= decoded.height) {
      small = img.copyResize(decoded, width: 32);
    } else {
      small = img.copyResize(decoded, height: 32);
    }

    final blur = BlurHash.encode(small, numCompX: 4, numCompY: 3);
    return (hash: blur.hash, aspectRatio: aspectRatio);
  } catch (_) {
    return null;
  }
}
