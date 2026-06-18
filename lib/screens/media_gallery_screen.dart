// lib/screens/media_gallery_screen.dart
//
// Shared "all media in this chat" gallery, opened from ChatScreen,
// GroupChatScreen, ExternalGroupChatScreen and FavoritesScreen via the
// overflow menu. Presented as a large dialog (same chrome/animation as the
// "Manage Cache" dialog) rather than a separate pushed screen. Renders three
// tabs (Media / Voice / Files) reusing the exact widgets the chat bubble
// already uses for downloading, caching and playback (ImageMessageWidget,
// VideoMessageWidget, VoiceMessagePlayer, FileMessageWidget) so behavior
// stays identical to tapping the same media inline in the conversation.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../globals.dart' show isDesktop;
import '../l10n/app_localizations.dart';
import '../utils/gallery_extractor.dart';
import '../widgets/adaptive_glass_card.dart';
import '../widgets/album_message_widget.dart' show AlbumItem;
import '../widgets/apple_segmented_tabs.dart';
import '../widgets/chat_images_scope.dart';
import '../widgets/file_message_widget.dart';
import '../widgets/image_message_widget.dart';
import '../widgets/video_message_widget.dart';
import '../widgets/voice_message_widget.dart';

enum _SortOrder { newest, oldest }

String _fmtDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';

String _fmtDateTime(DateTime dt) =>
    '${_fmtDate(dt)}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

/// Opens the gallery as a large dialog (not a separate screen/route).
Future<void> showMediaGalleryDialog(
  BuildContext context, {
  required List<GalleryItem> items,
  required String peerUsername,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Gallery',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (_, __, ___) =>
        _MediaGalleryDialog(items: items, peerUsername: peerUsername),
  );
}

class _MediaGalleryDialog extends StatefulWidget {
  final List<GalleryItem> items;
  final String peerUsername;

  const _MediaGalleryDialog({required this.items, required this.peerUsername});

  @override
  State<_MediaGalleryDialog> createState() => _MediaGalleryDialogState();
}

class _MediaGalleryDialogState extends State<_MediaGalleryDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  _SortOrder _sort = _SortOrder.newest;
  int _columns = 3;

  late final List<GalleryItem> _allMedia = widget.items
      .where((i) => i.kind == GalleryKind.photo || i.kind == GalleryKind.video)
      .toList();
  late final List<GalleryItem> _allVoice =
      widget.items.where((i) => i.kind == GalleryKind.voice).toList();
  late final List<GalleryItem> _allFiles =
      widget.items.where((i) => i.kind == GalleryKind.file).toList();

  List<GalleryItem> get _media =>
      _sort == _SortOrder.newest ? _allMedia : _allMedia.reversed.toList();
  List<GalleryItem> get _voice =>
      _sort == _SortOrder.newest ? _allVoice : _allVoice.reversed.toList();
  List<GalleryItem> get _files =>
      _sort == _SortOrder.newest ? _allFiles : _allFiles.reversed.toList();

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _toggleSort() =>
      setState(() => _sort = _sort == _SortOrder.newest ? _SortOrder.oldest : _SortOrder.newest);
  void _zoomOut() => setState(() => _columns = (_columns + 1).clamp(2, 6));
  void _zoomIn() => setState(() => _columns = (_columns - 1).clamp(2, 6));

  // Pinch-to-zoom (mobile only — desktop keeps the +/- buttons instead).
  //
  // Deliberately uses raw Listener pointer events instead of a GestureDetector
  // with onScale: a GestureDetector's ScaleGestureRecognizer competes with the
  // GridView's own vertical-drag scroll recognizer in the gesture arena, and
  // the scroll recognizer reliably wins — so the pinch never fired at all.
  // Listener doesn't enter the gesture arena, so it sees every pointer
  // (including the second finger of a pinch) regardless of what the
  // GridView's scrolling does with them.
  final Map<int, Offset> _activePointers = {};
  double? _pinchStartDistance;
  int _pinchBaseColumns = 3;

  double _currentPointerSpan() {
    final pts = _activePointers.values.toList();
    if (pts.length < 2) return 0;
    return (pts[0] - pts[1]).distance;
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.position;
    if (_activePointers.length == 2) {
      _pinchStartDistance = _currentPointerSpan();
      _pinchBaseColumns = _columns;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_activePointers.containsKey(event.pointer)) return;
    _activePointers[event.pointer] = event.position;
    final start = _pinchStartDistance;
    if (_activePointers.length == 2 && start != null && start > 10) {
      final scale = _currentPointerSpan() / start;
      final target = (_pinchBaseColumns / scale).round().clamp(2, 6);
      if (target != _columns) setState(() => _columns = target);
    }
  }

  void _onPointerEnd(PointerEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2) _pinchStartDistance = null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final isWide = mq.size.width > 700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isWide ? 40 : 12,
        vertical: 24,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Material(
            color: cs.surface,
            borderRadius: BorderRadius.circular(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(l, cs),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: AppleSegmentedTabs(
                    controller: _tab,
                    segments: [
                      AppleSegment(icon: Icons.photo_outlined, label: l.galleryTabMedia),
                      AppleSegment(icon: Icons.mic_none_rounded, label: l.galleryTabVoice),
                      AppleSegment(
                          icon: Icons.insert_drive_file_outlined,
                          label: l.galleryTabFiles),
                    ],
                  ),
                ),
                Flexible(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _buildMediaTab(l, cs),
                      _buildVoiceTab(l, cs),
                      _buildFilesTab(l, cs),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        border: Border(
          bottom: BorderSide(color: cs.primary.withValues(alpha: 0.10), width: 0.8),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.photo_library_rounded, size: 18, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(l.galleryTitle,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: cs.onSurface)),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.close_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.55)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(ColorScheme cs, int count, {bool showZoom = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$count',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ),
          if (showZoom) ...[
            IconButton(
              tooltip: 'Zoom out',
              icon: const Icon(Icons.zoom_out_rounded, size: 19),
              visualDensity: VisualDensity.compact,
              onPressed: _columns < 6 ? _zoomOut : null,
            ),
            IconButton(
              tooltip: 'Zoom in',
              icon: const Icon(Icons.zoom_in_rounded, size: 19),
              visualDensity: VisualDensity.compact,
              onPressed: _columns > 2 ? _zoomIn : null,
            ),
          ],
          IconButton(
            tooltip: _sort == _SortOrder.newest ? 'Newest first' : 'Oldest first',
            icon: Icon(
              _sort == _SortOrder.newest ? Icons.south_rounded : Icons.north_rounded,
              size: 19,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: _toggleSort,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String label) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: cs.onSurfaceVariant.withValues(alpha: 0.35)),
          const SizedBox(height: 12),
          Text(label,
              style:
                  TextStyle(fontSize: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  // ── Media tab ────────────────────────────────────────────────────────────

  Widget _buildMediaTab(AppLocalizations l, ColorScheme cs) {
    final media = _media;
    if (media.isEmpty) {
      return _buildEmptyState(Icons.photo_library_outlined, l.galleryEmptyMedia);
    }
    final photoAlbumItems = media
        .where((i) => i.kind == GalleryKind.photo)
        .map((i) {
          final data =
              jsonDecode(i.content.substring('IMAGEv1:'.length)) as Map<String, dynamic>;
          return AlbumItem(
            filename: data['url'] as String? ?? data['filename'] as String? ?? '',
            orig: data['orig'] as String? ?? '',
            owner: data['owner'] as String?,
            mediaKeyB64: data['key'] as String?,
            blurHash: data['blur'] as String?,
          );
        })
        .where((i) => i.filename.isNotEmpty)
        .toList();

    final grid = ChatImagesScope(
      allImages: photoAlbumItems,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        // Off-screen tiles don't keep their decoded image alive — re-showing
        // them re-reads from the (already-cached) file instead of holding
        // every image's state in memory for the whole scroll session, which
        // is what made fast scrolling through a big album feel laggy.
        addAutomaticKeepAlives: false,
        cacheExtent: 600,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columns,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemCount: media.length,
        itemBuilder: (_, i) => _buildMediaTile(media[i]),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(cs, media.length, showZoom: isDesktop),
        Expanded(
          child: isDesktop
              ? grid
              : Listener(
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerEnd,
                  onPointerCancel: _onPointerEnd,
                  child: grid,
                ),
        ),
      ],
    );
  }

  Widget _buildMediaTile(GalleryItem item) {
    final isVideo = item.kind == GalleryKind.video;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: 280,
                height: 280,
                child: isVideo ? _buildVideoTileContent(item) : _buildPhotoTileContent(item),
              ),
            ),
            if (isVideo)
              const Positioned(
                right: 6,
                top: 6,
                child: IgnorePointer(
                  child: Icon(Icons.play_circle_fill_rounded, size: 20, color: Colors.white),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 14, 6, 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                  child: Text(
                    _fmtDate(item.time),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // The grid always renders tiles at a fixed 280x280 logical box (scaled down
  // via FittedBox to whatever the actual cell size is), so without this the
  // image would always decode at the chat-bubble's full 560px width even
  // when 6 columns are showing — wasted decode work that's the main cause of
  // janky/black thumbnails while scrolling a dense, zoomed-out grid fast.
  int get _thumbCacheWidth {
    final cellWidth = MediaQuery.of(context).size.width / _columns;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return (cellWidth * dpr).round().clamp(80, 560);
  }

  Widget _buildPhotoTileContent(GalleryItem item) {
    final data =
        jsonDecode(item.content.substring('IMAGEv1:'.length)) as Map<String, dynamic>;
    final filename = data['url'] as String? ?? data['filename'] as String? ?? '';
    return ImageMessageWidget(
      filename: filename,
      owner: data['owner'] as String?,
      peerUsername: widget.peerUsername,
      mediaKeyB64: data['key'] as String?,
      blurHash: data['blur'] as String?,
      cacheWidth: _thumbCacheWidth,
      initialAspectRatio: (data['ar'] as num?)?.toDouble(),
    );
  }

  Widget _buildVideoTileContent(GalleryItem item) {
    final data =
        jsonDecode(item.content.substring('VIDEOv1:'.length)) as Map<String, dynamic>;
    final filename = data['url'] as String? ?? data['filename'] as String? ?? '';
    return VideoMessageWidget(
      filename: filename,
      owner: data['owner'] as String?,
      peerUsername: widget.peerUsername,
      mediaKeyB64: data['key'] as String?,
      blurHash: data['blur'] as String?,
      initialAspectRatio: (data['ar'] as num?)?.toDouble(),
    );
  }

  // ── Voice tab ────────────────────────────────────────────────────────────

  Widget _buildVoiceTab(AppLocalizations l, ColorScheme cs) {
    final voice = _voice;
    if (voice.isEmpty) {
      return _buildEmptyState(Icons.mic_none_rounded, l.galleryEmptyVoice);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(cs, voice.length),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: voice.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final item = voice[i];
              final data = jsonDecode(item.content.substring(item.content.indexOf(':') + 1))
                  as Map<String, dynamic>;
              final filename = data['url'] as String? ?? data['filename'] as String? ?? '';
              return AdaptiveGlassCard(
                borderRadius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmtDateTime(item.time),
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 4),
                    VoiceMessagePlayer(
                      filename: filename,
                      owner: data['owner'] as String?,
                      label: '',
                      peerUsername: widget.peerUsername,
                      mediaKeyB64: data['key'] as String?,
                      isFile: item.content.startsWith('AUDIOv1:'),
                      origName: data['orig'] as String?,
                      expand: true,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Files tab ────────────────────────────────────────────────────────────

  Widget _buildFilesTab(AppLocalizations l, ColorScheme cs) {
    final files = _files;
    if (files.isEmpty) {
      return _buildEmptyState(Icons.insert_drive_file_outlined, l.galleryEmptyFiles);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(cs, files.length),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: files.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final item = files[i];
              final data = jsonDecode(item.content.substring('FILEv1:'.length))
                  as Map<String, dynamic>;
              return AdaptiveGlassCard(
                borderRadius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 2),
                      child: Text(
                        _fmtDateTime(item.time),
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                      ),
                    ),
                    FileMessageWidget(
                      filename: data['filename'] as String? ?? '',
                      owner: data['owner'] as String?,
                      peerUsername: widget.peerUsername,
                      isOutgoing: false,
                      mediaKeyB64: data['key'] as String?,
                      directUrl: data['directUrl'] as String?,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
