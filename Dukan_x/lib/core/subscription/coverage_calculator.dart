/// Coverage calculation for the Tiering_System.
///
/// This module answers three questions for the plan-mapping pipeline:
///
/// 1. **How many capabilities does a business type have?**
///    [CoverageCalculator.availableCount] reads the
///    `Available_Capability_Count` *only* from `businessCapabilityRegistry`
///    (the single source of truth, Requirement 3.5).
/// 2. **What integer tier sizes should each tier target?**
///    [CoverageCalculator.recommendedSizes] picks, per tier, an integer
///    capability count whose Tier_Coverage lands inside the tier's
///    [CoverageBand]; when no integer fits the band it selects the closest
///    ordering-preserving size and records a deviation justification
///    (Requirement 1.6). Coverage-band evaluation is skipped entirely for a
///    zero-capability type (Requirement 1.7).
/// 3. **Does an actual mapping respect its bands?**
///    [CoverageCalculator.coverageOf] and [CoverageCalculator.evaluate] measure
///    the Tier_Coverage of a concrete tier assignment and flag any tier whose
///    coverage falls outside its band.
///
/// ### Decoupling from `PlanMapping`
///
/// The `PlanMapping` model (task 5.1, `plan_mapping.dart`) is built in parallel
/// with this module and may not exist yet. To avoid a hard compile-time
/// dependency and a build race, the coverage math here is expressed against the
/// minimal shape it actually needs — a cumulative per-tier capability set
/// ([TierCapabilities]) plus an `Available_Capability_Count` — rather than the
/// concrete `PlanMapping` type. Once `plan_mapping.dart` lands, callers pass
/// `mapping.tiers` and `calculator.availableCount(mapping.businessType)` into
/// these methods; no convenience overload is added here while the model is
/// absent, keeping the core math reusable and dependency-free.
///
/// The module is pure Dart on top of the existing enum and tier model, with no
/// new runtime dependencies.
library;

import '../isolation/business_capability.dart';
import 'subscription_tier.dart';

/// The cumulative capability set assigned to each subscription tier.
///
/// This is the minimal view of a plan mapping that the coverage math needs:
/// for each [SubscriptionTier], the set of [BusinessCapability] values granted
/// at that tier (cumulative, so higher tiers are supersets of lower tiers).
typedef TierCapabilities = Map<SubscriptionTier, Set<BusinessCapability>>;

/// A per-tier coverage record: the band the tier must hit, the capability count
/// chosen for the tier, the resulting Tier_Coverage, whether that coverage is
/// inside the band, and an optional justification when it is not.
///
/// The same record type is produced both when *recommending* target sizes for
/// a tier (see [CoverageCalculator.recommendedSizes]) and when *evaluating* an
/// already-assigned mapping (see [CoverageCalculator.evaluate]). In the former
/// case [chosenSize] is the recommended target; in the latter it is the number
/// of capabilities actually assigned to the tier.
class TierCoverageRecord {
  /// The tier this record describes.
  final SubscriptionTier tier;

  /// The Tier_Coverage band the tier is expected to satisfy.
  final CoverageBand band;

  /// The capability count selected for the tier (a recommended target size, or
  /// the actual number of capabilities assigned, depending on the producer).
  final int chosenSize;

  /// The Tier_Coverage of [chosenSize] against the `Available_Capability_Count`,
  /// as a percentage in `[0, 100]`.
  final double coveragePercent;

  /// Whether [coveragePercent] falls inside [band] (inclusive on both ends).
  final bool withinBand;

  /// A human-readable justification recorded when [withinBand] is `false`.
  ///
  /// `null` when the coverage is inside the band. Present whenever the band is
  /// infeasible for the `Available_Capability_Count`, or when preserving tier
  /// ordering forced a size outside the band (Requirement 1.6).
  final String? deviationReason;

  const TierCoverageRecord({
    required this.tier,
    required this.band,
    required this.chosenSize,
    required this.coveragePercent,
    required this.withinBand,
    this.deviationReason,
  });

  @override
  bool operator ==(Object other) =>
      other is TierCoverageRecord &&
      other.tier == tier &&
      other.band == band &&
      other.chosenSize == chosenSize &&
      other.coveragePercent == coveragePercent &&
      other.withinBand == withinBand &&
      other.deviationReason == deviationReason;

  @override
  int get hashCode => Object.hash(
    tier,
    band,
    chosenSize,
    coveragePercent,
    withinBand,
    deviationReason,
  );

  @override
  String toString() =>
      'TierCoverageRecord(${tier.name}, size=$chosenSize, '
      '${coveragePercent.toStringAsFixed(1)}%, '
      'withinBand=$withinBand'
      '${deviationReason == null ? '' : ', deviation="$deviationReason"'})';
}

/// Computes `Available_Capability_Count`, per-tier Tier_Coverage, feasible band
/// sizes, and deviation records for the Tiering_System.
///
/// All coverage math is derived from the capability registry passed at
/// construction (defaulting to `businessCapabilityRegistry`), so the
/// `Available_Capability_Count` is always sourced from the registry and never
/// from a mapping or any other input (Requirement 3.5).
class CoverageCalculator {
  /// The capability registry treated as the source of truth.
  ///
  /// Defaults to the global `businessCapabilityRegistry`. An explicit registry
  /// can be injected to evaluate synthesized entries (e.g. randomized registry
  /// entries used by property tests) without mutating global state.
  final Map<String, Set<BusinessCapability>> _registry;

  /// Creates a calculator over [registry], or the global
  /// `businessCapabilityRegistry` when [registry] is omitted.
  CoverageCalculator({Map<String, Set<BusinessCapability>>? registry})
    : _registry = registry ?? businessCapabilityRegistry;

  /// The `Available_Capability_Count` for [businessType]: the number of
  /// distinct Registered_Capability values for the type, sourced *only* from
  /// the capability registry (Requirement 3.5).
  ///
  /// Returns `0` for an unknown business type or one with an empty entry. The
  /// registry stores capabilities in a [Set], so its length is already the
  /// distinct count.
  int availableCount(String businessType) {
    final capabilities = _registry[businessType];
    if (capabilities == null) return 0;
    return capabilities.length;
  }

  /// The Tier_Coverage of [tier] in [tiers], as a percentage in `[0, 100]`.
  ///
  /// Defined as `|tiers[tier]| / availableCount * 100`. Returns `0` when
  /// [availableCount] is zero (a zero-capability type has no coverage to
  /// report, Requirement 1.7) or when [tier] is absent from [tiers].
  ///
  /// Operates on the minimal [TierCapabilities] shape rather than a concrete
  /// `PlanMapping`; callers holding a `PlanMapping` pass `mapping.tiers` and
  /// `availableCount(mapping.businessType)`.
  double coverageOf(
    TierCapabilities tiers,
    SubscriptionTier tier,
    int availableCount,
  ) {
    if (availableCount <= 0) return 0;
    final assigned = tiers[tier]?.length ?? 0;
    return assigned / availableCount * 100;
  }

  /// Recommends, for each tier, the integer capability count whose Tier_Coverage
  /// best satisfies the tier's [CoverageBand] for [availableCount].
  ///
  /// For each tier in ascending order the recommended size is:
  /// - a feasible size inside the band (closest to the band midpoint) when one
  ///   exists that also preserves tier ordering (non-decreasing sizes); or
  /// - the integer size closest to the band that preserves ordering, with a
  ///   recorded [TierCoverageRecord.deviationReason], when the band is
  ///   infeasible for [availableCount] (Requirement 1.6).
  ///
  /// Returns an empty list when [availableCount] is zero: coverage-band
  /// evaluation and deviation recording are skipped for a zero-capability type
  /// (Requirement 1.7).
  List<TierCoverageRecord> recommendedSizes(int availableCount) {
    if (availableCount <= 0) return const [];
    final records = <TierCoverageRecord>[];
    var minSize = 0; // sizes must be non-decreasing to preserve tier ordering
    for (final tier in SubscriptionTier.values) {
      final band = tier.band;
      final size = _chooseSize(band, availableCount, minSize);
      final coverage = size / availableCount * 100;
      final withinBand = band.contains(coverage);
      records.add(
        TierCoverageRecord(
          tier: tier,
          band: band,
          chosenSize: size,
          coveragePercent: coverage,
          withinBand: withinBand,
          deviationReason: withinBand
              ? null
              : _deviationReason(tier, band, size, availableCount, coverage),
        ),
      );
      minSize = size;
    }
    return records;
  }

  /// Evaluates an already-assigned mapping: produces one [TierCoverageRecord]
  /// per tier describing the Tier_Coverage of the capabilities actually
  /// assigned to that tier in [tiers], and whether it lands inside the band.
  ///
  /// Skips evaluation entirely (returns an empty list) when [availableCount]
  /// is zero (Requirement 1.7). A tier whose actual coverage falls outside its
  /// band is recorded with a [TierCoverageRecord.deviationReason]
  /// (Requirement 1.6 / 6.3).
  ///
  /// Operates on the minimal [TierCapabilities] shape so it does not depend on
  /// the `PlanMapping` model; callers holding a `PlanMapping` pass
  /// `mapping.tiers` and `availableCount(mapping.businessType)`.
  List<TierCoverageRecord> evaluate(
    TierCapabilities tiers,
    int availableCount,
  ) {
    if (availableCount <= 0) return const [];
    final records = <TierCoverageRecord>[];
    for (final tier in SubscriptionTier.values) {
      final band = tier.band;
      final size = tiers[tier]?.length ?? 0;
      final coverage = size / availableCount * 100;
      final withinBand = band.contains(coverage);
      records.add(
        TierCoverageRecord(
          tier: tier,
          band: band,
          chosenSize: size,
          coveragePercent: coverage,
          withinBand: withinBand,
          deviationReason: withinBand
              ? null
              : _deviationReason(tier, band, size, availableCount, coverage),
        ),
      );
    }
    return records;
  }

  /// Convenience wrapper around [evaluate] that reads the
  /// `Available_Capability_Count` for [businessType] from the registry.
  ///
  /// Equivalent to `evaluate(tiers, availableCount(businessType))`.
  List<TierCoverageRecord> evaluateType(
    String businessType,
    TierCapabilities tiers,
  ) => evaluate(tiers, availableCount(businessType));

  /// Chooses an integer tier size for [band] and [availableCount] that is at
  /// least [minSize] (so tier ordering is preserved).
  ///
  /// Prefers a feasible in-band size closest to the band midpoint; falls back
  /// to the closest ordering-preserving size when the band cannot be satisfied
  /// exactly.
  int _chooseSize(CoverageBand band, int availableCount, int minSize) {
    final feasible = band
        .feasibleSizes(availableCount)
        .where((n) => n >= minSize)
        .toList();
    if (feasible.isNotEmpty) {
      final midpoint = (band.minPercent + band.maxPercent) / 2;
      feasible.sort((a, b) {
        final distanceA = (a / availableCount * 100 - midpoint).abs();
        final distanceB = (b / availableCount * 100 - midpoint).abs();
        final byDistance = distanceA.compareTo(distanceB);
        return byDistance != 0 ? byDistance : a.compareTo(b);
      });
      return feasible.first;
    }
    return _closestSizeToBand(band, availableCount, minSize);
  }

  /// The integer size in `[minSize, availableCount]` whose Tier_Coverage is
  /// closest to [band]. Ties resolve to the smaller size for determinism.
  int _closestSizeToBand(CoverageBand band, int availableCount, int minSize) {
    final lowerBound = minSize.clamp(0, availableCount);
    var best = lowerBound;
    var bestDistance = _distanceToBand(lowerBound, availableCount, band);
    for (var n = lowerBound + 1; n <= availableCount; n++) {
      final distance = _distanceToBand(n, availableCount, band);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = n;
      }
    }
    return best;
  }

  /// The distance (in percentage points) from the Tier_Coverage of [size] to
  /// the nearest edge of [band]; `0` when the coverage is inside the band.
  double _distanceToBand(int size, int availableCount, CoverageBand band) {
    final coverage = size / availableCount * 100;
    if (coverage < band.minPercent) return band.minPercent - coverage;
    if (coverage > band.maxPercent) return coverage - band.maxPercent;
    return 0;
  }

  /// Builds a human-readable justification for a tier whose coverage falls
  /// outside its band (Requirement 1.6).
  String _deviationReason(
    SubscriptionTier tier,
    CoverageBand band,
    int size,
    int availableCount,
    double coverage,
  ) {
    return '${tier.name} coverage ${coverage.toStringAsFixed(1)}% '
        '($size/$availableCount) is outside the target band '
        '${band.minPercent}\u2013${band.maxPercent}%; '
        'selected the closest ordering-preserving size for '
        'availableCount=$availableCount.';
  }
}
