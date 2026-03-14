import 'package:flutter/material.dart';
import '../widgets/message_notification_popup.dart';

class MessageNotificationPopupManager {
  static final MessageNotificationPopupManager _instance =
      MessageNotificationPopupManager._internal();

  factory MessageNotificationPopupManager() => _instance;
  MessageNotificationPopupManager._internal();

  final ValueNotifier<MessageNotificationData?> currentNotification =
      ValueNotifier<MessageNotificationData?>(null);

  Future<void> show({
    required String username,
    required String displayName,
    required String message,
    String? avatarUrl,
    Duration displayDuration = const Duration(seconds: 5),
    VoidCallback? onTap,
  }) async {
    final data = MessageNotificationData(
      username: username,
      displayName: displayName,
      message: message,
      avatarUrl: avatarUrl,
      displayDuration: displayDuration,
      onTap: onTap,
    );

    currentNotification.value = data;

    Future.delayed(displayDuration, () {
      if (currentNotification.value == data) {
        dismiss();
      }
    });
  }

  void dismiss() {
    currentNotification.value = null;
  }
}