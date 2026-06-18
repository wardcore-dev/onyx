import 'package:drift/drift.dart';
import '../../models/group.dart' as model;
import '../app_database.dart';

part 'group_dao.g.dart';

@DriftAccessor(tables: [Groups])
class GroupDao extends DatabaseAccessor<AppDatabase> with _$GroupDaoMixin {
  GroupDao(super.db);

  Future<List<GroupRow>> getRawGroups(String accountId, String serverHost) {
    return (select(groups)
          ..where((t) =>
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost)))
        .get();
  }

  Future<List<model.Group>> getGroups(
    String accountId,
    String serverHost,
  ) async {
    final rows = await getRawGroups(accountId, serverHost);
    return rows.map(_toModel).toList();
  }

  Stream<List<model.Group>> watchGroups(String accountId, String serverHost) {
    return (select(groups)
          ..where((t) =>
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost)))
        .watch()
        .map((rows) => rows.map(_toModel).toList());
  }

  Future<void> upsertGroups(
    String accountId,
    String serverHost,
    List<model.Group> groupList,
  ) {
    final entries = groupList
        .map((g) => GroupsCompanion(
              groupId: Value(g.id),
              accountId: Value(accountId),
              serverHost: Value(serverHost),
              name: Value(g.name),
              isChannel: Value(g.isChannel),
              owner: Value(g.owner),
              inviteLink: Value(g.inviteLink),
              avatarVersion: Value(g.avatarVersion),
              externalServerId: Value(g.externalServerId),
              myRole: Value(g.myRole),
            ))
        .toList();
    return batch((b) => b.insertAllOnConflictUpdate(groups, entries));
  }

  Future<int> deleteGroup(
    int groupId,
    String accountId,
    String serverHost,
  ) {
    return (delete(groups)
          ..where((t) =>
              t.groupId.equals(groupId) &
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost)))
        .go();
  }

  static model.Group _toModel(GroupRow row) {
    return model.Group(
      id: row.groupId,
      name: row.name,
      isChannel: row.isChannel,
      owner: row.owner,
      inviteLink: row.inviteLink,
      avatarVersion: row.avatarVersion,
      externalServerId: row.externalServerId,
      myRole: row.myRole,
    );
  }
}
