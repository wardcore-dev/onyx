import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import 'tables/messages_table.dart';
import 'tables/groups_table.dart';
import 'tables/group_messages_table.dart';
import 'tables/favorite_chats_table.dart';
import 'daos/message_dao.dart';
import 'daos/group_dao.dart';
import 'daos/group_message_dao.dart';
import 'daos/favorite_chat_dao.dart';

export 'tables/messages_table.dart';
export 'tables/groups_table.dart';
export 'tables/group_messages_table.dart';
export 'tables/favorite_chats_table.dart';
export 'daos/message_dao.dart';
export 'daos/group_dao.dart';
export 'daos/group_message_dao.dart';
export 'daos/favorite_chat_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Messages, Groups, GroupMessages, FavoriteChats],
  daos: [MessageDao, GroupDao, GroupMessageDao, FavoriteChatDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(String dbDirectory)
      : super(_openConnection(dbDirectory));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await customStatement(
              'ALTER TABLE messages ADD COLUMN mesh_meta_json TEXT',
            );
          }
        },
        onCreate: (m) async {
          await m.createAll();
          // Indexes for fast chat-list and pagination queries.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_messages_chat '
            'ON messages (chat_id, account_id, server_host, time_ms DESC)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_messages_server_id '
            'ON messages (server_message_id, account_id, server_host)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_group_messages_group '
            'ON group_messages (group_id, account_id, server_host, time_ms ASC)',
          );
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_group_messages_server_id '
            'ON group_messages (server_msg_id, group_id, account_id, server_host) '
            'WHERE server_msg_id IS NOT NULL',
          );
        },
      );
}

LazyDatabase _openConnection(String dbDirectory) {
  return LazyDatabase(() async {
    final file = File(p.join(dbDirectory, 'onyx_data.db'));
    return NativeDatabase.createInBackground(file, logStatements: false);
  });
}
