// lib/background/notification_service.dart
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math' show sqrt;
import 'dart:typed_data'; 
import 'package:flutter/material.dart' show Color;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/onyx_base_dir.dart' show getOnyxSupportDirectory;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    final windowsIconPath =
        Platform.isWindows ? await _ensureWindowsToastIconOnDisk() : null;

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
              guid: '3f0b6a8b-1b1b-4cde-9f2a-123456789abc',
              iconPath: windowsIconPath)
          : null,
      linux: Platform.isLinux
          ? const LinuxInitializationSettings(defaultActionName: 'Open')
          : null,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _handleNotificationTap,
    );

    await checkNotificationLaunchDetails();

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
          // Separate channel for scheduled reminders — Android channel sound
          // can't be changed after creation, so the alarm-like sound needs
          // its own channel rather than reusing messages_channel.
          const remindersChannel = AndroidNotificationChannel(
            'reminders_channel',
            'Reminders',
            description: 'Scheduled message reminder alerts',
            importance: Importance.max,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('onyxringtone0'),
          );
          await androidPlugin.createNotificationChannel(remindersChannel);
        } catch (e) {
          debugPrint('createNotificationChannel failed: $e');
        }
      }
    }

    _initialized = true;
  }

  // Set to the payload of the most recently handled
  // getNotificationAppLaunchDetails() response, so a repeat call that finds
  // the *same* still-cached launch intent (see checkNotificationLaunchDetails'
  // doc) doesn't replay it again.
  static String? _lastHandledLaunchPayload;

  /// Checks whether the current Activity's launch Intent was the tap on a
  /// notification, and if so replays it exactly like a live tap would.
  ///
  /// Called once from [init] for the ordinary cold-start case, and *again*
  /// from main.dart on every app resume — because on at least some Android
  /// OEMs (confirmed via field logs on a Samsung device) the Activity can be
  /// destroyed and recreated by the OS while the Dart process/isolate stays
  /// alive underneath it (e.g. kept alive by the background keep-alive
  /// foreground service), and `init()`'s `_initialized` guard means it only
  /// ever runs once per *process* lifetime — not once per *Activity*
  /// lifetime. A notification tapped while the app is in that state
  /// recreates the Activity with a fresh launch Intent that nothing was
  /// re-checking for, so the tap was silently lost before it ever reached
  /// [_handleNotificationTap] or even flutter_local_notifications' own
  /// response callbacks — matching exactly what field logs showed: no
  /// "_handleNotificationTap fired" line at all, and every
  /// [consumePendingTap] call finding nothing persisted.
  ///
  /// flutter_local_notifications caches the launch details against the
  /// current Activity's `getIntent()` — calling this repeatedly without an
  /// actual new launch just keeps returning the same cached response, so
  /// [_lastHandledLaunchPayload] dedups against that instead of replaying
  /// the same already-handled tap on every future resume.
  static Future<void> checkNotificationLaunchDetails() async {
    try {
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      final launchResponse = launchDetails?.notificationResponse;
      final payload = launchResponse?.payload;
      if (launchDetails?.didNotificationLaunchApp != true ||
          launchResponse == null ||
          payload == null ||
          payload == _lastHandledLaunchPayload) {
        return;
      }
      _lastHandledLaunchPayload = payload;
      // Dispatched once RootScreen signals its listeners are attached (see
      // [listenersReady]) rather than on a guessed delay, since both
      // openChatStream/openReminderStream are plain broadcast streams — an
      // event fired before anyone is listening is lost for good.
      unawaited(() async {
        await listenersReady.future.timeout(
          const Duration(seconds: 8),
          onTimeout: () {},
        );
        _handleNotificationTap(launchResponse);
      }());
    } catch (e) {
      debugPrint('[notif] getNotificationAppLaunchDetails failed: $e');
    }
  }

  /// flutter_local_notifications' Windows plugin registers the toast's
  /// `IconUri` registry value from [WindowsInitializationSettings.iconPath]
  /// — that value needs an actual file on disk, not a Flutter asset bundle
  /// reference. Without it, Windows falls back to the app's window-class
  /// icon (loaded via the legacy `LoadIcon` Win32 API, which only ever
  /// resolves a 32px frame), which is what made the toast's icon look
  /// blurry when the shell scaled it up for Action Center. Extracting the
  /// bundled 512x512 source icon once and pointing the toast at that fixes
  /// the resolution.
  static Future<String?> _ensureWindowsToastIconOnDisk() async {
    try {
      final dir = await getOnyxSupportDirectory();
      final file = File('${dir.path}/notification_icon.png');
      if (!await file.exists()) {
        final bytes = await rootBundle.load('assets/onyx_icon.png');
        await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      }
      return file.path;
    } catch (e) {
      debugPrint('[notif] failed to stage Windows toast icon: $e');
      return null;
    }
  }

  /// Completes once RootScreen has subscribed to both openChatStream and
  /// openReminderStream — lets a cold-start notification-tap payload (see
  /// [init]) wait for a real listener instead of firing on a guessed delay.
  static final Completer<void> listenersReady = Completer<void>();

  static void markListenersReady() {
    if (!listenersReady.isCompleted) listenersReady.complete();
  }

  static final StreamController<String> _openChatController =
      StreamController<String>.broadcast();
  static Stream<String> get openChatStream => _openChatController.stream;

  static void openChat(String username) {
    _openChatController.add(username);
  }

  // WorkManager's syncMessagesTask (background_worker.dart) calls
  // NotificationService.init() from its own headless background isolate to
  // show notifications, and Android can likewise invoke
  // onDidReceiveBackgroundNotificationResponse in yet another disposable
  // isolate when a notification is tapped while the main UI isolate/Activity
  // isn't currently attached — which "app is merely backgrounded" often
  // still qualifies as, depending how aggressively Android tore the Activity
  // down. Every isolate gets its own static _openChatController/
  // _openReminderController, so a tap handled off the main isolate has no
  // listener and is silently lost. SharedPreferences is one of the few
  // mechanisms that actually crosses that isolate boundary, so tap payloads
  // are stashed there and replayed by the main isolate once it's ready.
  static const _pendingTapPrefsKey = 'onyx_pending_notification_tap';

  // Serializes every persist→dispatch→clear cycle against every
  // read→dispatch→clear cycle on the pending-tap prefs slot. Without this,
  // a live tap handled by _handleNotificationTap (which persists, dispatches,
  // then asynchronously clears the persisted copy) could interleave with a
  // concurrent consumePendingTap() call — main.dart fires one unconditionally
  // on every app resume, and Android can deliver an inactive→resumed blip
  // just from tapping a notification even when the app was already
  // foregrounded. If consumePendingTap's read lands between the persist and
  // the clear, it finds the same payload still there, sees the same live
  // listener, and dispatches it a second time — opening the same chat twice.
  // Chaining every critical section onto this future makes them run
  // strictly one after another in call order, regardless of which one
  // started suspending on its own `await`s first.
  static Future<void> _tapQueue = Future.value();

  static Future<T> _serializedTapAccess<T>(Future<T> Function() action) {
    final result = _tapQueue.then((_) => action());
    // Swallow errors on the queue chain itself (not on the caller's Future)
    // so one failed critical section can't wedge every call after it.
    _tapQueue = result.then((_) {}, onError: (_) {});
    return result;
  }

  static Future<void> _persistPendingTap(String rawPayload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingTapPrefsKey, rawPayload);
    } catch (e) {
      debugPrint('[notif] failed to persist pending tap: $e');
    }
  }

  /// Clears whatever [_persistPendingTap] stashed, without replaying it.
  /// Called right after a direct/live dispatch of that same payload reached
  /// an actual listener — otherwise the next unconditional
  /// [consumePendingTap] call (main.dart fires one on every app resume, to
  /// recover background-isolate taps) finds the same payload still sitting
  /// there and replays it a second time, opening the same chat twice.
  static Future<void> _clearPendingTapIfMatches(String rawPayload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_pendingTapPrefsKey) == rawPayload) {
        await prefs.remove(_pendingTapPrefsKey);
      }
    } catch (e) {
      debugPrint('[notif] failed to clear pending tap: $e');
    }
  }

  /// Reads back and clears any payload stashed by [_persistPendingTap],
  /// replaying it into the live streams. Only meaningful from the main UI
  /// isolate (after its listeners are attached) — call it speculatively any
  /// number of times, it's a no-op once the stored value is gone. Used both
  /// at cold start (after listenersReady) and on every app resume, since a
  /// background-isolate tap can arrive while the app is simply backgrounded.
  static Future<void> consumePendingTap() {
    return _serializedTapAccess(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_pendingTapPrefsKey);
        debugPrint('[notif] consumePendingTap: raw=${raw != null} '
            'chatListener=${_openChatController.hasListener} '
            'reminderListener=${_openReminderController.hasListener}');
        if (raw == null) return;
        if (!_openChatController.hasListener &&
            !_openReminderController.hasListener) {
          // Nobody's listening yet (e.g. still behind the initial PIN gate,
          // where RootScreen hasn't mounted at all) — leave it persisted for
          // the next resume/markListenersReady call instead of firing into
          // streams no one will ever observe.
          return;
        }
        await prefs.remove(_pendingTapPrefsKey);
        _dispatchPayload(raw);
      } catch (e) {
        debugPrint('[notif] consumePendingTap failed: $e');
      }
    });
  }

  // Separate from [openChatStream] (which only ever carries a bare DM
  // username) so reminder taps — which can point at a favorite/group/
  // external-group/mesh chat, not just a DM — don't have to be shoehorned
  // into that shape.
  static final StreamController<Map<String, dynamic>> _openReminderController =
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get openReminderStream =>
      _openReminderController.stream;

  static final Map<String, List<Message>> _messageHistory = {};

  static int _notifId(String username) => username.hashCode.abs() % 100000;

  static void clearMessagesForUser(String username) {
    _messageHistory.remove(username);
    try { _plugin.cancel(_notifId(username)); } catch (e) {}
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

    // macOS gets a real system notification too (via UNUserNotificationCenter,
    // same DarwinNotificationDetails object as iOS) — Windows/Linux keep
    // their separate mechanisms (custom in-app popup / sound-only) and stay
    // excluded here.
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
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
        NotificationDetails(
            android: androidDetails, iOS: iosDetails, macOS: iosDetails),
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

/// Top-level (NOT a class method) on purpose: when the app process is fully
/// killed, Android invokes onDidReceiveBackgroundNotificationResponse in a
/// fresh background isolate spun up just for the tap. flutter_local
/// notifications' own docs/examples always use a top-level function for
/// that callback — a class static method with `@pragma('vm:entry-point')`
/// is not reliably kept reachable from that isolate by the AOT compiler,
/// which is what made taps silently do nothing after a full app kill.
/// Dart privacy is per-file, not per-class, so this can still reach
/// NotificationService's private statics directly since it's in the same
/// library.
void _dispatchPayload(String rawPayload) {
  try {
    final p = jsonDecode(rawPayload);
    if (p is Map && p['type'] == 'msg' && p['username'] is String) {
      final username = p['username'] as String;
      NotificationService._messageHistory.remove(username);
      NotificationService._openChatController.add(username);
    } else if (p is Map && p['type'] == 'reminder') {
      NotificationService._openReminderController
          .add(Map<String, dynamic>.from(p));
    }
  } catch (e) {
    debugPrint('Failed to handle notification response: $e');
  }
}

@pragma('vm:entry-point')
void _handleNotificationTap(NotificationResponse response) async {
  final payload = response.payload;
  debugPrint('[notif] _handleNotificationTap fired: '
      'actionId=${response.actionId} notificationId=${response.id} '
      'payload=$payload');
  if (payload == null || payload.isEmpty) return;
  // Persist first — cheap, and it's what actually survives this callback
  // running in a disposable background isolate (see consumePendingTap's
  // doc comment). Also attempt an immediate dispatch for the common case
  // where this IS the main UI isolate with live listeners already attached,
  // so foreground/just-backgrounded taps still navigate instantly instead
  // of waiting for the next resume-time consumePendingTap() poll.
  //
  // The whole persist→dispatch→clear sequence runs as one serialized
  // critical section (see _serializedTapAccess's doc) so a concurrent
  // consumePendingTap() call can't read the persisted copy between the
  // persist and the clear and replay the same tap a second time.
  await NotificationService._serializedTapAccess(() async {
    await NotificationService._persistPendingTap(payload);
    final hadLiveListener =
        NotificationService._openChatController.hasListener ||
            NotificationService._openReminderController.hasListener;
    _dispatchPayload(payload);
    if (hadLiveListener) {
      // Reached a real listener just now — clear the persisted copy so
      // main.dart's unconditional per-resume consumePendingTap() doesn't
      // replay this same tap and open the chat a second time.
      await NotificationService._clearPendingTapIfMatches(payload);
    }
  });
}