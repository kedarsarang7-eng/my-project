// ============================================================================
// Trial Banner — Displays Trial Status and Upgrade CTA
// ============================================================================
// Shows trial countdown with color-coded urgency levels.
// Features:
//   - Auto-hides when not in trial
//   - Color changes based on days remaining
//   - Tap to upgrade
//   - Dismissible (session only)
//
// Usage: Place in Scaffold body or AppBar bottom
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/licensing/plan_context_cache.dart';
import '../providers/license_snapshot_provider.dart';

class TrialBanner extends ConsumerStatefulWidget {
  final VoidCallback? onUpgradeTap;
  final bool dismissible;

  const TrialBanner({
    super.key,
    this.onUpgradeTap,
    this.dismissible = true,
  });

  @override
  ConsumerState<TrialBanner> createState() => _TrialBannerState();
}

class _TrialBannerState extends ConsumerState<TrialBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    // Check both cache and provider
    final cacheStatus = planContextCache.getTrialStatus();
    final licenseAsync = ref.watch(licenseSnapshotProvider);

    // Use cached status if provider is loading
    TrialStatus? status;
    licenseAsync.when(
      data: (snapshot) {
        status = TrialStatus(
          isInTrial: snapshot.planStatus == 'trial',
          daysRemaining: snapshot.daysRemaining ?? 0,
          trialEndDate: snapshot.trialEndDate,
          planStatus: snapshot.planStatus ?? 'unknown',
        );
      },
      loading: () {
        status = cacheStatus;
      },
      error: (_, _) {
        status = cacheStatus;
      },
    );

    if (status == null || !status!.isInTrial || _dismissed) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = _getColorScheme(status!.urgency, theme);

    return Material(
      color: colorScheme.background,
      child: InkWell(
        onTap: widget.onUpgradeTap ?? () => _showUpgradeDialog(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colorScheme.border, width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.access_time,
                color: colorScheme.icon,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      status!.displayMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (status!.daysRemaining <= 3)
                      Text(
                        'Upgrade now to keep Premium features',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.text.withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.dismissible)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: colorScheme.icon,
                  onPressed: () => setState(() => _dismissed = true),
                  tooltip: 'Dismiss',
                ),
              ElevatedButton(
                onPressed: widget.onUpgradeTap ?? () => _showUpgradeDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.button,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                child: const Text('UPGRADE'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _ColorScheme _getColorScheme(TrialUrgency urgency, ThemeData theme) {
    switch (urgency) {
      case TrialUrgency.critical:
        return _ColorScheme(
          background: Colors.red.shade50,
          border: Colors.red.shade200,
          icon: Colors.red.shade700,
          text: Colors.red.shade900,
          button: Colors.red.shade600,
        );
      case TrialUrgency.high:
        return _ColorScheme(
          background: Colors.orange.shade50,
          border: Colors.orange.shade200,
          icon: Colors.orange.shade700,
          text: Colors.orange.shade900,
          button: Colors.orange.shade600,
        );
      case TrialUrgency.medium:
        return _ColorScheme(
          background: Colors.amber.shade50,
          border: Colors.amber.shade200,
          icon: Colors.amber.shade700,
          text: Colors.amber.shade900,
          button: Colors.amber.shade600,
        );
      case TrialUrgency.low:
        return _ColorScheme(
          background: Colors.blue.shade50,
          border: Colors.blue.shade200,
          icon: Colors.blue.shade700,
          text: Colors.blue.shade900,
          button: Colors.blue.shade600,
        );
      default:
        return _ColorScheme(
          background: theme.colorScheme.surface,
          border: theme.dividerColor,
          icon: theme.iconTheme.color ?? Colors.grey,
          text: theme.textTheme.bodyMedium?.color ?? Colors.black,
          button: theme.colorScheme.primary,
        );
    }
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const TrialUpgradeDialog(),
    );
  }
}

class _ColorScheme {
  final Color background;
  final Color border;
  final Color icon;
  final Color text;
  final Color button;

  _ColorScheme({
    required this.background,
    required this.border,
    required this.icon,
    required this.text,
    required this.button,
  });
}

/// Upgrade dialog shown when trial is about to expire
class TrialUpgradeDialog extends StatelessWidget {
  const TrialUpgradeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Upgrade Your Plan'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your free trial is ending soon. Upgrade now to:',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _buildFeatureRow(context, 'Unlimited products'),
          _buildFeatureRow(context, 'Unlimited invoices'),
          _buildFeatureRow(context, 'Multi-user access'),
          _buildFeatureRow(context, 'Advanced reports'),
          _buildFeatureRow(context, 'Priority support'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.savings, color: Colors.green.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Save 20% with yearly billing',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Maybe Later'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            // Navigate to upgrade screen
            // context.push('/settings/billing/upgrade');
          },
          child: const Text('View Plans'),
        ),
      ],
    );
  }

  Widget _buildFeatureRow(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
          const SizedBox(width: 8),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Extension to add trial info to LicenseSnapshot
extension LicenseSnapshotTrial on Object? {
  String? get planStatus => null;
  int? get daysRemaining => null;
  DateTime? get trialEndDate => null;
}
