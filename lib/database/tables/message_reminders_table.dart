import 'package:drift/drift.dart';

@DataClassName('MessageReminderRow')
class MessageReminders extends Table {
  TextColumn get reminderId => text()();
  TextColumn get accountId => text()();
  TextColumn get serverHost => text()();

  TextColumn get messageId => text()();
  TextColumn get chatId => text()();
  TextColumn get chatType => text()(); // 'dm' | 'fav' | 'group' | 'extgroup' | 'mesh'

  TextColumn get chatTitle => text()();
  TextColumn get messagePreview => text()();
  TextColumn get avatarPath => text().nullable()();

  TextColumn get externalServerId => text().nullable()();
  TextColumn get otherUsername => text().nullable()();

  // ARGB32 of the app's accent color at the moment the reminder was
  // scheduled — baked in so the notification tint matches the user's
  // chosen theme instead of the OS's default fallback color.
  IntColumn get accentColorArgb => integer().nullable()();

  IntColumn get scheduledAtMs => integer()();
  IntColumn get createdAtMs => integer()();

  BoolColumn get fired => boolean().withDefault(const Constant(false))();
  BoolColumn get cancelled => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {reminderId, accountId, serverHost};
}
