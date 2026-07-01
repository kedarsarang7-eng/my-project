import 'feature_plan_matrix.dart';
import 'license_snapshot.dart';
import 'plan_tier.dart';

/// Plan-based access for sidebar routes and [PlanFeatureGate].
class LicenseFeatureAccess {
  final LicenseSnapshot snapshot;

  const LicenseFeatureAccess(this.snapshot);

  /// Treat everything as unlocked (loading / error fallback — avoids blocking UX).
  factory LicenseFeatureAccess.unrestricted() {
    return LicenseFeatureAccess(
      LicenseSnapshot(planTier: 'enterprise', featureFlags: {}),
    );
  }

  factory LicenseFeatureAccess.fromSnapshot(LicenseSnapshot s) {
    return LicenseFeatureAccess(s);
  }

  /// Whether the user may open this sidebar destination (not locked).
  bool isSidebarItemUnlocked(String itemId) {
    if (snapshot.explicitUnlock(itemId)) return true;

    final minPlan = FeaturePlanMatrix.minPlanForSidebarItem(itemId);
    if (minPlan == null) return true;

    return planMeetsOrExceeds(snapshot.planTier, minPlan);
  }

  String get planTier => snapshot.planTier;
}
