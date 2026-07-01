// ============================================================================
// Plan Status Banner — Persistent plan + expiry indicator
// ============================================================================
// Shows current plan tier and days until expiry. Changes color based on
// urgency: green (>30 days), amber (7-30 days), red (<7 days).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../guards/plan_tier_guard.dart';
import '../services/license_service.dart';
import '../core/di/service_locator.dart';

/// Provider for license expiry info
final licenseExpiryProvider = FutureProvider<_ExpiryInfo?>((ref) async {
  final licenseService = sl<LicenseService>();
  final info = await licenseService.getLicenseInfo();
  if (info == null) return null;

  final daysUntilExpiry = info['daysUntilExpiry'] as int? ?? 0;
  final planType = info['planType'] as String? ?? 'basic';

  return _ExpiryInfo(
    daysUntilExpiry: daysUntilExpiry,
    planTier: PlanTier.fromString(planType),
  );
});

class _ExpiryInfo {
  final int daysUntilExpiry;
  final PlanTier planTier;

  _ExpiryInfo({required this.daysUntilExpiry, required this.planTier});
}

/// Persistent banner showing current plan + expiry countdown
class PlanStatusBanner extends ConsumerWidget {
  const PlanStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiryAsync = ref.watch(licenseExpiryProvider);

    return expiryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (info) {
        if (info == null) return const SizedBox.shrink();

        // Don't show banner if >30 days remaining
        if (info.daysUntilExpiry > 30) return const SizedBox.shrink();

        final color = _getUrgencyColor(info.daysUntilExpiry);
        final message = _getMessage(info);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.7)],
            ),
          ),
          child: Row(
            children: [
              Icon(
                info.daysUntilExpiry <= 3
                    ? Icons.warning_amber_rounded
                    : Icons.info_outline,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(info.planTier.icon, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                info.planTier.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getUrgencyColor(int days) {
    if (days <= 0) return Colors.red.shade700;
    if (days <= 7) return Colors.red.shade600;
    if (days <= 14) return Colors.orange.shade700;
    return Colors.amber.shade700;
  }

  String _getMessage(_ExpiryInfo info) {
    if (info.daysUntilExpiry <= 0) {
      return 'License expired! Renew now to continue.';
    }
    if (info.daysUntilExpiry == 1) {
      return 'License expires tomorrow!';
    }
    return 'License expires in ${info.daysUntilExpiry} days.';
  }
}
