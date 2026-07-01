// ============================================================================
// Task 7.5 — PROPERTY TEST
// Feature: subscription-plan-tiers, Property 6
// **Validates: Requirements 5.1, 5.2, 5.3, 5.5, 5.6**
// ============================================================================
// Property 6: Registered billing-core members live at Basic.
//
//   FORWARD  (Req 5.1, 5.2, 5.3, 5.6): for every business type, every registered
//            Billing_Core member (useInvoiceCreate, useInvoiceList,
//            useInvoiceSearch) is assigned to Basic_Tier (and therefore to every
//            higher tier), even when a member would otherwise fall under
//            analytics gating. The independent validator agrees.
//
//   REJECTION (Req 5.5): moving a registered Billing_Core member above Basic
//            (removing it from Basic while leaving it in a higher tier) causes
//            the validator to reject the mapping and report the split, naming the
//            billing-core member.
//
// Both directions run over the 19 real registered types AND synthesized random
// registries. Synthesized registries always include all three Billing_Core
// members (see subscription_pbt_support.dart), so the billing-core check is
// always exercised with three registered members.
//
// PBT library: dartproptest ^0.2.1.
//
// Run: flutter test test/core/subscription/billing_core_property_test.dart
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

  /// True when every registered Billing_Core member is present at Basic_Tier
  /// (Req 5.1, 5.2, 5.6).
  bool billingCoreAtBasic(
    PlanMapping mapping,
    Set<BusinessCapability> registered,
  ) {
    final basic = mapping.capabilitiesAt(SubscriptionTier.basic);
    for (final cap in CapabilityClassifier.billingCoreCapabilities) {
      if (registered.contains(cap) && !basic.contains(cap)) return false;
    }
    return true;
  }

  group('Feature: subscription-plan-tiers, Property 6 '
      '(Registered billing-core members live at Basic)', () {
    test('Feature: subscription-plan-tiers, Property 6 — FORWARD: every '
        'registered billing-core member is at Basic for real types', () {
      final held = forAll(
        (String type) {
          final builder = PlanMappingBuilder();
          final validator = PlanMappingValidator();
          final mapping = builder.buildFor(type);
          final registered = businessCapabilityRegistry[type]!;

          if (!billingCoreAtBasic(mapping, registered)) return false;
          return validator.validate(type, mapping).isValid;
        },
        [realTypeGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    test(
      'Feature: subscription-plan-tiers, Property 6 — FORWARD: every '
      'registered billing-core member is at Basic for synthesized registries',
      () {
        final held = forAll(
          (Set<BusinessCapability> registered) {
            final registry = {kSynthType: registered};
            final builder = PlanMappingBuilder(registry: registry);
            final validator = PlanMappingValidator(registry: registry);
            final mapping = builder.buildFor(kSynthType);

            if (!billingCoreAtBasic(mapping, registered)) return false;
            return validator.validate(kSynthType, mapping).isValid;
          },
          [registryGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    test('Feature: subscription-plan-tiers, Property 6 — REJECTION: moving a '
        'registered billing-core member above Basic is rejected and the split '
        'reported', () {
      final held = forAll(
        (Set<BusinessCapability> registered, int seed) {
          final registry = {kSynthType: registered};
          final builder = PlanMappingBuilder(registry: registry);
          final validator = PlanMappingValidator(registry: registry);
          final base = builder.buildFor(kSynthType);

          // Pick a registered Billing_Core member and push it above Basic by
          // removing it from Basic only (it remains at Pro and above, so the
          // mapping stays cumulative — the only broken rule is billing-core
          // placement).
          final registeredBilling =
              CapabilityClassifier.billingCoreCapabilities
                  .where(registered.contains)
                  .toList()
                ..sort((a, b) => a.index.compareTo(b.index));
          precond(registeredBilling.isNotEmpty);
          final member = registeredBilling[seed % registeredBilling.length];

          final tiers = copyTiers(base);
          tiers[SubscriptionTier.basic]!.remove(member);
          // It must still appear at Pro+ for the "split" to be meaningful.
          precond(tiers[SubscriptionTier.pro]!.contains(member));

          final mutated = rebuildMapping(base, tiers);
          final result = validator.validate(kSynthType, mutated);

          final billingViolations = result.violations.where(
            (v) =>
                v.rule == 'Req 5.5 billing-core' &&
                v.capability == member &&
                v.businessType == kSynthType,
          );
          return !result.isValid && billingViolations.isNotEmpty;
        },
        [registryGen, Gen.interval(0, 1 << 20)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // Deterministic anchor over a real type.
    test('Feature: subscription-plan-tiers, Property 6 — anchor: moving '
        'useInvoiceCreate above Basic for grocery is rejected', () {
      const type = 'grocery';
      final builder = PlanMappingBuilder();
      final validator = PlanMappingValidator();
      final base = builder.buildFor(type);

      const member = BusinessCapability.useInvoiceCreate;
      expect(
        businessCapabilityRegistry[type]!.contains(member),
        isTrue,
        reason: 'precondition: grocery registers $member',
      );

      final tiers = copyTiers(base);
      tiers[SubscriptionTier.basic]!.remove(member);
      final mutated = rebuildMapping(base, tiers);
      final result = validator.validate(type, mutated);

      expect(result.isValid, isFalse);
      expect(
        result.violations.any(
          (v) =>
              v.rule == 'Req 5.5 billing-core' &&
              v.capability == member &&
              v.businessType == type,
        ),
        isTrue,
        reason: 'expected a billing-core split violation for $member',
      );
    });
  });
}
