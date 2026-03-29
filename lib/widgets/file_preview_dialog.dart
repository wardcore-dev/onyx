import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../managers/settings_manager.dart';

class FilePreviewDialog extends StatefulWidget {
  final String filePath;
  final Uint8List? fileBytes;
  final VoidCallback onSend;
  final VoidCallback onCancel;
  /// Called when the user presses Ctrl+V while the dialog is open.
  /// Returns the path to the pasted image temp file, or null if nothing.
  final Future<String?> Function()? onPasteExtra;
  /// Called instead of [onSend] when the user has pasted extra images (album mode).
  final void Function(List<String>)? onSendAlbum;

  const FilePreviewDialog({
    Key? key,
    required this.filePath,
    this.fileBytes,
    required this.onSend,
    required this.onCancel,
    this.onPasteExtra,
    this.onSendAlbum,
  }) : super(key: key);

  @override
  State<FilePreviewDialog> createState() => _FilePreviewDialogState();
}

class _FilePreviewDialogState extends State<FilePreviewDialog> {
  late final String _filename;
  late final String _extension;
  late String _fileSize = '—';
  Uint8List? _previewBytes;

  /// Non-empty only when the initial file is an image and album support is enabled.
  final List<String> _albumPaths = [];

  bool get _isAlbumMode => _albumPaths.length > 1;

  @override
  void initState() {
    super.initState();
    _filename = p.basename(widget.filePath);
    _extension = p.extension(_filename).toLowerCase();
    if (_isImageFile() && widget.onPasteExtra != null) {
      _albumPaths.add(widget.filePath);
      HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    }
    _loadFileInfo();
  }

  @override
  void dispose() {
    if (widget.onPasteExtra != null && _isImageFile()) {
      HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    }
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyV &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      _pasteImage();
      return true;
    }
    return false;
  }

  Future<void> _pasteImage() async {
    if (widget.onPasteExtra == null) return;
    final path = await widget.onPasteExtra!();
    if (path == null || !mounted) return;
    setState(() => _albumPaths.add(path));
  }

  Future<void> _loadFileInfo() async {
    try {
      late final int fileSize;
      if (kIsWeb && widget.fileBytes != null) {
        fileSize = widget.fileBytes!.length;
        _previewBytes = widget.fileBytes;
      } else if (!kIsWeb) {
        final file = File(widget.filePath);
        if (await file.exists()) {
          fileSize = await file.length();
          if (_isImageFile()) {
            _previewBytes = await file.readAsBytes();
          }
        } else {
          fileSize = 0;
        }
      } else {
        fileSize = 0;
      }

      _fileSize = _formatFileSize(fileSize);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading file info: $e');
    }
  }

  bool _isImageFile() {
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.svg']
        .contains(_extension);
  }

  bool _isVideoFile() {
    return ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.flv', '.m4v']
        .contains(_extension);
  }

  bool _isAudioFile() {
    return ['.mp3', '.wav', '.aac', '.m4a', '.flac', '.ogg', '.wma']
        .contains(_extension);
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (bytes.toString().length - 1) ~/ 3;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(2)} ${suffixes[i]}';
  }

  IconData _getFileIcon() {
    if (_isImageFile()) return Icons.image;
    if (_isVideoFile()) return Icons.video_camera_back;
    if (['.mp3', '.wav', '.aac', '.m4a', '.flac', '.ogg', '.wma']
        .contains(_extension)) return Icons.audio_file;
    if (['.pdf'].contains(_extension)) return Icons.picture_as_pdf;
    if (['.doc', '.docx'].contains(_extension)) return Icons.description;
    if (['.xls', '.xlsx'].contains(_extension)) return Icons.table_chart;
    if (['.ppt', '.pptx'].contains(_extension)) return Icons.slideshow;
    if (['.zip', '.rar', '.7z', '.tar', '.gz'].contains(_extension))
      return Icons.folder_zip;
    if (['.txt', '.rtf', '.json', '.xml', '.csv'].contains(_extension))
      return Icons.text_snippet;
    return Icons.attach_file;
  }

  // ── Album grid ────────────────────────────────────────────────────────────

  Widget _buildAlbumGrid(ColorScheme cs) {
    final count = _albumPaths.length;
    final thumbPaths = _albumPaths.take(4).toList();
    final extra = count - 4;

    if (thumbPaths.length == 1) {
      return _albumThumb(thumbPaths[0], 200, 200, extra: 0, cs: cs);
    }

    const cellSize = 98.0;
    return SizedBox(
      width: cellSize * 2 + 4,
      height: cellSize * 2 + 4,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (int i = 0; i < thumbPaths.length; i++)
            _albumThumb(
              thumbPaths[i],
              cellSize,
              cellSize,
              extra: (i == thumbPaths.length - 1 && extra > 0) ? extra : 0,
              cs: cs,
            ),
        ],
      ),
    );
  }

  Widget _albumThumb(
    String filePath,
    double w,
    double h, {
    required int extra,
    required ColorScheme cs,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
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
                child: Icon(Icons.broken_image, color: cs.onSurfaceVariant),
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

  // ── Preview section ───────────────────────────────────────────────────────

  Widget _buildPreview(ThemeData theme, ColorScheme colorScheme, double elemOpacity, Color surfaceBg) {
    final border = Border.all(color: colorScheme.outline.withValues(alpha: 0.25 * elemOpacity));
    final radius = BorderRadius.circular(12);

    // ── Album mode ─────────────────────────────────────────────────────────
    if (_isAlbumMode) {
      return Container(
        decoration: BoxDecoration(border: border, borderRadius: radius),
        padding: const EdgeInsets.all(8),
        child: Center(child: _buildAlbumGrid(colorScheme)),
      );
    }

    // ── Image ──────────────────────────────────────────────────────────────
    if (_isImageFile() && _previewBytes != null) {
      return ClipRRect(
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 320),
          decoration: BoxDecoration(border: border, borderRadius: radius),
          child: Image.memory(_previewBytes!, fit: BoxFit.contain),
        ),
      );
    }

    // ── Image loading placeholder ──────────────────────────────────────────
    if (_isImageFile() && _previewBytes == null) {
      return Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(color: surfaceBg, borderRadius: radius, border: border),
        child: Center(
          child: CircularProgressIndicator(color: colorScheme.primary, strokeWidth: 2),
        ),
      );
    }

    // ── Video ──────────────────────────────────────────────────────────────
    if (_isVideoFile()) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: surfaceBg,
          borderRadius: radius,
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.3 * elemOpacity),
          ),
        ),
        child: Center(
          child: Icon(Icons.play_circle_outline, size: 48, color: colorScheme.primary),
        ),
      );
    }

    // ── Audio ──────────────────────────────────────────────────────────────
    if (_isAudioFile()) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: surfaceBg,
          borderRadius: radius,
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.3 * elemOpacity),
          ),
        ),
        child: Center(
          child: Icon(_getFileIcon(), size: 48, color: colorScheme.primary),
        ),
      );
    }

    // ── Generic file ───────────────────────────────────────────────────────
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: surfaceBg,
        borderRadius: radius,
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.3 * elemOpacity),
        ),
      ),
      child: Center(
        child: Icon(_getFileIcon(), size: 48, color: colorScheme.primary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final count = _albumPaths.length;

    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementOpacity,
      builder: (_, elemOpacity, __) {
        return ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementBrightness,
          builder: (_, brightness, ___) {
            final surfaceHighestColor = SettingsManager.getElementColor(
              colorScheme.surfaceContainerHighest,
              brightness,
            );
            return Dialog(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header ──────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1 * elemOpacity),
                        border: Border(
                          bottom: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.2 * elemOpacity),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isAlbumMode
                                ? Icons.photo_library_outlined
                                : Icons.attach_file,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _isAlbumMode ? 'Send Album' : 'Send File',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Preview ────────────────────────────────────────
                          _buildPreview(theme, colorScheme, elemOpacity, surfaceHighestColor),

                          const SizedBox(height: 24),

                          // ── Info box ───────────────────────────────────────
                          if (_isAlbumMode)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: surfaceHighestColor.withValues(alpha: 1.0),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.outline.withValues(alpha: 0.2 * elemOpacity),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.collections_outlined,
                                      size: 20, color: colorScheme.primary),
                                  const SizedBox(width: 12),
                                  Text(
                                    '$count ${count == 1 ? 'image' : 'images'} selected',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: surfaceHighestColor.withValues(alpha: 1.0),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.outline.withValues(alpha: 0.2 * elemOpacity),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'File Details',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Text(
                                        'Name:',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: SelectableText(
                                          _filename,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        'Size:',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _fileSize,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        'Type:',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _extension.isEmpty
                                            ? 'Unknown'
                                            : _extension.toUpperCase(),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 24),

                          // ── Confirm / hint text ────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.1 * elemOpacity),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: colorScheme.primary.withValues(alpha: 0.3 * elemOpacity),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info,
                                  size: 18,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _isAlbumMode
                                        ? 'Are you sure you want to send these images as an album?'
                                        : 'Are you sure you want to send this file?',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Action buttons ─────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.2 * elemOpacity),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onCancel();
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.tonal(
                            onPressed: () {
                              Navigator.pop(context);
                              if (_isAlbumMode && widget.onSendAlbum != null) {
                                widget.onSendAlbum!(List<String>.from(_albumPaths));
                              } else {
                                widget.onSend();
                              }
                            },
                            child: Text(_isAlbumMode ? 'Send Album' : 'Send File'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
