import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../models/business_type.dart';
import '../../../../providers/app_state_providers.dart';
import '../providers/dashboard_v2_providers.dart';

class DashboardTopBar extends ConsumerWidget {
  const DashboardTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessType = ref.watch(businessTypeProvider).type;
    final notifCount = ref.watch(dashboardV2NotificationCountProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        border: Border(
          bottom: BorderSide(
            color: FuturisticColors.border,
          ),
        ),
      ),
      child: Row(
        children: [
          // Business icon + title
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: FuturisticColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              businessType.icon,
              color: FuturisticColors.onSurface,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                businessType.displayName,
                style: TextStyle(
                  color: FuturisticColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  decoration: TextDecoration.none,
                ),
              ),
              Text(
                'Dashboard Overview',
                style: TextStyle(
                  color: FuturisticColors.textSecondary.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Search
          Container(
            width: 260,
            height: 38,
            decoration: BoxDecoration(
              color: FuturisticColors.background.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FuturisticColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.search_rounded,
                    color: FuturisticColors.textSecondary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Search invoices, customers...',
                    style: TextStyle(
                      color: FuturisticColors.textSecondary.withValues(alpha: 0.5),
                      fontSize: 13,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: FuturisticColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '⌘K',
                    style: TextStyle(
                      color: FuturisticColors.textSecondary.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Notification bell
          Stack(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_outlined),
                color: FuturisticColors.textSecondary,
                iconSize: 22,
                tooltip: 'Notifications',
              ),
              notifCount.when(
                data: (count) => count > 0
                    ? Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: FuturisticColors.error,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: FuturisticColors.surface, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              count > 9 ? '9+' : count.toString(),
                              style: TextStyle(
                                color: FuturisticColors.onSurface,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),

          const SizedBox(width: 8),

          // Period selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: FuturisticColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: FuturisticColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_rounded,
                    color: FuturisticColors.primary, size: 14),
                const SizedBox(width: 6),
                const Text(
                  'This Month',
                  style: TextStyle(
                    color: FuturisticColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: FuturisticColors.primary, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
