import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../managers/settings_manager.dart';
import '../l10n/app_localizations.dart';
import 'onyx_dialog.dart';

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
  final FocusNode _focusNode = FocusNode();

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
    }
    _loadFileInfo();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // Scoped to this dialog's own Focus node (autofocused on open) — NOT a
  // global HardwareKeyboard handler. A global handler reacts to an Enter
  // keydown from anywhere in the app for as long as the dialog is mounted
  // (e.g. a stray/buffered Enter left over from submitting the chat
  // composer moments earlier), which could silently auto-confirm "Send
  // File" without the user ever interacting with the dialog.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _confirmSend();
      return KeyEventResult.handled;
    }
    if (widget.onPasteExtra != null &&
        event.logicalKey == LogicalKeyboardKey.keyV &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      _pasteImage();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _confirmSend() {
    Navigator.pop(context);
    if (_isAlbumMode && widget.onSendAlbum != null) {
      widget.onSendAlbum!(List<String>.from(_albumPaths));
    } else {
      widget.onSend();
    }
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

  Widget _buildPreview(ThemeData theme, ColorScheme colorScheme,
      double elemOpacity, Color surfaceBg) {
    final border = Border.all(
        color: colorScheme.outline.withValues(alpha: 0.25 * elemOpacity));
    final radius = BorderRadius.circular(20);

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
        decoration: BoxDecoration(
            color: surfaceBg, borderRadius: radius, border: border),
        child: Center(
          child: CircularProgressIndicator(
              color: colorScheme.primary, strokeWidth: 2),
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
          child: Icon(Icons.play_circle_outline,
              size: 48, color: colorScheme.primary),
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
    final l = AppLocalizations.of(context);
    final title = _isAlbumMode ? l.sendAlbum : l.mediaSendFileTitle;
    void cancel() {
      Navigator.pop(context);
      widget.onCancel();
    }

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
            return Focus(
              focusNode: _focusNode,
              autofocus: true,
              onKeyEvent: _handleKeyEvent,
              child: OnyxDialogShell(
                maxWidth: 480,
                radius: kOnyxPanelRadius,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OnyxDialogHeader(
                      leading: OnyxHeaderBadge(_isAlbumMode
                          ? Icons.photo_library_outlined
                          : Icons.attach_file),
                      title: OnyxHeaderTitle(title),
                      onClose: cancel,
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: _buildPreview(theme, colorScheme,
                                  elemOpacity, surfaceHighestColor),
                            ),
                            const SizedBox(height: 16),
                            if (_isAlbumMode)
                              OnyxDetailsPanel(
                                title: l.mediaSendAlbumHeading,
                                rows: [
                                  (
                                    l.mediaSendImagesLabel,
                                    l.mediaSendImagesCount(count)
                                  ),
                                ],
                              )
                            else
                              OnyxDetailsPanel(
                                title: l.mediaSendFileDetails,
                                rows: [
                                  (l.mediaSendName, _filename),
                                  (l.mediaSendSize, _fileSize),
                                  (
                                    l.mediaSendType,
                                    _extension.isEmpty
                                        ? l.mediaSendUnknown
                                        : _extension.toUpperCase()
                                  ),
                                ],
                              ),
                            const SizedBox(height: 16),
                            Text(
                              _isAlbumMode
                                  ? l.mediaSendConfirmAlbum
                                  : l.mediaSendConfirmFile,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    OnyxConfirmButtons(
                      confirmLabel: title,
                      onConfirm: _confirmSend,
                      cancelLabel: l.cancel,
                      onCancel: cancel,
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
