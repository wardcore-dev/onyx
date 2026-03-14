// lib/widgets/adaptive_blur.dart
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class AdaptiveBlur extends StatelessWidget {
  final ImageProvider imageProvider;
  final double sigma;
  final BoxFit fit;
  final bool enabled;
  final double pixelLimit;

  const AdaptiveBlur({
    Key? key,
    required this.imageProvider,
    required this.sigma,
    this.fit = BoxFit.cover,
    this.enabled = true,
    this.pixelLimit = 2e6, 
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!enabled || sigma <= 0.01) {
      return Image(image: imageProvider, fit: fit);
    }

    final mq = MediaQuery.of(context);
    final width = mq.size.width;
    final height = mq.size.height;
    final dpr = mq.devicePixelRatio;

    final devicePixels = width * height * dpr * dpr;

    double scale = 1.0;
    if (devicePixels > pixelLimit) {
      scale = math.sqrt(pixelLimit / devicePixels);
      scale = scale.clamp(0.25, 1.0);
    }

    final targetDecodeWidth = math.max(1, (width * scale * dpr).round());

    ImageProvider provider;
    try {
      provider = ResizeImage(imageProvider, width: targetDecodeWidth);
    } catch (e) {
      provider = imageProvider;
    }

    return RepaintBoundary(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Image(
          image: provider,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}