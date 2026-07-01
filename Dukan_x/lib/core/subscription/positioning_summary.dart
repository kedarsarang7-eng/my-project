/// Plan-positioning summary generator for the Tiering_System.
///
/// The Plan_Positioning_Summary is a human-facing artifact for the pricing and
/// product team (Req 18). It describes, for each of the four ordered tiers
/// (Basic → Pro → Premium → Enterprise):
///
/// * the **target customer** the tier is built for,
/// * the **value narrative** that sells the tier,
/// * the **primary upgrade trigger** that moves a customer toward the next
///   stage,
/// * the **coverage target** the tier must hit (sourced from
///   [SubscriptionTier.band], the Requirement 1 coverage bands), and
/// * the **category anchors** — the [GatingCategory] values whose capabilities
///   anchor that tier's value, consistent with Requirements 9, 10, and 11.
///
/// Unlike the per-type Plan_Mapping, this artifact is tier-level and identical
/// across business types: it captures the *positioning rationale*, not the
/// per-type capability assignment. The narratives are fixed by Requirement 18.2
/// and the coverage targets and anchors are reused from the shared tier model
/// and capability classifier, so this artifact can never drift from the gating
/// rules it summarizes.
///
/// This is pure-Dart logic depending only on [SubscriptionTier]/[CoverageBand]
/// and the [GatingCategory] classification; it is safe to use from any layer.
library;

import 'capability_classifier.dart';
import 'subscription_tier.dart';

/// The positioning of a single subscription tier.
///
/// An immutable value type describing why a tier exists and who it is for. It
/// pairs the human-facing narrative fields (Req 18.1, 18.2) with the machine
/// references that keep the narrative honest: the [coverageTarget] band from
/// Requirement 1 (Req 18.3) and the [categoryAnchors] that tie the tier's value
/// to the gating rules of Requirements 9, 10, and 11 (Req 18.4).
class TierPositioning {
  /// The tier this positioning describes.
  final SubscriptionTier tier;

  /// The customer the tier is built for (e.g. a solo operator for Basic).
  final String targetCustomer;

  /// The value narrative that sells the tier (Req 18.2).
  final String valueNarrative;

  /// The primary trigger that moves a customer toward the next stage (Req 18.1).
  ///
  /// For [SubscriptionTier.enterprise] — the top tier — this describes the
  /// condition that lands a customer at Enterprise rather than a move to a
  /// higher tier, since none exists.
  final String upgradeTrigger;

  /// The Tier_Coverage target the tier must hit, referenced from the
  /// Requirement 1 coverage bands via [SubscriptionTier.band] (Req 18.3).
  final CoverageBand coverageTarget;

  /// The capability categories that anchor this tier's value (Req 18.4).
  ///
  /// Consistent with the gating rules: analytics/export anchors Premium and
  /// above (Req 9), compliance/seasonal anchors Premium and above (Req 11), and
  /// bulk/B2B/financial-risk anchors Enterprise (Req 10). Stored as an
  /// unmodifiable list.
  final List<GatingCategory> categoryAnchors;

  /// Creates an immutable tier positioning. [categoryAnchors] is wrapped in an
  /// unmodifiable view so the value cannot be mutated after construction.
  TierPositioning({
    required this.tier,
    required this.targetCustomer,
    required this.valueNarrative,
    required this.upgradeTrigger,
    required this.coverageTarget,
    required List<GatingCategory> categoryAnchors,
  }) : categoryAnchors = List.unmodifiable(categoryAnchors);

  @override
  String toString() =>
      'TierPositioning(${tier.name}, target="$targetCustomer", '
      'coverage=$coverageTarget, '
      'anchors=${categoryAnchors.map((c) => c.name).join('+')})';
}

/// The Plan_Positioning_Summary artifact: one [TierPositioning] per tier (Req 18).
///
/// Holds exactly one entry for each [SubscriptionTier] in ascending order.
/// Construct the standard, Requirement-18 summary with
/// [PlanPositioningSummaryGenerator.generate].
class PlanPositioningSummary {
  /// The positioning entry for each tier, keyed by [SubscriptionTier].
  final Map<SubscriptionTier, TierPositioning> tiers;

  /// Creates an immutable summary from a per-tier [tiers] map. The map is
  /// wrapped in an unmodifiable view.
  PlanPositioningSummary({
    required Map<SubscriptionTier, TierPositioning> tiers,
  }) : tiers = Map.unmodifiable(tiers);

  /// The positioning for [tier], or `null` when the summary has no entry for it.
  TierPositioning? positioningFor(SubscriptionTier tier) => tiers[tier];

  @override
  String toString() => 'PlanPositioningSummary(${tiers.length} tiers)';
}

/// Generates the standard [PlanPositioningSummary] defined by Requirement 18.
///
/// The summary is fixed: the narratives come verbatim from Req 18.2, the
/// coverage targets from the shared tier bands (Req 18.3), and the category
/// anchors from the gating categories of Requirements 9–11 (Req 18.4). The
/// generator therefore takes no per-type input and always produces the same,
/// fully-populated four-tier summary.
class PlanPositioningSummaryGenerator {
  /// Creates a stateless generator. Instances are interchangeable.
  const PlanPositioningSummaryGenerator();

  /// Builds the Plan_Positioning_Summary with exactly one non-empty entry per
  /// tier (Req 18.1–18.4).
  PlanPositioningSummary generate() {
    return PlanPositioningSummary(
      tiers: {
        for (final tier in SubscriptionTier.values) tier: _positioningFor(tier),
      },
    );
  }

  /// The fixed positioning for [tier].
  TierPositioning _positioningFor(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.basic:
        return TierPositioning(
          tier: tier,
          targetCustomer:
              'A solo operator running the shop alone, moving off '
              'pen-and-paper records.',
          // Req 18.2: Basic is the pen-and-paper replacement for a solo operator.
          valueNarrative:
              'The pen-and-paper replacement for a solo operator: create and '
              'find bills and cover the daily essentials with no learning '
              'curve, on every plan.',
          upgradeTrigger:
              'The owner takes on the first one or two staff and needs faster, '
              'repeatable workflows than manual entry can keep up with.',
          // Req 18.3: reference the Requirement 1 coverage target (Basic 30–40%).
          coverageTarget: tier.band,
          // Req 18.4: Basic is anchored by Billing_Core, which always lives at
          // Basic (Req 5); the rest is everyday standard capability.
          categoryAnchors: const [
            GatingCategory.billingCore,
            GatingCategory.standard,
          ],
        );
      case SubscriptionTier.pro:
        return TierPositioning(
          tier: tier,
          targetCustomer:
              'A growing shop with 1 to 5 staff that needs day-to-day '
              'efficiency tools.',
          // Req 18.2: Pro is the efficiency tier for a shop with 1 to 5 staff.
          valueNarrative:
              'The efficiency tier for a shop with 1 to 5 staff: unlocks the '
              'single most essential vertical workflow plus the everyday tools '
              'that speed up a busy counter.',
          upgradeTrigger:
              'The business starts needing reporting, returns, and multi-step '
              'workflows to understand and control a larger operation.',
          // Req 18.3: reference the Requirement 1 coverage target (Pro 55–65%).
          coverageTarget: tier.band,
          // Req 18.4: Pro is anchored by standard efficiency capabilities; the
          // gated analytics, compliance, and enterprise categories stay higher.
          categoryAnchors: const [GatingCategory.standard],
        );
      case SubscriptionTier.premium:
        return TierPositioning(
          tier: tier,
          targetCustomer:
              'An established business that needs reporting, returns, and '
              'multi-workflow depth.',
          // Req 18.2: Premium is the reporting and multi-workflow tier for an
          // established business.
          valueNarrative:
              'The reporting and multi-workflow tier for an established '
              'business: adds analytics, exports, and compliance and seasonal '
              'depth on top of the efficiency tools.',
          upgradeTrigger:
              'The business expands to multiple locations or high-volume, '
              'regulated, or B2B operations that need franchise-grade controls.',
          // Req 18.3: reference the Requirement 1 coverage target (Premium 75–85%).
          coverageTarget: tier.band,
          // Req 18.4: Premium is anchored by analytics/export (Req 9) and
          // compliance/seasonal (Req 11) capabilities.
          categoryAnchors: const [
            GatingCategory.analyticsExport,
            GatingCategory.complianceSeasonal,
          ],
        );
      case SubscriptionTier.enterprise:
        return TierPositioning(
          tier: tier,
          targetCustomer:
              'A multi-location, high-volume, regulated, or franchise-ready '
              'business.',
          // Req 18.2: Enterprise is the multi-location, regulated, and
          // franchise-ready tier.
          valueNarrative:
              'The multi-location, regulated, and franchise-ready tier: '
              'complete capability coverage with bulk, B2B, and financial-risk '
              'controls.',
          upgradeTrigger:
              'Operating across multiple locations or under regulatory and '
              'financial-risk requirements that demand bulk, B2B, and '
              'credit-risk controls.',
          // Req 18.3: reference the Requirement 1 coverage target (Enterprise 100%).
          coverageTarget: tier.band,
          // Req 18.4: Enterprise is anchored by the bulk/B2B/financial-risk
          // capabilities reserved for it (Req 10).
          categoryAnchors: const [GatingCategory.enterpriseOnly],
        );
    }
  }
}
