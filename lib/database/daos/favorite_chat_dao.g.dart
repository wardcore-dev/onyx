// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_chat_dao.dart';

// ignore_for_file: type=lint
mixin _$FavoriteChatDaoMixin on DatabaseAccessor<AppDatabase> {
  $FavoriteChatsTable get favoriteChats => attachedDatabase.favoriteChats;
  FavoriteChatDaoManager get managers => FavoriteChatDaoManager(this);
}

class FavoriteChatDaoManager {
  final _$FavoriteChatDaoMixin _db;
  FavoriteChatDaoManager(this._db);
  $$FavoriteChatsTableTableManager get favoriteChats =>
      $$FavoriteChatsTableTableManager(_db.attachedDatabase, _db.favoriteChats);
}
