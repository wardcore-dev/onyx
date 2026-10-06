// lib/services/wardlink/wardlink_media.dart
//
// Locates favourites media on the sender and decides where the receiver must
// write it so the existing message widgets actually find it. This mirrors how
// each widget resolves a file:
//   • `fav://name`  → applicationDocuments/fav_media  (voice → /voice_cache)
//   • plain name    → applicationSupport/<type>_cache (image/video/…)
//                     voice → applicationDocuments/voice_cache
// Only PLAIN (already-decrypted) local files are transferred — encrypted `.enc`
// cache copies are intentionally skipped (decrypting them in-process would
// reintroduce the memory blow-up; such files are server-backed and the receiver
// fetches them normally). Files that aren't found locally simply aren't sent,
// and the widget falls back to its usual server fetch.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../utils/onyx_base_dir.dart';

import '../../globals.dart';
import '../../utils/image_file_cache.dart';

class WardLinkMedia {
  /// All directories favourites media can live in, searched on the sender.
  static Future<List<String>> _searchDirs() async {
    final doc = (await getOnyxDocumentsDirectory()).path;
    final sup = (await getOnyxSupportDirectory()).path;
    final tmp = (await getTemporaryDirectory()).path;
    return [
      '$doc/fav_media',
      '$doc/voice_cache',
      '$doc/lan_media',
      // Media of Tor (onion://) messages, sent or received.
      '$doc/onion_media',
      '$sup/voice_cache',
      '$sup/audio_cache',
      '$sup/video_cache',
      '$sup/image_cache',
      '$sup/document_cache',
      '$sup/archive_cache',
      '$sup/data_cache',
      '$sup/fav_avatars',
      '$tmp/onyx_display/voice',
      '$tmp/onyx_display/video',
      '$tmp/onyx_display/image',
      '$tmp/onyx_display/audio',
      '$tmp/onyx_display/file',
    ];
  }

  /// Find the plain local file for [fullFilename] (which may carry a `fav://` /
  /// `lan://` / `onion://` prefix), or null if it isn't stored locally.
  /// An empty file (an aborted write) doesn't count -- it would never render
  /// and would block the download that fixes it.
  static Future<String?> resolveLocal(String fullFilename) async {
    final base = p.basename(fullFilename);
    if (base.isEmpty) return null;
    for (final dir in await _searchDirs()) {
      final f = File('$dir/$base');
      if (await f.exists() && await f.length() > 0) return f.path;
    }
    return null;
  }

  /// Whether the widget for [fullFilename] will find it here: a prefixed
  /// file must be in its own directory (a copy elsewhere isn't looked at).
  static Future<bool> isWhereWidgetLooks(String fullFilename, String type) async {
    final target = await saveTarget(fullFilename, type);
    final f = File(target);
    return await f.exists() && await f.length() > 0;
  }

  /// Where the receiver must write a file of [type] for [fullFilename] so the
  /// matching widget will find it. Creates the directory.
  static Future<String> saveTarget(String fullFilename, String type) async {
    final base = p.basename(fullFilename);
    final isFav = fullFilename.startsWith('fav://');
    final doc = (await getOnyxDocumentsDirectory()).path;
    final sup = (await getOnyxSupportDirectory()).path;

    String dir;
    if (type == 'avatar') {
      dir = '$sup/fav_avatars';
    } else if (fullFilename.startsWith('onion://')) {
      // Every onion:// widget (image, video, voice, file) reads from here.
      dir = '$doc/onion_media';
    } else if (fullFilename.startsWith('lan://')) {
      dir = '$doc/lan_media';
    } else if (isFav) {
      dir = type == 'voice' ? '$doc/voice_cache' : '$doc/fav_media';
    } else {
      switch (type) {
        case 'image':
          dir = '$sup/image_cache';
        case 'video':
          dir = '$sup/video_cache';
        case 'voice':
          dir = '$doc/voice_cache';
        case 'audio':
          dir = '$sup/audio_cache';
        case 'document':
          dir = '$sup/document_cache';
        case 'archive':
          dir = '$sup/archive_cache';
        default:
          dir = '$sup/data_cache';
      }
    }
    await Directory(dir).create(recursive: true);
    return '$dir/$base';
  }

  /// Register a freshly-saved file in the runtime caches the widgets consult, so
  /// it renders without a reload. Widgets key the registry by the *full*
  /// filename (incl. any prefix), so register both that and the basename.
  static void register(String fullFilename, String type, String path, int size) {
    if (type == 'avatar') return;
    final base = p.basename(fullFilename);
    mediaFilePathRegistry[fullFilename] = path;
    mediaFilePathRegistry[base] = path;
    if (type == 'image') {
      // Register under both the full key (what AlbumThumb looks up in initState/
      // didUpdateWidget) and the basename (legacy lookups), so the widget finds
      // the file immediately after WardLink downloads it without a disk round-trip.
      final entry = (file: File(path), size: size, aspectRatio: null);
      imageFileCache[fullFilename] = entry;
      imageFileCache[base] = entry;
    }
  }
}
