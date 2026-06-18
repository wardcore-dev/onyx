// lib/widgets/inline_search_bar.dart
import 'package:flutter/material.dart';
import '../managers/settings_manager.dart';

class InlineSearchBar extends StatefulWidget {
  const InlineSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hintText,
    this.hasText = false,
    this.padding = const EdgeInsets.fromLTRB(12, 6, 12, 6),
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  final bool hasText;
  final EdgeInsetsGeometry padding;

  @override
  State<InlineSearchBar> createState() => _InlineSearchBarState();
}

class _InlineSearchBarState extends State<InlineSearchBar> {
  final FocusNode _focusNode = FocusNode();

  // True only when the user explicitly tapped the field (onTap fires before
  // focus is established via requestFocus). If focus arrives without this
  // flag being set, it means Flutter auto-restored it after a dialog/sheet
  // closed — in that case we immediately dismiss it.
  bool _focusedByUser = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    FocusManager.instance.addListener(_onGlobalFocusChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onGlobalFocusChange);
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _focusedByUser = false;
    }
  }

  void _onGlobalFocusChange() {
    if (!mounted) return;
    if (_focusNode.hasFocus && !_focusedByUser) {
      // Focus came back to us without the user tapping — this is Flutter
      // auto-restoring focus after a dialog/sheet was dismissed.
      // Unfocus immediately so the keyboard does not reappear.
      _focusNode.unfocus(disposition: UnfocusDisposition.scope);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementOpacity,
      builder: (_, opacity, __) {
        return ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementBrightness,
          builder: (_, brightness, __) {
            final fillColor = SettingsManager.getElementColor(
              cs.surfaceContainerHighest,
              brightness,
            ).withValues(alpha: opacity);
            return Padding(
              padding: widget.padding,
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  onChanged: widget.onChanged,
                  onTap: () => _focusedByUser = true,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(fontSize: 15, color: cs.onSurface.withValues(alpha: 0.4)),
                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.45)),
                    prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    suffixIcon: widget.hasText
                        ? GestureDetector(
                            onTap: () {
                              widget.controller.clear();
                              widget.onChanged('');
                            },
                            child: Icon(Icons.close_rounded, size: 16, color: cs.onSurface.withValues(alpha: 0.45)),
                          )
                        : null,
                    suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    filled: true,
                    fillColor: fillColor,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
