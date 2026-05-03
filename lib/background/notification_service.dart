// lib/background/notification_service.dart
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math' show sqrt;
import 'dart:typed_data'; 
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:image/image.dart' as img;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinNotificationAction openAction = DarwinNotificationAction.plain(
      'open',
      'Open',
      options: {DarwinNotificationActionOption.foreground},
    );
    final DarwinNotificationCategory messageCategory = DarwinNotificationCategory(
      'message',
      actions: [openAction],
    );

    final DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [messageCategory],
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
      windows: Platform.isWindows
          ? WindowsInitializationSettings(
              appName: 'ONYX',
              appUserModelId: 'com.onyx.onyx',
              guid: '3f0b6a8b-1b1b-4cde-9f2a-123456789abc')
          : null,
      linux: Platform.isLinux
          ? const LinuxInitializationSettings(defaultActionName: 'Open')
          : null,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onDidReceiveNotificationResponse,
    );

    if (Platform.isAndroid) {
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
        try {
          const channel = AndroidNotificationChannel(
            'messages_channel',
            'Messages',
            description: 'Incoming message alerts',
            importance: Importance.max,
          );
          await androidPlugin.createNotificationChannel(channel);

          const mediaChannel = AndroidNotificationChannel(
            'media_player',
            'Media Player',
            description: 'Audio playback controls',
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
            showBadge: false,
          );
          await androidPlugin.createNotificationChannel(mediaChannel);
        } catch (e) {
          debugPrint('createNotificationChannel failed: $e');
        }
      }
    }

    _initialized = true;
  }

  static const int _mediaNotifId = 88888;

  static Future<void> showMediaNotification({
    required String trackName,
    required bool isPlaying,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final androidDetails = AndroidNotificationDetails(
        'media_player',
        'Media Player',
        channelDescription: 'Audio playback controls',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        playSound: false,
        enableVibration: false,
        showWhen: false,
        category: AndroidNotificationCategory.transport,
        styleInformation: const MediaStyleInformation(
          htmlFormatTitle: false,
          htmlFormatContent: false,
        ),
        color: const Color(0xFF7C4DFF),
      );
      await _plugin.show(
        _mediaNotifId,
        isPlaying ? 'Playing' : 'Paused',
        trackName,
        NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('showMediaNotification failed: $e');
    }
  }

  static Future<void> cancelMediaNotification() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _plugin.cancel(_mediaNotifId);
    } catch (e) {
      debugPrint('cancelMediaNotification failed: $e');
    }
  }

  static final StreamController<String> _openChatController =
      StreamController<String>.broadcast();
  static Stream<String> get openChatStream => _openChatController.stream;

  static void openChat(String username) {
    _openChatController.add(username);
  }

  static final Map<String, List<Message>> _messageHistory = {};

  static int _notifId(String username) => username.hashCode.abs() % 100000;

  static void clearMessagesForUser(String username) {
    _messageHistory.remove(username);
    try { _plugin.cancel(_notifId(username)); } catch (e) {}
  }

  static void _onDidReceiveNotificationResponse(NotificationResponse response) {
    try {
      if (response.payload != null && response.payload!.isNotEmpty) {
        final p = jsonDecode(response.payload!);
        if (p is Map && p['type'] == 'msg' && p['username'] is String) {
          final username = p['username'] as String;
          _messageHistory.remove(username); 
          _openChatController.add(username);
        }
      }
    } catch (e) {
      debugPrint('Failed to handle notification response: $e');
    }
  }

  static Future<bool> requestPermissionFromUser() async {
    try {
      if (Platform.isAndroid) {
        final androidPlugin =
            _plugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          try {
            final res = await androidPlugin.requestNotificationsPermission();
            if (res != null) return res;
          } catch (e) {
            debugPrint('requestPermissionFromUser: plugin request failed: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('requestPermissionFromUser: unexpected error: $e');
    }
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  static Future<Uint8List> _buildLetterAvatarBytes(
    String displayName,
    Color bgColor,
    Color letterColor,
  ) async {
    const size = 192;
    final image = img.Image(width: size, height: size, numChannels: 4);
    img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));

    int toC(double v) => (v * 255.0).round().clamp(0, 255);
    final bgR = toC(bgColor.r), bgG = toC(bgColor.g), bgB = toC(bgColor.b);

    final cx = size / 2.0, cy = size / 2.0, r = size / 2.0;
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final dx = x + 0.5 - cx, dy = y + 0.5 - cy;
        final dist = sqrt(dx * dx + dy * dy);
        final a = ((r - dist + 1.0).clamp(0.0, 1.0) * 255).round();
        if (a > 0) image.setPixel(x, y, img.ColorRgba8(bgR, bgG, bgB, a));
      }
    }

    final letter = (displayName.isNotEmpty ? displayName[0] : '?').toUpperCase();
    final fg = img.ColorRgba8(toC(letterColor.r), toC(letterColor.g), toC(letterColor.b), 255);
    final font = img.arial48;
    final charW = font.characters[letter.codeUnitAt(0)]?.width ?? 28;
    final lx = (size - charW) ~/ 2;
    final ly = (size - font.size) ~/ 2;
    img.drawString(image, letter, font: font, x: lx, y: ly, color: fg);

    return Uint8List.fromList(img.encodePng(image));
  }

  static Uint8List _cropCircular(Uint8List bytes) {
    final original = img.decodeImage(bytes);
    if (original == null) return bytes;
    const outSize = 192;
    final square = img.copyResizeCropSquare(original, size: outSize);
    final output = img.Image(width: outSize, height: outSize, numChannels: 4);
    img.fill(output, color: img.ColorRgba8(0, 0, 0, 0));
    final cx = outSize / 2.0, cy = outSize / 2.0, r = outSize / 2.0;
    for (int y = 0; y < outSize; y++) {
      for (int x = 0; x < outSize; x++) {
        final dx = x + 0.5 - cx, dy = y + 0.5 - cy;
        final dist = sqrt(dx * dx + dy * dy);
        final a = ((r - dist + 1.0).clamp(0.0, 1.0) * 255).round();
        if (a > 0) {
          final src = square.getPixel(x, y);
          output.setPixel(x, y, img.ColorRgba8(
            src.r.toInt(), src.g.toInt(), src.b.toInt(), a));
        }
      }
    }
    return Uint8List.fromList(img.encodePng(output));
  }

  static Future<void> showMessageNotification({
    required String title,
    required String body,
    required String username,
    Uint8List? avatarBytes,
    Color accentColor = const Color(0xFF7C4DFF),
    Color avatarBgColor = const Color(0xFF4A6741),
    Color avatarLetterColor = const Color(0xFFFFFFFF),
    DateTime? timestamp,
    String? conversationTitle,
  }) async {
    timestamp ??= DateTime.now();

    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return; 
    }

    final vibrationPattern = Int64List.fromList([0, 250, 100, 250]);

    Uint8List? iconBytes;
    if (avatarBytes != null && avatarBytes.isNotEmpty) {
      try {
        iconBytes = _cropCircular(avatarBytes);
      } catch (e) {
        debugPrint('Failed to process avatar bytes: $e');
      }
    }
    iconBytes ??= await _buildLetterAvatarBytes(title, avatarBgColor, avatarLetterColor);

    final AndroidBitmap<Object> largeIcon = ByteArrayAndroidBitmap(iconBytes);

    final person = Person(name: title);

    final history = _messageHistory.putIfAbsent(username, () => []);
    history.add(Message(body, timestamp, person));
    if (history.length > 5) history.removeAt(0);

    final messagingStyle = MessagingStyleInformation(
      person,
      messages: List.of(history),
      conversationTitle: conversationTitle ?? title,
      groupConversation: false,
    );

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'messages_channel',
      'Messages',
      channelDescription: 'Incoming message alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('notification0'),
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      styleInformation: messagingStyle,
      largeIcon: largeIcon,
      color: accentColor,
      colorized: true,
      autoCancel: true,
      ticker: 'Новое сообщение',
    );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      subtitle: conversationTitle ?? title,
      threadIdentifier: conversationTitle ?? 'messages',
      categoryIdentifier: 'message',
    );

    final payload = jsonEncode({
      'type': 'msg',
      'username': username,
      'conversationTitle': conversationTitle ?? title,
    });

    final notifId = _notifId(username);
    try {
      await _plugin.show(
        notifId,
        title,
        body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: payload,
      );
    } catch (e) {
      debugPrint('showMessageNotification failed: $e');
      await _plugin.show(
        notifId,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'messages_channel', 'Messages',
            channelDescription: 'Incoming message alerts',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: payload,
      );
    }
  }
}