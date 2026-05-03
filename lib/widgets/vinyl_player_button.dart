// lib/widgets/vinyl_player_button.dart
import 'dart:math' show pi;
import 'package:flutter/material.dart';
import '../globals.dart' show navigatorKey;
import '../utils/global_audio_controller.dart';
import 'full_player_sheet.dart';

/// Floats above all screens (placed as a child of the app-level Stack in
/// MaterialApp.builder). Returns Positioned when active, SizedBox.shrink when
/// not — both are valid Stack children. Tap = play/pause, long-press = full
/// player, drag = reposition.
class VinylPlayerButton extends StatefulWidget {
  const VinylPlayerButton({super.key});

  @override
  State<VinylPlayerButton> createState() => _VinylPlayerButtonState();
}

class _VinylPlayerButtonState extends State<VinylPlayerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  // Lazily initialised from MediaQuery on first active build.
  Offset? _pos;

  @override
  void initState() {
    super.initState();

    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          _spin.value = 0;
          if (globalAudioController.isPlaying) _spin.forward();
        }
      });

    globalAudioController.addListener(_onAudio);
  }

  void _onAudio() {
    if (!mounted) return;
    _syncSpin();
    setState(() {});
  }

  void _syncSpin() {
    if (globalAudioController.isPlaying) {
      if (!_spin.isAnimating) _spin.forward();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    globalAudioController.removeListener(_onAudio);
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!globalAudioController.isActive) return const SizedBox.shrink();

    final mq = MediaQuery.of(context);
    // Default position: top-right corner, below status bar.
    _pos ??= Offset(mq.size.width - 74, mq.viewPadding.top + 108);

    final cs = Theme.of(context).colorScheme;
    final isPlaying = globalAudioController.isPlaying;

    return Positioned(
      left: _pos!.dx,
      top: _pos!.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) {
          setState(() {
            _pos = Offset(
              (_pos!.dx + d.delta.dx).clamp(0.0, mq.size.width - 58),
              (_pos!.dy + d.delta.dy)
                  .clamp(mq.viewPadding.top, mq.size.height - 100),
            );
          });
        },
        onTap: globalAudioController.playPause,
        onLongPress: () {
          // VinylPlayerButton lives above the Navigator in MaterialApp.builder,
          // so its own context has no Navigator ancestor. Use the overlay
          // context from the root navigator, which IS below the Navigator.
          final navCtx = navigatorKey.currentState?.overlay?.context;
          FullPlayerSheet.show(navCtx ?? context);
        },
        child: AnimatedBuilder(
          animation: _spin,
          builder: (_, __) => Transform.rotate(
            angle: _spin.value * 2 * pi,
            child: _VinylDisc(
              isPlaying: isPlaying,
              primaryColor: cs.primary,
              primaryContainer: cs.primaryContainer,
              onPrimaryContainer: cs.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Vinyl disc visual ─────────────────────────────────────────────────────────

class _VinylDisc extends StatelessWidget {
  final bool isPlaying;
  final Color primaryColor;
  final Color primaryContainer;
  final Color onPrimaryContainer;

  const _VinylDisc({
    required this.isPlaying,
    required this.primaryColor,
    required this.primaryContainer,
    required this.onPrimaryContainer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: primaryColor.withValues(alpha: isPlaying ? 0.45 : 0.0),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: CustomPaint(
        painter: _VinylPainter(primaryColor: primaryColor),
        child: Center(
          child: Container(
            width: 21,
            height: 21,
            decoration: BoxDecoration(
              color: primaryContainer,
              shape: BoxShape.circle,
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.65),
                width: 1.5,
              ),
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 12,
              color: onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

class _VinylPainter extends CustomPainter {
  final Color primaryColor;
  const _VinylPainter({required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0D0D0D));

    final groove = Paint()
      ..color = const Color(0xFF272727)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    final inner = r * 0.36;
    final outer = r * 0.91;
    for (int i = 0; i <= 11; i++) {
      canvas.drawCircle(c, inner + (outer - inner) * i / 11, groove);
    }

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.55, -0.55),
          radius: 1.0,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    canvas.drawCircle(c, r * 0.335,
        Paint()..color = primaryColor.withValues(alpha: 0.88));

    canvas.drawCircle(c, r * 0.055, Paint()..color = const Color(0xFF060606));
  }

  @override
  bool shouldRepaint(_VinylPainter old) => old.primaryColor != primaryColor;
}
