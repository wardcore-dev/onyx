import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'onyx_dialog.dart';

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
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    void cancel() {
      Navigator.pop(context);
      onCancel();
    }

    return OnyxDialogShell(
      maxWidth: 400,
      radius: kOnyxPanelRadius,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnyxDialogHeader(
            leading: const OnyxHeaderBadge(Icons.mic),
            title: OnyxHeaderTitle(l.mediaSendVoiceTitle),
            onClose: cancel,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.30),
                        width: 2,
                      ),
                    ),
                    child: Icon(Icons.mic, size: 44, color: cs.primary),
                  ),
                ),
                const SizedBox(height: 20),
                OnyxDetailsPanel(
                  title: l.mediaSendVoiceHeading,
                  rows: [
                    (l.mediaSendDuration, _formatDuration(duration)),
                    (l.mediaSendType, 'Audio (M4A)'),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  l.mediaSendConfirmVoice,
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
          OnyxConfirmButtons(
            confirmLabel: l.sendVoice,
            onConfirm: () {
              Navigator.pop(context);
              onSend();
            },
            cancelLabel: l.cancel,
            onCancel: cancel,
          ),
        ],
      ),
    );
  }
}
