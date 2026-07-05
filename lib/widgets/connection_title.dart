import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ONYX/globals.dart';
import 'package:ONYX/managers/settings_manager.dart';

class ConnectionTitle extends StatefulWidget {
  final TextStyle? style;
  const ConnectionTitle({Key? key, this.style}) : super(key: key);

  @override
  State<ConnectionTitle> createState() => _ConnectionTitleState();
}

class _ConnectionTitleState extends State<ConnectionTitle> {
  @override
  Widget build(BuildContext context) {
    final baseStyle =
        widget.style ?? const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);

    return ValueListenableBuilder<bool>(
      valueListenable: SettingsManager.meshModeEnabled,
      builder: (_, meshEnabled, __) {
        return ValueListenableBuilder<bool>(
          valueListenable: wsConnectedNotifier,
          builder: (_, connected, __) {
            Widget child;

            if (connected || meshEnabled) {
              child = Text(
                'ONYX',
                key: const ValueKey('title_onyx'),
                style: baseStyle,
              );
            } else {
              child = Row(
                key: const ValueKey('title_connecting'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Connecting',
                    style: baseStyle.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  AnimatedDots(
                    style: baseStyle.copyWith(
                      fontWeight: FontWeight.w400,
                      fontSize: (baseStyle.fontSize ?? 20) * 0.9,
                    ),
                  ),
                ],
              );
            }

            return AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.12),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: child,
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class AnimatedDots extends StatefulWidget {
  final TextStyle? style;
  final Duration interval;
  const AnimatedDots({
    super.key,
    this.style,
    this.interval = const Duration(milliseconds: 500),
  });

  @override
  State<AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<AnimatedDots> {
  int _count = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) {
      setState(() => _count = (_count + 1) % 4);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text('.' * _count,
        style: widget.style ?? const TextStyle(fontSize: 20));
  }
}
