// lib/widgets/voice_channel_bar.dart
//
// Floating bar shown at the bottom of the app when the user is in a voice
// channel. Mirrors the Discord "connected to voice" indicator.

import 'package:flutter/material.dart';
import '../voice/voice_channel_manager.dart';
import '../managers/settings_manager.dart';

class VoiceChannelBar extends StatelessWidget {
  const VoiceChannelBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: VoiceChannelManager.instance.isInChannel,
      builder: (_, inChannel, __) {
        if (!inChannel) return const SizedBox.shrink();

        return ValueListenableBuilder<String?>(
          valueListenable: VoiceChannelManager.instance.currentChannelId,
          builder: (_, channelId, __) {
            return ValueListenableBuilder<bool>(
              valueListenable: VoiceChannelManager.instance.isMuted,
              builder: (_, muted, __) {
                return ValueListenableBuilder<List<String>>(
                  valueListenable: VoiceChannelManager.instance.channelUsers,
                  builder: (_, users, __) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: SettingsManager.debugMode,
                      builder: (_, debugMode, __) {
                        return ValueListenableBuilder<int>(
                          valueListenable:
                              VoiceChannelManager.instance.selfMonitorMode,
                          builder: (_, monitorMode, __) {
                            return ValueListenableBuilder<double>(
                              valueListenable:
                                  VoiceChannelManager.instance.audioLevel,
                              builder: (_, level, __) {
                                return _Bar(
                                  channelId: channelId ?? '',
                                  userCount: users.length + 1,
                                  muted: muted,
                                  debugMode: debugMode,
                                  monitorMode: monitorMode,
                                  audioLevel: level,
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.channelId,
    required this.userCount,
    required this.muted,
    required this.debugMode,
    required this.monitorMode,
    required this.audioLevel,
  });

  final String channelId;
  final int userCount;
  final bool muted;
  final bool debugMode;
  /// 0=off  1=WebRTC loopback  2=direct PCM
  final int monitorMode;
  final double audioLevel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DefaultTextStyle(
      style: TextStyle(
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        decoration: TextDecoration.none,
        color: scheme.onSurface,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF43B581),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.volume_up_rounded, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    channelId,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$userCount connected',
                    style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            if (debugMode) ...[
              _BarIconButton(
                icon: monitorMode == 1
                    ? Icons.hearing_rounded
                    : monitorMode == 2
                        ? Icons.surround_sound_rounded
                        : Icons.hearing_disabled_rounded,
                color: monitorMode == 1
                    ? const Color(0xFF43B581)
                    : monitorMode == 2
                        ? Colors.amber
                        : scheme.onSurface,
                tooltip: monitorMode == 1
                    ? 'Monitoring: server'
                    : monitorMode == 2
                        ? 'Monitoring: direct'
                        : 'Monitor self',
                onTap: () => VoiceChannelManager.instance.toggleSelfMonitor(),
              ),
              const SizedBox(width: 4),
            ],
            _MicVuButton(
              muted: muted,
              audioLevel: audioLevel,
              onTap: () => VoiceChannelManager.instance.toggleMute(),
            ),
            const SizedBox(width: 4),
            _BarIconButton(
              icon: Icons.call_end_rounded,
              color: scheme.error,
              tooltip: 'Leave channel',
              onTap: () => VoiceChannelManager.instance.leaveChannel(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mic button with a FL-Studio-style VU fill that rises from the bottom
/// as the user's input level increases. Red when muted, green fill when active.
class _MicVuButton extends StatelessWidget {
  const _MicVuButton({
    required this.muted,
    required this.audioLevel,
    required this.onTap,
  });

  final bool muted;
  final double audioLevel; // 0.0–1.0 normalised mic level
  final VoidCallback onTap;

  static const _kGreen = Color(0xFF43B581);
  // Scale level up so normal speech (0.05–0.2 range) fills a good chunk of the button.
  static const _kBoost = 4.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final boosted = (audioLevel * _kBoost).clamp(0.0, 1.0);
    final active = !muted && boosted > 0.02;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Stack(
            children: [
              // Base background
              Positioned.fill(
                child: ColoredBox(
                  color: muted
                      ? scheme.error.withValues(alpha: 0.12)
                      : scheme.onSurface.withValues(alpha: 0.12),
                ),
              ),
              // VU green fill rising from the bottom
              if (active)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: boosted,
                    widthFactor: 1.0,
                    child: ColoredBox(
                      color: _kGreen.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              // Icon on top
              Center(
                child: Icon(
                  muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  size: 20,
                  color: muted
                      ? scheme.error
                      : (active ? _kGreen : scheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarIconButton extends StatelessWidget {
  const _BarIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}
