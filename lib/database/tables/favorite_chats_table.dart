import 'package:drift/drift.dart';

@DataClassName('FavoriteChatRow')
class FavoriteChats extends Table {
  TextColumn get favId => text()();
  TextColumn get accountId => text()();
  TextColumn get serverHost => text()();

  TextColumn get title => text()();
  TextColumn get avatarPath => text().nullable()();
  IntColumn get createdAtMs => integer()();

  @override
  Set<Column> get primaryKey => {favId, accountId, serverHost};
}
