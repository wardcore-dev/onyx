// lib/widgets/measure_size.dart
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

class _MeasureSizeRenderObject extends RenderProxyBox {
  Size? _oldSize;
  ValueChanged<Size> onChange;

  _MeasureSizeRenderObject(this.onChange);

  @override
  void performLayout() {
    super.performLayout();
    final newSize = child?.size;
    if (newSize == null || newSize == _oldSize) return;
    _oldSize = newSize;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(newSize));
  }
}

/// Reports the rendered size of [child] after every layout pass, without
/// affecting [child]'s own layout (a transparent proxy box).
class MeasureSize extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onChange;

  const MeasureSize({super.key, required this.onChange, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _MeasureSizeRenderObject(onChange);

  @override
  void updateRenderObject(BuildContext context, covariant _MeasureSizeRenderObject renderObject) {
    renderObject.onChange = onChange;
  }
}
