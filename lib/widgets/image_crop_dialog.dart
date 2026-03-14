// lib/widgets/image_crop_dialog.dart
import 'dart:typed_data';
import 'dart:math' show min, max;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../managers/settings_manager.dart';

Future<Uint8List?> showImageCropDialog(BuildContext context, Uint8List bytes) async {
  try {
    final srcImg = img.decodeImage(bytes);
    if (srcImg == null) return null;

    final srcW = srcImg.width.toDouble();
    final srcH = srcImg.height.toDouble();

    final mq = MediaQuery.of(context);
    final maxSize = mq.size.width - 80.0;
    final displaySize = (maxSize > 360) ? 360.0 : maxSize;
    final cropSize = displaySize - 40.0;

    final initialScale = (srcW == 0 || srcH == 0)
        ? 1.0
        : (min(displaySize / srcW, displaySize / srcH));

    double childWidth = srcW * initialScale;
    double childHeight = srcH * initialScale;

    if (childWidth < cropSize || childHeight < cropSize) {
      final scaleUp = max(cropSize / childWidth, cropSize / childHeight);
      childWidth *= scaleUp;
      childHeight *= scaleUp;
    }

    final controller = TransformationController();
    
    controller.value = Matrix4.identity()
      ..translate((displaySize - childWidth) / 2, (displaySize - childHeight) / 2);

    return await showDialog<Uint8List?>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementBrightness,
          builder: (_, brightness, __) {
            final surfaceColor = SettingsManager.getElementColor(
              Theme.of(ctx).colorScheme.surface,
              brightness,
            );
            return Center(
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: displaySize,
                    padding: const EdgeInsets.all(12),
                    color: surfaceColor.withValues(alpha: 1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: displaySize,
                      height: displaySize,
                      child: Stack(
                        children: [
                          ScrollConfiguration(
                            behavior: ScrollConfiguration.of(ctx).copyWith(
                              scrollbars: false,
                            ),
                            child: InteractiveViewer(
                              transformationController: controller,
                              boundaryMargin: const EdgeInsets.all(300),
                              minScale: 0.5,
                              maxScale: 5.0,
                              child: SizedBox(
                                width: childWidth,
                                height: childHeight,
                                child: Image.memory(
                                  bytes,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                          ),
                          
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                size: Size.infinite,
                                painter: _CircleHolePainter(
                                  overlayColor: surfaceColor.withValues(alpha: 0.6),
                                  borderColor: Theme.of(ctx).colorScheme.primary,
                                  holeRadius: cropSize / 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(null),
                          child: const Text('Cancel'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () {
                            
                            final matrix = controller.value;
                            final viewerScale = matrix.getMaxScaleOnAxis();

                            final viewportCenter = Offset(displaySize / 2, displaySize / 2);
                            final viewportRadius = cropSize / 2;

                            final childCenter = controller.toScene(viewportCenter);

                            final childToImageScaleX = srcW / childWidth;
                            final childToImageScaleY = srcH / childHeight;

                            final imageCenterX = childCenter.dx * childToImageScaleX;
                            final imageCenterY = childCenter.dy * childToImageScaleY;

                            final imageRadiusX = (viewportRadius / viewerScale) * childToImageScaleX;
                            final imageRadiusY = (viewportRadius / viewerScale) * childToImageScaleY;
                            
                            final imageRadius = (imageRadiusX + imageRadiusY) / 2;

                            var side = (imageRadius * 2).round();
                            side = max(1, side);
                            side = min(side, srcImg.width);
                            side = min(side, srcImg.height);

                            int sx = (imageCenterX - side / 2).round();
                            int sy = (imageCenterY - side / 2).round();

                            sx = sx.clamp(0, max(0, srcImg.width - side)).toInt();
                            sy = sy.clamp(0, max(0, srcImg.height - side)).toInt();

                            try {
                              
                              final square = img.copyCrop(srcImg, x: sx, y: sy, width: side, height: side);
                              
                              final resized = img.copyResize(square, width: 512, height: 512, interpolation: img.Interpolation.linear);
                              final out = img.encodeJpg(resized, quality: 85);
                              Navigator.of(ctx).pop(Uint8List.fromList(out));
                            } catch (e) {
                              Navigator.of(ctx).pop(null);
                            }
                          },
                          child: const Text('Crop & Upload'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
              ),
            );
          },
        );
      },
    );
  } catch (e) {
    return null;
  }
}

class _CircleHolePainter extends CustomPainter {
  final Color overlayColor;
  final Color borderColor;
  final double holeRadius;

  _CircleHolePainter({required this.overlayColor, required this.borderColor, required this.holeRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    
    canvas.saveLayer(rect, Paint());
    final overlayPaint = Paint()..color = overlayColor;
    canvas.drawRect(rect, overlayPaint);

    final clearPaint = Paint()..blendMode = BlendMode.clear;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, holeRadius, clearPaint);

    canvas.restore();

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = borderColor;
    canvas.drawCircle(center, holeRadius, stroke);
  }

  @override
  bool shouldRepaint(covariant _CircleHolePainter oldDelegate) {
    return oldDelegate.overlayColor != overlayColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.holeRadius != holeRadius;
  }
}