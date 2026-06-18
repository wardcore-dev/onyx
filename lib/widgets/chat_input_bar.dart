import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'measure_size.dart';

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
    this.glassMode = false,
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
  final bool glassMode;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final FocusNode _keyboardNode = FocusNode();

  // While true, an opaque overlay sits on top of the TextField and is the
  // only thing that can catch the next tap (see build() below). This makes
  // "the user touching the field re-enables focus" deterministic: relying on
  // a plain Listener wrapping the TextField raced against the TextField's
  // own internal tap-to-focus handling (which runs first, since hit-testing
  // visits the deepest target before its ancestors) and could silently lose
  // that race — leaving the field permanently untappable until the screen
  // was rebuilt (e.g. by leaving and re-entering the chat).
  bool _focusShieldActive = false;

  // The pill's true single-line height (text field + mic/send buttons) isn't
  // exactly `minHeight` — it depends on font metrics/scale, so hardcoding the
  // plus button to `minHeight` left a 1-2px seam where it didn't quite match
  // the rest of the pill. Tracked via MeasureSize (not LayoutBuilder — that
  // doesn't support intrinsic-dimension queries and silently breaks the
  // IntrinsicHeight pass this row depends on, which caused wrapped lines to
  // get clipped) on the main input area, taking the smallest height ever
  // observed as the true single-line height. The plus button is pinned to
  // that value so it matches exactly at rest but doesn't balloon into a tall
  // stadium once the text field grows past it.
  double _collapsedRowHeight = 48.0;
  // The very first measurement is accepted unconditionally (the initial
  // 48.0 guess above is just a placeholder for that first frame) — after
  // that, only a smaller measurement updates the baseline, since the true
  // single-line height is always the minimum the row will ever report.
  bool _hasMeasuredRowHeight = false;

  static bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    if (_isMobile) {
      widget.textFocusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    if (_isMobile) {
      widget.textFocusNode.removeListener(_onFocusChange);
    }
    _keyboardNode.dispose();
    super.dispose();
  }

  // When the input loses focus on mobile, block auto-restoration so that
  // closing a dialog cannot pop the keyboard back up unexpectedly.
  // canRequestFocus is re-enabled either by the user touching the field
  // (the focus shield in build() below) or by the screen calling _requestFocus().
  void _onFocusChange() {
    if (!_isMobile || !mounted) return;
    if (widget.textFocusNode.hasFocus) {
      // Focus was restored through some other path (e.g. the screen calling
      // _requestFocus()) — drop the shield so it doesn't linger uselessly.
      if (_focusShieldActive) setState(() => _focusShieldActive = false);
    } else {
      widget.textFocusNode.canRequestFocus = false;
      setState(() => _focusShieldActive = true);
    }
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

        // In glass mode borderColor is Colors.transparent; withValues(alpha)
        // would produce semi-transparent black (0x4D000000), causing visible
        // black bars. Force transparent borders when glassMode is on.
        final borderSide = BorderSide(
          color: widget.glassMode
              ? Colors.transparent
              : widget.borderColor.withValues(alpha: 0.3),
          width: 1,
          strokeAlign: BorderSide.strokeAlignInside,
        );
        final bgColor = widget.backgroundColor.withValues(alpha: widget.opacity);

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.98, end: isFocused ? 1.0 : 0.98),
          duration: duration,
          curve: curve,
          builder: (_, widthFactor, child) => FractionallySizedBox(
            widthFactor: widget.glassMode ? 1.0 : widthFactor,
            child: child,
          ),
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
                  // The Liquid Plus Button (Detachable Bubble).
                  // Wrapped in Align so the Row's CrossAxisAlignment.stretch
                  // (needed to make the input area match the multi-line
                  // TextField's height) stretches the Align instead of the
                  // button itself — the button stays a fixed-size circle.
                  Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 48,
                      height: _collapsedRowHeight,
                      child: AnimatedContainer(
                        duration: duration,
                        curve: curve,
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
                              color: colorScheme.onSurface.withValues(alpha: 0.7),
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
                    ),
                  ),

                  // Spacer that appears when focused (Liquid detaching effect)
                  AnimatedContainer(
                    duration: duration,
                    curve: curve,
                    width: (!widget.glassMode && isFocused) ? 8 : 0,
                  ),

                  // Main Input Area
                  Expanded(
                    child: MeasureSize(
                      onChange: (size) {
                        if (!mounted) return;
                        final isFirstMeasurement = !_hasMeasuredRowHeight;
                        if (isFirstMeasurement || size.height < _collapsedRowHeight) {
                          setState(() {
                            _hasMeasuredRowHeight = true;
                            _collapsedRowHeight = size.height;
                          });
                        }
                      },
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
                            child: Stack(
                              children: [
                                KeyboardListener(
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
                                // Catches the *first* tap after focus was lost
                                // on mobile: explicitly re-enables and requests
                                // focus itself, rather than racing the
                                // TextField's own internal tap-to-focus handling
                                // (see _focusShieldActive doc above).
                                if (_isMobile && _focusShieldActive)
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        widget.textFocusNode.canRequestFocus = true;
                                        setState(() => _focusShieldActive = false);
                                        widget.textFocusNode.requestFocus();
                                      },
                                    ),
                                  ),
                              ],
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
                                          color: isRecording ? colorScheme.error : colorScheme.onSurface.withValues(alpha: 0.6),
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
                                        color: hasText ? (widget.sendColor ?? colorScheme.primary) : colorScheme.onSurface.withValues(alpha: 0.3),
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


