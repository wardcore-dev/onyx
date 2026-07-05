// lib/screens/mesh_graph_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import '../globals.dart';
import '../l10n/app_localizations.dart';
import '../managers/account_manager.dart';
import '../managers/settings_manager.dart';
import '../services/mesh/mesh_crypto.dart';
import '../services/mesh/mesh_manager.dart';
import '../services/mesh/mesh_neighbor_table.dart';
import '../services/mesh/mesh_peripheral.dart';
import 'mesh_chat_screen.dart';

Future<void> showMeshRadarSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _MeshRadarSheet(),
  );
}

// -----------------------------------------------------------------------------

class _MeshRadarSheet extends StatefulWidget {
  const _MeshRadarSheet();

  @override
  State<_MeshRadarSheet> createState() => _MeshRadarSheetState();
}

class _MeshRadarSheetState extends State<_MeshRadarSheet>
    with SingleTickerProviderStateMixin {
  bool _radarView = true;
  final _searchCtrl = TextEditingController();
  String _search = '';
  late AnimationController _sweepCtrl;

  @override
  void initState() {
    super.initState();
    _sweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _searchCtrl.addListener(() {
      setState(() => _search = _searchCtrl.text.toLowerCase().trim());
    });

    _ensureMeshRunning();
  }

  Future<void> _ensureMeshRunning() async {
    if (!SettingsManager.meshModeEnabled.value) return;
    if (MeshManager.instance.isRunning) return;
    final username = await AccountManager.getCurrentAccount();
    if (username != null) {
      await MeshManager.instance.start(username);
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _sweepCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MeshNeighbor> _filtered(List<MeshNeighbor> all) {
    if (_search.isEmpty) return all;
    return all.where((n) {
      final name = (n.displayName ?? '').toLowerCase();
      final user = (n.username ?? '').toLowerCase();
      return name.contains(_search) || user.contains(_search);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      snap: true,
      builder: (ctx, _) => Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.radar_rounded,
                      size: 18, color: cs.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 10),
                  Text(
                    l.meshRadarTitle,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  _ViewToggle(
                    radarView: _radarView,
                    onToggle: (v) => setState(() => _radarView = v),
                    cs: cs,
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),

            // Location services required banner (Android ≤11)
            ValueListenableBuilder<bool>(
              valueListenable: MeshManager.instance.locationServicesRequired,
              builder: (_, needed, __) {
                if (!needed) return const SizedBox.shrink();
                return Material(
                  color: Colors.orange.withValues(alpha: 0.15),
                  child: InkWell(
                    onTap: () => MeshPeripheral.openLocationSettings(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.location_off_rounded,
                              size: 16, color: Colors.orange),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l.meshLocationRequired,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.orange),
                            ),
                          ),
                          const Icon(Icons.open_in_new_rounded,
                              size: 14, color: Colors.orange),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Content
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: SettingsManager.meshModeEnabled,
                builder: (_, meshOn, __) {
                  if (!meshOn) {
                    return _EmptyState(
                      icon: Icons.bluetooth_disabled_rounded,
                      message: l.meshRadarDisabled,
                      cs: cs,
                    );
                  }

                  return ListenableBuilder(
                    listenable: MeshManager.instance.neighbors,
                    builder: (_, __) {
                      final neighbors = MeshManager.instance.neighbors.neighbors;

                      if (_radarView) {
                        return _RadarView(
                          neighbors: neighbors,
                          sweepAnim: _sweepCtrl,
                          cs: cs,
                          isDark: isDark,
                          scanningLabel: l.meshRadarScanning,
                          foundLabel: (n) => l.meshRadarFound(n),
                          myUsername: MeshManager.instance.myUsername,
                        );
                      }

                      return _NeighborListView(
                        neighbors: _filtered(neighbors),
                        search: _search,
                        searchCtrl: _searchCtrl,
                        cs: cs,
                        searchHint: l.meshRadarSearchHint,
                        emptyMessage: _search.isNotEmpty
                            ? l.meshRadarSearchEmpty(_search)
                            : l.meshRadarNoDevices,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class _ViewToggle extends StatefulWidget {
  final bool radarView;
  final ValueChanged<bool> onToggle;
  final ColorScheme cs;

  const _ViewToggle(
      {required this.radarView, required this.onToggle, required this.cs});

  @override
  State<_ViewToggle> createState() => _ViewToggleState();
}

class _ViewToggleState extends State<_ViewToggle>
    with SingleTickerProviderStateMixin {
  static const double _w = 88;
  static const double _h = 36;
  static const double _pad = 3;
  static const double _thumbW = (_w - _pad * 2) / 2;

  late final AnimationController _ac;
  late final Animation<double> _pos;

  double? _dragOriginX;
  double? _dragOriginVal;

  double get _leftX => _pad;
  double get _rightX => _w - _pad - _thumbW;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: widget.radarView ? 0.0 : 1.0,
    );
    _pos = CurvedAnimation(parent: _ac, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(_ViewToggle old) {
    super.didUpdateWidget(old);
    if (old.radarView != widget.radarView) {
      widget.radarView ? _ac.reverse() : _ac.forward();
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails d) {
    _dragOriginX = d.localPosition.dx;
    _dragOriginVal = _ac.value;
    _ac.stop();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_dragOriginX == null) return;
    final dx = d.localPosition.dx - _dragOriginX!;
    _ac.value = (_dragOriginVal! + dx / (_rightX - _leftX)).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d) {
    final vel = d.velocity.pixelsPerSecond.dx;
    final isRadar = vel.abs() > 300 ? vel < 0 : _ac.value < 0.5;
    widget.onToggle(isRadar);
    _dragOriginX = null;
    _dragOriginVal = null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onTapUp: (d) {
        final goList = d.localPosition.dx >= _w / 2;
        if (goList == widget.radarView) widget.onToggle(!goList);
      },
      child: Container(
        width: _w,
        height: _h,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(_h / 2),
        ),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _pos,
              builder: (_, __) => Positioned(
                left: _leftX + (_rightX - _leftX) * _pos.value,
                top: _pad,
                width: _thumbW,
                height: _h - _pad * 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular((_h - _pad * 2) / 2),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Icon(Icons.radar_rounded,
                        size: 19,
                        color: widget.radarView
                            ? cs.primary
                            : cs.onSurfaceVariant),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Icon(Icons.list_rounded,
                        size: 19,
                        color: !widget.radarView
                            ? cs.primary
                            : cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class _RadarView extends StatelessWidget {
  final List<MeshNeighbor> neighbors;
  final Animation<double> sweepAnim;
  final ColorScheme cs;
  final bool isDark;
  final String scanningLabel;
  final String Function(int) foundLabel;
  final String? myUsername;

  const _RadarView({
    required this.neighbors,
    required this.sweepAnim,
    required this.cs,
    required this.isDark,
    required this.scanningLabel,
    required this.foundLabel,
    this.myUsername,
  });

  void _onTap(BuildContext context, TapUpDetails details, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final tap = details.localPosition;
    for (final n in neighbors) {
      if (n.username == null || myUsername == null) continue;
      final a = _stableAngle(n.deviceId);
      final dist = n.radarDistance;
      final dot = Offset(
        center.dx + r * dist * cos(a),
        center.dy + r * dist * sin(a),
      );
      if ((tap - dot).distance <= 22) {
        if (isDesktop) {
          Navigator.of(context, rootNavigator: true).pop();
          rootScreenKey.currentState?.openMeshChat(myUsername!, n.username!);
        } else {
          final nav = Navigator.of(context, rootNavigator: true);
          nav.pop();
          nav.push(MaterialPageRoute(
            builder: (_) => MeshChatScreen(
              myUsername: myUsername!,
              otherUsername: n.username!,
            ),
          ));
        }
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final size = Size(constraints.maxWidth, constraints.maxHeight);
                    return GestureDetector(
                      onTapUp: (d) => _onTap(ctx, d, size),
                      child: AnimatedBuilder(
                        animation: sweepAnim,
                        builder: (_, __) => CustomPaint(
                          painter: _RadarPainter(
                            neighbors: neighbors,
                            sweepAngle: sweepAnim.value * 2 * pi,
                            accentColor: cs.primary,
                            isDark: isDark,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(
            neighbors.isEmpty ? scanningLabel : foundLabel(neighbors.length),
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ),
      ],
    );
  }
}

double _stableAngle(String deviceId) {
  var h = 0;
  for (final c in deviceId.codeUnits) {
    h = ((h << 5) ^ h ^ c) & 0x7FFFFFFF;
  }
  return (h % 3600) / 3600 * 2 * pi;
}

class _RadarPainter extends CustomPainter {
  final List<MeshNeighbor> neighbors;
  final double sweepAngle;
  final Color accentColor;
  final bool isDark;

  const _RadarPainter({
    required this.neighbors,
    required this.sweepAngle,
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // Background fill
    canvas.drawCircle(
      center,
      maxR,
      Paint()..color = accentColor.withValues(alpha: isDark ? 0.05 : 0.04),
    );

    // Range rings
    final ringPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxR * i / 3, ringPaint);
    }

    // Cross hairs
    final crossPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.08)
      ..strokeWidth = 0.6;
    canvas.drawLine(Offset(center.dx, center.dy - maxR),
        Offset(center.dx, center.dy + maxR), crossPaint);
    canvas.drawLine(Offset(center.dx - maxR, center.dy),
        Offset(center.dx + maxR, center.dy), crossPaint);

    // Phosphor trail: rotate canvas so the sweep line sits at angle 0,
    // then draw a fixed gradient ending at 2π. This avoids the clamp-mode
    // wrap-around flash that happens when startAngle crosses 0/2π.
    const trailAngle = 2.2; // ~126° of fading trail
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(sweepAngle);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawCircle(
      center,
      maxR,
      Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: 2 * pi - trailAngle,
          endAngle: 2 * pi,
          colors: [
            Colors.transparent,
            accentColor.withValues(alpha: 0.05),
            accentColor.withValues(alpha: 0.26),
          ],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: maxR)),
    );
    canvas.restore();

    // Sweep line: soft glow halo + bright core
    final lineEnd = Offset(
      center.dx + maxR * cos(sweepAngle),
      center.dy + maxR * sin(sweepAngle),
    );
    canvas.drawLine(
      center,
      lineEnd,
      Paint()
        ..color = accentColor.withValues(alpha: 0.18)
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      center,
      lineEnd,
      Paint()
        ..color = accentColor.withValues(alpha: 0.75)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );

    canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: maxR)));

    // Neighbor dots
    for (final n in neighbors) {
      final angle = _stableAngle(n.deviceId);
      final dist = n.radarDistance;
      final pos = Offset(
        center.dx + maxR * dist * cos(angle),
        center.dy + maxR * dist * sin(angle),
      );
      final color = Color(MeshCrypto.colorFromPub(n.publicKey));

      canvas.drawCircle(pos, 16, Paint()..color = color.withValues(alpha: 0.2));
      canvas.drawCircle(pos, 12, Paint()..color = color);

      // LAN-нода: тонкое белое кольцо (отличие от BLE)
      if (n.isLan) {
        canvas.drawCircle(
          pos,
          14,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }

      final tp = TextPainter(
        text: TextSpan(
          text: n.avatarLetter,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
    }

    // Center dot
    canvas.drawCircle(center, 5, Paint()..color = accentColor);
    canvas.drawCircle(
        center,
        8,
        Paint()
          ..color = accentColor.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.sweepAngle != sweepAngle || old.neighbors != neighbors;
}

// -----------------------------------------------------------------------------

class _NeighborListView extends StatelessWidget {
  final List<MeshNeighbor> neighbors;
  final String search;
  final TextEditingController searchCtrl;
  final ColorScheme cs;
  final String searchHint;
  final String emptyMessage;

  const _NeighborListView({
    required this.neighbors,
    required this.search,
    required this.searchCtrl,
    required this.cs,
    required this.searchHint,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: searchCtrl,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: searchHint,
              hintStyle:
                  TextStyle(color: cs.onSurface.withValues(alpha: 0.35)),
              prefixIcon: Icon(Icons.search_rounded,
                  color: cs.onSurface.withValues(alpha: 0.35), size: 20),
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(50),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (neighbors.isEmpty)
          Expanded(
            child: _EmptyState(
              icon: Icons.bluetooth_searching_rounded,
              message: emptyMessage,
              cs: cs,
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: neighbors.length,
              itemBuilder: (ctx, i) => _NeighborTile(
                neighbor: neighbors[i],
                cs: cs,
                myUsername: MeshManager.instance.myUsername,
              ),
            ),
          ),
      ],
    );
  }
}

class _NeighborTile extends StatelessWidget {
  final MeshNeighbor neighbor;
  final ColorScheme cs;
  final String? myUsername;

  const _NeighborTile({required this.neighbor, required this.cs, this.myUsername});

  @override
  Widget build(BuildContext context) {
    final color = Color(MeshCrypto.colorFromPub(neighbor.publicKey));
    final rssiPct = ((neighbor.rssi + 90) / 50).clamp(0.0, 1.0);
    final rssiColor = Color.lerp(Colors.red.shade400, cs.primary, rssiPct)!;

    final canOpen = neighbor.username != null && myUsername != null;

    return GestureDetector(
      onTap: canOpen
          ? () {
              if (isDesktop) {
                Navigator.of(context, rootNavigator: true).pop();
                rootScreenKey.currentState?.openMeshChat(myUsername!, neighbor.username!);
              } else {
                final nav = Navigator.of(context, rootNavigator: true);
                nav.pop();
                nav.push(MaterialPageRoute(
                  builder: (_) => MeshChatScreen(
                    myUsername: myUsername!,
                    otherUsername: neighbor.username!,
                  ),
                ));
              }
            }
          : null,
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: canOpen ? 0.5 : 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(
              child: Text(
                neighbor.avatarLetter,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (neighbor.displayName != null)
                  Text(neighbor.displayName!,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                Text(
                  neighbor.username != null
                      ? '@${neighbor.username}'
                      : '#${neighbor.keyHashHex.substring(0, 8)}',
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
          // LAN-сосед: WiFi иконка; BLE-сосед: уровень сигнала
          if (neighbor.isLan)
            Icon(Icons.wifi_rounded, color: cs.primary, size: 18)
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(Icons.bluetooth_rounded, color: rssiColor, size: 15),
                Text('${neighbor.rssi} dBm',
                    style: TextStyle(fontSize: 11, color: rssiColor)),
              ],
            ),
        ],
      ),
    ),
    );
  }
}

// -----------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final ColorScheme cs;

  const _EmptyState(
      {required this.icon, required this.message, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: cs.onSurface.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withValues(alpha: 0.4),
                  height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
