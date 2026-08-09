import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Persists the configured backend server URL across app restarts (Sprint 0.1's
/// drift proof-of-concept). Later sprints add the offline cache tables
/// (credentials/folders/tags/etc.) described in docs/planning/high-level-design.md §2 —
/// deliberately not scaffolded yet since Sprint 1.1 doesn't need them.
class ServerConfigTable extends Table {
  @override
  String get tableName => 'server_config';

  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get baseUrl => text()();
  DateTimeColumn get lastConnectedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [ServerConfigTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  Future<String?> getServerBaseUrl() async {
    final row = await (select(serverConfigTable)..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    return row?.baseUrl;
  }

  Future<void> setServerBaseUrl(String url) {
    return into(serverConfigTable).insertOnConflictUpdate(
      ServerConfigTableCompanion.insert(id: const Value(1), baseUrl: url),
    );
  }

  Future<void> clearServerBaseUrl() {
    return (delete(serverConfigTable)..where((t) => t.id.equals(1))).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'xcred_mobile.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
