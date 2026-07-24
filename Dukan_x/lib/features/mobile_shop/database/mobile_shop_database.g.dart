// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mobile_shop_database.dart';

// ignore_for_file: type=lint
class $MobileImeiUnitsTable extends MobileImeiUnits
    with TableInfo<$MobileImeiUnitsTable, MobileImeiUnitEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MobileImeiUnitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _imeiMeta = const VerificationMeta('imei');
  @override
  late final GeneratedColumn<String> imei = GeneratedColumn<String>(
    'imei',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lifecycleStateMeta = const VerificationMeta(
    'lifecycleState',
  );
  @override
  late final GeneratedColumn<String> lifecycleState = GeneratedColumn<String>(
    'lifecycle_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('IN_STOCK'),
  );
  static const VerificationMeta _conditionMeta = const VerificationMeta(
    'condition',
  );
  @override
  late final GeneratedColumn<String> condition = GeneratedColumn<String>(
    'condition',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
    'brand',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _salePricePaiseMeta = const VerificationMeta(
    'salePricePaise',
  );
  @override
  late final GeneratedColumn<int> salePricePaise = GeneratedColumn<int>(
    'sale_price_paise',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _acquisitionCostPaiseMeta =
      const VerificationMeta('acquisitionCostPaise');
  @override
  late final GeneratedColumn<int> acquisitionCostPaise = GeneratedColumn<int>(
    'acquisition_cost_paise',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _warrantyStartDateMeta = const VerificationMeta(
    'warrantyStartDate',
  );
  @override
  late final GeneratedColumn<DateTime> warrantyStartDate =
      GeneratedColumn<DateTime>(
        'warranty_start_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _warrantyEndDateMeta = const VerificationMeta(
    'warrantyEndDate',
  );
  @override
  late final GeneratedColumn<DateTime> warrantyEndDate =
      GeneratedColumn<DateTime>(
        'warranty_end_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _confirmationStatusMeta =
      const VerificationMeta('confirmationStatus');
  @override
  late final GeneratedColumn<String> confirmationStatus =
      GeneratedColumn<String>(
        'confirmation_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('pending'),
      );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dataModelVersionMeta = const VerificationMeta(
    'dataModelVersion',
  );
  @override
  late final GeneratedColumn<int> dataModelVersion = GeneratedColumn<int>(
    'data_model_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    entityId,
    imei,
    version,
    serverVersion,
    lifecycleState,
    condition,
    brand,
    model,
    salePricePaise,
    acquisitionCostPaise,
    warrantyStartDate,
    warrantyEndDate,
    confirmationStatus,
    syncedAt,
    dataModelVersion,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mobile_imei_units';
  @override
  VerificationContext validateIntegrity(
    Insertable<MobileImeiUnitEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('imei')) {
      context.handle(
        _imeiMeta,
        imei.isAcceptableOrUnknown(data['imei']!, _imeiMeta),
      );
    } else if (isInserting) {
      context.missing(_imeiMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    if (data.containsKey('lifecycle_state')) {
      context.handle(
        _lifecycleStateMeta,
        lifecycleState.isAcceptableOrUnknown(
          data['lifecycle_state']!,
          _lifecycleStateMeta,
        ),
      );
    }
    if (data.containsKey('condition')) {
      context.handle(
        _conditionMeta,
        condition.isAcceptableOrUnknown(data['condition']!, _conditionMeta),
      );
    }
    if (data.containsKey('brand')) {
      context.handle(
        _brandMeta,
        brand.isAcceptableOrUnknown(data['brand']!, _brandMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('sale_price_paise')) {
      context.handle(
        _salePricePaiseMeta,
        salePricePaise.isAcceptableOrUnknown(
          data['sale_price_paise']!,
          _salePricePaiseMeta,
        ),
      );
    }
    if (data.containsKey('acquisition_cost_paise')) {
      context.handle(
        _acquisitionCostPaiseMeta,
        acquisitionCostPaise.isAcceptableOrUnknown(
          data['acquisition_cost_paise']!,
          _acquisitionCostPaiseMeta,
        ),
      );
    }
    if (data.containsKey('warranty_start_date')) {
      context.handle(
        _warrantyStartDateMeta,
        warrantyStartDate.isAcceptableOrUnknown(
          data['warranty_start_date']!,
          _warrantyStartDateMeta,
        ),
      );
    }
    if (data.containsKey('warranty_end_date')) {
      context.handle(
        _warrantyEndDateMeta,
        warrantyEndDate.isAcceptableOrUnknown(
          data['warranty_end_date']!,
          _warrantyEndDateMeta,
        ),
      );
    }
    if (data.containsKey('confirmation_status')) {
      context.handle(
        _confirmationStatusMeta,
        confirmationStatus.isAcceptableOrUnknown(
          data['confirmation_status']!,
          _confirmationStatusMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('data_model_version')) {
      context.handle(
        _dataModelVersionMeta,
        dataModelVersion.isAcceptableOrUnknown(
          data['data_model_version']!,
          _dataModelVersionMeta,
        ),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {tenantId, imei},
    {tenantId, entityId},
  ];
  @override
  MobileImeiUnitEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MobileImeiUnitEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      imei: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}imei'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      )!,
      lifecycleState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lifecycle_state'],
      )!,
      condition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}condition'],
      ),
      brand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}brand'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      salePricePaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sale_price_paise'],
      ),
      acquisitionCostPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}acquisition_cost_paise'],
      ),
      warrantyStartDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}warranty_start_date'],
      ),
      warrantyEndDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}warranty_end_date'],
      ),
      confirmationStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confirmation_status'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
      dataModelVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}data_model_version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MobileImeiUnitsTable createAlias(String alias) {
    return $MobileImeiUnitsTable(attachedDatabase, alias);
  }
}

class MobileImeiUnitEntity extends DataClass
    implements Insertable<MobileImeiUnitEntity> {
  /// Local row identifier.
  final String id;

  /// Owning tenant — part of all unique constraints.
  final String tenantId;

  /// Server-assigned entity identifier.
  final String entityId;

  /// Normalized 15-digit IMEI.
  final String imei;

  /// Local optimistic version (incremented on local writes).
  final int version;

  /// Last known server version from the canonical backend.
  final int serverVersion;

  /// Device lifecycle state (IN_STOCK, RESERVED, SALE_PENDING, SOLD,
  /// RETURNED, DEMO, IN_SERVICE, EXCHANGED, DAMAGED, RETIRED).
  final String lifecycleState;

  /// Device condition (new, excellent, good, fair, poor).
  final String? condition;

  /// Device brand.
  final String? brand;

  /// Device model.
  final String? model;

  /// Sale price in integer minor units (paise).
  final int? salePricePaise;

  /// Acquisition cost in integer minor units (paise).
  final int? acquisitionCostPaise;

  /// Warranty start date.
  final DateTime? warrantyStartDate;

  /// Warranty end date.
  final DateTime? warrantyEndDate;

  /// Confirmation status: pending | serverConfirmed | conflict.
  final String confirmationStatus;

  /// Last time this row was synced from the server.
  final DateTime? syncedAt;

  /// Data model version for migration compatibility.
  final int dataModelVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MobileImeiUnitEntity({
    required this.id,
    required this.tenantId,
    required this.entityId,
    required this.imei,
    required this.version,
    required this.serverVersion,
    required this.lifecycleState,
    this.condition,
    this.brand,
    this.model,
    this.salePricePaise,
    this.acquisitionCostPaise,
    this.warrantyStartDate,
    this.warrantyEndDate,
    required this.confirmationStatus,
    this.syncedAt,
    required this.dataModelVersion,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['entity_id'] = Variable<String>(entityId);
    map['imei'] = Variable<String>(imei);
    map['version'] = Variable<int>(version);
    map['server_version'] = Variable<int>(serverVersion);
    map['lifecycle_state'] = Variable<String>(lifecycleState);
    if (!nullToAbsent || condition != null) {
      map['condition'] = Variable<String>(condition);
    }
    if (!nullToAbsent || brand != null) {
      map['brand'] = Variable<String>(brand);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || salePricePaise != null) {
      map['sale_price_paise'] = Variable<int>(salePricePaise);
    }
    if (!nullToAbsent || acquisitionCostPaise != null) {
      map['acquisition_cost_paise'] = Variable<int>(acquisitionCostPaise);
    }
    if (!nullToAbsent || warrantyStartDate != null) {
      map['warranty_start_date'] = Variable<DateTime>(warrantyStartDate);
    }
    if (!nullToAbsent || warrantyEndDate != null) {
      map['warranty_end_date'] = Variable<DateTime>(warrantyEndDate);
    }
    map['confirmation_status'] = Variable<String>(confirmationStatus);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    map['data_model_version'] = Variable<int>(dataModelVersion);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MobileImeiUnitsCompanion toCompanion(bool nullToAbsent) {
    return MobileImeiUnitsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      entityId: Value(entityId),
      imei: Value(imei),
      version: Value(version),
      serverVersion: Value(serverVersion),
      lifecycleState: Value(lifecycleState),
      condition: condition == null && nullToAbsent
          ? const Value.absent()
          : Value(condition),
      brand: brand == null && nullToAbsent
          ? const Value.absent()
          : Value(brand),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
      salePricePaise: salePricePaise == null && nullToAbsent
          ? const Value.absent()
          : Value(salePricePaise),
      acquisitionCostPaise: acquisitionCostPaise == null && nullToAbsent
          ? const Value.absent()
          : Value(acquisitionCostPaise),
      warrantyStartDate: warrantyStartDate == null && nullToAbsent
          ? const Value.absent()
          : Value(warrantyStartDate),
      warrantyEndDate: warrantyEndDate == null && nullToAbsent
          ? const Value.absent()
          : Value(warrantyEndDate),
      confirmationStatus: Value(confirmationStatus),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      dataModelVersion: Value(dataModelVersion),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MobileImeiUnitEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MobileImeiUnitEntity(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      entityId: serializer.fromJson<String>(json['entityId']),
      imei: serializer.fromJson<String>(json['imei']),
      version: serializer.fromJson<int>(json['version']),
      serverVersion: serializer.fromJson<int>(json['serverVersion']),
      lifecycleState: serializer.fromJson<String>(json['lifecycleState']),
      condition: serializer.fromJson<String?>(json['condition']),
      brand: serializer.fromJson<String?>(json['brand']),
      model: serializer.fromJson<String?>(json['model']),
      salePricePaise: serializer.fromJson<int?>(json['salePricePaise']),
      acquisitionCostPaise: serializer.fromJson<int?>(
        json['acquisitionCostPaise'],
      ),
      warrantyStartDate: serializer.fromJson<DateTime?>(
        json['warrantyStartDate'],
      ),
      warrantyEndDate: serializer.fromJson<DateTime?>(json['warrantyEndDate']),
      confirmationStatus: serializer.fromJson<String>(
        json['confirmationStatus'],
      ),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      dataModelVersion: serializer.fromJson<int>(json['dataModelVersion']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'entityId': serializer.toJson<String>(entityId),
      'imei': serializer.toJson<String>(imei),
      'version': serializer.toJson<int>(version),
      'serverVersion': serializer.toJson<int>(serverVersion),
      'lifecycleState': serializer.toJson<String>(lifecycleState),
      'condition': serializer.toJson<String?>(condition),
      'brand': serializer.toJson<String?>(brand),
      'model': serializer.toJson<String?>(model),
      'salePricePaise': serializer.toJson<int?>(salePricePaise),
      'acquisitionCostPaise': serializer.toJson<int?>(acquisitionCostPaise),
      'warrantyStartDate': serializer.toJson<DateTime?>(warrantyStartDate),
      'warrantyEndDate': serializer.toJson<DateTime?>(warrantyEndDate),
      'confirmationStatus': serializer.toJson<String>(confirmationStatus),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'dataModelVersion': serializer.toJson<int>(dataModelVersion),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MobileImeiUnitEntity copyWith({
    String? id,
    String? tenantId,
    String? entityId,
    String? imei,
    int? version,
    int? serverVersion,
    String? lifecycleState,
    Value<String?> condition = const Value.absent(),
    Value<String?> brand = const Value.absent(),
    Value<String?> model = const Value.absent(),
    Value<int?> salePricePaise = const Value.absent(),
    Value<int?> acquisitionCostPaise = const Value.absent(),
    Value<DateTime?> warrantyStartDate = const Value.absent(),
    Value<DateTime?> warrantyEndDate = const Value.absent(),
    String? confirmationStatus,
    Value<DateTime?> syncedAt = const Value.absent(),
    int? dataModelVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MobileImeiUnitEntity(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    entityId: entityId ?? this.entityId,
    imei: imei ?? this.imei,
    version: version ?? this.version,
    serverVersion: serverVersion ?? this.serverVersion,
    lifecycleState: lifecycleState ?? this.lifecycleState,
    condition: condition.present ? condition.value : this.condition,
    brand: brand.present ? brand.value : this.brand,
    model: model.present ? model.value : this.model,
    salePricePaise: salePricePaise.present
        ? salePricePaise.value
        : this.salePricePaise,
    acquisitionCostPaise: acquisitionCostPaise.present
        ? acquisitionCostPaise.value
        : this.acquisitionCostPaise,
    warrantyStartDate: warrantyStartDate.present
        ? warrantyStartDate.value
        : this.warrantyStartDate,
    warrantyEndDate: warrantyEndDate.present
        ? warrantyEndDate.value
        : this.warrantyEndDate,
    confirmationStatus: confirmationStatus ?? this.confirmationStatus,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    dataModelVersion: dataModelVersion ?? this.dataModelVersion,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MobileImeiUnitEntity copyWithCompanion(MobileImeiUnitsCompanion data) {
    return MobileImeiUnitEntity(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      imei: data.imei.present ? data.imei.value : this.imei,
      version: data.version.present ? data.version.value : this.version,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      lifecycleState: data.lifecycleState.present
          ? data.lifecycleState.value
          : this.lifecycleState,
      condition: data.condition.present ? data.condition.value : this.condition,
      brand: data.brand.present ? data.brand.value : this.brand,
      model: data.model.present ? data.model.value : this.model,
      salePricePaise: data.salePricePaise.present
          ? data.salePricePaise.value
          : this.salePricePaise,
      acquisitionCostPaise: data.acquisitionCostPaise.present
          ? data.acquisitionCostPaise.value
          : this.acquisitionCostPaise,
      warrantyStartDate: data.warrantyStartDate.present
          ? data.warrantyStartDate.value
          : this.warrantyStartDate,
      warrantyEndDate: data.warrantyEndDate.present
          ? data.warrantyEndDate.value
          : this.warrantyEndDate,
      confirmationStatus: data.confirmationStatus.present
          ? data.confirmationStatus.value
          : this.confirmationStatus,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      dataModelVersion: data.dataModelVersion.present
          ? data.dataModelVersion.value
          : this.dataModelVersion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MobileImeiUnitEntity(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('entityId: $entityId, ')
          ..write('imei: $imei, ')
          ..write('version: $version, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('lifecycleState: $lifecycleState, ')
          ..write('condition: $condition, ')
          ..write('brand: $brand, ')
          ..write('model: $model, ')
          ..write('salePricePaise: $salePricePaise, ')
          ..write('acquisitionCostPaise: $acquisitionCostPaise, ')
          ..write('warrantyStartDate: $warrantyStartDate, ')
          ..write('warrantyEndDate: $warrantyEndDate, ')
          ..write('confirmationStatus: $confirmationStatus, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('dataModelVersion: $dataModelVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    entityId,
    imei,
    version,
    serverVersion,
    lifecycleState,
    condition,
    brand,
    model,
    salePricePaise,
    acquisitionCostPaise,
    warrantyStartDate,
    warrantyEndDate,
    confirmationStatus,
    syncedAt,
    dataModelVersion,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MobileImeiUnitEntity &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.entityId == this.entityId &&
          other.imei == this.imei &&
          other.version == this.version &&
          other.serverVersion == this.serverVersion &&
          other.lifecycleState == this.lifecycleState &&
          other.condition == this.condition &&
          other.brand == this.brand &&
          other.model == this.model &&
          other.salePricePaise == this.salePricePaise &&
          other.acquisitionCostPaise == this.acquisitionCostPaise &&
          other.warrantyStartDate == this.warrantyStartDate &&
          other.warrantyEndDate == this.warrantyEndDate &&
          other.confirmationStatus == this.confirmationStatus &&
          other.syncedAt == this.syncedAt &&
          other.dataModelVersion == this.dataModelVersion &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MobileImeiUnitsCompanion extends UpdateCompanion<MobileImeiUnitEntity> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> entityId;
  final Value<String> imei;
  final Value<int> version;
  final Value<int> serverVersion;
  final Value<String> lifecycleState;
  final Value<String?> condition;
  final Value<String?> brand;
  final Value<String?> model;
  final Value<int?> salePricePaise;
  final Value<int?> acquisitionCostPaise;
  final Value<DateTime?> warrantyStartDate;
  final Value<DateTime?> warrantyEndDate;
  final Value<String> confirmationStatus;
  final Value<DateTime?> syncedAt;
  final Value<int> dataModelVersion;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MobileImeiUnitsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.entityId = const Value.absent(),
    this.imei = const Value.absent(),
    this.version = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.lifecycleState = const Value.absent(),
    this.condition = const Value.absent(),
    this.brand = const Value.absent(),
    this.model = const Value.absent(),
    this.salePricePaise = const Value.absent(),
    this.acquisitionCostPaise = const Value.absent(),
    this.warrantyStartDate = const Value.absent(),
    this.warrantyEndDate = const Value.absent(),
    this.confirmationStatus = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.dataModelVersion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MobileImeiUnitsCompanion.insert({
    required String id,
    required String tenantId,
    required String entityId,
    required String imei,
    this.version = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.lifecycleState = const Value.absent(),
    this.condition = const Value.absent(),
    this.brand = const Value.absent(),
    this.model = const Value.absent(),
    this.salePricePaise = const Value.absent(),
    this.acquisitionCostPaise = const Value.absent(),
    this.warrantyStartDate = const Value.absent(),
    this.warrantyEndDate = const Value.absent(),
    this.confirmationStatus = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.dataModelVersion = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       entityId = Value(entityId),
       imei = Value(imei),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MobileImeiUnitEntity> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? entityId,
    Expression<String>? imei,
    Expression<int>? version,
    Expression<int>? serverVersion,
    Expression<String>? lifecycleState,
    Expression<String>? condition,
    Expression<String>? brand,
    Expression<String>? model,
    Expression<int>? salePricePaise,
    Expression<int>? acquisitionCostPaise,
    Expression<DateTime>? warrantyStartDate,
    Expression<DateTime>? warrantyEndDate,
    Expression<String>? confirmationStatus,
    Expression<DateTime>? syncedAt,
    Expression<int>? dataModelVersion,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (entityId != null) 'entity_id': entityId,
      if (imei != null) 'imei': imei,
      if (version != null) 'version': version,
      if (serverVersion != null) 'server_version': serverVersion,
      if (lifecycleState != null) 'lifecycle_state': lifecycleState,
      if (condition != null) 'condition': condition,
      if (brand != null) 'brand': brand,
      if (model != null) 'model': model,
      if (salePricePaise != null) 'sale_price_paise': salePricePaise,
      if (acquisitionCostPaise != null)
        'acquisition_cost_paise': acquisitionCostPaise,
      if (warrantyStartDate != null) 'warranty_start_date': warrantyStartDate,
      if (warrantyEndDate != null) 'warranty_end_date': warrantyEndDate,
      if (confirmationStatus != null) 'confirmation_status': confirmationStatus,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (dataModelVersion != null) 'data_model_version': dataModelVersion,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MobileImeiUnitsCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? entityId,
    Value<String>? imei,
    Value<int>? version,
    Value<int>? serverVersion,
    Value<String>? lifecycleState,
    Value<String?>? condition,
    Value<String?>? brand,
    Value<String?>? model,
    Value<int?>? salePricePaise,
    Value<int?>? acquisitionCostPaise,
    Value<DateTime?>? warrantyStartDate,
    Value<DateTime?>? warrantyEndDate,
    Value<String>? confirmationStatus,
    Value<DateTime?>? syncedAt,
    Value<int>? dataModelVersion,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MobileImeiUnitsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      entityId: entityId ?? this.entityId,
      imei: imei ?? this.imei,
      version: version ?? this.version,
      serverVersion: serverVersion ?? this.serverVersion,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      condition: condition ?? this.condition,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      salePricePaise: salePricePaise ?? this.salePricePaise,
      acquisitionCostPaise: acquisitionCostPaise ?? this.acquisitionCostPaise,
      warrantyStartDate: warrantyStartDate ?? this.warrantyStartDate,
      warrantyEndDate: warrantyEndDate ?? this.warrantyEndDate,
      confirmationStatus: confirmationStatus ?? this.confirmationStatus,
      syncedAt: syncedAt ?? this.syncedAt,
      dataModelVersion: dataModelVersion ?? this.dataModelVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (imei.present) {
      map['imei'] = Variable<String>(imei.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (lifecycleState.present) {
      map['lifecycle_state'] = Variable<String>(lifecycleState.value);
    }
    if (condition.present) {
      map['condition'] = Variable<String>(condition.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (salePricePaise.present) {
      map['sale_price_paise'] = Variable<int>(salePricePaise.value);
    }
    if (acquisitionCostPaise.present) {
      map['acquisition_cost_paise'] = Variable<int>(acquisitionCostPaise.value);
    }
    if (warrantyStartDate.present) {
      map['warranty_start_date'] = Variable<DateTime>(warrantyStartDate.value);
    }
    if (warrantyEndDate.present) {
      map['warranty_end_date'] = Variable<DateTime>(warrantyEndDate.value);
    }
    if (confirmationStatus.present) {
      map['confirmation_status'] = Variable<String>(confirmationStatus.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (dataModelVersion.present) {
      map['data_model_version'] = Variable<int>(dataModelVersion.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MobileImeiUnitsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('entityId: $entityId, ')
          ..write('imei: $imei, ')
          ..write('version: $version, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('lifecycleState: $lifecycleState, ')
          ..write('condition: $condition, ')
          ..write('brand: $brand, ')
          ..write('model: $model, ')
          ..write('salePricePaise: $salePricePaise, ')
          ..write('acquisitionCostPaise: $acquisitionCostPaise, ')
          ..write('warrantyStartDate: $warrantyStartDate, ')
          ..write('warrantyEndDate: $warrantyEndDate, ')
          ..write('confirmationStatus: $confirmationStatus, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('dataModelVersion: $dataModelVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MobileInvoiceAssociationsTable extends MobileInvoiceAssociations
    with
        TableInfo<
          $MobileInvoiceAssociationsTable,
          MobileInvoiceAssociationEntity
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MobileInvoiceAssociationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _invoiceIdMeta = const VerificationMeta(
    'invoiceId',
  );
  @override
  late final GeneratedColumn<String> invoiceId = GeneratedColumn<String>(
    'invoice_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _imeiMeta = const VerificationMeta('imei');
  @override
  late final GeneratedColumn<String> imei = GeneratedColumn<String>(
    'imei',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineNumberMeta = const VerificationMeta(
    'lineNumber',
  );
  @override
  late final GeneratedColumn<int> lineNumber = GeneratedColumn<int>(
    'line_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _linePricePaiseMeta = const VerificationMeta(
    'linePricePaise',
  );
  @override
  late final GeneratedColumn<int> linePricePaise = GeneratedColumn<int>(
    'line_price_paise',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _confirmationStatusMeta =
      const VerificationMeta('confirmationStatus');
  @override
  late final GeneratedColumn<String> confirmationStatus =
      GeneratedColumn<String>(
        'confirmation_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('pending'),
      );
  static const VerificationMeta _dataModelVersionMeta = const VerificationMeta(
    'dataModelVersion',
  );
  @override
  late final GeneratedColumn<int> dataModelVersion = GeneratedColumn<int>(
    'data_model_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    invoiceId,
    entityId,
    imei,
    lineNumber,
    linePricePaise,
    serverVersion,
    confirmationStatus,
    dataModelVersion,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mobile_invoice_associations';
  @override
  VerificationContext validateIntegrity(
    Insertable<MobileInvoiceAssociationEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('invoice_id')) {
      context.handle(
        _invoiceIdMeta,
        invoiceId.isAcceptableOrUnknown(data['invoice_id']!, _invoiceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_invoiceIdMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('imei')) {
      context.handle(
        _imeiMeta,
        imei.isAcceptableOrUnknown(data['imei']!, _imeiMeta),
      );
    } else if (isInserting) {
      context.missing(_imeiMeta);
    }
    if (data.containsKey('line_number')) {
      context.handle(
        _lineNumberMeta,
        lineNumber.isAcceptableOrUnknown(data['line_number']!, _lineNumberMeta),
      );
    }
    if (data.containsKey('line_price_paise')) {
      context.handle(
        _linePricePaiseMeta,
        linePricePaise.isAcceptableOrUnknown(
          data['line_price_paise']!,
          _linePricePaiseMeta,
        ),
      );
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    if (data.containsKey('confirmation_status')) {
      context.handle(
        _confirmationStatusMeta,
        confirmationStatus.isAcceptableOrUnknown(
          data['confirmation_status']!,
          _confirmationStatusMeta,
        ),
      );
    }
    if (data.containsKey('data_model_version')) {
      context.handle(
        _dataModelVersionMeta,
        dataModelVersion.isAcceptableOrUnknown(
          data['data_model_version']!,
          _dataModelVersionMeta,
        ),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {tenantId, invoiceId, imei},
  ];
  @override
  MobileInvoiceAssociationEntity map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MobileInvoiceAssociationEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      invoiceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invoice_id'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      imei: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}imei'],
      )!,
      lineNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_number'],
      )!,
      linePricePaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_price_paise'],
      ),
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      )!,
      confirmationStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confirmation_status'],
      )!,
      dataModelVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}data_model_version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MobileInvoiceAssociationsTable createAlias(String alias) {
    return $MobileInvoiceAssociationsTable(attachedDatabase, alias);
  }
}

class MobileInvoiceAssociationEntity extends DataClass
    implements Insertable<MobileInvoiceAssociationEntity> {
  final String id;
  final String tenantId;
  final String invoiceId;
  final String entityId;

  /// The IMEI associated with this invoice line.
  final String imei;

  /// Line number within the invoice.
  final int lineNumber;

  /// Sale price for this line in integer minor units (paise).
  final int? linePricePaise;

  /// Server version of this association.
  final int serverVersion;
  final String confirmationStatus;
  final int dataModelVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MobileInvoiceAssociationEntity({
    required this.id,
    required this.tenantId,
    required this.invoiceId,
    required this.entityId,
    required this.imei,
    required this.lineNumber,
    this.linePricePaise,
    required this.serverVersion,
    required this.confirmationStatus,
    required this.dataModelVersion,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['invoice_id'] = Variable<String>(invoiceId);
    map['entity_id'] = Variable<String>(entityId);
    map['imei'] = Variable<String>(imei);
    map['line_number'] = Variable<int>(lineNumber);
    if (!nullToAbsent || linePricePaise != null) {
      map['line_price_paise'] = Variable<int>(linePricePaise);
    }
    map['server_version'] = Variable<int>(serverVersion);
    map['confirmation_status'] = Variable<String>(confirmationStatus);
    map['data_model_version'] = Variable<int>(dataModelVersion);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MobileInvoiceAssociationsCompanion toCompanion(bool nullToAbsent) {
    return MobileInvoiceAssociationsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      invoiceId: Value(invoiceId),
      entityId: Value(entityId),
      imei: Value(imei),
      lineNumber: Value(lineNumber),
      linePricePaise: linePricePaise == null && nullToAbsent
          ? const Value.absent()
          : Value(linePricePaise),
      serverVersion: Value(serverVersion),
      confirmationStatus: Value(confirmationStatus),
      dataModelVersion: Value(dataModelVersion),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MobileInvoiceAssociationEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MobileInvoiceAssociationEntity(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      invoiceId: serializer.fromJson<String>(json['invoiceId']),
      entityId: serializer.fromJson<String>(json['entityId']),
      imei: serializer.fromJson<String>(json['imei']),
      lineNumber: serializer.fromJson<int>(json['lineNumber']),
      linePricePaise: serializer.fromJson<int?>(json['linePricePaise']),
      serverVersion: serializer.fromJson<int>(json['serverVersion']),
      confirmationStatus: serializer.fromJson<String>(
        json['confirmationStatus'],
      ),
      dataModelVersion: serializer.fromJson<int>(json['dataModelVersion']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'invoiceId': serializer.toJson<String>(invoiceId),
      'entityId': serializer.toJson<String>(entityId),
      'imei': serializer.toJson<String>(imei),
      'lineNumber': serializer.toJson<int>(lineNumber),
      'linePricePaise': serializer.toJson<int?>(linePricePaise),
      'serverVersion': serializer.toJson<int>(serverVersion),
      'confirmationStatus': serializer.toJson<String>(confirmationStatus),
      'dataModelVersion': serializer.toJson<int>(dataModelVersion),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MobileInvoiceAssociationEntity copyWith({
    String? id,
    String? tenantId,
    String? invoiceId,
    String? entityId,
    String? imei,
    int? lineNumber,
    Value<int?> linePricePaise = const Value.absent(),
    int? serverVersion,
    String? confirmationStatus,
    int? dataModelVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MobileInvoiceAssociationEntity(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    invoiceId: invoiceId ?? this.invoiceId,
    entityId: entityId ?? this.entityId,
    imei: imei ?? this.imei,
    lineNumber: lineNumber ?? this.lineNumber,
    linePricePaise: linePricePaise.present
        ? linePricePaise.value
        : this.linePricePaise,
    serverVersion: serverVersion ?? this.serverVersion,
    confirmationStatus: confirmationStatus ?? this.confirmationStatus,
    dataModelVersion: dataModelVersion ?? this.dataModelVersion,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MobileInvoiceAssociationEntity copyWithCompanion(
    MobileInvoiceAssociationsCompanion data,
  ) {
    return MobileInvoiceAssociationEntity(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      invoiceId: data.invoiceId.present ? data.invoiceId.value : this.invoiceId,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      imei: data.imei.present ? data.imei.value : this.imei,
      lineNumber: data.lineNumber.present
          ? data.lineNumber.value
          : this.lineNumber,
      linePricePaise: data.linePricePaise.present
          ? data.linePricePaise.value
          : this.linePricePaise,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      confirmationStatus: data.confirmationStatus.present
          ? data.confirmationStatus.value
          : this.confirmationStatus,
      dataModelVersion: data.dataModelVersion.present
          ? data.dataModelVersion.value
          : this.dataModelVersion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MobileInvoiceAssociationEntity(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('invoiceId: $invoiceId, ')
          ..write('entityId: $entityId, ')
          ..write('imei: $imei, ')
          ..write('lineNumber: $lineNumber, ')
          ..write('linePricePaise: $linePricePaise, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('confirmationStatus: $confirmationStatus, ')
          ..write('dataModelVersion: $dataModelVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    invoiceId,
    entityId,
    imei,
    lineNumber,
    linePricePaise,
    serverVersion,
    confirmationStatus,
    dataModelVersion,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MobileInvoiceAssociationEntity &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.invoiceId == this.invoiceId &&
          other.entityId == this.entityId &&
          other.imei == this.imei &&
          other.lineNumber == this.lineNumber &&
          other.linePricePaise == this.linePricePaise &&
          other.serverVersion == this.serverVersion &&
          other.confirmationStatus == this.confirmationStatus &&
          other.dataModelVersion == this.dataModelVersion &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MobileInvoiceAssociationsCompanion
    extends UpdateCompanion<MobileInvoiceAssociationEntity> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> invoiceId;
  final Value<String> entityId;
  final Value<String> imei;
  final Value<int> lineNumber;
  final Value<int?> linePricePaise;
  final Value<int> serverVersion;
  final Value<String> confirmationStatus;
  final Value<int> dataModelVersion;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MobileInvoiceAssociationsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.invoiceId = const Value.absent(),
    this.entityId = const Value.absent(),
    this.imei = const Value.absent(),
    this.lineNumber = const Value.absent(),
    this.linePricePaise = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.confirmationStatus = const Value.absent(),
    this.dataModelVersion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MobileInvoiceAssociationsCompanion.insert({
    required String id,
    required String tenantId,
    required String invoiceId,
    required String entityId,
    required String imei,
    this.lineNumber = const Value.absent(),
    this.linePricePaise = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.confirmationStatus = const Value.absent(),
    this.dataModelVersion = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       invoiceId = Value(invoiceId),
       entityId = Value(entityId),
       imei = Value(imei),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MobileInvoiceAssociationEntity> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? invoiceId,
    Expression<String>? entityId,
    Expression<String>? imei,
    Expression<int>? lineNumber,
    Expression<int>? linePricePaise,
    Expression<int>? serverVersion,
    Expression<String>? confirmationStatus,
    Expression<int>? dataModelVersion,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (invoiceId != null) 'invoice_id': invoiceId,
      if (entityId != null) 'entity_id': entityId,
      if (imei != null) 'imei': imei,
      if (lineNumber != null) 'line_number': lineNumber,
      if (linePricePaise != null) 'line_price_paise': linePricePaise,
      if (serverVersion != null) 'server_version': serverVersion,
      if (confirmationStatus != null) 'confirmation_status': confirmationStatus,
      if (dataModelVersion != null) 'data_model_version': dataModelVersion,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MobileInvoiceAssociationsCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? invoiceId,
    Value<String>? entityId,
    Value<String>? imei,
    Value<int>? lineNumber,
    Value<int?>? linePricePaise,
    Value<int>? serverVersion,
    Value<String>? confirmationStatus,
    Value<int>? dataModelVersion,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MobileInvoiceAssociationsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      invoiceId: invoiceId ?? this.invoiceId,
      entityId: entityId ?? this.entityId,
      imei: imei ?? this.imei,
      lineNumber: lineNumber ?? this.lineNumber,
      linePricePaise: linePricePaise ?? this.linePricePaise,
      serverVersion: serverVersion ?? this.serverVersion,
      confirmationStatus: confirmationStatus ?? this.confirmationStatus,
      dataModelVersion: dataModelVersion ?? this.dataModelVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (invoiceId.present) {
      map['invoice_id'] = Variable<String>(invoiceId.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (imei.present) {
      map['imei'] = Variable<String>(imei.value);
    }
    if (lineNumber.present) {
      map['line_number'] = Variable<int>(lineNumber.value);
    }
    if (linePricePaise.present) {
      map['line_price_paise'] = Variable<int>(linePricePaise.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (confirmationStatus.present) {
      map['confirmation_status'] = Variable<String>(confirmationStatus.value);
    }
    if (dataModelVersion.present) {
      map['data_model_version'] = Variable<int>(dataModelVersion.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MobileInvoiceAssociationsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('invoiceId: $invoiceId, ')
          ..write('entityId: $entityId, ')
          ..write('imei: $imei, ')
          ..write('lineNumber: $lineNumber, ')
          ..write('linePricePaise: $linePricePaise, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('confirmationStatus: $confirmationStatus, ')
          ..write('dataModelVersion: $dataModelVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MobileServiceJobsTable extends MobileServiceJobs
    with TableInfo<$MobileServiceJobsTable, MobileServiceJobEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MobileServiceJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _imeiMeta = const VerificationMeta('imei');
  @override
  late final GeneratedColumn<String> imei = GeneratedColumn<String>(
    'imei',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customerNameMeta = const VerificationMeta(
    'customerName',
  );
  @override
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
    'customer_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('RECEIVED'),
  );
  static const VerificationMeta _technicianIdMeta = const VerificationMeta(
    'technicianId',
  );
  @override
  late final GeneratedColumn<String> technicianId = GeneratedColumn<String>(
    'technician_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _problemDescriptionMeta =
      const VerificationMeta('problemDescription');
  @override
  late final GeneratedColumn<String> problemDescription =
      GeneratedColumn<String>(
        'problem_description',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _diagnosisMeta = const VerificationMeta(
    'diagnosis',
  );
  @override
  late final GeneratedColumn<String> diagnosis = GeneratedColumn<String>(
    'diagnosis',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _estimatedCostPaiseMeta =
      const VerificationMeta('estimatedCostPaise');
  @override
  late final GeneratedColumn<int> estimatedCostPaise = GeneratedColumn<int>(
    'estimated_cost_paise',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actualCostPaiseMeta = const VerificationMeta(
    'actualCostPaise',
  );
  @override
  late final GeneratedColumn<int> actualCostPaise = GeneratedColumn<int>(
    'actual_cost_paise',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _confirmationStatusMeta =
      const VerificationMeta('confirmationStatus');
  @override
  late final GeneratedColumn<String> confirmationStatus =
      GeneratedColumn<String>(
        'confirmation_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('pending'),
      );
  static const VerificationMeta _dataModelVersionMeta = const VerificationMeta(
    'dataModelVersion',
  );
  @override
  late final GeneratedColumn<int> dataModelVersion = GeneratedColumn<int>(
    'data_model_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    entityId,
    imei,
    customerId,
    customerName,
    status,
    technicianId,
    problemDescription,
    diagnosis,
    estimatedCostPaise,
    actualCostPaise,
    dueAt,
    version,
    serverVersion,
    confirmationStatus,
    dataModelVersion,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mobile_service_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<MobileServiceJobEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('imei')) {
      context.handle(
        _imeiMeta,
        imei.isAcceptableOrUnknown(data['imei']!, _imeiMeta),
      );
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    }
    if (data.containsKey('customer_name')) {
      context.handle(
        _customerNameMeta,
        customerName.isAcceptableOrUnknown(
          data['customer_name']!,
          _customerNameMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('technician_id')) {
      context.handle(
        _technicianIdMeta,
        technicianId.isAcceptableOrUnknown(
          data['technician_id']!,
          _technicianIdMeta,
        ),
      );
    }
    if (data.containsKey('problem_description')) {
      context.handle(
        _problemDescriptionMeta,
        problemDescription.isAcceptableOrUnknown(
          data['problem_description']!,
          _problemDescriptionMeta,
        ),
      );
    }
    if (data.containsKey('diagnosis')) {
      context.handle(
        _diagnosisMeta,
        diagnosis.isAcceptableOrUnknown(data['diagnosis']!, _diagnosisMeta),
      );
    }
    if (data.containsKey('estimated_cost_paise')) {
      context.handle(
        _estimatedCostPaiseMeta,
        estimatedCostPaise.isAcceptableOrUnknown(
          data['estimated_cost_paise']!,
          _estimatedCostPaiseMeta,
        ),
      );
    }
    if (data.containsKey('actual_cost_paise')) {
      context.handle(
        _actualCostPaiseMeta,
        actualCostPaise.isAcceptableOrUnknown(
          data['actual_cost_paise']!,
          _actualCostPaiseMeta,
        ),
      );
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    if (data.containsKey('confirmation_status')) {
      context.handle(
        _confirmationStatusMeta,
        confirmationStatus.isAcceptableOrUnknown(
          data['confirmation_status']!,
          _confirmationStatusMeta,
        ),
      );
    }
    if (data.containsKey('data_model_version')) {
      context.handle(
        _dataModelVersionMeta,
        dataModelVersion.isAcceptableOrUnknown(
          data['data_model_version']!,
          _dataModelVersionMeta,
        ),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {tenantId, entityId},
  ];
  @override
  MobileServiceJobEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MobileServiceJobEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      imei: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}imei'],
      ),
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      ),
      customerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_name'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      technicianId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}technician_id'],
      ),
      problemDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}problem_description'],
      ),
      diagnosis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}diagnosis'],
      ),
      estimatedCostPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estimated_cost_paise'],
      ),
      actualCostPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actual_cost_paise'],
      ),
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      )!,
      confirmationStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confirmation_status'],
      )!,
      dataModelVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}data_model_version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MobileServiceJobsTable createAlias(String alias) {
    return $MobileServiceJobsTable(attachedDatabase, alias);
  }
}

class MobileServiceJobEntity extends DataClass
    implements Insertable<MobileServiceJobEntity> {
  final String id;
  final String tenantId;
  final String entityId;

  /// Associated IMEI (may be null for non-IMEI service work).
  final String? imei;
  final String? customerId;
  final String? customerName;

  /// Service job status (RECEIVED, DIAGNOSED, WAITING_APPROVAL, APPROVED,
  /// WAITING_PARTS, IN_PROGRESS, COMPLETED, READY, DELIVERED, CANCELLED).
  final String status;
  final String? technicianId;
  final String? problemDescription;
  final String? diagnosis;

  /// Estimated cost in paise.
  final int? estimatedCostPaise;

  /// Actual cost in paise.
  final int? actualCostPaise;
  final DateTime? dueAt;
  final int version;
  final int serverVersion;
  final String confirmationStatus;
  final int dataModelVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MobileServiceJobEntity({
    required this.id,
    required this.tenantId,
    required this.entityId,
    this.imei,
    this.customerId,
    this.customerName,
    required this.status,
    this.technicianId,
    this.problemDescription,
    this.diagnosis,
    this.estimatedCostPaise,
    this.actualCostPaise,
    this.dueAt,
    required this.version,
    required this.serverVersion,
    required this.confirmationStatus,
    required this.dataModelVersion,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['entity_id'] = Variable<String>(entityId);
    if (!nullToAbsent || imei != null) {
      map['imei'] = Variable<String>(imei);
    }
    if (!nullToAbsent || customerId != null) {
      map['customer_id'] = Variable<String>(customerId);
    }
    if (!nullToAbsent || customerName != null) {
      map['customer_name'] = Variable<String>(customerName);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || technicianId != null) {
      map['technician_id'] = Variable<String>(technicianId);
    }
    if (!nullToAbsent || problemDescription != null) {
      map['problem_description'] = Variable<String>(problemDescription);
    }
    if (!nullToAbsent || diagnosis != null) {
      map['diagnosis'] = Variable<String>(diagnosis);
    }
    if (!nullToAbsent || estimatedCostPaise != null) {
      map['estimated_cost_paise'] = Variable<int>(estimatedCostPaise);
    }
    if (!nullToAbsent || actualCostPaise != null) {
      map['actual_cost_paise'] = Variable<int>(actualCostPaise);
    }
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<DateTime>(dueAt);
    }
    map['version'] = Variable<int>(version);
    map['server_version'] = Variable<int>(serverVersion);
    map['confirmation_status'] = Variable<String>(confirmationStatus);
    map['data_model_version'] = Variable<int>(dataModelVersion);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MobileServiceJobsCompanion toCompanion(bool nullToAbsent) {
    return MobileServiceJobsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      entityId: Value(entityId),
      imei: imei == null && nullToAbsent ? const Value.absent() : Value(imei),
      customerId: customerId == null && nullToAbsent
          ? const Value.absent()
          : Value(customerId),
      customerName: customerName == null && nullToAbsent
          ? const Value.absent()
          : Value(customerName),
      status: Value(status),
      technicianId: technicianId == null && nullToAbsent
          ? const Value.absent()
          : Value(technicianId),
      problemDescription: problemDescription == null && nullToAbsent
          ? const Value.absent()
          : Value(problemDescription),
      diagnosis: diagnosis == null && nullToAbsent
          ? const Value.absent()
          : Value(diagnosis),
      estimatedCostPaise: estimatedCostPaise == null && nullToAbsent
          ? const Value.absent()
          : Value(estimatedCostPaise),
      actualCostPaise: actualCostPaise == null && nullToAbsent
          ? const Value.absent()
          : Value(actualCostPaise),
      dueAt: dueAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dueAt),
      version: Value(version),
      serverVersion: Value(serverVersion),
      confirmationStatus: Value(confirmationStatus),
      dataModelVersion: Value(dataModelVersion),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MobileServiceJobEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MobileServiceJobEntity(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      entityId: serializer.fromJson<String>(json['entityId']),
      imei: serializer.fromJson<String?>(json['imei']),
      customerId: serializer.fromJson<String?>(json['customerId']),
      customerName: serializer.fromJson<String?>(json['customerName']),
      status: serializer.fromJson<String>(json['status']),
      technicianId: serializer.fromJson<String?>(json['technicianId']),
      problemDescription: serializer.fromJson<String?>(
        json['problemDescription'],
      ),
      diagnosis: serializer.fromJson<String?>(json['diagnosis']),
      estimatedCostPaise: serializer.fromJson<int?>(json['estimatedCostPaise']),
      actualCostPaise: serializer.fromJson<int?>(json['actualCostPaise']),
      dueAt: serializer.fromJson<DateTime?>(json['dueAt']),
      version: serializer.fromJson<int>(json['version']),
      serverVersion: serializer.fromJson<int>(json['serverVersion']),
      confirmationStatus: serializer.fromJson<String>(
        json['confirmationStatus'],
      ),
      dataModelVersion: serializer.fromJson<int>(json['dataModelVersion']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'entityId': serializer.toJson<String>(entityId),
      'imei': serializer.toJson<String?>(imei),
      'customerId': serializer.toJson<String?>(customerId),
      'customerName': serializer.toJson<String?>(customerName),
      'status': serializer.toJson<String>(status),
      'technicianId': serializer.toJson<String?>(technicianId),
      'problemDescription': serializer.toJson<String?>(problemDescription),
      'diagnosis': serializer.toJson<String?>(diagnosis),
      'estimatedCostPaise': serializer.toJson<int?>(estimatedCostPaise),
      'actualCostPaise': serializer.toJson<int?>(actualCostPaise),
      'dueAt': serializer.toJson<DateTime?>(dueAt),
      'version': serializer.toJson<int>(version),
      'serverVersion': serializer.toJson<int>(serverVersion),
      'confirmationStatus': serializer.toJson<String>(confirmationStatus),
      'dataModelVersion': serializer.toJson<int>(dataModelVersion),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MobileServiceJobEntity copyWith({
    String? id,
    String? tenantId,
    String? entityId,
    Value<String?> imei = const Value.absent(),
    Value<String?> customerId = const Value.absent(),
    Value<String?> customerName = const Value.absent(),
    String? status,
    Value<String?> technicianId = const Value.absent(),
    Value<String?> problemDescription = const Value.absent(),
    Value<String?> diagnosis = const Value.absent(),
    Value<int?> estimatedCostPaise = const Value.absent(),
    Value<int?> actualCostPaise = const Value.absent(),
    Value<DateTime?> dueAt = const Value.absent(),
    int? version,
    int? serverVersion,
    String? confirmationStatus,
    int? dataModelVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MobileServiceJobEntity(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    entityId: entityId ?? this.entityId,
    imei: imei.present ? imei.value : this.imei,
    customerId: customerId.present ? customerId.value : this.customerId,
    customerName: customerName.present ? customerName.value : this.customerName,
    status: status ?? this.status,
    technicianId: technicianId.present ? technicianId.value : this.technicianId,
    problemDescription: problemDescription.present
        ? problemDescription.value
        : this.problemDescription,
    diagnosis: diagnosis.present ? diagnosis.value : this.diagnosis,
    estimatedCostPaise: estimatedCostPaise.present
        ? estimatedCostPaise.value
        : this.estimatedCostPaise,
    actualCostPaise: actualCostPaise.present
        ? actualCostPaise.value
        : this.actualCostPaise,
    dueAt: dueAt.present ? dueAt.value : this.dueAt,
    version: version ?? this.version,
    serverVersion: serverVersion ?? this.serverVersion,
    confirmationStatus: confirmationStatus ?? this.confirmationStatus,
    dataModelVersion: dataModelVersion ?? this.dataModelVersion,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MobileServiceJobEntity copyWithCompanion(MobileServiceJobsCompanion data) {
    return MobileServiceJobEntity(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      imei: data.imei.present ? data.imei.value : this.imei,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      status: data.status.present ? data.status.value : this.status,
      technicianId: data.technicianId.present
          ? data.technicianId.value
          : this.technicianId,
      problemDescription: data.problemDescription.present
          ? data.problemDescription.value
          : this.problemDescription,
      diagnosis: data.diagnosis.present ? data.diagnosis.value : this.diagnosis,
      estimatedCostPaise: data.estimatedCostPaise.present
          ? data.estimatedCostPaise.value
          : this.estimatedCostPaise,
      actualCostPaise: data.actualCostPaise.present
          ? data.actualCostPaise.value
          : this.actualCostPaise,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      version: data.version.present ? data.version.value : this.version,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      confirmationStatus: data.confirmationStatus.present
          ? data.confirmationStatus.value
          : this.confirmationStatus,
      dataModelVersion: data.dataModelVersion.present
          ? data.dataModelVersion.value
          : this.dataModelVersion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MobileServiceJobEntity(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('entityId: $entityId, ')
          ..write('imei: $imei, ')
          ..write('customerId: $customerId, ')
          ..write('customerName: $customerName, ')
          ..write('status: $status, ')
          ..write('technicianId: $technicianId, ')
          ..write('problemDescription: $problemDescription, ')
          ..write('diagnosis: $diagnosis, ')
          ..write('estimatedCostPaise: $estimatedCostPaise, ')
          ..write('actualCostPaise: $actualCostPaise, ')
          ..write('dueAt: $dueAt, ')
          ..write('version: $version, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('confirmationStatus: $confirmationStatus, ')
          ..write('dataModelVersion: $dataModelVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    entityId,
    imei,
    customerId,
    customerName,
    status,
    technicianId,
    problemDescription,
    diagnosis,
    estimatedCostPaise,
    actualCostPaise,
    dueAt,
    version,
    serverVersion,
    confirmationStatus,
    dataModelVersion,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MobileServiceJobEntity &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.entityId == this.entityId &&
          other.imei == this.imei &&
          other.customerId == this.customerId &&
          other.customerName == this.customerName &&
          other.status == this.status &&
          other.technicianId == this.technicianId &&
          other.problemDescription == this.problemDescription &&
          other.diagnosis == this.diagnosis &&
          other.estimatedCostPaise == this.estimatedCostPaise &&
          other.actualCostPaise == this.actualCostPaise &&
          other.dueAt == this.dueAt &&
          other.version == this.version &&
          other.serverVersion == this.serverVersion &&
          other.confirmationStatus == this.confirmationStatus &&
          other.dataModelVersion == this.dataModelVersion &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MobileServiceJobsCompanion
    extends UpdateCompanion<MobileServiceJobEntity> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> entityId;
  final Value<String?> imei;
  final Value<String?> customerId;
  final Value<String?> customerName;
  final Value<String> status;
  final Value<String?> technicianId;
  final Value<String?> problemDescription;
  final Value<String?> diagnosis;
  final Value<int?> estimatedCostPaise;
  final Value<int?> actualCostPaise;
  final Value<DateTime?> dueAt;
  final Value<int> version;
  final Value<int> serverVersion;
  final Value<String> confirmationStatus;
  final Value<int> dataModelVersion;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MobileServiceJobsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.entityId = const Value.absent(),
    this.imei = const Value.absent(),
    this.customerId = const Value.absent(),
    this.customerName = const Value.absent(),
    this.status = const Value.absent(),
    this.technicianId = const Value.absent(),
    this.problemDescription = const Value.absent(),
    this.diagnosis = const Value.absent(),
    this.estimatedCostPaise = const Value.absent(),
    this.actualCostPaise = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.version = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.confirmationStatus = const Value.absent(),
    this.dataModelVersion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MobileServiceJobsCompanion.insert({
    required String id,
    required String tenantId,
    required String entityId,
    this.imei = const Value.absent(),
    this.customerId = const Value.absent(),
    this.customerName = const Value.absent(),
    this.status = const Value.absent(),
    this.technicianId = const Value.absent(),
    this.problemDescription = const Value.absent(),
    this.diagnosis = const Value.absent(),
    this.estimatedCostPaise = const Value.absent(),
    this.actualCostPaise = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.version = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.confirmationStatus = const Value.absent(),
    this.dataModelVersion = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       entityId = Value(entityId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MobileServiceJobEntity> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? entityId,
    Expression<String>? imei,
    Expression<String>? customerId,
    Expression<String>? customerName,
    Expression<String>? status,
    Expression<String>? technicianId,
    Expression<String>? problemDescription,
    Expression<String>? diagnosis,
    Expression<int>? estimatedCostPaise,
    Expression<int>? actualCostPaise,
    Expression<DateTime>? dueAt,
    Expression<int>? version,
    Expression<int>? serverVersion,
    Expression<String>? confirmationStatus,
    Expression<int>? dataModelVersion,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (entityId != null) 'entity_id': entityId,
      if (imei != null) 'imei': imei,
      if (customerId != null) 'customer_id': customerId,
      if (customerName != null) 'customer_name': customerName,
      if (status != null) 'status': status,
      if (technicianId != null) 'technician_id': technicianId,
      if (problemDescription != null) 'problem_description': problemDescription,
      if (diagnosis != null) 'diagnosis': diagnosis,
      if (estimatedCostPaise != null)
        'estimated_cost_paise': estimatedCostPaise,
      if (actualCostPaise != null) 'actual_cost_paise': actualCostPaise,
      if (dueAt != null) 'due_at': dueAt,
      if (version != null) 'version': version,
      if (serverVersion != null) 'server_version': serverVersion,
      if (confirmationStatus != null) 'confirmation_status': confirmationStatus,
      if (dataModelVersion != null) 'data_model_version': dataModelVersion,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MobileServiceJobsCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? entityId,
    Value<String?>? imei,
    Value<String?>? customerId,
    Value<String?>? customerName,
    Value<String>? status,
    Value<String?>? technicianId,
    Value<String?>? problemDescription,
    Value<String?>? diagnosis,
    Value<int?>? estimatedCostPaise,
    Value<int?>? actualCostPaise,
    Value<DateTime?>? dueAt,
    Value<int>? version,
    Value<int>? serverVersion,
    Value<String>? confirmationStatus,
    Value<int>? dataModelVersion,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MobileServiceJobsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      entityId: entityId ?? this.entityId,
      imei: imei ?? this.imei,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      status: status ?? this.status,
      technicianId: technicianId ?? this.technicianId,
      problemDescription: problemDescription ?? this.problemDescription,
      diagnosis: diagnosis ?? this.diagnosis,
      estimatedCostPaise: estimatedCostPaise ?? this.estimatedCostPaise,
      actualCostPaise: actualCostPaise ?? this.actualCostPaise,
      dueAt: dueAt ?? this.dueAt,
      version: version ?? this.version,
      serverVersion: serverVersion ?? this.serverVersion,
      confirmationStatus: confirmationStatus ?? this.confirmationStatus,
      dataModelVersion: dataModelVersion ?? this.dataModelVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (imei.present) {
      map['imei'] = Variable<String>(imei.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (technicianId.present) {
      map['technician_id'] = Variable<String>(technicianId.value);
    }
    if (problemDescription.present) {
      map['problem_description'] = Variable<String>(problemDescription.value);
    }
    if (diagnosis.present) {
      map['diagnosis'] = Variable<String>(diagnosis.value);
    }
    if (estimatedCostPaise.present) {
      map['estimated_cost_paise'] = Variable<int>(estimatedCostPaise.value);
    }
    if (actualCostPaise.present) {
      map['actual_cost_paise'] = Variable<int>(actualCostPaise.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (confirmationStatus.present) {
      map['confirmation_status'] = Variable<String>(confirmationStatus.value);
    }
    if (dataModelVersion.present) {
      map['data_model_version'] = Variable<int>(dataModelVersion.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MobileServiceJobsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('entityId: $entityId, ')
          ..write('imei: $imei, ')
          ..write('customerId: $customerId, ')
          ..write('customerName: $customerName, ')
          ..write('status: $status, ')
          ..write('technicianId: $technicianId, ')
          ..write('problemDescription: $problemDescription, ')
          ..write('diagnosis: $diagnosis, ')
          ..write('estimatedCostPaise: $estimatedCostPaise, ')
          ..write('actualCostPaise: $actualCostPaise, ')
          ..write('dueAt: $dueAt, ')
          ..write('version: $version, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('confirmationStatus: $confirmationStatus, ')
          ..write('dataModelVersion: $dataModelVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MobileExchangesTable extends MobileExchanges
    with TableInfo<$MobileExchangesTable, MobileExchangeEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MobileExchangesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _oldDeviceImeiMeta = const VerificationMeta(
    'oldDeviceImei',
  );
  @override
  late final GeneratedColumn<String> oldDeviceImei = GeneratedColumn<String>(
    'old_device_imei',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _newDeviceImeiMeta = const VerificationMeta(
    'newDeviceImei',
  );
  @override
  late final GeneratedColumn<String> newDeviceImei = GeneratedColumn<String>(
    'new_device_imei',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _oldDeviceValuationPaiseMeta =
      const VerificationMeta('oldDeviceValuationPaise');
  @override
  late final GeneratedColumn<int> oldDeviceValuationPaise =
      GeneratedColumn<int>(
        'old_device_valuation_paise',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _adjustmentPaiseMeta = const VerificationMeta(
    'adjustmentPaise',
  );
  @override
  late final GeneratedColumn<int> adjustmentPaise = GeneratedColumn<int>(
    'adjustment_paise',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PENDING'),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _confirmationStatusMeta =
      const VerificationMeta('confirmationStatus');
  @override
  late final GeneratedColumn<String> confirmationStatus =
      GeneratedColumn<String>(
        'confirmation_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('pending'),
      );
  static const VerificationMeta _dataModelVersionMeta = const VerificationMeta(
    'dataModelVersion',
  );
  @override
  late final GeneratedColumn<int> dataModelVersion = GeneratedColumn<int>(
    'data_model_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    entityId,
    oldDeviceImei,
    newDeviceImei,
    customerId,
    oldDeviceValuationPaise,
    adjustmentPaise,
    status,
    version,
    serverVersion,
    confirmationStatus,
    dataModelVersion,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mobile_exchanges';
  @override
  VerificationContext validateIntegrity(
    Insertable<MobileExchangeEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('old_device_imei')) {
      context.handle(
        _oldDeviceImeiMeta,
        oldDeviceImei.isAcceptableOrUnknown(
          data['old_device_imei']!,
          _oldDeviceImeiMeta,
        ),
      );
    }
    if (data.containsKey('new_device_imei')) {
      context.handle(
        _newDeviceImeiMeta,
        newDeviceImei.isAcceptableOrUnknown(
          data['new_device_imei']!,
          _newDeviceImeiMeta,
        ),
      );
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    }
    if (data.containsKey('old_device_valuation_paise')) {
      context.handle(
        _oldDeviceValuationPaiseMeta,
        oldDeviceValuationPaise.isAcceptableOrUnknown(
          data['old_device_valuation_paise']!,
          _oldDeviceValuationPaiseMeta,
        ),
      );
    }
    if (data.containsKey('adjustment_paise')) {
      context.handle(
        _adjustmentPaiseMeta,
        adjustmentPaise.isAcceptableOrUnknown(
          data['adjustment_paise']!,
          _adjustmentPaiseMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    if (data.containsKey('confirmation_status')) {
      context.handle(
        _confirmationStatusMeta,
        confirmationStatus.isAcceptableOrUnknown(
          data['confirmation_status']!,
          _confirmationStatusMeta,
        ),
      );
    }
    if (data.containsKey('data_model_version')) {
      context.handle(
        _dataModelVersionMeta,
        dataModelVersion.isAcceptableOrUnknown(
          data['data_model_version']!,
          _dataModelVersionMeta,
        ),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {tenantId, entityId},
  ];
  @override
  MobileExchangeEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MobileExchangeEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      oldDeviceImei: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}old_device_imei'],
      ),
      newDeviceImei: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}new_device_imei'],
      ),
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      ),
      oldDeviceValuationPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}old_device_valuation_paise'],
      ),
      adjustmentPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}adjustment_paise'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      )!,
      confirmationStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confirmation_status'],
      )!,
      dataModelVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}data_model_version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MobileExchangesTable createAlias(String alias) {
    return $MobileExchangesTable(attachedDatabase, alias);
  }
}

class MobileExchangeEntity extends DataClass
    implements Insertable<MobileExchangeEntity> {
  final String id;
  final String tenantId;
  final String entityId;

  /// Old device IMEI being exchanged.
  final String? oldDeviceImei;

  /// New device IMEI being given.
  final String? newDeviceImei;
  final String? customerId;

  /// Old device valuation in paise.
  final int? oldDeviceValuationPaise;

  /// Financial adjustment (difference) in paise.
  final int? adjustmentPaise;

  /// Exchange status (PENDING, APPROVED, COMPLETED, CANCELLED).
  final String status;
  final int version;
  final int serverVersion;
  final String confirmationStatus;
  final int dataModelVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MobileExchangeEntity({
    required this.id,
    required this.tenantId,
    required this.entityId,
    this.oldDeviceImei,
    this.newDeviceImei,
    this.customerId,
    this.oldDeviceValuationPaise,
    this.adjustmentPaise,
    required this.status,
    required this.version,
    required this.serverVersion,
    required this.confirmationStatus,
    required this.dataModelVersion,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['entity_id'] = Variable<String>(entityId);
    if (!nullToAbsent || oldDeviceImei != null) {
      map['old_device_imei'] = Variable<String>(oldDeviceImei);
    }
    if (!nullToAbsent || newDeviceImei != null) {
      map['new_device_imei'] = Variable<String>(newDeviceImei);
    }
    if (!nullToAbsent || customerId != null) {
      map['customer_id'] = Variable<String>(customerId);
    }
    if (!nullToAbsent || oldDeviceValuationPaise != null) {
      map['old_device_valuation_paise'] = Variable<int>(
        oldDeviceValuationPaise,
      );
    }
    if (!nullToAbsent || adjustmentPaise != null) {
      map['adjustment_paise'] = Variable<int>(adjustmentPaise);
    }
    map['status'] = Variable<String>(status);
    map['version'] = Variable<int>(version);
    map['server_version'] = Variable<int>(serverVersion);
    map['confirmation_status'] = Variable<String>(confirmationStatus);
    map['data_model_version'] = Variable<int>(dataModelVersion);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MobileExchangesCompanion toCompanion(bool nullToAbsent) {
    return MobileExchangesCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      entityId: Value(entityId),
      oldDeviceImei: oldDeviceImei == null && nullToAbsent
          ? const Value.absent()
          : Value(oldDeviceImei),
      newDeviceImei: newDeviceImei == null && nullToAbsent
          ? const Value.absent()
          : Value(newDeviceImei),
      customerId: customerId == null && nullToAbsent
          ? const Value.absent()
          : Value(customerId),
      oldDeviceValuationPaise: oldDeviceValuationPaise == null && nullToAbsent
          ? const Value.absent()
          : Value(oldDeviceValuationPaise),
      adjustmentPaise: adjustmentPaise == null && nullToAbsent
          ? const Value.absent()
          : Value(adjustmentPaise),
      status: Value(status),
      version: Value(version),
      serverVersion: Value(serverVersion),
      confirmationStatus: Value(confirmationStatus),
      dataModelVersion: Value(dataModelVersion),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MobileExchangeEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MobileExchangeEntity(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      entityId: serializer.fromJson<String>(json['entityId']),
      oldDeviceImei: serializer.fromJson<String?>(json['oldDeviceImei']),
      newDeviceImei: serializer.fromJson<String?>(json['newDeviceImei']),
      customerId: serializer.fromJson<String?>(json['customerId']),
      oldDeviceValuationPaise: serializer.fromJson<int?>(
        json['oldDeviceValuationPaise'],
      ),
      adjustmentPaise: serializer.fromJson<int?>(json['adjustmentPaise']),
      status: serializer.fromJson<String>(json['status']),
      version: serializer.fromJson<int>(json['version']),
      serverVersion: serializer.fromJson<int>(json['serverVersion']),
      confirmationStatus: serializer.fromJson<String>(
        json['confirmationStatus'],
      ),
      dataModelVersion: serializer.fromJson<int>(json['dataModelVersion']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'entityId': serializer.toJson<String>(entityId),
      'oldDeviceImei': serializer.toJson<String?>(oldDeviceImei),
      'newDeviceImei': serializer.toJson<String?>(newDeviceImei),
      'customerId': serializer.toJson<String?>(customerId),
      'oldDeviceValuationPaise': serializer.toJson<int?>(
        oldDeviceValuationPaise,
      ),
      'adjustmentPaise': serializer.toJson<int?>(adjustmentPaise),
      'status': serializer.toJson<String>(status),
      'version': serializer.toJson<int>(version),
      'serverVersion': serializer.toJson<int>(serverVersion),
      'confirmationStatus': serializer.toJson<String>(confirmationStatus),
      'dataModelVersion': serializer.toJson<int>(dataModelVersion),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MobileExchangeEntity copyWith({
    String? id,
    String? tenantId,
    String? entityId,
    Value<String?> oldDeviceImei = const Value.absent(),
    Value<String?> newDeviceImei = const Value.absent(),
    Value<String?> customerId = const Value.absent(),
    Value<int?> oldDeviceValuationPaise = const Value.absent(),
    Value<int?> adjustmentPaise = const Value.absent(),
    String? status,
    int? version,
    int? serverVersion,
    String? confirmationStatus,
    int? dataModelVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MobileExchangeEntity(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    entityId: entityId ?? this.entityId,
    oldDeviceImei: oldDeviceImei.present
        ? oldDeviceImei.value
        : this.oldDeviceImei,
    newDeviceImei: newDeviceImei.present
        ? newDeviceImei.value
        : this.newDeviceImei,
    customerId: customerId.present ? customerId.value : this.customerId,
    oldDeviceValuationPaise: oldDeviceValuationPaise.present
        ? oldDeviceValuationPaise.value
        : this.oldDeviceValuationPaise,
    adjustmentPaise: adjustmentPaise.present
        ? adjustmentPaise.value
        : this.adjustmentPaise,
    status: status ?? this.status,
    version: version ?? this.version,
    serverVersion: serverVersion ?? this.serverVersion,
    confirmationStatus: confirmationStatus ?? this.confirmationStatus,
    dataModelVersion: dataModelVersion ?? this.dataModelVersion,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MobileExchangeEntity copyWithCompanion(MobileExchangesCompanion data) {
    return MobileExchangeEntity(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      oldDeviceImei: data.oldDeviceImei.present
          ? data.oldDeviceImei.value
          : this.oldDeviceImei,
      newDeviceImei: data.newDeviceImei.present
          ? data.newDeviceImei.value
          : this.newDeviceImei,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      oldDeviceValuationPaise: data.oldDeviceValuationPaise.present
          ? data.oldDeviceValuationPaise.value
          : this.oldDeviceValuationPaise,
      adjustmentPaise: data.adjustmentPaise.present
          ? data.adjustmentPaise.value
          : this.adjustmentPaise,
      status: data.status.present ? data.status.value : this.status,
      version: data.version.present ? data.version.value : this.version,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      confirmationStatus: data.confirmationStatus.present
          ? data.confirmationStatus.value
          : this.confirmationStatus,
      dataModelVersion: data.dataModelVersion.present
          ? data.dataModelVersion.value
          : this.dataModelVersion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MobileExchangeEntity(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('entityId: $entityId, ')
          ..write('oldDeviceImei: $oldDeviceImei, ')
          ..write('newDeviceImei: $newDeviceImei, ')
          ..write('customerId: $customerId, ')
          ..write('oldDeviceValuationPaise: $oldDeviceValuationPaise, ')
          ..write('adjustmentPaise: $adjustmentPaise, ')
          ..write('status: $status, ')
          ..write('version: $version, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('confirmationStatus: $confirmationStatus, ')
          ..write('dataModelVersion: $dataModelVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    entityId,
    oldDeviceImei,
    newDeviceImei,
    customerId,
    oldDeviceValuationPaise,
    adjustmentPaise,
    status,
    version,
    serverVersion,
    confirmationStatus,
    dataModelVersion,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MobileExchangeEntity &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.entityId == this.entityId &&
          other.oldDeviceImei == this.oldDeviceImei &&
          other.newDeviceImei == this.newDeviceImei &&
          other.customerId == this.customerId &&
          other.oldDeviceValuationPaise == this.oldDeviceValuationPaise &&
          other.adjustmentPaise == this.adjustmentPaise &&
          other.status == this.status &&
          other.version == this.version &&
          other.serverVersion == this.serverVersion &&
          other.confirmationStatus == this.confirmationStatus &&
          other.dataModelVersion == this.dataModelVersion &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MobileExchangesCompanion extends UpdateCompanion<MobileExchangeEntity> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> entityId;
  final Value<String?> oldDeviceImei;
  final Value<String?> newDeviceImei;
  final Value<String?> customerId;
  final Value<int?> oldDeviceValuationPaise;
  final Value<int?> adjustmentPaise;
  final Value<String> status;
  final Value<int> version;
  final Value<int> serverVersion;
  final Value<String> confirmationStatus;
  final Value<int> dataModelVersion;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MobileExchangesCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.entityId = const Value.absent(),
    this.oldDeviceImei = const Value.absent(),
    this.newDeviceImei = const Value.absent(),
    this.customerId = const Value.absent(),
    this.oldDeviceValuationPaise = const Value.absent(),
    this.adjustmentPaise = const Value.absent(),
    this.status = const Value.absent(),
    this.version = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.confirmationStatus = const Value.absent(),
    this.dataModelVersion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MobileExchangesCompanion.insert({
    required String id,
    required String tenantId,
    required String entityId,
    this.oldDeviceImei = const Value.absent(),
    this.newDeviceImei = const Value.absent(),
    this.customerId = const Value.absent(),
    this.oldDeviceValuationPaise = const Value.absent(),
    this.adjustmentPaise = const Value.absent(),
    this.status = const Value.absent(),
    this.version = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.confirmationStatus = const Value.absent(),
    this.dataModelVersion = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       entityId = Value(entityId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MobileExchangeEntity> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? entityId,
    Expression<String>? oldDeviceImei,
    Expression<String>? newDeviceImei,
    Expression<String>? customerId,
    Expression<int>? oldDeviceValuationPaise,
    Expression<int>? adjustmentPaise,
    Expression<String>? status,
    Expression<int>? version,
    Expression<int>? serverVersion,
    Expression<String>? confirmationStatus,
    Expression<int>? dataModelVersion,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (entityId != null) 'entity_id': entityId,
      if (oldDeviceImei != null) 'old_device_imei': oldDeviceImei,
      if (newDeviceImei != null) 'new_device_imei': newDeviceImei,
      if (customerId != null) 'customer_id': customerId,
      if (oldDeviceValuationPaise != null)
        'old_device_valuation_paise': oldDeviceValuationPaise,
      if (adjustmentPaise != null) 'adjustment_paise': adjustmentPaise,
      if (status != null) 'status': status,
      if (version != null) 'version': version,
      if (serverVersion != null) 'server_version': serverVersion,
      if (confirmationStatus != null) 'confirmation_status': confirmationStatus,
      if (dataModelVersion != null) 'data_model_version': dataModelVersion,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MobileExchangesCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? entityId,
    Value<String?>? oldDeviceImei,
    Value<String?>? newDeviceImei,
    Value<String?>? customerId,
    Value<int?>? oldDeviceValuationPaise,
    Value<int?>? adjustmentPaise,
    Value<String>? status,
    Value<int>? version,
    Value<int>? serverVersion,
    Value<String>? confirmationStatus,
    Value<int>? dataModelVersion,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MobileExchangesCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      entityId: entityId ?? this.entityId,
      oldDeviceImei: oldDeviceImei ?? this.oldDeviceImei,
      newDeviceImei: newDeviceImei ?? this.newDeviceImei,
      customerId: customerId ?? this.customerId,
      oldDeviceValuationPaise:
          oldDeviceValuationPaise ?? this.oldDeviceValuationPaise,
      adjustmentPaise: adjustmentPaise ?? this.adjustmentPaise,
      status: status ?? this.status,
      version: version ?? this.version,
      serverVersion: serverVersion ?? this.serverVersion,
      confirmationStatus: confirmationStatus ?? this.confirmationStatus,
      dataModelVersion: dataModelVersion ?? this.dataModelVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (oldDeviceImei.present) {
      map['old_device_imei'] = Variable<String>(oldDeviceImei.value);
    }
    if (newDeviceImei.present) {
      map['new_device_imei'] = Variable<String>(newDeviceImei.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (oldDeviceValuationPaise.present) {
      map['old_device_valuation_paise'] = Variable<int>(
        oldDeviceValuationPaise.value,
      );
    }
    if (adjustmentPaise.present) {
      map['adjustment_paise'] = Variable<int>(adjustmentPaise.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (confirmationStatus.present) {
      map['confirmation_status'] = Variable<String>(confirmationStatus.value);
    }
    if (dataModelVersion.present) {
      map['data_model_version'] = Variable<int>(dataModelVersion.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MobileExchangesCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('entityId: $entityId, ')
          ..write('oldDeviceImei: $oldDeviceImei, ')
          ..write('newDeviceImei: $newDeviceImei, ')
          ..write('customerId: $customerId, ')
          ..write('oldDeviceValuationPaise: $oldDeviceValuationPaise, ')
          ..write('adjustmentPaise: $adjustmentPaise, ')
          ..write('status: $status, ')
          ..write('version: $version, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('confirmationStatus: $confirmationStatus, ')
          ..write('dataModelVersion: $dataModelVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MobileWarrantiesTable extends MobileWarranties
    with TableInfo<$MobileWarrantiesTable, MobileWarrantyEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MobileWarrantiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _imeiMeta = const VerificationMeta('imei');
  @override
  late final GeneratedColumn<String> imei = GeneratedColumn<String>(
    'imei',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _warrantyMonthsMeta = const VerificationMeta(
    'warrantyMonths',
  );
  @override
  late final GeneratedColumn<int> warrantyMonths = GeneratedColumn<int>(
    'warranty_months',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ACTIVE'),
  );
  static const VerificationMeta _claimStatusMeta = const VerificationMeta(
    'claimStatus',
  );
  @override
  late final GeneratedColumn<String> claimStatus = GeneratedColumn<String>(
    'claim_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _evidenceRefMeta = const VerificationMeta(
    'evidenceRef',
  );
  @override
  late final GeneratedColumn<String> evidenceRef = GeneratedColumn<String>(
    'evidence_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _confirmationStatusMeta =
      const VerificationMeta('confirmationStatus');
  @override
  late final GeneratedColumn<String> confirmationStatus =
      GeneratedColumn<String>(
        'confirmation_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('pending'),
      );
  static const VerificationMeta _dataModelVersionMeta = const VerificationMeta(
    'dataModelVersion',
  );
  @override
  late final GeneratedColumn<int> dataModelVersion = GeneratedColumn<int>(
    'data_model_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    entityId,
    imei,
    provider,
    warrantyMonths,
    startDate,
    endDate,
    status,
    claimStatus,
    evidenceRef,
    version,
    serverVersion,
    confirmationStatus,
    dataModelVersion,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mobile_warranties';
  @override
  VerificationContext validateIntegrity(
    Insertable<MobileWarrantyEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('imei')) {
      context.handle(
        _imeiMeta,
        imei.isAcceptableOrUnknown(data['imei']!, _imeiMeta),
      );
    } else if (isInserting) {
      context.missing(_imeiMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    }
    if (data.containsKey('warranty_months')) {
      context.handle(
        _warrantyMonthsMeta,
        warrantyMonths.isAcceptableOrUnknown(
          data['warranty_months']!,
          _warrantyMonthsMeta,
        ),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('claim_status')) {
      context.handle(
        _claimStatusMeta,
        claimStatus.isAcceptableOrUnknown(
          data['claim_status']!,
          _claimStatusMeta,
        ),
      );
    }
    if (data.containsKey('evidence_ref')) {
      context.handle(
        _evidenceRefMeta,
        evidenceRef.isAcceptableOrUnknown(
          data['evidence_ref']!,
          _evidenceRefMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    if (data.containsKey('confirmation_status')) {
      context.handle(
        _confirmationStatusMeta,
        confirmationStatus.isAcceptableOrUnknown(
          data['confirmation_status']!,
          _confirmationStatusMeta,
        ),
      );
    }
    if (data.containsKey('data_model_version')) {
      context.handle(
        _dataModelVersionMeta,
        dataModelVersion.isAcceptableOrUnknown(
          data['data_model_version']!,
          _dataModelVersionMeta,
        ),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {tenantId, entityId},
  ];
  @override
  MobileWarrantyEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MobileWarrantyEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      imei: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}imei'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      ),
      warrantyMonths: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}warranty_months'],
      ),
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      ),
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      claimStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}claim_status'],
      ),
      evidenceRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence_ref'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      )!,
      confirmationStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confirmation_status'],
      )!,
      dataModelVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}data_model_version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MobileWarrantiesTable createAlias(String alias) {
    return $MobileWarrantiesTable(attachedDatabase, alias);
  }
}

class MobileWarrantyEntity extends DataClass
    implements Insertable<MobileWarrantyEntity> {
  final String id;
  final String tenantId;
  final String entityId;

  /// Associated IMEI.
  final String imei;

  /// Warranty provider name.
  final String? provider;

  /// Warranty months.
  final int? warrantyMonths;
  final DateTime? startDate;
  final DateTime? endDate;

  /// Warranty status (ACTIVE, EXPIRED, CLAIMED, VOID).
  final String status;

  /// Claim status if a claim has been filed.
  final String? claimStatus;

  /// Evidence reference (e.g., document path).
  final String? evidenceRef;
  final int version;
  final int serverVersion;
  final String confirmationStatus;
  final int dataModelVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MobileWarrantyEntity({
    required this.id,
    required this.tenantId,
    required this.entityId,
    required this.imei,
    this.provider,
    this.warrantyMonths,
    this.startDate,
    this.endDate,
    required this.status,
    this.claimStatus,
    this.evidenceRef,
    required this.version,
    required this.serverVersion,
    required this.confirmationStatus,
    required this.dataModelVersion,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['entity_id'] = Variable<String>(entityId);
    map['imei'] = Variable<String>(imei);
    if (!nullToAbsent || provider != null) {
      map['provider'] = Variable<String>(provider);
    }
    if (!nullToAbsent || warrantyMonths != null) {
      map['warranty_months'] = Variable<int>(warrantyMonths);
    }
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<DateTime>(startDate);
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || claimStatus != null) {
      map['claim_status'] = Variable<String>(claimStatus);
    }
    if (!nullToAbsent || evidenceRef != null) {
      map['evidence_ref'] = Variable<String>(evidenceRef);
    }
    map['version'] = Variable<int>(version);
    map['server_version'] = Variable<int>(serverVersion);
    map['confirmation_status'] = Variable<String>(confirmationStatus);
    map['data_model_version'] = Variable<int>(dataModelVersion);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MobileWarrantiesCompanion toCompanion(bool nullToAbsent) {
    return MobileWarrantiesCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      entityId: Value(entityId),
      imei: Value(imei),
      provider: provider == null && nullToAbsent
          ? const Value.absent()
          : Value(provider),
      warrantyMonths: warrantyMonths == null && nullToAbsent
          ? const Value.absent()
          : Value(warrantyMonths),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      status: Value(status),
      claimStatus: claimStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(claimStatus),
      evidenceRef: evidenceRef == null && nullToAbsent
          ? const Value.absent()
          : Value(evidenceRef),
      version: Value(version),
      serverVersion: Value(serverVersion),
      confirmationStatus: Value(confirmationStatus),
      dataModelVersion: Value(dataModelVersion),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MobileWarrantyEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MobileWarrantyEntity(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      entityId: serializer.fromJson<String>(json['entityId']),
      imei: serializer.fromJson<String>(json['imei']),
      provider: serializer.fromJson<String?>(json['provider']),
      warrantyMonths: serializer.fromJson<int?>(json['warrantyMonths']),
      startDate: serializer.fromJson<DateTime?>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      status: serializer.fromJson<String>(json['status']),
      claimStatus: serializer.fromJson<String?>(json['claimStatus']),
      evidenceRef: serializer.fromJson<String?>(json['evidenceRef']),
      version: serializer.fromJson<int>(json['version']),
      serverVersion: serializer.fromJson<int>(json['serverVersion']),
      confirmationStatus: serializer.fromJson<String>(
        json['confirmationStatus'],
      ),
      dataModelVersion: serializer.fromJson<int>(json['dataModelVersion']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'entityId': serializer.toJson<String>(entityId),
      'imei': serializer.toJson<String>(imei),
      'provider': serializer.toJson<String?>(provider),
      'warrantyMonths': serializer.toJson<int?>(warrantyMonths),
      'startDate': serializer.toJson<DateTime?>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'status': serializer.toJson<String>(status),
      'claimStatus': serializer.toJson<String?>(claimStatus),
      'evidenceRef': serializer.toJson<String?>(evidenceRef),
      'version': serializer.toJson<int>(version),
      'serverVersion': serializer.toJson<int>(serverVersion),
      'confirmationStatus': serializer.toJson<String>(confirmationStatus),
      'dataModelVersion': serializer.toJson<int>(dataModelVersion),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MobileWarrantyEntity copyWith({
    String? id,
    String? tenantId,
    String? entityId,
    String? imei,
    Value<String?> provider = const Value.absent(),
    Value<int?> warrantyMonths = const Value.absent(),
    Value<DateTime?> startDate = const Value.absent(),
    Value<DateTime?> endDate = const Value.absent(),
    String? status,
    Value<String?> claimStatus = const Value.absent(),
    Value<String?> evidenceRef = const Value.absent(),
    int? version,
    int? serverVersion,
    String? confirmationStatus,
    int? dataModelVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MobileWarrantyEntity(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    entityId: entityId ?? this.entityId,
    imei: imei ?? this.imei,
    provider: provider.present ? provider.value : this.provider,
    warrantyMonths: warrantyMonths.present
        ? warrantyMonths.value
        : this.warrantyMonths,
    startDate: startDate.present ? startDate.value : this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    status: status ?? this.status,
    claimStatus: claimStatus.present ? claimStatus.value : this.claimStatus,
    evidenceRef: evidenceRef.present ? evidenceRef.value : this.evidenceRef,
    version: version ?? this.version,
    serverVersion: serverVersion ?? this.serverVersion,
    confirmationStatus: confirmationStatus ?? this.confirmationStatus,
    dataModelVersion: dataModelVersion ?? this.dataModelVersion,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MobileWarrantyEntity copyWithCompanion(MobileWarrantiesCompanion data) {
    return MobileWarrantyEntity(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      imei: data.imei.present ? data.imei.value : this.imei,
      provider: data.provider.present ? data.provider.value : this.provider,
      warrantyMonths: data.warrantyMonths.present
          ? data.warrantyMonths.value
          : this.warrantyMonths,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      status: data.status.present ? data.status.value : this.status,
      claimStatus: data.claimStatus.present
          ? data.claimStatus.value
          : this.claimStatus,
      evidenceRef: data.evidenceRef.present
          ? data.evidenceRef.value
          : this.evidenceRef,
      version: data.version.present ? data.version.value : this.version,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      confirmationStatus: data.confirmationStatus.present
          ? data.confirmationStatus.value
          : this.confirmationStatus,
      dataModelVersion: data.dataModelVersion.present
          ? data.dataModelVersion.value
          : this.dataModelVersion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MobileWarrantyEntity(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('entityId: $entityId, ')
          ..write('imei: $imei, ')
          ..write('provider: $provider, ')
          ..write('warrantyMonths: $warrantyMonths, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('status: $status, ')
          ..write('claimStatus: $claimStatus, ')
          ..write('evidenceRef: $evidenceRef, ')
          ..write('version: $version, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('confirmationStatus: $confirmationStatus, ')
          ..write('dataModelVersion: $dataModelVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    entityId,
    imei,
    provider,
    warrantyMonths,
    startDate,
    endDate,
    status,
    claimStatus,
    evidenceRef,
    version,
    serverVersion,
    confirmationStatus,
    dataModelVersion,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MobileWarrantyEntity &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.entityId == this.entityId &&
          other.imei == this.imei &&
          other.provider == this.provider &&
          other.warrantyMonths == this.warrantyMonths &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.status == this.status &&
          other.claimStatus == this.claimStatus &&
          other.evidenceRef == this.evidenceRef &&
          other.version == this.version &&
          other.serverVersion == this.serverVersion &&
          other.confirmationStatus == this.confirmationStatus &&
          other.dataModelVersion == this.dataModelVersion &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MobileWarrantiesCompanion extends UpdateCompanion<MobileWarrantyEntity> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> entityId;
  final Value<String> imei;
  final Value<String?> provider;
  final Value<int?> warrantyMonths;
  final Value<DateTime?> startDate;
  final Value<DateTime?> endDate;
  final Value<String> status;
  final Value<String?> claimStatus;
  final Value<String?> evidenceRef;
  final Value<int> version;
  final Value<int> serverVersion;
  final Value<String> confirmationStatus;
  final Value<int> dataModelVersion;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MobileWarrantiesCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.entityId = const Value.absent(),
    this.imei = const Value.absent(),
    this.provider = const Value.absent(),
    this.warrantyMonths = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.status = const Value.absent(),
    this.claimStatus = const Value.absent(),
    this.evidenceRef = const Value.absent(),
    this.version = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.confirmationStatus = const Value.absent(),
    this.dataModelVersion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MobileWarrantiesCompanion.insert({
    required String id,
    required String tenantId,
    required String entityId,
    required String imei,
    this.provider = const Value.absent(),
    this.warrantyMonths = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.status = const Value.absent(),
    this.claimStatus = const Value.absent(),
    this.evidenceRef = const Value.absent(),
    this.version = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.confirmationStatus = const Value.absent(),
    this.dataModelVersion = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       entityId = Value(entityId),
       imei = Value(imei),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MobileWarrantyEntity> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? entityId,
    Expression<String>? imei,
    Expression<String>? provider,
    Expression<int>? warrantyMonths,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<String>? status,
    Expression<String>? claimStatus,
    Expression<String>? evidenceRef,
    Expression<int>? version,
    Expression<int>? serverVersion,
    Expression<String>? confirmationStatus,
    Expression<int>? dataModelVersion,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (entityId != null) 'entity_id': entityId,
      if (imei != null) 'imei': imei,
      if (provider != null) 'provider': provider,
      if (warrantyMonths != null) 'warranty_months': warrantyMonths,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (status != null) 'status': status,
      if (claimStatus != null) 'claim_status': claimStatus,
      if (evidenceRef != null) 'evidence_ref': evidenceRef,
      if (version != null) 'version': version,
      if (serverVersion != null) 'server_version': serverVersion,
      if (confirmationStatus != null) 'confirmation_status': confirmationStatus,
      if (dataModelVersion != null) 'data_model_version': dataModelVersion,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MobileWarrantiesCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? entityId,
    Value<String>? imei,
    Value<String?>? provider,
    Value<int?>? warrantyMonths,
    Value<DateTime?>? startDate,
    Value<DateTime?>? endDate,
    Value<String>? status,
    Value<String?>? claimStatus,
    Value<String?>? evidenceRef,
    Value<int>? version,
    Value<int>? serverVersion,
    Value<String>? confirmationStatus,
    Value<int>? dataModelVersion,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MobileWarrantiesCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      entityId: entityId ?? this.entityId,
      imei: imei ?? this.imei,
      provider: provider ?? this.provider,
      warrantyMonths: warrantyMonths ?? this.warrantyMonths,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      claimStatus: claimStatus ?? this.claimStatus,
      evidenceRef: evidenceRef ?? this.evidenceRef,
      version: version ?? this.version,
      serverVersion: serverVersion ?? this.serverVersion,
      confirmationStatus: confirmationStatus ?? this.confirmationStatus,
      dataModelVersion: dataModelVersion ?? this.dataModelVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (imei.present) {
      map['imei'] = Variable<String>(imei.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (warrantyMonths.present) {
      map['warranty_months'] = Variable<int>(warrantyMonths.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (claimStatus.present) {
      map['claim_status'] = Variable<String>(claimStatus.value);
    }
    if (evidenceRef.present) {
      map['evidence_ref'] = Variable<String>(evidenceRef.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (confirmationStatus.present) {
      map['confirmation_status'] = Variable<String>(confirmationStatus.value);
    }
    if (dataModelVersion.present) {
      map['data_model_version'] = Variable<int>(dataModelVersion.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MobileWarrantiesCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('entityId: $entityId, ')
          ..write('imei: $imei, ')
          ..write('provider: $provider, ')
          ..write('warrantyMonths: $warrantyMonths, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('status: $status, ')
          ..write('claimStatus: $claimStatus, ')
          ..write('evidenceRef: $evidenceRef, ')
          ..write('version: $version, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('confirmationStatus: $confirmationStatus, ')
          ..write('dataModelVersion: $dataModelVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MobileReconciliationStatusTable extends MobileReconciliationStatus
    with
        TableInfo<
          $MobileReconciliationStatusTable,
          MobileReconciliationStatusEntity
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MobileReconciliationStatusTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reconciliationIdMeta = const VerificationMeta(
    'reconciliationId',
  );
  @override
  late final GeneratedColumn<String> reconciliationId = GeneratedColumn<String>(
    'reconciliation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PENDING'),
  );
  static const VerificationMeta _totalStepsMeta = const VerificationMeta(
    'totalSteps',
  );
  @override
  late final GeneratedColumn<int> totalSteps = GeneratedColumn<int>(
    'total_steps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedStepsMeta = const VerificationMeta(
    'completedSteps',
  );
  @override
  late final GeneratedColumn<int> completedSteps = GeneratedColumn<int>(
    'completed_steps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _latestErrorMeta = const VerificationMeta(
    'latestError',
  );
  @override
  late final GeneratedColumn<String> latestError = GeneratedColumn<String>(
    'latest_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _terminalEvidenceMeta = const VerificationMeta(
    'terminalEvidence',
  );
  @override
  late final GeneratedColumn<String> terminalEvidence = GeneratedColumn<String>(
    'terminal_evidence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dataModelVersionMeta = const VerificationMeta(
    'dataModelVersion',
  );
  @override
  late final GeneratedColumn<int> dataModelVersion = GeneratedColumn<int>(
    'data_model_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    operationId,
    reconciliationId,
    status,
    totalSteps,
    completedSteps,
    latestError,
    terminalEvidence,
    dataModelVersion,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mobile_reconciliation_status';
  @override
  VerificationContext validateIntegrity(
    Insertable<MobileReconciliationStatusEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('reconciliation_id')) {
      context.handle(
        _reconciliationIdMeta,
        reconciliationId.isAcceptableOrUnknown(
          data['reconciliation_id']!,
          _reconciliationIdMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('total_steps')) {
      context.handle(
        _totalStepsMeta,
        totalSteps.isAcceptableOrUnknown(data['total_steps']!, _totalStepsMeta),
      );
    }
    if (data.containsKey('completed_steps')) {
      context.handle(
        _completedStepsMeta,
        completedSteps.isAcceptableOrUnknown(
          data['completed_steps']!,
          _completedStepsMeta,
        ),
      );
    }
    if (data.containsKey('latest_error')) {
      context.handle(
        _latestErrorMeta,
        latestError.isAcceptableOrUnknown(
          data['latest_error']!,
          _latestErrorMeta,
        ),
      );
    }
    if (data.containsKey('terminal_evidence')) {
      context.handle(
        _terminalEvidenceMeta,
        terminalEvidence.isAcceptableOrUnknown(
          data['terminal_evidence']!,
          _terminalEvidenceMeta,
        ),
      );
    }
    if (data.containsKey('data_model_version')) {
      context.handle(
        _dataModelVersionMeta,
        dataModelVersion.isAcceptableOrUnknown(
          data['data_model_version']!,
          _dataModelVersionMeta,
        ),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {tenantId, operationId},
  ];
  @override
  MobileReconciliationStatusEntity map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MobileReconciliationStatusEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      reconciliationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reconciliation_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      totalSteps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_steps'],
      )!,
      completedSteps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_steps'],
      )!,
      latestError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}latest_error'],
      ),
      terminalEvidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}terminal_evidence'],
      ),
      dataModelVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}data_model_version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MobileReconciliationStatusTable createAlias(String alias) {
    return $MobileReconciliationStatusTable(attachedDatabase, alias);
  }
}

class MobileReconciliationStatusEntity extends DataClass
    implements Insertable<MobileReconciliationStatusEntity> {
  final String id;
  final String tenantId;

  /// The operation that triggered reconciliation.
  final String operationId;

  /// Reconciliation record ID from the server.
  final String? reconciliationId;

  /// Current reconciliation status (PENDING, IN_PROGRESS, COMPLETED, FAILED).
  final String status;

  /// Total steps in the reconciliation plan.
  final int totalSteps;

  /// Steps completed so far.
  final int completedSteps;

  /// Latest error message if any step failed.
  final String? latestError;

  /// Terminal state evidence (e.g., JSON summary).
  final String? terminalEvidence;
  final int dataModelVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MobileReconciliationStatusEntity({
    required this.id,
    required this.tenantId,
    required this.operationId,
    this.reconciliationId,
    required this.status,
    required this.totalSteps,
    required this.completedSteps,
    this.latestError,
    this.terminalEvidence,
    required this.dataModelVersion,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['operation_id'] = Variable<String>(operationId);
    if (!nullToAbsent || reconciliationId != null) {
      map['reconciliation_id'] = Variable<String>(reconciliationId);
    }
    map['status'] = Variable<String>(status);
    map['total_steps'] = Variable<int>(totalSteps);
    map['completed_steps'] = Variable<int>(completedSteps);
    if (!nullToAbsent || latestError != null) {
      map['latest_error'] = Variable<String>(latestError);
    }
    if (!nullToAbsent || terminalEvidence != null) {
      map['terminal_evidence'] = Variable<String>(terminalEvidence);
    }
    map['data_model_version'] = Variable<int>(dataModelVersion);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MobileReconciliationStatusCompanion toCompanion(bool nullToAbsent) {
    return MobileReconciliationStatusCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      operationId: Value(operationId),
      reconciliationId: reconciliationId == null && nullToAbsent
          ? const Value.absent()
          : Value(reconciliationId),
      status: Value(status),
      totalSteps: Value(totalSteps),
      completedSteps: Value(completedSteps),
      latestError: latestError == null && nullToAbsent
          ? const Value.absent()
          : Value(latestError),
      terminalEvidence: terminalEvidence == null && nullToAbsent
          ? const Value.absent()
          : Value(terminalEvidence),
      dataModelVersion: Value(dataModelVersion),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MobileReconciliationStatusEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MobileReconciliationStatusEntity(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      operationId: serializer.fromJson<String>(json['operationId']),
      reconciliationId: serializer.fromJson<String?>(json['reconciliationId']),
      status: serializer.fromJson<String>(json['status']),
      totalSteps: serializer.fromJson<int>(json['totalSteps']),
      completedSteps: serializer.fromJson<int>(json['completedSteps']),
      latestError: serializer.fromJson<String?>(json['latestError']),
      terminalEvidence: serializer.fromJson<String?>(json['terminalEvidence']),
      dataModelVersion: serializer.fromJson<int>(json['dataModelVersion']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'operationId': serializer.toJson<String>(operationId),
      'reconciliationId': serializer.toJson<String?>(reconciliationId),
      'status': serializer.toJson<String>(status),
      'totalSteps': serializer.toJson<int>(totalSteps),
      'completedSteps': serializer.toJson<int>(completedSteps),
      'latestError': serializer.toJson<String?>(latestError),
      'terminalEvidence': serializer.toJson<String?>(terminalEvidence),
      'dataModelVersion': serializer.toJson<int>(dataModelVersion),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MobileReconciliationStatusEntity copyWith({
    String? id,
    String? tenantId,
    String? operationId,
    Value<String?> reconciliationId = const Value.absent(),
    String? status,
    int? totalSteps,
    int? completedSteps,
    Value<String?> latestError = const Value.absent(),
    Value<String?> terminalEvidence = const Value.absent(),
    int? dataModelVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MobileReconciliationStatusEntity(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    operationId: operationId ?? this.operationId,
    reconciliationId: reconciliationId.present
        ? reconciliationId.value
        : this.reconciliationId,
    status: status ?? this.status,
    totalSteps: totalSteps ?? this.totalSteps,
    completedSteps: completedSteps ?? this.completedSteps,
    latestError: latestError.present ? latestError.value : this.latestError,
    terminalEvidence: terminalEvidence.present
        ? terminalEvidence.value
        : this.terminalEvidence,
    dataModelVersion: dataModelVersion ?? this.dataModelVersion,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MobileReconciliationStatusEntity copyWithCompanion(
    MobileReconciliationStatusCompanion data,
  ) {
    return MobileReconciliationStatusEntity(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      reconciliationId: data.reconciliationId.present
          ? data.reconciliationId.value
          : this.reconciliationId,
      status: data.status.present ? data.status.value : this.status,
      totalSteps: data.totalSteps.present
          ? data.totalSteps.value
          : this.totalSteps,
      completedSteps: data.completedSteps.present
          ? data.completedSteps.value
          : this.completedSteps,
      latestError: data.latestError.present
          ? data.latestError.value
          : this.latestError,
      terminalEvidence: data.terminalEvidence.present
          ? data.terminalEvidence.value
          : this.terminalEvidence,
      dataModelVersion: data.dataModelVersion.present
          ? data.dataModelVersion.value
          : this.dataModelVersion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MobileReconciliationStatusEntity(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('operationId: $operationId, ')
          ..write('reconciliationId: $reconciliationId, ')
          ..write('status: $status, ')
          ..write('totalSteps: $totalSteps, ')
          ..write('completedSteps: $completedSteps, ')
          ..write('latestError: $latestError, ')
          ..write('terminalEvidence: $terminalEvidence, ')
          ..write('dataModelVersion: $dataModelVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    operationId,
    reconciliationId,
    status,
    totalSteps,
    completedSteps,
    latestError,
    terminalEvidence,
    dataModelVersion,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MobileReconciliationStatusEntity &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.operationId == this.operationId &&
          other.reconciliationId == this.reconciliationId &&
          other.status == this.status &&
          other.totalSteps == this.totalSteps &&
          other.completedSteps == this.completedSteps &&
          other.latestError == this.latestError &&
          other.terminalEvidence == this.terminalEvidence &&
          other.dataModelVersion == this.dataModelVersion &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MobileReconciliationStatusCompanion
    extends UpdateCompanion<MobileReconciliationStatusEntity> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> operationId;
  final Value<String?> reconciliationId;
  final Value<String> status;
  final Value<int> totalSteps;
  final Value<int> completedSteps;
  final Value<String?> latestError;
  final Value<String?> terminalEvidence;
  final Value<int> dataModelVersion;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MobileReconciliationStatusCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.operationId = const Value.absent(),
    this.reconciliationId = const Value.absent(),
    this.status = const Value.absent(),
    this.totalSteps = const Value.absent(),
    this.completedSteps = const Value.absent(),
    this.latestError = const Value.absent(),
    this.terminalEvidence = const Value.absent(),
    this.dataModelVersion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MobileReconciliationStatusCompanion.insert({
    required String id,
    required String tenantId,
    required String operationId,
    this.reconciliationId = const Value.absent(),
    this.status = const Value.absent(),
    this.totalSteps = const Value.absent(),
    this.completedSteps = const Value.absent(),
    this.latestError = const Value.absent(),
    this.terminalEvidence = const Value.absent(),
    this.dataModelVersion = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       operationId = Value(operationId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MobileReconciliationStatusEntity> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? operationId,
    Expression<String>? reconciliationId,
    Expression<String>? status,
    Expression<int>? totalSteps,
    Expression<int>? completedSteps,
    Expression<String>? latestError,
    Expression<String>? terminalEvidence,
    Expression<int>? dataModelVersion,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (operationId != null) 'operation_id': operationId,
      if (reconciliationId != null) 'reconciliation_id': reconciliationId,
      if (status != null) 'status': status,
      if (totalSteps != null) 'total_steps': totalSteps,
      if (completedSteps != null) 'completed_steps': completedSteps,
      if (latestError != null) 'latest_error': latestError,
      if (terminalEvidence != null) 'terminal_evidence': terminalEvidence,
      if (dataModelVersion != null) 'data_model_version': dataModelVersion,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MobileReconciliationStatusCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? operationId,
    Value<String?>? reconciliationId,
    Value<String>? status,
    Value<int>? totalSteps,
    Value<int>? completedSteps,
    Value<String?>? latestError,
    Value<String?>? terminalEvidence,
    Value<int>? dataModelVersion,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MobileReconciliationStatusCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      operationId: operationId ?? this.operationId,
      reconciliationId: reconciliationId ?? this.reconciliationId,
      status: status ?? this.status,
      totalSteps: totalSteps ?? this.totalSteps,
      completedSteps: completedSteps ?? this.completedSteps,
      latestError: latestError ?? this.latestError,
      terminalEvidence: terminalEvidence ?? this.terminalEvidence,
      dataModelVersion: dataModelVersion ?? this.dataModelVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (reconciliationId.present) {
      map['reconciliation_id'] = Variable<String>(reconciliationId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (totalSteps.present) {
      map['total_steps'] = Variable<int>(totalSteps.value);
    }
    if (completedSteps.present) {
      map['completed_steps'] = Variable<int>(completedSteps.value);
    }
    if (latestError.present) {
      map['latest_error'] = Variable<String>(latestError.value);
    }
    if (terminalEvidence.present) {
      map['terminal_evidence'] = Variable<String>(terminalEvidence.value);
    }
    if (dataModelVersion.present) {
      map['data_model_version'] = Variable<int>(dataModelVersion.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MobileReconciliationStatusCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('operationId: $operationId, ')
          ..write('reconciliationId: $reconciliationId, ')
          ..write('status: $status, ')
          ..write('totalSteps: $totalSteps, ')
          ..write('completedSteps: $completedSteps, ')
          ..write('latestError: $latestError, ')
          ..write('terminalEvidence: $terminalEvidence, ')
          ..write('dataModelVersion: $dataModelVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MobileProviderStateTable extends MobileProviderState
    with TableInfo<$MobileProviderStateTable, MobileProviderStateEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MobileProviderStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerRequestIdMeta = const VerificationMeta(
    'providerRequestId',
  );
  @override
  late final GeneratedColumn<String> providerRequestId =
      GeneratedColumn<String>(
        'provider_request_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _providerTypeMeta = const VerificationMeta(
    'providerType',
  );
  @override
  late final GeneratedColumn<String> providerType = GeneratedColumn<String>(
    'provider_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requestPayloadMeta = const VerificationMeta(
    'requestPayload',
  );
  @override
  late final GeneratedColumn<String> requestPayload = GeneratedColumn<String>(
    'request_payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _responseStatusMeta = const VerificationMeta(
    'responseStatus',
  );
  @override
  late final GeneratedColumn<String> responseStatus = GeneratedColumn<String>(
    'response_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PENDING'),
  );
  static const VerificationMeta _responsePayloadMeta = const VerificationMeta(
    'responsePayload',
  );
  @override
  late final GeneratedColumn<String> responsePayload = GeneratedColumn<String>(
    'response_payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _externalRefMeta = const VerificationMeta(
    'externalRef',
  );
  @override
  late final GeneratedColumn<String> externalRef = GeneratedColumn<String>(
    'external_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dataModelVersionMeta = const VerificationMeta(
    'dataModelVersion',
  );
  @override
  late final GeneratedColumn<int> dataModelVersion = GeneratedColumn<int>(
    'data_model_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    operationId,
    providerRequestId,
    providerType,
    requestPayload,
    responseStatus,
    responsePayload,
    externalRef,
    dataModelVersion,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mobile_provider_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<MobileProviderStateEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('provider_request_id')) {
      context.handle(
        _providerRequestIdMeta,
        providerRequestId.isAcceptableOrUnknown(
          data['provider_request_id']!,
          _providerRequestIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerRequestIdMeta);
    }
    if (data.containsKey('provider_type')) {
      context.handle(
        _providerTypeMeta,
        providerType.isAcceptableOrUnknown(
          data['provider_type']!,
          _providerTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerTypeMeta);
    }
    if (data.containsKey('request_payload')) {
      context.handle(
        _requestPayloadMeta,
        requestPayload.isAcceptableOrUnknown(
          data['request_payload']!,
          _requestPayloadMeta,
        ),
      );
    }
    if (data.containsKey('response_status')) {
      context.handle(
        _responseStatusMeta,
        responseStatus.isAcceptableOrUnknown(
          data['response_status']!,
          _responseStatusMeta,
        ),
      );
    }
    if (data.containsKey('response_payload')) {
      context.handle(
        _responsePayloadMeta,
        responsePayload.isAcceptableOrUnknown(
          data['response_payload']!,
          _responsePayloadMeta,
        ),
      );
    }
    if (data.containsKey('external_ref')) {
      context.handle(
        _externalRefMeta,
        externalRef.isAcceptableOrUnknown(
          data['external_ref']!,
          _externalRefMeta,
        ),
      );
    }
    if (data.containsKey('data_model_version')) {
      context.handle(
        _dataModelVersionMeta,
        dataModelVersion.isAcceptableOrUnknown(
          data['data_model_version']!,
          _dataModelVersionMeta,
        ),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {tenantId, operationId, providerType},
  ];
  @override
  MobileProviderStateEntity map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MobileProviderStateEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      providerRequestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_request_id'],
      )!,
      providerType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_type'],
      )!,
      requestPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_payload'],
      ),
      responseStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}response_status'],
      )!,
      responsePayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}response_payload'],
      ),
      externalRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_ref'],
      ),
      dataModelVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}data_model_version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MobileProviderStateTable createAlias(String alias) {
    return $MobileProviderStateTable(attachedDatabase, alias);
  }
}

class MobileProviderStateEntity extends DataClass
    implements Insertable<MobileProviderStateEntity> {
  final String id;
  final String tenantId;

  /// The operation that initiated the provider request.
  final String operationId;

  /// Stable provider request identity for retry safety.
  final String providerRequestId;

  /// Provider type (FINANCE, RECHARGE, OCR, COMPLIANCE, EWAY).
  final String providerType;

  /// Request payload (JSON).
  final String? requestPayload;

  /// Provider response status (PENDING, SUCCESS, FAILED, AMBIGUOUS).
  final String responseStatus;

  /// Provider response payload (JSON).
  final String? responsePayload;

  /// External provider reference (transaction ID, etc).
  final String? externalRef;
  final int dataModelVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MobileProviderStateEntity({
    required this.id,
    required this.tenantId,
    required this.operationId,
    required this.providerRequestId,
    required this.providerType,
    this.requestPayload,
    required this.responseStatus,
    this.responsePayload,
    this.externalRef,
    required this.dataModelVersion,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['operation_id'] = Variable<String>(operationId);
    map['provider_request_id'] = Variable<String>(providerRequestId);
    map['provider_type'] = Variable<String>(providerType);
    if (!nullToAbsent || requestPayload != null) {
      map['request_payload'] = Variable<String>(requestPayload);
    }
    map['response_status'] = Variable<String>(responseStatus);
    if (!nullToAbsent || responsePayload != null) {
      map['response_payload'] = Variable<String>(responsePayload);
    }
    if (!nullToAbsent || externalRef != null) {
      map['external_ref'] = Variable<String>(externalRef);
    }
    map['data_model_version'] = Variable<int>(dataModelVersion);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MobileProviderStateCompanion toCompanion(bool nullToAbsent) {
    return MobileProviderStateCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      operationId: Value(operationId),
      providerRequestId: Value(providerRequestId),
      providerType: Value(providerType),
      requestPayload: requestPayload == null && nullToAbsent
          ? const Value.absent()
          : Value(requestPayload),
      responseStatus: Value(responseStatus),
      responsePayload: responsePayload == null && nullToAbsent
          ? const Value.absent()
          : Value(responsePayload),
      externalRef: externalRef == null && nullToAbsent
          ? const Value.absent()
          : Value(externalRef),
      dataModelVersion: Value(dataModelVersion),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MobileProviderStateEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MobileProviderStateEntity(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      operationId: serializer.fromJson<String>(json['operationId']),
      providerRequestId: serializer.fromJson<String>(json['providerRequestId']),
      providerType: serializer.fromJson<String>(json['providerType']),
      requestPayload: serializer.fromJson<String?>(json['requestPayload']),
      responseStatus: serializer.fromJson<String>(json['responseStatus']),
      responsePayload: serializer.fromJson<String?>(json['responsePayload']),
      externalRef: serializer.fromJson<String?>(json['externalRef']),
      dataModelVersion: serializer.fromJson<int>(json['dataModelVersion']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'operationId': serializer.toJson<String>(operationId),
      'providerRequestId': serializer.toJson<String>(providerRequestId),
      'providerType': serializer.toJson<String>(providerType),
      'requestPayload': serializer.toJson<String?>(requestPayload),
      'responseStatus': serializer.toJson<String>(responseStatus),
      'responsePayload': serializer.toJson<String?>(responsePayload),
      'externalRef': serializer.toJson<String?>(externalRef),
      'dataModelVersion': serializer.toJson<int>(dataModelVersion),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MobileProviderStateEntity copyWith({
    String? id,
    String? tenantId,
    String? operationId,
    String? providerRequestId,
    String? providerType,
    Value<String?> requestPayload = const Value.absent(),
    String? responseStatus,
    Value<String?> responsePayload = const Value.absent(),
    Value<String?> externalRef = const Value.absent(),
    int? dataModelVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MobileProviderStateEntity(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    operationId: operationId ?? this.operationId,
    providerRequestId: providerRequestId ?? this.providerRequestId,
    providerType: providerType ?? this.providerType,
    requestPayload: requestPayload.present
        ? requestPayload.value
        : this.requestPayload,
    responseStatus: responseStatus ?? this.responseStatus,
    responsePayload: responsePayload.present
        ? responsePayload.value
        : this.responsePayload,
    externalRef: externalRef.present ? externalRef.value : this.externalRef,
    dataModelVersion: dataModelVersion ?? this.dataModelVersion,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MobileProviderStateEntity copyWithCompanion(
    MobileProviderStateCompanion data,
  ) {
    return MobileProviderStateEntity(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      providerRequestId: data.providerRequestId.present
          ? data.providerRequestId.value
          : this.providerRequestId,
      providerType: data.providerType.present
          ? data.providerType.value
          : this.providerType,
      requestPayload: data.requestPayload.present
          ? data.requestPayload.value
          : this.requestPayload,
      responseStatus: data.responseStatus.present
          ? data.responseStatus.value
          : this.responseStatus,
      responsePayload: data.responsePayload.present
          ? data.responsePayload.value
          : this.responsePayload,
      externalRef: data.externalRef.present
          ? data.externalRef.value
          : this.externalRef,
      dataModelVersion: data.dataModelVersion.present
          ? data.dataModelVersion.value
          : this.dataModelVersion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MobileProviderStateEntity(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('operationId: $operationId, ')
          ..write('providerRequestId: $providerRequestId, ')
          ..write('providerType: $providerType, ')
          ..write('requestPayload: $requestPayload, ')
          ..write('responseStatus: $responseStatus, ')
          ..write('responsePayload: $responsePayload, ')
          ..write('externalRef: $externalRef, ')
          ..write('dataModelVersion: $dataModelVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    operationId,
    providerRequestId,
    providerType,
    requestPayload,
    responseStatus,
    responsePayload,
    externalRef,
    dataModelVersion,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MobileProviderStateEntity &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.operationId == this.operationId &&
          other.providerRequestId == this.providerRequestId &&
          other.providerType == this.providerType &&
          other.requestPayload == this.requestPayload &&
          other.responseStatus == this.responseStatus &&
          other.responsePayload == this.responsePayload &&
          other.externalRef == this.externalRef &&
          other.dataModelVersion == this.dataModelVersion &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MobileProviderStateCompanion
    extends UpdateCompanion<MobileProviderStateEntity> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> operationId;
  final Value<String> providerRequestId;
  final Value<String> providerType;
  final Value<String?> requestPayload;
  final Value<String> responseStatus;
  final Value<String?> responsePayload;
  final Value<String?> externalRef;
  final Value<int> dataModelVersion;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MobileProviderStateCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.operationId = const Value.absent(),
    this.providerRequestId = const Value.absent(),
    this.providerType = const Value.absent(),
    this.requestPayload = const Value.absent(),
    this.responseStatus = const Value.absent(),
    this.responsePayload = const Value.absent(),
    this.externalRef = const Value.absent(),
    this.dataModelVersion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MobileProviderStateCompanion.insert({
    required String id,
    required String tenantId,
    required String operationId,
    required String providerRequestId,
    required String providerType,
    this.requestPayload = const Value.absent(),
    this.responseStatus = const Value.absent(),
    this.responsePayload = const Value.absent(),
    this.externalRef = const Value.absent(),
    this.dataModelVersion = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       operationId = Value(operationId),
       providerRequestId = Value(providerRequestId),
       providerType = Value(providerType),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MobileProviderStateEntity> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? operationId,
    Expression<String>? providerRequestId,
    Expression<String>? providerType,
    Expression<String>? requestPayload,
    Expression<String>? responseStatus,
    Expression<String>? responsePayload,
    Expression<String>? externalRef,
    Expression<int>? dataModelVersion,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (operationId != null) 'operation_id': operationId,
      if (providerRequestId != null) 'provider_request_id': providerRequestId,
      if (providerType != null) 'provider_type': providerType,
      if (requestPayload != null) 'request_payload': requestPayload,
      if (responseStatus != null) 'response_status': responseStatus,
      if (responsePayload != null) 'response_payload': responsePayload,
      if (externalRef != null) 'external_ref': externalRef,
      if (dataModelVersion != null) 'data_model_version': dataModelVersion,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MobileProviderStateCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? operationId,
    Value<String>? providerRequestId,
    Value<String>? providerType,
    Value<String?>? requestPayload,
    Value<String>? responseStatus,
    Value<String?>? responsePayload,
    Value<String?>? externalRef,
    Value<int>? dataModelVersion,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MobileProviderStateCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      operationId: operationId ?? this.operationId,
      providerRequestId: providerRequestId ?? this.providerRequestId,
      providerType: providerType ?? this.providerType,
      requestPayload: requestPayload ?? this.requestPayload,
      responseStatus: responseStatus ?? this.responseStatus,
      responsePayload: responsePayload ?? this.responsePayload,
      externalRef: externalRef ?? this.externalRef,
      dataModelVersion: dataModelVersion ?? this.dataModelVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (providerRequestId.present) {
      map['provider_request_id'] = Variable<String>(providerRequestId.value);
    }
    if (providerType.present) {
      map['provider_type'] = Variable<String>(providerType.value);
    }
    if (requestPayload.present) {
      map['request_payload'] = Variable<String>(requestPayload.value);
    }
    if (responseStatus.present) {
      map['response_status'] = Variable<String>(responseStatus.value);
    }
    if (responsePayload.present) {
      map['response_payload'] = Variable<String>(responsePayload.value);
    }
    if (externalRef.present) {
      map['external_ref'] = Variable<String>(externalRef.value);
    }
    if (dataModelVersion.present) {
      map['data_model_version'] = Variable<int>(dataModelVersion.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MobileProviderStateCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('operationId: $operationId, ')
          ..write('providerRequestId: $providerRequestId, ')
          ..write('providerType: $providerType, ')
          ..write('requestPayload: $requestPayload, ')
          ..write('responseStatus: $responseStatus, ')
          ..write('responsePayload: $responsePayload, ')
          ..write('externalRef: $externalRef, ')
          ..write('dataModelVersion: $dataModelVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MobileOutboxMutationsTable extends MobileOutboxMutations
    with TableInfo<$MobileOutboxMutationsTable, MobileOutboxMutationEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MobileOutboxMutationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mutationFingerprintMeta =
      const VerificationMeta('mutationFingerprint');
  @override
  late final GeneratedColumn<String> mutationFingerprint =
      GeneratedColumn<String>(
        'mutation_fingerprint',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseVersionsMeta = const VerificationMeta(
    'baseVersions',
  );
  @override
  late final GeneratedColumn<String> baseVersions = GeneratedColumn<String>(
    'base_versions',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dependenciesMeta = const VerificationMeta(
    'dependencies',
  );
  @override
  late final GeneratedColumn<String> dependencies = GeneratedColumn<String>(
    'dependencies',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _maxRetriesMeta = const VerificationMeta(
    'maxRetries',
  );
  @override
  late final GeneratedColumn<int> maxRetries = GeneratedColumn<int>(
    'max_retries',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('queued'),
  );
  static const VerificationMeta _dataModelVersionMeta = const VerificationMeta(
    'dataModelVersion',
  );
  @override
  late final GeneratedColumn<int> dataModelVersion = GeneratedColumn<int>(
    'data_model_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    operationId,
    mutationFingerprint,
    entityType,
    payload,
    baseVersions,
    dependencies,
    retryCount,
    maxRetries,
    status,
    dataModelVersion,
    createdAt,
    lastAttemptAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mobile_outbox_mutations';
  @override
  VerificationContext validateIntegrity(
    Insertable<MobileOutboxMutationEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('mutation_fingerprint')) {
      context.handle(
        _mutationFingerprintMeta,
        mutationFingerprint.isAcceptableOrUnknown(
          data['mutation_fingerprint']!,
          _mutationFingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mutationFingerprintMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('base_versions')) {
      context.handle(
        _baseVersionsMeta,
        baseVersions.isAcceptableOrUnknown(
          data['base_versions']!,
          _baseVersionsMeta,
        ),
      );
    }
    if (data.containsKey('dependencies')) {
      context.handle(
        _dependenciesMeta,
        dependencies.isAcceptableOrUnknown(
          data['dependencies']!,
          _dependenciesMeta,
        ),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('max_retries')) {
      context.handle(
        _maxRetriesMeta,
        maxRetries.isAcceptableOrUnknown(data['max_retries']!, _maxRetriesMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('data_model_version')) {
      context.handle(
        _dataModelVersionMeta,
        dataModelVersion.isAcceptableOrUnknown(
          data['data_model_version']!,
          _dataModelVersionMeta,
        ),
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
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {tenantId, operationId},
  ];
  @override
  MobileOutboxMutationEntity map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MobileOutboxMutationEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      mutationFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_fingerprint'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      baseVersions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_versions'],
      ),
      dependencies: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dependencies'],
      ),
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      maxRetries: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_retries'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      dataModelVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}data_model_version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MobileOutboxMutationsTable createAlias(String alias) {
    return $MobileOutboxMutationsTable(attachedDatabase, alias);
  }
}

class MobileOutboxMutationEntity extends DataClass
    implements Insertable<MobileOutboxMutationEntity> {
  final String id;
  final String tenantId;

  /// Idempotent operation identifier — reused on every retry.
  final String operationId;

  /// Deterministic digest of immutable request fields.
  final String mutationFingerprint;

  /// Entity type being mutated (IMEI_UNIT, INVOICE, SERVICE_JOB, etc).
  final String entityType;

  /// Full mutation payload serialized as JSON.
  final String payload;

  /// Expected entity versions for conditional writes (JSON map).
  final String? baseVersions;

  /// Operation IDs this mutation depends on (JSON array).
  final String? dependencies;

  /// Number of push attempts made.
  final int retryCount;

  /// Maximum retries before moving to dead-letter state.
  final int maxRetries;

  /// Outbox status: queued | sending | sent | failed.
  final String status;

  /// Data model version for schema compatibility.
  final int dataModelVersion;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final DateTime updatedAt;
  const MobileOutboxMutationEntity({
    required this.id,
    required this.tenantId,
    required this.operationId,
    required this.mutationFingerprint,
    required this.entityType,
    required this.payload,
    this.baseVersions,
    this.dependencies,
    required this.retryCount,
    required this.maxRetries,
    required this.status,
    required this.dataModelVersion,
    required this.createdAt,
    this.lastAttemptAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['operation_id'] = Variable<String>(operationId);
    map['mutation_fingerprint'] = Variable<String>(mutationFingerprint);
    map['entity_type'] = Variable<String>(entityType);
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || baseVersions != null) {
      map['base_versions'] = Variable<String>(baseVersions);
    }
    if (!nullToAbsent || dependencies != null) {
      map['dependencies'] = Variable<String>(dependencies);
    }
    map['retry_count'] = Variable<int>(retryCount);
    map['max_retries'] = Variable<int>(maxRetries);
    map['status'] = Variable<String>(status);
    map['data_model_version'] = Variable<int>(dataModelVersion);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MobileOutboxMutationsCompanion toCompanion(bool nullToAbsent) {
    return MobileOutboxMutationsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      operationId: Value(operationId),
      mutationFingerprint: Value(mutationFingerprint),
      entityType: Value(entityType),
      payload: Value(payload),
      baseVersions: baseVersions == null && nullToAbsent
          ? const Value.absent()
          : Value(baseVersions),
      dependencies: dependencies == null && nullToAbsent
          ? const Value.absent()
          : Value(dependencies),
      retryCount: Value(retryCount),
      maxRetries: Value(maxRetries),
      status: Value(status),
      dataModelVersion: Value(dataModelVersion),
      createdAt: Value(createdAt),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MobileOutboxMutationEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MobileOutboxMutationEntity(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      operationId: serializer.fromJson<String>(json['operationId']),
      mutationFingerprint: serializer.fromJson<String>(
        json['mutationFingerprint'],
      ),
      entityType: serializer.fromJson<String>(json['entityType']),
      payload: serializer.fromJson<String>(json['payload']),
      baseVersions: serializer.fromJson<String?>(json['baseVersions']),
      dependencies: serializer.fromJson<String?>(json['dependencies']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      maxRetries: serializer.fromJson<int>(json['maxRetries']),
      status: serializer.fromJson<String>(json['status']),
      dataModelVersion: serializer.fromJson<int>(json['dataModelVersion']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'operationId': serializer.toJson<String>(operationId),
      'mutationFingerprint': serializer.toJson<String>(mutationFingerprint),
      'entityType': serializer.toJson<String>(entityType),
      'payload': serializer.toJson<String>(payload),
      'baseVersions': serializer.toJson<String?>(baseVersions),
      'dependencies': serializer.toJson<String?>(dependencies),
      'retryCount': serializer.toJson<int>(retryCount),
      'maxRetries': serializer.toJson<int>(maxRetries),
      'status': serializer.toJson<String>(status),
      'dataModelVersion': serializer.toJson<int>(dataModelVersion),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MobileOutboxMutationEntity copyWith({
    String? id,
    String? tenantId,
    String? operationId,
    String? mutationFingerprint,
    String? entityType,
    String? payload,
    Value<String?> baseVersions = const Value.absent(),
    Value<String?> dependencies = const Value.absent(),
    int? retryCount,
    int? maxRetries,
    String? status,
    int? dataModelVersion,
    DateTime? createdAt,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    DateTime? updatedAt,
  }) => MobileOutboxMutationEntity(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    operationId: operationId ?? this.operationId,
    mutationFingerprint: mutationFingerprint ?? this.mutationFingerprint,
    entityType: entityType ?? this.entityType,
    payload: payload ?? this.payload,
    baseVersions: baseVersions.present ? baseVersions.value : this.baseVersions,
    dependencies: dependencies.present ? dependencies.value : this.dependencies,
    retryCount: retryCount ?? this.retryCount,
    maxRetries: maxRetries ?? this.maxRetries,
    status: status ?? this.status,
    dataModelVersion: dataModelVersion ?? this.dataModelVersion,
    createdAt: createdAt ?? this.createdAt,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MobileOutboxMutationEntity copyWithCompanion(
    MobileOutboxMutationsCompanion data,
  ) {
    return MobileOutboxMutationEntity(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      mutationFingerprint: data.mutationFingerprint.present
          ? data.mutationFingerprint.value
          : this.mutationFingerprint,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      payload: data.payload.present ? data.payload.value : this.payload,
      baseVersions: data.baseVersions.present
          ? data.baseVersions.value
          : this.baseVersions,
      dependencies: data.dependencies.present
          ? data.dependencies.value
          : this.dependencies,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      maxRetries: data.maxRetries.present
          ? data.maxRetries.value
          : this.maxRetries,
      status: data.status.present ? data.status.value : this.status,
      dataModelVersion: data.dataModelVersion.present
          ? data.dataModelVersion.value
          : this.dataModelVersion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MobileOutboxMutationEntity(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('operationId: $operationId, ')
          ..write('mutationFingerprint: $mutationFingerprint, ')
          ..write('entityType: $entityType, ')
          ..write('payload: $payload, ')
          ..write('baseVersions: $baseVersions, ')
          ..write('dependencies: $dependencies, ')
          ..write('retryCount: $retryCount, ')
          ..write('maxRetries: $maxRetries, ')
          ..write('status: $status, ')
          ..write('dataModelVersion: $dataModelVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    operationId,
    mutationFingerprint,
    entityType,
    payload,
    baseVersions,
    dependencies,
    retryCount,
    maxRetries,
    status,
    dataModelVersion,
    createdAt,
    lastAttemptAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MobileOutboxMutationEntity &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.operationId == this.operationId &&
          other.mutationFingerprint == this.mutationFingerprint &&
          other.entityType == this.entityType &&
          other.payload == this.payload &&
          other.baseVersions == this.baseVersions &&
          other.dependencies == this.dependencies &&
          other.retryCount == this.retryCount &&
          other.maxRetries == this.maxRetries &&
          other.status == this.status &&
          other.dataModelVersion == this.dataModelVersion &&
          other.createdAt == this.createdAt &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.updatedAt == this.updatedAt);
}

class MobileOutboxMutationsCompanion
    extends UpdateCompanion<MobileOutboxMutationEntity> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> operationId;
  final Value<String> mutationFingerprint;
  final Value<String> entityType;
  final Value<String> payload;
  final Value<String?> baseVersions;
  final Value<String?> dependencies;
  final Value<int> retryCount;
  final Value<int> maxRetries;
  final Value<String> status;
  final Value<int> dataModelVersion;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MobileOutboxMutationsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.operationId = const Value.absent(),
    this.mutationFingerprint = const Value.absent(),
    this.entityType = const Value.absent(),
    this.payload = const Value.absent(),
    this.baseVersions = const Value.absent(),
    this.dependencies = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.maxRetries = const Value.absent(),
    this.status = const Value.absent(),
    this.dataModelVersion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MobileOutboxMutationsCompanion.insert({
    required String id,
    required String tenantId,
    required String operationId,
    required String mutationFingerprint,
    required String entityType,
    required String payload,
    this.baseVersions = const Value.absent(),
    this.dependencies = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.maxRetries = const Value.absent(),
    this.status = const Value.absent(),
    this.dataModelVersion = const Value.absent(),
    required DateTime createdAt,
    this.lastAttemptAt = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       operationId = Value(operationId),
       mutationFingerprint = Value(mutationFingerprint),
       entityType = Value(entityType),
       payload = Value(payload),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MobileOutboxMutationEntity> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? operationId,
    Expression<String>? mutationFingerprint,
    Expression<String>? entityType,
    Expression<String>? payload,
    Expression<String>? baseVersions,
    Expression<String>? dependencies,
    Expression<int>? retryCount,
    Expression<int>? maxRetries,
    Expression<String>? status,
    Expression<int>? dataModelVersion,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastAttemptAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (operationId != null) 'operation_id': operationId,
      if (mutationFingerprint != null)
        'mutation_fingerprint': mutationFingerprint,
      if (entityType != null) 'entity_type': entityType,
      if (payload != null) 'payload': payload,
      if (baseVersions != null) 'base_versions': baseVersions,
      if (dependencies != null) 'dependencies': dependencies,
      if (retryCount != null) 'retry_count': retryCount,
      if (maxRetries != null) 'max_retries': maxRetries,
      if (status != null) 'status': status,
      if (dataModelVersion != null) 'data_model_version': dataModelVersion,
      if (createdAt != null) 'created_at': createdAt,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MobileOutboxMutationsCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? operationId,
    Value<String>? mutationFingerprint,
    Value<String>? entityType,
    Value<String>? payload,
    Value<String?>? baseVersions,
    Value<String?>? dependencies,
    Value<int>? retryCount,
    Value<int>? maxRetries,
    Value<String>? status,
    Value<int>? dataModelVersion,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastAttemptAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MobileOutboxMutationsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      operationId: operationId ?? this.operationId,
      mutationFingerprint: mutationFingerprint ?? this.mutationFingerprint,
      entityType: entityType ?? this.entityType,
      payload: payload ?? this.payload,
      baseVersions: baseVersions ?? this.baseVersions,
      dependencies: dependencies ?? this.dependencies,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      status: status ?? this.status,
      dataModelVersion: dataModelVersion ?? this.dataModelVersion,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (mutationFingerprint.present) {
      map['mutation_fingerprint'] = Variable<String>(mutationFingerprint.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (baseVersions.present) {
      map['base_versions'] = Variable<String>(baseVersions.value);
    }
    if (dependencies.present) {
      map['dependencies'] = Variable<String>(dependencies.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (maxRetries.present) {
      map['max_retries'] = Variable<int>(maxRetries.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (dataModelVersion.present) {
      map['data_model_version'] = Variable<int>(dataModelVersion.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MobileOutboxMutationsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('operationId: $operationId, ')
          ..write('mutationFingerprint: $mutationFingerprint, ')
          ..write('entityType: $entityType, ')
          ..write('payload: $payload, ')
          ..write('baseVersions: $baseVersions, ')
          ..write('dependencies: $dependencies, ')
          ..write('retryCount: $retryCount, ')
          ..write('maxRetries: $maxRetries, ')
          ..write('status: $status, ')
          ..write('dataModelVersion: $dataModelVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MobileConflictsTable extends MobileConflicts
    with TableInfo<$MobileConflictsTable, MobileConflictEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MobileConflictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
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
  static const VerificationMeta _localVersionMeta = const VerificationMeta(
    'localVersion',
  );
  @override
  late final GeneratedColumn<int> localVersion = GeneratedColumn<int>(
    'local_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolutionStatusMeta = const VerificationMeta(
    'resolutionStatus',
  );
  @override
  late final GeneratedColumn<String> resolutionStatus = GeneratedColumn<String>(
    'resolution_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unresolved'),
  );
  static const VerificationMeta _resolutionEvidenceMeta =
      const VerificationMeta('resolutionEvidence');
  @override
  late final GeneratedColumn<String> resolutionEvidence =
      GeneratedColumn<String>(
        'resolution_evidence',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _dataModelVersionMeta = const VerificationMeta(
    'dataModelVersion',
  );
  @override
  late final GeneratedColumn<int> dataModelVersion = GeneratedColumn<int>(
    'data_model_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    operationId,
    entityType,
    entityId,
    localVersion,
    serverVersion,
    reason,
    resolutionStatus,
    resolutionEvidence,
    dataModelVersion,
    createdAt,
    resolvedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mobile_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<MobileConflictEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('local_version')) {
      context.handle(
        _localVersionMeta,
        localVersion.isAcceptableOrUnknown(
          data['local_version']!,
          _localVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localVersionMeta);
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serverVersionMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('resolution_status')) {
      context.handle(
        _resolutionStatusMeta,
        resolutionStatus.isAcceptableOrUnknown(
          data['resolution_status']!,
          _resolutionStatusMeta,
        ),
      );
    }
    if (data.containsKey('resolution_evidence')) {
      context.handle(
        _resolutionEvidenceMeta,
        resolutionEvidence.isAcceptableOrUnknown(
          data['resolution_evidence']!,
          _resolutionEvidenceMeta,
        ),
      );
    }
    if (data.containsKey('data_model_version')) {
      context.handle(
        _dataModelVersionMeta,
        dataModelVersion.isAcceptableOrUnknown(
          data['data_model_version']!,
          _dataModelVersionMeta,
        ),
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
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {tenantId, operationId},
  ];
  @override
  MobileConflictEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MobileConflictEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      localVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_version'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      resolutionStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolution_status'],
      )!,
      resolutionEvidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolution_evidence'],
      ),
      dataModelVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}data_model_version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MobileConflictsTable createAlias(String alias) {
    return $MobileConflictsTable(attachedDatabase, alias);
  }
}

class MobileConflictEntity extends DataClass
    implements Insertable<MobileConflictEntity> {
  final String id;
  final String tenantId;

  /// The operation that caused the conflict.
  final String operationId;

  /// Entity type (IMEI_UNIT, INVOICE, SERVICE_JOB, etc).
  final String entityType;

  /// Entity identifier.
  final String entityId;

  /// Local version at time of conflict.
  final int localVersion;

  /// Server version that conflicted.
  final int serverVersion;

  /// Conflict reason (VERSION_MISMATCH, UNIQUENESS_VIOLATION, etc).
  final String reason;

  /// Resolution status: unresolved | accepted | rejected | merged.
  final String resolutionStatus;

  /// Evidence of resolution (JSON — notes, actor, policy applied).
  final String? resolutionEvidence;
  final int dataModelVersion;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final DateTime updatedAt;
  const MobileConflictEntity({
    required this.id,
    required this.tenantId,
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.localVersion,
    required this.serverVersion,
    required this.reason,
    required this.resolutionStatus,
    this.resolutionEvidence,
    required this.dataModelVersion,
    required this.createdAt,
    this.resolvedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['operation_id'] = Variable<String>(operationId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['local_version'] = Variable<int>(localVersion);
    map['server_version'] = Variable<int>(serverVersion);
    map['reason'] = Variable<String>(reason);
    map['resolution_status'] = Variable<String>(resolutionStatus);
    if (!nullToAbsent || resolutionEvidence != null) {
      map['resolution_evidence'] = Variable<String>(resolutionEvidence);
    }
    map['data_model_version'] = Variable<int>(dataModelVersion);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MobileConflictsCompanion toCompanion(bool nullToAbsent) {
    return MobileConflictsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      operationId: Value(operationId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      localVersion: Value(localVersion),
      serverVersion: Value(serverVersion),
      reason: Value(reason),
      resolutionStatus: Value(resolutionStatus),
      resolutionEvidence: resolutionEvidence == null && nullToAbsent
          ? const Value.absent()
          : Value(resolutionEvidence),
      dataModelVersion: Value(dataModelVersion),
      createdAt: Value(createdAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MobileConflictEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MobileConflictEntity(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      operationId: serializer.fromJson<String>(json['operationId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      localVersion: serializer.fromJson<int>(json['localVersion']),
      serverVersion: serializer.fromJson<int>(json['serverVersion']),
      reason: serializer.fromJson<String>(json['reason']),
      resolutionStatus: serializer.fromJson<String>(json['resolutionStatus']),
      resolutionEvidence: serializer.fromJson<String?>(
        json['resolutionEvidence'],
      ),
      dataModelVersion: serializer.fromJson<int>(json['dataModelVersion']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'operationId': serializer.toJson<String>(operationId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'localVersion': serializer.toJson<int>(localVersion),
      'serverVersion': serializer.toJson<int>(serverVersion),
      'reason': serializer.toJson<String>(reason),
      'resolutionStatus': serializer.toJson<String>(resolutionStatus),
      'resolutionEvidence': serializer.toJson<String?>(resolutionEvidence),
      'dataModelVersion': serializer.toJson<int>(dataModelVersion),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MobileConflictEntity copyWith({
    String? id,
    String? tenantId,
    String? operationId,
    String? entityType,
    String? entityId,
    int? localVersion,
    int? serverVersion,
    String? reason,
    String? resolutionStatus,
    Value<String?> resolutionEvidence = const Value.absent(),
    int? dataModelVersion,
    DateTime? createdAt,
    Value<DateTime?> resolvedAt = const Value.absent(),
    DateTime? updatedAt,
  }) => MobileConflictEntity(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    operationId: operationId ?? this.operationId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    localVersion: localVersion ?? this.localVersion,
    serverVersion: serverVersion ?? this.serverVersion,
    reason: reason ?? this.reason,
    resolutionStatus: resolutionStatus ?? this.resolutionStatus,
    resolutionEvidence: resolutionEvidence.present
        ? resolutionEvidence.value
        : this.resolutionEvidence,
    dataModelVersion: dataModelVersion ?? this.dataModelVersion,
    createdAt: createdAt ?? this.createdAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MobileConflictEntity copyWithCompanion(MobileConflictsCompanion data) {
    return MobileConflictEntity(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      localVersion: data.localVersion.present
          ? data.localVersion.value
          : this.localVersion,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      reason: data.reason.present ? data.reason.value : this.reason,
      resolutionStatus: data.resolutionStatus.present
          ? data.resolutionStatus.value
          : this.resolutionStatus,
      resolutionEvidence: data.resolutionEvidence.present
          ? data.resolutionEvidence.value
          : this.resolutionEvidence,
      dataModelVersion: data.dataModelVersion.present
          ? data.dataModelVersion.value
          : this.dataModelVersion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MobileConflictEntity(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('operationId: $operationId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('localVersion: $localVersion, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('reason: $reason, ')
          ..write('resolutionStatus: $resolutionStatus, ')
          ..write('resolutionEvidence: $resolutionEvidence, ')
          ..write('dataModelVersion: $dataModelVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    operationId,
    entityType,
    entityId,
    localVersion,
    serverVersion,
    reason,
    resolutionStatus,
    resolutionEvidence,
    dataModelVersion,
    createdAt,
    resolvedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MobileConflictEntity &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.operationId == this.operationId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.localVersion == this.localVersion &&
          other.serverVersion == this.serverVersion &&
          other.reason == this.reason &&
          other.resolutionStatus == this.resolutionStatus &&
          other.resolutionEvidence == this.resolutionEvidence &&
          other.dataModelVersion == this.dataModelVersion &&
          other.createdAt == this.createdAt &&
          other.resolvedAt == this.resolvedAt &&
          other.updatedAt == this.updatedAt);
}

class MobileConflictsCompanion extends UpdateCompanion<MobileConflictEntity> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> operationId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<int> localVersion;
  final Value<int> serverVersion;
  final Value<String> reason;
  final Value<String> resolutionStatus;
  final Value<String?> resolutionEvidence;
  final Value<int> dataModelVersion;
  final Value<DateTime> createdAt;
  final Value<DateTime?> resolvedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MobileConflictsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.operationId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.localVersion = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.reason = const Value.absent(),
    this.resolutionStatus = const Value.absent(),
    this.resolutionEvidence = const Value.absent(),
    this.dataModelVersion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MobileConflictsCompanion.insert({
    required String id,
    required String tenantId,
    required String operationId,
    required String entityType,
    required String entityId,
    required int localVersion,
    required int serverVersion,
    required String reason,
    this.resolutionStatus = const Value.absent(),
    this.resolutionEvidence = const Value.absent(),
    this.dataModelVersion = const Value.absent(),
    required DateTime createdAt,
    this.resolvedAt = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       operationId = Value(operationId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       localVersion = Value(localVersion),
       serverVersion = Value(serverVersion),
       reason = Value(reason),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MobileConflictEntity> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? operationId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<int>? localVersion,
    Expression<int>? serverVersion,
    Expression<String>? reason,
    Expression<String>? resolutionStatus,
    Expression<String>? resolutionEvidence,
    Expression<int>? dataModelVersion,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? resolvedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (operationId != null) 'operation_id': operationId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (localVersion != null) 'local_version': localVersion,
      if (serverVersion != null) 'server_version': serverVersion,
      if (reason != null) 'reason': reason,
      if (resolutionStatus != null) 'resolution_status': resolutionStatus,
      if (resolutionEvidence != null) 'resolution_evidence': resolutionEvidence,
      if (dataModelVersion != null) 'data_model_version': dataModelVersion,
      if (createdAt != null) 'created_at': createdAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MobileConflictsCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? operationId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<int>? localVersion,
    Value<int>? serverVersion,
    Value<String>? reason,
    Value<String>? resolutionStatus,
    Value<String?>? resolutionEvidence,
    Value<int>? dataModelVersion,
    Value<DateTime>? createdAt,
    Value<DateTime?>? resolvedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MobileConflictsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      operationId: operationId ?? this.operationId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      localVersion: localVersion ?? this.localVersion,
      serverVersion: serverVersion ?? this.serverVersion,
      reason: reason ?? this.reason,
      resolutionStatus: resolutionStatus ?? this.resolutionStatus,
      resolutionEvidence: resolutionEvidence ?? this.resolutionEvidence,
      dataModelVersion: dataModelVersion ?? this.dataModelVersion,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (localVersion.present) {
      map['local_version'] = Variable<int>(localVersion.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (resolutionStatus.present) {
      map['resolution_status'] = Variable<String>(resolutionStatus.value);
    }
    if (resolutionEvidence.present) {
      map['resolution_evidence'] = Variable<String>(resolutionEvidence.value);
    }
    if (dataModelVersion.present) {
      map['data_model_version'] = Variable<int>(dataModelVersion.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MobileConflictsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('operationId: $operationId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('localVersion: $localVersion, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('reason: $reason, ')
          ..write('resolutionStatus: $resolutionStatus, ')
          ..write('resolutionEvidence: $resolutionEvidence, ')
          ..write('dataModelVersion: $dataModelVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MobileEventInboxTable extends MobileEventInbox
    with TableInfo<$MobileEventInboxTable, MobileEventInboxEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MobileEventInboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
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
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataModelVersionMeta = const VerificationMeta(
    'dataModelVersion',
  );
  @override
  late final GeneratedColumn<int> dataModelVersion = GeneratedColumn<int>(
    'data_model_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _receivedAtMeta = const VerificationMeta(
    'receivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
    'received_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _processedAtMeta = const VerificationMeta(
    'processedAt',
  );
  @override
  late final GeneratedColumn<DateTime> processedAt = GeneratedColumn<DateTime>(
    'processed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    eventId,
    entityType,
    entityId,
    version,
    action,
    dataModelVersion,
    receivedAt,
    processedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mobile_event_inbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<MobileEventInboxEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('data_model_version')) {
      context.handle(
        _dataModelVersionMeta,
        dataModelVersion.isAcceptableOrUnknown(
          data['data_model_version']!,
          _dataModelVersionMeta,
        ),
      );
    }
    if (data.containsKey('received_at')) {
      context.handle(
        _receivedAtMeta,
        receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    if (data.containsKey('processed_at')) {
      context.handle(
        _processedAtMeta,
        processedAt.isAcceptableOrUnknown(
          data['processed_at']!,
          _processedAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {tenantId, eventId},
  ];
  @override
  MobileEventInboxEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MobileEventInboxEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      dataModelVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}data_model_version'],
      )!,
      receivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}received_at'],
      )!,
      processedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}processed_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MobileEventInboxTable createAlias(String alias) {
    return $MobileEventInboxTable(attachedDatabase, alias);
  }
}

class MobileEventInboxEntity extends DataClass
    implements Insertable<MobileEventInboxEntity> {
  final String id;
  final String tenantId;

  /// Server-assigned event identifier — globally unique within tenant.
  final String eventId;

  /// Entity type the event applies to.
  final String entityType;

  /// Entity identifier.
  final String entityId;

  /// Entity version after this event.
  final int version;

  /// Event action (CREATED, UPDATED, DELETED, LIFECYCLE_CHANGE, etc).
  final String action;
  final int dataModelVersion;
  final DateTime receivedAt;
  final DateTime? processedAt;
  final DateTime updatedAt;
  const MobileEventInboxEntity({
    required this.id,
    required this.tenantId,
    required this.eventId,
    required this.entityType,
    required this.entityId,
    required this.version,
    required this.action,
    required this.dataModelVersion,
    required this.receivedAt,
    this.processedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['event_id'] = Variable<String>(eventId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['version'] = Variable<int>(version);
    map['action'] = Variable<String>(action);
    map['data_model_version'] = Variable<int>(dataModelVersion);
    map['received_at'] = Variable<DateTime>(receivedAt);
    if (!nullToAbsent || processedAt != null) {
      map['processed_at'] = Variable<DateTime>(processedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MobileEventInboxCompanion toCompanion(bool nullToAbsent) {
    return MobileEventInboxCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      eventId: Value(eventId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      version: Value(version),
      action: Value(action),
      dataModelVersion: Value(dataModelVersion),
      receivedAt: Value(receivedAt),
      processedAt: processedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(processedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MobileEventInboxEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MobileEventInboxEntity(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      eventId: serializer.fromJson<String>(json['eventId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      version: serializer.fromJson<int>(json['version']),
      action: serializer.fromJson<String>(json['action']),
      dataModelVersion: serializer.fromJson<int>(json['dataModelVersion']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
      processedAt: serializer.fromJson<DateTime?>(json['processedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'eventId': serializer.toJson<String>(eventId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'version': serializer.toJson<int>(version),
      'action': serializer.toJson<String>(action),
      'dataModelVersion': serializer.toJson<int>(dataModelVersion),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
      'processedAt': serializer.toJson<DateTime?>(processedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MobileEventInboxEntity copyWith({
    String? id,
    String? tenantId,
    String? eventId,
    String? entityType,
    String? entityId,
    int? version,
    String? action,
    int? dataModelVersion,
    DateTime? receivedAt,
    Value<DateTime?> processedAt = const Value.absent(),
    DateTime? updatedAt,
  }) => MobileEventInboxEntity(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    eventId: eventId ?? this.eventId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    version: version ?? this.version,
    action: action ?? this.action,
    dataModelVersion: dataModelVersion ?? this.dataModelVersion,
    receivedAt: receivedAt ?? this.receivedAt,
    processedAt: processedAt.present ? processedAt.value : this.processedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MobileEventInboxEntity copyWithCompanion(MobileEventInboxCompanion data) {
    return MobileEventInboxEntity(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      version: data.version.present ? data.version.value : this.version,
      action: data.action.present ? data.action.value : this.action,
      dataModelVersion: data.dataModelVersion.present
          ? data.dataModelVersion.value
          : this.dataModelVersion,
      receivedAt: data.receivedAt.present
          ? data.receivedAt.value
          : this.receivedAt,
      processedAt: data.processedAt.present
          ? data.processedAt.value
          : this.processedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MobileEventInboxEntity(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('eventId: $eventId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('version: $version, ')
          ..write('action: $action, ')
          ..write('dataModelVersion: $dataModelVersion, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('processedAt: $processedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    eventId,
    entityType,
    entityId,
    version,
    action,
    dataModelVersion,
    receivedAt,
    processedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MobileEventInboxEntity &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.eventId == this.eventId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.version == this.version &&
          other.action == this.action &&
          other.dataModelVersion == this.dataModelVersion &&
          other.receivedAt == this.receivedAt &&
          other.processedAt == this.processedAt &&
          other.updatedAt == this.updatedAt);
}

class MobileEventInboxCompanion
    extends UpdateCompanion<MobileEventInboxEntity> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> eventId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<int> version;
  final Value<String> action;
  final Value<int> dataModelVersion;
  final Value<DateTime> receivedAt;
  final Value<DateTime?> processedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MobileEventInboxCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.version = const Value.absent(),
    this.action = const Value.absent(),
    this.dataModelVersion = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.processedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MobileEventInboxCompanion.insert({
    required String id,
    required String tenantId,
    required String eventId,
    required String entityType,
    required String entityId,
    required int version,
    required String action,
    this.dataModelVersion = const Value.absent(),
    required DateTime receivedAt,
    this.processedAt = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       eventId = Value(eventId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       version = Value(version),
       action = Value(action),
       receivedAt = Value(receivedAt),
       updatedAt = Value(updatedAt);
  static Insertable<MobileEventInboxEntity> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? eventId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<int>? version,
    Expression<String>? action,
    Expression<int>? dataModelVersion,
    Expression<DateTime>? receivedAt,
    Expression<DateTime>? processedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (eventId != null) 'event_id': eventId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (version != null) 'version': version,
      if (action != null) 'action': action,
      if (dataModelVersion != null) 'data_model_version': dataModelVersion,
      if (receivedAt != null) 'received_at': receivedAt,
      if (processedAt != null) 'processed_at': processedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MobileEventInboxCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? eventId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<int>? version,
    Value<String>? action,
    Value<int>? dataModelVersion,
    Value<DateTime>? receivedAt,
    Value<DateTime?>? processedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MobileEventInboxCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      eventId: eventId ?? this.eventId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      version: version ?? this.version,
      action: action ?? this.action,
      dataModelVersion: dataModelVersion ?? this.dataModelVersion,
      receivedAt: receivedAt ?? this.receivedAt,
      processedAt: processedAt ?? this.processedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (dataModelVersion.present) {
      map['data_model_version'] = Variable<int>(dataModelVersion.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (processedAt.present) {
      map['processed_at'] = Variable<DateTime>(processedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MobileEventInboxCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('eventId: $eventId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('version: $version, ')
          ..write('action: $action, ')
          ..write('dataModelVersion: $dataModelVersion, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('processedAt: $processedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MobileContinuationCheckpointsTable extends MobileContinuationCheckpoints
    with
        TableInfo<
          $MobileContinuationCheckpointsTable,
          MobileContinuationCheckpointEntity
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MobileContinuationCheckpointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bucketMeta = const VerificationMeta('bucket');
  @override
  late final GeneratedColumn<String> bucket = GeneratedColumn<String>(
    'bucket',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastPositionMeta = const VerificationMeta(
    'lastPosition',
  );
  @override
  late final GeneratedColumn<String> lastPosition = GeneratedColumn<String>(
    'last_position',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastPulledAtMeta = const VerificationMeta(
    'lastPulledAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPulledAt = GeneratedColumn<DateTime>(
    'last_pulled_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dataModelVersionMeta = const VerificationMeta(
    'dataModelVersion',
  );
  @override
  late final GeneratedColumn<int> dataModelVersion = GeneratedColumn<int>(
    'data_model_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    bucket,
    lastPosition,
    lastPulledAt,
    serverVersion,
    dataModelVersion,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mobile_continuation_checkpoints';
  @override
  VerificationContext validateIntegrity(
    Insertable<MobileContinuationCheckpointEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('bucket')) {
      context.handle(
        _bucketMeta,
        bucket.isAcceptableOrUnknown(data['bucket']!, _bucketMeta),
      );
    } else if (isInserting) {
      context.missing(_bucketMeta);
    }
    if (data.containsKey('last_position')) {
      context.handle(
        _lastPositionMeta,
        lastPosition.isAcceptableOrUnknown(
          data['last_position']!,
          _lastPositionMeta,
        ),
      );
    }
    if (data.containsKey('last_pulled_at')) {
      context.handle(
        _lastPulledAtMeta,
        lastPulledAt.isAcceptableOrUnknown(
          data['last_pulled_at']!,
          _lastPulledAtMeta,
        ),
      );
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    if (data.containsKey('data_model_version')) {
      context.handle(
        _dataModelVersionMeta,
        dataModelVersion.isAcceptableOrUnknown(
          data['data_model_version']!,
          _dataModelVersionMeta,
        ),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {tenantId, bucket},
  ];
  @override
  MobileContinuationCheckpointEntity map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MobileContinuationCheckpointEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      bucket: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bucket'],
      )!,
      lastPosition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_position'],
      ),
      lastPulledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_pulled_at'],
      ),
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      )!,
      dataModelVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}data_model_version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MobileContinuationCheckpointsTable createAlias(String alias) {
    return $MobileContinuationCheckpointsTable(attachedDatabase, alias);
  }
}

class MobileContinuationCheckpointEntity extends DataClass
    implements Insertable<MobileContinuationCheckpointEntity> {
  final String id;
  final String tenantId;

  /// Logical bucket for partitioned sync (e.g., entity type or shard).
  final String bucket;

  /// Opaque server-issued continuation position.
  final String? lastPosition;

  /// When the last successful pull completed.
  final DateTime? lastPulledAt;

  /// Server version at last pull.
  final int serverVersion;
  final int dataModelVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MobileContinuationCheckpointEntity({
    required this.id,
    required this.tenantId,
    required this.bucket,
    this.lastPosition,
    this.lastPulledAt,
    required this.serverVersion,
    required this.dataModelVersion,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['bucket'] = Variable<String>(bucket);
    if (!nullToAbsent || lastPosition != null) {
      map['last_position'] = Variable<String>(lastPosition);
    }
    if (!nullToAbsent || lastPulledAt != null) {
      map['last_pulled_at'] = Variable<DateTime>(lastPulledAt);
    }
    map['server_version'] = Variable<int>(serverVersion);
    map['data_model_version'] = Variable<int>(dataModelVersion);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MobileContinuationCheckpointsCompanion toCompanion(bool nullToAbsent) {
    return MobileContinuationCheckpointsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      bucket: Value(bucket),
      lastPosition: lastPosition == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPosition),
      lastPulledAt: lastPulledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPulledAt),
      serverVersion: Value(serverVersion),
      dataModelVersion: Value(dataModelVersion),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MobileContinuationCheckpointEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MobileContinuationCheckpointEntity(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      bucket: serializer.fromJson<String>(json['bucket']),
      lastPosition: serializer.fromJson<String?>(json['lastPosition']),
      lastPulledAt: serializer.fromJson<DateTime?>(json['lastPulledAt']),
      serverVersion: serializer.fromJson<int>(json['serverVersion']),
      dataModelVersion: serializer.fromJson<int>(json['dataModelVersion']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'bucket': serializer.toJson<String>(bucket),
      'lastPosition': serializer.toJson<String?>(lastPosition),
      'lastPulledAt': serializer.toJson<DateTime?>(lastPulledAt),
      'serverVersion': serializer.toJson<int>(serverVersion),
      'dataModelVersion': serializer.toJson<int>(dataModelVersion),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MobileContinuationCheckpointEntity copyWith({
    String? id,
    String? tenantId,
    String? bucket,
    Value<String?> lastPosition = const Value.absent(),
    Value<DateTime?> lastPulledAt = const Value.absent(),
    int? serverVersion,
    int? dataModelVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MobileContinuationCheckpointEntity(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    bucket: bucket ?? this.bucket,
    lastPosition: lastPosition.present ? lastPosition.value : this.lastPosition,
    lastPulledAt: lastPulledAt.present ? lastPulledAt.value : this.lastPulledAt,
    serverVersion: serverVersion ?? this.serverVersion,
    dataModelVersion: dataModelVersion ?? this.dataModelVersion,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MobileContinuationCheckpointEntity copyWithCompanion(
    MobileContinuationCheckpointsCompanion data,
  ) {
    return MobileContinuationCheckpointEntity(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      bucket: data.bucket.present ? data.bucket.value : this.bucket,
      lastPosition: data.lastPosition.present
          ? data.lastPosition.value
          : this.lastPosition,
      lastPulledAt: data.lastPulledAt.present
          ? data.lastPulledAt.value
          : this.lastPulledAt,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      dataModelVersion: data.dataModelVersion.present
          ? data.dataModelVersion.value
          : this.dataModelVersion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MobileContinuationCheckpointEntity(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('bucket: $bucket, ')
          ..write('lastPosition: $lastPosition, ')
          ..write('lastPulledAt: $lastPulledAt, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('dataModelVersion: $dataModelVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    bucket,
    lastPosition,
    lastPulledAt,
    serverVersion,
    dataModelVersion,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MobileContinuationCheckpointEntity &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.bucket == this.bucket &&
          other.lastPosition == this.lastPosition &&
          other.lastPulledAt == this.lastPulledAt &&
          other.serverVersion == this.serverVersion &&
          other.dataModelVersion == this.dataModelVersion &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MobileContinuationCheckpointsCompanion
    extends UpdateCompanion<MobileContinuationCheckpointEntity> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> bucket;
  final Value<String?> lastPosition;
  final Value<DateTime?> lastPulledAt;
  final Value<int> serverVersion;
  final Value<int> dataModelVersion;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MobileContinuationCheckpointsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.bucket = const Value.absent(),
    this.lastPosition = const Value.absent(),
    this.lastPulledAt = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.dataModelVersion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MobileContinuationCheckpointsCompanion.insert({
    required String id,
    required String tenantId,
    required String bucket,
    this.lastPosition = const Value.absent(),
    this.lastPulledAt = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.dataModelVersion = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       bucket = Value(bucket),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MobileContinuationCheckpointEntity> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? bucket,
    Expression<String>? lastPosition,
    Expression<DateTime>? lastPulledAt,
    Expression<int>? serverVersion,
    Expression<int>? dataModelVersion,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (bucket != null) 'bucket': bucket,
      if (lastPosition != null) 'last_position': lastPosition,
      if (lastPulledAt != null) 'last_pulled_at': lastPulledAt,
      if (serverVersion != null) 'server_version': serverVersion,
      if (dataModelVersion != null) 'data_model_version': dataModelVersion,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MobileContinuationCheckpointsCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? bucket,
    Value<String?>? lastPosition,
    Value<DateTime?>? lastPulledAt,
    Value<int>? serverVersion,
    Value<int>? dataModelVersion,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MobileContinuationCheckpointsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      bucket: bucket ?? this.bucket,
      lastPosition: lastPosition ?? this.lastPosition,
      lastPulledAt: lastPulledAt ?? this.lastPulledAt,
      serverVersion: serverVersion ?? this.serverVersion,
      dataModelVersion: dataModelVersion ?? this.dataModelVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (bucket.present) {
      map['bucket'] = Variable<String>(bucket.value);
    }
    if (lastPosition.present) {
      map['last_position'] = Variable<String>(lastPosition.value);
    }
    if (lastPulledAt.present) {
      map['last_pulled_at'] = Variable<DateTime>(lastPulledAt.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (dataModelVersion.present) {
      map['data_model_version'] = Variable<int>(dataModelVersion.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MobileContinuationCheckpointsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('bucket: $bucket, ')
          ..write('lastPosition: $lastPosition, ')
          ..write('lastPulledAt: $lastPulledAt, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('dataModelVersion: $dataModelVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$MobileShopDatabase extends GeneratedDatabase {
  _$MobileShopDatabase(QueryExecutor e) : super(e);
  $MobileShopDatabaseManager get managers => $MobileShopDatabaseManager(this);
  late final $MobileImeiUnitsTable mobileImeiUnits = $MobileImeiUnitsTable(
    this,
  );
  late final $MobileInvoiceAssociationsTable mobileInvoiceAssociations =
      $MobileInvoiceAssociationsTable(this);
  late final $MobileServiceJobsTable mobileServiceJobs =
      $MobileServiceJobsTable(this);
  late final $MobileExchangesTable mobileExchanges = $MobileExchangesTable(
    this,
  );
  late final $MobileWarrantiesTable mobileWarranties = $MobileWarrantiesTable(
    this,
  );
  late final $MobileReconciliationStatusTable mobileReconciliationStatus =
      $MobileReconciliationStatusTable(this);
  late final $MobileProviderStateTable mobileProviderState =
      $MobileProviderStateTable(this);
  late final $MobileOutboxMutationsTable mobileOutboxMutations =
      $MobileOutboxMutationsTable(this);
  late final $MobileConflictsTable mobileConflicts = $MobileConflictsTable(
    this,
  );
  late final $MobileEventInboxTable mobileEventInbox = $MobileEventInboxTable(
    this,
  );
  late final $MobileContinuationCheckpointsTable mobileContinuationCheckpoints =
      $MobileContinuationCheckpointsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    mobileImeiUnits,
    mobileInvoiceAssociations,
    mobileServiceJobs,
    mobileExchanges,
    mobileWarranties,
    mobileReconciliationStatus,
    mobileProviderState,
    mobileOutboxMutations,
    mobileConflicts,
    mobileEventInbox,
    mobileContinuationCheckpoints,
  ];
}

typedef $$MobileImeiUnitsTableCreateCompanionBuilder =
    MobileImeiUnitsCompanion Function({
      required String id,
      required String tenantId,
      required String entityId,
      required String imei,
      Value<int> version,
      Value<int> serverVersion,
      Value<String> lifecycleState,
      Value<String?> condition,
      Value<String?> brand,
      Value<String?> model,
      Value<int?> salePricePaise,
      Value<int?> acquisitionCostPaise,
      Value<DateTime?> warrantyStartDate,
      Value<DateTime?> warrantyEndDate,
      Value<String> confirmationStatus,
      Value<DateTime?> syncedAt,
      Value<int> dataModelVersion,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MobileImeiUnitsTableUpdateCompanionBuilder =
    MobileImeiUnitsCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> entityId,
      Value<String> imei,
      Value<int> version,
      Value<int> serverVersion,
      Value<String> lifecycleState,
      Value<String?> condition,
      Value<String?> brand,
      Value<String?> model,
      Value<int?> salePricePaise,
      Value<int?> acquisitionCostPaise,
      Value<DateTime?> warrantyStartDate,
      Value<DateTime?> warrantyEndDate,
      Value<String> confirmationStatus,
      Value<DateTime?> syncedAt,
      Value<int> dataModelVersion,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$MobileImeiUnitsTableFilterComposer
    extends Composer<_$MobileShopDatabase, $MobileImeiUnitsTable> {
  $$MobileImeiUnitsTableFilterComposer({
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

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imei => $composableBuilder(
    column: $table.imei,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lifecycleState => $composableBuilder(
    column: $table.lifecycleState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get condition => $composableBuilder(
    column: $table.condition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get salePricePaise => $composableBuilder(
    column: $table.salePricePaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get acquisitionCostPaise => $composableBuilder(
    column: $table.acquisitionCostPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get warrantyStartDate => $composableBuilder(
    column: $table.warrantyStartDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get warrantyEndDate => $composableBuilder(
    column: $table.warrantyEndDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confirmationStatus => $composableBuilder(
    column: $table.confirmationStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
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
}

class $$MobileImeiUnitsTableOrderingComposer
    extends Composer<_$MobileShopDatabase, $MobileImeiUnitsTable> {
  $$MobileImeiUnitsTableOrderingComposer({
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

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imei => $composableBuilder(
    column: $table.imei,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lifecycleState => $composableBuilder(
    column: $table.lifecycleState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get condition => $composableBuilder(
    column: $table.condition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get salePricePaise => $composableBuilder(
    column: $table.salePricePaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get acquisitionCostPaise => $composableBuilder(
    column: $table.acquisitionCostPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get warrantyStartDate => $composableBuilder(
    column: $table.warrantyStartDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get warrantyEndDate => $composableBuilder(
    column: $table.warrantyEndDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confirmationStatus => $composableBuilder(
    column: $table.confirmationStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
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
}

class $$MobileImeiUnitsTableAnnotationComposer
    extends Composer<_$MobileShopDatabase, $MobileImeiUnitsTable> {
  $$MobileImeiUnitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get imei =>
      $composableBuilder(column: $table.imei, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lifecycleState => $composableBuilder(
    column: $table.lifecycleState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get condition =>
      $composableBuilder(column: $table.condition, builder: (column) => column);

  GeneratedColumn<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<int> get salePricePaise => $composableBuilder(
    column: $table.salePricePaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get acquisitionCostPaise => $composableBuilder(
    column: $table.acquisitionCostPaise,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get warrantyStartDate => $composableBuilder(
    column: $table.warrantyStartDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get warrantyEndDate => $composableBuilder(
    column: $table.warrantyEndDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get confirmationStatus => $composableBuilder(
    column: $table.confirmationStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MobileImeiUnitsTableTableManager
    extends
        RootTableManager<
          _$MobileShopDatabase,
          $MobileImeiUnitsTable,
          MobileImeiUnitEntity,
          $$MobileImeiUnitsTableFilterComposer,
          $$MobileImeiUnitsTableOrderingComposer,
          $$MobileImeiUnitsTableAnnotationComposer,
          $$MobileImeiUnitsTableCreateCompanionBuilder,
          $$MobileImeiUnitsTableUpdateCompanionBuilder,
          (
            MobileImeiUnitEntity,
            BaseReferences<
              _$MobileShopDatabase,
              $MobileImeiUnitsTable,
              MobileImeiUnitEntity
            >,
          ),
          MobileImeiUnitEntity,
          PrefetchHooks Function()
        > {
  $$MobileImeiUnitsTableTableManager(
    _$MobileShopDatabase db,
    $MobileImeiUnitsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MobileImeiUnitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MobileImeiUnitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MobileImeiUnitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> imei = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<String> lifecycleState = const Value.absent(),
                Value<String?> condition = const Value.absent(),
                Value<String?> brand = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<int?> salePricePaise = const Value.absent(),
                Value<int?> acquisitionCostPaise = const Value.absent(),
                Value<DateTime?> warrantyStartDate = const Value.absent(),
                Value<DateTime?> warrantyEndDate = const Value.absent(),
                Value<String> confirmationStatus = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> dataModelVersion = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MobileImeiUnitsCompanion(
                id: id,
                tenantId: tenantId,
                entityId: entityId,
                imei: imei,
                version: version,
                serverVersion: serverVersion,
                lifecycleState: lifecycleState,
                condition: condition,
                brand: brand,
                model: model,
                salePricePaise: salePricePaise,
                acquisitionCostPaise: acquisitionCostPaise,
                warrantyStartDate: warrantyStartDate,
                warrantyEndDate: warrantyEndDate,
                confirmationStatus: confirmationStatus,
                syncedAt: syncedAt,
                dataModelVersion: dataModelVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String entityId,
                required String imei,
                Value<int> version = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<String> lifecycleState = const Value.absent(),
                Value<String?> condition = const Value.absent(),
                Value<String?> brand = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<int?> salePricePaise = const Value.absent(),
                Value<int?> acquisitionCostPaise = const Value.absent(),
                Value<DateTime?> warrantyStartDate = const Value.absent(),
                Value<DateTime?> warrantyEndDate = const Value.absent(),
                Value<String> confirmationStatus = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> dataModelVersion = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MobileImeiUnitsCompanion.insert(
                id: id,
                tenantId: tenantId,
                entityId: entityId,
                imei: imei,
                version: version,
                serverVersion: serverVersion,
                lifecycleState: lifecycleState,
                condition: condition,
                brand: brand,
                model: model,
                salePricePaise: salePricePaise,
                acquisitionCostPaise: acquisitionCostPaise,
                warrantyStartDate: warrantyStartDate,
                warrantyEndDate: warrantyEndDate,
                confirmationStatus: confirmationStatus,
                syncedAt: syncedAt,
                dataModelVersion: dataModelVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MobileImeiUnitsTableProcessedTableManager =
    ProcessedTableManager<
      _$MobileShopDatabase,
      $MobileImeiUnitsTable,
      MobileImeiUnitEntity,
      $$MobileImeiUnitsTableFilterComposer,
      $$MobileImeiUnitsTableOrderingComposer,
      $$MobileImeiUnitsTableAnnotationComposer,
      $$MobileImeiUnitsTableCreateCompanionBuilder,
      $$MobileImeiUnitsTableUpdateCompanionBuilder,
      (
        MobileImeiUnitEntity,
        BaseReferences<
          _$MobileShopDatabase,
          $MobileImeiUnitsTable,
          MobileImeiUnitEntity
        >,
      ),
      MobileImeiUnitEntity,
      PrefetchHooks Function()
    >;
typedef $$MobileInvoiceAssociationsTableCreateCompanionBuilder =
    MobileInvoiceAssociationsCompanion Function({
      required String id,
      required String tenantId,
      required String invoiceId,
      required String entityId,
      required String imei,
      Value<int> lineNumber,
      Value<int?> linePricePaise,
      Value<int> serverVersion,
      Value<String> confirmationStatus,
      Value<int> dataModelVersion,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MobileInvoiceAssociationsTableUpdateCompanionBuilder =
    MobileInvoiceAssociationsCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> invoiceId,
      Value<String> entityId,
      Value<String> imei,
      Value<int> lineNumber,
      Value<int?> linePricePaise,
      Value<int> serverVersion,
      Value<String> confirmationStatus,
      Value<int> dataModelVersion,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$MobileInvoiceAssociationsTableFilterComposer
    extends Composer<_$MobileShopDatabase, $MobileInvoiceAssociationsTable> {
  $$MobileInvoiceAssociationsTableFilterComposer({
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

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get invoiceId => $composableBuilder(
    column: $table.invoiceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imei => $composableBuilder(
    column: $table.imei,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineNumber => $composableBuilder(
    column: $table.lineNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get linePricePaise => $composableBuilder(
    column: $table.linePricePaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confirmationStatus => $composableBuilder(
    column: $table.confirmationStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
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
}

class $$MobileInvoiceAssociationsTableOrderingComposer
    extends Composer<_$MobileShopDatabase, $MobileInvoiceAssociationsTable> {
  $$MobileInvoiceAssociationsTableOrderingComposer({
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

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invoiceId => $composableBuilder(
    column: $table.invoiceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imei => $composableBuilder(
    column: $table.imei,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineNumber => $composableBuilder(
    column: $table.lineNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get linePricePaise => $composableBuilder(
    column: $table.linePricePaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confirmationStatus => $composableBuilder(
    column: $table.confirmationStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
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
}

class $$MobileInvoiceAssociationsTableAnnotationComposer
    extends Composer<_$MobileShopDatabase, $MobileInvoiceAssociationsTable> {
  $$MobileInvoiceAssociationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get invoiceId =>
      $composableBuilder(column: $table.invoiceId, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get imei =>
      $composableBuilder(column: $table.imei, builder: (column) => column);

  GeneratedColumn<int> get lineNumber => $composableBuilder(
    column: $table.lineNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get linePricePaise => $composableBuilder(
    column: $table.linePricePaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get confirmationStatus => $composableBuilder(
    column: $table.confirmationStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MobileInvoiceAssociationsTableTableManager
    extends
        RootTableManager<
          _$MobileShopDatabase,
          $MobileInvoiceAssociationsTable,
          MobileInvoiceAssociationEntity,
          $$MobileInvoiceAssociationsTableFilterComposer,
          $$MobileInvoiceAssociationsTableOrderingComposer,
          $$MobileInvoiceAssociationsTableAnnotationComposer,
          $$MobileInvoiceAssociationsTableCreateCompanionBuilder,
          $$MobileInvoiceAssociationsTableUpdateCompanionBuilder,
          (
            MobileInvoiceAssociationEntity,
            BaseReferences<
              _$MobileShopDatabase,
              $MobileInvoiceAssociationsTable,
              MobileInvoiceAssociationEntity
            >,
          ),
          MobileInvoiceAssociationEntity,
          PrefetchHooks Function()
        > {
  $$MobileInvoiceAssociationsTableTableManager(
    _$MobileShopDatabase db,
    $MobileInvoiceAssociationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MobileInvoiceAssociationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$MobileInvoiceAssociationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MobileInvoiceAssociationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> invoiceId = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> imei = const Value.absent(),
                Value<int> lineNumber = const Value.absent(),
                Value<int?> linePricePaise = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<String> confirmationStatus = const Value.absent(),
                Value<int> dataModelVersion = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MobileInvoiceAssociationsCompanion(
                id: id,
                tenantId: tenantId,
                invoiceId: invoiceId,
                entityId: entityId,
                imei: imei,
                lineNumber: lineNumber,
                linePricePaise: linePricePaise,
                serverVersion: serverVersion,
                confirmationStatus: confirmationStatus,
                dataModelVersion: dataModelVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String invoiceId,
                required String entityId,
                required String imei,
                Value<int> lineNumber = const Value.absent(),
                Value<int?> linePricePaise = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<String> confirmationStatus = const Value.absent(),
                Value<int> dataModelVersion = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MobileInvoiceAssociationsCompanion.insert(
                id: id,
                tenantId: tenantId,
                invoiceId: invoiceId,
                entityId: entityId,
                imei: imei,
                lineNumber: lineNumber,
                linePricePaise: linePricePaise,
                serverVersion: serverVersion,
                confirmationStatus: confirmationStatus,
                dataModelVersion: dataModelVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MobileInvoiceAssociationsTableProcessedTableManager =
    ProcessedTableManager<
      _$MobileShopDatabase,
      $MobileInvoiceAssociationsTable,
      MobileInvoiceAssociationEntity,
      $$MobileInvoiceAssociationsTableFilterComposer,
      $$MobileInvoiceAssociationsTableOrderingComposer,
      $$MobileInvoiceAssociationsTableAnnotationComposer,
      $$MobileInvoiceAssociationsTableCreateCompanionBuilder,
      $$MobileInvoiceAssociationsTableUpdateCompanionBuilder,
      (
        MobileInvoiceAssociationEntity,
        BaseReferences<
          _$MobileShopDatabase,
          $MobileInvoiceAssociationsTable,
          MobileInvoiceAssociationEntity
        >,
      ),
      MobileInvoiceAssociationEntity,
      PrefetchHooks Function()
    >;
typedef $$MobileServiceJobsTableCreateCompanionBuilder =
    MobileServiceJobsCompanion Function({
      required String id,
      required String tenantId,
      required String entityId,
      Value<String?> imei,
      Value<String?> customerId,
      Value<String?> customerName,
      Value<String> status,
      Value<String?> technicianId,
      Value<String?> problemDescription,
      Value<String?> diagnosis,
      Value<int?> estimatedCostPaise,
      Value<int?> actualCostPaise,
      Value<DateTime?> dueAt,
      Value<int> version,
      Value<int> serverVersion,
      Value<String> confirmationStatus,
      Value<int> dataModelVersion,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MobileServiceJobsTableUpdateCompanionBuilder =
    MobileServiceJobsCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> entityId,
      Value<String?> imei,
      Value<String?> customerId,
      Value<String?> customerName,
      Value<String> status,
      Value<String?> technicianId,
      Value<String?> problemDescription,
      Value<String?> diagnosis,
      Value<int?> estimatedCostPaise,
      Value<int?> actualCostPaise,
      Value<DateTime?> dueAt,
      Value<int> version,
      Value<int> serverVersion,
      Value<String> confirmationStatus,
      Value<int> dataModelVersion,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$MobileServiceJobsTableFilterComposer
    extends Composer<_$MobileShopDatabase, $MobileServiceJobsTable> {
  $$MobileServiceJobsTableFilterComposer({
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

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imei => $composableBuilder(
    column: $table.imei,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get technicianId => $composableBuilder(
    column: $table.technicianId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get problemDescription => $composableBuilder(
    column: $table.problemDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get diagnosis => $composableBuilder(
    column: $table.diagnosis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimatedCostPaise => $composableBuilder(
    column: $table.estimatedCostPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get actualCostPaise => $composableBuilder(
    column: $table.actualCostPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confirmationStatus => $composableBuilder(
    column: $table.confirmationStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
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
}

class $$MobileServiceJobsTableOrderingComposer
    extends Composer<_$MobileShopDatabase, $MobileServiceJobsTable> {
  $$MobileServiceJobsTableOrderingComposer({
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

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imei => $composableBuilder(
    column: $table.imei,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get technicianId => $composableBuilder(
    column: $table.technicianId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get problemDescription => $composableBuilder(
    column: $table.problemDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get diagnosis => $composableBuilder(
    column: $table.diagnosis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimatedCostPaise => $composableBuilder(
    column: $table.estimatedCostPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get actualCostPaise => $composableBuilder(
    column: $table.actualCostPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confirmationStatus => $composableBuilder(
    column: $table.confirmationStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
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
}

class $$MobileServiceJobsTableAnnotationComposer
    extends Composer<_$MobileShopDatabase, $MobileServiceJobsTable> {
  $$MobileServiceJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get imei =>
      $composableBuilder(column: $table.imei, builder: (column) => column);

  GeneratedColumn<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get technicianId => $composableBuilder(
    column: $table.technicianId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get problemDescription => $composableBuilder(
    column: $table.problemDescription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get diagnosis =>
      $composableBuilder(column: $table.diagnosis, builder: (column) => column);

  GeneratedColumn<int> get estimatedCostPaise => $composableBuilder(
    column: $table.estimatedCostPaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get actualCostPaise => $composableBuilder(
    column: $table.actualCostPaise,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get confirmationStatus => $composableBuilder(
    column: $table.confirmationStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MobileServiceJobsTableTableManager
    extends
        RootTableManager<
          _$MobileShopDatabase,
          $MobileServiceJobsTable,
          MobileServiceJobEntity,
          $$MobileServiceJobsTableFilterComposer,
          $$MobileServiceJobsTableOrderingComposer,
          $$MobileServiceJobsTableAnnotationComposer,
          $$MobileServiceJobsTableCreateCompanionBuilder,
          $$MobileServiceJobsTableUpdateCompanionBuilder,
          (
            MobileServiceJobEntity,
            BaseReferences<
              _$MobileShopDatabase,
              $MobileServiceJobsTable,
              MobileServiceJobEntity
            >,
          ),
          MobileServiceJobEntity,
          PrefetchHooks Function()
        > {
  $$MobileServiceJobsTableTableManager(
    _$MobileShopDatabase db,
    $MobileServiceJobsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MobileServiceJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MobileServiceJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MobileServiceJobsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String?> imei = const Value.absent(),
                Value<String?> customerId = const Value.absent(),
                Value<String?> customerName = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> technicianId = const Value.absent(),
                Value<String?> problemDescription = const Value.absent(),
                Value<String?> diagnosis = const Value.absent(),
                Value<int?> estimatedCostPaise = const Value.absent(),
                Value<int?> actualCostPaise = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<String> confirmationStatus = const Value.absent(),
                Value<int> dataModelVersion = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MobileServiceJobsCompanion(
                id: id,
                tenantId: tenantId,
                entityId: entityId,
                imei: imei,
                customerId: customerId,
                customerName: customerName,
                status: status,
                technicianId: technicianId,
                problemDescription: problemDescription,
                diagnosis: diagnosis,
                estimatedCostPaise: estimatedCostPaise,
                actualCostPaise: actualCostPaise,
                dueAt: dueAt,
                version: version,
                serverVersion: serverVersion,
                confirmationStatus: confirmationStatus,
                dataModelVersion: dataModelVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String entityId,
                Value<String?> imei = const Value.absent(),
                Value<String?> customerId = const Value.absent(),
                Value<String?> customerName = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> technicianId = const Value.absent(),
                Value<String?> problemDescription = const Value.absent(),
                Value<String?> diagnosis = const Value.absent(),
                Value<int?> estimatedCostPaise = const Value.absent(),
                Value<int?> actualCostPaise = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<String> confirmationStatus = const Value.absent(),
                Value<int> dataModelVersion = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MobileServiceJobsCompanion.insert(
                id: id,
                tenantId: tenantId,
                entityId: entityId,
                imei: imei,
                customerId: customerId,
                customerName: customerName,
                status: status,
                technicianId: technicianId,
                problemDescription: problemDescription,
                diagnosis: diagnosis,
                estimatedCostPaise: estimatedCostPaise,
                actualCostPaise: actualCostPaise,
                dueAt: dueAt,
                version: version,
                serverVersion: serverVersion,
                confirmationStatus: confirmationStatus,
                dataModelVersion: dataModelVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MobileServiceJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$MobileShopDatabase,
      $MobileServiceJobsTable,
      MobileServiceJobEntity,
      $$MobileServiceJobsTableFilterComposer,
      $$MobileServiceJobsTableOrderingComposer,
      $$MobileServiceJobsTableAnnotationComposer,
      $$MobileServiceJobsTableCreateCompanionBuilder,
      $$MobileServiceJobsTableUpdateCompanionBuilder,
      (
        MobileServiceJobEntity,
        BaseReferences<
          _$MobileShopDatabase,
          $MobileServiceJobsTable,
          MobileServiceJobEntity
        >,
      ),
      MobileServiceJobEntity,
      PrefetchHooks Function()
    >;
typedef $$MobileExchangesTableCreateCompanionBuilder =
    MobileExchangesCompanion Function({
      required String id,
      required String tenantId,
      required String entityId,
      Value<String?> oldDeviceImei,
      Value<String?> newDeviceImei,
      Value<String?> customerId,
      Value<int?> oldDeviceValuationPaise,
      Value<int?> adjustmentPaise,
      Value<String> status,
      Value<int> version,
      Value<int> serverVersion,
      Value<String> confirmationStatus,
      Value<int> dataModelVersion,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MobileExchangesTableUpdateCompanionBuilder =
    MobileExchangesCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> entityId,
      Value<String?> oldDeviceImei,
      Value<String?> newDeviceImei,
      Value<String?> customerId,
      Value<int?> oldDeviceValuationPaise,
      Value<int?> adjustmentPaise,
      Value<String> status,
      Value<int> version,
      Value<int> serverVersion,
      Value<String> confirmationStatus,
      Value<int> dataModelVersion,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$MobileExchangesTableFilterComposer
    extends Composer<_$MobileShopDatabase, $MobileExchangesTable> {
  $$MobileExchangesTableFilterComposer({
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

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oldDeviceImei => $composableBuilder(
    column: $table.oldDeviceImei,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get newDeviceImei => $composableBuilder(
    column: $table.newDeviceImei,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get oldDeviceValuationPaise => $composableBuilder(
    column: $table.oldDeviceValuationPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get adjustmentPaise => $composableBuilder(
    column: $table.adjustmentPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confirmationStatus => $composableBuilder(
    column: $table.confirmationStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
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
}

class $$MobileExchangesTableOrderingComposer
    extends Composer<_$MobileShopDatabase, $MobileExchangesTable> {
  $$MobileExchangesTableOrderingComposer({
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

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oldDeviceImei => $composableBuilder(
    column: $table.oldDeviceImei,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get newDeviceImei => $composableBuilder(
    column: $table.newDeviceImei,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get oldDeviceValuationPaise => $composableBuilder(
    column: $table.oldDeviceValuationPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get adjustmentPaise => $composableBuilder(
    column: $table.adjustmentPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confirmationStatus => $composableBuilder(
    column: $table.confirmationStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
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
}

class $$MobileExchangesTableAnnotationComposer
    extends Composer<_$MobileShopDatabase, $MobileExchangesTable> {
  $$MobileExchangesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get oldDeviceImei => $composableBuilder(
    column: $table.oldDeviceImei,
    builder: (column) => column,
  );

  GeneratedColumn<String> get newDeviceImei => $composableBuilder(
    column: $table.newDeviceImei,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get oldDeviceValuationPaise => $composableBuilder(
    column: $table.oldDeviceValuationPaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get adjustmentPaise => $composableBuilder(
    column: $table.adjustmentPaise,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get confirmationStatus => $composableBuilder(
    column: $table.confirmationStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MobileExchangesTableTableManager
    extends
        RootTableManager<
          _$MobileShopDatabase,
          $MobileExchangesTable,
          MobileExchangeEntity,
          $$MobileExchangesTableFilterComposer,
          $$MobileExchangesTableOrderingComposer,
          $$MobileExchangesTableAnnotationComposer,
          $$MobileExchangesTableCreateCompanionBuilder,
          $$MobileExchangesTableUpdateCompanionBuilder,
          (
            MobileExchangeEntity,
            BaseReferences<
              _$MobileShopDatabase,
              $MobileExchangesTable,
              MobileExchangeEntity
            >,
          ),
          MobileExchangeEntity,
          PrefetchHooks Function()
        > {
  $$MobileExchangesTableTableManager(
    _$MobileShopDatabase db,
    $MobileExchangesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MobileExchangesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MobileExchangesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MobileExchangesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String?> oldDeviceImei = const Value.absent(),
                Value<String?> newDeviceImei = const Value.absent(),
                Value<String?> customerId = const Value.absent(),
                Value<int?> oldDeviceValuationPaise = const Value.absent(),
                Value<int?> adjustmentPaise = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<String> confirmationStatus = const Value.absent(),
                Value<int> dataModelVersion = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MobileExchangesCompanion(
                id: id,
                tenantId: tenantId,
                entityId: entityId,
                oldDeviceImei: oldDeviceImei,
                newDeviceImei: newDeviceImei,
                customerId: customerId,
                oldDeviceValuationPaise: oldDeviceValuationPaise,
                adjustmentPaise: adjustmentPaise,
                status: status,
                version: version,
                serverVersion: serverVersion,
                confirmationStatus: confirmationStatus,
                dataModelVersion: dataModelVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String entityId,
                Value<String?> oldDeviceImei = const Value.absent(),
                Value<String?> newDeviceImei = const Value.absent(),
                Value<String?> customerId = const Value.absent(),
                Value<int?> oldDeviceValuationPaise = const Value.absent(),
                Value<int?> adjustmentPaise = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<String> confirmationStatus = const Value.absent(),
                Value<int> dataModelVersion = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MobileExchangesCompanion.insert(
                id: id,
                tenantId: tenantId,
                entityId: entityId,
                oldDeviceImei: oldDeviceImei,
                newDeviceImei: newDeviceImei,
                customerId: customerId,
                oldDeviceValuationPaise: oldDeviceValuationPaise,
                adjustmentPaise: adjustmentPaise,
                status: status,
                version: version,
                serverVersion: serverVersion,
                confirmationStatus: confirmationStatus,
                dataModelVersion: dataModelVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MobileExchangesTableProcessedTableManager =
    ProcessedTableManager<
      _$MobileShopDatabase,
      $MobileExchangesTable,
      MobileExchangeEntity,
      $$MobileExchangesTableFilterComposer,
      $$MobileExchangesTableOrderingComposer,
      $$MobileExchangesTableAnnotationComposer,
      $$MobileExchangesTableCreateCompanionBuilder,
      $$MobileExchangesTableUpdateCompanionBuilder,
      (
        MobileExchangeEntity,
        BaseReferences<
          _$MobileShopDatabase,
          $MobileExchangesTable,
          MobileExchangeEntity
        >,
      ),
      MobileExchangeEntity,
      PrefetchHooks Function()
    >;
typedef $$MobileWarrantiesTableCreateCompanionBuilder =
    MobileWarrantiesCompanion Function({
      required String id,
      required String tenantId,
      required String entityId,
      required String imei,
      Value<String?> provider,
      Value<int?> warrantyMonths,
      Value<DateTime?> startDate,
      Value<DateTime?> endDate,
      Value<String> status,
      Value<String?> claimStatus,
      Value<String?> evidenceRef,
      Value<int> version,
      Value<int> serverVersion,
      Value<String> confirmationStatus,
      Value<int> dataModelVersion,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MobileWarrantiesTableUpdateCompanionBuilder =
    MobileWarrantiesCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> entityId,
      Value<String> imei,
      Value<String?> provider,
      Value<int?> warrantyMonths,
      Value<DateTime?> startDate,
      Value<DateTime?> endDate,
      Value<String> status,
      Value<String?> claimStatus,
      Value<String?> evidenceRef,
      Value<int> version,
      Value<int> serverVersion,
      Value<String> confirmationStatus,
      Value<int> dataModelVersion,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$MobileWarrantiesTableFilterComposer
    extends Composer<_$MobileShopDatabase, $MobileWarrantiesTable> {
  $$MobileWarrantiesTableFilterComposer({
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

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imei => $composableBuilder(
    column: $table.imei,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get warrantyMonths => $composableBuilder(
    column: $table.warrantyMonths,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get claimStatus => $composableBuilder(
    column: $table.claimStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evidenceRef => $composableBuilder(
    column: $table.evidenceRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confirmationStatus => $composableBuilder(
    column: $table.confirmationStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
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
}

class $$MobileWarrantiesTableOrderingComposer
    extends Composer<_$MobileShopDatabase, $MobileWarrantiesTable> {
  $$MobileWarrantiesTableOrderingComposer({
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

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imei => $composableBuilder(
    column: $table.imei,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get warrantyMonths => $composableBuilder(
    column: $table.warrantyMonths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get claimStatus => $composableBuilder(
    column: $table.claimStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evidenceRef => $composableBuilder(
    column: $table.evidenceRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confirmationStatus => $composableBuilder(
    column: $table.confirmationStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
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
}

class $$MobileWarrantiesTableAnnotationComposer
    extends Composer<_$MobileShopDatabase, $MobileWarrantiesTable> {
  $$MobileWarrantiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get imei =>
      $composableBuilder(column: $table.imei, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<int> get warrantyMonths => $composableBuilder(
    column: $table.warrantyMonths,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get claimStatus => $composableBuilder(
    column: $table.claimStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get evidenceRef => $composableBuilder(
    column: $table.evidenceRef,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get confirmationStatus => $composableBuilder(
    column: $table.confirmationStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MobileWarrantiesTableTableManager
    extends
        RootTableManager<
          _$MobileShopDatabase,
          $MobileWarrantiesTable,
          MobileWarrantyEntity,
          $$MobileWarrantiesTableFilterComposer,
          $$MobileWarrantiesTableOrderingComposer,
          $$MobileWarrantiesTableAnnotationComposer,
          $$MobileWarrantiesTableCreateCompanionBuilder,
          $$MobileWarrantiesTableUpdateCompanionBuilder,
          (
            MobileWarrantyEntity,
            BaseReferences<
              _$MobileShopDatabase,
              $MobileWarrantiesTable,
              MobileWarrantyEntity
            >,
          ),
          MobileWarrantyEntity,
          PrefetchHooks Function()
        > {
  $$MobileWarrantiesTableTableManager(
    _$MobileShopDatabase db,
    $MobileWarrantiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MobileWarrantiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MobileWarrantiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MobileWarrantiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> imei = const Value.absent(),
                Value<String?> provider = const Value.absent(),
                Value<int?> warrantyMonths = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> claimStatus = const Value.absent(),
                Value<String?> evidenceRef = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<String> confirmationStatus = const Value.absent(),
                Value<int> dataModelVersion = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MobileWarrantiesCompanion(
                id: id,
                tenantId: tenantId,
                entityId: entityId,
                imei: imei,
                provider: provider,
                warrantyMonths: warrantyMonths,
                startDate: startDate,
                endDate: endDate,
                status: status,
                claimStatus: claimStatus,
                evidenceRef: evidenceRef,
                version: version,
                serverVersion: serverVersion,
                confirmationStatus: confirmationStatus,
                dataModelVersion: dataModelVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String entityId,
                required String imei,
                Value<String?> provider = const Value.absent(),
                Value<int?> warrantyMonths = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> claimStatus = const Value.absent(),
                Value<String?> evidenceRef = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<String> confirmationStatus = const Value.absent(),
                Value<int> dataModelVersion = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MobileWarrantiesCompanion.insert(
                id: id,
                tenantId: tenantId,
                entityId: entityId,
                imei: imei,
                provider: provider,
                warrantyMonths: warrantyMonths,
                startDate: startDate,
                endDate: endDate,
                status: status,
                claimStatus: claimStatus,
                evidenceRef: evidenceRef,
                version: version,
                serverVersion: serverVersion,
                confirmationStatus: confirmationStatus,
                dataModelVersion: dataModelVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MobileWarrantiesTableProcessedTableManager =
    ProcessedTableManager<
      _$MobileShopDatabase,
      $MobileWarrantiesTable,
      MobileWarrantyEntity,
      $$MobileWarrantiesTableFilterComposer,
      $$MobileWarrantiesTableOrderingComposer,
      $$MobileWarrantiesTableAnnotationComposer,
      $$MobileWarrantiesTableCreateCompanionBuilder,
      $$MobileWarrantiesTableUpdateCompanionBuilder,
      (
        MobileWarrantyEntity,
        BaseReferences<
          _$MobileShopDatabase,
          $MobileWarrantiesTable,
          MobileWarrantyEntity
        >,
      ),
      MobileWarrantyEntity,
      PrefetchHooks Function()
    >;
typedef $$MobileReconciliationStatusTableCreateCompanionBuilder =
    MobileReconciliationStatusCompanion Function({
      required String id,
      required String tenantId,
      required String operationId,
      Value<String?> reconciliationId,
      Value<String> status,
      Value<int> totalSteps,
      Value<int> completedSteps,
      Value<String?> latestError,
      Value<String?> terminalEvidence,
      Value<int> dataModelVersion,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MobileReconciliationStatusTableUpdateCompanionBuilder =
    MobileReconciliationStatusCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> operationId,
      Value<String?> reconciliationId,
      Value<String> status,
      Value<int> totalSteps,
      Value<int> completedSteps,
      Value<String?> latestError,
      Value<String?> terminalEvidence,
      Value<int> dataModelVersion,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$MobileReconciliationStatusTableFilterComposer
    extends Composer<_$MobileShopDatabase, $MobileReconciliationStatusTable> {
  $$MobileReconciliationStatusTableFilterComposer({
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

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reconciliationId => $composableBuilder(
    column: $table.reconciliationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalSteps => $composableBuilder(
    column: $table.totalSteps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedSteps => $composableBuilder(
    column: $table.completedSteps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get latestError => $composableBuilder(
    column: $table.latestError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get terminalEvidence => $composableBuilder(
    column: $table.terminalEvidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
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
}

class $$MobileReconciliationStatusTableOrderingComposer
    extends Composer<_$MobileShopDatabase, $MobileReconciliationStatusTable> {
  $$MobileReconciliationStatusTableOrderingComposer({
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

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reconciliationId => $composableBuilder(
    column: $table.reconciliationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalSteps => $composableBuilder(
    column: $table.totalSteps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedSteps => $composableBuilder(
    column: $table.completedSteps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get latestError => $composableBuilder(
    column: $table.latestError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get terminalEvidence => $composableBuilder(
    column: $table.terminalEvidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
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
}

class $$MobileReconciliationStatusTableAnnotationComposer
    extends Composer<_$MobileShopDatabase, $MobileReconciliationStatusTable> {
  $$MobileReconciliationStatusTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reconciliationId => $composableBuilder(
    column: $table.reconciliationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get totalSteps => $composableBuilder(
    column: $table.totalSteps,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedSteps => $composableBuilder(
    column: $table.completedSteps,
    builder: (column) => column,
  );

  GeneratedColumn<String> get latestError => $composableBuilder(
    column: $table.latestError,
    builder: (column) => column,
  );

  GeneratedColumn<String> get terminalEvidence => $composableBuilder(
    column: $table.terminalEvidence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MobileReconciliationStatusTableTableManager
    extends
        RootTableManager<
          _$MobileShopDatabase,
          $MobileReconciliationStatusTable,
          MobileReconciliationStatusEntity,
          $$MobileReconciliationStatusTableFilterComposer,
          $$MobileReconciliationStatusTableOrderingComposer,
          $$MobileReconciliationStatusTableAnnotationComposer,
          $$MobileReconciliationStatusTableCreateCompanionBuilder,
          $$MobileReconciliationStatusTableUpdateCompanionBuilder,
          (
            MobileReconciliationStatusEntity,
            BaseReferences<
              _$MobileShopDatabase,
              $MobileReconciliationStatusTable,
              MobileReconciliationStatusEntity
            >,
          ),
          MobileReconciliationStatusEntity,
          PrefetchHooks Function()
        > {
  $$MobileReconciliationStatusTableTableManager(
    _$MobileShopDatabase db,
    $MobileReconciliationStatusTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MobileReconciliationStatusTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$MobileReconciliationStatusTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MobileReconciliationStatusTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<String?> reconciliationId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> totalSteps = const Value.absent(),
                Value<int> completedSteps = const Value.absent(),
                Value<String?> latestError = const Value.absent(),
                Value<String?> terminalEvidence = const Value.absent(),
                Value<int> dataModelVersion = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MobileReconciliationStatusCompanion(
                id: id,
                tenantId: tenantId,
                operationId: operationId,
                reconciliationId: reconciliationId,
                status: status,
                totalSteps: totalSteps,
                completedSteps: completedSteps,
                latestError: latestError,
                terminalEvidence: terminalEvidence,
                dataModelVersion: dataModelVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String operationId,
                Value<String?> reconciliationId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> totalSteps = const Value.absent(),
                Value<int> completedSteps = const Value.absent(),
                Value<String?> latestError = const Value.absent(),
                Value<String?> terminalEvidence = const Value.absent(),
                Value<int> dataModelVersion = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MobileReconciliationStatusCompanion.insert(
                id: id,
                tenantId: tenantId,
                operationId: operationId,
                reconciliationId: reconciliationId,
                status: status,
                totalSteps: totalSteps,
                completedSteps: completedSteps,
                latestError: latestError,
                terminalEvidence: terminalEvidence,
                dataModelVersion: dataModelVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MobileReconciliationStatusTableProcessedTableManager =
    ProcessedTableManager<
      _$MobileShopDatabase,
      $MobileReconciliationStatusTable,
      MobileReconciliationStatusEntity,
      $$MobileReconciliationStatusTableFilterComposer,
      $$MobileReconciliationStatusTableOrderingComposer,
      $$MobileReconciliationStatusTableAnnotationComposer,
      $$MobileReconciliationStatusTableCreateCompanionBuilder,
      $$MobileReconciliationStatusTableUpdateCompanionBuilder,
      (
        MobileReconciliationStatusEntity,
        BaseReferences<
          _$MobileShopDatabase,
          $MobileReconciliationStatusTable,
          MobileReconciliationStatusEntity
        >,
      ),
      MobileReconciliationStatusEntity,
      PrefetchHooks Function()
    >;
typedef $$MobileProviderStateTableCreateCompanionBuilder =
    MobileProviderStateCompanion Function({
      required String id,
      required String tenantId,
      required String operationId,
      required String providerRequestId,
      required String providerType,
      Value<String?> requestPayload,
      Value<String> responseStatus,
      Value<String?> responsePayload,
      Value<String?> externalRef,
      Value<int> dataModelVersion,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MobileProviderStateTableUpdateCompanionBuilder =
    MobileProviderStateCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> operationId,
      Value<String> providerRequestId,
      Value<String> providerType,
      Value<String?> requestPayload,
      Value<String> responseStatus,
      Value<String?> responsePayload,
      Value<String?> externalRef,
      Value<int> dataModelVersion,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$MobileProviderStateTableFilterComposer
    extends Composer<_$MobileShopDatabase, $MobileProviderStateTable> {
  $$MobileProviderStateTableFilterComposer({
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

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerRequestId => $composableBuilder(
    column: $table.providerRequestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerType => $composableBuilder(
    column: $table.providerType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestPayload => $composableBuilder(
    column: $table.requestPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get responseStatus => $composableBuilder(
    column: $table.responseStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get responsePayload => $composableBuilder(
    column: $table.responsePayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalRef => $composableBuilder(
    column: $table.externalRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
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
}

class $$MobileProviderStateTableOrderingComposer
    extends Composer<_$MobileShopDatabase, $MobileProviderStateTable> {
  $$MobileProviderStateTableOrderingComposer({
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

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerRequestId => $composableBuilder(
    column: $table.providerRequestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerType => $composableBuilder(
    column: $table.providerType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestPayload => $composableBuilder(
    column: $table.requestPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get responseStatus => $composableBuilder(
    column: $table.responseStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get responsePayload => $composableBuilder(
    column: $table.responsePayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalRef => $composableBuilder(
    column: $table.externalRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
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
}

class $$MobileProviderStateTableAnnotationComposer
    extends Composer<_$MobileShopDatabase, $MobileProviderStateTable> {
  $$MobileProviderStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerRequestId => $composableBuilder(
    column: $table.providerRequestId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerType => $composableBuilder(
    column: $table.providerType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get requestPayload => $composableBuilder(
    column: $table.requestPayload,
    builder: (column) => column,
  );

  GeneratedColumn<String> get responseStatus => $composableBuilder(
    column: $table.responseStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get responsePayload => $composableBuilder(
    column: $table.responsePayload,
    builder: (column) => column,
  );

  GeneratedColumn<String> get externalRef => $composableBuilder(
    column: $table.externalRef,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MobileProviderStateTableTableManager
    extends
        RootTableManager<
          _$MobileShopDatabase,
          $MobileProviderStateTable,
          MobileProviderStateEntity,
          $$MobileProviderStateTableFilterComposer,
          $$MobileProviderStateTableOrderingComposer,
          $$MobileProviderStateTableAnnotationComposer,
          $$MobileProviderStateTableCreateCompanionBuilder,
          $$MobileProviderStateTableUpdateCompanionBuilder,
          (
            MobileProviderStateEntity,
            BaseReferences<
              _$MobileShopDatabase,
              $MobileProviderStateTable,
              MobileProviderStateEntity
            >,
          ),
          MobileProviderStateEntity,
          PrefetchHooks Function()
        > {
  $$MobileProviderStateTableTableManager(
    _$MobileShopDatabase db,
    $MobileProviderStateTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MobileProviderStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MobileProviderStateTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MobileProviderStateTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<String> providerRequestId = const Value.absent(),
                Value<String> providerType = const Value.absent(),
                Value<String?> requestPayload = const Value.absent(),
                Value<String> responseStatus = const Value.absent(),
                Value<String?> responsePayload = const Value.absent(),
                Value<String?> externalRef = const Value.absent(),
                Value<int> dataModelVersion = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MobileProviderStateCompanion(
                id: id,
                tenantId: tenantId,
                operationId: operationId,
                providerRequestId: providerRequestId,
                providerType: providerType,
                requestPayload: requestPayload,
                responseStatus: responseStatus,
                responsePayload: responsePayload,
                externalRef: externalRef,
                dataModelVersion: dataModelVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String operationId,
                required String providerRequestId,
                required String providerType,
                Value<String?> requestPayload = const Value.absent(),
                Value<String> responseStatus = const Value.absent(),
                Value<String?> responsePayload = const Value.absent(),
                Value<String?> externalRef = const Value.absent(),
                Value<int> dataModelVersion = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MobileProviderStateCompanion.insert(
                id: id,
                tenantId: tenantId,
                operationId: operationId,
                providerRequestId: providerRequestId,
                providerType: providerType,
                requestPayload: requestPayload,
                responseStatus: responseStatus,
                responsePayload: responsePayload,
                externalRef: externalRef,
                dataModelVersion: dataModelVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MobileProviderStateTableProcessedTableManager =
    ProcessedTableManager<
      _$MobileShopDatabase,
      $MobileProviderStateTable,
      MobileProviderStateEntity,
      $$MobileProviderStateTableFilterComposer,
      $$MobileProviderStateTableOrderingComposer,
      $$MobileProviderStateTableAnnotationComposer,
      $$MobileProviderStateTableCreateCompanionBuilder,
      $$MobileProviderStateTableUpdateCompanionBuilder,
      (
        MobileProviderStateEntity,
        BaseReferences<
          _$MobileShopDatabase,
          $MobileProviderStateTable,
          MobileProviderStateEntity
        >,
      ),
      MobileProviderStateEntity,
      PrefetchHooks Function()
    >;
typedef $$MobileOutboxMutationsTableCreateCompanionBuilder =
    MobileOutboxMutationsCompanion Function({
      required String id,
      required String tenantId,
      required String operationId,
      required String mutationFingerprint,
      required String entityType,
      required String payload,
      Value<String?> baseVersions,
      Value<String?> dependencies,
      Value<int> retryCount,
      Value<int> maxRetries,
      Value<String> status,
      Value<int> dataModelVersion,
      required DateTime createdAt,
      Value<DateTime?> lastAttemptAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MobileOutboxMutationsTableUpdateCompanionBuilder =
    MobileOutboxMutationsCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> operationId,
      Value<String> mutationFingerprint,
      Value<String> entityType,
      Value<String> payload,
      Value<String?> baseVersions,
      Value<String?> dependencies,
      Value<int> retryCount,
      Value<int> maxRetries,
      Value<String> status,
      Value<int> dataModelVersion,
      Value<DateTime> createdAt,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$MobileOutboxMutationsTableFilterComposer
    extends Composer<_$MobileShopDatabase, $MobileOutboxMutationsTable> {
  $$MobileOutboxMutationsTableFilterComposer({
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

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mutationFingerprint => $composableBuilder(
    column: $table.mutationFingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseVersions => $composableBuilder(
    column: $table.baseVersions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dependencies => $composableBuilder(
    column: $table.dependencies,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxRetries => $composableBuilder(
    column: $table.maxRetries,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MobileOutboxMutationsTableOrderingComposer
    extends Composer<_$MobileShopDatabase, $MobileOutboxMutationsTable> {
  $$MobileOutboxMutationsTableOrderingComposer({
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

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mutationFingerprint => $composableBuilder(
    column: $table.mutationFingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseVersions => $composableBuilder(
    column: $table.baseVersions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dependencies => $composableBuilder(
    column: $table.dependencies,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxRetries => $composableBuilder(
    column: $table.maxRetries,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MobileOutboxMutationsTableAnnotationComposer
    extends Composer<_$MobileShopDatabase, $MobileOutboxMutationsTable> {
  $$MobileOutboxMutationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mutationFingerprint => $composableBuilder(
    column: $table.mutationFingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get baseVersions => $composableBuilder(
    column: $table.baseVersions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dependencies => $composableBuilder(
    column: $table.dependencies,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxRetries => $composableBuilder(
    column: $table.maxRetries,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MobileOutboxMutationsTableTableManager
    extends
        RootTableManager<
          _$MobileShopDatabase,
          $MobileOutboxMutationsTable,
          MobileOutboxMutationEntity,
          $$MobileOutboxMutationsTableFilterComposer,
          $$MobileOutboxMutationsTableOrderingComposer,
          $$MobileOutboxMutationsTableAnnotationComposer,
          $$MobileOutboxMutationsTableCreateCompanionBuilder,
          $$MobileOutboxMutationsTableUpdateCompanionBuilder,
          (
            MobileOutboxMutationEntity,
            BaseReferences<
              _$MobileShopDatabase,
              $MobileOutboxMutationsTable,
              MobileOutboxMutationEntity
            >,
          ),
          MobileOutboxMutationEntity,
          PrefetchHooks Function()
        > {
  $$MobileOutboxMutationsTableTableManager(
    _$MobileShopDatabase db,
    $MobileOutboxMutationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MobileOutboxMutationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$MobileOutboxMutationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MobileOutboxMutationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<String> mutationFingerprint = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String?> baseVersions = const Value.absent(),
                Value<String?> dependencies = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int> maxRetries = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> dataModelVersion = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MobileOutboxMutationsCompanion(
                id: id,
                tenantId: tenantId,
                operationId: operationId,
                mutationFingerprint: mutationFingerprint,
                entityType: entityType,
                payload: payload,
                baseVersions: baseVersions,
                dependencies: dependencies,
                retryCount: retryCount,
                maxRetries: maxRetries,
                status: status,
                dataModelVersion: dataModelVersion,
                createdAt: createdAt,
                lastAttemptAt: lastAttemptAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String operationId,
                required String mutationFingerprint,
                required String entityType,
                required String payload,
                Value<String?> baseVersions = const Value.absent(),
                Value<String?> dependencies = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int> maxRetries = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> dataModelVersion = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MobileOutboxMutationsCompanion.insert(
                id: id,
                tenantId: tenantId,
                operationId: operationId,
                mutationFingerprint: mutationFingerprint,
                entityType: entityType,
                payload: payload,
                baseVersions: baseVersions,
                dependencies: dependencies,
                retryCount: retryCount,
                maxRetries: maxRetries,
                status: status,
                dataModelVersion: dataModelVersion,
                createdAt: createdAt,
                lastAttemptAt: lastAttemptAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MobileOutboxMutationsTableProcessedTableManager =
    ProcessedTableManager<
      _$MobileShopDatabase,
      $MobileOutboxMutationsTable,
      MobileOutboxMutationEntity,
      $$MobileOutboxMutationsTableFilterComposer,
      $$MobileOutboxMutationsTableOrderingComposer,
      $$MobileOutboxMutationsTableAnnotationComposer,
      $$MobileOutboxMutationsTableCreateCompanionBuilder,
      $$MobileOutboxMutationsTableUpdateCompanionBuilder,
      (
        MobileOutboxMutationEntity,
        BaseReferences<
          _$MobileShopDatabase,
          $MobileOutboxMutationsTable,
          MobileOutboxMutationEntity
        >,
      ),
      MobileOutboxMutationEntity,
      PrefetchHooks Function()
    >;
typedef $$MobileConflictsTableCreateCompanionBuilder =
    MobileConflictsCompanion Function({
      required String id,
      required String tenantId,
      required String operationId,
      required String entityType,
      required String entityId,
      required int localVersion,
      required int serverVersion,
      required String reason,
      Value<String> resolutionStatus,
      Value<String?> resolutionEvidence,
      Value<int> dataModelVersion,
      required DateTime createdAt,
      Value<DateTime?> resolvedAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MobileConflictsTableUpdateCompanionBuilder =
    MobileConflictsCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> operationId,
      Value<String> entityType,
      Value<String> entityId,
      Value<int> localVersion,
      Value<int> serverVersion,
      Value<String> reason,
      Value<String> resolutionStatus,
      Value<String?> resolutionEvidence,
      Value<int> dataModelVersion,
      Value<DateTime> createdAt,
      Value<DateTime?> resolvedAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$MobileConflictsTableFilterComposer
    extends Composer<_$MobileShopDatabase, $MobileConflictsTable> {
  $$MobileConflictsTableFilterComposer({
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

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
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

  ColumnFilters<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolutionStatus => $composableBuilder(
    column: $table.resolutionStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolutionEvidence => $composableBuilder(
    column: $table.resolutionEvidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MobileConflictsTableOrderingComposer
    extends Composer<_$MobileShopDatabase, $MobileConflictsTable> {
  $$MobileConflictsTableOrderingComposer({
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

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
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

  ColumnOrderings<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolutionStatus => $composableBuilder(
    column: $table.resolutionStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolutionEvidence => $composableBuilder(
    column: $table.resolutionEvidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MobileConflictsTableAnnotationComposer
    extends Composer<_$MobileShopDatabase, $MobileConflictsTable> {
  $$MobileConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get resolutionStatus => $composableBuilder(
    column: $table.resolutionStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolutionEvidence => $composableBuilder(
    column: $table.resolutionEvidence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MobileConflictsTableTableManager
    extends
        RootTableManager<
          _$MobileShopDatabase,
          $MobileConflictsTable,
          MobileConflictEntity,
          $$MobileConflictsTableFilterComposer,
          $$MobileConflictsTableOrderingComposer,
          $$MobileConflictsTableAnnotationComposer,
          $$MobileConflictsTableCreateCompanionBuilder,
          $$MobileConflictsTableUpdateCompanionBuilder,
          (
            MobileConflictEntity,
            BaseReferences<
              _$MobileShopDatabase,
              $MobileConflictsTable,
              MobileConflictEntity
            >,
          ),
          MobileConflictEntity,
          PrefetchHooks Function()
        > {
  $$MobileConflictsTableTableManager(
    _$MobileShopDatabase db,
    $MobileConflictsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MobileConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MobileConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MobileConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<int> localVersion = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<String> resolutionStatus = const Value.absent(),
                Value<String?> resolutionEvidence = const Value.absent(),
                Value<int> dataModelVersion = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MobileConflictsCompanion(
                id: id,
                tenantId: tenantId,
                operationId: operationId,
                entityType: entityType,
                entityId: entityId,
                localVersion: localVersion,
                serverVersion: serverVersion,
                reason: reason,
                resolutionStatus: resolutionStatus,
                resolutionEvidence: resolutionEvidence,
                dataModelVersion: dataModelVersion,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String operationId,
                required String entityType,
                required String entityId,
                required int localVersion,
                required int serverVersion,
                required String reason,
                Value<String> resolutionStatus = const Value.absent(),
                Value<String?> resolutionEvidence = const Value.absent(),
                Value<int> dataModelVersion = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> resolvedAt = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MobileConflictsCompanion.insert(
                id: id,
                tenantId: tenantId,
                operationId: operationId,
                entityType: entityType,
                entityId: entityId,
                localVersion: localVersion,
                serverVersion: serverVersion,
                reason: reason,
                resolutionStatus: resolutionStatus,
                resolutionEvidence: resolutionEvidence,
                dataModelVersion: dataModelVersion,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MobileConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$MobileShopDatabase,
      $MobileConflictsTable,
      MobileConflictEntity,
      $$MobileConflictsTableFilterComposer,
      $$MobileConflictsTableOrderingComposer,
      $$MobileConflictsTableAnnotationComposer,
      $$MobileConflictsTableCreateCompanionBuilder,
      $$MobileConflictsTableUpdateCompanionBuilder,
      (
        MobileConflictEntity,
        BaseReferences<
          _$MobileShopDatabase,
          $MobileConflictsTable,
          MobileConflictEntity
        >,
      ),
      MobileConflictEntity,
      PrefetchHooks Function()
    >;
typedef $$MobileEventInboxTableCreateCompanionBuilder =
    MobileEventInboxCompanion Function({
      required String id,
      required String tenantId,
      required String eventId,
      required String entityType,
      required String entityId,
      required int version,
      required String action,
      Value<int> dataModelVersion,
      required DateTime receivedAt,
      Value<DateTime?> processedAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MobileEventInboxTableUpdateCompanionBuilder =
    MobileEventInboxCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> eventId,
      Value<String> entityType,
      Value<String> entityId,
      Value<int> version,
      Value<String> action,
      Value<int> dataModelVersion,
      Value<DateTime> receivedAt,
      Value<DateTime?> processedAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$MobileEventInboxTableFilterComposer
    extends Composer<_$MobileShopDatabase, $MobileEventInboxTable> {
  $$MobileEventInboxTableFilterComposer({
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

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
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

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MobileEventInboxTableOrderingComposer
    extends Composer<_$MobileShopDatabase, $MobileEventInboxTable> {
  $$MobileEventInboxTableOrderingComposer({
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

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
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

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MobileEventInboxTableAnnotationComposer
    extends Composer<_$MobileShopDatabase, $MobileEventInboxTable> {
  $$MobileEventInboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MobileEventInboxTableTableManager
    extends
        RootTableManager<
          _$MobileShopDatabase,
          $MobileEventInboxTable,
          MobileEventInboxEntity,
          $$MobileEventInboxTableFilterComposer,
          $$MobileEventInboxTableOrderingComposer,
          $$MobileEventInboxTableAnnotationComposer,
          $$MobileEventInboxTableCreateCompanionBuilder,
          $$MobileEventInboxTableUpdateCompanionBuilder,
          (
            MobileEventInboxEntity,
            BaseReferences<
              _$MobileShopDatabase,
              $MobileEventInboxTable,
              MobileEventInboxEntity
            >,
          ),
          MobileEventInboxEntity,
          PrefetchHooks Function()
        > {
  $$MobileEventInboxTableTableManager(
    _$MobileShopDatabase db,
    $MobileEventInboxTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MobileEventInboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MobileEventInboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MobileEventInboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<int> dataModelVersion = const Value.absent(),
                Value<DateTime> receivedAt = const Value.absent(),
                Value<DateTime?> processedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MobileEventInboxCompanion(
                id: id,
                tenantId: tenantId,
                eventId: eventId,
                entityType: entityType,
                entityId: entityId,
                version: version,
                action: action,
                dataModelVersion: dataModelVersion,
                receivedAt: receivedAt,
                processedAt: processedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String eventId,
                required String entityType,
                required String entityId,
                required int version,
                required String action,
                Value<int> dataModelVersion = const Value.absent(),
                required DateTime receivedAt,
                Value<DateTime?> processedAt = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MobileEventInboxCompanion.insert(
                id: id,
                tenantId: tenantId,
                eventId: eventId,
                entityType: entityType,
                entityId: entityId,
                version: version,
                action: action,
                dataModelVersion: dataModelVersion,
                receivedAt: receivedAt,
                processedAt: processedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MobileEventInboxTableProcessedTableManager =
    ProcessedTableManager<
      _$MobileShopDatabase,
      $MobileEventInboxTable,
      MobileEventInboxEntity,
      $$MobileEventInboxTableFilterComposer,
      $$MobileEventInboxTableOrderingComposer,
      $$MobileEventInboxTableAnnotationComposer,
      $$MobileEventInboxTableCreateCompanionBuilder,
      $$MobileEventInboxTableUpdateCompanionBuilder,
      (
        MobileEventInboxEntity,
        BaseReferences<
          _$MobileShopDatabase,
          $MobileEventInboxTable,
          MobileEventInboxEntity
        >,
      ),
      MobileEventInboxEntity,
      PrefetchHooks Function()
    >;
typedef $$MobileContinuationCheckpointsTableCreateCompanionBuilder =
    MobileContinuationCheckpointsCompanion Function({
      required String id,
      required String tenantId,
      required String bucket,
      Value<String?> lastPosition,
      Value<DateTime?> lastPulledAt,
      Value<int> serverVersion,
      Value<int> dataModelVersion,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MobileContinuationCheckpointsTableUpdateCompanionBuilder =
    MobileContinuationCheckpointsCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> bucket,
      Value<String?> lastPosition,
      Value<DateTime?> lastPulledAt,
      Value<int> serverVersion,
      Value<int> dataModelVersion,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$MobileContinuationCheckpointsTableFilterComposer
    extends
        Composer<_$MobileShopDatabase, $MobileContinuationCheckpointsTable> {
  $$MobileContinuationCheckpointsTableFilterComposer({
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

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bucket => $composableBuilder(
    column: $table.bucket,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastPosition => $composableBuilder(
    column: $table.lastPosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPulledAt => $composableBuilder(
    column: $table.lastPulledAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
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
}

class $$MobileContinuationCheckpointsTableOrderingComposer
    extends
        Composer<_$MobileShopDatabase, $MobileContinuationCheckpointsTable> {
  $$MobileContinuationCheckpointsTableOrderingComposer({
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

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bucket => $composableBuilder(
    column: $table.bucket,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastPosition => $composableBuilder(
    column: $table.lastPosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPulledAt => $composableBuilder(
    column: $table.lastPulledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
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
}

class $$MobileContinuationCheckpointsTableAnnotationComposer
    extends
        Composer<_$MobileShopDatabase, $MobileContinuationCheckpointsTable> {
  $$MobileContinuationCheckpointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get bucket =>
      $composableBuilder(column: $table.bucket, builder: (column) => column);

  GeneratedColumn<String> get lastPosition => $composableBuilder(
    column: $table.lastPosition,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPulledAt => $composableBuilder(
    column: $table.lastPulledAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dataModelVersion => $composableBuilder(
    column: $table.dataModelVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MobileContinuationCheckpointsTableTableManager
    extends
        RootTableManager<
          _$MobileShopDatabase,
          $MobileContinuationCheckpointsTable,
          MobileContinuationCheckpointEntity,
          $$MobileContinuationCheckpointsTableFilterComposer,
          $$MobileContinuationCheckpointsTableOrderingComposer,
          $$MobileContinuationCheckpointsTableAnnotationComposer,
          $$MobileContinuationCheckpointsTableCreateCompanionBuilder,
          $$MobileContinuationCheckpointsTableUpdateCompanionBuilder,
          (
            MobileContinuationCheckpointEntity,
            BaseReferences<
              _$MobileShopDatabase,
              $MobileContinuationCheckpointsTable,
              MobileContinuationCheckpointEntity
            >,
          ),
          MobileContinuationCheckpointEntity,
          PrefetchHooks Function()
        > {
  $$MobileContinuationCheckpointsTableTableManager(
    _$MobileShopDatabase db,
    $MobileContinuationCheckpointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MobileContinuationCheckpointsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$MobileContinuationCheckpointsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MobileContinuationCheckpointsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> bucket = const Value.absent(),
                Value<String?> lastPosition = const Value.absent(),
                Value<DateTime?> lastPulledAt = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<int> dataModelVersion = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MobileContinuationCheckpointsCompanion(
                id: id,
                tenantId: tenantId,
                bucket: bucket,
                lastPosition: lastPosition,
                lastPulledAt: lastPulledAt,
                serverVersion: serverVersion,
                dataModelVersion: dataModelVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String bucket,
                Value<String?> lastPosition = const Value.absent(),
                Value<DateTime?> lastPulledAt = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<int> dataModelVersion = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MobileContinuationCheckpointsCompanion.insert(
                id: id,
                tenantId: tenantId,
                bucket: bucket,
                lastPosition: lastPosition,
                lastPulledAt: lastPulledAt,
                serverVersion: serverVersion,
                dataModelVersion: dataModelVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MobileContinuationCheckpointsTableProcessedTableManager =
    ProcessedTableManager<
      _$MobileShopDatabase,
      $MobileContinuationCheckpointsTable,
      MobileContinuationCheckpointEntity,
      $$MobileContinuationCheckpointsTableFilterComposer,
      $$MobileContinuationCheckpointsTableOrderingComposer,
      $$MobileContinuationCheckpointsTableAnnotationComposer,
      $$MobileContinuationCheckpointsTableCreateCompanionBuilder,
      $$MobileContinuationCheckpointsTableUpdateCompanionBuilder,
      (
        MobileContinuationCheckpointEntity,
        BaseReferences<
          _$MobileShopDatabase,
          $MobileContinuationCheckpointsTable,
          MobileContinuationCheckpointEntity
        >,
      ),
      MobileContinuationCheckpointEntity,
      PrefetchHooks Function()
    >;

class $MobileShopDatabaseManager {
  final _$MobileShopDatabase _db;
  $MobileShopDatabaseManager(this._db);
  $$MobileImeiUnitsTableTableManager get mobileImeiUnits =>
      $$MobileImeiUnitsTableTableManager(_db, _db.mobileImeiUnits);
  $$MobileInvoiceAssociationsTableTableManager get mobileInvoiceAssociations =>
      $$MobileInvoiceAssociationsTableTableManager(
        _db,
        _db.mobileInvoiceAssociations,
      );
  $$MobileServiceJobsTableTableManager get mobileServiceJobs =>
      $$MobileServiceJobsTableTableManager(_db, _db.mobileServiceJobs);
  $$MobileExchangesTableTableManager get mobileExchanges =>
      $$MobileExchangesTableTableManager(_db, _db.mobileExchanges);
  $$MobileWarrantiesTableTableManager get mobileWarranties =>
      $$MobileWarrantiesTableTableManager(_db, _db.mobileWarranties);
  $$MobileReconciliationStatusTableTableManager
  get mobileReconciliationStatus =>
      $$MobileReconciliationStatusTableTableManager(
        _db,
        _db.mobileReconciliationStatus,
      );
  $$MobileProviderStateTableTableManager get mobileProviderState =>
      $$MobileProviderStateTableTableManager(_db, _db.mobileProviderState);
  $$MobileOutboxMutationsTableTableManager get mobileOutboxMutations =>
      $$MobileOutboxMutationsTableTableManager(_db, _db.mobileOutboxMutations);
  $$MobileConflictsTableTableManager get mobileConflicts =>
      $$MobileConflictsTableTableManager(_db, _db.mobileConflicts);
  $$MobileEventInboxTableTableManager get mobileEventInbox =>
      $$MobileEventInboxTableTableManager(_db, _db.mobileEventInbox);
  $$MobileContinuationCheckpointsTableTableManager
  get mobileContinuationCheckpoints =>
      $$MobileContinuationCheckpointsTableTableManager(
        _db,
        _db.mobileContinuationCheckpoints,
      );
}
