// ============================================================================
// Shared support for the subscription-plan-tiers property tests.
//
// This file is NOT a test file (it has no `main` and does not end in
// `_test.dart`), so the test runner never executes it directly. It is imported
// by the four property-test files (Properties 3, 4, 6, 7) to share:
//
//   * smart generators that synthesize registry entries the builder can always
//     turn into a *valid* mapping (so the forward direction is never vacuous),
//   * a deterministic "mutate one valid mapping to break exactly one rule"
//     helper used by every rejection-direction property.
//
// The synthesized-registry generator always includes the three Billing_Core
// members and at least five additional capabilities, giving an
// Available_Capability_Count of 8 or more. This was determined empirically:
// builder output for every registry of size >= 8 (and for all 19 real types)
// passes the independent PlanMappingValidator, while smaller registries can hit
// documented small-count exceptions (empty deltas, no second Enterprise
// capability). Keeping synthesized registries at >= 8 capabilities means the
// forward properties assert a real, non-degenerate guarantee.
//
// PBT library: dartproptest ^0.2.1.
// ============================================================================

import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/subscription/capability_classifier.dart';
import 'package:dukanx/core/subscription/plan_mapping.dart';
import 'package:dukanx/core/subscription/subscription_tier.dart';

/// At least 100 iterations per the spec; 200 is the dartproptest default.
const int kNumRuns = 200;

/// The sentinel registry key used for synthesized single-entry registries.
const String kSynthType = 'pbtSynthType';

/// The three Billing_Core members, always included in a synthesized registry so
/// that Basic is well-formed and the mapping validates (Req 5).
final List<BusinessCapability> kBillingCore = CapabilityClassifier
    .billingCoreCapabilities
    .toList();

/// Every capability that is not a Billing_Core member. Synthesized registries
/// draw their "extra" capabilities from this pool so the Billing_Core members
/// are added exactly once.
final List<BusinessCapability> kNonBillingCaps = BusinessCapability.values
    .where((c) => !CapabilityClassifier.billingCoreCapabilities.contains(c))
    .toList(growable: false);

/// A generator drawing one of the 19 real registered business types.
final Generator<String> realTypeGen = Gen.elementOf<String>(
  businessCapabilityRegistry.keys.toList(),
);

/// A generator of synthesized registry capability sets the builder can always
/// turn into a valid mapping.
///
/// Each generated set is `{...Billing_Core, ...extras}` where `extras` is a
/// random subset of [kNonBillingCaps] of size `[minExtras, maxExtras]`. Because
/// Billing_Core (3 members) is disjoint from the extras pool, the resulting
/// Available_Capability_Count is `3 + |extras| >= 3 + minExtras`. With the
/// default `minExtras = 5` every generated registry has at least 8
/// capabilities — inside the "always valid" envelope.
Generator<Set<BusinessCapability>> validRegistryGen({
  int minExtras = 5,
  int maxExtras = 24,
}) {
  return Gen.set<BusinessCapability>(
    Gen.elementOf<BusinessCapability>(kNonBillingCaps),
    minSize: minExtras,
    maxSize: maxExtras,
  ).map((extras) => <BusinessCapability>{...kBillingCore, ...extras});
}

/// A mutable deep copy of [mapping]'s cumulative tier sets, suitable for
/// surgical mutation before rebuilding a [PlanMapping].
Map<SubscriptionTier, Set<BusinessCapability>> copyTiers(PlanMapping mapping) =>
    {
      for (final tier in SubscriptionTier.values)
        tier: {...mapping.capabilitiesAt(tier)},
    };

/// Rebuilds a [PlanMapping] from mutated [tiers], recomputing each tier's
/// Tier_Delta as `tier \ next-lower-tier` so the recorded delta always matches
/// the (mutated) cumulative sets.
///
/// Recomputing the deltas is deliberate: it keeps a mutation *surgical*. The
/// only invariant a mutation breaks is the one it targets, rather than also
/// tripping the "recorded delta must equal computed delta" check (Req 6.4) as a
/// side effect. [notes] defaults to the base mapping's notes; pass an explicit
/// list to strip notes that would otherwise excuse the targeted violation.
PlanMapping rebuildMapping(
  PlanMapping base,
  Map<SubscriptionTier, Set<BusinessCapability>> tiers, {
  List<MappingNote>? notes,
}) {
  const ordered = SubscriptionTier.values;
  final deltas = <SubscriptionTier, Set<BusinessCapability>>{};
  for (var i = 0; i < ordered.length; i++) {
    final tier = ordered[i];
    final lower = i == 0
        ? const <BusinessCapability>{}
        : tiers[ordered[i - 1]]!;
    deltas[tier] = tiers[tier]!.difference(lower);
  }
  return PlanMapping(
    businessType: base.businessType,
    tiers: tiers,
    registeredCapabilities: base.registeredCapabilities,
    deltas: deltas,
    essentialVerticalCapability: base.essentialVerticalCapability,
    essentialVerticalRationale: base.essentialVerticalRationale,
    workflowPairTiers: base.workflowPairTiers,
    notes: notes ?? base.notes,
  );
}

/// Whether two capability sets contain exactly the same members.
bool setEquals(Set<BusinessCapability> a, Set<BusinessCapability> b) =>
    a.length == b.length && a.containsAll(b);
