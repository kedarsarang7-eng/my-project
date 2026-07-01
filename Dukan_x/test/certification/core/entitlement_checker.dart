/// Subscription/license entitlement checker.
///
/// Pure function: a gated feature is accessible if and only if the active
/// subscription's entitlement set contains it AND the subscription is active
/// AND the license is activated; otherwise blocked with a denial indication.
///
/// Covers license activation and upgrade/downgrade gating (Req 5.4).
library;

/// Represents an active subscription with its entitlement set.
class Subscription {
  /// Unique subscription identifier.
  final String id;

  /// Set of feature identifiers the subscription grants access to.
  final Set<String> entitlements;

  /// Whether the subscription is currently active (not expired/cancelled).
  final bool isActive;

  /// Whether the license has been activated on this device/instance.
  final bool licenseActivated;

  const Subscription({
    required this.id,
    required this.entitlements,
    required this.isActive,
    required this.licenseActivated,
  });
}

/// The binary access decision for a gated feature.
enum AccessResult { accessible, blocked }

/// The outcome of an entitlement check, including denial reason when blocked.
class EntitlementDecision {
  /// Whether access is granted or denied.
  final AccessResult result;

  /// Non-null when [result] is [AccessResult.blocked]; describes why access
  /// was denied.
  final String? denialReason;

  const EntitlementDecision._({required this.result, this.denialReason});

  /// Factory for an accessible decision.
  const factory EntitlementDecision.accessible() = _AccessibleDecision;

  /// Factory for a blocked decision with a denial reason.
  factory EntitlementDecision.blocked(String reason) =>
      EntitlementDecision._(result: AccessResult.blocked, denialReason: reason);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntitlementDecision &&
          result == other.result &&
          denialReason == other.denialReason;

  @override
  int get hashCode => Object.hash(result, denialReason);

  @override
  String toString() =>
      'EntitlementDecision(result: $result, denialReason: $denialReason)';
}

class _AccessibleDecision extends EntitlementDecision {
  const _AccessibleDecision()
    : super._(result: AccessResult.accessible, denialReason: null);
}

/// Pure entitlement checker with no I/O.
///
/// Decision logic:
/// 1. Subscription must be active → otherwise blocked (inactive subscription).
/// 2. License must be activated → otherwise blocked (license not activated).
/// 3. Feature must be in the entitlement set → otherwise blocked (feature not
///    entitled under current plan).
///
/// This covers:
/// - License activation gating (step 2)
/// - Upgrade gating: feature not in current tier's entitlements (step 3)
/// - Downgrade gating: feature removed after downgrade (step 3)
class EntitlementChecker {
  const EntitlementChecker();

  /// Pure decision: feature is accessible iff subscription is active,
  /// license is activated, and entitlements contains the feature.
  /// Otherwise blocked with a denial indication.
  EntitlementDecision check(Subscription subscription, String feature) {
    if (!subscription.isActive) {
      return EntitlementDecision.blocked(
        'Subscription "${subscription.id}" is not active',
      );
    }

    if (!subscription.licenseActivated) {
      return EntitlementDecision.blocked(
        'License for subscription "${subscription.id}" is not activated',
      );
    }

    if (!subscription.entitlements.contains(feature)) {
      return EntitlementDecision.blocked(
        'Feature "$feature" is not entitled under subscription "${subscription.id}"',
      );
    }

    return const EntitlementDecision.accessible();
  }
}
