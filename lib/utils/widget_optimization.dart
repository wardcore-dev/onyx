// lib/utils/widget_optimization.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DebouncedValueNotifier<T> extends ValueNotifier<T> {
  Timer? _debounce;
  final Duration delay;

  DebouncedValueNotifier(
    super.value, {
    this.delay = const Duration(milliseconds: 300),
  });

  void setValueDebounced(T newValue) {
    _debounce?.cancel();
    _debounce = Timer(delay, () {
      value = newValue;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

class ComputeCache<K, V> {
  final Map<K, _CachedValue<V>> _cache = {};
  final Duration ttl;

  ComputeCache({this.ttl = const Duration(minutes: 5)});

  V getOrCompute(K key, V Function() compute) {
    final now = DateTime.now();
    final cached = _cache[key];

    if (cached != null && now.difference(cached.createdAt) < ttl) {
      return cached.value;
    }

    final computed = compute();
    _cache[key] = _CachedValue(value: computed, createdAt: now);
    return computed;
  }

  void clear() => _cache.clear();
}

class _CachedValue<V> {
  final V value;
  final DateTime createdAt;

  _CachedValue({required this.value, required this.createdAt});
}

class OptimizedBuilder<T> extends StatelessWidget {
  final ValueListenable<T> valueListenable;
  final Widget Function(BuildContext, T, Widget?) builder;
  final Widget? child;
  final Duration? rebuildThrottle;

  const OptimizedBuilder({
    Key? key,
    required this.valueListenable,
    required this.builder,
    this.child,
    this.rebuildThrottle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<T>(
      valueListenable: valueListenable,
      child: child,
      builder: (context, value, child) {
        return RepaintBoundary(
          child: builder(context, value, child),
        );
      },
    );
  }
}