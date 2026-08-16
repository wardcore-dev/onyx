// lib/widgets/message_reaction_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'emoji_picker_dialog.dart';
import '../managers/settings_manager.dart';

/// Normalized reaction data for one emoji, computed from whatever shape the
/// server sent for that message:
///  - Private (1:1) reactions arrive as a raw `List` of usernames — reactor
///    identity is meaningful there (only two people in the conversation).
///  - Group/channel reactions arrive as a `{count, reactedByMe}` map —
///    reactions are anonymous by design, so no reactor names ever exist to
///    show, even in a tooltip.
class _ReactionData {
  final int count;
  final bool reactedByMe;
  final List<String>? reactors;

  const _ReactionData({
    required this.count,
    required this.reactedByMe,
    this.reactors,
  });

  factory _ReactionData.fromRaw(dynamic raw, String myUsername) {
    if (raw is List) {
      final list = List<String>.from(raw);
      return _ReactionData(
        count: list.length,
        reactedByMe: list.contains(myUsername),
        reactors: list,
      );
    }
    if (raw is Map) {
      return _ReactionData(
        count: (raw['count'] as num?)?.toInt() ?? 0,
        reactedByMe: raw['reactedByMe'] == true,
      );
    }
    return const _ReactionData(count: 0, reactedByMe: false);
  }
}

/// A bar that shows emoji reaction chips below a message bubble.
///
/// [reactions] maps emoji → either a list of usernames (private/1:1
/// messages) or a `{count, reactedByMe}` map (anonymous group/channel
/// reactions) — see [_ReactionData.fromRaw].
/// [myUsername] is used to determine if the current user already reacted.
/// [onToggle] is called with the emoji when a chip is tapped.
/// [onAddReaction] is called when the "+" button is pressed (receives context).
class MessageReactionBar extends StatelessWidget {
  final Map<String, dynamic> reactions;
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

    final entries = reactions.entries
        .map((e) => MapEntry(e.key, _ReactionData.fromRaw(e.value, myUsername)))
        .toList();

    // Sort: emojis with higher count first; own reactions come first on ties.
    entries.sort((a, b) {
      final cmp = b.value.count.compareTo(a.value.count);
      if (cmp != 0) return cmp;
      final aMe = a.value.reactedByMe ? 0 : 1;
      final bMe = b.value.reactedByMe ? 0 : 1;
      return aMe.compareTo(bMe);
    });

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        alignment: outgoing ? WrapAlignment.end : WrapAlignment.start,
        spacing: 4,
        runSpacing: 4,
        children: [
          ...entries.map((e) => _ReactionChip(
                emoji: e.key,
                data: e.value,
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
  final _ReactionData data;
  final VoidCallback onTap;

  const _ReactionChip({
    required this.emoji,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMine = data.reactedByMe;
    final count = data.count;
    final reactors = data.reactors;

    // Only private (1:1) reactions carry reactor names — group/channel
    // reactions are anonymous, so there's nothing to show in a tooltip.
    final tooltip = (reactors == null || reactors.isEmpty)
        ? null
        : (reactors.length <= 10
            ? reactors.join(', ')
            : '${reactors.take(10).join(', ')} +${reactors.length - 10}');

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

          final chip = GestureDetector(
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
          );

          if (tooltip == null) return chip;
          return Tooltip(
            message: tooltip,
            waitDuration: const Duration(milliseconds: 500),
            child: chip,
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
  /// messageKey → emoji → raw reaction data as sent by the server: a
  /// `List` of usernames for private (1:1) messages, or a
  /// `{count, reactedByMe}` map for anonymous group/channel reactions.
  final Map<String, Map<String, dynamic>> _reactionState = {};

  Map<String, dynamic> reactionsFor(String key) => _reactionState[key] ?? {};

  /// Seed reaction state from persisted data without triggering setState.
  /// Safe to call during build — only writes if the key is not yet present.
  void seedReactions(String key, Map<String, dynamic> persisted) {
    if (!_reactionState.containsKey(key) && persisted.isNotEmpty) {
      _reactionState[key] = Map<String, dynamic>.from(persisted);
    }
  }

  /// Returns true if myUsername already has this emoji on this message.
  bool hasReaction(String messageKey, String emoji, String myUsername) {
    final raw = _reactionState[messageKey]?[emoji];
    if (raw is List) return raw.contains(myUsername);
    if (raw is Map) return raw['reactedByMe'] == true;
    return false;
  }

  /// Optimistically toggle a reaction before the server confirms it.
  /// [anonymous] must be true for group/channel reactions (which use the
  /// `{count, reactedByMe}` shape) and false for private/1:1 reactions
  /// (which use a plain username list). The server response that follows
  /// (via [applyReactionUpdate]) is always the source of truth.
  void toggleReaction(String messageKey, String emoji, String myUsername,
      {bool anonymous = false}) {
    setState(() {
      final msgReactions = _reactionState.putIfAbsent(messageKey, () => {});
      if (anonymous) {
        final raw = msgReactions[emoji];
        final count = raw is Map ? ((raw['count'] as num?)?.toInt() ?? 0) : 0;
        final reactedByMe = raw is Map && raw['reactedByMe'] == true;
        if (reactedByMe) {
          final newCount = count - 1;
          if (newCount <= 0) {
            msgReactions.remove(emoji);
          } else {
            msgReactions[emoji] = {'count': newCount, 'reactedByMe': false};
          }
        } else {
          msgReactions[emoji] = {'count': count + 1, 'reactedByMe': true};
        }
      } else {
        final existing = msgReactions[emoji];
        final users = existing is List ? List<String>.from(existing) : <String>[];
        if (users.contains(myUsername)) {
          users.remove(myUsername);
        } else {
          users.add(myUsername);
        }
        if (users.isEmpty) {
          msgReactions.remove(emoji);
        } else {
          msgReactions[emoji] = users;
        }
      }
      if (msgReactions.isEmpty) _reactionState.remove(messageKey);
    });
  }

  /// Replace local state for one message key with server-authoritative data.
  /// Only use this for the direct HTTP response to OUR OWN add/remove call —
  /// that's the one place `reactedByMe` is actually truthful for us. See
  /// [applyReactionCounts] for WebSocket broadcasts, which cannot make that
  /// promise.
  void applyReactionUpdate(String key, Map<String, dynamic> serverReactions) {
    if (!mounted) return;
    setState(() {
      if (serverReactions.isEmpty) {
        _reactionState.remove(key);
      } else {
        _reactionState[key] = Map<String, dynamic>.from(serverReactions);
      }
    });
  }

  /// Apply a reaction update that arrived via WebSocket broadcast.
  ///
  /// Group/channel reaction broadcasts are anonymous by design — the server
  /// fans the same packet out to every subscriber, so it can only ever
  /// report `reactedByMe: false` in it (see rust `messages.rs`
  /// `add_reaction`/`remove_reaction`, which broadcast a viewer-less
  /// `load_reactions_map`). Feeding that straight into [applyReactionUpdate]
  /// would stomp on our own just-confirmed state: right after we add a
  /// reaction, the broadcast echo arrives and reports `reactedByMe: false`,
  /// making our own reaction look unset — so the next tap tries to add
  /// again instead of removing, i.e. removing a reaction silently never
  /// works. Only `count` is trustworthy from a broadcast; `reactedByMe` is
  /// preserved from whatever we already know locally (set by our own
  /// optimistic toggle / the HTTP response to our own call).
  void applyReactionCounts(String key, Map<String, dynamic> serverReactions) {
    if (!mounted) return;
    setState(() {
      if (serverReactions.isEmpty) {
        _reactionState.remove(key);
        return;
      }
      final current = _reactionState[key] ?? const <String, dynamic>{};
      final merged = <String, dynamic>{};
      for (final entry in serverReactions.entries) {
        final raw = entry.value;
        if (raw is Map) {
          final count = (raw['count'] as num?)?.toInt() ?? 0;
          final existingRaw = current[entry.key];
          final knownReactedByMe =
              existingRaw is Map && existingRaw['reactedByMe'] == true;
          merged[entry.key] = {'count': count, 'reactedByMe': knownReactedByMe};
        } else {
          // Non-anonymous (private 1:1) shape carries real usernames and is
          // authoritative as broadcast — trust it as-is.
          merged[entry.key] = raw;
        }
      }
      _reactionState[key] = merged;
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
          _reactionState[entry.key] = Map<String, dynamic>.from(entry.value);
        }
      }
    });
  }

  void openEmojiPicker(
    BuildContext ctx,
    String messageKey,
    String myUsername, {
    void Function(String emoji, bool wasReacted)? onAfterToggle,
    bool anonymous = false,
  }) {
    EmojiPickerDialog.show(ctx, onSelected: (emoji) {
      final wasReacted = hasReaction(messageKey, emoji, myUsername);
      toggleReaction(messageKey, emoji, myUsername, anonymous: anonymous);
      onAfterToggle?.call(emoji, wasReacted);
    });
  }
}
