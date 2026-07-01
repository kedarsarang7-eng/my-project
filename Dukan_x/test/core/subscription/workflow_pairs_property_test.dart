// ============================================================================
// Task 7.7 — PROPERTY TEST
// Feature: subscription-plan-tiers, Property 8
// **Validates: Requirements 7.1, 7.3, 7.4, 8.1, 8.2, 8.3, 8.4, 8.5**
// ============================================================================
// Property 8: Workflow pairs share a tier.
//
// For all business types and for every defined Workflow_Pair
// ({usePurchaseOrder, useSupplierBill}, {useIMEI, useWarranty},
// {useJobSheets, useRepairStatus}, {usePrescription, useDoctorLinking},
// {usePatientRegistry, useAppointments}):
//
//   FORWARD   — when both members are Registered_Capability values, the builder
//               assigns them to the SAME tier and documents that tier in the
//               mapping's workflowPairTiers; the validator reports no split.
//   REJECTION — splitting a fully-registered pair across two tiers makes the
//               validator report the split with the offending capability, the
//               new tier, and the correct rule (Req 7.3 for the purchase pair,
//               Req 8.5 for the specialized pairs).
//
// The builder and validator are SEPARATE implementations: the forward direction
// feeds builder output to the validator; the rejection direction mutates a
// builder-produced (valid) mapping to break exactly this rule.
//
// Property-based testing library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
// `forAll` returns true when the property held for every run and throws a
// shrinking Exception with a counterexample otherwise.
//
// Run: flutter test test/core/subscription/workflow_pairs_property_test.dart
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

  // The members of a Workflow_Pair, sorted by enum name (the same key order the
  // builder uses to document workflowPairTiers).
  List<BusinessCapability> sortedMembers(Set<BusinessCapability> pair) =>
      pair.toList()..sort((a, b) => a.name.compareTo(b.name));

  // The documentation key the builder records for a fully-registered pair.
  String pairKey(List<BusinessCapability> members) =>
      members.map((c) => c.name).join('+');

  // Whether [registered] contains both members of [pair].
  bool fullyRegistered(
    Set<BusinessCapability> pair,
    Set<BusinessCapability> r,
  ) => pair.every(r.contains);

  // Forward check: every fully-registered pair shares a tier that is documented,
  // and the validator reports no workflow-split rule.
  bool forwardHolds(
    String type,
    Set<BusinessCapability> registered,
    PlanMapping mapping,
    PlanMappingValidator validator,
  ) {
    for (final pair in workflowPairs) {
      if (!fullyRegistered(pair, registered)) continue;
      final members = sortedMembers(pair);
      final tierA = assignedTierOf(mapping, members[0]);
      final tierB = assignedTierOf(mapping, members[1]);
      if (tierA == null || tierB == null || tierA != tierB) return false;
      // Req 7.4 / 8: the shared tier is documented.
      final documented = mapping.workflowPairTiers[pairKey(members)];
      if (documented != tierA) return false;
    }
    final rules = violatedRules(validator.validate(type, mapping));
    return !rules.contains('Req 7.3 workflow-pair') &&
        !rules.contains('Req 8.5 workflow-pair');
  }

  // Generators (defined once, reused across runs).
  final typeGen = Gen.elementOf<String>(
    businessCapabilityRegistry.keys.toList(),
  );
  final subsetGen = Gen.set<BusinessCapability>(
    Gen.elementOf<BusinessCapability>(BusinessCapability.values),
    minSize: 0,
    maxSize: 24,
  );
  final pairIndexGen = Gen.interval(0, workflowPairs.length - 1);

  group('Feature: subscription-plan-tiers, Property 8 '
      '(Workflow pairs share a tier)', () {
    test(
      'Feature: subscription-plan-tiers, Property 8 — FORWARD: builder keeps '
      'every fully-registered Workflow_Pair on one documented tier for real '
      'and synthesized registries',
      () {
        final held = forAll(
          (String type, Set<BusinessCapability> subset, int pairIdx) {
            // Direction A: a real registered business type.
            final realBuilder = PlanMappingBuilder();
            final realValidator = PlanMappingValidator();
            final realMapping = realBuilder.buildFor(type);
            final realOk = forwardHolds(
              type,
              businessCapabilityRegistry[type]!,
              realMapping,
              realValidator,
            );

            // Direction B: a synthesized registry that always contains the
            // chosen pair (plus standard filler so lower tiers can fill).
            final members = sortedMembers(workflowPairs[pairIdx]);
            final registered = <BusinessCapability>{
              ...subset,
              ...kStandardFiller,
              ...members,
            };
            final reg = {synthKey: registered};
            final synthBuilder = PlanMappingBuilder(registry: reg);
            final synthValidator = PlanMappingValidator(registry: reg);
            final synthMapping = synthBuilder.buildFor(synthKey);
            final synthOk = forwardHolds(
              synthKey,
              registered,
              synthMapping,
              synthValidator,
            );

            return realOk && synthOk;
          },
          [typeGen, subsetGen, pairIndexGen],
          numRuns: kNumRuns,
        );

        expect(held, isTrue);
      },
    );

    test(
      'Feature: subscription-plan-tiers, Property 8 — REJECTION: splitting a '
      'fully-registered Workflow_Pair makes the validator report the split '
      'with the offending capability, tier, and correct rule',
      () {
        final held = forAll(
          (Set<BusinessCapability> subset, int pairIdx) {
            final members = sortedMembers(workflowPairs[pairIdx]);
            final registered = <BusinessCapability>{
              ...subset,
              ...kStandardFiller,
              ...members,
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

            // Start from a fully valid mapping (soft rules suppressed) so the
            // mutation is the only thing the validator can object to.
            final cleanBase = rebuildAssignments(base, assignmentsOf(base));
            precond(validator.validate(synthKey, cleanBase).isValid);

            // Move the non-ordering member of the pair (useSupplierBill for
            // the purchase pair, otherwise the first member) so that the
            // stock-entry ordering rule is never disturbed by the mutation.
            final moveCap =
                members.contains(BusinessCapability.usePurchaseOrder)
                ? BusinessCapability.useSupplierBill
                : members.first;
            final sharedTier = assignedTierOf(base, moveCap)!;
            // Move within {basic, pro} so the essential-vertical-by-Pro rule
            // is never violated as a side effect.
            final target = sharedTier == SubscriptionTier.basic
                ? SubscriptionTier.pro
                : SubscriptionTier.basic;

            final assignments = assignmentsOf(base);
            assignments[moveCap] = target;
            final mutated = rebuildAssignments(base, assignments);

            final result = validator.validate(synthKey, mutated);
            final expectedRule =
                members.contains(BusinessCapability.usePurchaseOrder)
                ? 'Req 7.3 workflow-pair'
                : 'Req 8.5 workflow-pair';

            final reported =
                findViolation(
                  result,
                  rule: expectedRule,
                  capability: moveCap,
                  tier: target,
                ) !=
                null;
            // Exactly this rule was broken by the mutation.
            final rules = violatedRules(result);
            final isolated = rules.length == 1 && rules.contains(expectedRule);
            return reported && isolated;
          },
          [subsetGen, pairIndexGen],
          numRuns: kNumRuns,
        );

        expect(held, isTrue);
      },
    );

    // Forward anchor: every one of the 19 real types' builder output passes
    // the full validator (no violations of any rule, including Property 8's).
    test(
      'Feature: subscription-plan-tiers, Property 8 — all 19 real types build '
      'and fully pass the validator',
      () {
        final mappings = PlanMappingBuilder().buildAll();
        final result = PlanMappingValidator().validateAll(mappings);
        expect(
          result.isValid,
          isTrue,
          reason: result.violations.map((v) => v.toString()).join('\n'),
        );
      },
    );

    // Deterministic example: a fully-registered pair split is rejected.
    test('Feature: subscription-plan-tiers, Property 8 — example: splitting '
        '{useIMEI, useWarranty} is reported under Req 8.5', () {
      final registered = <BusinessCapability>{
        ...kStandardFiller,
        BusinessCapability.useIMEI,
        BusinessCapability.useWarranty,
      };
      final reg = {synthKey: registered};
      final builder = PlanMappingBuilder(registry: reg);
      final validator = PlanMappingValidator(registry: reg);
      final base = builder.buildFor(synthKey);

      final assignments = assignmentsOf(base);
      final shared = assignments[BusinessCapability.useIMEI]!;
      final target = shared == SubscriptionTier.basic
          ? SubscriptionTier.pro
          : SubscriptionTier.basic;
      assignments[BusinessCapability.useIMEI] = target;
      final mutated = rebuildAssignments(base, assignments);

      final result = validator.validate(synthKey, mutated);
      expect(
        findViolation(
          result,
          rule: 'Req 8.5 workflow-pair',
          capability: BusinessCapability.useIMEI,
          tier: target,
        ),
        isNotNull,
      );
    });
  });
}
