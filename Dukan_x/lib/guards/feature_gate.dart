// ============================================================================
// Feature Gate — Manifest-Driven Feature Gating (Plan Feature System v2)
// ============================================================================
// Widget and utility classes for gating UI based on the server's feature
// manifest. Unlike PlanTierGuard which uses hardcoded tier mappings, this
// uses the actual effectiveFeatures list from GET /tenant/config.
//
// The manifest is computed server-side as:
//   (PlanConfig.default ∩ allowedPerBusiness) ∪ manualOverrides.added \ removed
//
// Usage:
//   FeatureGate(
//     featureKey: 'api_access',
//     child: ApiSettingsWidget(),
//     fallback: UpgradePrompt(feature: 'api_access'),
//   )
//
//   if (ref.watch(featureEnabledProvider('multi_branch'))) { ... }
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/tenant_config_provider.dart';
import '../widgets/feature_locked_dialog.dart';
import 'plan_tier_guard.dart';

/// Feature Gate Widget — shows child only if feature is enabled in manifest
class FeatureGate extends ConsumerWidget {
  final String featureKey;
  final Widget child;
  final Widget? fallback;
  final bool showUpgradePrompt;

  const FeatureGate({
    super.key,
    required this.featureKey,
    required this.child,
    this.fallback,
    this.showUpgradePrompt = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(featureEnabledProvider(featureKey));
    final configState = ref.watch(tenantConfigProvider);

    if (configState.isLoading) return const _LoadingPlaceholder();
    if (isEnabled) return child;
    return fallback ?? _buildLockedState(context);
  }

  Widget _buildLockedState(BuildContext context) {
    if (!showUpgradePrompt) {
      return const SizedBox.shrink();
    }

    // Show locked indicator that opens upgrade dialog on tap
    return _LockedFeatureIndicator(
      featureKey: featureKey,
      onTap: () => _showUpgradeDialog(context),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    final requiredTier =
        PlanTierFeatureFlags.getRequiredTier(featureKey) ?? PlanTier.pro;
    showDialog(
      context: context,
      builder: (context) => FeatureLockedDialog(
        requiredTier: requiredTier,
      ),
    );
  }
}

/// Multi-feature gate — shows child only if ALL features are enabled
class AllFeaturesGate extends ConsumerWidget {
  final List<String> featureKeys;
  final Widget child;
  final Widget? fallback;

  const AllFeaturesGate({
    super.key,
    required this.featureKeys,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allEnabled = featureKeys.every(
      (key) => ref.watch(featureEnabledProvider(key)),
    );

    if (allEnabled) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// Any-feature gate — shows child if ANY feature is enabled
class AnyFeatureGate extends ConsumerWidget {
  final List<String> featureKeys;
  final Widget child;
  final Widget? fallback;

  const AnyFeatureGate({
    super.key,
    required this.featureKeys,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anyEnabled = featureKeys.any(
      (key) => ref.watch(featureEnabledProvider(key)),
    );

    if (anyEnabled) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// Badge showing feature tier requirement (for UI hints)
class FeatureTierBadge extends StatelessWidget {
  final String featureKey;
  final PlanTier? requiredTier;

  const FeatureTierBadge({
    super.key,
    required this.featureKey,
    this.requiredTier,
  });

  @override
  Widget build(BuildContext context) {
    final tier = requiredTier ?? _guessTier(featureKey);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _tierColor(tier).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _tierColor(tier)),
      ),
      child: Text(
        tier.displayName,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: _tierColor(tier),
        ),
      ),
    );
  }

  PlanTier _guessTier(String feature) {
    // Prefer authoritative lookup from PlanTierFeatureFlags.
    final mapped = PlanTierFeatureFlags.getRequiredTier(feature);
    if (mapped != null) return mapped;

    // Fallback tier hints for features not yet in the registry.
    // NOTE: audit_logs/cloud_backup/advanced_analytics are Premium+ per spec §6,§7.
    final enterpriseFeatures = {
      'api_access', 'multi_branch', 'centralized_inventory_sync',
      'financial_reconciliation_engine', 'hierarchical_role_control',
    };
    final premiumFeatures = {
      'advanced_role_permissions', 'vendor_po_automation', 'aging_reports',
      'audit_logs', 'audit_trail', 'cloud_backup', 'backup',
      'advanced_analytics', 'gst_reports', 'gstr1',
      'accounting_reports', 'income_statement', 'funds_flow',
    };
    final proFeatures = {
      'advanced_reports', 'barcode_tag_printing', 'stock_valuation',
      'analytics_hub', 'insights', 'margin_analysis', 'batch_tracking',
    };

    if (enterpriseFeatures.contains(feature)) return PlanTier.enterprise;
    if (premiumFeatures.contains(feature)) return PlanTier.premium;
    if (proFeatures.contains(feature)) return PlanTier.pro;
    return PlanTier.basic;
  }

  Color _tierColor(PlanTier tier) {
    switch (tier) {
      case PlanTier.basic:
        return Colors.grey;
      case PlanTier.pro:
        return Colors.blue;
      case PlanTier.premium:
        return Colors.orange;
      case PlanTier.enterprise:
        return Colors.purple;
    }
  }
}

/// Locked feature indicator widget
class _LockedFeatureIndicator extends StatelessWidget {
  final String featureKey;
  final VoidCallback onTap;

  const _LockedFeatureIndicator({
    required this.featureKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.grey.shade600, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatFeatureName(featureKey),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Upgrade to unlock this feature',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  String _formatFeatureName(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

/// Loading placeholder for when config is loading
class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

// ── Utility Extensions ─────────────────────────────────────────────────────

extension FeatureGateContext on BuildContext {
  /// Quick check if a feature is enabled (for use in callbacks)
  /// Note: For widgets, use FeatureGate or featureEnabledProvider instead
  Future<bool> isFeatureEnabled(String featureKey) async {
    // This is async and reads from provider - intended for button handlers
    final container = ProviderScope.containerOf(this, listen: false);
    return container.read(featureEnabledProvider(featureKey));
  }
}
