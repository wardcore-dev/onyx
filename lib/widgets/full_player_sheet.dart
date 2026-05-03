// lib/widgets/full_player_sheet.dart
import 'package:flutter/material.dart';
import '../utils/global_audio_controller.dart';

class FullPlayerSheet extends StatelessWidget {
  const FullPlayerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => const FullPlayerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = MediaQuery.of(context).size.height;
    return Container(
      height: h * 0.88,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: AnimatedBuilder(
        animation: globalAudioController,
        builder: (context, _) => _buildContent(context),
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

    return Column(
      children: [
        // ── Drag handle ────────────────────────────────────────────────────
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 24),

                // ── Large art / icon ───────────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey(ctrl.isPlaying),
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(
                              alpha: ctrl.isPlaying ? 0.4 : 0.15),
                          blurRadius: ctrl.isPlaying ? 48 : 24,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Icon(
                      ctrl.isPlaying
                          ? Icons.graphic_eq_rounded
                          : (ctrl.isFile
                              ? Icons.music_note_rounded
                              : Icons.mic_rounded),
                      size: 84,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Track name ─────────────────────────────────────────────
                Text(
                  ctrl.trackName ?? '',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        fontSize: 20,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  ctrl.isFile ? 'Audio file' : 'Voice message',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
                ),

                const SizedBox(height: 24),

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

                const SizedBox(height: 28),

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

                const Spacer(),

                // ── Close row ──────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 22),
                      label: const Text('Minimize'),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        globalAudioController.stopAndClose();
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Stop'),
                      style: TextButton.styleFrom(
                        foregroundColor: cs.error.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected
                ? cs.onPrimaryContainer
                : cs.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}
