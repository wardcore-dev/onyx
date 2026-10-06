import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ONYX/globals.dart';
import 'package:ONYX/managers/settings_manager.dart';
import 'package:ONYX/services/onion/onion_identity.dart';

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

    // Title doubles as the Tor status: plain "ONYX" when everything is fine
    // (or Onion mode is off), a live "Tor N%" while bootstrapping, and
    // "Tor offline" if it failed to start.
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsManager.onionModeEnabled,
      builder: (_, onionOn, __) {
        return ValueListenableBuilder<OnionStatus>(
          valueListenable: OnionIdentity.status,
          builder: (_, st, __) {
            final booting = onionOn && st.phase == OnionPhase.bootstrapping;
            final failed = onionOn && st.phase == OnionPhase.failed;
            Widget child;

            if (booting) {
              child = Row(
                key: const ValueKey('title_tor_boot'),
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
            } else if (failed) {
              child = Text(
                'Tor offline',
                key: const ValueKey('title_tor_failed'),
                style: baseStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.error,
                ),
              );
            } else {
              child = Text(
                'ONYX',
                key: const ValueKey('title_onyx'),
                style: baseStyle,
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
