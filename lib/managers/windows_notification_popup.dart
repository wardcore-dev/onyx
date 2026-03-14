import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WindowsNotificationPopup {
  static const platform = MethodChannel('com.onyx.messenger/notifications');

  static Future<void> showNotification({
    required String username,
    required String displayName,
    required String message,
    Duration displayDuration = const Duration(seconds: 5),
    String? surfaceColor,
    String? onSurfaceColor,
    String? onSurfaceVariantColor,
    
    String? avatarColor,
    
    String? avatarLetterColor,
    String? primaryColor,
    
    String? messageColor,
    
    String position = 'bottom_right',
  }) async {
    try {
      await platform.invokeMethod<void>('showNotification', {
        'username': username,
        'displayName': displayName,
        'message': message,
        'displayDurationMs': displayDuration.inMilliseconds,
        'surfaceColor': surfaceColor,
        'onSurfaceColor': onSurfaceColor,
        'onSurfaceVariantColor': onSurfaceVariantColor,
        'avatarColor': avatarColor,
        'avatarLetterColor': avatarLetterColor,
        'primaryColor': primaryColor,
        'messageColor': messageColor,
        'position': position,
      });
    } catch (e) {
      debugPrint('[WindowsNotification] showNotification error: $e');
    }
  }

  static Future<void> updateAvatar(Uint8List bytes) async {
    try {
      await platform.invokeMethod<void>('updateAvatar', {
        'avatarBytes': bytes,
      });
    } catch (e) {
      debugPrint('[WindowsNotification] updateAvatar error: $e');
    }
  }

  static Future<void> closeNotification() async {
    try {
      await platform.invokeMethod<void>('closeNotification');
    } catch (e) {
      debugPrint('[WindowsNotification] closeNotification error: $e');
    }
  }

  static void onNotificationTapped(Function(String username) callback) {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationTapped') {
        final username = call.arguments['username'] as String?;
        if (username != null) {
          callback(username);
        }
      }
    });
  }
}