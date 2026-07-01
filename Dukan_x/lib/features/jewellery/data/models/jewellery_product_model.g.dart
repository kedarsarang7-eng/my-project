// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jewellery_product_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_JewelleryProduct _$JewelleryProductFromJson(Map<String, dynamic> json) =>
    _JewelleryProduct(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      businessType: json['businessType'] as String? ?? 'jewellery',
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'General',
      subCategory: json['subCategory'] as String?,
      metalType:
          $enumDecodeNullable(_$MetalTypeEnumMap, json['metalType']) ??
          MetalType.gold22k,
      purityStandard: $enumDecodeNullable(
        _$PurityStandardEnumMap,
        json['purityStandard'],
      ),
      purity: json['purity'] as String?,
      metalWeightGrams: (json['metalWeightGrams'] as num?)?.toDouble() ?? 0.0,
      grossWeightGrams: (json['grossWeightGrams'] as num?)?.toDouble() ?? 0.0,
      netWeightGrams: (json['netWeightGrams'] as num?)?.toDouble() ?? 0.0,
      makingChargesPerGram:
          (json['makingChargesPerGram'] as num?)?.toDouble() ?? 0,
      wastagePercent: (json['wastagePercent'] as num?)?.toDouble() ?? 0,
      stoneWeightGrams: (json['stoneWeightGrams'] as num?)?.toDouble() ?? 0,
      stoneCharges: (json['stoneCharges'] as num?)?.toDouble() ?? 0,
      huid: json['huid'] as String?,
      hallmarkNumber: json['hallmarkNumber'] as String?,
      hallmarkDate: json['hallmarkDate'] == null
          ? null
          : DateTime.parse(json['hallmarkDate'] as String),
      assayingCenter: json['assayingCenter'] as String?,
      isHallmarked: json['isHallmarked'] as bool? ?? false,
      pricePerGramPaisa: (json['pricePerGramPaisa'] as num).toInt(),
      totalMrpPaisa: (json['totalMrpPaisa'] as num).toInt(),
      costPricePaisa: (json['costPricePaisa'] as num?)?.toInt(),
      stockQuantity: (json['stockQuantity'] as num?)?.toInt() ?? 0,
      reorderLevel: (json['reorderLevel'] as num?)?.toInt() ?? 5,
      unit: json['unit'] as String? ?? 'pcs',
      gstRate: (json['gstRate'] as num?)?.toDouble() ?? 3.0,
      hsnCode: json['hsnCode'] as String?,
      barcode: json['barcode'] as String?,
      sku: json['sku'] as String?,
      s3ImageKey: json['s3ImageKey'] as String?,
      s3ThumbnailKey: json['s3ThumbnailKey'] as String?,
      presignedImageUrl: json['presignedImageUrl'] as String?,
      additionalImageKeys: (json['additionalImageKeys'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      createdBy: json['createdBy'] as String,
      updatedBy: json['updatedBy'] as String,
      synced: json['synced'] as bool? ?? true,
      lastSyncedAt: json['lastSyncedAt'] == null
          ? null
          : DateTime.parse(json['lastSyncedAt'] as String),
      version: (json['version'] as num?)?.toInt() ?? 1,
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      pendingOperation: json['pendingOperation'] as String?,
      pendingSince: json['pendingSince'] == null
          ? null
          : DateTime.parse(json['pendingSince'] as String),
    );

Map<String, dynamic> _$JewelleryProductToJson(_JewelleryProduct instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'businessType': instance.businessType,
      'name': instance.name,
      'description': instance.description,
      'category': instance.category,
      'subCategory': instance.subCategory,
      'metalType': _$MetalTypeEnumMap[instance.metalType]!,
      'purityStandard': _$PurityStandardEnumMap[instance.purityStandard],
      'purity': instance.purity,
      'metalWeightGrams': instance.metalWeightGrams,
      'grossWeightGrams': instance.grossWeightGrams,
      'netWeightGrams': instance.netWeightGrams,
      'makingChargesPerGram': instance.makingChargesPerGram,
      'wastagePercent': instance.wastagePercent,
      'stoneWeightGrams': instance.stoneWeightGrams,
      'stoneCharges': instance.stoneCharges,
      'huid': instance.huid,
      'hallmarkNumber': instance.hallmarkNumber,
      'hallmarkDate': instance.hallmarkDate?.toIso8601String(),
      'assayingCenter': instance.assayingCenter,
      'isHallmarked': instance.isHallmarked,
      'pricePerGramPaisa': instance.pricePerGramPaisa,
      'totalMrpPaisa': instance.totalMrpPaisa,
      'costPricePaisa': instance.costPricePaisa,
      'stockQuantity': instance.stockQuantity,
      'reorderLevel': instance.reorderLevel,
      'unit': instance.unit,
      'gstRate': instance.gstRate,
      'hsnCode': instance.hsnCode,
      'barcode': instance.barcode,
      'sku': instance.sku,
      's3ImageKey': instance.s3ImageKey,
      's3ThumbnailKey': instance.s3ThumbnailKey,
      'presignedImageUrl': instance.presignedImageUrl,
      'additionalImageKeys': instance.additionalImageKeys,
      'isActive': instance.isActive,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'createdBy': instance.createdBy,
      'updatedBy': instance.updatedBy,
      'synced': instance.synced,
      'lastSyncedAt': instance.lastSyncedAt?.toIso8601String(),
      'version': instance.version,
      'isDeleted': instance.isDeleted,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'pendingOperation': instance.pendingOperation,
      'pendingSince': instance.pendingSince?.toIso8601String(),
    };

const _$MetalTypeEnumMap = {
  MetalType.gold24k: 'gold24k',
  MetalType.gold22k: 'gold22k',
  MetalType.gold18k: 'gold18k',
  MetalType.gold14k: 'gold14k',
  MetalType.gold9k: 'gold9k',
  MetalType.silver: 'silver',
  MetalType.platinum: 'platinum',
  MetalType.diamond: 'diamond',
  MetalType.other: 'other',
};

const _$PurityStandardEnumMap = {
  PurityStandard.p999: 'p999',
  PurityStandard.p916: 'p916',
  PurityStandard.p750: 'p750',
  PurityStandard.p585: 'p585',
  PurityStandard.p375: 'p375',
};

_GoldRateCard _$GoldRateCardFromJson(Map<String, dynamic> json) =>
    _GoldRateCard(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      date: json['date'] as String,
      gold24KPer10gPaisa: (json['gold24KPer10gPaisa'] as num).toInt(),
      gold22KPer10gPaisa: (json['gold22KPer10gPaisa'] as num).toInt(),
      gold18KPer10gPaisa: (json['gold18KPer10gPaisa'] as num).toInt(),
      silverPerKgPaisa: (json['silverPerKgPaisa'] as num).toInt(),
      platinumPerGramPaisa: (json['platinumPerGramPaisa'] as num).toInt(),
      source: json['source'] as String? ?? 'MANUAL',
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      createdBy: json['createdBy'] as String,
      synced: json['synced'] as bool? ?? true,
      lastSyncedAt: json['lastSyncedAt'] == null
          ? null
          : DateTime.parse(json['lastSyncedAt'] as String),
      pendingOperation: json['pendingOperation'] as String?,
    );

Map<String, dynamic> _$GoldRateCardToJson(_GoldRateCard instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'date': instance.date,
      'gold24KPer10gPaisa': instance.gold24KPer10gPaisa,
      'gold22KPer10gPaisa': instance.gold22KPer10gPaisa,
      'gold18KPer10gPaisa': instance.gold18KPer10gPaisa,
      'silverPerKgPaisa': instance.silverPerKgPaisa,
      'platinumPerGramPaisa': instance.platinumPerGramPaisa,
      'source': instance.source,
      'notes': instance.notes,
      'createdAt': instance.createdAt.toIso8601String(),
      'createdBy': instance.createdBy,
      'synced': instance.synced,
      'lastSyncedAt': instance.lastSyncedAt?.toIso8601String(),
      'pendingOperation': instance.pendingOperation,
    };

_OldGoldExchange _$OldGoldExchangeFromJson(
  Map<String, dynamic> json,
) => _OldGoldExchange(
  id: json['id'] as String,
  tenantId: json['tenantId'] as String,
  customerId: json['customerId'] as String,
  customerName: json['customerName'] as String,
  customerPhone: json['customerPhone'] as String?,
  customerIdType: json['customerIdType'] as String,
  customerIdNumber: json['customerIdNumber'] as String,
  customerPhotoUrl: json['customerPhotoUrl'] as String?,
  idDocumentUrl: json['idDocumentUrl'] as String?,
  oldGoldMetalType: $enumDecode(_$MetalTypeEnumMap, json['oldGoldMetalType']),
  oldGoldWeightGrams: (json['oldGoldWeightGrams'] as num).toDouble(),
  oldGoldValuePaisa: (json['oldGoldValuePaisa'] as num).toInt(),
  oldGoldRatePerGramPaisa: (json['oldGoldRatePerGramPaisa'] as num).toInt(),
  purityTestMethod: json['purityTestMethod'] as String?,
  actualPurityPercentage: (json['actualPurityPercentage'] as num?)?.toDouble(),
  purityTestReportUrl: json['purityTestReportUrl'] as String?,
  newItemDescription: json['newItemDescription'] as String?,
  newItemMetalType: $enumDecodeNullable(
    _$MetalTypeEnumMap,
    json['newItemMetalType'],
  ),
  newItemWeightGrams: (json['newItemWeightGrams'] as num?)?.toDouble(),
  newItemTotalPaisa: (json['newItemTotalPaisa'] as num?)?.toInt(),
  newItemInvoiceId: json['newItemInvoiceId'] as String?,
  exchangeValuePaisa: (json['exchangeValuePaisa'] as num).toInt(),
  cashAdjustmentPaisa: (json['cashAdjustmentPaisa'] as num?)?.toInt() ?? 0,
  status: json['status'] as String? ?? 'PENDING',
  verifiedBy: json['verifiedBy'] as String?,
  verifiedAt: json['verifiedAt'] == null
      ? null
      : DateTime.parse(json['verifiedAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  createdBy: json['createdBy'] as String,
  synced: json['synced'] as bool? ?? true,
  lastSyncedAt: json['lastSyncedAt'] == null
      ? null
      : DateTime.parse(json['lastSyncedAt'] as String),
  pendingOperation: json['pendingOperation'] as String?,
  pmlCompliant: json['pmlCompliant'] as bool? ?? true,
  complianceNotes: json['complianceNotes'] as String?,
);

Map<String, dynamic> _$OldGoldExchangeToJson(_OldGoldExchange instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'customerId': instance.customerId,
      'customerName': instance.customerName,
      'customerPhone': instance.customerPhone,
      'customerIdType': instance.customerIdType,
      'customerIdNumber': instance.customerIdNumber,
      'customerPhotoUrl': instance.customerPhotoUrl,
      'idDocumentUrl': instance.idDocumentUrl,
      'oldGoldMetalType': _$MetalTypeEnumMap[instance.oldGoldMetalType]!,
      'oldGoldWeightGrams': instance.oldGoldWeightGrams,
      'oldGoldValuePaisa': instance.oldGoldValuePaisa,
      'oldGoldRatePerGramPaisa': instance.oldGoldRatePerGramPaisa,
      'purityTestMethod': instance.purityTestMethod,
      'actualPurityPercentage': instance.actualPurityPercentage,
      'purityTestReportUrl': instance.purityTestReportUrl,
      'newItemDescription': instance.newItemDescription,
      'newItemMetalType': _$MetalTypeEnumMap[instance.newItemMetalType],
      'newItemWeightGrams': instance.newItemWeightGrams,
      'newItemTotalPaisa': instance.newItemTotalPaisa,
      'newItemInvoiceId': instance.newItemInvoiceId,
      'exchangeValuePaisa': instance.exchangeValuePaisa,
      'cashAdjustmentPaisa': instance.cashAdjustmentPaisa,
      'status': instance.status,
      'verifiedBy': instance.verifiedBy,
      'verifiedAt': instance.verifiedAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'createdBy': instance.createdBy,
      'synced': instance.synced,
      'lastSyncedAt': instance.lastSyncedAt?.toIso8601String(),
      'pendingOperation': instance.pendingOperation,
      'pmlCompliant': instance.pmlCompliant,
      'complianceNotes': instance.complianceNotes,
    };

_JewelleryOrder _$JewelleryOrderFromJson(
  Map<String, dynamic> json,
) => _JewelleryOrder(
  id: json['id'] as String,
  tenantId: json['tenantId'] as String,
  customerId: json['customerId'] as String,
  customerName: json['customerName'] as String,
  customerPhone: json['customerPhone'] as String?,
  itemDescription: json['itemDescription'] as String,
  designReference: json['designReference'] as String?,
  designNotes: json['designNotes'] as String?,
  metalType: $enumDecode(_$MetalTypeEnumMap, json['metalType']),
  estimatedWeightGrams: (json['estimatedWeightGrams'] as num).toDouble(),
  actualWeightGrams: (json['actualWeightGrams'] as num?)?.toDouble(),
  metalRatePerGramPaisa: (json['metalRatePerGramPaisa'] as num).toInt(),
  makingChargesPerGramPaisa: (json['makingChargesPerGramPaisa'] as num).toInt(),
  wastagePercent: (json['wastagePercent'] as num?)?.toDouble() ?? 0,
  stoneChargesPaisa: (json['stoneChargesPaisa'] as num?)?.toInt() ?? 0,
  otherChargesPaisa: (json['otherChargesPaisa'] as num?)?.toInt() ?? 0,
  estimatedTotalPaisa: (json['estimatedTotalPaisa'] as num).toInt(),
  actualTotalPaisa: (json['actualTotalPaisa'] as num?)?.toInt(),
  advanceReceivedPaisa: (json['advanceReceivedPaisa'] as num?)?.toInt() ?? 0,
  advancePaymentMode: json['advancePaymentMode'] as String?,
  orderDate: DateTime.parse(json['orderDate'] as String),
  promisedDeliveryDate: json['promisedDeliveryDate'] as String,
  actualDeliveryDate: json['actualDeliveryDate'] as String?,
  status: json['status'] as String? ?? 'PENDING',
  statusHistory: (json['statusHistory'] as List<dynamic>?)
      ?.map((e) => OrderStatusUpdate.fromJson(e as Map<String, dynamic>))
      .toList(),
  assignedTo: json['assignedTo'] as String?,
  workProgress: (json['workProgress'] as List<dynamic>?)
      ?.map((e) => WorkProgressUpdate.fromJson(e as Map<String, dynamic>))
      .toList(),
  finalProductId: json['finalProductId'] as String?,
  invoiceId: json['invoiceId'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  createdBy: json['createdBy'] as String,
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  updatedBy: json['updatedBy'] as String,
  synced: json['synced'] as bool? ?? true,
  lastSyncedAt: json['lastSyncedAt'] == null
      ? null
      : DateTime.parse(json['lastSyncedAt'] as String),
  pendingOperation: json['pendingOperation'] as String?,
);

Map<String, dynamic> _$JewelleryOrderToJson(_JewelleryOrder instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'customerId': instance.customerId,
      'customerName': instance.customerName,
      'customerPhone': instance.customerPhone,
      'itemDescription': instance.itemDescription,
      'designReference': instance.designReference,
      'designNotes': instance.designNotes,
      'metalType': _$MetalTypeEnumMap[instance.metalType]!,
      'estimatedWeightGrams': instance.estimatedWeightGrams,
      'actualWeightGrams': instance.actualWeightGrams,
      'metalRatePerGramPaisa': instance.metalRatePerGramPaisa,
      'makingChargesPerGramPaisa': instance.makingChargesPerGramPaisa,
      'wastagePercent': instance.wastagePercent,
      'stoneChargesPaisa': instance.stoneChargesPaisa,
      'otherChargesPaisa': instance.otherChargesPaisa,
      'estimatedTotalPaisa': instance.estimatedTotalPaisa,
      'actualTotalPaisa': instance.actualTotalPaisa,
      'advanceReceivedPaisa': instance.advanceReceivedPaisa,
      'advancePaymentMode': instance.advancePaymentMode,
      'orderDate': instance.orderDate.toIso8601String(),
      'promisedDeliveryDate': instance.promisedDeliveryDate,
      'actualDeliveryDate': instance.actualDeliveryDate,
      'status': instance.status,
      'statusHistory': instance.statusHistory,
      'assignedTo': instance.assignedTo,
      'workProgress': instance.workProgress,
      'finalProductId': instance.finalProductId,
      'invoiceId': instance.invoiceId,
      'createdAt': instance.createdAt.toIso8601String(),
      'createdBy': instance.createdBy,
      'updatedAt': instance.updatedAt.toIso8601String(),
      'updatedBy': instance.updatedBy,
      'synced': instance.synced,
      'lastSyncedAt': instance.lastSyncedAt?.toIso8601String(),
      'pendingOperation': instance.pendingOperation,
    };

_OrderStatusUpdate _$OrderStatusUpdateFromJson(Map<String, dynamic> json) =>
    _OrderStatusUpdate(
      status: json['status'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      updatedBy: json['updatedBy'] as String,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$OrderStatusUpdateToJson(_OrderStatusUpdate instance) =>
    <String, dynamic>{
      'status': instance.status,
      'timestamp': instance.timestamp.toIso8601String(),
      'updatedBy': instance.updatedBy,
      'notes': instance.notes,
    };

_WorkProgressUpdate _$WorkProgressUpdateFromJson(Map<String, dynamic> json) =>
    _WorkProgressUpdate(
      stage: json['stage'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      notes: json['notes'] as String?,
      imageUrls: (json['imageUrls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$WorkProgressUpdateToJson(_WorkProgressUpdate instance) =>
    <String, dynamic>{
      'stage': instance.stage,
      'timestamp': instance.timestamp.toIso8601String(),
      'notes': instance.notes,
      'imageUrls': instance.imageUrls,
    };

_HallmarkRegisterEntry _$HallmarkRegisterEntryFromJson(
  Map<String, dynamic> json,
) => _HallmarkRegisterEntry(
  id: json['id'] as String,
  tenantId: json['tenantId'] as String,
  huid: json['huid'] as String,
  productId: json['productId'] as String,
  productName: json['productName'] as String,
  purityStandard: $enumDecode(_$PurityStandardEnumMap, json['purityStandard']),
  weightGrams: (json['weightGrams'] as num).toDouble(),
  articleType: json['articleType'] as String?,
  bisLogo: json['bisLogo'] as String?,
  purityMark: json['purityMark'] as String?,
  assayingCenterMark: json['assayingCenterMark'] as String?,
  jewelerMark: json['jewelerMark'] as String?,
  hallmarkDate: DateTime.parse(json['hallmarkDate'] as String),
  registrationNumber: json['registrationNumber'] as String?,
  status: json['status'] as String? ?? 'ACTIVE',
  saleInvoiceId: json['saleInvoiceId'] as String?,
  soldDate: json['soldDate'] == null
      ? null
      : DateTime.parse(json['soldDate'] as String),
  hallmarkImageUrl: json['hallmarkImageUrl'] as String?,
  productImageUrl: json['productImageUrl'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  synced: json['synced'] as bool? ?? true,
  lastSyncedAt: json['lastSyncedAt'] == null
      ? null
      : DateTime.parse(json['lastSyncedAt'] as String),
);

Map<String, dynamic> _$HallmarkRegisterEntryToJson(
  _HallmarkRegisterEntry instance,
) => <String, dynamic>{
  'id': instance.id,
  'tenantId': instance.tenantId,
  'huid': instance.huid,
  'productId': instance.productId,
  'productName': instance.productName,
  'purityStandard': _$PurityStandardEnumMap[instance.purityStandard]!,
  'weightGrams': instance.weightGrams,
  'articleType': instance.articleType,
  'bisLogo': instance.bisLogo,
  'purityMark': instance.purityMark,
  'assayingCenterMark': instance.assayingCenterMark,
  'jewelerMark': instance.jewelerMark,
  'hallmarkDate': instance.hallmarkDate.toIso8601String(),
  'registrationNumber': instance.registrationNumber,
  'status': instance.status,
  'saleInvoiceId': instance.saleInvoiceId,
  'soldDate': instance.soldDate?.toIso8601String(),
  'hallmarkImageUrl': instance.hallmarkImageUrl,
  'productImageUrl': instance.productImageUrl,
  'createdAt': instance.createdAt.toIso8601String(),
  'synced': instance.synced,
  'lastSyncedAt': instance.lastSyncedAt?.toIso8601String(),
};
