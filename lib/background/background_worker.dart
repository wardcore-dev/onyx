// lib/background/background_worker.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import '../services/message_sync_service.dart';
import 'notification_service.dart';

const String syncTaskName = 'syncMessagesTask';

@pragma('vm:entry-point')
Future<void> syncMessagesTask() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.init();

  final result = await MessageSyncService.checkForNewMessages();

  if (result.hasNewMessages && result.sender != null) {
    await NotificationService.showMessageNotification(
      title: result.sender!,
      username: result.sender!,
      body: result.preview ?? '',
      conversationTitle: result.sender!,
    );
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