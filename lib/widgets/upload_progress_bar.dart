// lib/widgets/upload_progress_bar.dart
//
// Slim progress indicator shown above the chat input — replaces the old
// per-message "pending upload" bubble that used to sit inline in the
// message list (blurred image thumbnail + circular progress). Lives in the
// same Column slot as the reply/edit preview, just below it, so the two
// never overlap — only one or both stack vertically when both are active.
//
// Works for every UploadTask.type ('image' | 'video' | 'voice' | 'audio' |
// 'file'): shows a type icon, an "Uploading <type>..." label and a thin
// LinearProgressIndicator. When more than one upload is in flight at once
// (e.g. a file send fired while a previous one is still uploading) it
// collapses into a single summary bar — "Uploading file (1/3)" — with the
// combined average progress, instead of stacking N separate bars and
// pushing the input field around.
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../managers/settings_manager.dart';
import '../utils/upload_task.dart';

class UploadProgressBar extends StatelessWidget {
  final List<UploadTask> tasks;
  final double maxWidth;

  /// Cancels every task currently represented by this bar.
  final VoidCallback? onCancelAll;

  /// When true the bar shows the real percentage from each task's progress
  /// (presign S3 uploads, which report byte-level progress). When false
  /// (catbox / multipart uploads, which don't) it shows an indeterminate
  /// bar instead — no percentage text, no real `value` on the indicator.
  final bool showProgress;

  const UploadProgressBar({
    super.key,
    required this.tasks,
    required this.maxWidth,
    this.onCancelAll,
    this.showProgress = true,
  });

  static IconData _iconFor(String type) {
    switch (type) {
      case 'image':
        return Icons.image_outlined;
      case 'video':
        return Icons.videocam_outlined;
      case 'voice':
        return Icons.mic_none_rounded;
      case 'audio':
        return Icons.audiotrack_rounded;
      case 'album':
        return Icons.photo_library_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  static String _labelFor(AppLocalizations loc, String type) {
    switch (type) {
      case 'image':
        return loc.uploadingImageLabel;
      case 'video':
        return loc.uploadingVideoLabel;
      case 'voice':
        return loc.uploadingVoice;
      case 'audio':
        return loc.uploadingAudioLabel;
      default:
        return loc.uploadingFileLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    return ListenableBuilder(
      // Each UploadTask reports progress via its own notifier (no parent
      // setState per byte chunk) — merging them here is what makes this bar
      // auto-rebuild as bytes go out, same pattern as the old card used.
      listenable: Listenable.merge([
        SettingsManager.elementBrightness,
        SettingsManager.elementOpacity,
        for (final t in tasks) t.progressNotifier,
        for (final t in tasks) t.statusNotifier,
        for (final t in tasks) t.albumDoneNotifier,
      ]),
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final brightness = SettingsManager.elementBrightness.value;
        final opacity = SettingsManager.elementOpacity.value;
        final baseColor = SettingsManager.getElementColor(
          cs.surfaceContainerHighest,
          brightness,
        );

        final loc = AppLocalizations(SettingsManager.appLocale.value);
        final count = tasks.length;
        final primary = tasks.first;
        final anyFailed = tasks.any((t) => t.status == UploadStatus.failed);
        final avgProgress =
            tasks.fold<double>(0, (sum, t) => sum + t.progress) / count;
        final pct = (avgProgress * 100).clamp(0, 100).toInt();

        final isAlbum = primary.type == 'album';
        final albumDone = isAlbum ? primary.albumDone : 0;
        final albumTotal = isAlbum ? primary.albumTotal : 1;
        final albumProgress = isAlbum && albumTotal > 0
            ? albumDone / albumTotal
            : avgProgress;

        final baseLabel = isAlbum
            ? loc.uploadingAlbumProgress(albumDone, albumTotal)
            : _labelFor(loc, primary.type);
        final label = count > 1 ? '$baseLabel (1/$count)' : baseLabel;

        return Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _iconFor(primary.type),
                color: anyFailed ? cs.error : cs.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      anyFailed ? loc.uploadFailed : label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: anyFailed
                            ? 1.0
                            : (isAlbum || showProgress ? albumProgress : null),
                        backgroundColor: cs.onSurface.withValues(alpha: 0.12),
                        color: anyFailed ? cs.error : cs.primary,
                        minHeight: 3,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAlbum) ...[
                const SizedBox(width: 10),
                Text(
                  '$albumDone/$albumTotal',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ] else if (showProgress) ...[
                const SizedBox(width: 10),
                Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
              if (onCancelAll != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onCancelAll,
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
