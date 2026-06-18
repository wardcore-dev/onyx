import 'package:flutter/material.dart';

/// Centered "no messages yet" placeholder shown in an empty chat, shared by
/// every chat-like screen (1:1, groups, external groups, favorites) so they
/// all look the same instead of each having their own plain/bare text.
class EmptyChatPlaceholder extends StatelessWidget {
  const EmptyChatPlaceholder({super.key, required this.label, this.hint});

  /// Bold title line (e.g. "No messages yet").
  final String label;

  /// Optional muted subtitle line below the title (e.g. a hint to send the
  /// first message). Falls back to nothing if omitted.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: cs.primary.withValues(alpha: 0.08),
            ),
            child: Icon(
              Icons.forum_outlined,
              size: 28,
              color: cs.primary.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.62),
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                hint!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.38),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
