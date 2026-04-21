// lib/widgets/message_reaction_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'emoji_picker_dialog.dart';
import '../managers/settings_manager.dart';

/// A bar that shows emoji reaction chips below a message bubble.
///
/// [reactions] maps emoji → list of usernames who reacted.
/// [myUsername] is used to determine if the current user already reacted.
/// [onToggle] is called with the emoji when a chip is tapped.
/// [onAddReaction] is called when the "+" button is pressed (receives context).
class MessageReactionBar extends StatelessWidget {
  final Map<String, List<String>> reactions;
  final String myUsername;
  final bool outgoing;
  final void Function(String emoji) onToggle;
  final void Function(BuildContext ctx) onAddReaction;

  const MessageReactionBar({
    super.key,
    required this.reactions,
    required this.myUsername,
    required this.outgoing,
    required this.onToggle,
    required this.onAddReaction,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    // Sort: emojis with higher count first; own reactions come first on ties.
    final sorted = reactions.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.length.compareTo(a.value.length);
        if (cmp != 0) return cmp;
        final aMe = a.value.contains(myUsername) ? 0 : 1;
        final bMe = b.value.contains(myUsername) ? 0 : 1;
        return aMe.compareTo(bMe);
      });

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        alignment: outgoing ? WrapAlignment.end : WrapAlignment.start,
        spacing: 4,
        runSpacing: 4,
        children: [
          ...sorted.map((e) => _ReactionChip(
                emoji: e.key,
                reactors: e.value,
                myUsername: myUsername,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onToggle(e.key);
                },
              )),
          _AddReactionButton(
            onTap: () => onAddReaction(context),
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }
}

// ─── Reaction chip ─────────────────────────────────────────────────────────────

class _ReactionChip extends StatelessWidget {
  final String emoji;
  final List<String> reactors;
  final String myUsername;
  final VoidCallback onTap;

  const _ReactionChip({
    required this.emoji,
    required this.reactors,
    required this.myUsername,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMine = reactors.contains(myUsername);
    final count = reactors.length;

    final tooltip = reactors.length <= 10
        ? reactors.join(', ')
        : '${reactors.take(10).join(', ')} +${reactors.length - 10}';

    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementBrightness,
      builder: (_, brightness, __) => ValueListenableBuilder<double>(
        valueListenable: SettingsManager.elementOpacity,
        builder: (_, opacity, __) {
          final baseColor = isMine
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest;
          final bgColor = SettingsManager.getElementColor(baseColor, brightness)
              .withValues(alpha: opacity);
          final borderColor = isMine
              ? colorScheme.primary.withValues(alpha: 0.6)
              : colorScheme.outline.withValues(alpha: 0.25);
          final textColor = isMine
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurface.withValues(alpha: 0.85);

          return Tooltip(
            message: tooltip,
            waitDuration: const Duration(milliseconds: 500),
            child: GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 14, height: 1.2)),
                    if (count > 1) ...[
                      const SizedBox(width: 4),
                      Text(
                        count.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── "+" add reaction button ────────────────────────────────────────────────

class _AddReactionButton extends StatelessWidget {
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _AddReactionButton({required this.onTap, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementBrightness,
      builder: (_, brightness, __) => ValueListenableBuilder<double>(
        valueListenable: SettingsManager.elementOpacity,
        builder: (_, opacity, __) {
          final bgColor = SettingsManager.getElementColor(
            colorScheme.surfaceContainerHighest, brightness,
          ).withValues(alpha: opacity);
          return GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_reaction_outlined,
                    size: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Mixin for screen-level reaction state ─────────────────────────────────────

/// Mixin that provides client-side reaction state management.
/// Mix into State classes for chat/group screens.
mixin ReactionStateMixin<T extends StatefulWidget> on State<T> {
  /// messageKey → emoji → [usernames]
  final Map<String, Map<String, List<String>>> _reactionState = {};

  Map<String, List<String>> reactionsFor(String key) =>
      _reactionState[key] ?? {};

  /// Seed reaction state from persisted data without triggering setState.
  /// Safe to call during build — only writes if the key is not yet present.
  void seedReactions(String key, Map<String, List<String>> persisted) {
    if (!_reactionState.containsKey(key) && persisted.isNotEmpty) {
      _reactionState[key] =
          persisted.map((e, u) => MapEntry(e, List<String>.from(u)));
    }
  }

  /// Returns true if myUsername already has this emoji on this message.
  bool hasReaction(String messageKey, String emoji, String myUsername) =>
      _reactionState[messageKey]?[emoji]?.contains(myUsername) == true;

  void toggleReaction(String messageKey, String emoji, String myUsername) {
    setState(() {
      final msgReactions = _reactionState.putIfAbsent(messageKey, () => {});
      final users = msgReactions.putIfAbsent(emoji, () => []);
      if (users.contains(myUsername)) {
        users.remove(myUsername);
        if (users.isEmpty) msgReactions.remove(emoji);
        if (msgReactions.isEmpty) _reactionState.remove(messageKey);
      } else {
        users.add(myUsername);
      }
    });
  }

  /// Replace local state for one message key with server-authoritative data.
  void applyReactionUpdate(String key, Map<String, dynamic> serverReactions) {
    if (!mounted) return;
    setState(() {
      if (serverReactions.isEmpty) {
        _reactionState.remove(key);
      } else {
        _reactionState[key] = serverReactions.map(
          (emoji, users) => MapEntry(emoji, List<String>.from(users as List)),
        );
      }
    });
  }

  /// Apply multiple reaction updates in a single setState (used after history load).
  void applyReactionBatch(Map<String, Map<String, dynamic>> updates) {
    if (!mounted || updates.isEmpty) return;
    setState(() {
      for (final entry in updates.entries) {
        if (entry.value.isEmpty) {
          _reactionState.remove(entry.key);
        } else {
          _reactionState[entry.key] = entry.value.map(
            (emoji, users) => MapEntry(emoji, List<String>.from(users as List)),
          );
        }
      }
    });
  }

  void openEmojiPicker(
    BuildContext ctx,
    String messageKey,
    String myUsername, {
    void Function(String emoji, bool wasReacted)? onAfterToggle,
  }) {
    EmojiPickerDialog.show(ctx, onSelected: (emoji) {
      final wasReacted = hasReaction(messageKey, emoji, myUsername);
      toggleReaction(messageKey, emoji, myUsername);
      onAfterToggle?.call(emoji, wasReacted);
    });
  }
}
