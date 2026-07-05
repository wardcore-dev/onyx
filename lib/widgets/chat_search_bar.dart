// lib/widgets/chat_search_bar.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../enums/liquid_glass_quality.dart';
import '../managers/settings_manager.dart';

class ChatSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  /// (current: 1-based, total). current==0 means no matches.
  final ValueNotifier<({int current, int total})> statsNotifier;

  final ValueChanged<String> onChanged;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onClose;

  const ChatSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.statsNotifier,
    required this.onChanged,
    required this.onClose,
    this.onPrevious,
    this.onNext,
  });

  // Liquid glass on Android, iOS and macOS; on Windows/Linux — standard render
  // (matches the input bar's platform gate elsewhere in the app).
  static bool get _glassAllowed => !Platform.isWindows && !Platform.isLinux;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementOpacity,
      builder: (_, opacity, __) {
        return ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementBrightness,
          builder: (_, brightness, __) {
            final barColor = SettingsManager.getElementColor(
              cs.surfaceContainerHighest,
              brightness,
            ).withValues(alpha: opacity.clamp(0.85, 1.0));
            final btnBg = SettingsManager.getElementColor(
              cs.surfaceContainer,
              brightness,
            ).withValues(alpha: opacity.clamp(0.7, 1.0));
            final borderColor = cs.outlineVariant.withValues(alpha: 0.3);

            Widget pillBtn({
              required IconData icon,
              required VoidCallback? onTap,
              Color? iconColor,
              bool active = false,
            }) {
              return GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(19),
                    color: active
                        ? cs.primary.withValues(alpha: 0.15)
                        : btnBg,
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: iconColor ??
                        cs.onSurface.withValues(
                            alpha: onTap != null ? 0.75 : 0.3),
                  ),
                ),
              );
            }

            final content = Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── search field ─────────────────────────────────────────
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: true,
                    cursorColor: cs.primary,
                    decoration: InputDecoration(
                      hintText: 'Search in chat...',
                      hintStyle: TextStyle(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: cs.onSurface.withValues(alpha: 0.75),
                      ),
                      border: InputBorder.none,
                      filled: false,
                      isDense: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    style: TextStyle(fontSize: 14, color: cs.onSurface),
                    onChanged: onChanged,
                  ),
                ),

                // ── match counter ─────────────────────────────────────────
                ValueListenableBuilder(
                  valueListenable: statsNotifier,
                  builder: (_, stats, __) {
                    final hasQuery = controller.text.isNotEmpty;
                    final noMatch = hasQuery && stats.total == 0;
                    final hasMatch = stats.total > 0;

                    if (!hasQuery) return const SizedBox.shrink();

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: noMatch
                            ? cs.error.withValues(alpha: 0.15)
                            : hasMatch
                                ? cs.primary.withValues(alpha: 0.13)
                                : Colors.transparent,
                        border: Border.all(
                          color: noMatch
                              ? cs.error.withValues(alpha: 0.35)
                              : hasMatch
                                  ? cs.primary.withValues(alpha: 0.3)
                                  : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        noMatch
                            ? 'No results'
                            : '${stats.current} / ${stats.total}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: noMatch
                              ? cs.error.withValues(alpha: 0.85)
                              : cs.primary.withValues(alpha: 0.85),
                        ),
                      ),
                    );
                  },
                ),

                // ── nav buttons ───────────────────────────────────────────
                pillBtn(
                  icon: Icons.keyboard_arrow_up_rounded,
                  onTap: onPrevious,
                ),
                const SizedBox(width: 6),
                pillBtn(
                  icon: Icons.keyboard_arrow_down_rounded,
                  onTap: onNext,
                ),
                const SizedBox(width: 6),
                pillBtn(
                  icon: Icons.close_rounded,
                  onTap: onClose,
                  iconColor: cs.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 2),
              ],
            );

            if (!_glassAllowed) {
              return _buildStandard(cs, barColor, borderColor, content);
            }
            return ValueListenableBuilder<bool>(
              valueListenable: SettingsManager.liquidGlassOnSearch,
              builder: (_, onSearch, __) {
                if (!onSearch) {
                  return _buildStandard(cs, barColor, borderColor, content);
                }
                return _buildGlass(context, content);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStandard(
      ColorScheme cs, Color barColor, Color borderColor, Widget content) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: content,
    );
  }

  Widget _buildGlass(BuildContext context, Widget content) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        SettingsManager.liquidGlassSearchQuality,
        SettingsManager.liquidGlassSearchBlur,
        SettingsManager.liquidGlassSearchTint,
        SettingsManager.liquidGlassSearchSaturation,
        SettingsManager.liquidGlassSearchChromatic,
        SettingsManager.liquidGlassSearchRefractive,
        SettingsManager.liquidGlassSearchLightIntensity,
        SettingsManager.liquidGlassSearchThickness,
      ]),
      builder: (context, _) {
        final quality        = SettingsManager.liquidGlassSearchQuality.value;
        final blur           = SettingsManager.liquidGlassSearchBlur.value;
        final tint           = SettingsManager.liquidGlassSearchTint.value;
        final saturation     = SettingsManager.liquidGlassSearchSaturation.value;
        final chromatic      = SettingsManager.liquidGlassSearchChromatic.value;
        final refractive     = SettingsManager.liquidGlassSearchRefractive.value;
        final lightIntensity = SettingsManager.liquidGlassSearchLightIntensity.value;
        final thickness      = SettingsManager.liquidGlassSearchThickness.value;

        final glassQuality = switch (quality) {
          LiquidGlassQuality.fast    => GlassQuality.standard,
          LiquidGlassQuality.medium  => GlassQuality.minimal,
          LiquidGlassQuality.quality => GlassQuality.premium,
        };

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final tintColor = isDark
            ? Colors.white.withValues(alpha: tint)
            : Colors.black.withValues(alpha: tint);

        final settings = LiquidGlassSettings(
          thickness: thickness,
          blur: blur,
          chromaticAberration: chromatic,
          lightIntensity: lightIntensity,
          refractiveIndex: refractive,
          saturation: saturation,
          ambientStrength: 0.8,
          lightAngle: 0.75 * math.pi,
          glassColor: tintColor,
        );

        return SizedBox(
          height: 54,
          child: GlassCard(
            useOwnLayer: true,
            settings: settings,
            quality: glassQuality,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: LiquidRoundedRectangle(borderRadius: 28),
            clipBehavior: Clip.antiAlias,
            child: content,
          ),
        );
      },
    );
  }
}
