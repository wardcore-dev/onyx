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

/// Animated entrance for day-separator and unread-marker rows.
///
/// Plays a height-grow + fade + slight upward slide on first appearance,
/// matching the pacing of [AnimatedMessageBubble]'s _heightFactor so that
/// sibling messages and separators rise together without any sudden layout
/// jump. When [animate] is false the child is shown immediately at full size.
class AnimatedSeparator extends StatefulWidget {
  final Widget child;
  final bool animate;

  const AnimatedSeparator({
    super.key,
    required this.child,
    this.animate = true,
  });

  @override
  State<AnimatedSeparator> createState() => _AnimatedSeparatorState();
}

class _AnimatedSeparatorState extends State<AnimatedSeparator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _heightFactor;
  late final Animation<double> _opacity;
  late final Animation<double> _offsetY;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Layout slot grows in the first 75 % — layout stabilises before the
    // separator fully fades in, so no layout thrash coincides with the
    // visual settle (same rationale as AnimatedMessageBubble._heightFactor).
    _heightFactor = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
    );
    // Fade in over the first third of the animation — fast enough that the
    // separator doesn't look like it's "bleeding" in, but not so abrupt that
    // it pops.
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );
    // Subtle upward slide mirrors the feeling of sibling messages rising.
    _offsetY = Tween<double>(begin: 14.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    if (widget.animate) {
      _ctrl.forward();
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return Align(
            alignment: Alignment.bottomCenter,
            heightFactor: _heightFactor.value,
            widthFactor: 1.0,
            child: FadeTransition(
              opacity: _opacity,
              child: Transform.translate(
                offset: Offset(0, _offsetY.value),
                child: child,
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

class AnimatedMessageBubble extends StatefulWidget {
  final Widget child;
  final bool outgoing;
  /// If true, plays the spring entrance animation.
  /// If false, the child is shown immediately at its final state (no animation).
  /// Keeping the same widget type with the same ValueKey across rebuilds
  /// allows Flutter to preserve an in-flight animation when this flips false.
  final bool animate;

  /// When set (typically the chat input bar's key), the bubble itself flies
  /// in from that widget's on-screen position to its real slot in the list,
  /// instead of the default spring-from-below entrance. This is the actual
  /// list item flying — not a separate overlay placeholder — so it already
  /// has its final content (text, timestamp) the whole time.
  final GlobalKey? flightOriginKey;

  /// Incoming messages have no on-screen widget to fly from (the sender is
  /// off-device), so instead they fly in from just past their own screen
  /// edge — same stretch mechanic as [flightOriginKey], synthesized from
  /// the bubble's own measured rect rather than a second widget. Which edge
  /// is determined by [alignRight].
  final bool flightFromEdge;

  /// Which side of the screen this bubble rests on — only used by
  /// [flightFromEdge] to know which edge to fly in from.
  final bool alignRight;

  const AnimatedMessageBubble({
    super.key,
    required this.child,
    this.outgoing = false,
    this.animate = true,
    this.flightOriginKey,
    this.flightFromEdge = false,
    this.alignRight = false,
  });

  @override
  State<AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _offsetY;
  late final Animation<double> _opacity;
  // Drives the bubble's own layout slot height (0 -> 1 of its natural
  // height), so the list item itself grows into place instead of being
  // reserved at full size in a single frame. That's what makes the rest of
  // the (reverse) message list rise smoothly instead of jumping the instant
  // a new message is inserted.
  late final Animation<double> _heightFactor;

  // Set once the flight origin (input bar) and our own final position have
  // both been measured. While null and a flight is pending, we stay
  // invisible (but laid out) for exactly one frame to avoid a flash at the
  // wrong spot.
  //
  // X and Y are driven separately so outgoing bubbles can have a Y-axis
  // "dip then fly" curve while X stays smooth, without affecting incoming
  // edge-flights (horizontal only, no dip).
  Animation<double>? _flightOffsetX;
  Animation<double>? _flightOffsetY;
  Animation<double>? _flightShape;
  Size _originSize = Size.zero;
  Size _ownSize = Size.zero;
  bool _awaitingMeasurement = false;

  // Measuring via the bubble's own top-level RenderBox would report the
  // outer Align's (possibly collapsed) box instead of the content's real
  // size/position, once that box is also collapsed during the awaiting-
  // measurement frame below. This key sits on the inner content, which
  // Align never resizes (only repositions), so it always reports the true
  // final rect regardless of the outer box's current heightFactor.
  final GlobalKey _ownKey = GlobalKey();

  bool get _isFlight =>
      widget.animate &&
      (widget.flightOriginKey != null || widget.flightFromEdge);

  @override
  void initState() {
    super.initState();
    final bool isInputBarFlight = widget.flightOriginKey != null;
    _ctrl = AnimationController(
      vsync: this,
      // Outgoing flight gets 420ms so the "dip then launch" arc has enough
      // room to breathe — 320ms compressed the departure to the point where
      // you could barely see it before the bubble was already gone.
      duration: Duration(milliseconds: isInputBarFlight ? 420 : 224),
    );

    // Scale uses easeOutBack → gives the characteristic iMessage spring overshoot
    _scale = Tween<double>(begin: 0.01, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );

    // Translation: outgoing bubbles travel further up (from send button area)
    // — only used as a fallback when there's no measured flight origin.
    _offsetY = Tween<double>(
      begin: widget.outgoing ? 64.0 : 32.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Opacity pops in almost immediately — fully visible within ~10% of the
    // animation. Tightened from 25%: with the flight shape/offset now
    // holding at the input bar's position+size for a beat (see
    // _measureAndFly), opacity needs to already be at full strength during
    // that hold, otherwise the "pill" the user is meant to clearly see is
    // still fading in and looks washed out instead of solid.
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.1, curve: Curves.easeOut),
      ),
    );

    // Completes at 75 % of the total duration so the list layout stabilises
    // well before the bubble lands — the last ~25 % of the animation only
    // triggers a repaint (no layout recalculation), which is much cheaper
    // and eliminates the jank that happens when layout thrash and the final
    // position approach coincide in the same frames.
    _heightFactor = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
    );

    if (_isFlight) {
      // Defer to next frame: we need our own RenderBox laid out at its
      // final list position before we can compute how far it has to fly.
      _awaitingMeasurement = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndFly());
    } else if (widget.animate) {
      _ctrl.forward();
    } else {
      // Skip to final state immediately — no visual animation, no overhead.
      _ctrl.value = 1.0;
    }
  }

  void _measureAndFly() {
    if (!mounted) return;
    final ownBox =
        _ownKey.currentContext?.findRenderObject() as RenderBox?;
    if (ownBox == null || !ownBox.attached) {
      setState(() => _awaitingMeasurement = false);
      _ctrl.value = 1.0;
      return;
    }

    final ownTopLeft = ownBox.localToGlobal(Offset.zero);
    final ownSize = ownBox.size;

    Offset originTopLeft;
    Size originSize;
    final bool isInputBarFlight = widget.flightOriginKey != null;

    if (isInputBarFlight) {
      final originBox = widget.flightOriginKey?.currentContext
          ?.findRenderObject() as RenderBox?;
      if (originBox == null || !originBox.attached) {
        // Can't measure (e.g. window resized mid-frame) — just show in place.
        setState(() => _awaitingMeasurement = false);
        _ctrl.value = 1.0;
        return;
      }
      originTopLeft = originBox.localToGlobal(Offset.zero);
      originSize = originBox.size;
    } else {
      // Edge flight: synthesize a small pill-shaped origin just past this
      // bubble's own resting edge — same width/height-stretch mechanic as
      // the input-bar flight, but with no second widget to measure.
      const travel = 64.0;
      const compress = 0.45;
      originSize = Size(ownSize.width * compress, ownSize.height);
      if (widget.alignRight) {
        final finalRight = ownTopLeft.dx + ownSize.width;
        final originRight = finalRight + travel;
        originTopLeft =
            Offset(originRight - originSize.width, ownTopLeft.dy);
      } else {
        originTopLeft = Offset(ownTopLeft.dx - travel, ownTopLeft.dy);
      }
    }

    final delta = originTopLeft - ownTopLeft;

    setState(() {
      _awaitingMeasurement = false;
      _originSize = originSize;
      _ownSize = ownSize;

      // Shape morph: bubble transitions from pill → full bubble over the
      // whole flight. easeInOutCubic keeps it visibly "born from the input
      // field" before accelerating into its final form.
      final shapeCurve =
          CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
      _flightShape = shapeCurve;

      // X always moves smoothly on the same easeInOutCubic.
      _flightOffsetX =
          Tween<double>(begin: delta.dx, end: 0.0).animate(shapeCurve);

      if (isInputBarFlight) {
        // Outgoing bubble Y — two-phase arc:
        //
        // Phase 1 (0–22%, ~92ms): slow float DOWN 16px — "easeOut" means
        //   it starts barely moving (you see the bubble "peeling away" from
        //   the input bar) and decelerates into the low point. Long enough
        //   at 420ms total to actually enjoy watching the departure.
        //
        // Phase 2 (22–100%, ~328ms): fly UP from the dip to final position
        //   with "easeInOut" — starts slow at the dip low-point (the moment
        //   of "gravity reversal"), accelerates through the middle of the
        //   flight, then decelerates smoothly into the resting slot.
        //   The slow-start of phase 2 right after the dip creates a brief
        //   "hang" at the bottom — the reversal moment — before it launches.
        const dipPixels = 16.0;
        _flightOffsetY = TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(
              begin: delta.dy,
              end: delta.dy + dipPixels,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 22,
          ),
          TweenSequenceItem(
            tween: Tween<double>(
              begin: delta.dy + dipPixels,
              end: 0.0,
            ).chain(CurveTween(curve: Curves.easeInOutCubic)),
            weight: 78,
          ),
        ]).animate(_ctrl);
      } else {
        // Edge flight (incoming): purely horizontal, no Y dip.
        _flightOffsetY =
            Tween<double>(begin: delta.dy, end: 0.0).animate(shapeCurve);
      }
    });
    _ctrl.forward();
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
    if (_awaitingMeasurement) {
      // Stay invisible AND collapsed (heightFactor: 0) until we know where
      // to fly from. Previously this reserved the full-height slot while
      // invisible, which still pushed sibling messages up a frame early —
      // then the height animation below would restart from 0, snapping
      // them back down before growing again. The inner KeyedSubtree (keyed
      // by _ownKey) is unaffected by the outer collapse — Align only
      // repositions/overflows it, never resizes it — so _measureAndFly
      // still sees the bubble's true final size and position.
      return Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 0.0,
        widthFactor: 1.0,
        child: Opacity(
          opacity: 0,
          child: KeyedSubtree(key: _ownKey, child: widget.child),
        ),
      );
    }

    final flightOffsetX = _flightOffsetX;
    final flightOffsetY = _flightOffsetY;
    final flightShape = _flightShape;
    // Two-layer RepaintBoundary strategy for mobile GPU performance:
    //
    // OUTER boundary (here) — prevents sibling ListView items from repainting
    // on each animation tick; their compositing layers are repositioned by the
    // GPU without touching their raster caches.
    //
    // INNER boundary (on widget.child below) — caches the bubble content as a
    // raster layer once; every subsequent frame only applies the Transform
    // matrix to that cached layer (a pure GPU operation), with no re-
    // rasterisation. Without this inner boundary the non-uniform Matrix4 scale
    // invalidates the outer cache on every tick, forcing a full CPU+GPU repaint
    // of the bubble content at 60 fps — visibly janky on mid-range Android.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          Widget content;
          if (flightOffsetX != null && flightOffsetY != null &&
              flightShape != null) {
            // Flight mode: the real bubble translates in from the input bar's
            // position while literally stretching — at t=0 it's rendered at
            // the input pill's exact width/height (whatever that ratio is,
            // even if the pill is much wider than the final bubble), then
            // scales non-uniformly to its natural size as it flies. The clip
            // (Align widthFactor/heightFactor) approach only shrinks content
            // that's smaller than the target — it can't make a narrow bubble
            // start out pill-wide, hence the actual Transform.scale here.
            final t = flightShape.value;
            final sx = _ownSize.width == 0 ? 1.0 : _originSize.width / _ownSize.width;
            final sy = _ownSize.height == 0 ? 1.0 : _originSize.height / _ownSize.height;
            final scaleX = sx + (1.0 - sx) * t;
            final scaleY = sy + (1.0 - sy) * t;
            // FadeTransition avoids saveLayer (unlike Opacity) by painting at
            // the shader level — cheaper on the GPU for fractional alpha.
            content = FadeTransition(
              opacity: _opacity,
              child: Transform.translate(
                offset: Offset(flightOffsetX.value, flightOffsetY.value),
                child: Transform(
                  alignment: Alignment.topLeft,
                  transform: Matrix4.diagonal3Values(scaleX, scaleY, 1.0),
                  child: child,
                ),
              ),
            );
          } else {
            content = FadeTransition(
              opacity: _opacity,
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
            );
          }
          // No ClipRect here on purpose: the flight animation translates the
          // bubble in from off-slot (input bar / screen edge), and clipping to
          // this still-growing box would hide most of that flight, leaving
          // only the tail end visible. Align's heightFactor only changes the
          // box's LAYOUT size (what pushes sibling messages up) — the child
          // itself paints unclipped at wherever its transform places it.
          return Align(
            alignment: Alignment.bottomCenter,
            heightFactor: _heightFactor.value,
            // Without this, Align expands to fill all available row width
            // and centers its child horizontally — wiping out the bubble's
            // left/right placement. Pinning width to the child's own width
            // means only height (the growth effect) changes.
            widthFactor: 1.0,
            child: content,
          );
        },
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}
