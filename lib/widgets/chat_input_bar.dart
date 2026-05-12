import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.textFocusNode,
    required this.recordingListenable,
    required this.onCancelRecording,
    required this.onMicPressed,
    required this.onAttachPressed,
    required this.onSendPressed,
    required this.onPaste,
    required this.hintText,
    required this.backgroundColor,
    required this.opacity,
    required this.borderColor,
    this.onSendLongPress,
    this.onChanged,
    this.sendIcon,
    this.sendColor,
    this.textStyle,
    this.hintStyle,
    this.contentInsertionConfiguration,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final FocusNode textFocusNode;

  final ValueListenable<bool> recordingListenable;
  final VoidCallback onCancelRecording;
  final void Function(bool isRecording) onMicPressed;

  final VoidCallback onAttachPressed;
  final VoidCallback onSendPressed;
  final VoidCallback? onSendLongPress;

  final Future<void> Function() onPaste;
  final ValueChanged<String>? onChanged;

  final String hintText;

  final Color backgroundColor;
  final double opacity;
  final Color borderColor;

  final IconData? sendIcon;
  final Color? sendColor;

  final TextStyle? textStyle;
  final TextStyle? hintStyle;

  final ContentInsertionConfiguration? contentInsertionConfiguration;

  final bool readOnly;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final FocusNode _keyboardNode = FocusNode();

  @override
  void dispose() {
    _keyboardNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.keyV) &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      widget.onPaste();
      return;
    }

    if (HardwareKeyboard.instance
        .isLogicalKeyPressed(LogicalKeyboardKey.enter)) {
      if (!HardwareKeyboard.instance.isShiftPressed) {
        if (widget.controller.text.trim().isNotEmpty) widget.onSendPressed();
        return;
      }

      if (widget.controller.text.isNotEmpty) {
        final text = widget.controller.text;
        final selection = widget.controller.selection;
        widget.controller.text =
            '${text.substring(0, selection.start)}\n${text.substring(selection.start)}';
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: selection.start + 1),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: Listenable.merge([widget.textFocusNode, widget.controller]),
      builder: (context, _) {
        final isFocused = widget.textFocusNode.hasFocus;
        final hasText = widget.controller.text.isNotEmpty;
        const double minHeight = 48.0;
        const double radius = 24.0;
        final duration = const Duration(milliseconds: 300);
        const curve = Curves.easeInOutCubic;

        final borderSide = BorderSide(
          color: widget.borderColor.withValues(alpha: 0.3),
          width: 1,
          strokeAlign: BorderSide.strokeAlignInside,
        );
        final bgColor = widget.backgroundColor.withValues(alpha: widget.opacity);

        return AnimatedPadding(
          duration: duration,
          curve: curve,
          padding: EdgeInsets.symmetric(horizontal: isFocused ? 0 : 6),
          child: IntrinsicHeight(
            child: AnimatedContainer(
              duration: duration,
              curve: curve,
              // Group border around the whole pill when joined
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: isFocused ? Colors.transparent : borderSide.color,
                  width: borderSide.width,
                  strokeAlign: borderSide.strokeAlign,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The Liquid Plus Button (Detachable Bubble)
                  AnimatedContainer(
                    duration: duration,
                    curve: curve,
                    width: 48,
                    decoration: BoxDecoration(
                      color: bgColor,
                      // Seamless radius when joined, full radius when detached
                      borderRadius: isFocused
                          ? BorderRadius.circular(radius)
                          : const BorderRadius.only(
                              topLeft: Radius.circular(radius),
                              bottomLeft: Radius.circular(radius),
                            ),
                      border: Border.all(
                        color: isFocused ? borderSide.color : Colors.transparent,
                        width: borderSide.width,
                        strokeAlign: borderSide.strokeAlign,
                      ),
                    ),
                    child: Center(
                      child: IconButton(
                        icon: Icon(
                          Icons.add,
                          color: colorScheme.onSurface.withOpacity(0.7),
                          size: 24,
                        ),
                        onPressed: widget.readOnly ? null : widget.onAttachPressed,
                        visualDensity: VisualDensity.compact,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),

                  // Spacer that appears when focused (Liquid detaching effect)
                  AnimatedContainer(
                    duration: duration,
                    curve: curve,
                    width: isFocused ? 8 : 0,
                  ),

                  // Main Input Area
                  Expanded(
                    child: AnimatedContainer(
                      duration: duration,
                      curve: curve,
                      constraints: const BoxConstraints(minHeight: minHeight),
                      decoration: BoxDecoration(
                        color: bgColor,
                        // Seamless radius when joined, full radius when detached
                        borderRadius: isFocused
                            ? BorderRadius.circular(radius)
                            : const BorderRadius.only(
                                topRight: Radius.circular(radius),
                                bottomRight: Radius.circular(radius),
                              ),
                        border: Border.all(
                          color: isFocused ? borderSide.color : Colors.transparent,
                          width: borderSide.width,
                          strokeAlign: borderSide.strokeAlign,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(width: 12),
                          Expanded(
                            child: KeyboardListener(
                              focusNode: _keyboardNode,
                              onKeyEvent: _handleKeyEvent,
                              child: TextField(
                                focusNode: widget.textFocusNode,
                                controller: widget.controller,
                                minLines: 1,
                                maxLines: 5,
                                readOnly: widget.readOnly,
                                style: widget.textStyle ??
                                    TextStyle(color: colorScheme.onSurface),
                                decoration: InputDecoration(
                                  hintText: widget.hintText,
                                  hintStyle: widget.hintStyle ??
                                      TextStyle(
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 0,
                                  ),
                                ),
                                onChanged: widget.onChanged,
                                textInputAction: TextInputAction.none,
                                contentInsertionConfiguration:
                                    widget.contentInsertionConfiguration,
                              ),
                            ),
                          ),
                          
                            // Action Buttons (Mic and Send)
                            ValueListenableBuilder<bool>(
                              valueListenable: widget.recordingListenable,
                              builder: (context, isRecording, _) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Animated Trash Button (Slides and Fades)
                                    AnimatedContainer(
                                      duration: duration,
                                      curve: curve,
                                      width: isRecording ? 40 : 0,
                                      child: AnimatedOpacity(
                                        duration: duration,
                                        curve: curve,
                                        opacity: isRecording ? 1 : 0,
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          physics: const NeverScrollableScrollPhysics(),
                                          child: SizedBox(
                                            width: 40,
                                            child: IconButton(
                                              icon: Icon(Icons.delete, color: colorScheme.error, size: 20),
                                              onPressed: widget.onCancelRecording,
                                              visualDensity: VisualDensity.compact,
                                              splashColor: Colors.transparent,
                                              highlightColor: Colors.transparent,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    // Microphone Button (with icon transition)
                                    IconButton(
                                      icon: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 200),
                                        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                                        child: Icon(
                                          isRecording ? Icons.stop : Icons.mic,
                                          key: ValueKey(isRecording ? 'stop' : 'mic'),
                                          color: isRecording ? colorScheme.error : colorScheme.onSurface.withOpacity(0.6),
                                          size: 22,
                                        ),
                                      ),
                                      onPressed: widget.readOnly ? null : () => widget.onMicPressed(isRecording),
                                      visualDensity: VisualDensity.compact,
                                      splashColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                    ),

                                    // Send Button
                                    IconButton(
                                      icon: Icon(
                                        widget.sendIcon ?? Icons.send,
                                        color: hasText ? (widget.sendColor ?? colorScheme.primary) : colorScheme.onSurface.withOpacity(0.3),
                                        size: 22,
                                      ),
                                      onPressed: (widget.readOnly || !hasText) ? null : widget.onSendPressed,
                                      onLongPress: widget.onSendLongPress,
                                      visualDensity: VisualDensity.compact,
                                      splashColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                );
                              },
                            ),

                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );





  }
}


