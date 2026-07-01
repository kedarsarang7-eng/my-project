// ============================================================================
// OVERVIEW PANEL
// ============================================================================
// "Today's Overview" panel with 4 KPI cards:
// - Total Patients (with % change)
// - Today's Appointments (with completed count)
// - Staff On Duty (total / on duty)
// - Total Revenue Today (with % change)
// ============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/futuristic_colors.dart';
import '../models/clinic_dashboard_models.dart';

class OverviewPanel extends StatelessWidget {
  final DashboardOverview data;

  const OverviewPanel({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Overview",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: FuturisticColors.textPrimary,
              ),
            ),
            Text(
              _formatCurrentDate(),
              style: TextStyle(
                fontSize: 14,
                color: FuturisticColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // KPI Cards Row
        Row(
          children: [
            // Total Patients
            Expanded(
              child: _KpiCard(
                icon: Icons.people_outline,
                iconColor: FuturisticColors.primary,
                iconBgColor: FuturisticColors.primary.withValues(alpha: 0.1),
                title: 'Total Patients',
                value: data.totalPatients.count.toString(),
                changePercent: data.totalPatients.changePercent,
                isPositive: data.totalPatients.isPositive,
                subtitle: null,
              ),
            ),
            const SizedBox(width: 16),

            // Today's Appointments
            Expanded(
              child: _KpiCard(
                icon: Icons.calendar_today_outlined,
                iconColor: const Color(0xFF9C27B0), // Purple
                iconBgColor: const Color(0xFF9C27B0).withValues(alpha: 0.1),
                title: "Today's Appointments",
                value: data.appointmentsToday.total.toString(),
                changePercent: data.appointmentsToday.completionRate,
                isPositive: true,
                subtitle: '${data.appointmentsToday.completed} Completed',
              ),
            ),
            const SizedBox(width: 16),

            // Staff On Duty
            Expanded(
              child: _KpiCard(
                icon: Icons.person_outline,
                iconColor: const Color(0xFF00ACC1), // Cyan
                iconBgColor: const Color(0xFF00ACC1).withValues(alpha: 0.1),
                title: 'Staff On Duty',
                value: '${data.staffOnDuty.onDuty}/${data.staffOnDuty.total}',
                changePercent: data.staffOnDuty.onDutyPercent,
                isPositive: true,
                subtitle: null,
              ),
            ),
            const SizedBox(width: 16),

            // Total Revenue Today
            Expanded(
              child: _KpiCard(
                icon: Icons.attach_money,
                iconColor: const Color(0xFF2E7D32), // Green
                iconBgColor: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                title: 'Total Revenue Today',
                value: data.revenueToday.formattedAmount,
                changePercent: data.revenueToday.changePercent,
                isPositive: data.revenueToday.isPositive,
                subtitle: null,
                isCurrency: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String value;
  final double changePercent;
  final bool isPositive;
  final String? subtitle;
  final bool isCurrency;

  const _KpiCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.value,
    required this.changePercent,
    required this.isPositive,
    this.subtitle,
    this.isCurrency = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: FuturisticColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),

          // Value
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: isCurrency ? 22 : 28,
                  fontWeight: FontWeight.bold,
                  color: FuturisticColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              if (changePercent > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? FuturisticColors.success.withValues(alpha: 0.1)
                        : FuturisticColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 10,
                        color: isPositive ? FuturisticColors.success : FuturisticColors.error,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${changePercent.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPositive ? FuturisticColors.success : FuturisticColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          // Subtitle (if any)
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: FuturisticColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
