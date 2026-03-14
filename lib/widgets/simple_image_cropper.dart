// lib/widgets/simple_image_cropper.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:image/image.dart' as img;
import '../managers/settings_manager.dart';

Future<Uint8List?> showImageCropperDialog(BuildContext context, Uint8List bytes) async {
  final srcImg = img.decodeImage(bytes);
  if (srcImg == null) return null;

  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final uiImage = frame.image;

  if (!context.mounted) return null;

  return await showDialog<Uint8List?>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _SimpleCropperDialog(
      uiImage: uiImage,
      sourceImage: srcImg,
    ),
  );
}

class _SimpleCropperDialog extends StatefulWidget {
  final ui.Image uiImage;
  final img.Image sourceImage;

  const _SimpleCropperDialog({
    required this.uiImage,
    required this.sourceImage,
  });

  @override
  State<_SimpleCropperDialog> createState() => _SimpleCropperDialogState();
}

class _SimpleCropperDialogState extends State<_SimpleCropperDialog> {
  
  double _scale = 1.0;
  Offset _offset = Offset.zero;

  double _baseScale = 1.0;
  Offset _baseOffset = Offset.zero;
  Offset _baseFocalPoint = Offset.zero;

  double _viewportSize = 360.0;
  double _cropRadius = 160.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mq = MediaQuery.of(context);
    _viewportSize = math.min(mq.size.width - 80, 360.0);
    _cropRadius = (_viewportSize - 40) / 2;

    if (_scale == 1.0 && _offset == Offset.zero) {
      _setupInitialView();
    }
  }

  void _setupInitialView() {
    final imgW = widget.uiImage.width.toDouble();
    final imgH = widget.uiImage.height.toDouble();
    final cropDiameter = _cropRadius * 2;

    _scale = math.max(cropDiameter / imgW, cropDiameter / imgH);

    final scaledW = imgW * _scale;
    final scaledH = imgH * _scale;
    _offset = Offset(
      (_viewportSize - scaledW) / 2,
      (_viewportSize - scaledH) / 2,
    );

    setState(() {});
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = _scale;
    _baseOffset = _offset;
    _baseFocalPoint = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      
      _scale = (_baseScale * details.scale).clamp(0.5, 5.0);

      final imagePoint = (_baseFocalPoint - _baseOffset) / _baseScale;

      final newFocalPoint = details.localFocalPoint;
      _offset = newFocalPoint - imagePoint * _scale;
    });
  }

  Future<void> _cropAndSave() async {
    try {
      
      final centerX = _viewportSize / 2;
      final centerY = _viewportSize / 2;

      final imgCenterX = (centerX - _offset.dx) / _scale;
      final imgCenterY = (centerY - _offset.dy) / _scale;

      final imgRadius = _cropRadius / _scale;

      final side = (imgRadius * 2).toInt();
      var x = (imgCenterX - imgRadius).round();
      var y = (imgCenterY - imgRadius).round();

      x = x.clamp(0, widget.sourceImage.width - side);
      y = y.clamp(0, widget.sourceImage.height - side);

      var actualSide = side;
      if (x + actualSide > widget.sourceImage.width) {
        actualSide = widget.sourceImage.width - x;
      }
      if (y + actualSide > widget.sourceImage.height) {
        actualSide = widget.sourceImage.height - y;
      }
      actualSide = actualSide.clamp(1, math.min(widget.sourceImage.width, widget.sourceImage.height));

      final cropped = img.copyCrop(
        widget.sourceImage,
        x: x,
        y: y,
        width: actualSide,
        height: actualSide,
      );

      final resized = img.copyResize(
        cropped,
        width: 512,
        height: 512,
        interpolation: img.Interpolation.linear,
      );

      final encoded = img.encodeJpg(resized, quality: 85);

      if (mounted) {
        Navigator.of(context).pop(Uint8List.fromList(encoded));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(null);
      }
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
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: _viewportSize,
              decoration: BoxDecoration(
                color: surfaceColor.withValues(alpha: 1.0),
                borderRadius: BorderRadius.circular(12),
              ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              
              ClipRect(
                child: SizedBox(
                  width: _viewportSize,
                  height: _viewportSize,
                  child: Listener(
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent) {
                        
                        final scrollDelta = event.scrollDelta.dy;
                        if (scrollDelta == 0) return;

                        setState(() {
                          final oldScale = _scale;
                          
                          final zoomFactor = scrollDelta > 0 ? 0.85 : 1.15;
                          _scale = (_scale * zoomFactor).clamp(0.5, 5.0);

                          final mousePos = event.localPosition;
                          final imagePoint = (mousePos - _offset) / oldScale;
                          _offset = mousePos - imagePoint * _scale;
                        });
                      }
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: _onScaleUpdate,
                      onDoubleTap: () {
                        
                        setState(() {
                          _setupInitialView();
                        });
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                        
                        Positioned(
                          left: _offset.dx,
                          top: _offset.dy,
                          child: SizedBox(
                            width: widget.uiImage.width * _scale,
                            height: widget.uiImage.height * _scale,
                            child: CustomPaint(
                              painter: _ImagePainter(widget.uiImage),
                            ),
                          ),
                        ),
                        
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _CircleOverlayPainter(
                                radius: _cropRadius,
                                overlayColor: surfaceColor.withValues(alpha: 0.7),
                                borderColor: colorScheme.primary,
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
              const SizedBox(height: 12),
              
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _cropAndSave,
                    child: const Text('Crop & Upload'),
                  ),
                ],
              ),
            ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    widget.uiImage.dispose();
    super.dispose();
  }
}

class _ImagePainter extends CustomPainter {
  final ui.Image image;

  _ImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.high;
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, srcRect, dstRect, paint);
  }

  @override
  bool shouldRepaint(_ImagePainter oldDelegate) => false;
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
        ..strokeWidth = 2.5
        ..color = borderColor,
    );
  }

  @override
  bool shouldRepaint(_CircleOverlayPainter old) =>
      old.radius != radius ||
      old.overlayColor != overlayColor ||
      old.borderColor != borderColor;
}