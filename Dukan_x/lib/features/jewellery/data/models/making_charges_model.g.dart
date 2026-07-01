// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'making_charges_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TieredRate _$TieredRateFromJson(Map<String, dynamic> json) => _TieredRate(
  minWeightGrams: (json['minWeightGrams'] as num).toDouble(),
  maxWeightGrams: (json['maxWeightGrams'] as num).toDouble(),
  ratePaisaPerGram: (json['ratePaisaPerGram'] as num).toInt(),
  description: json['description'] as String?,
);

Map<String, dynamic> _$TieredRateToJson(_TieredRate instance) =>
    <String, dynamic>{
      'minWeightGrams': instance.minWeightGrams,
      'maxWeightGrams': instance.maxWeightGrams,
      'ratePaisaPerGram': instance.ratePaisaPerGram,
      'description': instance.description,
    };

_ComplexityRate _$ComplexityRateFromJson(Map<String, dynamic> json) =>
    _ComplexityRate(
      complexity: $enumDecode(_$JewelleryComplexityEnumMap, json['complexity']),
      ratePaisaPerGram: (json['ratePaisaPerGram'] as num).toInt(),
      description: json['description'] as String?,
    );

Map<String, dynamic> _$ComplexityRateToJson(_ComplexityRate instance) =>
    <String, dynamic>{
      'complexity': _$JewelleryComplexityEnumMap[instance.complexity]!,
      'ratePaisaPerGram': instance.ratePaisaPerGram,
      'description': instance.description,
    };

const _$JewelleryComplexityEnumMap = {
  JewelleryComplexity.simple: 'simple',
  JewelleryComplexity.medium: 'medium',
  JewelleryComplexity.intricate: 'intricate',
  JewelleryComplexity.veryIntricate: 'veryIntricate',
};

_MakingChargesConfig _$MakingChargesConfigFromJson(Map<String, dynamic> json) =>
    _MakingChargesConfig(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      type:
          $enumDecodeNullable(_$MakingChargeTypeEnumMap, json['type']) ??
          MakingChargeType.perGram,
      ratePaisaPerGram: (json['ratePaisaPerGram'] as num?)?.toInt(),
      percentageOfMetalValue: (json['percentageOfMetalValue'] as num?)
          ?.toDouble(),
      fixedAmountPaisa: (json['fixedAmountPaisa'] as num?)?.toInt(),
      tieredRates: (json['tieredRates'] as List<dynamic>?)
          ?.map((e) => TieredRate.fromJson(e as Map<String, dynamic>))
          .toList(),
      complexityRates: (json['complexityRates'] as List<dynamic>?)
          ?.map((e) => ComplexityRate.fromJson(e as Map<String, dynamic>))
          .toList(),
      baseAmountPaisa: (json['baseAmountPaisa'] as num?)?.toInt(),
      additionalPercentage: (json['additionalPercentage'] as num?)?.toDouble(),
      minimumChargePaisa: (json['minimumChargePaisa'] as num?)?.toInt(),
      maximumChargePaisa: (json['maximumChargePaisa'] as num?)?.toInt(),
      applyOnWastage: json['applyOnWastage'] as bool? ?? false,
      includeStoneWeight: json['includeStoneWeight'] as bool? ?? false,
      stoneMakingChargePaisa: (json['stoneMakingChargePaisa'] as num?)?.toInt(),
      stoneWeightPercentage:
          (json['stoneWeightPercentage'] as num?)?.toDouble() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      synced: json['synced'] as bool? ?? true,
      lastSyncedAt: json['lastSyncedAt'] == null
          ? null
          : DateTime.parse(json['lastSyncedAt'] as String),
    );

Map<String, dynamic> _$MakingChargesConfigToJson(
  _MakingChargesConfig instance,
) => <String, dynamic>{
  'id': instance.id,
  'tenantId': instance.tenantId,
  'name': instance.name,
  'description': instance.description,
  'type': _$MakingChargeTypeEnumMap[instance.type]!,
  'ratePaisaPerGram': instance.ratePaisaPerGram,
  'percentageOfMetalValue': instance.percentageOfMetalValue,
  'fixedAmountPaisa': instance.fixedAmountPaisa,
  'tieredRates': instance.tieredRates,
  'complexityRates': instance.complexityRates,
  'baseAmountPaisa': instance.baseAmountPaisa,
  'additionalPercentage': instance.additionalPercentage,
  'minimumChargePaisa': instance.minimumChargePaisa,
  'maximumChargePaisa': instance.maximumChargePaisa,
  'applyOnWastage': instance.applyOnWastage,
  'includeStoneWeight': instance.includeStoneWeight,
  'stoneMakingChargePaisa': instance.stoneMakingChargePaisa,
  'stoneWeightPercentage': instance.stoneWeightPercentage,
  'isActive': instance.isActive,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'synced': instance.synced,
  'lastSyncedAt': instance.lastSyncedAt?.toIso8601String(),
};

const _$MakingChargeTypeEnumMap = {
  MakingChargeType.perGram: 'perGram',
  MakingChargeType.percentage: 'percentage',
  MakingChargeType.fixed: 'fixed',
  MakingChargeType.tiered: 'tiered',
  MakingChargeType.complexity: 'complexity',
  MakingChargeType.combination: 'combination',
};

_MakingChargeResult _$MakingChargeResultFromJson(Map<String, dynamic> json) =>
    _MakingChargeResult(
      totalChargePaisa: (json['totalChargePaisa'] as num).toInt(),
      metalChargePaisa: (json['metalChargePaisa'] as num).toInt(),
      stoneChargePaisa: (json['stoneChargePaisa'] as num?)?.toInt(),
      metalWeightGrams: (json['metalWeightGrams'] as num).toDouble(),
      stoneWeightGrams: (json['stoneWeightGrams'] as num?)?.toDouble(),
      metalRatePaisaPerGram: (json['metalRatePaisaPerGram'] as num).toInt(),
      appliedType: $enumDecode(_$MakingChargeTypeEnumMap, json['appliedType']),
      calculationBreakdown: json['calculationBreakdown'] as String,
      steps: (json['steps'] as List<dynamic>)
          .map((e) => CalculationStep.fromJson(e as Map<String, dynamic>))
          .toList(),
      calculatedAt: json['calculatedAt'] == null
          ? null
          : DateTime.parse(json['calculatedAt'] as String),
      isError: json['isError'] as bool? ?? false,
      errorMessage: json['errorMessage'] as String?,
    );

Map<String, dynamic> _$MakingChargeResultToJson(_MakingChargeResult instance) =>
    <String, dynamic>{
      'totalChargePaisa': instance.totalChargePaisa,
      'metalChargePaisa': instance.metalChargePaisa,
      'stoneChargePaisa': instance.stoneChargePaisa,
      'metalWeightGrams': instance.metalWeightGrams,
      'stoneWeightGrams': instance.stoneWeightGrams,
      'metalRatePaisaPerGram': instance.metalRatePaisaPerGram,
      'appliedType': _$MakingChargeTypeEnumMap[instance.appliedType]!,
      'calculationBreakdown': instance.calculationBreakdown,
      'steps': instance.steps,
      'calculatedAt': instance.calculatedAt?.toIso8601String(),
      'isError': instance.isError,
      'errorMessage': instance.errorMessage,
    };

_CalculationStep _$CalculationStepFromJson(Map<String, dynamic> json) =>
    _CalculationStep(
      description: json['description'] as String,
      formula: json['formula'] as String,
      resultPaisa: (json['resultPaisa'] as num).toInt(),
    );

Map<String, dynamic> _$CalculationStepToJson(_CalculationStep instance) =>
    <String, dynamic>{
      'description': instance.description,
      'formula': instance.formula,
      'resultPaisa': instance.resultPaisa,
    };
