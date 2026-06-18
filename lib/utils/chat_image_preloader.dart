// lib/utils/chat_image_preloader.dart
//
// Parses message lists for IMAGEv1/ALBUMv1 content and schedules:
//   • a local-only preload (ImageLoader.preloadOnly) so already-downloaded
//     images appear instantly, and
//   • optionally, proactive WARMING (ImageLoader.warm) which downloads+decrypts
//     media around the open viewport BEFORE the user scrolls to it. Warming is
//     gated by the user's MediaPreloadMode setting and the current connection.
//
// Usage: ChatImagePreloader.preload(messages, peerUsername: peer);
//        ChatImagePreloader.preloadGroupMessages(messages);
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../enums/media_preload_mode.dart';
import '../managers/settings_manager.dart';
import '../models/chat_message.dart';
import '../utils/image_loader.dart';

typedef _MediaRef = ({String fn, String? owner, String? key, bool meta});

class ChatImagePreloader {
  // Only preload images near the chat's open position, not the entire history.
  // A chat with 1000 photos must not enqueue 1000 preloads — that wastes IO and
  // delays the visible images. We take a window from BOTH ends of the list
  // because message ordering differs across screens (some are newest-first,
  // others oldest-first); the open viewport is always at one end. Visible images
  // beyond this window still load instantly on demand via ImageLoader.load().
  static int get _window => SettingsManager.imagePreloadWindow.value;

  /// For direct chats and favorites (ChatMessage list).
  static void preload(List<ChatMessage> messages, {String peerUsername = ''}) {
    final refs = _extractFilenames(_windowed(messages));
    for (final m in refs) {
      ImageLoader.preloadOnly(m.fn, computeMetadata: m.meta);
    }
    _maybeWarm(refs, peerUsername);
  }

  /// For group and external-group chats (raw Map list from the group protocol).
  static void preloadGroupMessages(List<Map<String, dynamic>> messages,
      {String peerUsername = ''}) {
    final refs = _extractGroupFilenames(_windowed(messages));
    for (final m in refs) {
      ImageLoader.preloadOnly(m.fn, computeMetadata: m.meta);
    }
    _maybeWarm(refs, peerUsername);
  }

  // ── Warming ─────────────────────────────────────────────────────────────────

  static void _maybeWarm(List<_MediaRef> refs, String peerUsername) async {
    if (refs.isEmpty) return;
    if (!await _warmingAllowed()) return;
    for (final m in refs) {
      ImageLoader.warm(
        m.fn,
        peerUsername: peerUsername,
        owner: m.owner,
        mediaKeyB64: m.key,
        computeMetadata: m.meta,
      );
    }
  }

  /// Whether background warming is permitted right now, per the user's setting
  /// and the active connection.
  static Future<bool> _warmingAllowed() async {
    switch (SettingsManager.mediaPreloadMode.value) {
      case MediaPreloadMode.off:
        return false;
      case MediaPreloadMode.always:
        return true;
      case MediaPreloadMode.wifiOnly:
        try {
          final res = await Connectivity().checkConnectivity();
          return res.contains(ConnectivityResult.wifi) ||
              res.contains(ConnectivityResult.ethernet);
        } catch (_) {
          // If connectivity can't be determined, err on the safe side (no warm).
          return false;
        }
    }
  }

  /// Returns the first and last [_window]/2 items of [list] (the two possible
  /// viewport ends), or the whole list when it's small enough.
  static List<T> _windowed<T>(List<T> list) {
    if (list.length <= _window) return list;
    final half = _window ~/ 2;
    return [...list.take(half), ...list.skip(list.length - half)];
  }

  // ── Filename extraction ───────────────────────────────────────────────────
  //
  // [meta] flags whether the preload should read the image header for the
  // aspect ratio: true for single photos (they size their bubble by it), false
  // for album images (fixed-size thumbnails) so a big album doesn't read a
  // header per image on chat open.

  static List<_MediaRef> _extractGroupFilenames(
      List<Map<String, dynamic>> messages) {
    final result = <_MediaRef>[];
    for (final msg in messages) {
      _parseContent(msg['content'] as String? ?? '', result);
    }
    return result;
  }

  static List<_MediaRef> _extractFilenames(List<ChatMessage> messages) {
    final result = <_MediaRef>[];
    for (final msg in messages) {
      _parseContent(msg.content, result);
    }
    return result;
  }

  static void _parseContent(String c, List<_MediaRef> out) {
    if (c.startsWith('IMAGEv1:')) {
      try {
        final data = jsonDecode(c.substring(8)) as Map<String, dynamic>;
        final f = data['url'] as String? ?? data['filename'] as String? ?? '';
        if (f.isNotEmpty) {
          out.add((
            fn: f,
            owner: data['owner'] as String?,
            key: data['key'] as String?,
            meta: true,
          ));
        }
      } catch (_) {}
    } else if (c.startsWith('ALBUMv1:')) {
      try {
        final list = jsonDecode(c.substring(8)) as List;
        for (final item in list.whereType<Map<String, dynamic>>()) {
          final f = item['filename'] as String? ?? item['url'] as String? ?? '';
          if (f.isNotEmpty) {
            out.add((
              fn: f,
              owner: item['owner'] as String?,
              key: item['key'] as String?,
              meta: false,
            ));
          }
        }
      } catch (_) {}
    }
  }
}
