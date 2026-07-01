import 'package:flutter/material.dart';
import '../../models/business_order_models.dart';

/// Summary stats cards showing order counts and revenue.
class OrderStatsCards extends StatelessWidget {
  final OrderStats stats;

  const OrderStatsCards({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _StatCard(
            label: 'Total Orders',
            value: '${stats.totalOrders}',
            icon: Icons.receipt_long,
            color: Colors.blue,
          ),
          const SizedBox(width: 16),
          _StatCard(
            label: 'Pending',
            value: '${stats.pendingOrders}',
            icon: Icons.hourglass_empty,
            color: Colors.orange,
          ),
          const SizedBox(width: 16),
          _StatCard(
            label: 'Completed',
            value: '${stats.deliveredToday}',
            icon: Icons.check_circle,
            color: Colors.green,
          ),
          const SizedBox(width: 16),
          _StatCard(
            label: 'Revenue',
            value: '₹${stats.totalRevenue.toStringAsFixed(0)}',
            icon: Icons.currency_rupee,
            color: Colors.purple,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
