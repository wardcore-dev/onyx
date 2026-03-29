// lib/background/foreground_task_handler.dart
//
// Minimal foreground-task handler for flutter_foreground_task.
// The handler itself does nothing — its sole purpose is to satisfy the plugin
// API so the Android Foreground Service stays running.  While the service is
// active the OS will not kill the Flutter process, which keeps the main
// isolate's WebSocket connection alive and messages/notifications flowing.
//
// iOS note: iOS does not support persistent foreground services.  The service
// call is accepted by the plugin API but background execution on iOS remains
// limited to the OS-granted window after the app is backgrounded.

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Entry point called by the plugin in its own isolate.
/// Must be annotated so the Dart tree-shaker keeps it in release builds.
@pragma('vm:entry-point')
void onyxForegroundTaskEntryPoint() {
  FlutterForegroundTask.setTaskHandler(_OnyxConnectionHandler());
}

class _OnyxConnectionHandler extends TaskHandler {
  // Nothing to do on start — the WebSocket lives in the main isolate.
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  // No periodic work needed.
  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
