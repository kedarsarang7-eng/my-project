// ============================================================================
// PLAN TIER — Feature Gating Based on License Plan
// ============================================================================
// Provides plan-tier-based feature visibility checks.
//
// Usage:
//   PlanTierGuard(
//     requiredTier: PlanTier.premium,
//     child: AdvancedFeatureWidget(),
//   )
//
//   if (ref.watch(planTierProvider) == PlanTier.enterprise) { ... }
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/license_service.dart';
import '../core/di/service_locator.dart';
import '../widgets/feature_locked_dialog.dart';
import '../providers/license_snapshot_provider.dart';

/// Plan tier levels (ordered from lowest to highest)
enum PlanTier {
  basic,
  pro,
  premium,
  enterprise;

  /// Check if this tier is at least the given [required] tier
  bool isAtLeast(PlanTier required) {
    return index >= required.index;
  }

  /// Parse tier from string (case-insensitive)
  static PlanTier fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pro':
        return PlanTier.pro;
      case 'premium':
      case 'professional':
        return PlanTier.premium;
      case 'enterprise':
        return PlanTier.enterprise;
      case 'basic':
      default:
        return PlanTier.basic;
    }
  }

  /// Display name for UI
  String get displayName {
    switch (this) {
      case PlanTier.basic:
        return 'Basic';
      case PlanTier.pro:
        return 'Pro';
      case PlanTier.premium:
        return 'Premium';
      case PlanTier.enterprise:
        return 'Enterprise';
    }
  }

  /// Icon for UI
  IconData get icon {
    switch (this) {
      case PlanTier.basic:
        return Icons.star_border;
      case PlanTier.pro:
        return Icons.star_half;
      case PlanTier.premium:
        return Icons.star;
      case PlanTier.enterprise:
        return Icons.workspace_premium;
    }
  }
}

/// Provider for the current plan tier (reads from license snapshot)
final planTierProvider = FutureProvider<PlanTier>((ref) async {
  final snapshot = await ref.watch(licenseSnapshotProvider.future);
  return PlanTier.fromString(snapshot.planTier);
});

/// Feature flag utility — check if a feature is available for the current tier
class PlanTierFeatureFlags {
  /// Define which features belong to which tier.
  /// This is a stub — the exact features per tier will be defined later.
  static final Map<String, PlanTier> _featureTierMap = {
    // Basic tier features (available to all)
    'dashboard': PlanTier.basic,
    'general_settings': PlanTier.basic,
    'basic_user_roles': PlanTier.basic,
    'accounting_khata': PlanTier.basic,
    'basic_reporting': PlanTier.basic,
    'standard_pos': PlanTier.basic,
    'basic_inventory': PlanTier.basic,
    'customer_ledger': PlanTier.basic,
    'expense_tracker': PlanTier.basic,
    'basic_reorder_alerts': PlanTier.basic,

    // Pro tier features
    'advanced_reports': PlanTier.pro,
    'barcode_tag_printing': PlanTier.pro,
    'barcode_label_printing': PlanTier.pro,
    'stock_valuation': PlanTier.pro,
    'batch_tracking': PlanTier.pro,
    'analytics_hub': PlanTier.pro,
    'insights': PlanTier.pro,
    'margin_analysis': PlanTier.pro,
    'turnover_analysis': PlanTier.pro,
    'procurement_insights': PlanTier.pro,
    'product_performance': PlanTier.pro,
    'doctor_revenue': PlanTier.pro,
    'restaurant_owner_command': PlanTier.pro,

    // Premium tier features
    // NOTE: audit_logs, cloud_backup, advanced_analytics are Premium+, NOT Enterprise.
    // Spec §6: Cloud Backup = Premium+. §7: Audit Trail = Premium+. §8: GST Reports = Premium+.
    'advanced_role_permissions': PlanTier.premium,
    'vendor_po_automation': PlanTier.premium,
    'aging_reports': PlanTier.premium,
    'audit_logs': PlanTier.premium,
    'audit_trail': PlanTier.premium,
    'cloud_backup': PlanTier.premium,
    'backup': PlanTier.premium,
    'advanced_analytics': PlanTier.premium,
    'gst_reports': PlanTier.premium,
    'gstr1': PlanTier.premium,
    'accounting_reports': PlanTier.premium,
    'invoice_margin': PlanTier.premium,
    'income_statement': PlanTier.premium,
    'funds_flow': PlanTier.premium,
    'financial_position': PlanTier.premium,

    // Enterprise tier features
    // Spec §9: Multi-branch = Enterprise (no exceptions). §10: API Access = Enterprise.
    'multi_branch': PlanTier.enterprise,
    'branch_management': PlanTier.enterprise,
    'centralized_inventory_sync': PlanTier.enterprise,
    'centralized_inventory': PlanTier.enterprise,
    'api_access': PlanTier.enterprise,
    'financial_reconciliation_engine': PlanTier.enterprise,
    'hierarchical_role_control': PlanTier.enterprise,
    'role_management': PlanTier.enterprise,
    'online_orders': PlanTier.enterprise,
  };

  /// Check if a feature is available for the given tier
  static bool isFeatureAvailable(String featureKey, PlanTier currentTier) {
    final requiredTier = _featureTierMap[featureKey];
    if (requiredTier == null) {
      return false; // Unknown features default to LOCKED (fail-closed)
    }
    return currentTier.isAtLeast(requiredTier);
  }

  /// Get the required tier for a feature
  static PlanTier? getRequiredTier(String featureKey) {
    return _featureTierMap[featureKey];
  }

  /// Get all features available for a given tier
  static List<String> getFeaturesForTier(PlanTier tier) {
    return _featureTierMap.entries
        .where((e) => tier.isAtLeast(e.value))
        .map((e) => e.key)
        .toList();
  }
}

/// Plan Tier Guard Widget — hides/shows UI based on plan tier
class PlanTierGuard extends ConsumerWidget {
  final PlanTier requiredTier;
  final Widget child;
  final Widget? fallback;

  const PlanTierGuard({
    super.key,
    required this.requiredTier,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tierAsync = ref.watch(planTierProvider);

    return tierAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => fallback ?? _buildUpgradePrompt(context, requiredTier), // Fail-CLOSED on error
      data: (currentTier) {
        if (currentTier.isAtLeast(requiredTier)) {
          return child;
        }
        return fallback ?? _buildUpgradePrompt(context, requiredTier);
      },
    );
  }

  static Widget _buildUpgradePrompt(
    BuildContext context,
    PlanTier requiredTier,
  ) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.amber[700]),
            const SizedBox(height: 12),
            Text(
              '${requiredTier.displayName} Feature',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This feature requires the ${requiredTier.displayName} plan or higher.\n'
              'Upgrade your plan to unlock this feature.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to upgrade / contact support screen
                showDialog(
                  context: context,
                  builder: (_) => FeatureLockedDialog(requiredTier: requiredTier),
                );
              },
              icon: const Icon(Icons.upgrade),
              label: Text('Upgrade to ${requiredTier.displayName}'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Feature Guard Widget — checks specific feature availability
class FeatureGuard extends ConsumerWidget {
  final String featureKey;
  final Widget child;
  final Widget? fallback;

  const FeatureGuard({
    super.key,
    required this.featureKey,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tierAsync = ref.watch(planTierProvider);

    return tierAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => fallback ?? const SizedBox.shrink(), // Fail-CLOSED on error
      data: (currentTier) {
        if (PlanTierFeatureFlags.isFeatureAvailable(featureKey, currentTier)) {
          return child;
        }

        final requiredTier = PlanTierFeatureFlags.getRequiredTier(featureKey);
        return fallback ??
            PlanTierGuard._buildUpgradePrompt(
              context,
              requiredTier ?? PlanTier.premium,
            );
      },
    );
  }
}
