import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

class SwipeableMessageWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onSwipeLeft;
  final bool disabled;

  const SwipeableMessageWrapper({
    super.key,
    required this.child,
    this.onSwipeRight,
    this.onSwipeLeft,
    this.disabled = false,
  });

  @override
  State<SwipeableMessageWrapper> createState() =>
      _SwipeableMessageWrapperState();
}

class _SwipeableMessageWrapperState extends State<SwipeableMessageWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _offsetAnimation;
  double _dragOffset = 0.0;
  bool _isDragging = false;
  bool _actionFired = false;

  static const double _maxDrag = 96.0;
  static const double _triggerDistance = 30.0;
  // Rubber-band constant for _onDragUpdate's resistance curve: at
  // |_dragOffset| == this value, a further finger-pixel of delta only moves
  // the bubble half a pixel. Without this the bubble tracked the finger
  // 1:1, so raising _triggerDistance alone just moved the finish line
  // further away without the swipe ever feeling any heavier to pull.
  static const double _resistance = 28.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _offsetAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (widget.disabled) return;
    setState(() {
      final resistedDelta =
          details.delta.dx * _resistance / (_resistance + _dragOffset.abs());
      _dragOffset += resistedDelta;
      _dragOffset = _dragOffset.clamp(-_maxDrag, _maxDrag);
    });

    if (!_actionFired) {
      if (_dragOffset >= _triggerDistance && widget.onSwipeRight != null) {
        _actionFired = true;
        HapticFeedback.selectionClick();
      } else if (_dragOffset <= -_triggerDistance &&
          widget.onSwipeLeft != null) {
        _actionFired = true;
        HapticFeedback.selectionClick();
      }
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (widget.disabled) return;
    final capturedOffset = _dragOffset;
    final fired = _actionFired;
    _actionFired = false;
    _isDragging = false;

    _offsetAnimation = Tween<double>(begin: capturedOffset, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward(from: 0);

    // Only a drag that actually crossed _triggerDistance (tracked live by
    // _onDragUpdate as _actionFired) may fire the action. A fast horizontal
    // flick during vertical scrolling can produce a high release velocity
    // with negligible _dragOffset — that used to fire the action on
    // velocity alone, opening the reply/menu panel by accident mid-scroll.
    if (fired) {
      if (capturedOffset > 0) {
        widget.onSwipeRight?.call();
      } else {
        widget.onSwipeLeft?.call();
      }
    }

    setState(() {
      _dragOffset = 0;
    });
  }

  void _onDragStart(DragStartDetails details) {
    if (widget.disabled) return;
    _controller.stop();
    _isDragging = true;
    _actionFired = false;
    setState(() {
      _dragOffset = 0;
    });
  }

  static bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  @override
  Widget build(BuildContext context) {
    final disabled = widget.disabled || _isDesktop;
    return GestureDetector(
      onHorizontalDragStart: disabled ? null : _onDragStart,
      onHorizontalDragUpdate: disabled ? null : _onDragUpdate,
      onHorizontalDragEnd: disabled ? null : _onDragEnd,
      child: AnimatedBuilder(
        animation: _offsetAnimation,
        builder: (context, child) {
          final offset = _isDragging ? _dragOffset : _offsetAnimation.value;
          return Transform.translate(
            offset: Offset(offset, 0),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
