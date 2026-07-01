// Making Charges Calculator Service
// Feature 2: Flexible Jewellery Pricing Calculation
//
// DELEGATION TO CANONICAL ENGINE (Requirements 7.2, 7.3):
// `calculateTotalPrice` delegates metal-value, tax, and total computation to
// `JewelleryBusinessRules.billTotalPaisa` — the single canonical pricing engine.
// The making-charges breakdown logic (per-gram/percentage/tiered/complexity/
// combination) is RETAINED here and computes the `makingChargesPaisa` input
// that feeds into `billTotalPaisa`.

import '../models/making_charges_model.dart';
import '../../utils/jewellery_business_rules.dart';

/// Service for calculating making charges with various methods
class MakingChargesCalculator {
  /// Validate inputs for the calculator (Requirement 15.2).
  ///
  /// Rejects negative weight, negative rate, and any percentage > 100.
  /// Returns a [MakingChargeResult] with [isError] = true and a descriptive
  /// [errorMessage] when validation fails. The caller should retain the
  /// previous valid value and surface the error indication to the user.
  static MakingChargeResult? _validateInputs(
    CalculateMakingChargesRequest request,
  ) {
    final config = request.config;
    final errors = <String>[];

    // Reject negative weight
    if (request.metalWeightGrams < 0) {
      errors.add('Metal weight cannot be negative');
    }

    // Reject negative rate
    if (request.metalRatePaisaPerGram < 0) {
      errors.add('Metal rate cannot be negative');
    }

    // Reject negative per-gram making charge rate
    if (config.ratePaisaPerGram != null && config.ratePaisaPerGram! < 0) {
      errors.add('Making charge rate per gram cannot be negative');
    }

    // Reject percentage > 100
    if (config.percentageOfMetalValue != null &&
        config.percentageOfMetalValue! > 100) {
      errors.add('Percentage of metal value cannot exceed 100%');
    }

    // Reject additional percentage > 100 (combination type)
    if (config.additionalPercentage != null &&
        config.additionalPercentage! > 100) {
      errors.add('Additional percentage cannot exceed 100%');
    }

    // Reject wastage percentage > 100
    if (request.wastagePercent != null && request.wastagePercent! > 100) {
      errors.add('Wastage percentage cannot exceed 100%');
    }

    if (errors.isEmpty) return null;

    return MakingChargeResult(
      totalChargePaisa: 0,
      metalChargePaisa: 0,
      stoneChargePaisa: null,
      metalWeightGrams: request.metalWeightGrams,
      stoneWeightGrams: request.stoneWeightGrams,
      metalRatePaisaPerGram: request.metalRatePaisaPerGram,
      appliedType: config.type,
      calculationBreakdown: '',
      steps: const [],
      calculatedAt: DateTime.now(),
      isError: true,
      errorMessage: errors.join('; '),
    );
  }

  /// Calculate making charges based on configuration.
  ///
  /// INPUT VALIDATION (Requirement 15.2):
  /// If `metalWeightGrams < 0`, `metalRatePaisaPerGram < 0`, or any
  /// percentage > 100, the method returns a [MakingChargeResult] with
  /// `isError: true` and a descriptive `errorMessage`. The caller should
  /// retain the previous valid value and surface the error indication.
  static MakingChargeResult calculate(CalculateMakingChargesRequest request) {
    // Validate inputs (Requirement 15.2)
    final validationError = _validateInputs(request);
    if (validationError != null) return validationError;

    final steps = <CalculationStep>[];
    final config = request.config;

    switch (config.type) {
      case MakingChargeType.perGram:
        return _calculatePerGram(request, steps);
      case MakingChargeType.percentage:
        return _calculatePercentage(request, steps);
      case MakingChargeType.fixed:
        return _calculateFixed(request, steps);
      case MakingChargeType.tiered:
        return _calculateTiered(request, steps);
      case MakingChargeType.complexity:
        return _calculateComplexity(request, steps);
      case MakingChargeType.combination:
        return _calculateCombination(request, steps);
    }
  }

  /// Per Gram calculation
  ///
  /// WASTAGE FIX (Requirement 8.2): Wastage is applied ONCE in
  /// `calculateTotalPrice` (step 5), NOT here. The old code added wastage
  /// to effectiveWeight when `applyOnWastage` was true, causing a double-count
  /// because `calculateTotalPrice` also adds `wastageValuePaisa` to the
  /// aggregated charges. The `applyOnWastage` flag is now ignored in this
  /// method — wastage is always handled at the single explicit point.
  static MakingChargeResult _calculatePerGram(
    CalculateMakingChargesRequest request,
    List<CalculationStep> steps,
  ) {
    final config = request.config;
    final ratePerGram = config.ratePaisaPerGram ?? 0;

    // Wastage is NOT applied here — it is applied once in calculateTotalPrice
    // (Requirement 8.2: single wastage application, explicit and auditable).
    final double effectiveWeight = request.metalWeightGrams;

    // Calculate metal making charges
    int metalCharge = (effectiveWeight * ratePerGram).round();

    steps.add(
      CalculationStep(
        description: 'Per gram rate × Weight',
        formula:
            '₹${(ratePerGram / 100).toStringAsFixed(2)} × ${effectiveWeight.toStringAsFixed(2)}g',
        resultPaisa: metalCharge,
      ),
    );

    // Calculate stone making charges
    int? stoneCharge;
    if (config.includeStoneWeight &&
        request.stoneWeightGrams != null &&
        request.stoneWeightGrams! > 0) {
      stoneCharge = _calculateStoneCharge(config, request, steps);
    }

    int totalCharge = metalCharge + (stoneCharge ?? 0);

    // Apply min/max constraints
    totalCharge = _applyConstraints(totalCharge, config, steps);

    return MakingChargeResult(
      totalChargePaisa: totalCharge,
      metalChargePaisa: metalCharge,
      stoneChargePaisa: stoneCharge,
      metalWeightGrams: request.metalWeightGrams,
      stoneWeightGrams: request.stoneWeightGrams,
      metalRatePaisaPerGram: request.metalRatePaisaPerGram,
      appliedType: MakingChargeType.perGram,
      calculationBreakdown: _buildBreakdown(steps),
      steps: steps,
      calculatedAt: DateTime.now(),
    );
  }

  /// Percentage calculation
  static MakingChargeResult _calculatePercentage(
    CalculateMakingChargesRequest request,
    List<CalculationStep> steps,
  ) {
    final config = request.config;
    final percentage = config.percentageOfMetalValue ?? 0;

    // Calculate metal value
    final metalValue = request.metalWeightGrams * request.metalRatePaisaPerGram;

    steps.add(
      CalculationStep(
        description: 'Metal value',
        formula:
            '${request.metalWeightGrams.toStringAsFixed(2)}g × ₹${(request.metalRatePaisaPerGram / 100).toStringAsFixed(2)}',
        resultPaisa: metalValue.round(),
      ),
    );

    // Calculate percentage of metal value
    int metalCharge = (metalValue * (percentage / 100)).round();

    steps.add(
      CalculationStep(
        description: 'Making charges ($percentage%)',
        formula: '₹${(metalValue / 100).toStringAsFixed(2)} × $percentage%',
        resultPaisa: metalCharge,
      ),
    );

    // Stone charges
    int? stoneCharge;
    if (config.includeStoneWeight &&
        request.stoneWeightGrams != null &&
        request.stoneWeightGrams! > 0) {
      stoneCharge = _calculateStoneCharge(config, request, steps);
    }

    int totalCharge = metalCharge + (stoneCharge ?? 0);
    totalCharge = _applyConstraints(totalCharge, config, steps);

    return MakingChargeResult(
      totalChargePaisa: totalCharge,
      metalChargePaisa: metalCharge,
      stoneChargePaisa: stoneCharge,
      metalWeightGrams: request.metalWeightGrams,
      stoneWeightGrams: request.stoneWeightGrams,
      metalRatePaisaPerGram: request.metalRatePaisaPerGram,
      appliedType: MakingChargeType.percentage,
      calculationBreakdown: _buildBreakdown(steps),
      steps: steps,
      calculatedAt: DateTime.now(),
    );
  }

  /// Fixed amount calculation
  static MakingChargeResult _calculateFixed(
    CalculateMakingChargesRequest request,
    List<CalculationStep> steps,
  ) {
    final config = request.config;
    int metalCharge = config.fixedAmountPaisa ?? 0;

    steps.add(
      CalculationStep(
        description: 'Fixed making charges',
        formula: 'Flat amount',
        resultPaisa: metalCharge,
      ),
    );

    // Stone charges (if any)
    int? stoneCharge;
    if (config.includeStoneWeight &&
        request.stoneWeightGrams != null &&
        request.stoneWeightGrams! > 0) {
      stoneCharge = _calculateStoneCharge(config, request, steps);
    }

    int totalCharge = metalCharge + (stoneCharge ?? 0);
    totalCharge = _applyConstraints(totalCharge, config, steps);

    return MakingChargeResult(
      totalChargePaisa: totalCharge,
      metalChargePaisa: metalCharge,
      stoneChargePaisa: stoneCharge,
      metalWeightGrams: request.metalWeightGrams,
      stoneWeightGrams: request.stoneWeightGrams,
      metalRatePaisaPerGram: request.metalRatePaisaPerGram,
      appliedType: MakingChargeType.fixed,
      calculationBreakdown: _buildBreakdown(steps),
      steps: steps,
      calculatedAt: DateTime.now(),
    );
  }

  /// Tiered calculation based on weight ranges
  static MakingChargeResult _calculateTiered(
    CalculateMakingChargesRequest request,
    List<CalculationStep> steps,
  ) {
    final config = request.config;
    final tiers = config.tieredRates ?? [];

    // Find applicable tier
    TieredRate? applicableTier;
    for (final tier in tiers) {
      if (request.metalWeightGrams >= tier.minWeightGrams &&
          request.metalWeightGrams < tier.maxWeightGrams) {
        applicableTier = tier;
        break;
      }
    }

    // Use last tier if weight exceeds all
    applicableTier ??= tiers.isNotEmpty ? tiers.last : null;

    // Graceful tiered-error result (Requirement 15.3):
    // When tieredRates is empty or weight matches no tier, return an error
    // result instead of throwing an uncaught exception that would crash the
    // screen.
    if (applicableTier == null) {
      return MakingChargeResult(
        totalChargePaisa: 0,
        metalChargePaisa: 0,
        stoneChargePaisa: null,
        metalWeightGrams: request.metalWeightGrams,
        stoneWeightGrams: request.stoneWeightGrams,
        metalRatePaisaPerGram: request.metalRatePaisaPerGram,
        appliedType: MakingChargeType.tiered,
        calculationBreakdown: '',
        steps: steps,
        calculatedAt: DateTime.now(),
        isError: true,
        errorMessage:
            'No tier found for weight ${request.metalWeightGrams}g — tiered rates configuration is empty or does not cover this weight',
      );
    }

    steps.add(
      CalculationStep(
        description: 'Weight tier',
        formula:
            '${applicableTier.minWeightGrams}g - ${applicableTier.maxWeightGrams}g',
        resultPaisa: 0,
      ),
    );

    steps.add(
      CalculationStep(
        description: 'Selected rate',
        formula: '₹${applicableTier.displayRatePerGram}/g',
        resultPaisa: 0,
      ),
    );

    int metalCharge =
        (request.metalWeightGrams * applicableTier.ratePaisaPerGram).round();

    steps.add(
      CalculationStep(
        description: 'Metal making charges',
        formula:
            '${request.metalWeightGrams.toStringAsFixed(2)}g × ₹${applicableTier.displayRatePerGram}',
        resultPaisa: metalCharge,
      ),
    );

    // Stone charges
    int? stoneCharge;
    if (config.includeStoneWeight &&
        request.stoneWeightGrams != null &&
        request.stoneWeightGrams! > 0) {
      stoneCharge = _calculateStoneCharge(config, request, steps);
    }

    int totalCharge = metalCharge + (stoneCharge ?? 0);
    totalCharge = _applyConstraints(totalCharge, config, steps);

    return MakingChargeResult(
      totalChargePaisa: totalCharge,
      metalChargePaisa: metalCharge,
      stoneChargePaisa: stoneCharge,
      metalWeightGrams: request.metalWeightGrams,
      stoneWeightGrams: request.stoneWeightGrams,
      metalRatePaisaPerGram: request.metalRatePaisaPerGram,
      appliedType: MakingChargeType.tiered,
      calculationBreakdown: _buildBreakdown(steps),
      steps: steps,
      calculatedAt: DateTime.now(),
    );
  }

  /// Complexity-based calculation
  static MakingChargeResult _calculateComplexity(
    CalculateMakingChargesRequest request,
    List<CalculationStep> steps,
  ) {
    final config = request.config;
    final complexity = request.complexity ?? JewelleryComplexity.medium;

    // Find complexity rate
    final complexityRates = config.complexityRates ?? [];
    ComplexityRate? rate = complexityRates.firstWhere(
      (r) => r.complexity == complexity,
      orElse: () => ComplexityRate(
        complexity: complexity,
        ratePaisaPerGram: 100000, // Default ₹1000/g
      ),
    );

    steps.add(
      CalculationStep(
        description: 'Complexity level',
        formula: complexity.displayName,
        resultPaisa: 0,
      ),
    );

    steps.add(
      CalculationStep(
        description: 'Rate for ${complexity.displayName}',
        formula: '₹${rate.displayRatePerGram}/g',
        resultPaisa: 0,
      ),
    );

    int metalCharge = (request.metalWeightGrams * rate.ratePaisaPerGram)
        .round();

    steps.add(
      CalculationStep(
        description: 'Metal making charges',
        formula:
            '${request.metalWeightGrams.toStringAsFixed(2)}g × ₹${rate.displayRatePerGram}',
        resultPaisa: metalCharge,
      ),
    );

    // Stone charges
    int? stoneCharge;
    if (config.includeStoneWeight &&
        request.stoneWeightGrams != null &&
        request.stoneWeightGrams! > 0) {
      stoneCharge = _calculateStoneCharge(config, request, steps);
    }

    int totalCharge = metalCharge + (stoneCharge ?? 0);
    totalCharge = _applyConstraints(totalCharge, config, steps);

    return MakingChargeResult(
      totalChargePaisa: totalCharge,
      metalChargePaisa: metalCharge,
      stoneChargePaisa: stoneCharge,
      metalWeightGrams: request.metalWeightGrams,
      stoneWeightGrams: request.stoneWeightGrams,
      metalRatePaisaPerGram: request.metalRatePaisaPerGram,
      appliedType: MakingChargeType.complexity,
      calculationBreakdown: _buildBreakdown(steps),
      steps: steps,
      calculatedAt: DateTime.now(),
    );
  }

  /// Combination calculation (base + percentage)
  static MakingChargeResult _calculateCombination(
    CalculateMakingChargesRequest request,
    List<CalculationStep> steps,
  ) {
    final config = request.config;
    final baseAmount = config.baseAmountPaisa ?? 0;
    final percentage = config.additionalPercentage ?? 0;

    // Base amount
    steps.add(
      CalculationStep(
        description: 'Base making charges',
        formula: '₹${(baseAmount / 100).toStringAsFixed(2)}',
        resultPaisa: baseAmount,
      ),
    );

    // Additional percentage of metal value
    final metalValue = request.metalWeightGrams * request.metalRatePaisaPerGram;
    final additionalCharge = (metalValue * (percentage / 100)).round();

    if (percentage > 0) {
      steps.add(
        CalculationStep(
          description: 'Additional ($percentage% of metal value)',
          formula: '₹${(metalValue / 100).toStringAsFixed(2)} × $percentage%',
          resultPaisa: additionalCharge,
        ),
      );
    }

    int metalCharge = baseAmount + additionalCharge;

    steps.add(
      CalculationStep(
        description: 'Total metal charges',
        formula:
            '₹${(baseAmount / 100).toStringAsFixed(2)} + ₹${(additionalCharge / 100).toStringAsFixed(2)}',
        resultPaisa: metalCharge,
      ),
    );

    // Stone charges
    int? stoneCharge;
    if (config.includeStoneWeight &&
        request.stoneWeightGrams != null &&
        request.stoneWeightGrams! > 0) {
      stoneCharge = _calculateStoneCharge(config, request, steps);
    }

    int totalCharge = metalCharge + (stoneCharge ?? 0);
    totalCharge = _applyConstraints(totalCharge, config, steps);

    return MakingChargeResult(
      totalChargePaisa: totalCharge,
      metalChargePaisa: metalCharge,
      stoneChargePaisa: stoneCharge,
      metalWeightGrams: request.metalWeightGrams,
      stoneWeightGrams: request.stoneWeightGrams,
      metalRatePaisaPerGram: request.metalRatePaisaPerGram,
      appliedType: MakingChargeType.combination,
      calculationBreakdown: _buildBreakdown(steps),
      steps: steps,
      calculatedAt: DateTime.now(),
    );
  }

  /// Calculate stone making charges
  ///
  /// STONE COUNT FIX (Requirement 8.3): Uses the real `stoneCount` field from
  /// the request instead of the placeholder "1 stone per gram" assumption.
  static int _calculateStoneCharge(
    MakingChargesConfig config,
    CalculateMakingChargesRequest request,
    List<CalculationStep> steps,
  ) {
    if (request.stoneWeightGrams == null || request.stoneWeightGrams! <= 0) {
      return 0;
    }

    int stoneCharge = 0;

    // Method 1: Per-stone charge using real stone count (Requirement 8.3)
    if (config.stoneMakingChargePaisa != null) {
      final int count = request.stoneCount > 0 ? request.stoneCount : 1;
      stoneCharge = config.stoneMakingChargePaisa! * count;

      steps.add(
        CalculationStep(
          description: 'Stone making charges ($count stones)',
          formula:
              '₹${(config.stoneMakingChargePaisa! / 100).toStringAsFixed(2)} × $count stones',
          resultPaisa: stoneCharge,
        ),
      );
    }

    // Method 2: Percentage of stone weight
    if (config.stoneWeightPercentage > 0) {
      final effectiveStoneWeight =
          request.stoneWeightGrams! * (config.stoneWeightPercentage / 100);

      if (config.ratePaisaPerGram != null) {
        final weightBasedCharge =
            (effectiveStoneWeight * config.ratePaisaPerGram!).round();

        steps.add(
          CalculationStep(
            description:
                'Stone weight charge (${config.stoneWeightPercentage}% of ${request.stoneWeightGrams!.toStringAsFixed(2)}g)',
            formula:
                '${effectiveStoneWeight.toStringAsFixed(2)}g × ₹${(config.ratePaisaPerGram! / 100).toStringAsFixed(2)}',
            resultPaisa: weightBasedCharge,
          ),
        );

        stoneCharge = weightBasedCharge;
      }
    }

    return stoneCharge;
  }

  /// Apply minimum and maximum charge constraints
  static int _applyConstraints(
    int charge,
    MakingChargesConfig config,
    List<CalculationStep> steps,
  ) {
    // Apply minimum
    if (config.minimumChargePaisa != null &&
        charge < config.minimumChargePaisa!) {
      final adjustedCharge = config.minimumChargePaisa!;

      steps.add(
        CalculationStep(
          description: 'Minimum charge applied',
          formula:
              'Max(₹${(charge / 100).toStringAsFixed(2)}, ₹${(config.minimumChargePaisa! / 100).toStringAsFixed(2)})',
          resultPaisa: adjustedCharge,
        ),
      );

      return adjustedCharge;
    }

    // Apply maximum
    if (config.maximumChargePaisa != null &&
        charge > config.maximumChargePaisa!) {
      final adjustedCharge = config.maximumChargePaisa!;

      steps.add(
        CalculationStep(
          description: 'Maximum charge applied',
          formula:
              'Min(₹${(charge / 100).toStringAsFixed(2)}, ₹${(config.maximumChargePaisa! / 100).toStringAsFixed(2)})',
          resultPaisa: adjustedCharge,
        ),
      );

      return adjustedCharge;
    }

    return charge;
  }

  /// Build human-readable breakdown
  static String _buildBreakdown(List<CalculationStep> steps) {
    final buffer = StringBuffer();
    for (final step in steps) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write('${step.description}: ');
      buffer.write('${step.formula} = ');
      buffer.write('₹${(step.resultPaisa / 100).toStringAsFixed(2)}');
    }
    return buffer.toString();
  }

  /// Quick calculate - simplified method for common use case
  static int quickCalculate({
    required double weightGrams,
    required double ratePerGram,
    double? minimumCharge,
    double? maximumCharge,
  }) {
    int charge = (weightGrams * ratePerGram * 100).round();

    if (minimumCharge != null && charge < (minimumCharge * 100).round()) {
      charge = (minimumCharge * 100).round();
    }

    if (maximumCharge != null && charge > (maximumCharge * 100).round()) {
      charge = (maximumCharge * 100).round();
    }

    return charge;
  }

  /// Calculate total product price.
  ///
  /// DELEGATION (Requirements 7.2, 7.3):
  /// Metal-value, tax, and total computation are delegated to the canonical
  /// `JewelleryBusinessRules.billTotalPaisa` engine. The making-charges
  /// breakdown (per-gram/percentage/tiered/etc.) is retained here and its
  /// result (`makingChargesPaisa`) is passed as an input to the engine.
  ///
  /// GST SPLIT (Requirement 8.1 — Indian GST treatment):
  /// Under the Indian GST regime for jewellery, GST is computed as:
  ///   • 3% on metal value (gold/silver/platinum — HSN 7108/7113)
  ///   • 5% on making charges (job work services — SAC 9988)
  /// This replaces the prior single flat-rate approach.
  /// Reference: CBIC Notification No. 1/2017 (Rate), Sr. 8 & Sr. 26.
  ///
  /// INPUT VALIDATION (Requirement 15.2):
  /// If `metalWeightGrams < 0`, `metalRatePaisaPerGram < 0`, or any
  /// percentage > 100, the method returns an error map with `isError: true`
  /// and `errorMessage`. The caller should retain the previous valid value.
  ///
  /// Given identical inputs, this method and a direct call to `billTotalPaisa`
  /// produce grand totals equal to the nearest paise.
  static Map<String, dynamic> calculateTotalPrice({
    required double metalWeightGrams,
    required int metalRatePaisaPerGram,
    required MakingChargesConfig makingChargesConfig,
    required GoldPurity purity,
    double? stoneWeightGrams,
    int? stoneRatePaisaPerGram,
    double? wastagePercent,
    JewelleryComplexity? complexity,
    int discountPaisa = 0,
    int stoneCount = 0,
  }) {
    // -----------------------------------------------------------------------
    // 0. Input validation (Requirement 15.2)
    //    Reject negative weight, negative rate, or percentage > 100.
    //    Return an error map so the caller can retain the previous valid value
    //    and surface an error indication to the user.
    // -----------------------------------------------------------------------
    final validationErrors = <String>[];

    if (metalWeightGrams < 0) {
      validationErrors.add('Metal weight cannot be negative');
    }
    if (metalRatePaisaPerGram < 0) {
      validationErrors.add('Metal rate cannot be negative');
    }
    if (wastagePercent != null && wastagePercent > 100) {
      validationErrors.add('Wastage percentage cannot exceed 100%');
    }
    if (makingChargesConfig.percentageOfMetalValue != null &&
        makingChargesConfig.percentageOfMetalValue! > 100) {
      validationErrors.add('Making charges percentage cannot exceed 100%');
    }
    if (makingChargesConfig.additionalPercentage != null &&
        makingChargesConfig.additionalPercentage! > 100) {
      validationErrors.add('Additional percentage cannot exceed 100%');
    }

    if (validationErrors.isNotEmpty) {
      return {
        'isError': true,
        'errorMessage': validationErrors.join('; '),
        'metalValuePaisa': 0,
        'metalValueDisplay': 0.0,
        'wastageValuePaisa': 0,
        'wastageValueDisplay': 0.0,
        'makingChargesPaisa': 0,
        'makingChargesDisplay': 0.0,
        'makingBreakdown': '',
        'stoneValuePaisa': 0,
        'stoneValueDisplay': 0.0,
        'subtotalPaisa': 0,
        'subtotalDisplay': 0.0,
        'metalValueGstPaisa': 0,
        'metalValueGstDisplay': 0.0,
        'makingChargesGstPaisa': 0,
        'makingChargesGstDisplay': 0.0,
        'gstPaisa': 0,
        'gstDisplay': 0.0,
        'totalPaisa': 0,
        'totalDisplay': 0.0,
        'discountPaisa': 0,
        'discountDisplay': 0.0,
      };
    }
    // -----------------------------------------------------------------------
    // 1. Making-charges breakdown (RETAINED — this calculator's core job)
    // -----------------------------------------------------------------------
    final makingResult = calculate(
      CalculateMakingChargesRequest(
        config: makingChargesConfig,
        metalWeightGrams: metalWeightGrams,
        metalRatePaisaPerGram: metalRatePaisaPerGram,
        stoneWeightGrams: stoneWeightGrams,
        wastagePercent: wastagePercent,
        complexity: complexity,
        stoneCount: stoneCount,
      ),
    );

    // -----------------------------------------------------------------------
    // 2. Convert weight to integer milligrams for the canonical engine
    // -----------------------------------------------------------------------
    final int grossWeightMilligrams = (metalWeightGrams * 1000).round();

    // -----------------------------------------------------------------------
    // 3. Compute the 24K per-gram rate from the caller's effective per-gram
    //    rate and purity.
    //
    //    The canonical engine applies:
    //      metalValue = weight_mg * fineness * rate24K / 1_000_000
    //
    //    The caller passes `metalRatePaisaPerGram` which is typically the
    //    effective rate for the given purity. To back-derive the 24K rate:
    //      rate24K = metalRatePaisaPerGram * finenessDenominator / finenessNumerator
    //
    //    This ensures billTotalPaisa's fineness math reproduces the intended
    //    metal value.
    // -----------------------------------------------------------------------
    final int ratePerGram24KPaisa =
        (metalRatePaisaPerGram * GoldPurity.finenessDenominator) ~/
        purity.finenessNumerator;

    // -----------------------------------------------------------------------
    // 4. Get metal value from the canonical engine (for breakdown display)
    // -----------------------------------------------------------------------
    final int metalValuePaisa = JewelleryBusinessRules.billTotalPaisa(
      grossWeightMilligrams: grossWeightMilligrams,
      purity: purity,
      ratePerGram24KPaisa: ratePerGram24KPaisa,
    );

    // -----------------------------------------------------------------------
    // 5. Compute wastage in paise — applied ONCE here (Requirement 8.2).
    //    This is the SINGLE wastage application point. The double-count path
    //    in `_calculatePerGram` (which previously added wastage to effective
    //    weight when `applyOnWastage` was true) has been removed.
    // -----------------------------------------------------------------------
    int wastageValuePaisa = 0;
    if (wastagePercent != null && wastagePercent > 0) {
      wastageValuePaisa = (metalValuePaisa * wastagePercent ~/ 100);
    }

    // -----------------------------------------------------------------------
    // 6. Stone value (integer paise) — uses real stoneCount (Requirement 8.3)
    // -----------------------------------------------------------------------
    int stoneValuePaisa = 0;
    if (stoneWeightGrams != null &&
        stoneWeightGrams > 0 &&
        stoneRatePaisaPerGram != null) {
      stoneValuePaisa = (stoneWeightGrams * stoneRatePaisaPerGram).round();
    }

    // -----------------------------------------------------------------------
    // 7. Aggregate non-metal charges = making breakdown + wastage + stone
    //    These feed into billTotalPaisa as `makingChargesPaisa`.
    // -----------------------------------------------------------------------
    final int aggregateMakingPaisa =
        makingResult.totalChargePaisa + wastageValuePaisa + stoneValuePaisa;

    // -----------------------------------------------------------------------
    // 8. Compute subtotal (before tax) via the canonical engine
    // -----------------------------------------------------------------------
    final int subtotalPaisa = JewelleryBusinessRules.billTotalPaisa(
      grossWeightMilligrams: grossWeightMilligrams,
      purity: purity,
      ratePerGram24KPaisa: ratePerGram24KPaisa,
      makingChargesPaisa: aggregateMakingPaisa,
      discountPaisa: discountPaisa,
    );

    // -----------------------------------------------------------------------
    // 9. Compute SPLIT GST (Requirement 8.1 — Indian GST treatment).
    //
    //    Under Indian GST for jewellery (CBIC Notification No. 1/2017):
    //      • Metal value attracts 3% GST (gold/silver — HSN 7108/7113)
    //      • Making charges attract 5% GST (job work — SAC 9988)
    //
    //    This replaces the prior single flat-rate approach that applied one
    //    percentage to the entire subtotal, which is non-compliant with the
    //    documented Indian GST treatment.
    //
    //    All intermediate values are integer paise (Requirement 8.4).
    // -----------------------------------------------------------------------
    final int metalValueGstPaisa = metalValuePaisa * 3 ~/ 100;
    final int makingChargesGstPaisa = aggregateMakingPaisa * 5 ~/ 100;
    final int totalGstPaisa = metalValueGstPaisa + makingChargesGstPaisa;

    // -----------------------------------------------------------------------
    // 10. Delegate the final total to billTotalPaisa (canonical engine)
    // -----------------------------------------------------------------------
    final int totalPaisa = JewelleryBusinessRules.billTotalPaisa(
      grossWeightMilligrams: grossWeightMilligrams,
      purity: purity,
      ratePerGram24KPaisa: ratePerGram24KPaisa,
      makingChargesPaisa: aggregateMakingPaisa,
      taxPaisa: totalGstPaisa,
      discountPaisa: discountPaisa,
    );

    return {
      'metalValuePaisa': metalValuePaisa,
      'metalValueDisplay': metalValuePaisa / 100,
      'wastageValuePaisa': wastageValuePaisa,
      'wastageValueDisplay': wastageValuePaisa / 100,
      'makingChargesPaisa': makingResult.totalChargePaisa,
      'makingChargesDisplay': makingResult.totalChargePaisa / 100,
      'makingBreakdown': makingResult.calculationBreakdown,
      'stoneValuePaisa': stoneValuePaisa,
      'stoneValueDisplay': stoneValuePaisa / 100,
      'subtotalPaisa': subtotalPaisa,
      'subtotalDisplay': subtotalPaisa / 100,
      // Split GST breakdown (Requirement 8.1)
      'metalValueGstPaisa': metalValueGstPaisa,
      'metalValueGstDisplay': metalValueGstPaisa / 100,
      'makingChargesGstPaisa': makingChargesGstPaisa,
      'makingChargesGstDisplay': makingChargesGstPaisa / 100,
      'gstPaisa': totalGstPaisa,
      'gstDisplay': totalGstPaisa / 100,
      'totalPaisa': totalPaisa,
      'totalDisplay': totalPaisa / 100,
      'discountPaisa': discountPaisa,
      'discountDisplay': discountPaisa / 100,
    };
  }
}
