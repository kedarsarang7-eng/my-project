// ============================================================================
// Trial Banner Widget — Color-coded countdown banner
// ============================================================================
// Shows remaining trial days on Dashboard:
//   Green: > 7 days left
//   Yellow: 3–7 days left
//   Red: < 3 days left
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../providers/trial_subscription_provider.dart';
import '../../../../models/trial_subscription_state.dart';

class TrialBannerWidget extends ConsumerWidget {
  const TrialBannerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trialState = ref.watch(trialSubscriptionProvider);

    // Don't show banner if not in trial or no state
    if (trialState == null || !trialState.isInTrial) {
      return const SizedBox.shrink();
    }

    final days = trialState.daysRemaining ?? 0;
    final bannerColor = trialState.bannerColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: _getGradient(bannerColor),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _getShadowColor(bannerColor),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(_getIcon(bannerColor), color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getTitle(days),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getSubtitle(days),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (days <= 7)
            TextButton(
              onPressed: () {
                context.push('/upgrade');
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Upgrade',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  LinearGradient _getGradient(TrialBannerColor color) {
    switch (color) {
      case TrialBannerColor.green:
        return const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
        );
      case TrialBannerColor.yellow:
        return const LinearGradient(
          colors: [Color(0xFFF57F17), Color(0xFFFFA726)],
        );
      case TrialBannerColor.red:
        return const LinearGradient(
          colors: [Color(0xFFC62828), Color(0xFFEF5350)],
        );
      case TrialBannerColor.none:
        return const LinearGradient(
          colors: [Color(0xFF424242), Color(0xFF616161)],
        );
    }
  }

  Color _getShadowColor(TrialBannerColor color) {
    switch (color) {
      case TrialBannerColor.green:
        return const Color(0xFF4CAF50).withValues(alpha: 0.3);
      case TrialBannerColor.yellow:
        return const Color(0xFFFFA726).withValues(alpha: 0.3);
      case TrialBannerColor.red:
        return const Color(0xFFEF5350).withValues(alpha: 0.3);
      case TrialBannerColor.none:
        return Colors.transparent;
    }
  }

  IconData _getIcon(TrialBannerColor color) {
    switch (color) {
      case TrialBannerColor.green:
        return Icons.check_circle_outline;
      case TrialBannerColor.yellow:
        return Icons.access_time;
      case TrialBannerColor.red:
        return Icons.warning_amber_rounded;
      case TrialBannerColor.none:
        return Icons.info_outline;
    }
  }

  String _getTitle(int days) {
    if (days > 7) return 'Free Trial — $days days remaining';
    if (days > 1) return 'Trial ending soon — $days days left!';
    if (days == 1) return 'Last day of your trial!';
    return 'Trial expires today!';
  }

  String _getSubtitle(int days) {
    if (days > 7) return 'Explore all features during your trial period.';
    if (days > 3) return 'Upgrade now to avoid losing access.';
    return 'Upgrade immediately to keep all your data and features.';
  }
}
