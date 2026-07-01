/// Subscription Tier model for the Tiering_System.
///
/// Defines the four ordered subscription plans (Basic → Pro → Premium →
/// Enterprise) and the per-tier Tier_Coverage band that the plan mapping must
/// satisfy. This is the foundational, pure-Dart model for the
/// `subscription-plan-tiers` feature; it has no dependency on the capability
/// registry and is safe to use from any layer.
library;

/// The four ordered subscription plans.
///
/// `index` encodes the order so that
/// `basic(0) < pro(1) < premium(2) < enterprise(3)`. Higher tiers are always
/// supersets of lower tiers (see Plan_Mapping), so comparing tiers by `index`
/// is sufficient to reason about ordering.
enum SubscriptionTier {
  basic,
  pro,
  premium,
  enterprise;

  /// True when this tier is strictly lower than [other].
  bool operator <(SubscriptionTier other) => index < other.index;

  /// True when this tier is lower than or equal to [other].
  bool operator <=(SubscriptionTier other) => index <= other.index;

  /// True when this tier is strictly higher than [other].
  bool operator >(SubscriptionTier other) => index > other.index;

  /// True when this tier is higher than or equal to [other].
  bool operator >=(SubscriptionTier other) => index >= other.index;

  /// The Tier_Coverage band as an inclusive `[minPercent, maxPercent]`.
  ///
  /// Basic 30–40%, Pro 55–65%, Premium 75–85%, Enterprise exactly 100%.
  CoverageBand get band => switch (this) {
    SubscriptionTier.basic => const CoverageBand(30, 40),
    SubscriptionTier.pro => const CoverageBand(55, 65),
    SubscriptionTier.premium => const CoverageBand(75, 85),
    SubscriptionTier.enterprise => const CoverageBand(100, 100),
  };
}

/// An inclusive Tier_Coverage band expressed as a percentage range.
///
/// A tier satisfies its band when its Tier_Coverage (percentage of the
/// Available_Capability_Count assigned to the tier) lies within
/// `[minPercent, maxPercent]` inclusive.
class CoverageBand {
  /// Inclusive lower bound of the band, as a percentage.
  final int minPercent;

  /// Inclusive upper bound of the band, as a percentage.
  final int maxPercent;

  const CoverageBand(this.minPercent, this.maxPercent);

  /// Whether the given [percent] falls inside this band (inclusive on both
  /// ends).
  bool contains(num percent) => percent >= minPercent && percent <= maxPercent;

  /// Integer tier sizes (capability counts) whose Tier_Coverage lands inside
  /// this band for the given [availableCount].
  ///
  /// Returns an ascending list of counts `n` in `0..availableCount` for which
  /// `n / availableCount * 100` falls within `[minPercent, maxPercent]`. The
  /// list is empty when no integer size fits the band (an infeasible band) or
  /// when [availableCount] is zero.
  List<int> feasibleSizes(int availableCount) {
    if (availableCount <= 0) return const [];
    final sizes = <int>[];
    for (var n = 0; n <= availableCount; n++) {
      final coverage = n / availableCount * 100;
      if (contains(coverage)) sizes.add(n);
    }
    return sizes;
  }

  @override
  bool operator ==(Object other) =>
      other is CoverageBand &&
      other.minPercent == minPercent &&
      other.maxPercent == maxPercent;

  @override
  int get hashCode => Object.hash(minPercent, maxPercent);

  @override
  String toString() => 'CoverageBand($minPercent–$maxPercent%)';
}
