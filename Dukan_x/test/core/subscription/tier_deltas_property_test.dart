// ============================================================================
// Task 7.6 — PROPERTY TEST
// Feature: subscription-plan-tiers, Property 7
// **Validates: Requirements 6.1, 6.2, 6.4**
// ============================================================================
// Property 7: Tier deltas are non-empty and correctly recorded.
//
//   FORWARD  (Req 6.1, 6.4): for every business type, each tier's recorded
//            Tier_Delta equals that tier's capabilities minus the next-lower
//            tier's capabilities; and for types whose Available_Capability_Count
//            permits, the Pro, Premium, and Enterprise deltas each contain at
//            least one capability. The independent validator agrees.
//
//   REJECTION (Req 6.2): collapsing a tier onto its next-lower tier — making
//            that tier's delta empty where the count permits a non-empty delta —
//            causes the validator to reject the mapping and report the affected
//            tier.
//
// Both directions run over the 19 real registered types AND synthesized random
// registries. Synthesized registries always have Available_Capability_Count >= 8,
// where every tier delta is non-empty, so the synthesized forward direction
// asserts strictly non-empty Pro/Premium/Enterprise deltas. Real types use a
// note-aware assertion so the documented 'other'-type exception (Req 14, whose
// Pro=Premium=Enterprise) is honored rather than treated as a failure.
//
// PBT library: dartproptest ^0.2.1.
//
// Run: flutter test test/core/subscription/tier_deltas_property_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/subscription/plan_mapping.dart';
import 'package:dukanx/core/subscription/plan_mapping_builder.dart';
import 'package:dukanx/core/subscription/plan_mapping_validator.dart';
import 'package:dukanx/core/subscription/subscription_tier.dart';

import 'subscription_pbt_support.dart';

void main() {
  final registryGen = validRegistryGen();

  /// The higher tiers whose Tier_Delta is expected to be non-empty when the
  /// count permits.
  const higherTiers = [
    SubscriptionTier.pro,
    SubscriptionTier.premium,
    SubscriptionTier.enterprise,
  ];

  /// True when every recorded delta equals `tier \ next-lower-tier` (Req 6.4).
  bool deltasCorrectlyRecorded(PlanMapping mapping) {
    const ordered = SubscriptionTier.values;
    for (var i = 0; i < ordered.length; i++) {
      final tier = ordered[i];
      final lower = i == 0
          ? const <BusinessCapability>{}
          : mapping.capabilitiesAt(ordered[i - 1]);
      final computed = mapping.capabilitiesAt(tier).difference(lower);
      if (!setEquals(computed, mapping.deltaAt(tier))) return false;
    }
    return true;
  }

  /// Whether an empty delta for [tier] is excused by a recorded note (the same
  /// conditions the validator honors: small-count empty delta, the 'other'
  /// exception, or a plan-washing exemption).
  bool emptyDeltaExcused(PlanMapping mapping, SubscriptionTier tier) {
    return mapping.notes.any((note) {
      final kindAllows =
          note.kind == MappingNoteKind.emptyDelta ||
          note.kind == MappingNoteKind.otherTypeException ||
          note.kind == MappingNoteKind.planWashingException;
      final tierMatches = note.tier == null || note.tier == tier;
      return kindAllows && tierMatches;
    });
  }

  group('Feature: subscription-plan-tiers, Property 7 '
      '(Tier deltas are non-empty and correctly recorded)', () {
    test('Feature: subscription-plan-tiers, Property 7 — FORWARD: real-type '
        'deltas are correctly recorded and non-empty unless excused', () {
      final held = forAll(
        (String type) {
          final builder = PlanMappingBuilder();
          final validator = PlanMappingValidator();
          final mapping = builder.buildFor(type);

          // Req 6.4: recorded delta == computed delta for every tier.
          if (!deltasCorrectlyRecorded(mapping)) return false;

          // Req 6.1: Pro/Premium/Enterprise deltas non-empty unless a note
          // documents why the count cannot produce one (e.g. 'other').
          for (final tier in higherTiers) {
            if (mapping.deltaAt(tier).isEmpty &&
                !emptyDeltaExcused(mapping, tier)) {
              return false;
            }
          }

          return validator.validate(type, mapping).isValid;
        },
        [realTypeGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    test('Feature: subscription-plan-tiers, Property 7 — FORWARD: synthesized '
        'registries (count >= 8) have correctly recorded, strictly non-empty '
        'Pro/Premium/Enterprise deltas', () {
      final held = forAll(
        (Set<BusinessCapability> registered) {
          final registry = {kSynthType: registered};
          final builder = PlanMappingBuilder(registry: registry);
          final validator = PlanMappingValidator(registry: registry);
          final mapping = builder.buildFor(kSynthType);

          if (!deltasCorrectlyRecorded(mapping)) return false;
          for (final tier in higherTiers) {
            if (mapping.deltaAt(tier).isEmpty) return false;
          }
          return validator.validate(kSynthType, mapping).isValid;
        },
        [registryGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    test(
      'Feature: subscription-plan-tiers, Property 7 — REJECTION: collapsing a '
      'tier onto its next-lower tier (empty delta) is rejected and the '
      'affected tier reported',
      () {
        final held = forAll(
          (Set<BusinessCapability> registered, int seed) {
            final registry = {kSynthType: registered};
            final builder = PlanMappingBuilder(registry: registry);
            final validator = PlanMappingValidator(registry: registry);
            final base = builder.buildFor(kSynthType);

            // Choose a higher tier and its adjacent lower tier.
            const adjacent = {
              SubscriptionTier.pro: SubscriptionTier.basic,
              SubscriptionTier.premium: SubscriptionTier.pro,
              SubscriptionTier.enterprise: SubscriptionTier.premium,
            };
            final target = higherTiers[seed % higherTiers.length];
            final lower = adjacent[target]!;

            // The base delta is non-empty (count >= 8), so collapsing the
            // target onto the lower tier genuinely empties a delta the count
            // permits.
            precond(base.deltaAt(target).isNotEmpty);

            final tiers = copyTiers(base);
            tiers[target] = {...base.capabilitiesAt(lower)};
            // Strip notes so no recorded justification can excuse the empty
            // delta we just created — the validator must reject it on merit.
            final mutated = rebuildMapping(base, tiers, notes: const []);
            final result = validator.validate(kSynthType, mutated);

            final emptyDeltaViolations = result.violations.where(
              (v) =>
                  v.rule == 'Req 6.2 empty-delta' &&
                  v.tier == target &&
                  v.businessType == kSynthType,
            );
            return !result.isValid && emptyDeltaViolations.isNotEmpty;
          },
          [registryGen, Gen.interval(0, 1 << 20)],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // Deterministic anchor over a real type: collapse Premium onto Pro.
    test(
      'Feature: subscription-plan-tiers, Property 7 — anchor: collapsing '
      'Premium onto Pro for grocery is rejected with an empty-delta violation',
      () {
        const type = 'grocery';
        final builder = PlanMappingBuilder();
        final validator = PlanMappingValidator();
        final base = builder.buildFor(type);

        final tiers = copyTiers(base);
        tiers[SubscriptionTier.premium] = {
          ...base.capabilitiesAt(SubscriptionTier.pro),
        };
        final mutated = rebuildMapping(base, tiers, notes: const []);
        final result = validator.validate(type, mutated);

        expect(result.isValid, isFalse);
        expect(
          result.violations.any(
            (v) =>
                v.rule == 'Req 6.2 empty-delta' &&
                v.tier == SubscriptionTier.premium &&
                v.businessType == type,
          ),
          isTrue,
          reason: 'expected an empty-delta violation for premium',
        );
      },
    );
  });
}
