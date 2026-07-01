// ============================================================================
// Task 7.9 — PROPERTY TEST
// Feature: subscription-plan-tiers, Property 10
// **Validates: Requirements 9.1, 9.2, 9.3, 9.4, 9.5**
// ============================================================================
// Property 10: Analytics and export capabilities gated at Premium and above.
//
// For all business types, every registered analytics-or-export capability
// (useInventoryExport, usePurchaseRegister, useDeadStock, useRevenueOverview)
// is assigned only to Premium_Tier or Enterprise_Tier.
//
//   FORWARD   — builder output places every registered analytics/export
//               capability at Premium or Enterprise for real and synthesized
//               registries, and the validator reports no Req 9.5 violation.
//   REJECTION — assigning such a capability to Basic or Pro makes the validator
//               report the violation under Req 9.5, naming the capability and
//               its (too-low) tier.
//
// The builder and validator are SEPARATE implementations: the forward direction
// feeds builder output to the validator; the rejection direction mutates a
// builder-produced (valid) mapping to break exactly this rule.
//
// Property-based testing library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test test/core/subscription/analytics_gating_property_test.dart
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

  // The capabilities this property gates (Req 9). Sorted for determinism.
  final gatedCaps = CapabilityClassifier.analyticsExportCapabilities.toList()
    ..sort((a, b) => a.index.compareTo(b.index));

  // Req 9 floor is Premium; Basic/Pro are illegal.
  const SubscriptionTier floor = SubscriptionTier.premium;
  const String rule = 'Req 9.5 analytics-gating';

  // Forward: each registered gated capability sits at Premium or Enterprise,
  // and the validator reports no Req 9.5 violation.
  bool forwardHolds(
    String type,
    Set<BusinessCapability> registered,
    PlanMapping mapping,
    PlanMappingValidator validator,
  ) {
    for (final cap in CapabilityClassifier.analyticsExportCapabilities) {
      if (!registered.contains(cap)) continue;
      final tier = assignedTierOf(mapping, cap);
      if (tier == null || tier < floor) return false;
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
  // Which gated capability to force-register and (in the rejection run) push
  // below its floor.
  final gatedIndexGen = Gen.interval(0, gatedCaps.length - 1);
  // The illegal target tier: Basic (0) or Pro (1).
  final lowTierGen = Gen.elementOf<SubscriptionTier>(const [
    SubscriptionTier.basic,
    SubscriptionTier.pro,
  ]);

  group('Feature: subscription-plan-tiers, Property 10 '
      '(Analytics and export gated at Premium and above)', () {
    test('Feature: subscription-plan-tiers, Property 10 — FORWARD: every '
        'registered analytics/export capability is at Premium or Enterprise '
        'for real and synthesized registries', () {
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
          // chosen analytics capability plus standard filler.
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

    test('Feature: subscription-plan-tiers, Property 10 — REJECTION: assigning '
        'an analytics/export capability to Basic or Pro is reported under '
        'Req 9.5', () {
      final held = forAll(
        (Set<BusinessCapability> subset, int gatedIdx, SubscriptionTier low) {
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

          // Push the gated capability below its floor.
          final assignments = assignmentsOf(base);
          assignments[cap] = low;
          final mutated = rebuildAssignments(base, assignments);

          final result = validator.validate(synthKey, mutated);
          final reported =
              findViolation(result, rule: rule, capability: cap, tier: low) !=
              null;
          final rules = violatedRules(result);
          final isolated = rules.length == 1 && rules.contains(rule);
          return reported && isolated;
        },
        [subsetGen, gatedIndexGen, lowTierGen],
        numRuns: kNumRuns,
      );

      expect(held, isTrue);
    });

    test('Feature: subscription-plan-tiers, Property 10 — example: '
        'useRevenueOverview at Basic is reported under Req 9.5', () {
      const cap = BusinessCapability.useRevenueOverview;
      final registered = <BusinessCapability>{...kStandardFiller, cap};
      final reg = {synthKey: registered};
      final builder = PlanMappingBuilder(registry: reg);
      final validator = PlanMappingValidator(registry: reg);
      final base = builder.buildFor(synthKey);

      final assignments = assignmentsOf(base);
      assignments[cap] = SubscriptionTier.basic;
      final mutated = rebuildAssignments(base, assignments);

      expect(
        findViolation(
          validator.validate(synthKey, mutated),
          rule: rule,
          capability: cap,
          tier: SubscriptionTier.basic,
        ),
        isNotNull,
      );
    });
  });
}
