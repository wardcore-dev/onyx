import 'package:flutter/material.dart';
import '../managers/settings_manager.dart';

class VoiceConfirmDialog extends StatelessWidget {
  final Duration duration;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  const VoiceConfirmDialog({
    Key? key,
    required this.duration,
    required this.onSend,
    required this.onCancel,
  }) : super(key: key);

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
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
                      Icon(Icons.mic, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Send Voice Message',
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
                      
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1 * elemOpacity),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.3 * elemOpacity),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.mic,
                            size: 48,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),

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
                              'Voice Message Details',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  'Duration:',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatDuration(duration),
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
                                  'Audio (M4A)',
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
                                'Send this voice message?',
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
                          onCancel();
                        },
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonal(
                        onPressed: () {
                          Navigator.pop(context);
                          onSend();
                        },
                        child: const Text('Send Voice'),
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