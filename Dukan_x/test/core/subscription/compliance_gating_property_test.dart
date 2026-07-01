// ============================================================================
// Task 7.11 — PROPERTY TEST
// Feature: subscription-plan-tiers, Property 12
// **Validates: Requirements 11.1, 11.2, 11.3, 11.4, 11.5**
// ============================================================================
// Property 12: Compliance and seasonal capabilities gated at Premium and above.
//
// For all business types, every registered compliance-or-seasonal capability
// (useDrugSchedule, useBatchExpiry, useFuelManagement, useShiftManagement) is
// assigned only to Premium_Tier or Enterprise_Tier.
//
//   FORWARD   — builder output places every registered compliance/seasonal
//               capability at Premium or Enterprise for real and synthesized
//               registries, and the validator reports no Req 11.5 violation.
//   REJECTION — assigning such a capability to Basic or Pro makes the validator
//               report the violation under Req 11.5, naming the capability and
//               its (too-low) tier.
//
// The builder and validator are SEPARATE implementations: the forward direction
// feeds builder output to the validator; the rejection direction mutates a
// builder-produced (valid) mapping to break exactly this rule.
//
// Property-based testing library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test test/core/subscription/compliance_gating_property_test.dart
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

  // The capabilities this property gates (Req 11). Sorted for determinism.
  final gatedCaps = CapabilityClassifier.complianceSeasonalCapabilities.toList()
    ..sort((a, b) => a.index.compareTo(b.index));

  // Req 11 floor is Premium; Basic/Pro are illegal.
  const SubscriptionTier floor = SubscriptionTier.premium;
  const String rule = 'Req 11.5 compliance-gating';

  // Forward: each registered gated capability sits at Premium or Enterprise,
  // and the validator reports no Req 11.5 violation.
  bool forwardHolds(
    String type,
    Set<BusinessCapability> registered,
    PlanMapping mapping,
    PlanMappingValidator validator,
  ) {
    for (final cap in CapabilityClassifier.complianceSeasonalCapabilities) {
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
  final gatedIndexGen = Gen.interval(0, gatedCaps.length - 1);
  // The illegal target tier: Basic (0) or Pro (1).
  final lowTierGen = Gen.elementOf<SubscriptionTier>(const [
    SubscriptionTier.basic,
    SubscriptionTier.pro,
  ]);

  group('Feature: subscription-plan-tiers, Property 12 '
      '(Compliance and seasonal gated at Premium and above)', () {
    test('Feature: subscription-plan-tiers, Property 12 — FORWARD: every '
        'registered compliance/seasonal capability is at Premium or Enterprise '
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
          // chosen compliance/seasonal capability plus standard filler.
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

    test('Feature: subscription-plan-tiers, Property 12 — REJECTION: assigning '
        'a compliance/seasonal capability to Basic or Pro is reported under '
        'Req 11.5', () {
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

    test('Feature: subscription-plan-tiers, Property 12 — example: '
        'useDrugSchedule at Pro is reported under Req 11.5', () {
      const cap = BusinessCapability.useDrugSchedule;
      final registered = <BusinessCapability>{...kStandardFiller, cap};
      final reg = {synthKey: registered};
      final builder = PlanMappingBuilder(registry: reg);
      final validator = PlanMappingValidator(registry: reg);
      final base = builder.buildFor(synthKey);

      final assignments = assignmentsOf(base);
      assignments[cap] = SubscriptionTier.pro;
      final mutated = rebuildAssignments(base, assignments);

      expect(
        findViolation(
          validator.validate(synthKey, mutated),
          rule: rule,
          capability: cap,
          tier: SubscriptionTier.pro,
        ),
        isNotNull,
      );
    });
  });
}
