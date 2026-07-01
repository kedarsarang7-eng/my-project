// ============================================================================
// Task 7.4 — PROPERTY TEST
// Feature: subscription-plan-tiers, Property 4
// **Validates: Requirements 3.1, 3.2, 3.4**
// ============================================================================
// Property 4: Hard isolation and completeness.
//
//   FORWARD  (Req 3.1, 3.4): for every business type, every capability the
//            builder assigns to any tier is a Registered_Capability for that
//            type, and the union of the four tiers equals exactly the registered
//            capability set. The independent validator agrees.
//
//   REJECTION (Req 3.2): inserting a Hard_Isolated_Capability (one that is NOT
//            registered for the type) into a tier causes the validator to reject
//            the mapping and report the offending capability and business type.
//
// Both directions run over the 19 real registered types AND synthesized random
// registries (Billing_Core + >= 5 random extras).
//
// PBT library: dartproptest ^0.2.1.
//
// Run: flutter test test/core/subscription/hard_isolation_property_test.dart
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

  /// True when every assigned capability is registered AND the union of all
  /// four tiers equals exactly [registered] (Req 3.1, 3.4).
  bool isIsolatedAndComplete(
    PlanMapping mapping,
    Set<BusinessCapability> registered,
  ) {
    final union = <BusinessCapability>{};
    for (final tier in SubscriptionTier.values) {
      for (final cap in mapping.capabilitiesAt(tier)) {
        if (!registered.contains(cap)) {
          return false; // assigned but unregistered
        }
        union.add(cap);
      }
    }
    return setEquals(union, registered);
  }

  group('Feature: subscription-plan-tiers, Property 4 '
      '(Hard isolation and completeness)', () {
    test(
      'Feature: subscription-plan-tiers, Property 4 — FORWARD: builder output '
      'for real types only assigns registered caps and is complete',
      () {
        final held = forAll(
          (String type) {
            final builder = PlanMappingBuilder();
            final validator = PlanMappingValidator();
            final mapping = builder.buildFor(type);
            final registered = businessCapabilityRegistry[type]!;

            if (!isIsolatedAndComplete(mapping, registered)) return false;
            return validator.validate(type, mapping).isValid;
          },
          [realTypeGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    test(
      'Feature: subscription-plan-tiers, Property 4 — FORWARD: builder output '
      'for synthesized registries only assigns registered caps and is complete',
      () {
        final held = forAll(
          (Set<BusinessCapability> registered) {
            final registry = {kSynthType: registered};
            final builder = PlanMappingBuilder(registry: registry);
            final validator = PlanMappingValidator(registry: registry);
            final mapping = builder.buildFor(kSynthType);

            if (!isIsolatedAndComplete(mapping, registered)) return false;
            return validator.validate(kSynthType, mapping).isValid;
          },
          [registryGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    test(
      'Feature: subscription-plan-tiers, Property 4 — REJECTION: inserting an '
      'unregistered capability into a tier is rejected and the offending '
      'capability + business type reported',
      () {
        final held = forAll(
          (Set<BusinessCapability> registered, int seed) {
            final registry = {kSynthType: registered};
            final builder = PlanMappingBuilder(registry: registry);
            final validator = PlanMappingValidator(registry: registry);
            final base = builder.buildFor(kSynthType);

            // A Hard_Isolated_Capability: any enum value not registered for
            // this type.
            final hardCandidates =
                BusinessCapability.values
                    .where((c) => !registered.contains(c))
                    .toList()
                  ..sort((a, b) => a.index.compareTo(b.index));
            precond(hardCandidates.isNotEmpty);
            final hard = hardCandidates[seed % hardCandidates.length];

            // Insert into a chosen tier and every higher tier so the mapping
            // stays cumulative (the only invariant broken is hard isolation).
            const tiers = SubscriptionTier.values;
            final target = tiers[seed % tiers.length];
            final mutatedTiers = copyTiers(base);
            for (final t in SubscriptionTier.values) {
              if (t.index >= target.index) mutatedTiers[t]!.add(hard);
            }

            final mutated = rebuildMapping(base, mutatedTiers);
            final result = validator.validate(kSynthType, mutated);

            final isolationViolations = result.violations.where(
              (v) =>
                  v.rule == 'Req 3.2 hard-isolation' &&
                  v.capability == hard &&
                  v.businessType == kSynthType &&
                  v.tier == target,
            );
            return !result.isValid && isolationViolations.isNotEmpty;
          },
          [registryGen, Gen.interval(0, 1 << 20)],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // Deterministic anchor over a real type.
    test('Feature: subscription-plan-tiers, Property 4 — anchor: inserting an '
        'unregistered capability into Enterprise for clinic is rejected', () {
      const type = 'clinic';
      final builder = PlanMappingBuilder();
      final validator = PlanMappingValidator();
      final base = builder.buildFor(type);
      final registered = businessCapabilityRegistry[type]!;

      final hard = BusinessCapability.values.firstWhere(
        (c) => !registered.contains(c),
      );
      final tiers = copyTiers(base);
      tiers[SubscriptionTier.enterprise]!.add(hard);
      final mutated = rebuildMapping(base, tiers);
      final result = validator.validate(type, mutated);

      expect(result.isValid, isFalse);
      expect(
        result.violations.any(
          (v) =>
              v.rule == 'Req 3.2 hard-isolation' &&
              v.capability == hard &&
              v.businessType == type &&
              v.tier == SubscriptionTier.enterprise,
        ),
        isTrue,
        reason: 'expected a hard-isolation violation for $hard at enterprise',
      );
    });
  });
}
