// lib/widgets/marquee_text.dart
import 'package:flutter/material.dart';

/// Displays [text] normally when it fits, or animates it ping-pong style
/// (scroll right, pause, scroll back) when it overflows the available width.
class MarqueeText extends StatefulWidget {
  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.pauseDuration = const Duration(milliseconds: 1500),
    this.velocity = 40.0,
  });

  final String text;
  final TextStyle? style;
  final Duration pauseDuration;
  /// Scroll speed in logical pixels per second.
  final double velocity;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final ScrollController _sc = ScrollController();
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
  }

  @override
  void didUpdateWidget(MarqueeText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _running = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_sc.hasClients) _sc.jumpTo(0);
        _maybeStart();
      });
    }
  }

  void _maybeStart() {
    if (!mounted || !_sc.hasClients) return;
    final max = _sc.position.maxScrollExtent;
    if (max > 0) _loop(max);
  }

  Future<void> _loop(double max) async {
    if (_running) return;
    _running = true;
    final dur = Duration(milliseconds: (max / widget.velocity * 1000).round());
    while (_running && mounted) {
      await Future.delayed(widget.pauseDuration);
      if (!_running || !mounted) break;
      await _sc.animateTo(max, duration: dur, curve: Curves.easeInOut);
      if (!_running || !mounted) break;
      await Future.delayed(widget.pauseDuration);
      if (!_running || !mounted) break;
      await _sc.animateTo(0, duration: dur, curve: Curves.easeInOut);
    }
    _running = false;
  }

  @override
  void dispose() {
    _running = false;
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SingleChildScrollView(
        controller: _sc,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(
          widget.text,
          style: widget.style,
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );
  }
}
