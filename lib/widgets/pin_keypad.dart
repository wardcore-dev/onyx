// lib/widgets/pin_keypad.dart
//
// Shared fluid/playful PIN-entry primitives used by both pin_code_screen.dart
// (app unlock / account switch) and pin_lock_dialog.dart (per-chat / folder
// lock), so the two stay visually and behaviorally identical.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

/// A single PIN dot that pops in with a slight overshoot (spring-like
/// ease-out/ease-out pair) whenever it transitions from empty to filled,
/// instead of just swapping fill color — the fluid/playful "wave as you
/// type" feel.
class PinDot extends StatefulWidget {
  final bool filled;
  final Color color;
  final Color emptyBorderColor;

  const PinDot({
    super.key,
    required this.filled,
    required this.color,
    required this.emptyBorderColor,
  });

  @override
  State<PinDot> createState() => _PinDotState();
}

class _PinDotState extends State<PinDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.5, end: 1.18).chain(CurveTween(curve: Curves.easeOut)),
      weight: 55,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.18, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
      weight: 45,
    ),
  ]).animate(_pop);

  @override
  void didUpdateWidget(covariant PinDot old) {
    super.didUpdateWidget(old);
    if (!old.filled && widget.filled) {
      _pop.forward(from: 0);
    } else if (old.filled && !widget.filled) {
      _pop.value = 0;
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(
        scale: widget.filled ? _scale.value : 1.0,
        child: child,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.filled ? widget.color : Colors.transparent,
          border: Border.all(
            color: widget.filled ? widget.color : widget.emptyBorderColor,
            width: 2,
          ),
        ),
      ),
    );
  }
}

/// Wraps any PIN-screen element (lock icon, title, subtitle, dot row, a
/// numpad key, the biometrics button...) with two staggered, index-driven
/// animations shared across the *whole screen*: an iOS-springboard-style
/// scale+fade "pop in" played once on mount, and — once [exit] flips to true
/// after a correct PIN — a fly-up-and-fade "launch" so every element leaves
/// together, not just the numpad. Both are computed from a single controller
/// per phase (not one controller per element) so the cascade reads as one
/// continuous wave, the same phase-shifted-wave technique already used for
/// the wrong-PIN dot shake in pin_code_screen.dart/pin_lock_dialog.dart.
///
/// [index] should follow on-screen top-to-bottom order (lock icon = 0, title
/// = 1, subtitle = 2, dot row = 3, numpad keys = 4..14, biometrics button =
/// 15) — the stagger constants below are tuned for up to ~16 slots.
class PinRevealSlot extends StatefulWidget {
  final int index;
  final bool exit;
  final Widget child;

  const PinRevealSlot({
    super.key,
    required this.index,
    required this.exit,
    required this.child,
  });

  @override
  State<PinRevealSlot> createState() => _PinRevealSlotState();
}

class _PinRevealSlotState extends State<PinRevealSlot>
    with TickerProviderStateMixin {
  // Starts already-completed (value: 1.0) instead of forward()-ing from 0 —
  // the entrance "pop in" cascade is disabled, but the controller is kept so
  // the exit (fly-up on success) animation below still works unchanged.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    value: 1.0,
    duration: const Duration(milliseconds: 650),
  );
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void didUpdateWidget(covariant PinRevealSlot old) {
    super.didUpdateWidget(old);
    if (!old.exit && widget.exit) {
      _exit.forward(from: 0);
    } else if (old.exit && !widget.exit) {
      _exit.value = 0;
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _exit.dispose();
    super.dispose();
  }

  double _staggered(
    double t, {
    required double perItemDelay,
    required double growth,
    required Curve curve,
  }) {
    final local = ((t - widget.index * perItemDelay) / growth).clamp(0.0, 1.0);
    return curve.transform(local);
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary isolates each slot's own compositing layer so one
    // element's per-frame transform/opacity changes don't force Flutter to
    // re-rasterize its siblings (or the ambient mesh background) — with up
    // to 16 of these animating at once (screen entry / a successful
    // unlock), that isolation is what keeps the cascade smooth.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_enter, _exit]),
        builder: (_, child) {
          // Tuned for up to ~16 slots (whole screen, not just the numpad) so
          // even the last element's animation still finishes as its
          // controller reaches t=1.
          final e = _staggered(_enter.value,
              perItemDelay: 0.025, growth: 0.6, curve: Curves.easeOutBack);
          final x = _staggered(_exit.value,
              perItemDelay: 0.02, growth: 0.7, curve: Curves.easeIn);

          final scale = (e < 0 ? 0.0 : e) * (1 - 0.1 * x);
          final opacity = (e.clamp(0.0, 1.0)) * (1 - x);
          final flyUp = x * 140;

          Widget content = Transform.translate(
            offset: Offset(0, -flyUp),
            child: Transform.scale(scale: scale, child: child),
          );

          // Opacity forces its own offscreen compositing layer — the classic
          // Flutter jank source when many are animating simultaneously. Skip
          // it while fully opaque (most of the entrance overshoot's settle
          // phase) so only frames that are actually fading pay for it.
          final clampedOpacity = opacity.clamp(0.0, 1.0);
          if (clampedOpacity < 0.999) {
            content = Opacity(opacity: clampedOpacity, child: content);
          }
          return content;
        },
        child: widget.child,
      ),
    );
  }
}

/// Numpad key that "presses in" like a physical button — scales down and
/// darkens slightly on tap-down instead of a Material ripple — plus a light
/// haptic tick per key.
class PinKey extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color background;
  final Color? pressedBackground;

  const PinKey({
    super.key,
    required this.child,
    required this.onTap,
    required this.background,
    this.pressedBackground,
  });

  @override
  State<PinKey> createState() => _PinKeyState();
}

class _PinKeyState extends State<PinKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          setState(() => _pressed = true);
          HapticFeedback.selectionClick();
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _pressed
                  ? (widget.pressedBackground ?? widget.background)
                  : widget.background,
            ),
            alignment: Alignment.center,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
