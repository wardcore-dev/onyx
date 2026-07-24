// lib/background/background_worker.dart
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import '../database/db_provider.dart';
import '../services/message_sync_service.dart';
import '../services/reminder_service.dart';
import '../managers/mute_manager.dart';
import 'notification_service.dart';

const String syncTaskName = 'syncMessagesTask';

@pragma('vm:entry-point')
Future<void> syncMessagesTask() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.init();
  await MuteManager.init();
  if (!DbProvider.isInitialized) {
    try {
      await DbProvider.init();
    } catch (e) {
      debugPrint('[background] DbProvider.init failed: $e');
    }
  }

  final result = await MessageSyncService.checkForNewMessages();

  if (result.hasNewMessages && result.sender != null && !MuteManager.isMuted(result.sender!)) {
    await NotificationService.showMessageNotification(
      title: result.sender!,
      username: result.sender!,
      body: result.preview ?? '',
      conversationTitle: result.sender!,
    );
  }

  // Same background task, same plain-notification mechanism — a due
  // reminder just fires "a message from yourself to yourself" here instead
  // of needing separate OS-level exact-alarm scheduling.
  try {
    await ReminderService.checkDueReminders();
  } catch (e) {
    debugPrint('[background] reminder check failed: $e');
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case syncTaskName:
        await syncMessagesTask();
        return true;
      default:
        return false;
    }
  });
}