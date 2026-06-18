import 'package:drift/drift.dart';
import '../../models/favorite_chat.dart' as model;
import '../app_database.dart';

part 'favorite_chat_dao.g.dart';

@DriftAccessor(tables: [FavoriteChats])
class FavoriteChatDao extends DatabaseAccessor<AppDatabase>
    with _$FavoriteChatDaoMixin {
  FavoriteChatDao(super.db);

  Future<List<FavoriteChatRow>> getRawFavorites(
    String accountId,
    String serverHost,
  ) {
    return (select(favoriteChats)
          ..where((t) =>
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAtMs)]))
        .get();
  }

  Future<List<model.FavoriteChat>> getFavorites(
    String accountId,
    String serverHost,
  ) async {
    final rows = await getRawFavorites(accountId, serverHost);
    return rows.map(_toModel).toList();
  }

  Stream<List<model.FavoriteChat>> watchFavorites(
    String accountId,
    String serverHost,
  ) {
    return (select(favoriteChats)
          ..where((t) =>
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAtMs)]))
        .watch()
        .map((rows) => rows.map(_toModel).toList());
  }

  Future<void> upsertFavorite(
    String accountId,
    String serverHost,
    model.FavoriteChat fav,
  ) {
    return into(favoriteChats).insertOnConflictUpdate(
      FavoriteChatsCompanion(
        favId: Value(fav.id),
        accountId: Value(accountId),
        serverHost: Value(serverHost),
        title: Value(fav.title),
        avatarPath: Value(fav.avatarPath),
        createdAtMs: Value(fav.createdAt.millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> upsertFavorites(
    String accountId,
    String serverHost,
    List<model.FavoriteChat> favList,
  ) {
    final entries = favList
        .map((f) => FavoriteChatsCompanion(
              favId: Value(f.id),
              accountId: Value(accountId),
              serverHost: Value(serverHost),
              title: Value(f.title),
              avatarPath: Value(f.avatarPath),
              createdAtMs: Value(f.createdAt.millisecondsSinceEpoch),
            ))
        .toList();
    return batch((b) => b.insertAllOnConflictUpdate(favoriteChats, entries));
  }

  Future<int> deleteFavorite(
    String favId,
    String accountId,
    String serverHost,
  ) {
    return (delete(favoriteChats)
          ..where((t) =>
              t.favId.equals(favId) &
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost)))
        .go();
  }

  static model.FavoriteChat _toModel(FavoriteChatRow row) {
    return model.FavoriteChat(
      id: row.favId,
      title: row.title,
      avatarPath: row.avatarPath,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAtMs),
    );
  }
}
