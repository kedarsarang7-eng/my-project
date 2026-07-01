// ============================================================================
// Task 7.8 — PROPERTY TEST
// Feature: subscription-plan-tiers, Property 9
// **Validates: Requirements 7.2**
// ============================================================================
// Property 9: Stock entry never unlocks after purchase order.
//
// For all business types whose registry includes BOTH useStockEntry and
// usePurchaseOrder, the tier of useStockEntry is less than or equal to the tier
// of usePurchaseOrder.
//
//   FORWARD   — builder output keeps tier(useStockEntry) <= tier(usePurchaseOrder)
//               for real and synthesized registries, and the validator reports
//               no Req 7.2 ordering violation.
//   REJECTION — assigning useStockEntry strictly above usePurchaseOrder makes
//               the validator report the ordering violation under Req 7.2,
//               naming useStockEntry and its (too-high) tier.
//
// The builder and validator are SEPARATE implementations: the forward direction
// feeds builder output to the validator; the rejection direction mutates a
// builder-produced (valid) mapping to break exactly this rule.
//
// Property-based testing library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test test/core/subscription/stock_entry_ordering_property_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/subscription/plan_mapping.dart';
import 'package:dukanx/core/subscription/plan_mapping_builder.dart';
import 'package:dukanx/core/subscription/plan_mapping_validator.dart';
import 'package:dukanx/core/subscription/subscription_tier.dart';

import 'gating_workflow_pbt_support.dart';

void main() {
  const String synthKey = 'pbtSynthesizedType';

  const stockEntry = BusinessCapability.useStockEntry;
  const purchaseOrder = BusinessCapability.usePurchaseOrder;

  // Forward: ordering holds and the validator reports no Req 7.2 violation.
  bool forwardHolds(
    String type,
    Set<BusinessCapability> registered,
    PlanMapping mapping,
    PlanMappingValidator validator,
  ) {
    if (registered.contains(stockEntry) && registered.contains(purchaseOrder)) {
      final stockTier = assignedTierOf(mapping, stockEntry);
      final poTier = assignedTierOf(mapping, purchaseOrder);
      if (stockTier == null || poTier == null) return false;
      if (stockTier > poTier) return false;
    }
    return !violatedRules(
      validator.validate(type, mapping),
    ).contains('Req 7.2 stock-entry-ordering');
  }

  // Generators.
  final typeGen = Gen.elementOf<String>(
    businessCapabilityRegistry.keys.toList(),
  );
  // Random padding (useSupplierBill excluded later for clean rejection runs).
  final subsetGen = Gen.set<BusinessCapability>(
    Gen.elementOf<BusinessCapability>(BusinessCapability.values),
    minSize: 0,
    maxSize: 24,
  );

  group('Feature: subscription-plan-tiers, Property 9 '
      '(Stock entry never unlocks after purchase order)', () {
    test('Feature: subscription-plan-tiers, Property 9 — FORWARD: '
        'tier(useStockEntry) <= tier(usePurchaseOrder) for real and '
        'synthesized registries', () {
      final held = forAll(
        (String type, Set<BusinessCapability> subset) {
          // Direction A: a real registered business type.
          final realMapping = PlanMappingBuilder().buildFor(type);
          final realOk = forwardHolds(
            type,
            businessCapabilityRegistry[type]!,
            realMapping,
            PlanMappingValidator(),
          );

          // Direction B: a synthesized registry that always contains both
          // useStockEntry and usePurchaseOrder.
          final registered = <BusinessCapability>{
            ...subset,
            ...kStandardFiller,
            stockEntry,
            purchaseOrder,
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
        [typeGen, subsetGen],
        numRuns: kNumRuns,
      );

      expect(held, isTrue);
    });

    test('Feature: subscription-plan-tiers, Property 9 — REJECTION: assigning '
        'useStockEntry above usePurchaseOrder is reported under Req 7.2', () {
      final held = forAll(
        (Set<BusinessCapability> subset) {
          // Exclude useSupplierBill so the {usePurchaseOrder, useSupplierBill}
          // workflow pair imposes no co-location constraint, keeping the
          // mutated mapping's only broken rule the ordering rule.
          final registered = <BusinessCapability>{
            ...subset,
            ...kStandardFiller,
            stockEntry,
            purchaseOrder,
          }..remove(BusinessCapability.useSupplierBill);

          final reg = {synthKey: registered};
          final builder = PlanMappingBuilder(registry: reg);
          final validator = PlanMappingValidator(registry: reg);
          final base = builder.buildFor(synthKey);

          // Pin purchase order at Basic and stock entry one tier higher
          // (Pro): a clear ordering violation that touches no other rule
          // (both are standard capabilities placeable at any tier).
          final assignments = assignmentsOf(base);
          assignments[purchaseOrder] = SubscriptionTier.basic;
          assignments[stockEntry] = SubscriptionTier.pro;
          final mutated = rebuildAssignments(base, assignments);

          final result = validator.validate(synthKey, mutated);
          final reported =
              findViolation(
                result,
                rule: 'Req 7.2 stock-entry-ordering',
                capability: stockEntry,
                tier: SubscriptionTier.pro,
              ) !=
              null;
          final rules = violatedRules(result);
          final isolated =
              rules.length == 1 &&
              rules.contains('Req 7.2 stock-entry-ordering');
          return reported && isolated;
        },
        [subsetGen],
        numRuns: kNumRuns,
      );

      expect(held, isTrue);
    });

    test(
      'Feature: subscription-plan-tiers, Property 9 — example: stock entry at '
      'Enterprise above purchase order at Basic is reported',
      () {
        final registered = <BusinessCapability>{
          ...kStandardFiller,
          stockEntry,
          purchaseOrder,
        };
        final reg = {synthKey: registered};
        final builder = PlanMappingBuilder(registry: reg);
        final validator = PlanMappingValidator(registry: reg);
        final base = builder.buildFor(synthKey);

        final assignments = assignmentsOf(base);
        assignments[purchaseOrder] = SubscriptionTier.basic;
        assignments[stockEntry] = SubscriptionTier.enterprise;
        final mutated = rebuildAssignments(base, assignments);

        final result = validator.validate(synthKey, mutated);
        expect(
          findViolation(
            result,
            rule: 'Req 7.2 stock-entry-ordering',
            capability: stockEntry,
            tier: SubscriptionTier.enterprise,
          ),
          isNotNull,
        );
      },
    );
  });
}
