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

class $CachedCredentialsTableTable extends CachedCredentialsTable
    with TableInfo<$CachedCredentialsTableTable, CachedCredentialsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedCredentialsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encryptedDataMeta = const VerificationMeta(
    'encryptedData',
  );
  @override
  late final GeneratedColumn<String> encryptedData = GeneratedColumn<String>(
    'encrypted_data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataIvMeta = const VerificationMeta('dataIv');
  @override
  late final GeneratedColumn<String> dataIv = GeneratedColumn<String>(
    'data_iv',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encryptedCredentialKeyMeta =
      const VerificationMeta('encryptedCredentialKey');
  @override
  late final GeneratedColumn<String> encryptedCredentialKey =
      GeneratedColumn<String>(
        'encrypted_credential_key',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _expiryDateMeta = const VerificationMeta(
    'expiryDate',
  );
  @override
  late final GeneratedColumn<DateTime> expiryDate = GeneratedColumn<DateTime>(
    'expiry_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _folderNameMeta = const VerificationMeta(
    'folderName',
  );
  @override
  late final GeneratedColumn<String> folderName = GeneratedColumn<String>(
    'folder_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _credentialGroupIdMeta = const VerificationMeta(
    'credentialGroupId',
  );
  @override
  late final GeneratedColumn<String> credentialGroupId =
      GeneratedColumn<String>(
        'credential_group_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _credentialGroupNameMeta =
      const VerificationMeta('credentialGroupName');
  @override
  late final GeneratedColumn<String> credentialGroupName =
      GeneratedColumn<String>(
        'credential_group_name',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerUsernameMeta = const VerificationMeta(
    'ownerUsername',
  );
  @override
  late final GeneratedColumn<String> ownerUsername = GeneratedColumn<String>(
    'owner_username',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isSharedMeta = const VerificationMeta(
    'isShared',
  );
  @override
  late final GeneratedColumn<bool> isShared = GeneratedColumn<bool>(
    'is_shared',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_shared" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    encryptedData,
    dataIv,
    encryptedCredentialKey,
    expiryDate,
    folderId,
    folderName,
    credentialGroupId,
    credentialGroupName,
    ownerId,
    ownerUsername,
    isShared,
    createdAt,
    updatedAt,
    tagsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_credentials';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedCredentialsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('encrypted_data')) {
      context.handle(
        _encryptedDataMeta,
        encryptedData.isAcceptableOrUnknown(
          data['encrypted_data']!,
          _encryptedDataMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedDataMeta);
    }
    if (data.containsKey('data_iv')) {
      context.handle(
        _dataIvMeta,
        dataIv.isAcceptableOrUnknown(data['data_iv']!, _dataIvMeta),
      );
    } else if (isInserting) {
      context.missing(_dataIvMeta);
    }
    if (data.containsKey('encrypted_credential_key')) {
      context.handle(
        _encryptedCredentialKeyMeta,
        encryptedCredentialKey.isAcceptableOrUnknown(
          data['encrypted_credential_key']!,
          _encryptedCredentialKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedCredentialKeyMeta);
    }
    if (data.containsKey('expiry_date')) {
      context.handle(
        _expiryDateMeta,
        expiryDate.isAcceptableOrUnknown(data['expiry_date']!, _expiryDateMeta),
      );
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('folder_name')) {
      context.handle(
        _folderNameMeta,
        folderName.isAcceptableOrUnknown(data['folder_name']!, _folderNameMeta),
      );
    }
    if (data.containsKey('credential_group_id')) {
      context.handle(
        _credentialGroupIdMeta,
        credentialGroupId.isAcceptableOrUnknown(
          data['credential_group_id']!,
          _credentialGroupIdMeta,
        ),
      );
    }
    if (data.containsKey('credential_group_name')) {
      context.handle(
        _credentialGroupNameMeta,
        credentialGroupName.isAcceptableOrUnknown(
          data['credential_group_name']!,
          _credentialGroupNameMeta,
        ),
      );
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('owner_username')) {
      context.handle(
        _ownerUsernameMeta,
        ownerUsername.isAcceptableOrUnknown(
          data['owner_username']!,
          _ownerUsernameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerUsernameMeta);
    }
    if (data.containsKey('is_shared')) {
      context.handle(
        _isSharedMeta,
        isShared.isAcceptableOrUnknown(data['is_shared']!, _isSharedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedCredentialsTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedCredentialsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      encryptedData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_data'],
      )!,
      dataIv: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_iv'],
      )!,
      encryptedCredentialKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_credential_key'],
      )!,
      expiryDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expiry_date'],
      ),
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      folderName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_name'],
      ),
      credentialGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credential_group_id'],
      ),
      credentialGroupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credential_group_name'],
      ),
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      ownerUsername: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_username'],
      )!,
      isShared: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_shared'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      )!,
    );
  }

  @override
  $CachedCredentialsTableTable createAlias(String alias) {
    return $CachedCredentialsTableTable(attachedDatabase, alias);
  }
}

class CachedCredentialsTableData extends DataClass
    implements Insertable<CachedCredentialsTableData> {
  final String id;
  final String type;
  final String encryptedData;
  final String dataIv;
  final String encryptedCredentialKey;
  final DateTime? expiryDate;
  final String? folderId;
  final String? folderName;
  final String? credentialGroupId;
  final String? credentialGroupName;
  final String ownerId;
  final String ownerUsername;
  final bool isShared;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String tagsJson;
  const CachedCredentialsTableData({
    required this.id,
    required this.type,
    required this.encryptedData,
    required this.dataIv,
    required this.encryptedCredentialKey,
    this.expiryDate,
    this.folderId,
    this.folderName,
    this.credentialGroupId,
    this.credentialGroupName,
    required this.ownerId,
    required this.ownerUsername,
    required this.isShared,
    required this.createdAt,
    required this.updatedAt,
    required this.tagsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['encrypted_data'] = Variable<String>(encryptedData);
    map['data_iv'] = Variable<String>(dataIv);
    map['encrypted_credential_key'] = Variable<String>(encryptedCredentialKey);
    if (!nullToAbsent || expiryDate != null) {
      map['expiry_date'] = Variable<DateTime>(expiryDate);
    }
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    if (!nullToAbsent || folderName != null) {
      map['folder_name'] = Variable<String>(folderName);
    }
    if (!nullToAbsent || credentialGroupId != null) {
      map['credential_group_id'] = Variable<String>(credentialGroupId);
    }
    if (!nullToAbsent || credentialGroupName != null) {
      map['credential_group_name'] = Variable<String>(credentialGroupName);
    }
    map['owner_id'] = Variable<String>(ownerId);
    map['owner_username'] = Variable<String>(ownerUsername);
    map['is_shared'] = Variable<bool>(isShared);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['tags_json'] = Variable<String>(tagsJson);
    return map;
  }

  CachedCredentialsTableCompanion toCompanion(bool nullToAbsent) {
    return CachedCredentialsTableCompanion(
      id: Value(id),
      type: Value(type),
      encryptedData: Value(encryptedData),
      dataIv: Value(dataIv),
      encryptedCredentialKey: Value(encryptedCredentialKey),
      expiryDate: expiryDate == null && nullToAbsent
          ? const Value.absent()
          : Value(expiryDate),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      folderName: folderName == null && nullToAbsent
          ? const Value.absent()
          : Value(folderName),
      credentialGroupId: credentialGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(credentialGroupId),
      credentialGroupName: credentialGroupName == null && nullToAbsent
          ? const Value.absent()
          : Value(credentialGroupName),
      ownerId: Value(ownerId),
      ownerUsername: Value(ownerUsername),
      isShared: Value(isShared),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      tagsJson: Value(tagsJson),
    );
  }

  factory CachedCredentialsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedCredentialsTableData(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      encryptedData: serializer.fromJson<String>(json['encryptedData']),
      dataIv: serializer.fromJson<String>(json['dataIv']),
      encryptedCredentialKey: serializer.fromJson<String>(
        json['encryptedCredentialKey'],
      ),
      expiryDate: serializer.fromJson<DateTime?>(json['expiryDate']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      folderName: serializer.fromJson<String?>(json['folderName']),
      credentialGroupId: serializer.fromJson<String?>(
        json['credentialGroupId'],
      ),
      credentialGroupName: serializer.fromJson<String?>(
        json['credentialGroupName'],
      ),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      ownerUsername: serializer.fromJson<String>(json['ownerUsername']),
      isShared: serializer.fromJson<bool>(json['isShared']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'encryptedData': serializer.toJson<String>(encryptedData),
      'dataIv': serializer.toJson<String>(dataIv),
      'encryptedCredentialKey': serializer.toJson<String>(
        encryptedCredentialKey,
      ),
      'expiryDate': serializer.toJson<DateTime?>(expiryDate),
      'folderId': serializer.toJson<String?>(folderId),
      'folderName': serializer.toJson<String?>(folderName),
      'credentialGroupId': serializer.toJson<String?>(credentialGroupId),
      'credentialGroupName': serializer.toJson<String?>(credentialGroupName),
      'ownerId': serializer.toJson<String>(ownerId),
      'ownerUsername': serializer.toJson<String>(ownerUsername),
      'isShared': serializer.toJson<bool>(isShared),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'tagsJson': serializer.toJson<String>(tagsJson),
    };
  }

  CachedCredentialsTableData copyWith({
    String? id,
    String? type,
    String? encryptedData,
    String? dataIv,
    String? encryptedCredentialKey,
    Value<DateTime?> expiryDate = const Value.absent(),
    Value<String?> folderId = const Value.absent(),
    Value<String?> folderName = const Value.absent(),
    Value<String?> credentialGroupId = const Value.absent(),
    Value<String?> credentialGroupName = const Value.absent(),
    String? ownerId,
    String? ownerUsername,
    bool? isShared,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? tagsJson,
  }) => CachedCredentialsTableData(
    id: id ?? this.id,
    type: type ?? this.type,
    encryptedData: encryptedData ?? this.encryptedData,
    dataIv: dataIv ?? this.dataIv,
    encryptedCredentialKey:
        encryptedCredentialKey ?? this.encryptedCredentialKey,
    expiryDate: expiryDate.present ? expiryDate.value : this.expiryDate,
    folderId: folderId.present ? folderId.value : this.folderId,
    folderName: folderName.present ? folderName.value : this.folderName,
    credentialGroupId: credentialGroupId.present
        ? credentialGroupId.value
        : this.credentialGroupId,
    credentialGroupName: credentialGroupName.present
        ? credentialGroupName.value
        : this.credentialGroupName,
    ownerId: ownerId ?? this.ownerId,
    ownerUsername: ownerUsername ?? this.ownerUsername,
    isShared: isShared ?? this.isShared,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    tagsJson: tagsJson ?? this.tagsJson,
  );
  CachedCredentialsTableData copyWithCompanion(
    CachedCredentialsTableCompanion data,
  ) {
    return CachedCredentialsTableData(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      encryptedData: data.encryptedData.present
          ? data.encryptedData.value
          : this.encryptedData,
      dataIv: data.dataIv.present ? data.dataIv.value : this.dataIv,
      encryptedCredentialKey: data.encryptedCredentialKey.present
          ? data.encryptedCredentialKey.value
          : this.encryptedCredentialKey,
      expiryDate: data.expiryDate.present
          ? data.expiryDate.value
          : this.expiryDate,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      folderName: data.folderName.present
          ? data.folderName.value
          : this.folderName,
      credentialGroupId: data.credentialGroupId.present
          ? data.credentialGroupId.value
          : this.credentialGroupId,
      credentialGroupName: data.credentialGroupName.present
          ? data.credentialGroupName.value
          : this.credentialGroupName,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      ownerUsername: data.ownerUsername.present
          ? data.ownerUsername.value
          : this.ownerUsername,
      isShared: data.isShared.present ? data.isShared.value : this.isShared,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedCredentialsTableData(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('encryptedData: $encryptedData, ')
          ..write('dataIv: $dataIv, ')
          ..write('encryptedCredentialKey: $encryptedCredentialKey, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('folderId: $folderId, ')
          ..write('folderName: $folderName, ')
          ..write('credentialGroupId: $credentialGroupId, ')
          ..write('credentialGroupName: $credentialGroupName, ')
          ..write('ownerId: $ownerId, ')
          ..write('ownerUsername: $ownerUsername, ')
          ..write('isShared: $isShared, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('tagsJson: $tagsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    encryptedData,
    dataIv,
    encryptedCredentialKey,
    expiryDate,
    folderId,
    folderName,
    credentialGroupId,
    credentialGroupName,
    ownerId,
    ownerUsername,
    isShared,
    createdAt,
    updatedAt,
    tagsJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedCredentialsTableData &&
          other.id == this.id &&
          other.type == this.type &&
          other.encryptedData == this.encryptedData &&
          other.dataIv == this.dataIv &&
          other.encryptedCredentialKey == this.encryptedCredentialKey &&
          other.expiryDate == this.expiryDate &&
          other.folderId == this.folderId &&
          other.folderName == this.folderName &&
          other.credentialGroupId == this.credentialGroupId &&
          other.credentialGroupName == this.credentialGroupName &&
          other.ownerId == this.ownerId &&
          other.ownerUsername == this.ownerUsername &&
          other.isShared == this.isShared &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.tagsJson == this.tagsJson);
}

class CachedCredentialsTableCompanion
    extends UpdateCompanion<CachedCredentialsTableData> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> encryptedData;
  final Value<String> dataIv;
  final Value<String> encryptedCredentialKey;
  final Value<DateTime?> expiryDate;
  final Value<String?> folderId;
  final Value<String?> folderName;
  final Value<String?> credentialGroupId;
  final Value<String?> credentialGroupName;
  final Value<String> ownerId;
  final Value<String> ownerUsername;
  final Value<bool> isShared;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> tagsJson;
  final Value<int> rowid;
  const CachedCredentialsTableCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.encryptedData = const Value.absent(),
    this.dataIv = const Value.absent(),
    this.encryptedCredentialKey = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.folderId = const Value.absent(),
    this.folderName = const Value.absent(),
    this.credentialGroupId = const Value.absent(),
    this.credentialGroupName = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.ownerUsername = const Value.absent(),
    this.isShared = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedCredentialsTableCompanion.insert({
    required String id,
    required String type,
    required String encryptedData,
    required String dataIv,
    required String encryptedCredentialKey,
    this.expiryDate = const Value.absent(),
    this.folderId = const Value.absent(),
    this.folderName = const Value.absent(),
    this.credentialGroupId = const Value.absent(),
    this.credentialGroupName = const Value.absent(),
    required String ownerId,
    required String ownerUsername,
    this.isShared = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.tagsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       encryptedData = Value(encryptedData),
       dataIv = Value(dataIv),
       encryptedCredentialKey = Value(encryptedCredentialKey),
       ownerId = Value(ownerId),
       ownerUsername = Value(ownerUsername),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<CachedCredentialsTableData> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? encryptedData,
    Expression<String>? dataIv,
    Expression<String>? encryptedCredentialKey,
    Expression<DateTime>? expiryDate,
    Expression<String>? folderId,
    Expression<String>? folderName,
    Expression<String>? credentialGroupId,
    Expression<String>? credentialGroupName,
    Expression<String>? ownerId,
    Expression<String>? ownerUsername,
    Expression<bool>? isShared,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? tagsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (encryptedData != null) 'encrypted_data': encryptedData,
      if (dataIv != null) 'data_iv': dataIv,
      if (encryptedCredentialKey != null)
        'encrypted_credential_key': encryptedCredentialKey,
      if (expiryDate != null) 'expiry_date': expiryDate,
      if (folderId != null) 'folder_id': folderId,
      if (folderName != null) 'folder_name': folderName,
      if (credentialGroupId != null) 'credential_group_id': credentialGroupId,
      if (credentialGroupName != null)
        'credential_group_name': credentialGroupName,
      if (ownerId != null) 'owner_id': ownerId,
      if (ownerUsername != null) 'owner_username': ownerUsername,
      if (isShared != null) 'is_shared': isShared,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedCredentialsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? encryptedData,
    Value<String>? dataIv,
    Value<String>? encryptedCredentialKey,
    Value<DateTime?>? expiryDate,
    Value<String?>? folderId,
    Value<String?>? folderName,
    Value<String?>? credentialGroupId,
    Value<String?>? credentialGroupName,
    Value<String>? ownerId,
    Value<String>? ownerUsername,
    Value<bool>? isShared,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? tagsJson,
    Value<int>? rowid,
  }) {
    return CachedCredentialsTableCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      encryptedData: encryptedData ?? this.encryptedData,
      dataIv: dataIv ?? this.dataIv,
      encryptedCredentialKey:
          encryptedCredentialKey ?? this.encryptedCredentialKey,
      expiryDate: expiryDate ?? this.expiryDate,
      folderId: folderId ?? this.folderId,
      folderName: folderName ?? this.folderName,
      credentialGroupId: credentialGroupId ?? this.credentialGroupId,
      credentialGroupName: credentialGroupName ?? this.credentialGroupName,
      ownerId: ownerId ?? this.ownerId,
      ownerUsername: ownerUsername ?? this.ownerUsername,
      isShared: isShared ?? this.isShared,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tagsJson: tagsJson ?? this.tagsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (encryptedData.present) {
      map['encrypted_data'] = Variable<String>(encryptedData.value);
    }
    if (dataIv.present) {
      map['data_iv'] = Variable<String>(dataIv.value);
    }
    if (encryptedCredentialKey.present) {
      map['encrypted_credential_key'] = Variable<String>(
        encryptedCredentialKey.value,
      );
    }
    if (expiryDate.present) {
      map['expiry_date'] = Variable<DateTime>(expiryDate.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (folderName.present) {
      map['folder_name'] = Variable<String>(folderName.value);
    }
    if (credentialGroupId.present) {
      map['credential_group_id'] = Variable<String>(credentialGroupId.value);
    }
    if (credentialGroupName.present) {
      map['credential_group_name'] = Variable<String>(
        credentialGroupName.value,
      );
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (ownerUsername.present) {
      map['owner_username'] = Variable<String>(ownerUsername.value);
    }
    if (isShared.present) {
      map['is_shared'] = Variable<bool>(isShared.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedCredentialsTableCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('encryptedData: $encryptedData, ')
          ..write('dataIv: $dataIv, ')
          ..write('encryptedCredentialKey: $encryptedCredentialKey, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('folderId: $folderId, ')
          ..write('folderName: $folderName, ')
          ..write('credentialGroupId: $credentialGroupId, ')
          ..write('credentialGroupName: $credentialGroupName, ')
          ..write('ownerId: $ownerId, ')
          ..write('ownerUsername: $ownerUsername, ')
          ..write('isShared: $isShared, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedCredentialGroupsTableTable extends CachedCredentialGroupsTable
    with
        TableInfo<
          $CachedCredentialGroupsTableTable,
          CachedCredentialGroupsTableData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedCredentialGroupsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _teamGroupIdMeta = const VerificationMeta(
    'teamGroupId',
  );
  @override
  late final GeneratedColumn<String> teamGroupId = GeneratedColumn<String>(
    'team_group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _credentialCountMeta = const VerificationMeta(
    'credentialCount',
  );
  @override
  late final GeneratedColumn<int> credentialCount = GeneratedColumn<int>(
    'credential_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    icon,
    teamGroupId,
    credentialCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_credential_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedCredentialGroupsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('team_group_id')) {
      context.handle(
        _teamGroupIdMeta,
        teamGroupId.isAcceptableOrUnknown(
          data['team_group_id']!,
          _teamGroupIdMeta,
        ),
      );
    }
    if (data.containsKey('credential_count')) {
      context.handle(
        _credentialCountMeta,
        credentialCount.isAcceptableOrUnknown(
          data['credential_count']!,
          _credentialCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedCredentialGroupsTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedCredentialGroupsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      teamGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}team_group_id'],
      ),
      credentialCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}credential_count'],
      )!,
    );
  }

  @override
  $CachedCredentialGroupsTableTable createAlias(String alias) {
    return $CachedCredentialGroupsTableTable(attachedDatabase, alias);
  }
}

class CachedCredentialGroupsTableData extends DataClass
    implements Insertable<CachedCredentialGroupsTableData> {
  final String id;
  final String name;
  final String icon;
  final String? teamGroupId;
  final int credentialCount;
  const CachedCredentialGroupsTableData({
    required this.id,
    required this.name,
    required this.icon,
    this.teamGroupId,
    required this.credentialCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['icon'] = Variable<String>(icon);
    if (!nullToAbsent || teamGroupId != null) {
      map['team_group_id'] = Variable<String>(teamGroupId);
    }
    map['credential_count'] = Variable<int>(credentialCount);
    return map;
  }

  CachedCredentialGroupsTableCompanion toCompanion(bool nullToAbsent) {
    return CachedCredentialGroupsTableCompanion(
      id: Value(id),
      name: Value(name),
      icon: Value(icon),
      teamGroupId: teamGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(teamGroupId),
      credentialCount: Value(credentialCount),
    );
  }

  factory CachedCredentialGroupsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedCredentialGroupsTableData(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      icon: serializer.fromJson<String>(json['icon']),
      teamGroupId: serializer.fromJson<String?>(json['teamGroupId']),
      credentialCount: serializer.fromJson<int>(json['credentialCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'icon': serializer.toJson<String>(icon),
      'teamGroupId': serializer.toJson<String?>(teamGroupId),
      'credentialCount': serializer.toJson<int>(credentialCount),
    };
  }

  CachedCredentialGroupsTableData copyWith({
    String? id,
    String? name,
    String? icon,
    Value<String?> teamGroupId = const Value.absent(),
    int? credentialCount,
  }) => CachedCredentialGroupsTableData(
    id: id ?? this.id,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    teamGroupId: teamGroupId.present ? teamGroupId.value : this.teamGroupId,
    credentialCount: credentialCount ?? this.credentialCount,
  );
  CachedCredentialGroupsTableData copyWithCompanion(
    CachedCredentialGroupsTableCompanion data,
  ) {
    return CachedCredentialGroupsTableData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      icon: data.icon.present ? data.icon.value : this.icon,
      teamGroupId: data.teamGroupId.present
          ? data.teamGroupId.value
          : this.teamGroupId,
      credentialCount: data.credentialCount.present
          ? data.credentialCount.value
          : this.credentialCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedCredentialGroupsTableData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('teamGroupId: $teamGroupId, ')
          ..write('credentialCount: $credentialCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, icon, teamGroupId, credentialCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedCredentialGroupsTableData &&
          other.id == this.id &&
          other.name == this.name &&
          other.icon == this.icon &&
          other.teamGroupId == this.teamGroupId &&
          other.credentialCount == this.credentialCount);
}

class CachedCredentialGroupsTableCompanion
    extends UpdateCompanion<CachedCredentialGroupsTableData> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> icon;
  final Value<String?> teamGroupId;
  final Value<int> credentialCount;
  final Value<int> rowid;
  const CachedCredentialGroupsTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.icon = const Value.absent(),
    this.teamGroupId = const Value.absent(),
    this.credentialCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedCredentialGroupsTableCompanion.insert({
    required String id,
    required String name,
    required String icon,
    this.teamGroupId = const Value.absent(),
    this.credentialCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       icon = Value(icon);
  static Insertable<CachedCredentialGroupsTableData> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? icon,
    Expression<String>? teamGroupId,
    Expression<int>? credentialCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (teamGroupId != null) 'team_group_id': teamGroupId,
      if (credentialCount != null) 'credential_count': credentialCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedCredentialGroupsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? icon,
    Value<String?>? teamGroupId,
    Value<int>? credentialCount,
    Value<int>? rowid,
  }) {
    return CachedCredentialGroupsTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      teamGroupId: teamGroupId ?? this.teamGroupId,
      credentialCount: credentialCount ?? this.credentialCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (teamGroupId.present) {
      map['team_group_id'] = Variable<String>(teamGroupId.value);
    }
    if (credentialCount.present) {
      map['credential_count'] = Variable<int>(credentialCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedCredentialGroupsTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('teamGroupId: $teamGroupId, ')
          ..write('credentialCount: $credentialCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingMutationsTableTable extends PendingMutationsTable
    with TableInfo<$PendingMutationsTableTable, PendingMutationsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingMutationsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('credential'),
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('update'),
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUpdatedAtMeta = const VerificationMeta(
    'baseUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> baseUpdatedAt =
      GeneratedColumn<DateTime>(
        'base_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityType,
    entityId,
    operation,
    payloadJson,
    baseUpdatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_mutations';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingMutationsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('base_updated_at')) {
      context.handle(
        _baseUpdatedAtMeta,
        baseUpdatedAt.isAcceptableOrUnknown(
          data['base_updated_at']!,
          _baseUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baseUpdatedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingMutationsTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingMutationsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      baseUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}base_updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PendingMutationsTableTable createAlias(String alias) {
    return $PendingMutationsTableTable(attachedDatabase, alias);
  }
}

class PendingMutationsTableData extends DataClass
    implements Insertable<PendingMutationsTableData> {
  final int id;
  final String entityType;
  final String entityId;
  final String operation;
  final String payloadJson;
  final DateTime baseUpdatedAt;
  final DateTime createdAt;
  const PendingMutationsTableData({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
    required this.baseUpdatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['operation'] = Variable<String>(operation);
    map['payload_json'] = Variable<String>(payloadJson);
    map['base_updated_at'] = Variable<DateTime>(baseUpdatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingMutationsTableCompanion toCompanion(bool nullToAbsent) {
    return PendingMutationsTableCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: Value(operation),
      payloadJson: Value(payloadJson),
      baseUpdatedAt: Value(baseUpdatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory PendingMutationsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingMutationsTableData(
      id: serializer.fromJson<int>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      operation: serializer.fromJson<String>(json['operation']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      baseUpdatedAt: serializer.fromJson<DateTime>(json['baseUpdatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'operation': serializer.toJson<String>(operation),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'baseUpdatedAt': serializer.toJson<DateTime>(baseUpdatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingMutationsTableData copyWith({
    int? id,
    String? entityType,
    String? entityId,
    String? operation,
    String? payloadJson,
    DateTime? baseUpdatedAt,
    DateTime? createdAt,
  }) => PendingMutationsTableData(
    id: id ?? this.id,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    operation: operation ?? this.operation,
    payloadJson: payloadJson ?? this.payloadJson,
    baseUpdatedAt: baseUpdatedAt ?? this.baseUpdatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  PendingMutationsTableData copyWithCompanion(
    PendingMutationsTableCompanion data,
  ) {
    return PendingMutationsTableData(
      id: data.id.present ? data.id.value : this.id,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      baseUpdatedAt: data.baseUpdatedAt.present
          ? data.baseUpdatedAt.value
          : this.baseUpdatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingMutationsTableData(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('baseUpdatedAt: $baseUpdatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityType,
    entityId,
    operation,
    payloadJson,
    baseUpdatedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingMutationsTableData &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.operation == this.operation &&
          other.payloadJson == this.payloadJson &&
          other.baseUpdatedAt == this.baseUpdatedAt &&
          other.createdAt == this.createdAt);
}

class PendingMutationsTableCompanion
    extends UpdateCompanion<PendingMutationsTableData> {
  final Value<int> id;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> operation;
  final Value<String> payloadJson;
  final Value<DateTime> baseUpdatedAt;
  final Value<DateTime> createdAt;
  const PendingMutationsTableCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.baseUpdatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PendingMutationsTableCompanion.insert({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    required String entityId,
    this.operation = const Value.absent(),
    required String payloadJson,
    required DateTime baseUpdatedAt,
    this.createdAt = const Value.absent(),
  }) : entityId = Value(entityId),
       payloadJson = Value(payloadJson),
       baseUpdatedAt = Value(baseUpdatedAt);
  static Insertable<PendingMutationsTableData> custom({
    Expression<int>? id,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? operation,
    Expression<String>? payloadJson,
    Expression<DateTime>? baseUpdatedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (operation != null) 'operation': operation,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (baseUpdatedAt != null) 'base_updated_at': baseUpdatedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PendingMutationsTableCompanion copyWith({
    Value<int>? id,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? operation,
    Value<String>? payloadJson,
    Value<DateTime>? baseUpdatedAt,
    Value<DateTime>? createdAt,
  }) {
    return PendingMutationsTableCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payloadJson: payloadJson ?? this.payloadJson,
      baseUpdatedAt: baseUpdatedAt ?? this.baseUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (baseUpdatedAt.present) {
      map['base_updated_at'] = Variable<DateTime>(baseUpdatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingMutationsTableCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('baseUpdatedAt: $baseUpdatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ServerConfigTableTable serverConfigTable =
      $ServerConfigTableTable(this);
  late final $CachedCredentialsTableTable cachedCredentialsTable =
      $CachedCredentialsTableTable(this);
  late final $CachedCredentialGroupsTableTable cachedCredentialGroupsTable =
      $CachedCredentialGroupsTableTable(this);
  late final $PendingMutationsTableTable pendingMutationsTable =
      $PendingMutationsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    serverConfigTable,
    cachedCredentialsTable,
    cachedCredentialGroupsTable,
    pendingMutationsTable,
  ];
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
typedef $$CachedCredentialsTableTableCreateCompanionBuilder =
    CachedCredentialsTableCompanion Function({
      required String id,
      required String type,
      required String encryptedData,
      required String dataIv,
      required String encryptedCredentialKey,
      Value<DateTime?> expiryDate,
      Value<String?> folderId,
      Value<String?> folderName,
      Value<String?> credentialGroupId,
      Value<String?> credentialGroupName,
      required String ownerId,
      required String ownerUsername,
      Value<bool> isShared,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<String> tagsJson,
      Value<int> rowid,
    });
typedef $$CachedCredentialsTableTableUpdateCompanionBuilder =
    CachedCredentialsTableCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String> encryptedData,
      Value<String> dataIv,
      Value<String> encryptedCredentialKey,
      Value<DateTime?> expiryDate,
      Value<String?> folderId,
      Value<String?> folderName,
      Value<String?> credentialGroupId,
      Value<String?> credentialGroupName,
      Value<String> ownerId,
      Value<String> ownerUsername,
      Value<bool> isShared,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> tagsJson,
      Value<int> rowid,
    });

class $$CachedCredentialsTableTableFilterComposer
    extends Composer<_$AppDatabase, $CachedCredentialsTableTable> {
  $$CachedCredentialsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedData => $composableBuilder(
    column: $table.encryptedData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataIv => $composableBuilder(
    column: $table.dataIv,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedCredentialKey => $composableBuilder(
    column: $table.encryptedCredentialKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderName => $composableBuilder(
    column: $table.folderName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get credentialGroupId => $composableBuilder(
    column: $table.credentialGroupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get credentialGroupName => $composableBuilder(
    column: $table.credentialGroupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerUsername => $composableBuilder(
    column: $table.ownerUsername,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedCredentialsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedCredentialsTableTable> {
  $$CachedCredentialsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedData => $composableBuilder(
    column: $table.encryptedData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataIv => $composableBuilder(
    column: $table.dataIv,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedCredentialKey => $composableBuilder(
    column: $table.encryptedCredentialKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderName => $composableBuilder(
    column: $table.folderName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get credentialGroupId => $composableBuilder(
    column: $table.credentialGroupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get credentialGroupName => $composableBuilder(
    column: $table.credentialGroupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerUsername => $composableBuilder(
    column: $table.ownerUsername,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedCredentialsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedCredentialsTableTable> {
  $$CachedCredentialsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get encryptedData => $composableBuilder(
    column: $table.encryptedData,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dataIv =>
      $composableBuilder(column: $table.dataIv, builder: (column) => column);

  GeneratedColumn<String> get encryptedCredentialKey => $composableBuilder(
    column: $table.encryptedCredentialKey,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<String> get folderName => $composableBuilder(
    column: $table.folderName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get credentialGroupId => $composableBuilder(
    column: $table.credentialGroupId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get credentialGroupName => $composableBuilder(
    column: $table.credentialGroupName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get ownerUsername => $composableBuilder(
    column: $table.ownerUsername,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isShared =>
      $composableBuilder(column: $table.isShared, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);
}

class $$CachedCredentialsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedCredentialsTableTable,
          CachedCredentialsTableData,
          $$CachedCredentialsTableTableFilterComposer,
          $$CachedCredentialsTableTableOrderingComposer,
          $$CachedCredentialsTableTableAnnotationComposer,
          $$CachedCredentialsTableTableCreateCompanionBuilder,
          $$CachedCredentialsTableTableUpdateCompanionBuilder,
          (
            CachedCredentialsTableData,
            BaseReferences<
              _$AppDatabase,
              $CachedCredentialsTableTable,
              CachedCredentialsTableData
            >,
          ),
          CachedCredentialsTableData,
          PrefetchHooks Function()
        > {
  $$CachedCredentialsTableTableTableManager(
    _$AppDatabase db,
    $CachedCredentialsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedCredentialsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CachedCredentialsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachedCredentialsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> encryptedData = const Value.absent(),
                Value<String> dataIv = const Value.absent(),
                Value<String> encryptedCredentialKey = const Value.absent(),
                Value<DateTime?> expiryDate = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<String?> folderName = const Value.absent(),
                Value<String?> credentialGroupId = const Value.absent(),
                Value<String?> credentialGroupName = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> ownerUsername = const Value.absent(),
                Value<bool> isShared = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedCredentialsTableCompanion(
                id: id,
                type: type,
                encryptedData: encryptedData,
                dataIv: dataIv,
                encryptedCredentialKey: encryptedCredentialKey,
                expiryDate: expiryDate,
                folderId: folderId,
                folderName: folderName,
                credentialGroupId: credentialGroupId,
                credentialGroupName: credentialGroupName,
                ownerId: ownerId,
                ownerUsername: ownerUsername,
                isShared: isShared,
                createdAt: createdAt,
                updatedAt: updatedAt,
                tagsJson: tagsJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required String encryptedData,
                required String dataIv,
                required String encryptedCredentialKey,
                Value<DateTime?> expiryDate = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<String?> folderName = const Value.absent(),
                Value<String?> credentialGroupId = const Value.absent(),
                Value<String?> credentialGroupName = const Value.absent(),
                required String ownerId,
                required String ownerUsername,
                Value<bool> isShared = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<String> tagsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedCredentialsTableCompanion.insert(
                id: id,
                type: type,
                encryptedData: encryptedData,
                dataIv: dataIv,
                encryptedCredentialKey: encryptedCredentialKey,
                expiryDate: expiryDate,
                folderId: folderId,
                folderName: folderName,
                credentialGroupId: credentialGroupId,
                credentialGroupName: credentialGroupName,
                ownerId: ownerId,
                ownerUsername: ownerUsername,
                isShared: isShared,
                createdAt: createdAt,
                updatedAt: updatedAt,
                tagsJson: tagsJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedCredentialsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedCredentialsTableTable,
      CachedCredentialsTableData,
      $$CachedCredentialsTableTableFilterComposer,
      $$CachedCredentialsTableTableOrderingComposer,
      $$CachedCredentialsTableTableAnnotationComposer,
      $$CachedCredentialsTableTableCreateCompanionBuilder,
      $$CachedCredentialsTableTableUpdateCompanionBuilder,
      (
        CachedCredentialsTableData,
        BaseReferences<
          _$AppDatabase,
          $CachedCredentialsTableTable,
          CachedCredentialsTableData
        >,
      ),
      CachedCredentialsTableData,
      PrefetchHooks Function()
    >;
typedef $$CachedCredentialGroupsTableTableCreateCompanionBuilder =
    CachedCredentialGroupsTableCompanion Function({
      required String id,
      required String name,
      required String icon,
      Value<String?> teamGroupId,
      Value<int> credentialCount,
      Value<int> rowid,
    });
typedef $$CachedCredentialGroupsTableTableUpdateCompanionBuilder =
    CachedCredentialGroupsTableCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> icon,
      Value<String?> teamGroupId,
      Value<int> credentialCount,
      Value<int> rowid,
    });

class $$CachedCredentialGroupsTableTableFilterComposer
    extends Composer<_$AppDatabase, $CachedCredentialGroupsTableTable> {
  $$CachedCredentialGroupsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get teamGroupId => $composableBuilder(
    column: $table.teamGroupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get credentialCount => $composableBuilder(
    column: $table.credentialCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedCredentialGroupsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedCredentialGroupsTableTable> {
  $$CachedCredentialGroupsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get teamGroupId => $composableBuilder(
    column: $table.teamGroupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get credentialCount => $composableBuilder(
    column: $table.credentialCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedCredentialGroupsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedCredentialGroupsTableTable> {
  $$CachedCredentialGroupsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get teamGroupId => $composableBuilder(
    column: $table.teamGroupId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get credentialCount => $composableBuilder(
    column: $table.credentialCount,
    builder: (column) => column,
  );
}

class $$CachedCredentialGroupsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedCredentialGroupsTableTable,
          CachedCredentialGroupsTableData,
          $$CachedCredentialGroupsTableTableFilterComposer,
          $$CachedCredentialGroupsTableTableOrderingComposer,
          $$CachedCredentialGroupsTableTableAnnotationComposer,
          $$CachedCredentialGroupsTableTableCreateCompanionBuilder,
          $$CachedCredentialGroupsTableTableUpdateCompanionBuilder,
          (
            CachedCredentialGroupsTableData,
            BaseReferences<
              _$AppDatabase,
              $CachedCredentialGroupsTableTable,
              CachedCredentialGroupsTableData
            >,
          ),
          CachedCredentialGroupsTableData,
          PrefetchHooks Function()
        > {
  $$CachedCredentialGroupsTableTableTableManager(
    _$AppDatabase db,
    $CachedCredentialGroupsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedCredentialGroupsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CachedCredentialGroupsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachedCredentialGroupsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<String?> teamGroupId = const Value.absent(),
                Value<int> credentialCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedCredentialGroupsTableCompanion(
                id: id,
                name: name,
                icon: icon,
                teamGroupId: teamGroupId,
                credentialCount: credentialCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String icon,
                Value<String?> teamGroupId = const Value.absent(),
                Value<int> credentialCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedCredentialGroupsTableCompanion.insert(
                id: id,
                name: name,
                icon: icon,
                teamGroupId: teamGroupId,
                credentialCount: credentialCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedCredentialGroupsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedCredentialGroupsTableTable,
      CachedCredentialGroupsTableData,
      $$CachedCredentialGroupsTableTableFilterComposer,
      $$CachedCredentialGroupsTableTableOrderingComposer,
      $$CachedCredentialGroupsTableTableAnnotationComposer,
      $$CachedCredentialGroupsTableTableCreateCompanionBuilder,
      $$CachedCredentialGroupsTableTableUpdateCompanionBuilder,
      (
        CachedCredentialGroupsTableData,
        BaseReferences<
          _$AppDatabase,
          $CachedCredentialGroupsTableTable,
          CachedCredentialGroupsTableData
        >,
      ),
      CachedCredentialGroupsTableData,
      PrefetchHooks Function()
    >;
typedef $$PendingMutationsTableTableCreateCompanionBuilder =
    PendingMutationsTableCompanion Function({
      Value<int> id,
      Value<String> entityType,
      required String entityId,
      Value<String> operation,
      required String payloadJson,
      required DateTime baseUpdatedAt,
      Value<DateTime> createdAt,
    });
typedef $$PendingMutationsTableTableUpdateCompanionBuilder =
    PendingMutationsTableCompanion Function({
      Value<int> id,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> operation,
      Value<String> payloadJson,
      Value<DateTime> baseUpdatedAt,
      Value<DateTime> createdAt,
    });

class $$PendingMutationsTableTableFilterComposer
    extends Composer<_$AppDatabase, $PendingMutationsTableTable> {
  $$PendingMutationsTableTableFilterComposer({
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

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get baseUpdatedAt => $composableBuilder(
    column: $table.baseUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingMutationsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingMutationsTableTable> {
  $$PendingMutationsTableTableOrderingComposer({
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

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get baseUpdatedAt => $composableBuilder(
    column: $table.baseUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingMutationsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingMutationsTableTable> {
  $$PendingMutationsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get baseUpdatedAt => $composableBuilder(
    column: $table.baseUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PendingMutationsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingMutationsTableTable,
          PendingMutationsTableData,
          $$PendingMutationsTableTableFilterComposer,
          $$PendingMutationsTableTableOrderingComposer,
          $$PendingMutationsTableTableAnnotationComposer,
          $$PendingMutationsTableTableCreateCompanionBuilder,
          $$PendingMutationsTableTableUpdateCompanionBuilder,
          (
            PendingMutationsTableData,
            BaseReferences<
              _$AppDatabase,
              $PendingMutationsTableTable,
              PendingMutationsTableData
            >,
          ),
          PendingMutationsTableData,
          PrefetchHooks Function()
        > {
  $$PendingMutationsTableTableTableManager(
    _$AppDatabase db,
    $PendingMutationsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingMutationsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PendingMutationsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PendingMutationsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> baseUpdatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PendingMutationsTableCompanion(
                id: id,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                payloadJson: payloadJson,
                baseUpdatedAt: baseUpdatedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                required String entityId,
                Value<String> operation = const Value.absent(),
                required String payloadJson,
                required DateTime baseUpdatedAt,
                Value<DateTime> createdAt = const Value.absent(),
              }) => PendingMutationsTableCompanion.insert(
                id: id,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                payloadJson: payloadJson,
                baseUpdatedAt: baseUpdatedAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingMutationsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingMutationsTableTable,
      PendingMutationsTableData,
      $$PendingMutationsTableTableFilterComposer,
      $$PendingMutationsTableTableOrderingComposer,
      $$PendingMutationsTableTableAnnotationComposer,
      $$PendingMutationsTableTableCreateCompanionBuilder,
      $$PendingMutationsTableTableUpdateCompanionBuilder,
      (
        PendingMutationsTableData,
        BaseReferences<
          _$AppDatabase,
          $PendingMutationsTableTable,
          PendingMutationsTableData
        >,
      ),
      PendingMutationsTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ServerConfigTableTableTableManager get serverConfigTable =>
      $$ServerConfigTableTableTableManager(_db, _db.serverConfigTable);
  $$CachedCredentialsTableTableTableManager get cachedCredentialsTable =>
      $$CachedCredentialsTableTableTableManager(
        _db,
        _db.cachedCredentialsTable,
      );
  $$CachedCredentialGroupsTableTableTableManager
  get cachedCredentialGroupsTable =>
      $$CachedCredentialGroupsTableTableTableManager(
        _db,
        _db.cachedCredentialGroupsTable,
      );
  $$PendingMutationsTableTableTableManager get pendingMutationsTable =>
      $$PendingMutationsTableTableTableManager(_db, _db.pendingMutationsTable);
}
