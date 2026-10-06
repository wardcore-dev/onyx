import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../enums/liquid_glass_quality.dart';
import '../managers/settings_manager.dart';

// Liquid glass on Android, iOS and macOS; on Windows/Linux — standard render
// (matches the input bar's platform gate in chat_screen.dart/mesh_chat_screen.dart).
bool get _glassAllowed => !Platform.isWindows && !Platform.isLinux;

/// Shared glass-rendering body for chat app-bar surfaces — used by both
/// [AdaptiveGlassIconButton] (fixed-size round buttons) and [AdaptiveGlassPill]
/// (flexible-width title pill), driven by the `SettingsManager.liquidGlassAppBar*`
/// settings group.
Widget _buildAppBarGlass(
  BuildContext context, {
  required Widget child,
  required double borderRadius,
  required EdgeInsetsGeometry padding,
  double? width,
  double? height,
}) {
  return ListenableBuilder(
    listenable: Listenable.merge([
      SettingsManager.liquidGlassAppBarQuality,
      SettingsManager.liquidGlassAppBarBlur,
      SettingsManager.liquidGlassAppBarTint,
      SettingsManager.liquidGlassAppBarSaturation,
      SettingsManager.liquidGlassAppBarChromatic,
      SettingsManager.liquidGlassAppBarRefractive,
      SettingsManager.liquidGlassAppBarLightIntensity,
      SettingsManager.liquidGlassAppBarThickness,
    ]),
    builder: (context, _) {
      final quality        = SettingsManager.liquidGlassAppBarQuality.value;
      final blur           = SettingsManager.liquidGlassAppBarBlur.value;
      final tint           = SettingsManager.liquidGlassAppBarTint.value;
      final saturation     = SettingsManager.liquidGlassAppBarSaturation.value;
      final chromatic      = SettingsManager.liquidGlassAppBarChromatic.value;
      final refractive     = SettingsManager.liquidGlassAppBarRefractive.value;
      final lightIntensity = SettingsManager.liquidGlassAppBarLightIntensity.value;
      final thickness      = SettingsManager.liquidGlassAppBarThickness.value;

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

      final card = GlassCard(
        useOwnLayer: true,
        settings: settings,
        quality: glassQuality,
        padding: padding,
        shape: LiquidRoundedRectangle(borderRadius: borderRadius),
        clipBehavior: Clip.antiAlias,
        child: child,
      );

      if (width == null && height == null) return card;
      return SizedBox(width: width, height: height, child: card);
    },
  );
}

/// Same rounded "pill" shape/size used everywhere for chat app-bar buttons
/// (back, search, more-menu, selection actions) — renders the existing
/// frosted-container look by default, or a real Liquid Glass card when
/// [SettingsManager.liquidGlassOnAppBar] is on, mirroring how
/// [SettingsManager.liquidGlassOnInput]/`OnSearch` already work for
/// their respective elements.
class AdaptiveGlassIconButton extends StatelessWidget {
  const AdaptiveGlassIconButton({
    super.key,
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
    this.size = 50,
    this.borderRadius = 25,
  });

  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if (!_glassAllowed) return _buildStandard();
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsManager.liquidGlassOnAppBar,
      builder: (_, onAppBar, __) {
        if (!onAppBar) return _buildStandard();
        return _buildAppBarGlass(
          context,
          child: child,
          borderRadius: borderRadius,
          padding: EdgeInsets.zero,
          width: size,
          height: size,
        );
      },
    );
  }

  Widget _buildStandard() {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: backgroundColor,
            border: Border.all(color: borderColor, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The flexible-width chat-title "pill" (avatar + name + status, or the
/// "N selected" pill in selection mode) — same glass toggle/settings as
/// [AdaptiveGlassIconButton], but sized to its child's intrinsic width
/// (like the plain [Container] it replaces) instead of a fixed square.
class AdaptiveGlassPill extends StatelessWidget {
  const AdaptiveGlassPill({
    super.key,
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
    this.height = 50,
    this.borderRadius = 25,
    this.padding = const EdgeInsets.only(left: 6, right: 10),
  });

  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (!_glassAllowed) return _buildStandard();
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsManager.liquidGlassOnAppBar,
      builder: (_, onAppBar, __) {
        if (!onAppBar) return _buildStandard();
        return _buildAppBarGlass(
          context,
          child: child,
          borderRadius: borderRadius,
          padding: padding,
          height: height,
        );
      },
    );
  }

  Widget _buildStandard() {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: child,
    );
  }
}
