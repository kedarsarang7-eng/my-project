// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gold_scheme_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SchemePayment _$SchemePaymentFromJson(Map<String, dynamic> json) =>
    _SchemePayment(
      id: json['id'] as String,
      installmentNumber: (json['installmentNumber'] as num).toInt(),
      amountPaisa: (json['amountPaisa'] as num).toInt(),
      dueDate: DateTime.parse(json['dueDate'] as String),
      paidDate: json['paidDate'] == null
          ? null
          : DateTime.parse(json['paidDate'] as String),
      paidAmountPaisa: (json['paidAmountPaisa'] as num?)?.toInt(),
      isPaid: json['isPaid'] as bool? ?? false,
      isLate: json['isLate'] as bool? ?? false,
      lateFeePaisa: (json['lateFeePaisa'] as num?)?.toInt(),
      paymentMode: json['paymentMode'] as String?,
      transactionId: json['transactionId'] as String?,
      notes: json['notes'] as String?,
      receivedBy: json['receivedBy'] as String?,
      reminderSentDates: (json['reminderSentDates'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$SchemePaymentToJson(_SchemePayment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'installmentNumber': instance.installmentNumber,
      'amountPaisa': instance.amountPaisa,
      'dueDate': instance.dueDate.toIso8601String(),
      'paidDate': instance.paidDate?.toIso8601String(),
      'paidAmountPaisa': instance.paidAmountPaisa,
      'isPaid': instance.isPaid,
      'isLate': instance.isLate,
      'lateFeePaisa': instance.lateFeePaisa,
      'paymentMode': instance.paymentMode,
      'transactionId': instance.transactionId,
      'notes': instance.notes,
      'receivedBy': instance.receivedBy,
      'reminderSentDates': instance.reminderSentDates,
    };

_GoldWeightRecord _$GoldWeightRecordFromJson(Map<String, dynamic> json) =>
    _GoldWeightRecord(
      date: DateTime.parse(json['date'] as String),
      goldRatePerGramPaisa: (json['goldRatePerGramPaisa'] as num).toDouble(),
      goldWeightGrams: (json['goldWeightGrams'] as num).toDouble(),
      amountPaisa: (json['amountPaisa'] as num).toInt(),
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$GoldWeightRecordToJson(_GoldWeightRecord instance) =>
    <String, dynamic>{
      'date': instance.date.toIso8601String(),
      'goldRatePerGramPaisa': instance.goldRatePerGramPaisa,
      'goldWeightGrams': instance.goldWeightGrams,
      'amountPaisa': instance.amountPaisa,
      'notes': instance.notes,
    };

_SchemeRedemption _$SchemeRedemptionFromJson(Map<String, dynamic> json) =>
    _SchemeRedemption(
      id: json['id'] as String,
      type: $enumDecode(_$RedemptionTypeEnumMap, json['type']),
      redemptionDate: DateTime.parse(json['redemptionDate'] as String),
      totalAmountPaisa: (json['totalAmountPaisa'] as num).toInt(),
      bonusAmountPaisa: (json['bonusAmountPaisa'] as num?)?.toInt(),
      discountAmountPaisa: (json['discountAmountPaisa'] as num?)?.toInt(),
      finalAmountPaisa: (json['finalAmountPaisa'] as num?)?.toInt(),
      goldWeightGrams: (json['goldWeightGrams'] as num?)?.toDouble(),
      goldRateAtRedemptionPaisa: (json['goldRateAtRedemptionPaisa'] as num?)
          ?.toDouble(),
      purity: json['purity'] as String?,
      productId: json['productId'] as String?,
      productName: json['productName'] as String?,
      invoiceId: json['invoiceId'] as String?,
      bankAccountNumber: json['bankAccountNumber'] as String?,
      bankIfsc: json['bankIfsc'] as String?,
      upiId: json['upiId'] as String?,
      payoutDate: json['payoutDate'] == null
          ? null
          : DateTime.parse(json['payoutDate'] as String),
      notes: json['notes'] as String?,
      processedBy: json['processedBy'] as String?,
    );

Map<String, dynamic> _$SchemeRedemptionToJson(_SchemeRedemption instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$RedemptionTypeEnumMap[instance.type]!,
      'redemptionDate': instance.redemptionDate.toIso8601String(),
      'totalAmountPaisa': instance.totalAmountPaisa,
      'bonusAmountPaisa': instance.bonusAmountPaisa,
      'discountAmountPaisa': instance.discountAmountPaisa,
      'finalAmountPaisa': instance.finalAmountPaisa,
      'goldWeightGrams': instance.goldWeightGrams,
      'goldRateAtRedemptionPaisa': instance.goldRateAtRedemptionPaisa,
      'purity': instance.purity,
      'productId': instance.productId,
      'productName': instance.productName,
      'invoiceId': instance.invoiceId,
      'bankAccountNumber': instance.bankAccountNumber,
      'bankIfsc': instance.bankIfsc,
      'upiId': instance.upiId,
      'payoutDate': instance.payoutDate?.toIso8601String(),
      'notes': instance.notes,
      'processedBy': instance.processedBy,
    };

const _$RedemptionTypeEnumMap = {
  RedemptionType.goldJewellery: 'goldJewellery',
  RedemptionType.goldCoin: 'goldCoin',
  RedemptionType.cashPayout: 'cashPayout',
  RedemptionType.bankTransfer: 'bankTransfer',
};

_GoldScheme _$GoldSchemeFromJson(Map<String, dynamic> json) => _GoldScheme(
  id: json['id'] as String,
  tenantId: json['tenantId'] as String,
  schemeNumber: json['schemeNumber'] as String,
  customerId: json['customerId'] as String,
  customerName: json['customerName'] as String,
  customerPhone: json['customerPhone'] as String?,
  customerEmail: json['customerEmail'] as String?,
  customerAddress: json['customerAddress'] as String?,
  schemeName: json['schemeName'] as String,
  schemeDescription: json['schemeDescription'] as String?,
  installmentAmountPaisa: (json['installmentAmountPaisa'] as num).toInt(),
  totalInstallments: (json['totalInstallments'] as num).toInt(),
  frequency:
      $enumDecodeNullable(_$PaymentFrequencyEnumMap, json['frequency']) ??
      PaymentFrequency.monthly,
  minimumInstallmentsForRedemption:
      (json['minimumInstallmentsForRedemption'] as num?)?.toInt(),
  vendorBonusPaisa: (json['vendorBonusPaisa'] as num?)?.toInt(),
  bonusPercentage: (json['bonusPercentage'] as num?)?.toDouble(),
  bonusDescription: json['bonusDescription'] as String?,
  isGoldLinked: json['isGoldLinked'] as bool? ?? false,
  linkedMetalType: $enumDecodeNullable(
    _$MetalTypeEnumMap,
    json['linkedMetalType'],
  ),
  goldWeightHistory: (json['goldWeightHistory'] as List<dynamic>?)
      ?.map((e) => GoldWeightRecord.fromJson(e as Map<String, dynamic>))
      .toList(),
  status:
      $enumDecodeNullable(_$SchemeStatusEnumMap, json['status']) ??
      SchemeStatus.active,
  startDate: DateTime.parse(json['startDate'] as String),
  endDate: json['endDate'] == null
      ? null
      : DateTime.parse(json['endDate'] as String),
  promisedRedemptionDate: json['promisedRedemptionDate'] == null
      ? null
      : DateTime.parse(json['promisedRedemptionDate'] as String),
  payments: (json['payments'] as List<dynamic>)
      .map((e) => SchemePayment.fromJson(e as Map<String, dynamic>))
      .toList(),
  completedInstallments: (json['completedInstallments'] as num?)?.toInt() ?? 0,
  missedInstallments: (json['missedInstallments'] as num?)?.toInt() ?? 0,
  lateInstallments: (json['lateInstallments'] as num?)?.toInt() ?? 0,
  totalPaidPaisa: (json['totalPaidPaisa'] as num?)?.toInt() ?? 0,
  totalLateFeesPaisa: (json['totalLateFeesPaisa'] as num?)?.toInt() ?? 0,
  accumulatedGoldWeightGrams: (json['accumulatedGoldWeightGrams'] as num?)
      ?.toInt(),
  redemption: json['redemption'] == null
      ? null
      : SchemeRedemption.fromJson(json['redemption'] as Map<String, dynamic>),
  plannedRedemptionType: $enumDecodeNullable(
    _$RedemptionTypeEnumMap,
    json['plannedRedemptionType'],
  ),
  defaultAfterMissedInstallments:
      (json['defaultAfterMissedInstallments'] as num?)?.toInt(),
  foreclosureChargePercent: (json['foreclosureChargePercent'] as num?)?.toInt(),
  defaultedDate: json['defaultedDate'] == null
      ? null
      : DateTime.parse(json['defaultedDate'] as String),
  defaultReason: json['defaultReason'] as String?,
  cancelledDate: json['cancelledDate'] == null
      ? null
      : DateTime.parse(json['cancelledDate'] as String),
  cancellationReason: json['cancellationReason'] as String?,
  cancellationChargesPaisa: (json['cancellationChargesPaisa'] as num?)?.toInt(),
  refundAmountPaisa: (json['refundAmountPaisa'] as num?)?.toInt(),
  referredByCustomerId: json['referredByCustomerId'] as String?,
  referralCode: json['referralCode'] as String?,
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

Map<String, dynamic> _$GoldSchemeToJson(
  _GoldScheme instance,
) => <String, dynamic>{
  'id': instance.id,
  'tenantId': instance.tenantId,
  'schemeNumber': instance.schemeNumber,
  'customerId': instance.customerId,
  'customerName': instance.customerName,
  'customerPhone': instance.customerPhone,
  'customerEmail': instance.customerEmail,
  'customerAddress': instance.customerAddress,
  'schemeName': instance.schemeName,
  'schemeDescription': instance.schemeDescription,
  'installmentAmountPaisa': instance.installmentAmountPaisa,
  'totalInstallments': instance.totalInstallments,
  'frequency': _$PaymentFrequencyEnumMap[instance.frequency]!,
  'minimumInstallmentsForRedemption': instance.minimumInstallmentsForRedemption,
  'vendorBonusPaisa': instance.vendorBonusPaisa,
  'bonusPercentage': instance.bonusPercentage,
  'bonusDescription': instance.bonusDescription,
  'isGoldLinked': instance.isGoldLinked,
  'linkedMetalType': _$MetalTypeEnumMap[instance.linkedMetalType],
  'goldWeightHistory': instance.goldWeightHistory,
  'status': _$SchemeStatusEnumMap[instance.status]!,
  'startDate': instance.startDate.toIso8601String(),
  'endDate': instance.endDate?.toIso8601String(),
  'promisedRedemptionDate': instance.promisedRedemptionDate?.toIso8601String(),
  'payments': instance.payments,
  'completedInstallments': instance.completedInstallments,
  'missedInstallments': instance.missedInstallments,
  'lateInstallments': instance.lateInstallments,
  'totalPaidPaisa': instance.totalPaidPaisa,
  'totalLateFeesPaisa': instance.totalLateFeesPaisa,
  'accumulatedGoldWeightGrams': instance.accumulatedGoldWeightGrams,
  'redemption': instance.redemption,
  'plannedRedemptionType':
      _$RedemptionTypeEnumMap[instance.plannedRedemptionType],
  'defaultAfterMissedInstallments': instance.defaultAfterMissedInstallments,
  'foreclosureChargePercent': instance.foreclosureChargePercent,
  'defaultedDate': instance.defaultedDate?.toIso8601String(),
  'defaultReason': instance.defaultReason,
  'cancelledDate': instance.cancelledDate?.toIso8601String(),
  'cancellationReason': instance.cancellationReason,
  'cancellationChargesPaisa': instance.cancellationChargesPaisa,
  'refundAmountPaisa': instance.refundAmountPaisa,
  'referredByCustomerId': instance.referredByCustomerId,
  'referralCode': instance.referralCode,
  'createdAt': instance.createdAt.toIso8601String(),
  'createdBy': instance.createdBy,
  'updatedAt': instance.updatedAt.toIso8601String(),
  'updatedBy': instance.updatedBy,
  'synced': instance.synced,
  'lastSyncedAt': instance.lastSyncedAt?.toIso8601String(),
  'pendingOperation': instance.pendingOperation,
};

const _$PaymentFrequencyEnumMap = {
  PaymentFrequency.monthly: 'monthly',
  PaymentFrequency.weekly: 'weekly',
  PaymentFrequency.daily: 'daily',
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

const _$SchemeStatusEnumMap = {
  SchemeStatus.active: 'active',
  SchemeStatus.paused: 'paused',
  SchemeStatus.completed: 'completed',
  SchemeStatus.redeemed: 'redeemed',
  SchemeStatus.defaulted: 'defaulted',
  SchemeStatus.cancelled: 'cancelled',
};

_SchemeTemplate _$SchemeTemplateFromJson(Map<String, dynamic> json) =>
    _SchemeTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      installmentAmountPaisa: (json['installmentAmountPaisa'] as num).toInt(),
      totalInstallments: (json['totalInstallments'] as num).toInt(),
      frequency:
          $enumDecodeNullable(_$PaymentFrequencyEnumMap, json['frequency']) ??
          PaymentFrequency.monthly,
      vendorBonusPaisa: (json['vendorBonusPaisa'] as num?)?.toInt(),
      bonusPercentage: (json['bonusPercentage'] as num?)?.toDouble(),
      bonusDescription: json['bonusDescription'] as String?,
      minimumInstallmentsForRedemption:
          (json['minimumInstallmentsForRedemption'] as num?)?.toInt(),
      isGoldLinked: json['isGoldLinked'] as bool? ?? false,
      linkedMetalType: $enumDecodeNullable(
        _$MetalTypeEnumMap,
        json['linkedMetalType'],
      ),
      defaultAfterMissedInstallments:
          (json['defaultAfterMissedInstallments'] as num?)?.toInt(),
      foreclosureChargePercent: (json['foreclosureChargePercent'] as num?)
          ?.toInt(),
      isActive: json['isActive'] as bool? ?? true,
    );

Map<String, dynamic> _$SchemeTemplateToJson(
  _SchemeTemplate instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'installmentAmountPaisa': instance.installmentAmountPaisa,
  'totalInstallments': instance.totalInstallments,
  'frequency': _$PaymentFrequencyEnumMap[instance.frequency]!,
  'vendorBonusPaisa': instance.vendorBonusPaisa,
  'bonusPercentage': instance.bonusPercentage,
  'bonusDescription': instance.bonusDescription,
  'minimumInstallmentsForRedemption': instance.minimumInstallmentsForRedemption,
  'isGoldLinked': instance.isGoldLinked,
  'linkedMetalType': _$MetalTypeEnumMap[instance.linkedMetalType],
  'defaultAfterMissedInstallments': instance.defaultAfterMissedInstallments,
  'foreclosureChargePercent': instance.foreclosureChargePercent,
  'isActive': instance.isActive,
};

_GoldSchemeStatistics _$GoldSchemeStatisticsFromJson(
  Map<String, dynamic> json,
) => _GoldSchemeStatistics(
  totalSchemes: (json['totalSchemes'] as num?)?.toInt() ?? 0,
  activeSchemes: (json['activeSchemes'] as num?)?.toInt() ?? 0,
  completedSchemes: (json['completedSchemes'] as num?)?.toInt() ?? 0,
  redeemedSchemes: (json['redeemedSchemes'] as num?)?.toInt() ?? 0,
  defaultedSchemes: (json['defaultedSchemes'] as num?)?.toInt() ?? 0,
  totalCustomers: (json['totalCustomers'] as num?)?.toInt() ?? 0,
  totalPaidPaisa: (json['totalPaidPaisa'] as num?)?.toInt() ?? 0,
  totalBonusPaisa: (json['totalBonusPaisa'] as num?)?.toInt() ?? 0,
  totalOutstandingPaisa: (json['totalOutstandingPaisa'] as num?)?.toInt() ?? 0,
  totalOverduePaisa: (json['totalOverduePaisa'] as num?)?.toInt() ?? 0,
  averageSchemeDuration:
      (json['averageSchemeDuration'] as num?)?.toDouble() ?? 0.0,
  schemesDueThisMonth: (json['schemesDueThisMonth'] as num?)?.toInt() ?? 0,
  schemesOverdue: (json['schemesOverdue'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$GoldSchemeStatisticsToJson(
  _GoldSchemeStatistics instance,
) => <String, dynamic>{
  'totalSchemes': instance.totalSchemes,
  'activeSchemes': instance.activeSchemes,
  'completedSchemes': instance.completedSchemes,
  'redeemedSchemes': instance.redeemedSchemes,
  'defaultedSchemes': instance.defaultedSchemes,
  'totalCustomers': instance.totalCustomers,
  'totalPaidPaisa': instance.totalPaidPaisa,
  'totalBonusPaisa': instance.totalBonusPaisa,
  'totalOutstandingPaisa': instance.totalOutstandingPaisa,
  'totalOverduePaisa': instance.totalOverduePaisa,
  'averageSchemeDuration': instance.averageSchemeDuration,
  'schemesDueThisMonth': instance.schemesDueThisMonth,
  'schemesOverdue': instance.schemesOverdue,
};
