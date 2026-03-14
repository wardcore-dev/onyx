// lib/widgets/debug_overlay.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';

class DebugOverlay extends StatefulWidget {
  final Widget child;
  final bool initialShow;

  const DebugOverlay({
    Key? key,
    required this.child,
    this.initialShow = false,
  }) : super(key: key);

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> with WidgetsBindingObserver {
  bool _showOverlay = false;
  late Timer _updateTimer;
  int _frameCount = 0;
  int _fps = 0;
  late DateTime _lastUpdate;
  final List<int> _fpsHistory = [];
  
  int _totalMemory = 0;
  int _usedMemory = 0;

  @override
  void initState() {
    super.initState();
    _showOverlay = widget.initialShow;
    _lastUpdate = DateTime.now();
    
    _updateTimer = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _fps = _frameCount;
          _fpsHistory.add(_fps);
          if (_fpsHistory.length > 60) {
            _fpsHistory.removeAt(0);
          }
          _frameCount = 0;
          _updateMemoryStats();
        });
      }
    });

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(_onFrame);
  }

  void _onFrame(Duration duration) {
    _frameCount++;
    WidgetsBinding.instance.addPostFrameCallback(_onFrame);
  }

  void _updateMemoryStats() {
    
    try {
      final info = developer.Service.getInfo();
      _totalMemory = 0; 
      _usedMemory = 0;
    } catch (e) {
      debugPrint('[err] $e');
    }
  }

  @override
  void dispose() {
    _updateTimer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _toggleOverlay() {
    setState(() => _showOverlay = !_showOverlay);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showOverlay) _buildDebugPanel(),
        _buildDebugToggleButton(),
      ],
    );
  }

  Widget _buildDebugToggleButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      right: 8,
      child: GestureDetector(
        onTap: _toggleOverlay,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black87,
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              'FPS',
              style: TextStyle(
                color: _fps < 30 ? Colors.red : (_fps < 55 ? Colors.yellow : Colors.green),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDebugPanel() {
    final avgFps = _fpsHistory.isEmpty ? 0 : (_fpsHistory.reduce((a, b) => a + b) ~/ _fpsHistory.length);
    final maxFps = _fpsHistory.isEmpty ? 0 : _fpsHistory.reduce((a, b) => a > b ? a : b);
    final minFps = _fpsHistory.isEmpty ? 0 : _fpsHistory.reduce((a, b) => a < b ? a : b);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 8,
      right: 60,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 12,
              spreadRadius: 4,
            ),
          ],
        ),
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            _buildMetricRow(
              label: 'FPS',
              value: '$_fps',
              valueColor: _fpsToColor(_fps),
            ),
            _buildMetricRow(
              label: 'Avg FPS',
              value: '$avgFps',
              valueColor: _fpsToColor(avgFps),
            ),
            _buildMetricRow(
              label: 'Min / Max',
              value: '$minFps / $maxFps',
              valueColor: Colors.cyan,
            ),
            SizedBox(height: 8),
            
            _buildFpsGraph(),
            SizedBox(height: 8),

            _buildMetricRow(
              label: 'Time',
              value: '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}',
              valueColor: Colors.white70,
            ),

            _buildMetricRow(
              label: 'Build',
              value: 'Release',
              valueColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildFpsGraph() {
    if (_fpsHistory.isEmpty) {
      return SizedBox(
        height: 30,
        child: Center(
          child: Text('Loading...', style: TextStyle(color: Colors.white54, fontSize: 10)),
        ),
      );
    }

    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: CustomPaint(
        painter: _FpsGraphPainter(_fpsHistory),
        size: Size.infinite,
      ),
    );
  }

  Color _fpsToColor(int fps) {
    if (fps < 30) return Colors.red;
    if (fps < 45) return Colors.orange;
    if (fps < 55) return Colors.yellow;
    return Colors.green;
  }
}

class _FpsGraphPainter extends CustomPainter {
  final List<int> fpsHistory;

  _FpsGraphPainter(this.fpsHistory);

  @override
  void paint(Canvas canvas, Size size) {
    if (fpsHistory.isEmpty) return;

    final paint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final maxFps = 60.0;
    final stepX = size.width / (fpsHistory.length - 1).toDouble();
    final points = <Offset>[];

    for (int i = 0; i < fpsHistory.length; i++) {
      final x = i * stepX;
      final fps = fpsHistory[i];
      final y = size.height - (fps / maxFps) * size.height;
      points.add(Offset(x, y));
    }

    for (int i = 0; i < points.length - 1; i++) {
      paint.color = _fpsToColor(fpsHistory[i]).withOpacity(0.7);
      canvas.drawLine(points[i], points[i + 1], paint);
    }

    final paint30 = Paint()
      ..strokeWidth = 0.5
      ..color = Colors.red.withOpacity(0.3);
    final paint60 = Paint()
      ..strokeWidth = 0.5
      ..color = Colors.green.withOpacity(0.3);

    final y30 = size.height - (30 / 60) * size.height;
    final y60 = size.height - (60 / 60) * size.height;

    canvas.drawLine(Offset(0, y30), Offset(size.width, y30), paint30);
    canvas.drawLine(Offset(0, y60), Offset(size.width, y60), paint60);
  }

  Color _fpsToColor(int fps) {
    if (fps < 30) return Colors.red;
    if (fps < 45) return Colors.orange;
    if (fps < 55) return Colors.yellow;
    return Colors.green;
  }

  @override
  bool shouldRepaint(_FpsGraphPainter oldDelegate) => true;
}