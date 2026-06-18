// lib/utils/gallery_extractor.dart
//
// Pulls every photo, video, voice message and file out of a chat's message
// list for the shared media-gallery screen. Normalizes every source format
// (single image/video, multi-image albums, external-server media-proxy
// messages, and the legacy plain-text FILE: format) down to the same four
// content shapes (IMAGEv1:/VIDEOv1:/VOICEv1:/FILEv1:) so the gallery only
// ever needs to render four cases, reusing the exact widgets already used in
// the chat bubble (see message_bubble.dart) for downloading/caching/playback.

import 'dart:convert';

import '../managers/external_server_manager.dart';
import '../models/chat_message.dart';
import '../widgets/album_message_widget.dart' show AlbumItem;

enum GalleryKind { photo, video, voice, file }

class GalleryItem {
  final String id;
  final GalleryKind kind;
  final String content;
  final DateTime time;

  const GalleryItem({
    required this.id,
    required this.kind,
    required this.content,
    required this.time,
  });
}

List<GalleryItem> extractGalleryItemsFromChatMessages(
    List<ChatMessage> messages) {
  final out = <GalleryItem>[];
  for (final m in messages) {
    _extract(m.content, m.id, m.time, out);
  }
  out.sort((a, b) => b.time.compareTo(a.time));
  return out;
}

List<GalleryItem> extractGalleryItemsFromMaps(
    List<Map<String, dynamic>> messages) {
  final out = <GalleryItem>[];
  for (final m in messages) {
    final content = m['content']?.toString() ?? '';
    final id = m['id']?.toString() ?? '';
    final time = DateTime.tryParse(m['createdAt']?.toString() ?? '') ??
        DateTime.tryParse(m['time']?.toString() ?? '') ??
        DateTime.now();
    _extract(content, id, time, out);
  }
  out.sort((a, b) => b.time.compareTo(a.time));
  return out;
}

const List<String> _imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
const List<String> _videoExts = ['.mp4', '.mov', '.m4v', '.webm', '.m4a'];

void _extract(String content, String id, DateTime time, List<GalleryItem> out) {
  try {
    if (content.startsWith('IMAGEv1:')) {
      out.add(GalleryItem(id: id, kind: GalleryKind.photo, content: content, time: time));
    } else if (content.toUpperCase().startsWith('VIDEOV1:')) {
      out.add(GalleryItem(id: id, kind: GalleryKind.video, content: content, time: time));
    } else if (content.startsWith('ALBUMv1:')) {
      final list = jsonDecode(content.substring('ALBUMv1:'.length)) as List<dynamic>;
      var i = 0;
      for (final raw in list.whereType<Map<String, dynamic>>()) {
        final item = AlbumItem.fromJson(raw);
        if (item.filename.isEmpty) continue;
        out.add(GalleryItem(
          id: '$id#${i++}',
          kind: GalleryKind.photo,
          content: 'IMAGEv1:${_albumItemJson(item)}',
          time: time,
        ));
      }
    } else if (content.startsWith('VOICEv1:') || content.startsWith('AUDIOv1:')) {
      out.add(GalleryItem(id: id, kind: GalleryKind.voice, content: content, time: time));
    } else if (content.startsWith('FILEv1:')) {
      out.add(GalleryItem(id: id, kind: GalleryKind.file, content: content, time: time));
    } else if (content.startsWith('FILE:')) {
      final filename = content.substring('FILE:'.length).trim();
      if (filename.isNotEmpty) {
        out.add(GalleryItem(
          id: id,
          kind: GalleryKind.file,
          content: 'FILEv1:${jsonEncode({'filename': filename})}',
          time: time,
        ));
      }
    } else if (content.startsWith('DOCUMENTv1:') ||
        content.startsWith('ARCHIVEv1:') ||
        content.startsWith('DATAv1:')) {
      final meta = jsonDecode(content.substring(content.indexOf(':') + 1)) as Map<String, dynamic>;
      final filename = meta['filename'] as String? ?? '';
      if (filename.isNotEmpty) {
        out.add(GalleryItem(
          id: id,
          kind: GalleryKind.file,
          content: 'FILEv1:${jsonEncode({'filename': filename})}',
          time: time,
        ));
      }
    } else if (content.startsWith('MEDIA_PROXYv1:')) {
      _extractProxy(content, id, time, out);
    }
  } catch (_) {
    // Malformed metadata — skip silently, same as message_bubble.dart does.
  }
}

String _albumItemJson(AlbumItem item) => jsonEncode({
      'url': item.filename,
      'orig': item.orig,
      if (item.owner != null) 'owner': item.owner,
      if (item.mediaKeyB64 != null) 'key': item.mediaKeyB64,
      if (item.blurHash != null) 'blur': item.blurHash,
    });

void _extractProxy(String content, String id, DateTime time, List<GalleryItem> out) {
  final data = jsonDecode(content.substring('MEDIA_PROXYv1:'.length)) as Map<String, dynamic>;
  final type = data['type'] as String?;
  final orig = (data['orig'] as String?) ?? 'file';

  if (type == 'album') {
    final items = (data['items'] as List?)?.whereType<Map<String, dynamic>>() ?? const [];
    var i = 0;
    for (final raw in items) {
      final item = AlbumItem.fromJson(raw);
      if (item.filename.isEmpty) continue;
      out.add(GalleryItem(
        id: '$id#${i++}',
        kind: GalleryKind.photo,
        content: 'IMAGEv1:${_albumItemJson(item)}',
        time: time,
      ));
    }
    return;
  }

  final url = (data['url'] as String?)?.trim();
  if (url == null || url.isEmpty) return;
  final authUrl = ExternalServerManager.addTokenToUrl(url);

  switch (type) {
    case 'voice':
    case 'audio':
      out.add(GalleryItem(
        id: id,
        kind: GalleryKind.voice,
        content: 'VOICEv1:${jsonEncode({
              'url': authUrl,
              if (type == 'audio' && orig.isNotEmpty) 'orig': orig,
            })}',
        time: time,
      ));
      break;
    case 'document':
    case 'archive':
    case 'data':
    case 'file':
      out.add(GalleryItem(
        id: id,
        kind: GalleryKind.file,
        content: 'FILEv1:${jsonEncode({'filename': orig, 'directUrl': authUrl})}',
        time: time,
      ));
      break;
    case 'video':
      out.add(GalleryItem(
        id: id,
        kind: GalleryKind.video,
        content: 'VIDEOv1:${jsonEncode({'url': authUrl, 'orig': orig})}',
        time: time,
      ));
      break;
    default:
      final lower = url.toLowerCase();
      final origLower = orig.toLowerCase();
      final isVideo = type == 'video' ||
          _videoExts.any(origLower.endsWith) ||
          _videoExts.any(lower.endsWith);
      final isImage = !isVideo &&
          (type == 'image' ||
              _imageExts.any(origLower.endsWith) ||
              _imageExts.any(lower.endsWith));
      if (isVideo) {
        out.add(GalleryItem(
          id: id,
          kind: GalleryKind.video,
          content: 'VIDEOv1:${jsonEncode({'url': authUrl, 'orig': orig})}',
          time: time,
        ));
      } else if (isImage) {
        out.add(GalleryItem(
          id: id,
          kind: GalleryKind.photo,
          content: 'IMAGEv1:${jsonEncode({'url': authUrl, 'orig': orig})}',
          time: time,
        ));
      }
  }
}
