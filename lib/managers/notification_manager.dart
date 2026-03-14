import 'package:flutter/material.dart';

class OverlayNotification {
  final String username;
  final String? displayName;
  final String message;
  final String? avatarUrl;
  final DateTime time;
  final Duration displayDuration;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  OverlayNotification({
    required this.username,
    this.displayName,
    required this.message,
    this.avatarUrl,
    Duration? displayDuration,
    this.onTap,
    this.onDismiss,
  })  : time = DateTime.now(),
        displayDuration = displayDuration ?? const Duration(seconds: 5);
}

class OverlayNotificationManager {
  static final OverlayNotificationManager _instance = OverlayNotificationManager._internal();

  factory OverlayNotificationManager() {
    return _instance;
  }

  OverlayNotificationManager._internal();

  final ValueNotifier<List<OverlayNotification>> notificationsNotifier =
      ValueNotifier<List<OverlayNotification>>([]);

  final ValueNotifier<OverlayNotification?> currentNotification =
      ValueNotifier<OverlayNotification?>(null);

  void show(OverlayNotification notification) {
    currentNotification.value = notification;

    Future.delayed(notification.displayDuration, () {
      if (currentNotification.value == notification) {
        dismiss();
      }
    });
  }

  void dismiss() {
    final notification = currentNotification.value;
    currentNotification.value = null;
    notification?.onDismiss?.call();
  }

  void showFromMessage({
    required String username,
    String? displayName,
    required String message,
    String? avatarUrl,
    Duration? displayDuration,
    VoidCallback? onTap,
  }) {
    show(
      OverlayNotification(
        username: username,
        displayName: displayName ?? username,
        message: message,
        avatarUrl: avatarUrl,
        displayDuration: displayDuration,
        onTap: onTap,
      ),
    );
  }

  void clear() {
    currentNotification.value = null;
  }
}