// lib/widgets/debug_overlay_v2.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ONYX/utils/performance_monitor.dart';
import 'package:ONYX/managers/settings_manager.dart';

final List<String> _globalDebugLogs = [];

void setupDebugPrintCapture() {
  final originalPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    originalPrint(message, wrapWidth: wrapWidth);
    if (message != null) {
      _globalDebugLogs.add('[${DateTime.now().toIso8601String()}] $message');
      if (_globalDebugLogs.length > 500) _globalDebugLogs.removeAt(0);
    }
  };
}

class DebugOverlayV2 extends StatefulWidget {
  final Widget child;

  const DebugOverlayV2({Key? key, required this.child}) : super(key: key);

  @override
  State<DebugOverlayV2> createState() => _DebugOverlayV2State();
}

class _DebugOverlayV2State extends State<DebugOverlayV2>
    with WidgetsBindingObserver {
  bool _showOverlay = false;
  bool _showLogWindow = false;

  late Timer _updateTimer;
  int _frameCount = 0;
  int _fps = 0;
  int _minFps = 0;
  int _maxFps = 0;
  int _avgFps = 0;
  final List<int> _fpsHistory = [];
  final List<double> _perFrameFps = [];
  int? _lastFrameTimestampMicros;
  double _onePercentLow = 0.0;
  double _pointOnePercentLow = 0.0;
  final Stopwatch _stopwatch = Stopwatch();
  double _smoothedFps = 60.0;
  static const double _smoothingAlpha = 0.25;

  // Draggable panel positions
  Offset _fpsPos = const Offset(20, 20);
  Size _fpsSize = const Size(160, 120);

  Offset _logPos = const Offset(200, 100);
  Size _logSize = const Size(250, 350);

  Offset? _buttonsPos; // null = lazy-init to top-right on first build

  List<String> _logs = [];

  final _monitor = PerformanceMonitor();

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() {
        final elapsed = _stopwatch.elapsedMilliseconds / 1000.0;
        final measured = elapsed > 0 ? (_frameCount / elapsed) : 0.0;
        _smoothedFps =
            _smoothedFps * (1 - _smoothingAlpha) + measured * _smoothingAlpha;
        _fps = _smoothedFps.round();

        _fpsHistory.add(_fps);
        if (_fpsHistory.length > 120) _fpsHistory.removeAt(0);

        _minFps = _fpsHistory.isEmpty
            ? _fps
            : _fpsHistory.reduce((a, b) => a < b ? a : b);
        _maxFps = _fpsHistory.isEmpty
            ? _fps
            : _fpsHistory.reduce((a, b) => a > b ? a : b);
        _avgFps = _fpsHistory.isEmpty
            ? _fps
            : (_fpsHistory.reduce((a, b) => a + b) ~/ _fpsHistory.length);

        if (_perFrameFps.isNotEmpty) {
          final sorted = List<double>.from(_perFrameFps)..sort();
          final oneIdx = (sorted.length * 0.01).ceil() - 1;
          final pOneIdx = (sorted.length * 0.001).ceil() - 1;
          _onePercentLow = sorted[oneIdx.clamp(0, sorted.length - 1)];
          _pointOnePercentLow =
              sorted[pOneIdx.clamp(0, sorted.length - 1)];
          if (_perFrameFps.length > 5000) {
            _perFrameFps.removeRange(0, _perFrameFps.length - 5000);
          }
        } else {
          _onePercentLow = _fps.toDouble();
          _pointOnePercentLow = _fps.toDouble();
        }

        _frameCount = 0;
        _stopwatch.reset();
        _stopwatch.start();
        _logs = List.from(_globalDebugLogs);
      });
    });

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(_onFrame);
  }

  void _onFrame(Duration _) {
    _frameCount++;
    final now = DateTime.now().microsecondsSinceEpoch;
    if (_lastFrameTimestampMicros != null) {
      final delta = (now - _lastFrameTimestampMicros!) / 1e6;
      if (delta > 0) _perFrameFps.add(1.0 / delta);
    }
    _lastFrameTimestampMicros = now;
    WidgetsBinding.instance.addPostFrameCallback(_onFrame);
  }

  @override
  void dispose() {
    _updateTimer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Color _fpsColor(int fps) {
    if (fps >= 55) return Colors.green;
    if (fps >= 45) return Colors.yellow[700]!;
    if (fps >= 30) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scheme = Theme.of(context).colorScheme;

    _buttonsPos ??= Offset(mq.size.width - 52, 100);

    return ValueListenableBuilder<bool>(
      valueListenable: SettingsManager.debugMode,
      builder: (_, isDebugMode, __) {
        return Stack(
          children: [
            widget.child,
            if (isDebugMode && _showOverlay)
              _Draggable(
                position: _fpsPos,
                onDrag: (d) => setState(() => _fpsPos += d),
                child: _buildFpsPanel(scheme),
              ),
            if (isDebugMode && _showLogWindow)
              _Draggable(
                position: _logPos,
                onDrag: (d) => setState(() => _logPos += d),
                child: _buildLogWindow(scheme),
              ),
            if (isDebugMode)
              Positioned(
                left: _buttonsPos!.dx,
                top: _buttonsPos!.dy,
                child: _buildButtonsPanel(scheme, mq),
              ),
            // FPS panel resize handle
            if (isDebugMode && _showOverlay)
              _ResizeHandle(
                position: Offset(
                  _fpsPos.dx + _fpsSize.width - 10,
                  _fpsPos.dy + _fpsSize.height - 10,
                ),
                color: _fpsColor(_fps),
                onDrag: (d) => setState(() {
                  _fpsSize = Size(
                    (_fpsSize.width + d.dx).clamp(100, 400),
                    (_fpsSize.height + d.dy).clamp(80, 300),
                  );
                }),
              ),
            // Log window resize handle
            if (isDebugMode && _showLogWindow)
              _ResizeHandle(
                position: Offset(
                  _logPos.dx + _logSize.width - 10,
                  _logPos.dy + _logSize.height - 10,
                ),
                color: scheme.primary,
                onDrag: (d) => setState(() {
                  _logSize = Size(
                    (_logSize.width + d.dx).clamp(150, 600),
                    (_logSize.height + d.dy).clamp(100, 600),
                  );
                }),
              ),
          ],
        );
      },
    );
  }

  Widget _buildButtonsPanel(ColorScheme scheme, MediaQueryData mq) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Only the handle is draggable — buttons are independent tap targets.
          GestureDetector(
            onPanUpdate: (d) => setState(() {
              _buttonsPos = Offset(
                (_buttonsPos!.dx + d.delta.dx).clamp(0, mq.size.width - 44),
                (_buttonsPos!.dy + d.delta.dy).clamp(0, mq.size.height - 120),
              );
            }),
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 14,
                  color: scheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _PanelButton(
            icon: Icons.speed_rounded,
            color: _fpsColor(_fps),
            active: _showOverlay,
            tooltip: 'FPS overlay',
            onTap: () => setState(() => _showOverlay = !_showOverlay),
          ),
          const SizedBox(height: 6),
          _PanelButton(
            icon: Icons.list_alt_rounded,
            color: scheme.primary,
            active: _showLogWindow,
            tooltip: 'Logs',
            onTap: () => setState(() => _showLogWindow = !_showLogWindow),
          ),
        ],
      ),
    );
  }

  Widget _buildFpsPanel(ColorScheme scheme) {
    final fpsColor = _fpsColor(_fps);
    return Container(
      width: _fpsSize.width,
      height: _fpsSize.height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fpsColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: fpsColor.withValues(alpha: 0.18),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_fps FPS',
                  style: TextStyle(
                    color: fpsColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showOverlay = false),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statRow('Min', '$_minFps', scheme),
                  _statRow('Max', '$_maxFps', scheme),
                  _statRow('Avg', '$_avgFps', scheme),
                  const SizedBox(height: 3),
                  _statRow('1% low', '${_onePercentLow.round()}', scheme),
                  _statRow(
                      '0.1% low', '${_pointOnePercentLow.round()}', scheme),
                  const SizedBox(height: 3),
                  Expanded(
                    child: CustomPaint(
                      painter:
                          FpsGraphPainter(_fpsHistory, scheme.onSurface),
                      size: Size.infinite,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogWindow(ColorScheme scheme) {
    return Container(
      width: _logSize.width,
      height: _logSize.height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'debugPrint Logs',
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showLogWindow = false),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _logs.isEmpty
                ? Center(
                    child: Text(
                      'No logs yet',
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.38),
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    itemCount: _logs.length,
                    itemBuilder: (_, index) {
                      final log = _logs[_logs.length - 1 - index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          log,
                          style: TextStyle(
                            color:
                                scheme.onSurface.withValues(alpha: 0.75),
                            fontSize: 9,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Draggable extends StatelessWidget {
  const _Draggable({
    required this.position,
    required this.onDrag,
    required this.child,
  });

  final Offset position;
  final void Function(Offset delta) onDrag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanUpdate: (d) => onDrag(d.delta),
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: child,
        ),
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({
    required this.position,
    required this.color,
    required this.onDrag,
  });

  final Offset position;
  final Color color;
  final void Function(Offset delta) onDrag;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeDownRight,
        child: GestureDetector(
          onPanUpdate: (d) => onDrag(d.delta),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.zoom_out_map_rounded,
              size: 12,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.icon,
    required this.color,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: active ? color.withValues(alpha: 0.22) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: color.withValues(alpha: 0.12),
          splashColor: color.withValues(alpha: 0.2),
          highlightColor: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: active
                  ? Border.all(color: color.withValues(alpha: 0.5), width: 1)
                  : null,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

Widget _statRow(String label, String value, ColorScheme scheme) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.5), fontSize: 10)),
      Text(value,
          style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.85),
              fontSize: 10,
              fontWeight: FontWeight.w500)),
    ],
  );
}

class FpsGraphPainter extends CustomPainter {
  final List<int> fpsHistory;
  final Color lineColor;

  FpsGraphPainter(this.fpsHistory, this.lineColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (fpsHistory.isEmpty) return;

    final linePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < fpsHistory.length; i++) {
      final x = (i / fpsHistory.length) * size.width;
      final y = size.height - (fpsHistory[i] / 120) * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, linePaint);

    final y60 = size.height - (60 / 120) * size.height;
    canvas.drawLine(
      Offset(0, y60),
      Offset(size.width, y60),
      Paint()
        ..color = lineColor.withValues(alpha: 0.18)
        ..strokeWidth = 0.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(FpsGraphPainter old) => true;
}
