import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/credential_models.dart';

part 'app_database.g.dart';

/// Persists the configured backend server URL across app restarts (Sprint 0.1's
/// drift proof-of-concept).
class ServerConfigTable extends Table {
  @override
  String get tableName => 'server_config';

  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get baseUrl => text()();
  DateTimeColumn get lastConnectedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Offline cache for the credential list — ciphertext + metadata only, matching
/// high-level-design.md §2's local data model (scoped down to what Sprint 1.3 needs;
/// folders/tags get their own tables when Sprint 1.5 needs real CRUD for them — tags are
/// stored as an embedded JSON column here for now rather than a join table, since this
/// sprint only reads them, never manages them independently).
class CachedCredentialsTable extends Table {
  @override
  String get tableName => 'cached_credentials';

  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get encryptedData => text()();
  TextColumn get dataIv => text()();
  TextColumn get encryptedCredentialKey => text()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  TextColumn get folderId => text().nullable()();
  TextColumn get folderName => text().nullable()();
  TextColumn get credentialGroupId => text().nullable()();
  TextColumn get credentialGroupName => text().nullable()();
  TextColumn get ownerId => text()();
  TextColumn get ownerUsername => text()();
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {id};
}

class CachedCredentialGroupsTable extends Table {
  @override
  String get tableName => 'cached_credential_groups';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  TextColumn get teamGroupId => text().nullable()();
  IntColumn get credentialCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sprint 1.7 (MOB-SYNC-02) offline write queue — high-level-design.md §2's local data
/// model. Scoped to credential *updates* only (the sprint's tested path); offline
/// create/delete would need client-generated temp-ID reconciliation, a distinct chunk of
/// work not covered by this sprint's acceptance criteria.
///
/// [baseUpdatedAt] is the credential's server `updatedAt` at the moment the edit was
/// made — flush-time conflict detection (requirements §6.3) compares this against the
/// server's *current* `updatedAt` to tell "safe to replay" apart from "changed elsewhere
/// since," since the backend has no ETag/row-version field to detect that directly.
class PendingMutationsTable extends Table {
  @override
  String get tableName => 'pending_mutations';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text().withDefault(const Constant('credential'))();
  TextColumn get entityId => text()();
  TextColumn get operation => text().withDefault(const Constant('update'))();
  TextColumn get payloadJson => text()();
  DateTimeColumn get baseUpdatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [
  ServerConfigTable,
  CachedCredentialsTable,
  CachedCredentialGroupsTable,
  PendingMutationsTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(cachedCredentialsTable);
            await m.createTable(cachedCredentialGroupsTable);
          }
          if (from < 3) {
            await m.createTable(pendingMutationsTable);
          }
        },
      );

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

  Future<List<CredentialListItem>> getCachedCredentials() async {
    final rows = await select(cachedCredentialsTable).get();
    return rows.map(_credentialFromRow).toList();
  }

  Future<void> replaceCachedCredentials(List<CredentialListItem> items) async {
    await transaction(() async {
      await delete(cachedCredentialsTable).go();
      await batch((b) {
        b.insertAll(cachedCredentialsTable, items.map(_credentialToCompanion).toList());
      });
    });
  }

  Future<List<CredentialGroupSummary>> getCachedCredentialGroups() async {
    final rows = await select(cachedCredentialGroupsTable).get();
    return rows
        .map((r) => CredentialGroupSummary(
              id: r.id,
              name: r.name,
              icon: r.icon,
              teamGroupId: r.teamGroupId,
              credentialCount: r.credentialCount,
            ))
        .toList();
  }

  Future<void> replaceCachedCredentialGroups(List<CredentialGroupSummary> items) async {
    await transaction(() async {
      await delete(cachedCredentialGroupsTable).go();
      await batch((b) {
        b.insertAll(
          cachedCredentialGroupsTable,
          items.map((g) => CachedCredentialGroupsTableCompanion.insert(
                id: g.id,
                name: g.name,
                icon: g.icon,
                teamGroupId: Value(g.teamGroupId),
                credentialCount: Value(g.credentialCount),
              )),
        );
      });
    });
  }

  Future<List<PendingMutationsTableData>> getPendingMutations() {
    return (select(pendingMutationsTable)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> queuePendingMutation({
    required String entityId,
    required Map<String, dynamic> payload,
    required DateTime baseUpdatedAt,
  }) {
    return into(pendingMutationsTable).insert(PendingMutationsTableCompanion.insert(
      entityId: entityId,
      payloadJson: jsonEncode(payload),
      baseUpdatedAt: baseUpdatedAt,
    ));
  }

  Future<void> deletePendingMutation(int id) {
    return (delete(pendingMutationsTable)..where((t) => t.id.equals(id))).go();
  }

  /// Reflects a queued-offline edit in the read cache immediately, so the detail/edit
  /// screens (which fall back to this cache on the very next GET, still offline) show
  /// the just-made change rather than stale pre-edit data. `folderName`/
  /// `credentialGroupName`/`tagsJson` are deliberately left untouched — this is a
  /// best-effort local reflection, not a full re-derivation, and the next successful
  /// online fetch (including the one that follows a flush) replaces the row wholesale
  /// anyway.
  Future<void> applyOptimisticCredentialUpdate(
    String id,
    Map<String, dynamic> body,
    DateTime updatedAt,
  ) {
    return (update(cachedCredentialsTable)..where((t) => t.id.equals(id))).write(
      CachedCredentialsTableCompanion(
        encryptedData: Value(body['encryptedData'] as String),
        dataIv: Value(body['dataIv'] as String),
        encryptedCredentialKey: Value(body['encryptedCredentialKey'] as String),
        expiryDate: Value(
            body['expiryDate'] == null ? null : DateTime.parse(body['expiryDate'] as String)),
        folderId: Value(body['folderId'] as String?),
        credentialGroupId: Value(body['credentialGroupId'] as String?),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  CredentialListItem _credentialFromRow(CachedCredentialsTableData r) => CredentialListItem(
        id: r.id,
        type: r.type,
        encryptedData: r.encryptedData,
        dataIv: r.dataIv,
        encryptedCredentialKey: r.encryptedCredentialKey,
        expiryDate: r.expiryDate,
        folderId: r.folderId,
        folderName: r.folderName,
        credentialGroupId: r.credentialGroupId,
        credentialGroupName: r.credentialGroupName,
        ownerId: r.ownerId,
        ownerUsername: r.ownerUsername,
        isShared: r.isShared,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        tags: (jsonDecode(r.tagsJson) as List<dynamic>)
            .map((t) => TagRef.fromJson(t as Map<String, dynamic>))
            .toList(),
      );

  CachedCredentialsTableCompanion _credentialToCompanion(CredentialListItem c) =>
      CachedCredentialsTableCompanion.insert(
        id: c.id,
        type: c.type,
        encryptedData: c.encryptedData,
        dataIv: c.dataIv,
        encryptedCredentialKey: c.encryptedCredentialKey,
        expiryDate: Value(c.expiryDate),
        folderId: Value(c.folderId),
        folderName: Value(c.folderName),
        credentialGroupId: Value(c.credentialGroupId),
        credentialGroupName: Value(c.credentialGroupName),
        ownerId: c.ownerId,
        ownerUsername: c.ownerUsername,
        isShared: Value(c.isShared),
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
        tagsJson: Value(jsonEncode(c.tags.map((t) => t.toJson()).toList())),
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'xcred_mobile.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
