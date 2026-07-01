// ============================================================================
// Permission Provider — Flutter equivalent of usePermission(feature)
// ============================================================================
// Reads from LicenseContext + UserContext to determine feature access.
// Returns: allowed, reason, upgradeTier.
// HIDES (not disables) UI elements user cannot access.
// Shows locked state with upgrade prompt for higher-plan features.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../guards/plan_tier_guard.dart';

/// Result of a permission check
class PermissionResult {
  final bool allowed;
  final String? reason;
  final PlanTier? upgradeTo;
  final bool isLoading;

  const PermissionResult({
    required this.allowed,
    this.reason,
    this.upgradeTo,
    this.isLoading = false,
  });

  const PermissionResult.loading()
      : allowed = false,
        reason = null,
        upgradeTo = null,
        isLoading = true;

  const PermissionResult.denied(this.reason, {this.upgradeTo})
      : allowed = false,
        isLoading = false;

  const PermissionResult.granted()
      : allowed = true,
        reason = null,
        upgradeTo = null,
        isLoading = false;
}

/// Permission check provider — checks BOTH role AND plan for a feature.
/// Usage: ref.watch(permissionProvider('advanced_reports'))
final permissionProvider =
    FutureProvider.family<PermissionResult, String>((ref, feature) async {
  final currentTier = await ref.watch(planTierProvider.future);

  // Get required tier for feature
  final requiredTier = PlanTierFeatureFlags.getRequiredTier(feature);
  if (requiredTier == null) {
    // Unknown feature = locked (fail-closed)
    return const PermissionResult.denied('Feature not available');
  }

  // Check plan
  if (!currentTier.isAtLeast(requiredTier)) {
    return PermissionResult.denied(
      'Upgrade to ${requiredTier.displayName} to access this feature.',
      upgradeTo: requiredTier,
    );
  }

  // Owner/Admin always have full access within their plan
  // For other roles, we trust backend enforcement
  return const PermissionResult.granted();
});

/// Widget that HIDES children when feature is not permitted.
/// Shows upgrade prompt for features in higher plans.
class PermissionGate extends ConsumerWidget {
  final String feature;
  final Widget child;
  final Widget? lockedWidget;

  const PermissionGate({
    super.key,
    required this.feature,
    required this.child,
    this.lockedWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permAsync = ref.watch(permissionProvider(feature));

    return permAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(), // Fail-closed
      data: (perm) {
        if (perm.allowed) return child;

        // Feature requires higher plan — show locked state
        if (perm.upgradeTo != null) {
          return lockedWidget ?? _buildLockedCard(context, perm);
        }

        // Role insufficient or unknown — hide completely
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLockedCard(BuildContext context, PermissionResult perm) {
    return Card(
      margin: const EdgeInsets.all(8),
      color: Colors.grey.shade50,
      child: InkWell(
        onTap: () => _showUpgradeDialog(context, perm),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.amber.shade700, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${perm.upgradeTo?.displayName ?? "Higher"} Plan Feature',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      perm.reason ?? 'Upgrade to unlock',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context, PermissionResult perm) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(perm.upgradeTo?.icon ?? Icons.star, color: Colors.amber),
            const SizedBox(width: 8),
            Text('Upgrade to ${perm.upgradeTo?.displayName ?? "Higher Plan"}'),
          ],
        ),
        content: Text(
          '${perm.reason}\n\n'
          'Contact your administrator to upgrade your plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Inline permission check — use in conditional rendering.
/// Returns true if feature is available for current plan.
/// Does NOT check role (role checked server-side).
bool canAccessFeature(PlanTier currentTier, String feature) {
  return PlanTierFeatureFlags.isFeatureAvailable(feature, currentTier);
}
