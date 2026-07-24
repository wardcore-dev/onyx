import 'package:drift/drift.dart';
import '../../models/message_reminder.dart' as model;
import '../app_database.dart';

part 'message_reminder_dao.g.dart';

@DriftAccessor(tables: [MessageReminders])
class MessageReminderDao extends DatabaseAccessor<AppDatabase>
    with _$MessageReminderDaoMixin {
  MessageReminderDao(super.db);

  Future<MessageReminderRow?> getActiveReminderForMessage(
    String accountId,
    String serverHost,
    String chatId,
    String messageId,
  ) {
    return (select(messageReminders)
          ..where((t) =>
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost) &
              t.chatId.equals(chatId) &
              t.messageId.equals(messageId) &
              t.fired.equals(false) &
              t.cancelled.equals(false)))
        .getSingleOrNull();
  }

  Future<List<MessageReminderRow>> getDueReminders(
    String accountId,
    String serverHost,
    DateTime now,
  ) {
    final nowMs = now.millisecondsSinceEpoch;
    return (select(messageReminders)
          ..where((t) =>
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost) &
              t.fired.equals(false) &
              t.cancelled.equals(false) &
              t.scheduledAtMs.isSmallerOrEqualValue(nowMs)))
        .get();
  }

  Stream<List<model.MessageReminder>> watchActiveReminders(
    String accountId,
    String serverHost,
  ) {
    return (select(messageReminders)
          ..where((t) =>
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost) &
              t.fired.equals(false) &
              t.cancelled.equals(false)))
        .watch()
        .map((rows) => rows.map(_toModel).toList());
  }

  Future<void> upsertReminder(
    String accountId,
    String serverHost,
    model.MessageReminder reminder,
  ) {
    return into(messageReminders).insertOnConflictUpdate(
      MessageRemindersCompanion(
        reminderId: Value(reminder.reminderId),
        accountId: Value(accountId),
        serverHost: Value(serverHost),
        messageId: Value(reminder.messageId),
        chatId: Value(reminder.chatId),
        chatType: Value(reminder.chatType),
        chatTitle: Value(reminder.chatTitle),
        messagePreview: Value(reminder.messagePreview),
        avatarPath: Value(reminder.avatarPath),
        externalServerId: Value(reminder.externalServerId),
        otherUsername: Value(reminder.otherUsername),
        accentColorArgb: Value(reminder.accentColorArgb),
        scheduledAtMs: Value(reminder.scheduledAt.millisecondsSinceEpoch),
        createdAtMs: Value(reminder.createdAt.millisecondsSinceEpoch),
        fired: Value(reminder.fired),
        cancelled: Value(reminder.cancelled),
      ),
    );
  }

  Future<void> cancelReminderById(
    String reminderId,
    String accountId,
    String serverHost,
  ) {
    return (update(messageReminders)
          ..where((t) =>
              t.reminderId.equals(reminderId) &
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost)))
        .write(const MessageRemindersCompanion(cancelled: Value(true)));
  }

  Future<void> cancelReminderForMessage(
    String accountId,
    String serverHost,
    String chatId,
    String messageId,
  ) {
    return (update(messageReminders)
          ..where((t) =>
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost) &
              t.chatId.equals(chatId) &
              t.messageId.equals(messageId) &
              t.fired.equals(false) &
              t.cancelled.equals(false)))
        .write(const MessageRemindersCompanion(cancelled: Value(true)));
  }

  Future<void> markFired(
    String reminderId,
    String accountId,
    String serverHost,
  ) {
    return (update(messageReminders)
          ..where((t) =>
              t.reminderId.equals(reminderId) &
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost)))
        .write(const MessageRemindersCompanion(fired: Value(true)));
  }

  static model.MessageReminder _toModel(MessageReminderRow row) {
    return model.MessageReminder(
      reminderId: row.reminderId,
      messageId: row.messageId,
      chatId: row.chatId,
      chatType: row.chatType,
      chatTitle: row.chatTitle,
      messagePreview: row.messagePreview,
      avatarPath: row.avatarPath,
      externalServerId: row.externalServerId,
      otherUsername: row.otherUsername,
      accentColorArgb: row.accentColorArgb,
      scheduledAt: DateTime.fromMillisecondsSinceEpoch(row.scheduledAtMs),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAtMs),
      fired: row.fired,
      cancelled: row.cancelled,
    );
  }
}
