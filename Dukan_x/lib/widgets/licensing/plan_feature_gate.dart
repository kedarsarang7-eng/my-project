import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/licensing/feature_plan_matrix.dart';
import '../../core/licensing/license_feature_access.dart';
import '../../core/licensing/plan_tier.dart';
import '../../providers/license_snapshot_provider.dart';

/// Wraps [child] when the subscription allows it; otherwise shows [locked] or a default locked surface.
///
/// Prefer [sidebarItemId] to align with [FeaturePlanMatrix] + backend `feature_flags`.
/// Use [minimumPlan] when gating a screen that is not in the sidebar matrix.
class PlanFeatureGate extends ConsumerWidget {
  final String? sidebarItemId;
  final String? minimumPlan;
  final Widget child;
  final Widget? locked;

  const PlanFeatureGate({
    super.key,
    this.sidebarItemId,
    this.minimumPlan,
    required this.child,
    this.locked,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(licenseFeatureAccessProvider);

    if (_unlocked(access)) {
      return child;
    }

    final req = requiredPlanLabel;
    return locked ??
        _DefaultLockedCard(
          requiredPlan: req,
        );
  }

  bool _unlocked(LicenseFeatureAccess access) {
    if (sidebarItemId != null) {
      return access.isSidebarItemUnlocked(sidebarItemId!);
    }
    final min = minimumPlan;
    if (min == null || min.isEmpty) return true;
    return planMeetsOrExceeds(access.planTier, min);
  }

  String get requiredPlanLabel {
    if (minimumPlan != null && minimumPlan!.isNotEmpty) {
      return minimumPlan!;
    }
    if (sidebarItemId != null) {
      return FeaturePlanMatrix.minPlanForSidebarItem(sidebarItemId!) ?? 'pro';
    }
    return 'pro';
  }
}

class _DefaultLockedCard extends StatelessWidget {
  final String requiredPlan;

  const _DefaultLockedCard({required this.requiredPlan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: theme.disabledColor),
            const SizedBox(height: 12),
            Text(
              'Upgrade required',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'This area needs at least the "$requiredPlan" plan (or enablement from your administrator).',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
