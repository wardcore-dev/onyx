// lib/widgets/album_preview_dialog.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import 'onyx_dialog.dart';

class AlbumPreviewDialog extends StatefulWidget {
  
  final List<String> filePaths;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  const AlbumPreviewDialog({
    super.key,
    required this.filePaths,
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<AlbumPreviewDialog> createState() => _AlbumPreviewDialogState();
}

class _AlbumPreviewDialogState extends State<AlbumPreviewDialog> {

  static const int _maxThumb = 4;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      _confirmSend();
      return true;
    }
    return false;
  }

  void _confirmSend() {
    Navigator.pop(context);
    widget.onSend();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);
    final count = widget.filePaths.length;
    final thumbPaths = widget.filePaths.take(_maxThumb).toList();
    final extra = count - _maxThumb;

    void cancel() {
      Navigator.pop(context);
      widget.onCancel();
    }

    return OnyxDialogShell(
      maxWidth: 480,
      radius: kOnyxPanelRadius,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnyxDialogHeader(
            leading: const OnyxHeaderBadge(Icons.photo_library_outlined),
            title: OnyxHeaderTitle(l.sendAlbum),
            onClose: cancel,
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: _buildGrid(thumbPaths, extra, cs)),
                  const SizedBox(height: 16),
                  OnyxDetailsPanel(
                    title: l.mediaSendAlbumHeading,
                    rows: [
                      (l.mediaSendImagesLabel, l.mediaSendImagesCount(count)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l.mediaSendConfirmAlbum,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          OnyxConfirmButtons(
            confirmLabel: l.sendAlbum,
            onConfirm: _confirmSend,
            cancelLabel: l.cancel,
            onCancel: cancel,
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<String> paths, int extra, ColorScheme cs) {
    if (paths.isEmpty) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(Icons.photo_library_outlined,
            size: 48, color: cs.primary),
      );
    }

    if (paths.length == 1) {
      return _thumb(paths[0], 200, 200, extra: 0, cs: cs);
    }

    final cellSize = 98.0;
    return SizedBox(
      width: cellSize * 2 + 4,
      height: cellSize * 2 + 4,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (int i = 0; i < paths.length; i++)
            _thumb(
              paths[i],
              cellSize,
              cellSize,
              extra: i == paths.length - 1 ? extra : 0,
              cs: cs,
            ),
        ],
      ),
    );
  }

  Widget _thumb(
    String filePath,
    double w,
    double h, {
    required int extra,
    required ColorScheme cs,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(w > 150 ? 20 : 14),
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(filePath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: cs.surfaceContainerHighest,
                child: Icon(Icons.broken_image,
                    color: cs.onSurfaceVariant),
              ),
            ),
            if (extra > 0)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Text(
                    '+$extra',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Single confirmation for a drop/paste that will be split into several
/// album messages (e.g. dragging in hundreds of photos at once). Replaces
/// showing one [AlbumPreviewDialog] per album, which was the source of
/// heavy per-album lag (route transition + full-res thumbnail decode)
/// when sending thousands of images.
class BulkAlbumConfirmDialog extends StatefulWidget {
  final int imageCount;
  final int albumCount;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  const BulkAlbumConfirmDialog({
    super.key,
    required this.imageCount,
    required this.albumCount,
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<BulkAlbumConfirmDialog> createState() =>
      _BulkAlbumConfirmDialogState();
}

class _BulkAlbumConfirmDialogState extends State<BulkAlbumConfirmDialog> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      _confirmSend();
      return true;
    }
    return false;
  }

  void _confirmSend() {
    Navigator.pop(context);
    widget.onSend();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return OnyxDialogShell(
      maxWidth: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnyxDialogHeader(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.photo_library_outlined, size: 20, color: cs.primary),
            ),
            title: Text(
              l.sendAlbums,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            onClose: () {
              Navigator.pop(context);
              widget.onCancel();
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              'Send ${widget.imageCount} images as ${widget.albumCount} albums?',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: _confirmSend,
                  style: FilledButton.styleFrom(
                    padding: kOnyxDialogButtonPadding,
                    shape: kOnyxDialogButtonShape,
                  ),
                  child: Text(l.sendAllMedia),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onCancel();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: kOnyxDialogButtonPadding,
                    shape: kOnyxDialogButtonShape,
                  ),
                  child: Text(l.cancel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}