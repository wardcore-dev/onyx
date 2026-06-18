// lib/widgets/apple_segmented_tabs.dart
//
// Shared Apple-style segmented control (sliding pill indicator behind the
// selected segment) driven by a TabController. Originally built for the
// "Manage Cache" dialog; extracted so other full-screen dialogs (e.g. the
// media gallery) can reuse the exact same look and feel.

import 'package:flutter/material.dart';

class AppleSegment {
  final IconData icon;
  final String label;
  const AppleSegment({required this.icon, required this.label});
}

class AppleSegmentedTabs extends StatefulWidget {
  final TabController controller;
  final List<AppleSegment> segments;
  const AppleSegmentedTabs({super.key, required this.controller, required this.segments});

  @override
  State<AppleSegmentedTabs> createState() => _AppleSegmentedTabsState();
}

class _AppleSegmentedTabsState extends State<AppleSegmentedTabs> {
  @override
  void initState() {
    super.initState();
    widget.controller.animation?.addListener(_onAnimate);
  }

  @override
  void dispose() {
    widget.controller.animation?.removeListener(_onAnimate);
    super.dispose();
  }

  void _onAnimate() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = widget.segments.length;
    final position = widget.controller.animation?.value ?? widget.controller.index.toDouble();

    const trackHeight = 38.0;
    const trackPadding = 3.0;
    const pillRadius = (trackHeight - trackPadding * 2) / 2;

    return Container(
      height: trackHeight,
      padding: const EdgeInsets.all(trackPadding),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(trackHeight / 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / count;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                left: segmentWidth * position,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(pillRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: List.generate(count, (i) {
                  final selected = (widget.controller.index == i);
                  final segment = widget.segments[i];
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.controller.animateTo(i),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              segment.icon,
                              size: 15,
                              color: selected
                                  ? cs.primary
                                  : cs.onSurface.withValues(alpha: 0.55),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              segment.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                color: selected
                                    ? cs.onSurface
                                    : cs.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
