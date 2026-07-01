// ============================================================================
// Computer Shop — Sidebar Configuration
// ============================================================================
// Add these items to your desktop sidebar configuration
// ============================================================================

import 'package:flutter/material.dart';

/// Computer Shop Sidebar Items
/// 
/// Add these to your sidebar configuration file:
/// e.g., lib/widgets/desktop/sidebar_configuration.dart
/// 
/// Example usage:
/// ```dart
/// if (businessType == BusinessType.computerShop) {
///   items.addAll(ComputerShopSidebarItems.getItems(context));
/// }
/// ```

class ComputerShopSidebarItems {
  static List<Map<String, dynamic>> getItems(BuildContext context) {
    return [
      {
        'id': 'computer_shop_header',
        'type': 'header',
        'title': 'COMPUTER SHOP',
      },
      {
        'id': 'computer_job_cards',
        'type': 'route',
        'title': 'Service Job Cards',
        'icon': Icons.build,
        'route': '/computer-shop/job-cards',
      },
      {
        'id': 'computer_create_job',
        'type': 'route',
        'title': 'Create New Job',
        'icon': Icons.add_circle,
        'route': '/computer-shop/create-job-card',
      },
      {
        'id': 'computer_warranty',
        'type': 'route',
        'title': 'Warranty Management',
        'icon': Icons.verified_user,
        'route': '/computer-shop/warranty',
      },
      {
        'id': 'computer_multi_unit',
        'type': 'route',
        'title': 'Multi-Unit Config',
        'icon': Icons.swap_horiz,
        'route': '/computer-shop/multi-unit',
        'permission': 'systemSettings', // Only for managers/admins
      },
    ];
  }
}

/// Computer Shop Quick Actions for Dashboard
class ComputerShopQuickActions {
  static List<Map<String, dynamic>> getActions(BuildContext context) {
    return [
      {
        'id': 'new_job_card',
        'title': 'New Service Job',
        'icon': Icons.build,
        'color': const Color(0xFF3B82F6),
        'route': '/computer-shop/create-job-card',
      },
      {
        'id': 'lookup_warranty',
        'title': 'Warranty Lookup',
        'icon': Icons.verified_user,
        'color': const Color(0xFF10B981),
        'route': '/computer-shop/warranty',
      },
      {
        'id': 'view_jobs',
        'title': 'Open Jobs',
        'icon': Icons.list,
        'color': const Color(0xFFF59E0B),
        'route': '/computer-shop/job-cards',
      },
    ];
  }
}

/// Computer Shop Dashboard Summary Widget
class ComputerShopDashboardSummary extends StatelessWidget {
  final int openJobs;
  final int completedToday;
  final int pendingWarranty;

  const ComputerShopDashboardSummary({
    super.key,
    required this.openJobs,
    required this.completedToday,
    required this.pendingWarranty,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.computer, color: const Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                const Text(
                  'Computer Shop Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    value: openJobs.toString(),
                    label: 'Open Jobs',
                    color: const Color(0xFFF59E0B),
                    icon: Icons.build,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    value: completedToday.toString(),
                    label: 'Completed Today',
                    color: const Color(0xFF10B981),
                    icon: Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    value: pendingWarranty.toString(),
                    label: 'Warranty Expiring',
                    color: const Color(0xFFEF4444),
                    icon: Icons.warning,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
