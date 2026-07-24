// lib/widgets/custom_title_bar.dart
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseHsl = HSLColor.fromColor(colorScheme.primary);

    Color shifted(double hueShift, {double lightnessDelta = 0}) {
      final hue = (baseHsl.hue + hueShift) % 360;
      final lightness = (baseHsl.lightness + lightnessDelta).clamp(0.0, 1.0);
      return baseHsl
          .withHue(hue < 0 ? hue + 360 : hue)
          .withLightness(lightness)
          .toColor();
    }

    final minimizeColor = shifted(-25);
    final maximizeColor = shifted(0);
    final closeColor = shifted(25);

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (details) {
                windowManager.startDragging();
              },
              child: const SizedBox.expand(),
            ),
          ),
          _WindowDot(
            color: minimizeColor,
            icon: Icons.remove,
            onTap: () => windowManager.minimize(),
          ),
          const SizedBox(width: 8),
          _WindowDot(
            color: maximizeColor,
            icon: Icons.crop_square,
            onTap: () async {
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
          ),
          const SizedBox(width: 8),
          _WindowDot(
            color: closeColor,
            icon: Icons.close,
            onTap: () async {
              await windowManager.hide();
            },
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}

class _WindowDot extends StatefulWidget {
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _WindowDot({
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_WindowDot> createState() => _WindowDotState();
}

class _WindowDotState extends State<_WindowDot> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(widget.color);
    final iconColor = hsl.withLightness(
      (hsl.lightness - 0.3).clamp(0.0, 1.0),
    ).toColor();

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.6),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: _hovering
              ? Icon(widget.icon, size: 9, color: iconColor)
              : null,
        ),
      ),
    );
  }
}
