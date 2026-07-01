// ============================================================================
// Task 7.10 — PROPERTY TEST
// Feature: subscription-plan-tiers, Property 11
// **Validates: Requirements 10.1, 10.2, 10.3, 10.4, 10.5, 10.6**
// ============================================================================
// Property 11: Bulk, B2B, and financial-risk capabilities gated at Enterprise.
//
// For all business types, every registered enterprise-only capability
// (useCreditManagement, useCreditLimit, useDispatchNote, useStockReversal,
// useProformaInvoice) is assigned only to Enterprise_Tier.
//
//   FORWARD   — builder output places every registered enterprise-only
//               capability at Enterprise for real and synthesized registries,
//               and the validator reports no Req 10.6 violation.
//   REJECTION — assigning such a capability below Enterprise (Basic, Pro, or
//               Premium) makes the validator report the violation under
//               Req 10.6, naming the capability and its (too-low) tier.
//
// The builder and validator are SEPARATE implementations: the forward direction
// feeds builder output to the validator; the rejection direction mutates a
// builder-produced (valid) mapping to break exactly this rule.
//
// Property-based testing library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test test/core/subscription/enterprise_gating_property_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/subscription/capability_classifier.dart';
import 'package:dukanx/core/subscription/plan_mapping.dart';
import 'package:dukanx/core/subscription/plan_mapping_builder.dart';
import 'package:dukanx/core/subscription/plan_mapping_validator.dart';
import 'package:dukanx/core/subscription/subscription_tier.dart';

import 'gating_workflow_pbt_support.dart';

void main() {
  const String synthKey = 'pbtSynthesizedType';

  // The capabilities this property gates (Req 10). Sorted for determinism.
  final gatedCaps = CapabilityClassifier.enterpriseOnlyCapabilities.toList()
    ..sort((a, b) => a.index.compareTo(b.index));

  const String rule = 'Req 10.6 enterprise-gating';

  // Forward: each registered enterprise-only capability sits exactly at
  // Enterprise, and the validator reports no Req 10.6 violation.
  bool forwardHolds(
    String type,
    Set<BusinessCapability> registered,
    PlanMapping mapping,
    PlanMappingValidator validator,
  ) {
    for (final cap in CapabilityClassifier.enterpriseOnlyCapabilities) {
      if (!registered.contains(cap)) continue;
      final tier = assignedTierOf(mapping, cap);
      if (tier != SubscriptionTier.enterprise) return false;
    }
    return !violatedRules(validator.validate(type, mapping)).contains(rule);
  }

  // Generators.
  final typeGen = Gen.elementOf<String>(
    businessCapabilityRegistry.keys.toList(),
  );
  final subsetGen = Gen.set<BusinessCapability>(
    Gen.elementOf<BusinessCapability>(BusinessCapability.values),
    minSize: 0,
    maxSize: 24,
  );
  final gatedIndexGen = Gen.interval(0, gatedCaps.length - 1);
  // The illegal target tier: Basic (0), Pro (1), or Premium (2).
  final belowEnterpriseGen = Gen.elementOf<SubscriptionTier>(const [
    SubscriptionTier.basic,
    SubscriptionTier.pro,
    SubscriptionTier.premium,
  ]);

  group('Feature: subscription-plan-tiers, Property 11 '
      '(Bulk, B2B, and financial-risk gated at Enterprise)', () {
    test('Feature: subscription-plan-tiers, Property 11 — FORWARD: every '
        'registered enterprise-only capability is at Enterprise for real and '
        'synthesized registries', () {
      final held = forAll(
        (String type, Set<BusinessCapability> subset, int gatedIdx) {
          // Direction A: a real registered business type.
          final realMapping = PlanMappingBuilder().buildFor(type);
          final realOk = forwardHolds(
            type,
            businessCapabilityRegistry[type]!,
            realMapping,
            PlanMappingValidator(),
          );

          // Direction B: a synthesized registry that always contains the
          // chosen enterprise-only capability plus standard filler.
          final registered = <BusinessCapability>{
            ...subset,
            ...kStandardFiller,
            gatedCaps[gatedIdx],
          };
          final reg = {synthKey: registered};
          final synthMapping = PlanMappingBuilder(
            registry: reg,
          ).buildFor(synthKey);
          final synthOk = forwardHolds(
            synthKey,
            registered,
            synthMapping,
            PlanMappingValidator(registry: reg),
          );

          return realOk && synthOk;
        },
        [typeGen, subsetGen, gatedIndexGen],
        numRuns: kNumRuns,
      );

      expect(held, isTrue);
    });

    test('Feature: subscription-plan-tiers, Property 11 — REJECTION: assigning '
        'an enterprise-only capability below Enterprise is reported under '
        'Req 10.6', () {
      final held = forAll(
        (Set<BusinessCapability> subset, int gatedIdx, SubscriptionTier below) {
          final cap = gatedCaps[gatedIdx];
          final registered = <BusinessCapability>{
            ...subset,
            ...kStandardFiller,
            cap,
          };
          final reg = {synthKey: registered};
          final builder = PlanMappingBuilder(registry: reg);
          final validator = PlanMappingValidator(registry: reg);

          PlanMapping base;
          try {
            base = builder.buildFor(synthKey);
          } catch (_) {
            precond(false);
            return true;
          }

          final cleanBase = rebuildAssignments(base, assignmentsOf(base));
          precond(validator.validate(synthKey, cleanBase).isValid);

          // Pull the enterprise-only capability down below Enterprise.
          final assignments = assignmentsOf(base);
          assignments[cap] = below;
          final mutated = rebuildAssignments(base, assignments);

          final result = validator.validate(synthKey, mutated);
          final reported =
              findViolation(result, rule: rule, capability: cap, tier: below) !=
              null;
          final rules = violatedRules(result);
          final isolated = rules.length == 1 && rules.contains(rule);
          return reported && isolated;
        },
        [subsetGen, gatedIndexGen, belowEnterpriseGen],
        numRuns: kNumRuns,
      );

      expect(held, isTrue);
    });

    test('Feature: subscription-plan-tiers, Property 11 — example: '
        'useCreditManagement at Premium is reported under Req 10.6', () {
      const cap = BusinessCapability.useCreditManagement;
      final registered = <BusinessCapability>{...kStandardFiller, cap};
      final reg = {synthKey: registered};
      final builder = PlanMappingBuilder(registry: reg);
      final validator = PlanMappingValidator(registry: reg);
      final base = builder.buildFor(synthKey);

      final assignments = assignmentsOf(base);
      assignments[cap] = SubscriptionTier.premium;
      final mutated = rebuildAssignments(base, assignments);

      expect(
        findViolation(
          validator.validate(synthKey, mutated),
          rule: rule,
          capability: cap,
          tier: SubscriptionTier.premium,
        ),
        isNotNull,
      );
    });
  });
}
