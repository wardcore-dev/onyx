import 'package:flutter/material.dart';
import '../managers/settings_manager.dart';

/// Standard rounded card used all over the settings / lists. (It used to have
/// a Liquid Glass variant; that was dropped -- glass is now only for the nav
/// bar, input bar, search and app-bar buttons.)
class AdaptiveGlassCard extends StatelessWidget {
  const AdaptiveGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 8),
    this.onTap,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementOpacity,
      builder: (_, opacity, __) {
        return ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementBrightness,
          builder: (_, brightness, __) {
            final baseColor = SettingsManager.getElementColor(
              cs.surfaceContainerHighest,
              brightness,
            );
            final border = Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.15),
              width: 1,
            );
            if (onTap != null) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: Material(
                  color: baseColor.withValues(alpha: opacity),
                  child: InkWell(
                    onTap: onTap,
                    child: Container(
                      padding: padding,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(borderRadius),
                        border: border,
                      ),
                      child: child,
                    ),
                  ),
                ),
              );
            }
            return ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: border,
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
