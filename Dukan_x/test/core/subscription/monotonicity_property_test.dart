// ============================================================================
// Task 7.3 — PROPERTY TEST
// Feature: subscription-plan-tiers, Property 3
// **Validates: Requirements 2.1, 2.2, 2.3, 2.4**
// ============================================================================
// Property 3: Tier subset monotonicity.
//
//   FORWARD  (Req 2.1, 2.2, 2.3): for every business type, the builder's
//            cumulative tier sets satisfy basic ⊆ pro ⊆ premium ⊆ enterprise,
//            and the independent validator agrees the mapping is valid.
//
//   REJECTION (Req 2.4): mutating a valid mapping so a lower-tier capability is
//            dropped from the next-higher tier (breaking the subset relation)
//            causes the validator to reject the mapping and report the violating
//            capability and the higher tier it went missing from.
//
// Both directions run over the 19 real registered types AND synthesized random
// registries (Billing_Core + >= 5 random extras, so Available_Capability_Count
// >= 8 — inside the envelope where builder output is always valid).
//
// PBT library: dartproptest ^0.2.1. `forAll(closure, [generators], numRuns:)`
// returns true when the property held for every run and throws a shrinking
// Exception with a counterexample otherwise.
//
// Run: flutter test test/core/subscription/monotonicity_property_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/subscription/capability_classifier.dart';
import 'package:dukanx/core/subscription/plan_mapping.dart';
import 'package:dukanx/core/subscription/plan_mapping_builder.dart';
import 'package:dukanx/core/subscription/plan_mapping_validator.dart';
import 'package:dukanx/core/subscription/subscription_tier.dart';

import 'subscription_pbt_support.dart';

void main() {
  final registryGen = validRegistryGen();

  /// True when `basic ⊆ pro ⊆ premium ⊆ enterprise` holds for [mapping].
  bool isMonotonic(PlanMapping mapping) {
    const ordered = SubscriptionTier.values;
    for (var i = 0; i < ordered.length - 1; i++) {
      final lower = mapping.capabilitiesAt(ordered[i]);
      final higher = mapping.capabilitiesAt(ordered[i + 1]);
      if (!higher.containsAll(lower)) return false;
    }
    return true;
  }

  group('Feature: subscription-plan-tiers, Property 3 '
      '(Tier subset monotonicity)', () {
    test(
      'Feature: subscription-plan-tiers, Property 3 — FORWARD: builder output '
      'for real types is monotonic and validates',
      () {
        final held = forAll(
          (String type) {
            final builder = PlanMappingBuilder();
            final validator = PlanMappingValidator();
            final mapping = builder.buildFor(type);

            // Structural monotonicity (Req 2.1–2.3).
            if (!isMonotonic(mapping)) return false;

            // The independent validator must also accept the mapping.
            return validator.validate(type, mapping).isValid;
          },
          [realTypeGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    test(
      'Feature: subscription-plan-tiers, Property 3 — FORWARD: builder output '
      'for synthesized registries is monotonic and validates',
      () {
        final held = forAll(
          (Set<BusinessCapability> registered) {
            final registry = {kSynthType: registered};
            final builder = PlanMappingBuilder(registry: registry);
            final validator = PlanMappingValidator(registry: registry);
            final mapping = builder.buildFor(kSynthType);

            if (!isMonotonic(mapping)) return false;
            return validator.validate(kSynthType, mapping).isValid;
          },
          [registryGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    test('Feature: subscription-plan-tiers, Property 3 — REJECTION: removing a '
        'lower-tier capability from the next-higher tier is rejected and the '
        'violating capability + tier reported', () {
      final held = forAll(
        (Set<BusinessCapability> registered, int seed) {
          final registry = {kSynthType: registered};
          final builder = PlanMappingBuilder(registry: registry);
          final validator = PlanMappingValidator(registry: registry);
          final base = builder.buildFor(kSynthType);

          // Choose a lower→higher adjacent tier pair and a capability that
          // is present in the lower tier (and therefore, by monotonicity,
          // in the higher tier). Removing it ONLY from the higher tier
          // breaks the subset relation for exactly that pair.
          const adjacent = [
            [SubscriptionTier.basic, SubscriptionTier.pro],
            [SubscriptionTier.pro, SubscriptionTier.premium],
            [SubscriptionTier.premium, SubscriptionTier.enterprise],
          ];
          final pair = adjacent[seed % adjacent.length];
          final lower = pair[0];
          final higher = pair[1];

          final lowerCaps = base.capabilitiesAt(lower).toList()
            ..sort((a, b) => a.index.compareTo(b.index));
          // The lower tier is always non-empty (Billing_Core is at Basic),
          // so there is always a capability to drop from `higher`.
          precond(lowerCaps.isNotEmpty);
          final victim = lowerCaps[seed % lowerCaps.length];

          final tiers = copyTiers(base);
          tiers[higher]!.remove(victim);
          // Keep cumulativity above `higher` from masking the break: drop
          // the victim from every tier at or above `higher`.
          for (final t in SubscriptionTier.values) {
            if (t.index >= higher.index) tiers[t]!.remove(victim);
          }
          // Re-add it to `lower` (and below) so the subset relation is
          // genuinely violated: present below, absent above.
          for (final t in SubscriptionTier.values) {
            if (t.index <= lower.index &&
                base.capabilitiesAt(t).contains(victim)) {
              tiers[t]!.add(victim);
            }
          }
          // Only proceed if the victim really is in `lower` but not in
          // `higher` now (it always should be, given the construction).
          precond(
            tiers[lower]!.contains(victim) && !tiers[higher]!.contains(victim),
          );

          final mutated = rebuildMapping(base, tiers);
          final result = validator.validate(kSynthType, mutated);

          // Must reject and report a monotonicity violation naming the
          // victim and the higher tier it went missing from.
          final monoViolations = result.violations.where(
            (v) =>
                v.rule == 'Req 2.4 monotonicity' &&
                v.capability == victim &&
                v.tier == higher,
          );
          return !result.isValid && monoViolations.isNotEmpty;
        },
        [registryGen, Gen.interval(0, 1 << 20)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // Deterministic anchor: a hand-built non-monotonic mapping for a real
    // type is rejected with the expected rule/tier/capability.
    test('Feature: subscription-plan-tiers, Property 3 — anchor: dropping a '
        'Basic capability from Pro for grocery is rejected', () {
      const type = 'grocery';
      final builder = PlanMappingBuilder();
      final validator = PlanMappingValidator();
      final base = builder.buildFor(type);

      final pairCaps = workflowPairs.expand((p) => p).toSet();
      final victim = base
          .capabilitiesAt(SubscriptionTier.basic)
          .firstWhere(
            (c) =>
                !CapabilityClassifier.billingCoreCapabilities.contains(c) &&
                !pairCaps.contains(c) &&
                c != base.essentialVerticalCapability,
          );

      final tiers = copyTiers(base);
      for (final t in SubscriptionTier.values) {
        if (t.index >= SubscriptionTier.pro.index) tiers[t]!.remove(victim);
      }
      final mutated = rebuildMapping(base, tiers);
      final result = validator.validate(type, mutated);

      expect(result.isValid, isFalse);
      expect(
        result.violations.any(
          (v) =>
              v.rule == 'Req 2.4 monotonicity' &&
              v.capability == victim &&
              v.tier == SubscriptionTier.pro,
        ),
        isTrue,
        reason: 'expected a monotonicity violation for $victim at pro',
      );
    });
  });
}
