// lib/services/reminder_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/db_provider.dart';
import '../globals.dart' show serverBase;
import '../l10n/app_localizations.dart';
import '../managers/account_manager.dart';
import '../managers/mute_manager.dart';
import '../managers/settings_manager.dart';
import '../managers/windows_notification_popup.dart';
import '../models/app_themes.dart';
import '../models/message_reminder.dart';

/// Builds the title/body shown for a reminder, honoring the "hide
/// notification content" privacy setting and always labeling it as a
/// reminder (rather than looking like a plain new-message notification).
(String title, String body) _buildReminderDisplay(MessageReminder r) {
  final l = lookupAppLocalizations(SettingsManager.appLocale.value);
  final hideContent = SettingsManager.notifHideContent.value;
  if (hideContent) {
    return ('ONYX', l.reminderGenericBody);
  }
  return ('${l.reminderNotificationPrefix}: ${r.chatTitle}', r.messagePreview);
}

/// Fires reminders on chat messages, across all chat types
/// (dm/fav/group/extgroup/mesh) and all platforms.
///
/// Deliberately does NOT use any OS-level "exact alarm" scheduling
/// (`zonedSchedule`/`AlarmManager`) — that path turned out to be unreliable
/// in practice (Android 12+ gates it behind a special permission that many
/// OEMs don't auto-grant, and it silently no-ops instead of firing when
/// missing). Instead this uses the exact same mechanism as an ordinary
/// incoming-message notification: a plain, immediate `.show()` call, fired
/// off a periodic due-reminder check — the app polls its own reminders
/// table and shows a notification "from itself to itself" once one comes
/// due, just like it already does when a real message arrives.
///
/// On Android this poll also runs inside the existing background sync
/// WorkManager task (see background_worker.dart), so reminders can still
/// fire while the app isn't in the foreground, in the same ~15-minute
/// window regular background message sync already uses — no separate
/// alarm permission needed. On desktop, an in-app timer covers it while
/// the app is running (Windows keeps its custom popup + looping sound;
/// Linux is sound-only, no visual notification story there today).
class ReminderService {
  ReminderService._();

  static const _uuid = Uuid();
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static Timer? _pollTimer;
  static final AudioPlayer _alarmPlayer = AudioPlayer();

  static String _serverHost() {
    try {
      final uri = Uri.parse(serverBase);
      return uri.host.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    } catch (_) {
      return serverBase.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    }
  }

  static int _notifIdFor(String reminderId) =>
      100000 + (reminderId.hashCode.abs() % 900000);

  /// Call once at startup, after [DbProvider.init] and
  /// [NotificationService.init] have completed.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Catch-up pass first: fires anything that came due while the app was
    // fully closed, then a periodic in-app check while it's running.
    await _pollOnce();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => unawaited(_pollOnce()));
  }

  static Future<void> scheduleReminder({
    required String accountId,
    required String messageId,
    required String chatType,
    required String chatId,
    required String chatTitle,
    required String messagePreview,
    String? avatarPath,
    String? externalServerId,
    String? otherUsername,
    int? accentColorArgb,
    required DateTime scheduledAt,
  }) async {
    final serverHost = _serverHost();
    final reminder = MessageReminder(
      reminderId: _uuid.v4(),
      messageId: messageId,
      chatId: chatId,
      chatType: chatType,
      chatTitle: chatTitle,
      messagePreview: messagePreview,
      avatarPath: avatarPath,
      externalServerId: externalServerId,
      otherUsername: otherUsername,
      accentColorArgb: accentColorArgb,
      scheduledAt: scheduledAt,
      createdAt: DateTime.now(),
    );
    // That's it — no OS scheduling call. The due-reminder poll (in-app
    // timer + the background sync task on Android) picks this row up once
    // it's due and shows a plain notification, same as for a real message.
    await DbProvider.db.messageReminderDao
        .upsertReminder(accountId, serverHost, reminder);
  }

  static Future<void> cancelReminder(
    String accountId,
    String chatId,
    String messageId,
  ) async {
    final serverHost = _serverHost();
    final row = await DbProvider.db.messageReminderDao
        .getActiveReminderForMessage(accountId, serverHost, chatId, messageId);
    if (row == null) return;
    await DbProvider.db.messageReminderDao
        .cancelReminderById(row.reminderId, accountId, serverHost);
  }

  static Future<bool> hasActiveReminder(
    String accountId,
    String chatId,
    String messageId,
  ) async {
    final row = await DbProvider.db.messageReminderDao
        .getActiveReminderForMessage(accountId, _serverHost(), chatId, messageId);
    return row != null;
  }

  static Stream<List<MessageReminder>> watchActiveReminders(String accountId) {
    return DbProvider.db.messageReminderDao
        .watchActiveReminders(accountId, _serverHost());
  }

  // ── Due-reminder poll (foreground timer + background WorkManager task) ──

  /// Runs one due-reminder check. Safe to call from the main app (foreground
  /// timer) or from the Android background sync isolate — resolves the
  /// current account itself so callers don't need to plumb it through.
  static Future<void> checkDueReminders() => _pollOnce();

  static Future<void> _pollOnce() async {
    if (!DbProvider.isInitialized) return;
    String? accountId = currentAccountIdForReminders?.call();
    accountId ??= await AccountManager.getCurrentAccount();
    if (accountId == null || accountId.isEmpty) return;
    final serverHost = _serverHost();
    List<MessageReminderRow> due;
    try {
      due = await DbProvider.db.messageReminderDao
          .getDueReminders(accountId, serverHost, DateTime.now());
    } catch (e) {
      debugPrint('[ReminderService] poll query failed: $e');
      return;
    }
    for (final row in due) {
      await _fireReminder(row);
      await DbProvider.db.messageReminderDao
          .markFired(row.reminderId, accountId, serverHost);
    }
  }

  /// The prefix used to disambiguate a reminder tap from a normal-message
  /// tap on Windows, where both share the same native
  /// `onNotificationTapped(String username)` round-trip (see
  /// [WindowsNotificationPopup]) — there's no separate payload channel
  /// there like there is for flutter_local_notifications' payload string.
  static const reminderTapPrefix = 'reminder|';

  static String encodeWindowsReminderTap(MessageReminderRow row) {
    return '$reminderTapPrefix${row.chatType}|${row.chatId}|${row.messageId}|'
        '${row.otherUsername ?? ''}|${row.externalServerId ?? ''}';
  }

  static String _hex(int argb) => argb.toRadixString(16).padLeft(8, '0');

  /// Resolves the app's *live* current color scheme from persisted theme
  /// settings — used instead of BuildContext (ReminderService has none) so
  /// the Windows popup matches whatever theme/dark-mode is active right now,
  /// not a default. This mirrors exactly what RootScreen computes from
  /// Theme.of(context) for a normal new-message popup.
  static Future<ColorSchemeColors> _resolveColorScheme() async {
    final pref = await SettingsManager.loadThemePreference();
    final theme = AppTheme.fromStoredName(pref.name);
    final isDark = pref.isDark ?? true;
    final scheme = theme.getThemeData(isDark: isDark).colorScheme;
    return ColorSchemeColors(
      surface: _hex(scheme.surface.toARGB32()),
      onSurface: _hex(scheme.onSurface.toARGB32()),
      onSurfaceVariant: _hex(scheme.onSurfaceVariant.toARGB32()),
      primary: _hex(scheme.primary.toARGB32()),
      primaryContainer: _hex(scheme.primaryContainer.toARGB32()),
      onPrimaryContainer: _hex(scheme.onPrimaryContainer.toARGB32()),
    );
  }

  /// Stops the looping alarm sound (Windows/Linux) — call when the user
  /// taps/consumes a reminder, before it would otherwise keep ringing.
  static Future<void> stopAlarmSound() async {
    try {
      await _alarmPlayer.stop();
    } catch (_) {}
  }

  static Future<void> _fireReminder(MessageReminderRow row) async {
    if (MuteManager.isMuted(row.chatId)) return;
    final reminder = MessageReminder(
      reminderId: row.reminderId,
      messageId: row.messageId,
      chatId: row.chatId,
      chatType: row.chatType,
      chatTitle: row.chatTitle,
      messagePreview: row.messagePreview,
      accentColorArgb: row.accentColorArgb,
      externalServerId: row.externalServerId,
      otherUsername: row.otherUsername,
      scheduledAt: DateTime.fromMillisecondsSinceEpoch(row.scheduledAtMs),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAtMs),
    );
    final (title, body) = _buildReminderDisplay(reminder);

    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isMacOS)) {
        await _showMobileReminderNotification(row, title, body);
      } else if (!kIsWeb && Platform.isWindows) {
        await _showWindowsReminderPopup(row, title, body);
        await _playAlarmSound(loop: true);
      } else if (!kIsWeb && Platform.isLinux) {
        // Sound-only, no visual notification story on Linux today.
        await _playAlarmSound(loop: true);
      }
    } catch (e) {
      debugPrint('[ReminderService] failed to fire reminder: $e');
    }
  }

  /// Android/macOS: exactly the same immediate `.show()` call an incoming
  /// message notification uses — just a different channel (custom sound)
  /// and payload (routes taps to the reminder, not the chat directly).
  static Future<void> _showMobileReminderNotification(
    MessageReminderRow row,
    String title,
    String body,
  ) async {
    final payload = jsonEncode({
      'type': 'reminder',
      'chatType': row.chatType,
      'chatId': row.chatId,
      'messageId': row.messageId,
      'externalServerId': row.externalServerId,
      'otherUsername': row.otherUsername,
      'reminderId': row.reminderId,
    });

    final androidDetails = AndroidNotificationDetails(
      'reminders_channel',
      'Reminders',
      channelDescription: 'Scheduled message reminder alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('onyxringtone0'),
      category: AndroidNotificationCategory.reminder,
      color: row.accentColorArgb != null ? Color(row.accentColorArgb!) : null,
      colorized: row.accentColorArgb != null,
    );

    final darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'onyxringtone0.wav',
      subtitle: row.chatTitle,
      categoryIdentifier: 'message',
    );

    await _plugin.show(
      _notifIdFor(row.reminderId),
      title,
      body,
      NotificationDetails(android: androidDetails, macOS: darwinDetails),
      payload: payload,
    );
  }

  static Future<void> _showWindowsReminderPopup(
    MessageReminderRow row,
    String title,
    String body,
  ) async {
    final colors = await _resolveColorScheme();
    await WindowsNotificationPopup.showNotification(
      username: encodeWindowsReminderTap(row),
      displayName: title,
      message: body,
      // An alarm-like reminder should stay up until the user acts on it,
      // not vanish after a few seconds like a normal message toast — it's
      // closed explicitly on tap (see root_screen.dart's reminder routing),
      // so a long duration here is just a safety net, not the primary
      // dismissal path.
      displayDuration: const Duration(hours: 1),
      surfaceColor: colors.surface,
      onSurfaceColor: colors.onSurface,
      onSurfaceVariantColor: colors.onSurfaceVariant,
      primaryColor: colors.primary,
      avatarColor: colors.primaryContainer,
      avatarLetterColor: colors.onPrimaryContainer,
      messageColor: colors.primary,
    );
  }

  static Future<void> _playAlarmSound({required bool loop}) async {
    await _alarmPlayer.stop();
    await _alarmPlayer
        .setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
    await _alarmPlayer.play(AssetSource('onyxringtone0.wav'));
  }

  /// Set by RootScreen at startup so the poll loop (which has no
  /// BuildContext of its own) can resolve the current account id quickly,
  /// without a SharedPreferences round-trip, while the app is running.
  static String? Function()? currentAccountIdForReminders;
}

class ColorSchemeColors {
  final String surface;
  final String onSurface;
  final String onSurfaceVariant;
  final String primary;
  final String primaryContainer;
  final String onPrimaryContainer;

  const ColorSchemeColors({
    required this.surface,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.primary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
  });
}
