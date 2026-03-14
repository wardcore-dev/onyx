// lib/widgets/avatar_crop_screen.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../managers/settings_manager.dart';

Future<Uint8List?> showAvatarCropScreen(
    BuildContext context, Uint8List bytes) async {
  final srcImg = img.decodeImage(bytes);
  if (srcImg == null) return null;

  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final uiImage = frame.image;

  if (!context.mounted) return null;

  return Navigator.of(context, rootNavigator: true).push<Uint8List?>(
    PageRouteBuilder<Uint8List?>(
      opaque: false,
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, _, __) => _AvatarCropScreen(
        uiImage: uiImage,
        sourceImage: srcImg,
      ),
      transitionsBuilder: (ctx, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _AvatarCropScreen extends StatefulWidget {
  final ui.Image uiImage;
  final img.Image sourceImage;

  const _AvatarCropScreen({required this.uiImage, required this.sourceImage});

  @override
  State<_AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<_AvatarCropScreen> {
  
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  double _baseScale = 1.0;
  Offset _baseOffset = Offset.zero;
  Offset _baseFocalPoint = Offset.zero;

  int _rotQuarters = 0;

  Size _viewport = Size.zero;

  int get _effW =>
      _rotQuarters % 2 == 0 ? widget.uiImage.width : widget.uiImage.height;
  int get _effH =>
      _rotQuarters % 2 == 0 ? widget.uiImage.height : widget.uiImage.width;

  double get _cropRadius {
    if (_viewport == Size.zero) return 140;
    return math.min(_viewport.width, _viewport.height) * 0.42;
  }

  void _setupInitialView() {
    if (_viewport == Size.zero) return;
    final w = _effW.toDouble();
    final h = _effH.toDouble();
    final diameter = _cropRadius * 2;
    _scale = math.max(diameter / w, diameter / h);
    _offset = Offset(
      (_viewport.width - w * _scale) / 2,
      (_viewport.height - h * _scale) / 2,
    );
  }

  void _rotate() {
    setState(() {
      _rotQuarters = (_rotQuarters + 1) % 4;
      _scale = 1.0;
      _offset = Offset.zero;
      _setupInitialView();
    });
  }

  void _onScaleStart(ScaleStartDetails d) {
    _baseScale = _scale;
    _baseOffset = _offset;
    _baseFocalPoint = d.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      _scale = (_baseScale * d.scale).clamp(0.3, 10.0);
      final imgPt = (_baseFocalPoint - _baseOffset) / _baseScale;
      _offset = d.localFocalPoint - imgPt * _scale;
    });
  }

  Future<void> _confirm() async {
    try {
      final cx = _viewport.width / 2;
      final cy = _viewport.height / 2;

      final imgCx = (cx - _offset.dx) / _scale;
      final imgCy = (cy - _offset.dy) / _scale;
      final imgRadius = _cropRadius / _scale;

      var side = (imgRadius * 2).toInt();
      var x = (imgCx - imgRadius).round();
      var y = (imgCy - imgRadius).round();

      x = x.clamp(0, math.max(0, _effW - side));
      y = y.clamp(0, math.max(0, _effH - side));
      if (x + side > _effW) side = _effW - x;
      if (y + side > _effH) side = _effH - y;
      side = side.clamp(1, math.min(_effW, _effH));

      img.Image rotated = widget.sourceImage;
      for (var i = 0; i < _rotQuarters; i++) {
        rotated = img.copyRotate(rotated, angle: 90);
      }

      final cropped =
          img.copyCrop(rotated, x: x, y: y, width: side, height: side);
      final resized = img.copyResize(cropped,
          width: 512, height: 512, interpolation: img.Interpolation.linear);
      final encoded = img.encodeJpg(resized, quality: 85);

      if (mounted) Navigator.of(context).pop(Uint8List.fromList(encoded));
    } catch (e) {
      if (mounted) Navigator.of(context).pop(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementBrightness,
      builder: (_, brightness, __) {
        final surfaceColor = SettingsManager.getElementColor(
          colorScheme.surface,
          brightness,
        );

        return Scaffold(
          
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Container(
              
              color: surfaceColor.withValues(alpha: 0.93),
              child: Column(
                children: [
                  
                  Expanded(
                    child: LayoutBuilder(builder: (ctx, constraints) {
                      final newVp =
                          Size(constraints.maxWidth, constraints.maxHeight);
                      if (_viewport != newVp) {
                        Future.microtask(() {
                          if (!mounted) return;
                          setState(() {
                            final first = _viewport == Size.zero;
                            _viewport = newVp;
                            if (first) _setupInitialView();
                          });
                        });
                      }
                      return _buildCanvas(surfaceColor, colorScheme);
                    }),
                  ),
                  
                  _buildToolbar(surfaceColor, colorScheme),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCanvas(Color surfaceColor, ColorScheme colorScheme) {
    return Listener(
      onPointerSignal: (e) {
        if (e is PointerScrollEvent && e.scrollDelta.dy != 0) {
          setState(() {
            final oldScale = _scale;
            _scale = (_scale * (e.scrollDelta.dy > 0 ? 0.85 : 1.15))
                .clamp(0.3, 10.0);
            final pt = (e.localPosition - _offset) / oldScale;
            _offset = e.localPosition - pt * _scale;
          });
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onDoubleTap: () => setState(() {
          _scale = 1.0;
          _offset = Offset.zero;
          _setupInitialView();
        }),
        child: Stack(
          fit: StackFit.expand,
          children: [
            
            CustomPaint(
              painter: _RotatedImagePainter(
                image: widget.uiImage,
                offset: _offset,
                scale: _scale,
                rotQuarters: _rotQuarters,
              ),
            ),
            
            IgnorePointer(
              child: CustomPaint(
                painter: _CircleOverlayPainter(
                  radius: _cropRadius,
                  overlayColor: surfaceColor.withValues(alpha: 0.65),
                  borderColor: colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(Color surfaceColor, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          const Spacer(),
          IconButton(
            onPressed: _rotate,
            icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
            tooltip: 'Rotate',
          ),
          const Spacer(),
          FilledButton(
            onPressed: _confirm,
            child: const Text('Setup'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.uiImage.dispose();
    super.dispose();
  }
}

class _RotatedImagePainter extends CustomPainter {
  final ui.Image image;
  final Offset offset;
  final double scale;
  final int rotQuarters;

  _RotatedImagePainter({
    required this.image,
    required this.offset,
    required this.scale,
    required this.rotQuarters,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final effW = rotQuarters % 2 == 0
        ? image.width * scale
        : image.height * scale;
    final effH = rotQuarters % 2 == 0
        ? image.height * scale
        : image.width * scale;

    canvas.save();
    canvas.translate(offset.dx + effW / 2, offset.dy + effH / 2);
    canvas.rotate(rotQuarters * math.pi / 2);
    final w = image.width * scale;
    final h = image.height * scale;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(-w / 2, -h / 2, w, h),
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RotatedImagePainter old) =>
      old.offset != offset ||
      old.scale != scale ||
      old.rotQuarters != rotQuarters;
}

class _CircleOverlayPainter extends CustomPainter {
  final double radius;
  final Color overlayColor;
  final Color borderColor;

  _CircleOverlayPainter({
    required this.radius,
    required this.overlayColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Offset.zero & size;

    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, Paint()..color = overlayColor);
    canvas.drawCircle(center, radius, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = borderColor,
    );
  }

  @override
  bool shouldRepaint(_CircleOverlayPainter old) =>
      old.radius != radius ||
      old.overlayColor != overlayColor ||
      old.borderColor != borderColor;
}