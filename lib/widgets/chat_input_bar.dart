import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'measure_size.dart';

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.textFocusNode,
    required this.recordingListenable,
    this.recordingLevelListenable,
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
    this.meshMode = false,
    this.inputAreaKey,
  });

  final TextEditingController controller;
  final FocusNode textFocusNode;

  final ValueListenable<bool> recordingListenable;

  /// Normalized (0..1) live mic level, sampled every ~70ms while recording.
  /// Drives the recording glow's intensity so it reacts to actual loudness
  /// instead of running on a fixed timer. Null (or always-0) just means the
  /// glow never appears — recording still works fine without it.
  final ValueListenable<double>? recordingLevelListenable;
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
  final bool meshMode;

  /// Optional key on the decorated "pill" container (not the whole bar) —
  /// lets a caller read its exact global rect/shape at send time, e.g. to
  /// fly a "ghost" of the typed text from here to the new message bubble.
  final GlobalKey? inputAreaKey;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with TickerProviderStateMixin {
  final FocusNode _keyboardNode = FocusNode();

  // Drives the joined/detached (focus) transition explicitly instead of via
  // TweenAnimationBuilder, which rebuilds a brand new Tween object on every
  // build. This widget's ListenableBuilder rebuilds on every keystroke (it
  // listens to widget.controller too), so a fresh Tween was constructed on
  // every keystroke — and since didUpdateWidget only detects "the tween
  // object changed", not "the tween's begin/end are the same values as
  // before", that quietly re-armed the implicit animation each time,
  // producing a faint flicker while typing even though isFocused never
  // actually changed. Owning the controller here means it's only ever
  // told to animate when isFocused *actually* flips.
  late final AnimationController _focusController;
  late final Animation<double> _focusCurve;
  bool _wasFocused = false;

  // A lightweight underdamped spring (rather than a fixed-duration curve)
  // drives the joined/detached transition, so the pill has a slight
  // elastic "settle" instead of a mechanical ease. Tuned for a single small
  // overshoot, not a bouncy oscillation.
  static final SpringDescription _focusSpring = SpringDescription(
    mass: 1,
    stiffness: 300,
    damping: 20,
  );

  // Continuously-running (only while recording) controller driving both the
  // breathing border glow and the waveform bars from one shared phase, so
  // they stay visually in sync. Stopped while idle to avoid ticking for no
  // reason.
  late final AnimationController _recordAnimController;
  bool _wasRecording = false;

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
  double _collapsedRowHeight = 50.0;
  // The very first measurement is accepted unconditionally (the initial
  // 48.0 guess above is just a placeholder for that first frame) — after
  // that, only a smaller measurement updates the baseline, since the true
  // single-line height is always the minimum the row will ever report.
  bool _hasMeasuredRowHeight = false;

  // Envelope-followed mic level driving the recording glow: attacks fast
  // (snaps up right as speech starts) and releases slowly (eases back down
  // between words instead of chattering with every raw sample). Mutated
  // directly during build rather than via setState — it's already
  // recomputed every frame off _recordAnimController's tick, which is what
  // triggers the rebuild in the first place.
  double _smoothedRecordLevel = 0.0;

  static bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    // Starting value/duration don't matter here — every transition is driven
    // by animateWith(SpringSimulation(...)) in _syncFocusAnimation instead of
    // forward()/reverse(), so the controller is just the spring's carrier.
    _focusController = AnimationController(vsync: this, value: 0.0);
    _focusCurve = _focusController;
    _recordAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    if (_isMobile) {
      widget.textFocusNode.addListener(_onFocusChange);
    }
    widget.recordingListenable.addListener(_onRecordingChanged);
    // _onRecordingChanged only fires on a *transition* of recordingListenable
    // (false→true or true→false). If this bar is created while recording is
    // already in progress — e.g. switching to another chat mid-recording, so
    // a brand new ChatInputBar/State mounts for that screen — there's no
    // transition to catch: the value was already true before this widget
    // existed. Without this, _recordAnimController never starts ticking for
    // that instance, which froze both the recording glow and the mic
    // waveform (they're only recomputed on the controller's own frames).
    if (widget.recordingListenable.value) {
      _wasRecording = true;
      _recordAnimController.repeat();
    }
  }

  @override
  void dispose() {
    if (_isMobile) {
      widget.textFocusNode.removeListener(_onFocusChange);
    }
    widget.recordingListenable.removeListener(_onRecordingChanged);
    _focusController.dispose();
    _recordAnimController.dispose();
    _keyboardNode.dispose();
    super.dispose();
  }

  // Only (re)starts the joined/detached animation when isFocused actually
  // flips — called from build() on every rebuild, but a no-op on the
  // keystroke-triggered rebuilds where it hasn't changed.
  void _syncFocusAnimation(bool isFocused) {
    if (isFocused == _wasFocused) return;
    _wasFocused = isFocused;
    final target = isFocused ? 1.0 : 0.0;
    _focusController.animateWith(
      SpringSimulation(_focusSpring, _focusController.value, target, 0),
    );
  }

  // Recording is fully independent of typing/sending (see chat_screen.dart —
  // the mic starts a background upload task, the TextField and send button
  // keep working exactly as before). This only toggles the purely visual
  // breathing-border/waveform ticker on and off.
  void _onRecordingChanged() {
    if (!mounted) return;
    final isRecording = widget.recordingListenable.value;
    if (isRecording == _wasRecording) return;
    _wasRecording = isRecording;
    if (isRecording) {
      _recordAnimController.repeat();
    } else {
      _recordAnimController.stop();
    }
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

    if (HardwareKeyboard.instance
            .isLogicalKeyPressed(LogicalKeyboardKey.keyV) &&
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
        const double minHeight = 50.0;
        // Deliberately a bit larger than minHeight / 2 (25.0): the box's
        // *actual* rendered height at a single line runs a few px past
        // minHeight once font metrics/text scale are applied, so a radius
        // tied exactly to minHeight/2 slightly undershoots it and the
        // pill's ends read as flattened ovals instead of a true capsule.
        // 28 clips down to a full stadium at that single-line height —
        // matching the channel "read only" banner below, which uses the
        // same value for the same reason — without being some enormous
        // sentinel: once the field grows multi-line and the box gets much
        // taller than it is wide, an unbounded radius would clip to half
        // *that* height instead and balloon the corners into a giant oval.
        const double radius = 28.0;
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
        final bgColor =
            widget.backgroundColor.withValues(alpha: widget.opacity);

        _syncFocusAnimation(isFocused);

        return AnimatedBuilder(
          animation: Listenable.merge(
              [_focusCurve, _recordAnimController, widget.recordingListenable]),
          // A single shared 0→1 progress value (this controller) drives
          // every joined/detached property below (width, fill colors,
          // radii, borders) instead of each piece running its own
          // independent implicit animation. Independently-triggered
          // animations "fading in" while others "fade out" aren't
          // guaranteed to report the exact same progress on every frame, so
          // for one frame here and there both could be partially opaque at
          // once — their semi-transparent fills would then stack and
          // briefly paint darker than either endpoint. Computing everything
          // from one `focusT` in the same build guarantees they always sum
          // back to the same total alpha, so that flash can't happen.
          builder: (_, __) {
            // The spring can overshoot slightly past 0/1 on its settle —
            // clamped so Color/BorderRadius.lerp never extrapolate beyond
            // their defined endpoints.
            final focusT = _focusCurve.value.clamp(0.0, 1.0);
            final widthFactor = 0.98 + 0.02 * focusT;

            // The recording cue is now carried entirely by a soft, blurred
            // BoxShadow "bloom" on the field (see fieldGlowShadow below) —
            // border width/color stay completely static while recording, so
            // nothing about the field's own box ever changes size. A
            // BoxShadow paints outside the box without occupying layout
            // space, unlike a wider border, which is what makes that
            // possible.
            final isRecordingNow = widget.recordingListenable.value;
            final recordBorderWidth = borderSide.width;
            // The raw mic level arrives in ~70ms steps and jumps around
            // even during steady speech, so it's run through an
            // attack/release envelope (like a VU meter) rather than used
            // directly: snap up fast when you start talking, ease back down
            // between words/pauses instead of chattering with every sample.
            // _recordAnimController keeps ticking at 60fps while recording
            // regardless of whether a new mic sample arrived, which is what
            // gives this envelope per-frame granularity between samples.
            final rawLevel = isRecordingNow
                ? (widget.recordingLevelListenable?.value ?? 0.0)
                : 0.0;
            // Attack close to 1.0 means "basically snap to the new level
            // immediately" — each frame closes ~85% of the remaining gap,
            // so a sudden sound reads as near-instant instead of visibly
            // ramping up. Release stays much slower so it still eases back
            // down instead of chattering off between syllables.
            const attack = 0.85;
            const release = 0.08;
            final envelopeRate =
                rawLevel > _smoothedRecordLevel ? attack : release;
            _smoothedRecordLevel +=
                (rawLevel - _smoothedRecordLevel) * envelopeRate;
            final recordGlow = _smoothedRecordLevel.clamp(0.0, 1.0);
            // Joined (focusT 0) vs detached (focusT 1) aren't just a color
            // swap — they're different *shapes*: one continuous pill with
            // no seam vs. two separate pieces with a gap between them. The
            // glow has to follow whichever shape is actually showing, so it
            // splits the same way everything else here does: full weight on
            // the outer envelope (which paints the whole pill) when joined,
            // full weight on just the field's own box when detached, and a
            // crossfade between the two while focusT is mid-transition.
            //
            // In glassMode there's no detached shape to crossfade toward —
            // the plus/field spacer is pinned to 0 (see the SizedBox below)
            // and widthFactor is pinned to 1.0, so the glass card always
            // reads as one continuous full-width surface regardless of
            // focus. Splitting the glow by focusT there would shrink it
            // down onto just the narrow field piece while focused, even
            // though nothing visually detached — so it always gets full
            // weight on the outer (whole-card) glow instead.
            final outerRecordGlow =
                widget.glassMode ? recordGlow : recordGlow * (1 - focusT);
            final fieldRecordGlow =
                widget.glassMode ? 0.0 : recordGlow * focusT;
            // Color.lerp interpolates alpha too, so lerping a fully
            // transparent `base` (alpha 0 — meant to stay invisible, e.g.
            // the outer envelope's border once detached) toward the fully
            // opaque `colorScheme.error` would resurrect it as a
            // semi-opaque red border. That's what leaked the recording
            // glow onto/around the plus button: the outer envelope wraps
            // the whole row (plus + field), and even "invisible" at
            // alpha 0 it was being tinted visible by this lerp. Tinting
            // hue at full opacity first, then reapplying `base`'s own
            // alpha, keeps anything meant to be invisible actually
            // invisible — only pieces with real, non-zero alpha (i.e. the
            // field's own border) ever show the tint.
            // A fixed (non-animated) tint while recording — a persistent
            // "this is the active piece" cue. The animated signal lives
            // entirely in the shadow bloom above, not here, so the border
            // itself never moves or resizes.
            Color glow(Color base) {
              if (!isRecordingNow) return base;
              final tinted = Color.lerp(
                  base.withValues(alpha: 1.0), colorScheme.error, 0.28)!;
              return tinted.withValues(alpha: base.a);
            }

            // The outer envelope no longer paints a fill at all — only
            // the two pieces do, and they're laid out side by side so
            // they never spatially overlap. Previously the outer fill
            // faded out while the pieces faded in (both semi-transparent,
            // one drawn on top of the other) — alpha compositing two
            // translucent layers of the same color does NOT sum linearly,
            // so mid-fade the combined opacity briefly dipped below the
            // resting value, letting more of whatever's behind the input
            // bar show through and reading as a flash of darker color.
            // With the fill owned by exactly one non-overlapping layer at
            // every instant, there's nothing left to stack.
            final borderColorZero = borderSide.color.withValues(alpha: 0);

            const outerColor = Colors.transparent;
            final outerBorderColor = glow(
              Color.lerp(borderSide.color, borderColorZero, focusT)!,
            );
            // The field's own border glows/pulses while recording (it's the
            // piece next to the mic/waveform, so the glow reads as "this is
            // what's listening"). The plus/attach button intentionally does
            // NOT share this — same lerp, but never passed through glow(),
            // so recording never tints or pulses its border.
            final detachedBorderColor =
                Color.lerp(borderColorZero, borderSide.color, focusT)!;
            final pieceBorderColor = glow(detachedBorderColor);
            final plusBorderColor = detachedBorderColor;
            final plusColor = bgColor;
            final plusRadius = BorderRadius.lerp(
              const BorderRadius.only(
                topLeft: Radius.circular(radius),
                bottomLeft: Radius.circular(radius),
              ),
              BorderRadius.circular(radius),
              focusT,
            )!;
            final fieldColor = bgColor;
            final fieldRadius = widget.meshMode
                ? BorderRadius.circular(radius)
                : BorderRadius.lerp(
                    const BorderRadius.only(
                      topRight: Radius.circular(radius),
                      bottomRight: Radius.circular(radius),
                    ),
                    BorderRadius.circular(radius),
                    focusT,
                  )!;

            return FractionallySizedBox(
              widthFactor: widget.glassMode ? 1.0 : widthFactor,
              child: IntrinsicHeight(
                child: Container(
                  // Single fill + border around the whole pill when joined — the
                  // two inner pieces go transparent in that state (see below) so
                  // there's exactly one painted shape and no seam between them.
                  // When detached (focused), this goes transparent and each
                  // piece paints its own background instead.
                  decoration: BoxDecoration(
                    color: outerColor,
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: outerBorderColor,
                      width: recordBorderWidth,
                      strokeAlign: borderSide.strokeAlign,
                    ),
                    // Whole-pill glow while joined (see outerRecordGlow
                    // above) — this is what makes the bloom wrap the plus
                    // button too instead of stopping at the field's own
                    // edge, matching how the pill reads as one continuous
                    // shape in this state.
                    boxShadow: (isRecordingNow && outerRecordGlow > 0)
                        ? [
                            BoxShadow(
                              color: colorScheme.error
                                  .withValues(alpha: 0.30 * outerRecordGlow),
                              blurRadius: 18 * outerRecordGlow,
                              spreadRadius: 1 * outerRecordGlow,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The Liquid Plus Button (Detachable Bubble).
                      // The outer SizedBox still stretches to the Row's full
                      // cross-axis extent (via CrossAxisAlignment.stretch) so a
                      // multi-line, unfocused/joined TextField still gets a
                      // seamless fill with no gap above/below. But the *visible*
                      // decorated shape is capped to the single-line row height
                      // via the ConstrainedBox below — without that cap, once the
                      // pill is fully round (see `radius` above) a container much
                      // taller than its 48px width paints as a stretched vertical
                      // stadium instead of a circle.
                      if (!widget.meshMode)
                        SizedBox(
                          width: 48,
                          child: Align(
                            alignment: Alignment.center,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  maxHeight: _collapsedRowHeight),
                              child: Container(
                                decoration: BoxDecoration(
                                  // Transparent while joined — the outer pill paints
                                  // the fill then, so there's no seam at the edge
                                  // where this piece meets the text field piece.
                                  color: plusColor,
                                  // Seamless radius when joined, full radius when detached
                                  borderRadius: plusRadius,
                                  border: Border.all(
                                    // Deliberately not `pieceBorderColor`/
                                    // `recordBorderWidth` — the recording glow/pulse is
                                    // scoped to the field piece only (see field border
                                    // below), so the attach button never tints red or
                                    // widens while recording.
                                    color: plusBorderColor,
                                    width: borderSide.width,
                                    strokeAlign: borderSide.strokeAlign,
                                  ),
                                ),
                                child: Center(
                                  child: SizedBox(
                                    height: _collapsedRowHeight,
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.add,
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.7),
                                        size: 24,
                                      ),
                                      onPressed: widget.readOnly
                                          ? null
                                          : widget.onAttachPressed,
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
                          ),
                        ),

                      // Spacer that appears when focused (Liquid detaching effect)
                      if (!widget.meshMode)
                        SizedBox(width: widget.glassMode ? 0 : 8 * focusT),

                      // Main Input Area
                      Expanded(
                        child: MeasureSize(
                          onChange: (size) {
                            if (!mounted) return;
                            final isFirstMeasurement = !_hasMeasuredRowHeight;
                            if (isFirstMeasurement ||
                                size.height < _collapsedRowHeight) {
                              setState(() {
                                _hasMeasuredRowHeight = true;
                                _collapsedRowHeight = size.height;
                              });
                            }
                          },
                          child: Container(
                            key: widget.inputAreaKey,
                            constraints:
                                const BoxConstraints(minHeight: minHeight),
                            decoration: BoxDecoration(
                              // In meshMode this is the only piece (no + button),
                              // so it always paints itself. Otherwise it's
                              // transparent while joined — the outer pill paints
                              // the fill then — and paints itself once detached.
                              color: fieldColor,
                              // Seamless radius when joined, full radius when detached or in meshMode
                              borderRadius: fieldRadius,
                              border: Border.all(
                                color: widget.meshMode
                                    ? outerBorderColor
                                    : pieceBorderColor,
                                width: recordBorderWidth,
                                strokeAlign: borderSide.strokeAlign,
                              ),
                              // The actual "still recording" signal: a soft,
                              // blurred halo that blooms and fades with your
                              // voice (fieldRecordGlow above — the field's
                              // share of recordGlow once detached). BoxShadow
                              // paints outside the box's own bounds without
                              // reserving layout space for it, so the field
                              // never resizes or shifts neighboring widgets —
                              // unlike animating border width would.
                              boxShadow: (isRecordingNow && fieldRecordGlow > 0)
                                  ? [
                                      BoxShadow(
                                        color: colorScheme.error.withValues(
                                            alpha: 0.30 * fieldRecordGlow),
                                        blurRadius: 18 * fieldRecordGlow,
                                        spreadRadius: 1 * fieldRecordGlow,
                                      ),
                                    ]
                                  : null,
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
                                              TextStyle(
                                                  color: colorScheme.onSurface),
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
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              vertical: 12,
                                              horizontal: 0,
                                            ),
                                          ),
                                          onChanged: widget.onChanged,
                                          textInputAction: TextInputAction.none,
                                          contentInsertionConfiguration: widget
                                              .contentInsertionConfiguration,
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
                                              widget.textFocusNode
                                                  .canRequestFocus = true;
                                              setState(() =>
                                                  _focusShieldActive = false);
                                              widget.textFocusNode
                                                  .requestFocus();
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
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              child: SizedBox(
                                                width: 40,
                                                child: IconButton(
                                                  icon: Icon(Icons.delete,
                                                      color: colorScheme.error,
                                                      size: 20),
                                                  onPressed:
                                                      widget.onCancelRecording,
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  splashColor:
                                                      Colors.transparent,
                                                  highlightColor:
                                                      Colors.transparent,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Microphone Button — becomes a live waveform
                                        // while recording (typing/sending keep working
                                        // exactly as before; this is purely visual).
                                        // Скрыт в mesh режиме.
                                        if (!widget.meshMode)
                                          IconButton(
                                            icon: AnimatedSwitcher(
                                              duration: const Duration(
                                                  milliseconds: 200),
                                              transitionBuilder:
                                                  (child, anim) =>
                                                      ScaleTransition(
                                                          scale: anim,
                                                          child: child),
                                              child: isRecording
                                                  ? AnimatedBuilder(
                                                      key: const ValueKey(
                                                          'waveform'),
                                                      animation:
                                                          _recordAnimController,
                                                      builder: (_, __) =>
                                                          CustomPaint(
                                                        size:
                                                            const Size(22, 22),
                                                        painter:
                                                            _WaveformPainter(
                                                          phase:
                                                              _recordAnimController
                                                                  .value,
                                                          color:
                                                              colorScheme.error,
                                                        ),
                                                      ),
                                                    )
                                                  : Icon(
                                                      Icons.mic,
                                                      key:
                                                          const ValueKey('mic'),
                                                      color: colorScheme
                                                          .onSurface
                                                          .withValues(
                                                              alpha: 0.6),
                                                      size: 22,
                                                    ),
                                            ),
                                            onPressed: widget.readOnly
                                                ? null
                                                : () => widget
                                                    .onMicPressed(isRecording),
                                            visualDensity:
                                                VisualDensity.compact,
                                            splashColor: Colors.transparent,
                                            highlightColor: Colors.transparent,
                                          ),

                                        // Send Button — pops/spins in with a spring
                                        // overshoot whenever its active state flips.
                                        IconButton(
                                          icon: AnimatedSwitcher(
                                            duration: const Duration(
                                                milliseconds: 260),
                                            switchInCurve: Curves.easeOutBack,
                                            switchOutCurve: Curves.easeIn,
                                            transitionBuilder: (child, anim) =>
                                                ScaleTransition(
                                              scale: anim,
                                              child: RotationTransition(
                                                turns: Tween<double>(
                                                        begin: 0.7, end: 1.0)
                                                    .animate(anim),
                                                child: child,
                                              ),
                                            ),
                                            child: Icon(
                                              widget.sendIcon ?? Icons.send,
                                              key: ValueKey(
                                                  'send_${widget.sendIcon?.codePoint}_$hasText'),
                                              color: hasText
                                                  ? (widget.sendColor ??
                                                      colorScheme.primary)
                                                  : colorScheme.onSurface
                                                      .withValues(alpha: 0.3),
                                              size: 22,
                                            ),
                                          ),
                                          onPressed:
                                              (widget.readOnly || !hasText)
                                                  ? null
                                                  : widget.onSendPressed,
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
      },
    );
  }
}

// A small procedural waveform (not driven by actual mic amplitude — there's
// no live audio level plumbed to this widget) standing in for the static mic
// icon while recording, so the button reads as "listening" rather than idle.
class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.phase, required this.color});

  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    const barCount = 4;
    final spacing = size.width / barCount;
    final center = size.height / 2;
    for (var i = 0; i < barCount; i++) {
      final freq = 1.0 + i * 0.6;
      final phaseOffset = i * 0.9;
      final wave = math.sin(phase * 2 * math.pi * freq + phaseOffset).abs();
      final amplitude = 0.35 + 0.65 * wave;
      final barHeight = size.height * amplitude;
      final x = spacing * (i + 0.5);
      canvas.drawLine(
        Offset(x, center - barHeight / 2),
        Offset(x, center + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}
