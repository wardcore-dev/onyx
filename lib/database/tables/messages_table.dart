import 'package:drift/drift.dart';

class Messages extends Table {
  // Composite PK: (messageId, accountId, serverHost) — same message can't
  // exist twice for the same account on the same server.
  TextColumn get messageId => text()();
  TextColumn get chatId => text()(); // peer username OR 'fav:<favoriteId>'
  TextColumn get accountId => text()();
  TextColumn get serverHost => text()();

  TextColumn get fromUser => text()();
  TextColumn get toUser => text()();
  TextColumn get content => text()();

  BoolColumn get outgoing => boolean()();
  BoolColumn get delivered => boolean().withDefault(const Constant(false))();
  BoolColumn get isRead => boolean().withDefault(const Constant(true))();
  BoolColumn get pendingSend => boolean().withDefault(const Constant(false))();

  IntColumn get timeMs => integer()(); // DateTime.millisecondsSinceEpoch

  TextColumn get rawEnvelopePreview => text().nullable()();
  TextColumn get encryptedForDevice => text().nullable()();
  IntColumn get serverMessageId => integer().nullable()();

  IntColumn get replyToId => integer().nullable()();
  TextColumn get replyToSender => text().nullable()();
  TextColumn get replyToContent => text().nullable()();

  TextColumn get deliveryMode =>
      text().withDefault(const Constant('internet'))();
  IntColumn get deliveredAtMs => integer().nullable()();

  TextColumn get reactionsJson => text().nullable()(); // JSON-encoded map

  @override
  Set<Column> get primaryKey => {messageId, accountId, serverHost};
}
