// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_message_dao.dart';

// ignore_for_file: type=lint
mixin _$GroupMessageDaoMixin on DatabaseAccessor<AppDatabase> {
  $GroupMessagesTable get groupMessages => attachedDatabase.groupMessages;
  GroupMessageDaoManager get managers => GroupMessageDaoManager(this);
}

class GroupMessageDaoManager {
  final _$GroupMessageDaoMixin _db;
  GroupMessageDaoManager(this._db);
  $$GroupMessagesTableTableManager get groupMessages =>
      $$GroupMessagesTableTableManager(_db.attachedDatabase, _db.groupMessages);
}
