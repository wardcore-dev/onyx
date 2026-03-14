// lib/utils/ui_optimizer.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class UIOptimizer {
  
  static Widget wrapRepaintBoundary(Widget child) {
    return RepaintBoundary(child: child);
  }

  static Widget cached(
    Key key,
    Widget Function() builder, {
    Duration invalidateDuration = const Duration(minutes: 5),
  }) {
    return _CachedWidget(key: key, builder: builder, invalidateDuration: invalidateDuration);
  }

  static Future<T> runInBackground<T>(T Function() computation) async {
    return compute(_isolateRunner, computation);
  }

  static VoidCallback debounce(VoidCallback fn, {Duration delay = const Duration(milliseconds: 300)}) {
    Timer? _timer;
    return () {
      _timer?.cancel();
      _timer = Timer(delay, fn);
    };
  }

  static Function(T) debounceWithValue<T>(
    Function(T) fn, {
    Duration delay = const Duration(milliseconds: 300),
  }) {
    Timer? _timer;
    return (T value) {
      _timer?.cancel();
      _timer = Timer(delay, () => fn(value));
    };
  }
}

class _CachedWidget extends StatefulWidget {
  final Widget Function() builder;
  final Duration invalidateDuration;

  const _CachedWidget({
    required Key key,
    required this.builder,
    required this.invalidateDuration,
  }) : super(key: key);

  @override
  State<_CachedWidget> createState() => _CachedWidgetState();
}

class _CachedWidgetState extends State<_CachedWidget> {
  late Widget _cachedWidget;
  late DateTime _cacheTime;

  @override
  void initState() {
    super.initState();
    _cachedWidget = widget.builder();
    _cacheTime = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (now.difference(_cacheTime) > widget.invalidateDuration) {
      _cachedWidget = widget.builder();
      _cacheTime = now;
    }
    return RepaintBoundary(child: _cachedWidget);
  }
}

Future<T> _isolateRunner<T>(T Function() computation) async {
  return computation();
}

class ListNotifier extends ChangeNotifier {
  final List<dynamic> items = [];

  void add(dynamic item) {
    items.add(item);
    notifyListeners();
  }

  void addAll(List<dynamic> newItems) {
    items.addAll(newItems);
    notifyListeners();
  }

  void setAll(List<dynamic> newItems) {
    items.clear();
    items.addAll(newItems);
    notifyListeners();
  }

  void updateAt(int index, dynamic item) {
    if (index >= 0 && index < items.length) {
      items[index] = item;
      notifyListeners();
    }
  }

  void remove(dynamic item) {
    items.remove(item);
    notifyListeners();
  }

  void clear() {
    items.clear();
    notifyListeners();
  }

  int get length => items.length;
}