import 'dart:convert';
import 'package:drift/drift.dart';
import '../app_database.dart';

part 'group_message_dao.g.dart';

@DriftAccessor(tables: [GroupMessages])
class GroupMessageDao extends DatabaseAccessor<AppDatabase>
    with _$GroupMessageDaoMixin {
  GroupMessageDao(super.db);

  Future<List<Map<String, dynamic>>> getGroupMessages(
    int groupId,
    String accountId,
    String serverHost,
  ) async {
    final rows = await (select(groupMessages)
          ..where((t) =>
              t.groupId.equals(groupId) &
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost))
          ..orderBy([(t) => OrderingTerm.asc(t.timeMs)]))
        .get();
    return rows.map((r) {
      try {
        return jsonDecode(r.rawJson) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((m) => m.isNotEmpty).toList();
  }

  Stream<List<Map<String, dynamic>>> watchGroupMessages(
    int groupId,
    String accountId,
    String serverHost,
  ) {
    return (select(groupMessages)
          ..where((t) =>
              t.groupId.equals(groupId) &
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost))
          ..orderBy([(t) => OrderingTerm.asc(t.timeMs)]))
        .watch()
        .map((rows) => rows.map((r) {
              try {
                return jsonDecode(r.rawJson) as Map<String, dynamic>;
              } catch (_) {
                return <String, dynamic>{};
              }
            }).where((m) => m.isNotEmpty).toList());
  }

  /// Replaces all messages for a group (mirrors the current saveGroupHistory behavior).
  Future<void> saveGroupMessages(
    int groupId,
    String accountId,
    String serverHost,
    List<Map<String, dynamic>> messages,
  ) async {
    await transaction(() async {
      await (delete(groupMessages)
            ..where((t) =>
                t.groupId.equals(groupId) &
                t.accountId.equals(accountId) &
                t.serverHost.equals(serverHost)))
          .go();

      final entries = messages.map((m) {
        final serverMsgId = _parseInt(m['id'] ?? m['server_id']);
        final timeMs = _parseTimeMs(m['time'] ?? m['created_at'] ?? m['timestamp']);
        return GroupMessagesCompanion(
          groupId: Value(groupId),
          accountId: Value(accountId),
          serverHost: Value(serverHost),
          serverMsgId: Value(serverMsgId),
          timeMs: Value(timeMs),
          rawJson: Value(jsonEncode(m)),
        );
      }).toList();

      await batch((b) => b.insertAll(groupMessages, entries));
    });
  }

  Future<int> deleteGroupMessages(
    int groupId,
    String accountId,
    String serverHost,
  ) {
    return (delete(groupMessages)
          ..where((t) =>
              t.groupId.equals(groupId) &
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost)))
        .go();
  }

  static int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v != null) return int.tryParse(v.toString());
    return null;
  }

  static int _parseTimeMs(dynamic v) {
    if (v == null) return DateTime.now().millisecondsSinceEpoch;
    if (v is int) return v;
    final dt = DateTime.tryParse(v.toString());
    if (dt != null) return dt.millisecondsSinceEpoch;
    return DateTime.now().millisecondsSinceEpoch;
  }
}
