// Making Charges Model - Flexible Jewellery Pricing
// Feature 2: Making Charges Calculator

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'making_charges_model.freezed.dart';
part 'making_charges_model.g.dart';

/// Types of making charges calculation
enum MakingChargeType {
  perGram, // Fixed amount per gram of metal weight
  percentage, // Percentage of metal value
  fixed, // Fixed flat amount regardless of weight
  tiered, // Different rates for different weight ranges
  complexity, // Based on design complexity (simple, medium, intricate)
  combination, // Base + percentage combination
}

extension MakingChargeTypeExtension on MakingChargeType {
  String get displayName {
    switch (this) {
      case MakingChargeType.perGram:
        return 'Per Gram';
      case MakingChargeType.percentage:
        return 'Percentage of Metal Value';
      case MakingChargeType.fixed:
        return 'Fixed Amount';
      case MakingChargeType.tiered:
        return 'Tiered (Weight-Based)';
      case MakingChargeType.complexity:
        return 'Based on Complexity';
      case MakingChargeType.combination:
        return 'Base + Percentage';
    }
  }

  String get description {
    switch (this) {
      case MakingChargeType.perGram:
        return 'Charge calculated per gram of metal weight';
      case MakingChargeType.percentage:
        return 'Percentage of the metal value';
      case MakingChargeType.fixed:
        return 'Fixed flat amount regardless of weight';
      case MakingChargeType.tiered:
        return 'Different rates for different weight ranges';
      case MakingChargeType.complexity:
        return 'Rate based on design complexity level';
      case MakingChargeType.combination:
        return 'Base amount plus percentage of metal value';
    }
  }
}

/// Jewellery complexity levels (for complexity-based charges)
enum JewelleryComplexity {
  simple, // Basic design, plain
  medium, // Some work, patterns
  intricate, // Heavy work, detailed
  veryIntricate, // Extremely detailed, hand-crafted
}

extension JewelleryComplexityExtension on JewelleryComplexity {
  String get displayName {
    switch (this) {
      case JewelleryComplexity.simple:
        return 'Simple';
      case JewelleryComplexity.medium:
        return 'Medium';
      case JewelleryComplexity.intricate:
        return 'Intricate';
      case JewelleryComplexity.veryIntricate:
        return 'Very Intricate';
    }
  }

  String get description {
    switch (this) {
      case JewelleryComplexity.simple:
        return 'Plain design, minimal work';
      case JewelleryComplexity.medium:
        return 'Moderate detailing, some patterns';
      case JewelleryComplexity.intricate:
        return 'Heavy detailing, stone work';
      case JewelleryComplexity.veryIntricate:
        return 'Hand-crafted, temple/bridal work';
    }
  }
}

/// Tiered rate configuration
@freezed
abstract class TieredRate with _$TieredRate {
  @HiveType(typeId: 59)
  const factory TieredRate({
    @HiveField(0) required double minWeightGrams,
    @HiveField(1) required double maxWeightGrams,
    @HiveField(2) required int ratePaisaPerGram,
    @HiveField(3) String? description,
  }) = _TieredRate;

  const TieredRate._();

  factory TieredRate.fromJson(Map<String, dynamic> json) =>
      _$TieredRateFromJson(json);

  double get displayRatePerGram => ratePaisaPerGram / 100;
}

/// Complexity rate mapping
@freezed
abstract class ComplexityRate with _$ComplexityRate {
  @HiveType(typeId: 60)
  const factory ComplexityRate({
    @HiveField(0) required JewelleryComplexity complexity,
    @HiveField(1) required int ratePaisaPerGram,
    @HiveField(2) String? description,
  }) = _ComplexityRate;

  const ComplexityRate._();

  factory ComplexityRate.fromJson(Map<String, dynamic> json) =>
      _$ComplexityRateFromJson(json);

  double get displayRatePerGram => ratePaisaPerGram / 100;
}

/// Making Charges Configuration - Defines how making charges are calculated
@freezed
abstract class MakingChargesConfig with _$MakingChargesConfig {
  @HiveType(typeId: 61)
  const factory MakingChargesConfig({
    // Core identifiers
    @HiveField(0) required String id,
    @HiveField(1) required String tenantId,

    // Configuration name
    @HiveField(2) required String name,
    @HiveField(3) String? description,

    // Charge type
    @HiveField(4) @Default(MakingChargeType.perGram) MakingChargeType type,

    // For perGram type
    @HiveField(5) int? ratePaisaPerGram,

    // For percentage type
    @HiveField(6) double? percentageOfMetalValue,

    // For fixed type
    @HiveField(7) int? fixedAmountPaisa,

    // For tiered type
    @HiveField(8) List<TieredRate>? tieredRates,

    // For complexity type
    @HiveField(9) List<ComplexityRate>? complexityRates,

    // For combination type
    @HiveField(10) int? baseAmountPaisa,
    @HiveField(11) double? additionalPercentage,

    // Common settings
    @HiveField(12) int? minimumChargePaisa,
    @HiveField(13) int? maximumChargePaisa,
    @HiveField(14) @Default(false) bool applyOnWastage,
    @HiveField(15) @Default(false) bool includeStoneWeight,

    // Stone settings (if making charges apply to stones)
    @HiveField(16) int? stoneMakingChargePaisa,
    @HiveField(17)
    @Default(0)
    double
    stoneWeightPercentage, // % of total weight considered for stone making charges
    // Metadata
    @HiveField(18) @Default(true) bool isActive,
    @HiveField(19) required DateTime createdAt,
    @HiveField(20) required DateTime updatedAt,

    // Sync tracking
    @HiveField(21) @Default(true) bool synced,
    @HiveField(22) DateTime? lastSyncedAt,
  }) = _MakingChargesConfig;

  const MakingChargesConfig._();

  factory MakingChargesConfig.fromJson(Map<String, dynamic> json) =>
      _$MakingChargesConfigFromJson(json);

  double? get displayRatePerGram =>
      ratePaisaPerGram != null ? ratePaisaPerGram! / 100 : null;
  double? get displayFixedAmount =>
      fixedAmountPaisa != null ? fixedAmountPaisa! / 100 : null;
  double? get displayMinimumCharge =>
      minimumChargePaisa != null ? minimumChargePaisa! / 100 : null;
  double? get displayMaximumCharge =>
      maximumChargePaisa != null ? maximumChargePaisa! / 100 : null;
  double? get displayBaseAmount =>
      baseAmountPaisa != null ? baseAmountPaisa! / 100 : null;
}

/// Making Charge Calculation Result
@freezed
abstract class MakingChargeResult with _$MakingChargeResult {
  const factory MakingChargeResult({
    required int totalChargePaisa,
    required int metalChargePaisa,
    required int? stoneChargePaisa,
    required double metalWeightGrams,
    required double? stoneWeightGrams,
    required int metalRatePaisaPerGram,
    required MakingChargeType appliedType,
    required String calculationBreakdown,
    required List<CalculationStep> steps,
    DateTime? calculatedAt,

    /// Validation error flag (Requirement 15.2).
    /// When true, the result represents a rejected invalid input.
    /// The previous valid value should be retained by the caller.
    @Default(false) bool isError,

    /// Human-readable validation error message when [isError] is true.
    String? errorMessage,
  }) = _MakingChargeResult;

  const MakingChargeResult._();

  factory MakingChargeResult.fromJson(Map<String, dynamic> json) =>
      _$MakingChargeResultFromJson(json);

  double get displayTotalCharge => totalChargePaisa / 100;
  double get displayMetalCharge => metalChargePaisa / 100;
  double? get displayStoneCharge =>
      stoneChargePaisa != null ? stoneChargePaisa! / 100 : null;
}

/// Calculation step for detailed breakdown
@freezed
abstract class CalculationStep with _$CalculationStep {
  const factory CalculationStep({
    required String description,
    required String formula,
    required int resultPaisa,
  }) = _CalculationStep;

  factory CalculationStep.fromJson(Map<String, dynamic> json) =>
      _$CalculationStepFromJson(json);
}

/// Request to calculate making charges
class CalculateMakingChargesRequest {
  final MakingChargesConfig config;
  final double metalWeightGrams;
  final int metalRatePaisaPerGram;
  final double? stoneWeightGrams;
  final int? stoneRatePaisa;
  final JewelleryComplexity? complexity;
  final double? wastagePercent;

  /// Real stone count for the item (Requirement 8.3).
  /// Replaces the placeholder "1 stone per gram" assumption.
  final int stoneCount;

  CalculateMakingChargesRequest({
    required this.config,
    required this.metalWeightGrams,
    required this.metalRatePaisaPerGram,
    this.stoneWeightGrams,
    this.stoneRatePaisa,
    this.complexity,
    this.wastagePercent,
    this.stoneCount = 0,
  });
}

/// Create making charges config request
class CreateMakingChargesConfigRequest {
  final String name;
  final String? description;
  final MakingChargeType type;
  final double? ratePerGram;
  final double? percentageOfMetalValue;
  final double? fixedAmount;
  final List<TieredRate>? tieredRates;
  final List<ComplexityRate>? complexityRates;
  final double? baseAmount;
  final double? additionalPercentage;
  final double? minimumCharge;
  final double? maximumCharge;
  final bool applyOnWastage;
  final bool includeStoneWeight;

  CreateMakingChargesConfigRequest({
    required this.name,
    this.description,
    required this.type,
    this.ratePerGram,
    this.percentageOfMetalValue,
    this.fixedAmount,
    this.tieredRates,
    this.complexityRates,
    this.baseAmount,
    this.additionalPercentage,
    this.minimumCharge,
    this.maximumCharge,
    this.applyOnWastage = false,
    this.includeStoneWeight = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'type': type.name,
      'ratePaisaPerGram': ratePerGram != null
          ? (ratePerGram! * 100).round()
          : null,
      'percentageOfMetalValue': percentageOfMetalValue,
      'fixedAmountPaisa': fixedAmount != null
          ? (fixedAmount! * 100).round()
          : null,
      'tieredRates': tieredRates?.map((t) => t.toJson()).toList(),
      'complexityRates': complexityRates?.map((c) => c.toJson()).toList(),
      'baseAmountPaisa': baseAmount != null
          ? (baseAmount! * 100).round()
          : null,
      'additionalPercentage': additionalPercentage,
      'minimumChargePaisa': minimumCharge != null
          ? (minimumCharge! * 100).round()
          : null,
      'maximumChargePaisa': maximumCharge != null
          ? (maximumCharge! * 100).round()
          : null,
      'applyOnWastage': applyOnWastage,
      'includeStoneWeight': includeStoneWeight,
    };
  }
}

/// Update making charges config request
class UpdateMakingChargesConfigRequest {
  final String? name;
  final String? description;
  final MakingChargeType? type;
  final double? ratePerGram;
  final double? percentageOfMetalValue;
  final double? fixedAmount;
  final List<TieredRate>? tieredRates;
  final List<ComplexityRate>? complexityRates;
  final double? baseAmount;
  final double? additionalPercentage;
  final double? minimumCharge;
  final double? maximumCharge;
  final bool? applyOnWastage;
  final bool? includeStoneWeight;
  final bool? isActive;

  UpdateMakingChargesConfigRequest({
    this.name,
    this.description,
    this.type,
    this.ratePerGram,
    this.percentageOfMetalValue,
    this.fixedAmount,
    this.tieredRates,
    this.complexityRates,
    this.baseAmount,
    this.additionalPercentage,
    this.minimumCharge,
    this.maximumCharge,
    this.applyOnWastage,
    this.includeStoneWeight,
    this.isActive,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (description != null) data['description'] = description;
    if (type != null) data['type'] = type!.name;
    if (ratePerGram != null)
      data['ratePaisaPerGram'] = (ratePerGram! * 100).round();
    if (percentageOfMetalValue != null)
      data['percentageOfMetalValue'] = percentageOfMetalValue;
    if (fixedAmount != null)
      data['fixedAmountPaisa'] = (fixedAmount! * 100).round();
    if (tieredRates != null)
      data['tieredRates'] = tieredRates!.map((t) => t.toJson()).toList();
    if (complexityRates != null)
      data['complexityRates'] = complexityRates!
          .map((c) => c.toJson())
          .toList();
    if (baseAmount != null)
      data['baseAmountPaisa'] = (baseAmount! * 100).round();
    if (additionalPercentage != null)
      data['additionalPercentage'] = additionalPercentage;
    if (minimumCharge != null)
      data['minimumChargePaisa'] = (minimumCharge! * 100).round();
    if (maximumCharge != null)
      data['maximumChargePaisa'] = (maximumCharge! * 100).round();
    if (applyOnWastage != null) data['applyOnWastage'] = applyOnWastage;
    if (includeStoneWeight != null)
      data['includeStoneWeight'] = includeStoneWeight;
    if (isActive != null) data['isActive'] = isActive;
    return data;
  }
}

/// Preset configurations for common jewellery types
class MakingChargesPresets {
  static MakingChargesConfig simpleChain() {
    return MakingChargesConfig(
      id: 'preset_simple_chain',
      tenantId: '',
      name: 'Simple Chain',
      description: 'For plain gold chains with minimal work',
      type: MakingChargeType.perGram,
      ratePaisaPerGram: 50000, // ₹500/g
      minimumChargePaisa: 20000, // ₹200 min
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static MakingChargesConfig ringWithStone() {
    return MakingChargesConfig(
      id: 'preset_ring_with_stone',
      tenantId: '',
      name: 'Ring with Stone',
      description: 'For rings with stone setting',
      type: MakingChargeType.perGram,
      ratePaisaPerGram: 80000, // ₹800/g
      stoneMakingChargePaisa: 50000, // ₹500 per stone
      minimumChargePaisa: 30000, // ₹300 min
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static MakingChargesConfig bridalJewellery() {
    return MakingChargesConfig(
      id: 'preset_bridal',
      tenantId: '',
      name: 'Bridal Jewellery',
      description: 'For heavy bridal sets with intricate work',
      type: MakingChargeType.complexity,
      complexityRates: [
        ComplexityRate(
          complexity: JewelleryComplexity.intricate,
          ratePaisaPerGram: 150000, // ₹1500/g
          description: 'Heavy bridal work',
        ),
        ComplexityRate(
          complexity: JewelleryComplexity.veryIntricate,
          ratePaisaPerGram: 250000, // ₹2500/g
          description: 'Temple/Hand-crafted bridal',
        ),
      ],
      minimumChargePaisa: 50000, // ₹500 min
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static MakingChargesConfig lightWeight() {
    return MakingChargesConfig(
      id: 'preset_light_weight',
      tenantId: '',
      name: 'Light Weight Items',
      description: 'For items under 5g - higher per-gram rate',
      type: MakingChargeType.tiered,
      tieredRates: [
        TieredRate(
          minWeightGrams: 0,
          maxWeightGrams: 2,
          ratePaisaPerGram: 100000, // ₹1000/g
          description: 'Very light (0-2g)',
        ),
        TieredRate(
          minWeightGrams: 2,
          maxWeightGrams: 5,
          ratePaisaPerGram: 80000, // ₹800/g
          description: 'Light (2-5g)',
        ),
        TieredRate(
          minWeightGrams: 5,
          maxWeightGrams: 999999,
          ratePaisaPerGram: 50000, // ₹500/g
          description: 'Normal (5g+)',
        ),
      ],
      minimumChargePaisa: 20000, // ₹200 min
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
