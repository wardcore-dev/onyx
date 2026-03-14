import 'package:flutter/material.dart';

class FpsStimulator extends StatefulWidget {
  
  final bool enabled;

  const FpsStimulator({Key? key, this.enabled = true}) : super(key: key);

  @override
  State<FpsStimulator> createState() => _FpsStimulatorState();
}

class _FpsStimulatorState extends State<FpsStimulator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      
      duration: const Duration(milliseconds: 16),
    );

    if (widget.enabled) {
      
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    return SizedBox(
      width: 1,
      height: 1,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            return CustomPaint(
              size: const Size(1, 1),
              painter: _FpsPixelPainter(),
            );
          },
        ),
      ),
    );
  }
}

class _FpsPixelPainter extends CustomPainter {
  final Paint _paint = Paint()..color = const Color(0x01000000);

  @override
  void paint(Canvas canvas, Size size) {
    
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1, 1), _paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}