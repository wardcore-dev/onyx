import 'dart:async';
import 'package:flutter/material.dart';

class OptimizedStateManager {
  Timer? _debounceTimer;
  final Duration debounceDelay;
  bool _isDirty = false;

  OptimizedStateManager({
    this.debounceDelay = const Duration(milliseconds: 16), 
  });

  void updateState(
    VoidCallback onStateChange, {
    bool immediate = false,
  }) {
    if (immediate) {
      _cancel();
      onStateChange();
      _isDirty = false;
      return;
    }

    _isDirty = true;
    _debounceTimer?.cancel();

    _debounceTimer = Timer(debounceDelay, () {
      if (_isDirty) {
        onStateChange();
        _isDirty = false;
      }
    });
  }

  void _cancel() {
    _debounceTimer?.cancel();
    _isDirty = false;
  }

  void dispose() {
    _cancel();
  }
}

mixin OptimizedStateMixin<T extends StatefulWidget> on State<T> {
  late final OptimizedStateManager _stateManager;
  final Set<String> _changedFields = {};

  @override
  void initState() {
    super.initState();
    _stateManager = OptimizedStateManager();
  }

  @override
  void dispose() {
    _stateManager.dispose();
    super.dispose();
  }

  void updateStateOptimized(
    VoidCallback updates, {
    bool immediate = false,
    String? fieldName,
  }) {
    if (fieldName != null) {
      _changedFields.add(fieldName);
    }

    if (!mounted) return;

    _stateManager.updateState(
      () {
        if (!mounted) return;
        setState(updates);
        _changedFields.clear();
      },
      immediate: immediate,
    );
  }

  bool hasFieldChanged(String fieldName) {
    return _changedFields.contains(fieldName);
  }
}

class StateBatcher {
  final List<VoidCallback> _batch = [];
  Timer? _batchTimer;
  final Duration batchDelay;
  VoidCallback? _onBatchReady;

  StateBatcher({
    this.batchDelay = const Duration(milliseconds: 32), 
  });

  void add(VoidCallback update) {
    _batch.add(update);
    _scheduleBatchFlush();
  }

  void onBatchReady(VoidCallback callback) {
    _onBatchReady = callback;
  }

  void _scheduleBatchFlush() {
    if (_batchTimer != null) return; 

    _batchTimer = Timer(batchDelay, _flushBatch);
  }

  void _flushBatch() {
    _batchTimer = null;

    for (final update in _batch) {
      update();
    }
    _batch.clear();

    _onBatchReady?.call();
  }

  void dispose() {
    _batchTimer?.cancel();
    _batch.clear();
  }
}