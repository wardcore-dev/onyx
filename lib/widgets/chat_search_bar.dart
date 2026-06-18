// lib/widgets/chat_search_bar.dart
import 'package:flutter/material.dart';
import '../managers/settings_manager.dart';

class ChatSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  /// (current: 1-based, total). current==0 means no matches.
  final ValueNotifier<({int current, int total})> statsNotifier;

  final ValueChanged<String> onChanged;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onClose;

  const ChatSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.statsNotifier,
    required this.onChanged,
    required this.onClose,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementOpacity,
      builder: (_, opacity, __) {
        return ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementBrightness,
          builder: (_, brightness, __) {
            final barColor = SettingsManager.getElementColor(
              cs.surfaceContainerHighest,
              brightness,
            ).withValues(alpha: opacity.clamp(0.85, 1.0));
            final fieldColor = SettingsManager.getElementColor(
              cs.surfaceContainer,
              brightness,
            ).withValues(alpha: 0.65);

            return Container(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: cs.outline.withValues(alpha: 0.15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        autofocus: true,
                        cursorColor: cs.primary,
                        decoration: InputDecoration(
                          hintText: 'Search in chat...',
                          hintStyle: TextStyle(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 18,
                            color: cs.primary.withValues(alpha: 0.8),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: fieldColor,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          isDense: true,
                        ),
                        style: TextStyle(fontSize: 14, color: cs.onSurface),
                        onChanged: onChanged,
                      ),
                    ),
                    const SizedBox(width: 6),
                    ValueListenableBuilder(
                      valueListenable: statsNotifier,
                      builder: (_, stats, __) => SizedBox(
                        width: 48,
                        child: Text(
                          stats.total == 0
                              ? (controller.text.isEmpty ? '' : '0/0')
                              : '${stats.current}/${stats.total}',
                          style: TextStyle(
                            fontSize: 12,
                            color: stats.total > 0
                                ? cs.primary.withValues(alpha: 0.85)
                                : cs.onSurface.withValues(alpha: 0.4),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    // ↑ = older (toward top of chat)
                    IconButton(
                      icon: Icon(Icons.keyboard_arrow_up,
                          size: 20, color: cs.onSurfaceVariant),
                      onPressed: onPrevious,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      visualDensity: VisualDensity.compact,
                    ),
                    // ↓ = newer (toward bottom of chat)
                    IconButton(
                      icon: Icon(Icons.keyboard_arrow_down,
                          size: 20, color: cs.onSurfaceVariant),
                      onPressed: onNext,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          size: 20, color: cs.onSurfaceVariant),
                      onPressed: onClose,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      visualDensity: VisualDensity.compact,
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
