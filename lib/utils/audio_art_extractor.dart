// lib/utils/audio_art_extractor.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:audiotags/audiotags.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart' show Color;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import '../managers/settings_manager.dart';
import '../models/app_themes.dart';
import 'onyx_base_dir.dart' show getOnyxDocumentsDirectory;

/// Extracts an embedded cover picture (ID3v2 APIC / MP4 `covr` / FLAC /
/// Vorbis comment art) from a local audio file, using `audiotags` — a
/// cross-platform plugin (Android/iOS/macOS/Windows/Linux) so this needs no
/// per-platform native code of our own. Results are cached on disk keyed by
/// the source file's path, so replaying the same voice/audio message skips
/// re-decoding.
///
/// Returns the cached art file's path, or null if the file has no embedded
/// picture (or reading/writing it failed — this is a decorative feature, so
/// failures are swallowed rather than surfaced to the user).
Future<String?> extractArt(String audioFilePath) async {
  try {
    final docs = await getOnyxDocumentsDirectory();
    final cacheDir = Directory(p.join(docs.path, 'art_cache'));
    await cacheDir.create(recursive: true);

    final hash = md5.convert(utf8.encode(audioFilePath)).toString();
    final cachedFile = File(p.join(cacheDir.path, hash));
    if (await cachedFile.exists()) return cachedFile.path;

    final tag = await AudioTags.read(audioFilePath);
    if (tag == null) {
      debugPrint('[AudioArt] no tag found in $audioFilePath');
      return null;
    }
    debugPrint('[AudioArt] $audioFilePath: ${tag.pictures.length} picture(s)');
    final picture = tag.pictures.firstOrNull;
    if (picture == null || picture.bytes.isEmpty) {
      debugPrint('[AudioArt] tag has no usable picture for $audioFilePath');
      return null;
    }

    await cachedFile.writeAsBytes(picture.bytes, flush: true);
    debugPrint('[AudioArt] cached ${picture.bytes.length}B art for '
        '$audioFilePath -> ${cachedFile.path}');
    return cachedFile.path;
  } catch (e, st) {
    debugPrint('[AudioArt] extractArt failed for $audioFilePath: $e\n$st');
    return null;
  }
}

/// A plain solid-color square in the current in-app theme's accent color,
/// used as a stand-in `artUri` when a track has no embedded cover picture.
///
/// Some OEM Android skins (Samsung's One UI media card among them) derive
/// their own background tint for the system media notification/lock-screen
/// widget from the artwork bitmap's dominant color via their own palette
/// extraction, rather than fully honoring `NotificationCompat.setColor()` —
/// so a track with no art at all falls back to that skin's own default tint
/// (typically a blue-ish gradient) regardless of what color the app
/// requested. Handing it *some* artwork in the right color gives that
/// palette extraction something matching the app theme to key off instead.
Future<String?> getFallbackArt() async {
  try {
    final docs = await getOnyxDocumentsDirectory();
    final cacheDir = Directory(p.join(docs.path, 'art_cache'));
    await cacheDir.create(recursive: true);

    final pref = await SettingsManager.loadThemePreference();
    final theme = AppTheme.fromStoredName(pref.name);
    debugPrint('[AudioArt] getFallbackArt: storedThemeName=${pref.name} -> '
        'resolved=${theme.name} color=${theme.color}');
    final cachedFile = File(p.join(cacheDir.path, 'fallback_${theme.name}'));
    if (await cachedFile.exists()) return cachedFile.path;

    final bytes = _renderSolidColorPng(theme.color);
    await cachedFile.writeAsBytes(bytes, flush: true);
    return cachedFile.path;
  } catch (e) {
    debugPrint('[AudioArt] getFallbackArt failed: $e');
    return null;
  }
}

Uint8List _renderSolidColorPng(Color color) {
  const size = 192;
  int toC(double v) => (v * 255.0).round().clamp(0, 255);
  final image = img.Image(width: size, height: size, numChannels: 4);
  img.fill(
    image,
    color: img.ColorRgba8(toC(color.r), toC(color.g), toC(color.b), 255),
  );
  return Uint8List.fromList(img.encodePng(image));
}
