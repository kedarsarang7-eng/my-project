/// Feature_Matrix artifact generator for the Tiering_System.
///
/// The Feature_Matrix is the cross-plan deliverable (Req 17): for every business
/// type it records, against the four ordered tiers, the lowest tier at which
/// each capability is granted. A capability that is Hard_Isolated for a type
/// (not a Registered_Capability) is marked **not-applicable** with a `null`
/// entry. Because tiers are cumulative, storing the single lowest tier fully
/// describes inclusion: a capability granted at tier *T* is also granted at every
/// higher tier (Req 17.2).
///
/// This file defines:
///
/// * [FeatureMatrix] — the immutable grid
///   `included[businessType][capability] = lowest tier, or null when
///   Hard_Isolated`, plus helpers to query inclusion and to **reconstruct** the
///   per-tier capability sets from the grid.
/// * [MatrixDiscrepancy] — a single point where the matrix and a [PlanMapping]
///   disagree (Req 17.4).
///
/// The generator is pure Dart on top of the existing tier model and plan-mapping
/// models; it adds no new runtime dependencies. The matrix is derived solely
/// from the validated [PlanMapping] tier sets, so it cannot drift from the
/// mapping it was built from — and [FeatureMatrix.verifyAgainst] proves that
/// reconstructing the tiers from the matrix reproduces the mapping exactly
/// (Property 17).
library;

import '../isolation/business_capability.dart';
import 'plan_mapping.dart';
import 'subscription_tier.dart';

/// A single disagreement between a [FeatureMatrix] and a [PlanMapping].
///
/// Reported by [FeatureMatrix.verifyAgainst] when the tier capability sets
/// reconstructed from the matrix do not match the mapping's tier sets, or when
/// the matrix is missing a business type that the mapping defines (Req 17.4).
/// The [tier] and [capability] are populated when the discrepancy concerns a
/// specific tier or capability and are `null` for type-level discrepancies.
class MatrixDiscrepancy {
  /// The business type the discrepancy was found in.
  final String businessType;

  /// The tier the discrepancy concerns, when applicable.
  final SubscriptionTier? tier;

  /// The capability the discrepancy concerns, when applicable.
  final BusinessCapability? capability;

  /// A human-readable explanation of the discrepancy.
  final String message;

  const MatrixDiscrepancy({
    required this.businessType,
    required this.message,
    this.tier,
    this.capability,
  });

  @override
  bool operator ==(Object other) =>
      other is MatrixDiscrepancy &&
      other.businessType == businessType &&
      other.tier == tier &&
      other.capability == capability &&
      other.message == message;

  @override
  int get hashCode => Object.hash(businessType, tier, capability, message);

  @override
  String toString() =>
      'MatrixDiscrepancy(type: $businessType, tier: ${tier?.name}, '
      'capability: ${capability?.name}, message: $message)';
}

/// The cross-plan Feature_Matrix (Req 17).
///
/// [included] maps each business type to a row that records, for every
/// [BusinessCapability], the **lowest** [SubscriptionTier] at which the
/// capability is granted, or `null` when the capability is Hard_Isolated for
/// that type (not-applicable). Inclusion at higher tiers is implied because the
/// underlying tiers are cumulative (`basic ⊆ pro ⊆ premium ⊆ enterprise`).
///
/// The matrix is a pure data artifact: build it from a validated set of plan
/// mappings with [FeatureMatrix.fromMappings], query it with [lowestTierFor] /
/// [isIncludedAt], rebuild the per-tier sets with [capabilitiesAt] /
/// [reconstructTiers], and prove it consistent with the source mappings with
/// [verifyAgainst].
class FeatureMatrix {
  /// `included[businessType][capability]` = lowest tier at which the capability
  /// is granted, or `null` when Hard_Isolated for that type.
  ///
  /// Each row records every [BusinessCapability] value, so a `null` entry is an
  /// explicit not-applicable mark rather than a missing key (Req 17.3).
  final Map<String, Map<BusinessCapability, SubscriptionTier?>> included;

  /// Creates an immutable Feature_Matrix.
  ///
  /// [included] and each of its rows are wrapped in unmodifiable views so the
  /// constructed matrix cannot be mutated through the reference passed in.
  FeatureMatrix({
    required Map<String, Map<BusinessCapability, SubscriptionTier?>> included,
  }) : included =
           // Explicit type arguments are required on every nested
           // `unmodifiable` call: `Map.unmodifiable` takes a `dynamic`-typed
           // argument, so without them the inner rows are inferred as
           // `UnmodifiableMapView<dynamic, dynamic>` and the outer construction
           // throws a runtime cast error.
           Map<String, Map<BusinessCapability, SubscriptionTier?>>.unmodifiable(
             {
               for (final entry in included.entries)
                 entry.key:
                     Map<BusinessCapability, SubscriptionTier?>.unmodifiable(
                       entry.value,
                     ),
             },
           );

  /// Builds the Feature_Matrix from a set of per-type plan mappings.
  ///
  /// For each mapping, every [BusinessCapability] value is recorded against the
  /// lowest tier whose cumulative set contains it; capabilities that appear in
  /// no tier (Hard_Isolated for the type) are recorded as `null`
  /// (not-applicable). The result is consistent with the mappings by
  /// construction — see [verifyAgainst].
  factory FeatureMatrix.fromMappings(Map<String, PlanMapping> mappings) {
    final included = <String, Map<BusinessCapability, SubscriptionTier?>>{};
    for (final entry in mappings.entries) {
      included[entry.key] = _rowFor(entry.value);
    }
    return FeatureMatrix(included: included);
  }

  /// Computes the matrix row for a single mapping: every capability mapped to
  /// the lowest tier at which it is granted, or `null` when Hard_Isolated.
  static Map<BusinessCapability, SubscriptionTier?> _rowFor(
    PlanMapping mapping,
  ) {
    return {
      for (final cap in BusinessCapability.values)
        cap: _lowestTierOf(mapping, cap),
    };
  }

  /// The lowest tier whose cumulative set contains [cap], or `null` if no tier
  /// grants it. Tiers are scanned in ascending order (Basic → Enterprise), so
  /// the first match is the lowest.
  static SubscriptionTier? _lowestTierOf(
    PlanMapping mapping,
    BusinessCapability cap,
  ) {
    for (final tier in SubscriptionTier.values) {
      if (mapping.capabilitiesAt(tier).contains(cap)) return tier;
    }
    return null;
  }

  /// The business types present in the matrix.
  Iterable<String> get businessTypes => included.keys;

  /// The lowest tier at which [capability] is granted for [businessType], or
  /// `null` when the capability is Hard_Isolated (not-applicable) for that type
  /// or the type is absent from the matrix.
  SubscriptionTier? lowestTierFor(
    String businessType,
    BusinessCapability capability,
  ) => included[businessType]?[capability];

  /// Whether [capability] is included at [tier] for [businessType].
  ///
  /// True when the capability has a lowest tier at or below [tier] (cumulative
  /// inclusion). A Hard_Isolated capability is never included.
  bool isIncludedAt(
    String businessType,
    BusinessCapability capability,
    SubscriptionTier tier,
  ) {
    final lowest = lowestTierFor(businessType, capability);
    return lowest != null && lowest <= tier;
  }

  /// Reconstructs the cumulative capability set granted at [tier] for
  /// [businessType] from the matrix entries.
  ///
  /// Returns every capability whose lowest tier is at or below [tier]. Returns
  /// an empty set when the type is absent from the matrix.
  Set<BusinessCapability> capabilitiesAt(
    String businessType,
    SubscriptionTier tier,
  ) {
    final row = included[businessType];
    if (row == null) return const <BusinessCapability>{};
    final result = <BusinessCapability>{};
    for (final entry in row.entries) {
      final lowest = entry.value;
      if (lowest != null && lowest <= tier) result.add(entry.key);
    }
    return result;
  }

  /// Reconstructs the four cumulative tier capability sets for [businessType]
  /// from the matrix. The result mirrors `PlanMapping.tiers` and, for a matrix
  /// built from a valid mapping, equals it exactly (Property 17).
  Map<SubscriptionTier, Set<BusinessCapability>> reconstructTiers(
    String businessType,
  ) => {
    for (final tier in SubscriptionTier.values)
      tier: capabilitiesAt(businessType, tier),
  };

  /// Verifies that the matrix is consistent with [mappings] (Req 17.4).
  ///
  /// For each mapping, the tier capability sets reconstructed from the matrix
  /// must equal the mapping's tier sets. Any difference — a missing business
  /// type, or a capability that the matrix and mapping disagree on for a tier —
  /// is reported as a [MatrixDiscrepancy]. An empty list means the matrix
  /// faithfully reproduces every mapping.
  List<MatrixDiscrepancy> verifyAgainst(Map<String, PlanMapping> mappings) {
    final discrepancies = <MatrixDiscrepancy>[];
    for (final entry in mappings.entries) {
      final businessType = entry.key;
      final mapping = entry.value;

      if (!included.containsKey(businessType)) {
        discrepancies.add(
          MatrixDiscrepancy(
            businessType: businessType,
            message:
                'Feature_Matrix has no row for "$businessType" but a '
                'Plan_Mapping exists for it.',
          ),
        );
        continue;
      }

      for (final tier in SubscriptionTier.values) {
        final fromMatrix = capabilitiesAt(businessType, tier);
        final fromMapping = mapping.capabilitiesAt(tier);

        // Granted by the matrix but not by the mapping at this tier.
        for (final cap in fromMatrix.difference(fromMapping)) {
          discrepancies.add(
            MatrixDiscrepancy(
              businessType: businessType,
              tier: tier,
              capability: cap,
              message:
                  'Matrix includes ${cap.name} at ${tier.name} for '
                  '"$businessType", but the Plan_Mapping does not.',
            ),
          );
        }

        // Granted by the mapping but not reflected by the matrix at this tier.
        for (final cap in fromMapping.difference(fromMatrix)) {
          discrepancies.add(
            MatrixDiscrepancy(
              businessType: businessType,
              tier: tier,
              capability: cap,
              message:
                  'Plan_Mapping grants ${cap.name} at ${tier.name} for '
                  '"$businessType", but the matrix does not include it there.',
            ),
          );
        }
      }
    }
    return discrepancies;
  }

  /// Whether the matrix reproduces every mapping in [mappings] with no
  /// discrepancies.
  bool isConsistentWith(Map<String, PlanMapping> mappings) =>
      verifyAgainst(mappings).isEmpty;

  @override
  String toString() => 'FeatureMatrix(${included.length} business type(s))';
}
