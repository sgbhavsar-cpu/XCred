// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ServerConfigTableTable extends ServerConfigTable
    with TableInfo<$ServerConfigTableTable, ServerConfigTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServerConfigTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastConnectedAtMeta = const VerificationMeta(
    'lastConnectedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastConnectedAt =
      GeneratedColumn<DateTime>(
        'last_connected_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: currentDateAndTime,
      );
  @override
  List<GeneratedColumn> get $columns => [id, baseUrl, lastConnectedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'server_config';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServerConfigTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('last_connected_at')) {
      context.handle(
        _lastConnectedAtMeta,
        lastConnectedAt.isAcceptableOrUnknown(
          data['last_connected_at']!,
          _lastConnectedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ServerConfigTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServerConfigTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      lastConnectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_connected_at'],
      )!,
    );
  }

  @override
  $ServerConfigTableTable createAlias(String alias) {
    return $ServerConfigTableTable(attachedDatabase, alias);
  }
}

class ServerConfigTableData extends DataClass
    implements Insertable<ServerConfigTableData> {
  final int id;
  final String baseUrl;
  final DateTime lastConnectedAt;
  const ServerConfigTableData({
    required this.id,
    required this.baseUrl,
    required this.lastConnectedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['base_url'] = Variable<String>(baseUrl);
    map['last_connected_at'] = Variable<DateTime>(lastConnectedAt);
    return map;
  }

  ServerConfigTableCompanion toCompanion(bool nullToAbsent) {
    return ServerConfigTableCompanion(
      id: Value(id),
      baseUrl: Value(baseUrl),
      lastConnectedAt: Value(lastConnectedAt),
    );
  }

  factory ServerConfigTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServerConfigTableData(
      id: serializer.fromJson<int>(json['id']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      lastConnectedAt: serializer.fromJson<DateTime>(json['lastConnectedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'lastConnectedAt': serializer.toJson<DateTime>(lastConnectedAt),
    };
  }

  ServerConfigTableData copyWith({
    int? id,
    String? baseUrl,
    DateTime? lastConnectedAt,
  }) => ServerConfigTableData(
    id: id ?? this.id,
    baseUrl: baseUrl ?? this.baseUrl,
    lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
  );
  ServerConfigTableData copyWithCompanion(ServerConfigTableCompanion data) {
    return ServerConfigTableData(
      id: data.id.present ? data.id.value : this.id,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      lastConnectedAt: data.lastConnectedAt.present
          ? data.lastConnectedAt.value
          : this.lastConnectedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServerConfigTableData(')
          ..write('id: $id, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('lastConnectedAt: $lastConnectedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, baseUrl, lastConnectedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServerConfigTableData &&
          other.id == this.id &&
          other.baseUrl == this.baseUrl &&
          other.lastConnectedAt == this.lastConnectedAt);
}

class ServerConfigTableCompanion
    extends UpdateCompanion<ServerConfigTableData> {
  final Value<int> id;
  final Value<String> baseUrl;
  final Value<DateTime> lastConnectedAt;
  const ServerConfigTableCompanion({
    this.id = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.lastConnectedAt = const Value.absent(),
  });
  ServerConfigTableCompanion.insert({
    this.id = const Value.absent(),
    required String baseUrl,
    this.lastConnectedAt = const Value.absent(),
  }) : baseUrl = Value(baseUrl);
  static Insertable<ServerConfigTableData> custom({
    Expression<int>? id,
    Expression<String>? baseUrl,
    Expression<DateTime>? lastConnectedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (baseUrl != null) 'base_url': baseUrl,
      if (lastConnectedAt != null) 'last_connected_at': lastConnectedAt,
    });
  }

  ServerConfigTableCompanion copyWith({
    Value<int>? id,
    Value<String>? baseUrl,
    Value<DateTime>? lastConnectedAt,
  }) {
    return ServerConfigTableCompanion(
      id: id ?? this.id,
      baseUrl: baseUrl ?? this.baseUrl,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (lastConnectedAt.present) {
      map['last_connected_at'] = Variable<DateTime>(lastConnectedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServerConfigTableCompanion(')
          ..write('id: $id, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('lastConnectedAt: $lastConnectedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ServerConfigTableTable serverConfigTable =
      $ServerConfigTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [serverConfigTable];
}

typedef $$ServerConfigTableTableCreateCompanionBuilder =
    ServerConfigTableCompanion Function({
      Value<int> id,
      required String baseUrl,
      Value<DateTime> lastConnectedAt,
    });
typedef $$ServerConfigTableTableUpdateCompanionBuilder =
    ServerConfigTableCompanion Function({
      Value<int> id,
      Value<String> baseUrl,
      Value<DateTime> lastConnectedAt,
    });

class $$ServerConfigTableTableFilterComposer
    extends Composer<_$AppDatabase, $ServerConfigTableTable> {
  $$ServerConfigTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ServerConfigTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ServerConfigTableTable> {
  $$ServerConfigTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ServerConfigTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServerConfigTableTable> {
  $$ServerConfigTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => column,
  );
}

class $$ServerConfigTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ServerConfigTableTable,
          ServerConfigTableData,
          $$ServerConfigTableTableFilterComposer,
          $$ServerConfigTableTableOrderingComposer,
          $$ServerConfigTableTableAnnotationComposer,
          $$ServerConfigTableTableCreateCompanionBuilder,
          $$ServerConfigTableTableUpdateCompanionBuilder,
          (
            ServerConfigTableData,
            BaseReferences<
              _$AppDatabase,
              $ServerConfigTableTable,
              ServerConfigTableData
            >,
          ),
          ServerConfigTableData,
          PrefetchHooks Function()
        > {
  $$ServerConfigTableTableTableManager(
    _$AppDatabase db,
    $ServerConfigTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServerConfigTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServerConfigTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServerConfigTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<DateTime> lastConnectedAt = const Value.absent(),
              }) => ServerConfigTableCompanion(
                id: id,
                baseUrl: baseUrl,
                lastConnectedAt: lastConnectedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String baseUrl,
                Value<DateTime> lastConnectedAt = const Value.absent(),
              }) => ServerConfigTableCompanion.insert(
                id: id,
                baseUrl: baseUrl,
                lastConnectedAt: lastConnectedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ServerConfigTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ServerConfigTableTable,
      ServerConfigTableData,
      $$ServerConfigTableTableFilterComposer,
      $$ServerConfigTableTableOrderingComposer,
      $$ServerConfigTableTableAnnotationComposer,
      $$ServerConfigTableTableCreateCompanionBuilder,
      $$ServerConfigTableTableUpdateCompanionBuilder,
      (
        ServerConfigTableData,
        BaseReferences<
          _$AppDatabase,
          $ServerConfigTableTable,
          ServerConfigTableData
        >,
      ),
      ServerConfigTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ServerConfigTableTableTableManager get serverConfigTable =>
      $$ServerConfigTableTableTableManager(_db, _db.serverConfigTable);
}
