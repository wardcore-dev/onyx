// lib/widgets/album_preview_dialog.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../managers/settings_manager.dart';

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final count = widget.filePaths.length;
    final thumbPaths = widget.filePaths.take(_maxThumb).toList();
    final extra = count - _maxThumb;

    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementOpacity,
      builder: (_, elemOpacity, __) {
        return ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementBrightness,
          builder: (_, brightness, ___) {
            final surfaceColor = SettingsManager.getElementColor(
              cs.surfaceContainerHighest,
              brightness,
            );
            return Dialog(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1 * elemOpacity),
                        border: Border(
                          bottom: BorderSide(
                            color: cs.outline.withValues(alpha: 0.2 * elemOpacity),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.photo_library_outlined,
                              color: cs.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Send Album',
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
                          
                          _buildGrid(thumbPaths, extra, cs),

                          const SizedBox(height: 24),

                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: cs.outline.withValues(
                                    alpha: 0.2 * elemOpacity),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.collections_outlined,
                                    size: 20, color: cs.primary),
                                const SizedBox(width: 12),
                                Text(
                                  '$count ${count == 1 ? 'image' : 'images'} selected',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(
                                  alpha: 0.1 * elemOpacity),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: cs.primary.withValues(
                                    alpha: 0.3 * elemOpacity),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info,
                                    size: 18, color: cs.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Are you sure you want to send these images as an album?',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: cs.onSurface),
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
                            color: cs.outline.withValues(alpha: 0.2 * elemOpacity),
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
                            child: const Text('Send Album'),
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

  Widget _buildGrid(List<String> paths, int extra, ColorScheme cs) {
    if (paths.isEmpty) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
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