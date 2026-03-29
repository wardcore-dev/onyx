// lib/widgets/pending_upload_card.dart
//
// Reusable widget that shows a pending upload card inside the chat message list.
// Supports:
//   • Blurred image preview (like Telegram) for images
//   • Dark placeholder with progress bar for videos
//   • Icon + progress bar for files and voice messages
//   • showProgress=true  → circular indicator with % (presign S3 uploads)
//   • showProgress=false → indeterminate spinner (catbox / multipart uploads)
//   • Optional cancel callback
//
// The card auto-rebuilds when task.progressNotifier / task.statusNotifier
// change — no parent setState() needed for progress updates.
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../managers/settings_manager.dart';
import '../utils/upload_task.dart';

class PendingUploadCard extends StatelessWidget {
  final UploadTask task;
  final VoidCallback? onCancel;

  /// When true the indicator shows the real percentage from [task.progress].
  /// When false an indeterminate spinner is displayed (no percentage known).
  final bool showProgress;

  const PendingUploadCard({
    super.key,
    required this.task,
    this.onCancel,
    this.showProgress = true,
  });

  // ── helpers ─────────────────────────────────────────────────────────────────

  bool get _isFailed => task.status == UploadStatus.failed;

  Widget _cancelButton({bool forceWhite = false, required ColorScheme cs}) {
    if (onCancel == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onCancel,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: forceWhite
              ? Colors.white30
              : cs.onPrimaryContainer.withValues(alpha: 0.25),
        ),
        child: Icon(
          Icons.close,
          color: forceWhite ? Colors.white : cs.onPrimaryContainer,
          size: 16,
        ),
      ),
    );
  }

  // ── image ────────────────────────────────────────────────────────────────────
  Widget _buildImageContent(ColorScheme cs) {
    final pct = (task.progress * 100).toInt();
    return SizedBox(
      width: 200,
      height: 160,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Image.memory(
                task.previewBytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
          // Overlay with progress
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: Colors.black45,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 58,
                    height: 58,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: showProgress && !_isFailed ? task.progress : null,
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                        if (showProgress)
                          Text(
                            _isFailed ? '!' : '$pct%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _cancelButton(forceWhite: true, cs: cs),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── video ────────────────────────────────────────────────────────────────────
  Widget _buildVideoContent(ColorScheme cs, double brightness) {
    final pct = (task.progress * 100).toInt();
    final c1 = SettingsManager.getElementColor(Colors.blueGrey.shade800, brightness);
    final c2 = SettingsManager.getElementColor(Colors.blueGrey.shade900, brightness);
    return Container(
      width: 200,
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1, c2],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam, color: Colors.white60, size: 34),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              task.basename,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: showProgress && !_isFailed ? task.progress : null,
                backgroundColor: Colors.white24,
                color: Colors.white,
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            showProgress ? (_isFailed ? 'Failed' : '$pct%') : 'Uploading...',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 8),
          _cancelButton(forceWhite: true, cs: cs),
        ],
      ),
    );
  }

  // ── file / voice ─────────────────────────────────────────────────────────────
  Widget _buildFileContent(ColorScheme cs, double elemOpacity, double brightness) {
    final pct = (task.progress * 100).toInt();
    final icon = task.type == 'voice' ? Icons.mic : Icons.attach_file;
    final bgColor = SettingsManager.getElementColor(cs.primaryContainer, brightness);
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.9 * elemOpacity),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Filename row
          Row(
            children: [
              Icon(icon, color: cs.onPrimaryContainer, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.basename,
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: showProgress && !_isFailed ? task.progress : null,
              backgroundColor: cs.onPrimaryContainer.withValues(alpha: 0.2),
              color: cs.onPrimaryContainer,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 6),
          // Status + cancel
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                showProgress
                    ? (_isFailed ? 'Failed' : '$pct%')
                    : 'Uploading...',
                style: TextStyle(
                  color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
              if (onCancel != null)
                GestureDetector(
                  onTap: onCancel,
                  child: Icon(Icons.cancel_outlined,
                      color: cs.onPrimaryContainer, size: 22),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: Listenable.merge([
        task.progressNotifier,
        task.statusNotifier,
        SettingsManager.elementOpacity,
        SettingsManager.elementBrightness,
      ]),
      builder: (context, _) {
        final elemOpacity = SettingsManager.elementOpacity.value;
        final brightness  = SettingsManager.elementBrightness.value;

        Widget content;
        if (task.type == 'image' && task.previewBytes != null) {
          content = _buildImageContent(cs);
        } else if (task.type == 'video') {
          content = _buildVideoContent(cs, brightness);
        } else {
          content = _buildFileContent(cs, elemOpacity, brightness);
        }

        return Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            child: content,
          ),
        );
      },
    );
  }
}
