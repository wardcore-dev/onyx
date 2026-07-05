// lib/widgets/scrub_slider.dart
import 'package:flutter/material.dart';

/// A [Slider] that tracks drag position locally instead of the live
/// `progress` value while the user is dragging. Without this, a slider bound
/// directly to a playback-position stream fights the drag gesture on every
/// tick (several times a second) and the thumb visibly jitters. The seek
/// itself only fires once, in [onSeekEnd], instead of on every drag delta —
/// continuous seeking during a drag is what made scrubbing feel stuttery.
class ScrubSlider extends StatefulWidget {
  final double progress; // 0..1
  final SliderThemeData sliderTheme;
  final ValueChanged<double> onSeekEnd; // receives the released 0..1 value

  const ScrubSlider({
    super.key,
    required this.progress,
    required this.sliderTheme,
    required this.onSeekEnd,
  });

  @override
  State<ScrubSlider> createState() => _ScrubSliderState();
}

class _ScrubSliderState extends State<ScrubSlider> {
  bool _dragging = false;
  double _dragValue = 0;

  @override
  Widget build(BuildContext context) {
    final value = (_dragging ? _dragValue : widget.progress).clamp(0.0, 1.0);
    return SliderTheme(
      data: widget.sliderTheme,
      child: Slider(
        value: value,
        onChangeStart: (v) => setState(() {
          _dragging = true;
          _dragValue = v;
        }),
        onChanged: (v) => setState(() => _dragValue = v),
        onChangeEnd: (v) {
          setState(() => _dragging = false);
          widget.onSeekEnd(v);
        },
      ),
    );
  }
}
