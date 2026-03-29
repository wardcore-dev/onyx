// lib/widgets/animated_message_bubble.dart
//
// Single source of truth for the message appear animation used in
// ChatScreen, GroupChatScreen, ExternalGroupChatScreen and FavoritesScreen.
// iMessage-style: spring scale overshoot + upward slide + fast opacity pop.
//
// The [animate] flag controls whether the animation actually plays.
// Always using this widget (even with animate:false) keeps the widget TYPE
// consistent across rebuilds, so Flutter preserves in-flight animations when
// a parent setState fires mid-overshoot (e.g. server confirmation arriving
// before the 320ms spring completes).

import 'package:flutter/material.dart';

class AnimatedMessageBubble extends StatefulWidget {
  final Widget child;
  final bool outgoing;
  /// If true, plays the spring entrance animation.
  /// If false, the child is shown immediately at its final state (no animation).
  /// Keeping the same widget type with the same ValueKey across rebuilds
  /// allows Flutter to preserve an in-flight animation when this flips false.
  final bool animate;

  const AnimatedMessageBubble({
    Key? key,
    required this.child,
    this.outgoing = false,
    this.animate = true,
  }) : super(key: key);

  @override
  State<AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _offsetY;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    // iMessage timing: ~320 ms total, spring-like scale overshoot
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    // Scale uses easeOutBack → gives the characteristic iMessage spring overshoot
    _scale = Tween<double>(begin: 0.01, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );

    // Translation: outgoing bubbles travel further up (from send button area)
    _offsetY = Tween<double>(
      begin: widget.outgoing ? 64.0 : 32.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Opacity pops in fast — iMessage bubbles are fully visible within ~25% of animation
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );

    if (widget.animate) {
      _ctrl.forward();
    } else {
      // Skip to final state immediately — no visual animation, no overhead.
      _ctrl.value = 1.0;
    }
  }

  // didUpdateWidget intentionally does nothing: if animate flips false mid-flight
  // (e.g. server confirmation setState while the spring is overshooting), we
  // preserve the running controller so the animation completes naturally.

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(
          offset: Offset(0, _offsetY.value),
          child: Transform.scale(
            scale: _scale.value,
            alignment: widget.outgoing
                ? Alignment.bottomRight
                : Alignment.bottomLeft,
            child: child,
          ),
        ),
      ),
      child: widget.child,
    );
  }
}
