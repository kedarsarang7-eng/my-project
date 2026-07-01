import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/theme/futuristic_colors.dart';
import '../../models/pharmacy_dashboard_models.dart';
import '../../providers/pharmacy_dashboard_providers.dart';

class PharmacyRecentActivityFeed extends ConsumerWidget {
  const PharmacyRecentActivityFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(pharmacyRecentActivityProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: activityAsync.when(
              data: (data) => _buildActivityList(context, data),
              loading: () => _buildLoadingList(),
              error: (_, _) => _buildErrorList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: FuturisticColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.local_activity_rounded,
            color: FuturisticColors.info,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: FuturisticColors.textPrimary,
                ),
              ),
              Text(
                'Latest system events',
                style: TextStyle(
                  fontSize: 12,
                  color: FuturisticColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: FuturisticColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Live',
            style: TextStyle(
              fontSize: 10,
              color: FuturisticColors.info,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityList(BuildContext context, RecentActivityData data) {
    if (data.isEmpty || data.activities.isEmpty) {
      return _buildEmptyList();
    }

    return ListView.builder(
      itemCount: data.activities.length,
      itemBuilder: (context, index) {
        final activity = data.activities[index];
        return _ActivityItem(activity: activity);
      },
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon skeleton
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 12),
              
              // Content skeleton
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 150,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 100,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorList() {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: FuturisticColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to load activity feed',
            style: TextStyle(
              color: FuturisticColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyList() {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 48,
            color: FuturisticColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No recent activity',
            style: TextStyle(
              color: FuturisticColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Activity Item Widget ─────────────────────────────────────────────────────

class _ActivityItem extends StatelessWidget {
  final ActivityItem activity;

  const _ActivityItem({
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    final activityConfig = _getActivityConfig(activity.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity Icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: activityConfig.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              activityConfig.icon,
              color: activityConfig.color,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          
          // Activity Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.description,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: FuturisticColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _formatTimestamp(activity.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: FuturisticColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: TextStyle(
                        fontSize: 12,
                        color: FuturisticColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      activity.actor,
                      style: TextStyle(
                        fontSize: 12,
                        color: FuturisticColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ActivityConfig _getActivityConfig(String type) {
    switch (type.toLowerCase()) {
      case 'sale':
        return ActivityConfig(
          icon: Icons.receipt_long_rounded,
          color: FuturisticColors.success,
        );
      case 'prescription':
        return ActivityConfig(
          icon: Icons.medication_rounded,
          color: FuturisticColors.primary,
        );
      case 'stock_update':
        return ActivityConfig(
          icon: Icons.inventory_2_rounded,
          color: FuturisticColors.warning,
        );
      case 'new_patient':
        return ActivityConfig(
          icon: Icons.person_add_rounded,
          color: FuturisticColors.info,
        );
      case 'expiry_alert':
        return ActivityConfig(
          icon: Icons.warning_amber_rounded,
          color: FuturisticColors.error,
        );
      default:
        return ActivityConfig(
          icon: Icons.info_outline_rounded,
          color: FuturisticColors.textSecondary,
        );
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        // Format as date for older activities
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return timestamp; // Return original if parsing fails
    }
  }
}

// ── Activity Configuration ─────────────────────────────────────────────────────

class ActivityConfig {
  final IconData icon;
  final Color color;

  const ActivityConfig({
    required this.icon,
    required this.color,
  });
}
