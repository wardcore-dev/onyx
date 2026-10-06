// lib/widgets/pending_device_bubble.dart
//
// Floating, draggable reminder — same visual language as WardLinkSyncBubble —
// that stays on screen for as long as PendingDeviceApprovals.list is
// non-empty, independent of whether the approval dialog was dismissed.
// Tapping it reopens the dialog. Mount once at the global Stack level
// (main.dart's MaterialApp.builder), alongside the other floating bubbles.
import 'package:flutter/material.dart';
import '../globals.dart' show navigatorKey;
import '../services/pending_device_approvals.dart';
import 'pending_device_dialog.dart';

class PendingDeviceBubble extends StatefulWidget {
  const PendingDeviceBubble({super.key});

  @override
  State<PendingDeviceBubble> createState() => _PendingDeviceBubbleState();
}

class _PendingDeviceBubbleState extends State<PendingDeviceBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _appear;
  late final Animation<double> _appearCurve;
  Offset? _pos;

  @override
  void initState() {
    super.initState();
    _appear = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _appearCurve = CurvedAnimation(
      parent: _appear,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
    PendingDeviceApprovals.list.addListener(_onListChanged);
    _syncVisibility();
  }

  void _onListChanged() {
    if (!mounted) return;
    setState(() {});
    _syncVisibility();
  }

  void _syncVisibility() {
    if (PendingDeviceApprovals.list.value.isNotEmpty) {
      _appear.forward();
    } else {
      _appear.reverse();
    }
  }

  @override
  void dispose() {
    PendingDeviceApprovals.list.removeListener(_onListChanged);
    _appear.dispose();
    super.dispose();
  }

  void _openDialog() {
    final navCtx = navigatorKey.currentState?.overlay?.context;
    if (navCtx == null) return;
    showPendingDeviceApprovalsDialog(navCtx);
  }

  @override
  Widget build(BuildContext context) {
    final count = PendingDeviceApprovals.list.value.length;
    if (count == 0 && _appear.isDismissed) return const SizedBox.shrink();

    const sz = 52.0;
    final mq = MediaQuery.of(context);
    _pos ??= Offset(16, mq.size.height * 0.35);

    final cs = Theme.of(context).colorScheme;
    final scale = _appearCurve.value.clamp(0.0, 1.0);

    return Positioned(
      left: _pos!.dx,
      top: _pos!.dy,
      child: Opacity(
        opacity: _appear.value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) {
              setState(() {
                _pos = Offset(
                  (_pos!.dx + d.delta.dx).clamp(0.0, mq.size.width - sz),
                  (_pos!.dy + d.delta.dy).clamp(mq.viewPadding.top, mq.size.height - 90),
                );
              });
            },
            onTap: _openDialog,
            child: SizedBox(
              width: sz,
              height: sz,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: sz,
                    height: sz,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primary,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.35),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.shield_outlined, size: sz * 0.46, color: cs.onPrimary),
                  if (count > 0)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: cs.error,
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.surface, width: 1.5),
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        // Floating above the Navigator, outside any Material:
                        // a bare Text gets the debug style (yellow double
                        // underline). A transparent Material fixes that.
                        child: Material(
                          type: MaterialType.transparency,
                          child: Text(
                            '$count',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.onError),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
