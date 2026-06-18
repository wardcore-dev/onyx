import 'package:drift/drift.dart';

// Group messages are stored as raw JSON (server format) because the server
// returns them as Map<String, dynamic> with inconsistent key names.
// We extract only the fields needed for indexing/sorting.
class GroupMessages extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get groupId => integer()();
  TextColumn get accountId => text()();
  TextColumn get serverHost => text()();

  // Server-assigned message ID — nullable because local drafts may lack it.
  IntColumn get serverMsgId => integer().nullable()();

  IntColumn get timeMs => integer()(); // for ORDER BY

  TextColumn get rawJson => text()(); // full message as JSON string
}
