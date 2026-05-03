// lib/widgets/mini_player_banner.dart
import 'package:flutter/material.dart';
import '../utils/global_audio_controller.dart';
import 'full_player_sheet.dart';

/// Telegram / iPhone-style mini-player that slides in from the top whenever
/// a voice or music file is playing. Controlled entirely by
/// [globalAudioController]. Tap the track area to expand to full player.
class MiniPlayerBanner extends StatelessWidget {
  const MiniPlayerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Outer builder: shows/hides the card (AnimatedSize driven by isActive).
    return AnimatedBuilder(
      animation: globalAudioController,
      builder: (context, _) {
        return AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: globalAudioController.isActive
              ? const _MiniPlayerCard()
              : const SizedBox.shrink(),
        );
      },
    );
  }
}

/// The actual card. Uses its OWN AnimatedBuilder so that position/state
/// updates (which come many times per second) cause a rebuild here, not in
/// the outer AnimatedSize (which would re-animate the height on every tick).
class _MiniPlayerCard extends StatelessWidget {
  const _MiniPlayerCard();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: globalAudioController,
      builder: (context, _) => _buildCard(context),
    );
  }

  String _fmt(Duration d) {
    if (d == Duration.zero) return '0:00';
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildCard(BuildContext context) {
    final ctrl = globalAudioController;
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.surface.computeLuminance() > 0.5;

    final double rawProgress = ctrl.duration.inMilliseconds > 0
        ? ctrl.position.inMilliseconds / ctrl.duration.inMilliseconds
        : 0.0;
    final double progress = rawProgress.clamp(0.0, 1.0);

    final bgColor =
        isLight ? cs.surfaceContainerHighest : cs.surfaceContainerHigh;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 2, 8, 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.12 : 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Top row ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
              child: Row(
                children: [
                  // Left tappable zone: icon + name + timer → opens full player
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => FullPlayerSheet.show(context),
                      child: Row(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Icon(
                              key: ValueKey(ctrl.isPlaying),
                              ctrl.isPlaying
                                  ? Icons.graphic_eq_rounded
                                  : (ctrl.isFile
                                      ? Icons.music_note_rounded
                                      : Icons.mic_rounded),
                              size: 20,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ctrl.trackName ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                                letterSpacing: -0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${_fmt(ctrl.position)} / ${_fmt(ctrl.duration)}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: cs.onSurface.withValues(alpha: 0.5),
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                  // ─── Controls (not part of the tap zone) ───────────
                  _Btn(
                    icon: Icons.replay_10_rounded,
                    size: 21,
                    color: cs.onSurface.withValues(alpha: 0.75),
                    onTap: () {
                      final np =
                          ctrl.position - const Duration(seconds: 10);
                      ctrl.seek(np.isNegative ? Duration.zero : np);
                    },
                  ),
                  _Btn(
                    icon: ctrl.isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_filled_rounded,
                    size: 34,
                    color: cs.primary,
                    onTap: ctrl.playPause,
                  ),
                  _Btn(
                    icon: Icons.forward_10_rounded,
                    size: 21,
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
                    icon: Icons.close_rounded,
                    size: 17,
                    color: cs.onSurface.withValues(alpha: 0.4),
                    onTap: ctrl.stopAndClose,
                  ),
                ],
              ),
            ),
            // ── Progress slider ─────────────────────────────────────
            SizedBox(
              height: 28,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2.5,
                  thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5.5),
                  overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 11),
                  activeTrackColor: cs.primary,
                  inactiveTrackColor: cs.primary.withValues(alpha: 0.2),
                  thumbColor: cs.primary,
                  overlayColor: cs.primary.withValues(alpha: 0.15),
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
            ),
          ],
        ),
      ),
    );
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
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}
