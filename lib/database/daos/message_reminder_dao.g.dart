// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_reminder_dao.dart';

// ignore_for_file: type=lint
mixin _$MessageReminderDaoMixin on DatabaseAccessor<AppDatabase> {
  $MessageRemindersTable get messageReminders =>
      attachedDatabase.messageReminders;
  MessageReminderDaoManager get managers => MessageReminderDaoManager(this);
}

class MessageReminderDaoManager {
  final _$MessageReminderDaoMixin _db;
  MessageReminderDaoManager(this._db);
  $$MessageRemindersTableTableManager get messageReminders =>
      $$MessageRemindersTableTableManager(
          _db.attachedDatabase, _db.messageReminders);
}
