import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../managers/settings_manager.dart';

class FilePreviewDialog extends StatefulWidget {
  final String filePath;
  final Uint8List? fileBytes; 
  final VoidCallback onSend;
  final VoidCallback onCancel;

  const FilePreviewDialog({
    Key? key,
    required this.filePath,
    this.fileBytes,
    required this.onSend,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<FilePreviewDialog> createState() => _FilePreviewDialogState();
}

class _FilePreviewDialogState extends State<FilePreviewDialog> {
  late final String _filename;
  late final String _extension;
  late final String _fileSize;
  Uint8List? _previewBytes;

  @override
  void initState() {
    super.initState();
    _filename = p.basename(widget.filePath);
    _extension = p.extension(_filename).toLowerCase();
    _loadFileInfo();
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

  Widget _buildPreview(ThemeData theme, ColorScheme colorScheme, double elemOpacity, Color surfaceBg) {
    final border = Border.all(color: colorScheme.outline.withValues(alpha: 0.25 * elemOpacity));
    final radius = BorderRadius.circular(12);

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
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: border,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.18 * elemOpacity),
              colorScheme.secondary.withValues(alpha: 0.10 * elemOpacity),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_outline_rounded, size: 64, color: colorScheme.primary),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _filename,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _extension.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.primary),
            ),
          ],
        ),
      );
    }

    // ── Audio ──────────────────────────────────────────────────────────────
    if (_isAudioFile()) {
      return Container(
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: border,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.tertiary.withValues(alpha: 0.18 * elemOpacity),
              colorScheme.primary.withValues(alpha: 0.08 * elemOpacity),
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.audio_file_rounded, size: 56, color: colorScheme.tertiary),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _filename,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _extension.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.tertiary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Generic file ───────────────────────────────────────────────────────
    final icon = _getFileIcon();
    return Container(
      width: double.infinity,
      height: 140,
      decoration: BoxDecoration(color: surfaceBg, borderRadius: radius, border: border),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12 * elemOpacity),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 40, color: colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _filename,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _extension.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
          constraints: const BoxConstraints(
            maxWidth: 500,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1 * elemOpacity),
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.outline.withOpacity(0.2 * elemOpacity),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.attach_file, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Send File',
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
                      
                      _buildPreview(theme, colorScheme, elemOpacity, surfaceHighestColor),

                      const SizedBox(height: 24),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceHighestColor.withValues(alpha: 1.0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.2 * elemOpacity),
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
                                  _extension.isEmpty ? 'Unknown' : _extension.toUpperCase(),
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

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1 * elemOpacity),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.3 * elemOpacity),
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
                                'Are you sure you want to send this file?',
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

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: colorScheme.outline.withOpacity(0.2 * elemOpacity),
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
                          widget.onSend();
                        },
                        child: const Text('Send File'),
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