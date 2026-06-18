// lib/widgets/full_player_sheet.dart
import 'package:flutter/material.dart';
import '../utils/global_audio_controller.dart';

class FullPlayerSheet extends StatelessWidget {
  const FullPlayerSheet({super.key});

  /// Presented as a large centered dialog (Spotify/Apple Music "Now Playing"
  /// style) instead of a sheet sliding up from the bottom.
  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Now Playing',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (_, __, ___) => const FullPlayerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final isWide = mq.size.width > 700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isWide ? 40 : 20,
        vertical: 32,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: mq.size.height * 0.88,
          ),
          child: Material(
            color: cs.surface,
            borderRadius: BorderRadius.circular(28),
            child: AnimatedBuilder(
              animation: globalAudioController,
              builder: (context, _) => _buildContent(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final ctrl = globalAudioController;
    final cs = Theme.of(context).colorScheme;

    final double progress = ctrl.duration.inMilliseconds > 0
        ? (ctrl.position.inMilliseconds / ctrl.duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glowColor = cs.primary;

    return Stack(
      children: [
        // ── Ambient glow backdrop (stand-in for blurred album art) ─────────
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.6),
                radius: 1.1,
                colors: [
                  glowColor.withValues(alpha: isDark ? 0.22 : 0.12),
                  cs.surface.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.06),
                border: Border(
                  bottom: BorderSide(color: cs.primary.withValues(alpha: 0.10), width: 0.8),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.graphic_eq_rounded, size: 18, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Now Playing',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: cs.onSurface)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.close_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.55)),
                    ),
                  ),
                ],
              ),
            ),
            // Flexible (not Expanded) so this only takes as much height as its
            // content actually needs, up to the dialog's max — Expanded was
            // forcing it to always fill the full 88%-of-screen bound, leaving
            // an empty stretch below the controls whenever content was shorter.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 14),

                    // ── Large art / icon ───────────────────────────────────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        key: ValueKey(ctrl.isPlaying),
                        width: 196,
                        height: 196,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              cs.primary.withValues(alpha: 0.9),
                              cs.primary.withValues(alpha: 0.55),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: glowColor.withValues(
                                  alpha: ctrl.isPlaying ? 0.45 : 0.2),
                              blurRadius: ctrl.isPlaying ? 56 : 28,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Icon(
                                ctrl.isFile
                                    ? Icons.music_note_rounded
                                    : Icons.mic_rounded,
                                size: 80,
                                color: cs.onPrimary.withValues(alpha: 0.95),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Track name ─────────────────────────────────────────────
                    Text(
                      ctrl.isFile
                          ? (ctrl.trackName?.isNotEmpty == true
                              ? ctrl.trackName!
                              : 'Audio')
                          : 'Voice Message',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        fontSize: 21,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ctrl.isFile ? 'Audio file' : 'Voice message',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.45),
                      ),
                    ),

                    const SizedBox(height: 20),

                // ── Progress slider ────────────────────────────────────────
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4.5,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: cs.primary,
                    inactiveTrackColor: cs.primary.withValues(alpha: 0.18),
                    thumbColor: cs.primary,
                    overlayColor: cs.primary.withValues(alpha: 0.12),
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: (v) {
                      if (ctrl.duration == Duration.zero) return;
                      ctrl.seek(Duration(
                        milliseconds:
                            (v * ctrl.duration.inMilliseconds).round(),
                      ));
                    },
                  ),
                ),

                // ── Time row ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmt(ctrl.position),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.45),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        _fmt(ctrl.duration),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.45),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Transport: prev / -10s / play-pause / +10s / next ──────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Btn(
                      icon: Icons.skip_previous_rounded,
                      size: 32,
                      color: ctrl.hasPrev
                          ? cs.onSurface.withValues(alpha: 0.8)
                          : cs.onSurface.withValues(alpha: 0.2),
                      onTap: ctrl.hasPrev ? ctrl.playPrev : () {},
                    ),
                    _Btn(
                      icon: Icons.replay_10_rounded,
                      size: 36,
                      color: cs.onSurface.withValues(alpha: 0.75),
                      onTap: () {
                        final np =
                            ctrl.position - const Duration(seconds: 10);
                        ctrl.seek(np.isNegative ? Duration.zero : np);
                      },
                    ),
                    GestureDetector(
                      onTap: ctrl.playPause,
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          ctrl.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 36,
                          color: cs.onPrimary,
                        ),
                      ),
                    ),
                    _Btn(
                      icon: Icons.forward_10_rounded,
                      size: 36,
                      color: cs.onSurface.withValues(alpha: 0.75),
                      onTap: () {
                        if (ctrl.duration == Duration.zero) return;
                        final np =
                            ctrl.position + const Duration(seconds: 10);
                        ctrl.seek(
                            np > ctrl.duration ? ctrl.duration : np);
                      },
                    ),
                    _Btn(
                      icon: Icons.skip_next_rounded,
                      size: 32,
                      color: ctrl.hasNext
                          ? cs.onSurface.withValues(alpha: 0.8)
                          : cs.onSurface.withValues(alpha: 0.2),
                      onTap: ctrl.hasNext ? ctrl.playNext : () {},
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Speed control ──────────────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Preset row + speed readout + autoplay
                    Row(
                      children: [
                        _PresetChip(
                          label: '0.5x',
                          speed: 0.5,
                          current: ctrl.playbackSpeed,
                          cs: cs,
                        ),
                        const SizedBox(width: 8),
                        _PresetChip(
                          label: '1x',
                          speed: 1.0,
                          current: ctrl.playbackSpeed,
                          cs: cs,
                        ),
                        const SizedBox(width: 8),
                        _PresetChip(
                          label: '2x',
                          speed: 2.0,
                          current: ctrl.playbackSpeed,
                          cs: cs,
                        ),
                        const SizedBox(width: 8),
                        _PresetChip(
                          label: '3x',
                          speed: 3.0,
                          current: ctrl.playbackSpeed,
                          cs: cs,
                        ),
                        const Spacer(),
                        // Speed readout
                        Text(
                          '${_fmtSpeed(ctrl.playbackSpeed)}x',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Slider
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8),
                        overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 16),
                        activeTrackColor: cs.primary,
                        inactiveTrackColor: cs.primary.withValues(alpha: 0.15),
                        thumbColor: cs.primary,
                        overlayColor: cs.primary.withValues(alpha: 0.1),
                      ),
                      child: Slider(
                        value: ctrl.playbackSpeed.clamp(0.25, 4.0),
                        min: 0.25,
                        max: 4.0,
                        divisions: 15, // steps of 0.25
                        onChanged: (v) {
                          final snapped =
                              ((v * 4).round() / 4.0).clamp(0.25, 4.0);
                          globalAudioController.setPlaybackSpeed(snapped);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('0.25x',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurface.withValues(alpha: 0.35))),
                          // Autoplay toggle (center-ish)
                          GestureDetector(
                            onTap: () => globalAudioController
                                .setAutoPlay(!ctrl.autoPlay),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: ctrl.autoPlay
                                    ? cs.primaryContainer
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: ctrl.autoPlay
                                      ? cs.primary
                                      : cs.onSurface.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.repeat_rounded,
                                      size: 13,
                                      color: ctrl.autoPlay
                                          ? cs.primary
                                          : cs.onSurface
                                              .withValues(alpha: 0.4)),
                                  const SizedBox(width: 4),
                                  Text('Auto',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: ctrl.autoPlay
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: ctrl.autoPlay
                                            ? cs.primary
                                            : cs.onSurface
                                                .withValues(alpha: 0.4),
                                      )),
                                ],
                              ),
                            ),
                          ),
                          Text('4x',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurface.withValues(alpha: 0.35))),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Volume ───────────────────────────────────────────────────
                Row(
                  children: [
                    Icon(
                      ctrl.volume <= 0.0
                          ? Icons.volume_off_rounded
                          : (ctrl.volume < 0.5
                              ? Icons.volume_down_rounded
                              : Icons.volume_up_rounded),
                      size: 18,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14),
                          activeTrackColor: cs.primary,
                          inactiveTrackColor:
                              cs.primary.withValues(alpha: 0.15),
                          thumbColor: cs.primary,
                          overlayColor: cs.primary.withValues(alpha: 0.1),
                        ),
                        child: Slider(
                          value: ctrl.volume.clamp(0.0, 1.0),
                          onChanged: globalAudioController.setVolume,
                        ),
                      ),
                    ),
                    Icon(Icons.volume_up_rounded,
                        size: 18, color: cs.onSurface.withValues(alpha: 0.55)),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Stop ─────────────────────────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                        width: 0.8,
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          globalAudioController.stopAndClose();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.stop_rounded, size: 18, color: Colors.red),
                        label: const Text(
                          'Stop',
                          style: TextStyle(fontSize: 15, color: Colors.red),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.12),
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    if (d == Duration.zero) return '0:00';
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _fmtSpeed(double s) {
    final str = s.toStringAsFixed(2);
    return str.replaceAll(RegExp(r'\.?0+$'), '');
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback onTap;

  const _Btn({
    required this.icon,
    required this.size,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final double speed;
  final double current;
  final ColorScheme cs;

  const _PresetChip({
    required this.label,
    required this.speed,
    required this.current,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final selected = (current - speed).abs() < 0.01;
    return GestureDetector(
      onTap: () => globalAudioController.setPlaybackSpeed(speed),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? cs.onPrimary
                : cs.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}
