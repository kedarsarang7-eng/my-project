// ============================================================================
// Shared support for the workflow/gating property tests (Tasks 7.7–7.11,
// Properties 8–12) of the subscription-plan-tiers spec.
//
// This file is intentionally NOT named `*_test.dart` so the test runner does
// not execute it directly; it is imported by the five property-test files:
//   - workflow_pairs_property_test.dart      (Property 8)
//   - stock_entry_ordering_property_test.dart (Property 9)
//   - analytics_gating_property_test.dart     (Property 10)
//   - enterprise_gating_property_test.dart    (Property 11)
//   - compliance_gating_property_test.dart    (Property 12)
//
// The builder and validator are SEPARATE implementations. The forward
// direction feeds builder output through the targeted invariant; the rejection
// direction mutates a builder-produced ("valid") mapping to break exactly one
// rule and asserts the validator reports it.
//
// To keep a rejection mutation isolated to a single rule, `rebuildAssignments`
// re-derives cumulative tier sets (so monotonicity + completeness stay intact),
// recomputes the per-tier deltas (so the Req 6.4 delta-record check passes),
// and attaches notes that suppress the *soft* checks the validator allows to
// deviate (coverage bands Req 1.6, empty deltas Req 6.3, plan-washing Req 15.x).
// None of the targeted structural rules (workflow cohesion, stock ordering, or
// gating floors/ceilings) have any note-based suppression, so the only rule
// left broken is the one the mutation targets.
// ============================================================================

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/subscription/plan_mapping.dart';
import 'package:dukanx/core/subscription/plan_mapping_validator.dart';
import 'package:dukanx/core/subscription/subscription_tier.dart';

/// At least 100 iterations per the spec (200 is the dartproptest default).
const int kNumRuns = 200;

/// Standard (floor = Basic, non-gated, non-billing) capabilities used to pad a
/// synthesized registry so an essential vertical capability always exists and
/// the lower tiers have something to fill, keeping the mutated mapping's only
/// broken rule the one under test.
const Set<BusinessCapability> kStandardFiller = {
  BusinessCapability.useProductName,
  BusinessCapability.useProductAdd,
  BusinessCapability.useProductSalePrice,
  BusinessCapability.useProductStockQty,
  BusinessCapability.useProductUnit,
};

/// The lowest [SubscriptionTier] at which [cap] appears in [mapping] (its
/// effective assigned tier, because tiers are cumulative), or `null` when it
/// appears in no tier.
SubscriptionTier? assignedTierOf(PlanMapping mapping, BusinessCapability cap) {
  for (final tier in SubscriptionTier.values) {
    if (mapping.capabilitiesAt(tier).contains(cap)) return tier;
  }
  return null;
}

/// The per-capability assigned tier for every registered capability of
/// [mapping].
Map<BusinessCapability, SubscriptionTier> assignmentsOf(PlanMapping mapping) {
  final result = <BusinessCapability, SubscriptionTier>{};
  for (final cap in mapping.registeredCapabilities) {
    final tier = assignedTierOf(mapping, cap);
    if (tier != null) result[cap] = tier;
  }
  return result;
}

/// Per-tier deltas computed from cumulative tier sets (Basic's delta is its own
/// set). Mirrors the builder/validator delta definition so the Req 6.4
/// delta-record check passes on a rebuilt mapping.
Map<SubscriptionTier, Set<BusinessCapability>> _deltasOf(
  Map<SubscriptionTier, Set<BusinessCapability>> tiers,
) {
  final basic = tiers[SubscriptionTier.basic] ?? const {};
  final pro = tiers[SubscriptionTier.pro] ?? const {};
  final premium = tiers[SubscriptionTier.premium] ?? const {};
  final enterprise = tiers[SubscriptionTier.enterprise] ?? const {};
  return {
    SubscriptionTier.basic: {...basic},
    SubscriptionTier.pro: pro.difference(basic),
    SubscriptionTier.premium: premium.difference(pro),
    SubscriptionTier.enterprise: enterprise.difference(premium),
  };
}

/// Rebuilds a [PlanMapping] from an explicit per-capability tier [assignments]
/// map, deriving cumulative tier sets and recomputed deltas from [base].
///
/// When [suppressSoftRules] is true (the default), coverage-deviation and
/// plan-washing notes are attached so the validator's soft checks (Req 1, 6.2,
/// 15) do not fire — leaving only the rule a mutation deliberately breaks.
PlanMapping rebuildAssignments(
  PlanMapping base,
  Map<BusinessCapability, SubscriptionTier> assignments, {
  bool suppressSoftRules = true,
}) {
  final tiers = <SubscriptionTier, Set<BusinessCapability>>{
    for (final tier in SubscriptionTier.values) tier: <BusinessCapability>{},
  };
  assignments.forEach((cap, assignedTier) {
    for (final tier in SubscriptionTier.values) {
      if (tier.index >= assignedTier.index) tiers[tier]!.add(cap);
    }
  });

  final notes = <MappingNote>[...base.notes];
  if (suppressSoftRules) {
    notes.add(
      const MappingNote(
        kind: MappingNoteKind.coverageDeviation,
        message: 'PBT: coverage band suppressed to isolate the targeted rule.',
      ),
    );
    notes.add(
      const MappingNote(
        kind: MappingNoteKind.planWashingException,
        message:
            'PBT: plan-washing/empty-delta suppressed to isolate the targeted '
            'rule.',
      ),
    );
  }

  return PlanMapping(
    businessType: base.businessType,
    tiers: tiers,
    registeredCapabilities: base.registeredCapabilities,
    deltas: _deltasOf(tiers),
    essentialVerticalCapability: base.essentialVerticalCapability,
    essentialVerticalRationale: base.essentialVerticalRationale,
    workflowPairTiers: base.workflowPairTiers,
    notes: notes,
  );
}

/// The first violation in [result] matching [rule] and, when provided,
/// [capability] and [tier]; or `null` when none matches.
ValidationViolation? findViolation(
  ValidationResult result, {
  required String rule,
  BusinessCapability? capability,
  SubscriptionTier? tier,
}) {
  for (final v in result.violations) {
    if (v.rule == rule &&
        (capability == null || v.capability == capability) &&
        (tier == null || v.tier == tier)) {
      return v;
    }
  }
  return null;
}

/// The set of distinct rule labels present in [result].
Set<String> violatedRules(ValidationResult result) =>
    result.violations.map((v) => v.rule).toSet();
