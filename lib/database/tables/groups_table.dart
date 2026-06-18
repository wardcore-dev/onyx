import 'package:drift/drift.dart';

@DataClassName('GroupRow')
class Groups extends Table {
  IntColumn get groupId => integer()();
  TextColumn get accountId => text()();
  TextColumn get serverHost => text()();

  TextColumn get name => text()();
  BoolColumn get isChannel => boolean()();
  TextColumn get owner => text()();
  TextColumn get inviteLink => text().withDefault(const Constant(''))();
  IntColumn get avatarVersion => integer().withDefault(const Constant(0))();
  TextColumn get externalServerId => text().nullable()();
  TextColumn get myRole => text().nullable()();

  @override
  Set<Column> get primaryKey => {groupId, accountId, serverHost};
}
