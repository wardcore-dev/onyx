import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ONYX/globals.dart';

class ConnectionTitle extends StatefulWidget {
  final TextStyle? style;
  const ConnectionTitle({Key? key, this.style}) : super(key: key);

  @override
  _ConnectionTitleState createState() => _ConnectionTitleState();
}

class _ConnectionTitleState extends State<ConnectionTitle> {
  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.style ?? const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);

    return ValueListenableBuilder<bool>(
      valueListenable: wsConnectedNotifier,
      builder: (_, connected, __) {
        final textChild = AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, -0.1), end: Offset.zero).animate(animation), child: child)),
          child: connected
              ? KeyedSubtree(
                  key: const ValueKey('onyx'),
                  child: Text('ONYX', style: baseStyle),
                )
              : KeyedSubtree(
                  key: const ValueKey('connecting'),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Text('Connecting', style: baseStyle.copyWith(fontWeight: FontWeight.w600)), const SizedBox(width: 6), AnimatedDots(style: baseStyle.copyWith(fontWeight: FontWeight.w400, fontSize: (baseStyle.fontSize ?? 20) * 0.9))]),
                ),
        );

        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: textChild,
        );
      },
    );
  }
}

class AnimatedDots extends StatefulWidget {
  final TextStyle? style;
  final Duration interval;
  const AnimatedDots({Key? key, this.style, this.interval = const Duration(milliseconds: 500)}) : super(key: key);
  @override
  _AnimatedDotsState createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<AnimatedDots> {
  int _count = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (t) {
      setState(() {
        _count = (_count + 1) % 4; 
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _count;
    return Text(dots, style: widget.style ?? const TextStyle(fontSize: 20));
  }
}