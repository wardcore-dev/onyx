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
      if (_globalDebugLogs.length > 500) {
        _globalDebugLogs.removeAt(0);
      }
    }
  };
}

class DebugOverlayV2 extends StatefulWidget {
  final Widget child;

  const DebugOverlayV2({Key? key, required this.child}) : super(key: key);

  @override
  State<DebugOverlayV2> createState() => _DebugOverlayV2State();
}

class _DebugOverlayV2State extends State<DebugOverlayV2> with WidgetsBindingObserver {
  bool _showOverlay = false;
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
  final double _smoothingAlpha = 0.25;

  Offset _position = const Offset(20, 20);
  Size _size = const Size(160, 120);

  final _monitor = PerformanceMonitor();

  List<String> _logs = [];

  bool _showLogWindow = false;
  Offset _logWindowPosition = const Offset(100, 100);
  Size _logWindowSize = const Size(250, 350);

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        setState(() {
          final elapsed = _stopwatch.elapsedMilliseconds / 1000.0;
          final measuredFps = elapsed > 0 ? (_frameCount / elapsed) : 0.0;
          
          _smoothedFps = _smoothedFps * (1 - _smoothingAlpha) + measuredFps * _smoothingAlpha;
          _fps = _smoothedFps.round();

          _fpsHistory.add(_fps);
          if (_fpsHistory.length > 120) _fpsHistory.removeAt(0);

          _minFps = _fpsHistory.isEmpty ? _fps : _fpsHistory.reduce((a, b) => a < b ? a : b);
          _maxFps = _fpsHistory.isEmpty ? _fps : _fpsHistory.reduce((a, b) => a > b ? a : b);
          _avgFps = _fpsHistory.isEmpty
              ? _fps
              : (_fpsHistory.reduce((a, b) => a + b) ~/ _fpsHistory.length);

          if (_perFrameFps.isNotEmpty) {
            final sorted = List<double>.from(_perFrameFps)..sort();
            final oneIdx = (sorted.length * 0.01).ceil() - 1;
            final pOneIdx = (sorted.length * 0.001).ceil() - 1;
            _onePercentLow = sorted[oneIdx.clamp(0, sorted.length - 1)];
            _pointOnePercentLow = sorted[pOneIdx.clamp(0, sorted.length - 1)];
            
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
      }
    });

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(_onFrame);
  }

  void _onFrame(Duration duration) {
    _frameCount++;
    final nowMicros = DateTime.now().microsecondsSinceEpoch;
    if (_lastFrameTimestampMicros != null) {
      final deltaSec = (nowMicros - _lastFrameTimestampMicros!) / 1e6;
      if (deltaSec > 0) {
        final frameFps = 1.0 / deltaSec;
        _perFrameFps.add(frameFps);
        
        if (_perFrameFps.length > 5000) _perFrameFps.removeAt(0);
      }
    }
    _lastFrameTimestampMicros = nowMicros;
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

  void addLog(String log) {
    setState(() {
      _logs.add(log);
      if (_logs.length > 50) {
        _logs.removeAt(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsManager.debugMode,
      builder: (_, isDebugMode, __) {
        return Stack(
          children: [
            widget.child,
            if (isDebugMode && _showOverlay)
              Positioned(
                left: _position.dx,
                top: _position.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _position = Offset(
                        _position.dx + details.delta.dx,
                        _position.dy + details.delta.dy,
                      );
                    });
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: _buildFpsPanel(),
                  ),
                ),
              ),
            if (isDebugMode && _showLogWindow)
              Positioned(
                left: _logWindowPosition.dx,
                top: _logWindowPosition.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _logWindowPosition = Offset(
                        _logWindowPosition.dx + details.delta.dx,
                        _logWindowPosition.dy + details.delta.dy,
                      );
                    });
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: _buildLogWindow(),
                  ),
                ),
              ),
            
            if (isDebugMode)
              Positioned(
                top: 100,
                right: 16,
                child: Column(
                  children: [
                    FloatingActionButton(
                      mini: true,
                      backgroundColor: _fpsColor(_fps),
                      onPressed: () => setState(() => _showOverlay = !_showOverlay),
                      child: const Icon(Icons.speed, size: 16),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      mini: true,
                      backgroundColor: Colors.blue,
                      onPressed: () => setState(() => _showLogWindow = !_showLogWindow),
                      child: const Icon(Icons.list, size: 16),
                    ),
                  ],
                ),
              ),
            
            if (isDebugMode && _showOverlay)
              Positioned(
                left: _position.dx + _size.width - 12,
                top: _position.dy + _size.height - 12,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _size = Size(
                          (_size.width + details.delta.dx).clamp(100, 400),
                          (_size.height + details.delta.dy).clamp(80, 300),
                        );
                      });
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _fpsColor(_fps),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.zoom_out_map, size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ),
            if (isDebugMode && _showLogWindow)
              Positioned(
                left: _logWindowPosition.dx + _logWindowSize.width - 12,
                top: _logWindowPosition.dy + _logWindowSize.height - 12,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _logWindowSize = Size(
                          (_logWindowSize.width + details.delta.dx).clamp(150, 600),
                          (_logWindowSize.height + details.delta.dy).clamp(100, 600),
                        );
                      });
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.zoom_out_map, size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFpsPanel() {
    return Container(
      width: _size.width,
      height: _size.height,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _fpsColor(_fps), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _fpsColor(_fps).withOpacity(0.8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_fps FPS',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showOverlay = false),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
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
                  Text('Min: $_minFps',
                      style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  Text('Max: $_maxFps',
                      style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  Text('Avg: $_avgFps',
                      style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  const SizedBox(height: 4),
                  Text('1% low: ${_onePercentLow.round()}',
                      style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  Text('0.1% low: ${_pointOnePercentLow.round()}',
                      style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  const SizedBox(height: 4),
                  Expanded(
                    child: CustomPaint(
                      painter: FpsGraphPainter(_fpsHistory),
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

  Widget _buildLogWindow() {
    return Container(
      width: _logWindowSize.width,
      height: _logWindowSize.height,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue, width: 2),
      ),
      child: Column(
        children: [
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'debugPrint Logs',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showLogWindow = false),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _logs.isEmpty
                ? const Center(
                    child: Text(
                      'No logs',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[_logs.length - 1 - index];
                      return Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          log,
                          style: const TextStyle(
                            color: Colors.white70,
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

class FpsGraphPainter extends CustomPainter {
  final List<int> fpsHistory;

  FpsGraphPainter(this.fpsHistory);

  @override
  void paint(Canvas canvas, Size size) {
    if (fpsHistory.isEmpty) return;

    final paint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    final width = size.width;
    final height = size.height;

    for (int i = 0; i < fpsHistory.length; i++) {
      final x = (i / fpsHistory.length) * width;
      final y = height - (fpsHistory[i] / 120) * height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    final y60 = height - (60 / 120) * height;
    canvas.drawLine(
      Offset(0, y60),
      Offset(width, y60),
      Paint()
        ..color = Colors.white30
        ..strokeWidth = 0.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(FpsGraphPainter oldDelegate) => true;
}