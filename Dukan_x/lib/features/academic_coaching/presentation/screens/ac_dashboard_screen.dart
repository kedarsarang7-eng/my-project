// ============================================================================
// ACADEMIC COACHING — DASHBOARD SCREEN
// ============================================================================
// Modern, professional UI with KPI cards, charts, and quick actions

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models/ac_models.dart';
import '../../data/repositories/ac_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

final acDashboardProvider = FutureProvider<AcDashboardStats>((ref) async {
  final repo = sl<AcRepository>(); // ApiClient
  return await repo.getDashboard();
});

class AcDashboardScreen extends ConsumerWidget {
  const AcDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(acDashboardProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(
          responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            dashboardAsync.when(
              loading: () => _buildSkeletonLoader(),
              error: (e, _) => _buildError(context, e),
              data: (stats) => _buildDashboard(context, stats),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    final isMobile = context.isMobile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Academic Dashboard',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('EEEE, d MMMM yyyy').format(now),
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _buildActionButton(
              context,
              icon: Icons.person_add_outlined,
              label: isMobile ? 'Student' : 'New Student',
              color: const Color(0xFF4F46E5),
              onTap: () => context.push('/ac/students/new'),
            ),
            _buildActionButton(
              context,
              icon: Icons.payments_outlined,
              label: isMobile ? 'Fee' : 'Record Fee',
              color: const Color(0xFF059669),
              onTap: () => context.push('/ac/fees/collect'),
            ),
            _buildActionButton(
              context,
              icon: Icons.fact_check_outlined,
              label: 'Attendance',
              color: const Color(0xFFDC2626),
              onTap: () => context.push('/ac/attendance'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, AcDashboardStats stats) {
    final isMobile = context.isMobile;
    return Column(
      children: [
        _buildKpiSection(context, stats),
        const SizedBox(height: 24),
        if (isMobile) ...[
          _buildRevenueSection(context, stats.revenue, stats.overdue),
          const SizedBox(height: 16),
          _buildActivitySection(context, stats),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildRevenueSection(
                  context,
                  stats.revenue,
                  stats.overdue,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(child: _buildActivitySection(context, stats)),
            ],
          ),
        const SizedBox(height: 24),
        if (isMobile) ...[
          _buildStudentOverview(context, stats.students),
          const SizedBox(height: 16),
          _buildAttendanceCard(context, stats.todayAttendance),
          const SizedBox(height: 16),
          _buildBatchOverview(context, stats.batches),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildStudentOverview(context, stats.students)),
              const SizedBox(width: 20),
              Expanded(
                child: _buildAttendanceCard(context, stats.todayAttendance),
              ),
              const SizedBox(width: 20),
              Expanded(child: _buildBatchOverview(context, stats.batches)),
            ],
          ),
      ],
    );
  }

  /// Returns true when the dashboard query returned data but every KPI is zero,
  /// indicating no school activity yet (an honest empty state, not fabricated).
  bool _isDashboardEmpty(AcDashboardStats stats) {
    return stats.students.total == 0 &&
        stats.batches.active == 0 &&
        stats.revenue.monthly == 0 &&
        stats.overdue.amount == 0 &&
        stats.todayAttendance.total == 0 &&
        stats.faculty == 0;
  }

  Widget _buildKpiSection(BuildContext context, AcDashboardStats stats) {
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: sl<CurrencyService>().symbol,
      decimalDigits: 0,
    );

    // Requirement 5.7: Show a zero/empty-state indicator when query returns no data
    final isEmpty = _isDashboardEmpty(stats);

    final kpis = [
      _KpiItem(
        'Total Students',
        isEmpty ? '—' : '${stats.students.total}',
        Icons.people_alt_rounded,
        const Color(0xFF4F46E5),
        isEmpty ? 'No data yet' : '+${stats.students.newThisMonth} this month',
      ),
      _KpiItem(
        'Active Batches',
        isEmpty ? '—' : '${stats.batches.active}',
        Icons.class_rounded,
        const Color(0xFF0891B2),
        isEmpty ? 'No data yet' : '${stats.batches.upcoming} upcoming',
      ),
      _KpiItem(
        'Fee Collected',
        isEmpty ? '—' : fmt.format(stats.revenue.monthly),
        Icons.account_balance_wallet_rounded,
        const Color(0xFF059669),
        isEmpty ? 'No data yet' : 'This month',
      ),
      _KpiItem(
        'Pending Dues',
        isEmpty ? '—' : fmt.format(stats.overdue.amount),
        Icons.pending_actions_rounded,
        const Color(0xFFDC2626),
        isEmpty ? 'No data yet' : '${stats.overdue.count} invoices',
      ),
      _KpiItem(
        'Today\'s Attendance',
        isEmpty ? '—' : '${stats.todayAttendance.percentage}%',
        Icons.fact_check_rounded,
        (isEmpty || stats.todayAttendance.percentage < 75)
            ? const Color(0xFFF59E0B)
            : const Color(0xFF059669),
        isEmpty
            ? 'No data yet'
            : '${stats.todayAttendance.present}/${stats.todayAttendance.total} present',
      ),
      _KpiItem(
        'Total Faculty',
        isEmpty ? '—' : '${stats.faculty}',
        Icons.school_rounded,
        const Color(0xFF7C3AED),
        isEmpty ? 'No data yet' : 'Teaching staff',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'No school activity recorded yet',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisExtent: 120,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: kpis.length,
          itemBuilder: (ctx, i) => _buildKpiCard(ctx, kpis[i]),
        ),
      ],
    );
  }

  Widget _buildKpiCard(BuildContext context, _KpiItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.value,
                style: TextStyle(
                  fontSize: responsiveValue<double>(
                    context,
                    mobile: 20,
                    tablet: 22,
                    desktop: 24, // PRESERVED: Desktop uses exactly 24 as before
                  ),
                  fontWeight: FontWeight.bold,
                  color: item.color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                item.subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueSection(
    BuildContext context,
    AcRevenueStats revenue,
    AcOverdueStats overdue,
  ) {
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: sl<CurrencyService>().symbol,
      decimalDigits: 0,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Fee Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push('/ac/reports'),
                icon: const Icon(Icons.trending_up, size: 18),
                label: const Text('View Reports'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildRevenueMetric(
                'Total Revenue',
                fmt.format(revenue.total),
                const Color(0xFF4F46E5),
                Icons.paid_rounded,
              ),
              _buildRevenueMetric(
                'Collected',
                fmt.format(revenue.collected),
                const Color(0xFF059669),
                Icons.check_circle_rounded,
              ),
              _buildRevenueMetric(
                'Pending',
                fmt.format(revenue.pending),
                const Color(0xFFF59E0B),
                Icons.schedule_rounded,
              ),
              _buildRevenueMetric(
                'Overdue',
                fmt.format(overdue.amount),
                const Color(0xFFDC2626),
                Icons.warning_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: revenue.total > 0 ? revenue.collected / revenue.total : 0,
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF059669),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Collection Rate: ${revenue.total > 0 ? ((revenue.collected / revenue.total) * 100).toStringAsFixed(1) : 0}%',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              Text(
                '${overdue.count} overdue invoices',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueMetric(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection(BuildContext context, AcDashboardStats stats) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          _buildActivityItem(
            icon: Icons.person_add,
            color: const Color(0xFF4F46E5),
            title: '${stats.recentActivity.newStudents} new students',
            subtitle: 'Enrolled this month',
          ),
          const Divider(height: 24),
          _buildActivityItem(
            icon: Icons.notifications_active,
            color: const Color(0xFFF59E0B),
            title: '${stats.recentActivity.pendingFeeReminders} fee reminders',
            subtitle: 'Pending follow-ups',
          ),
          const Divider(height: 24),
          _buildActivityItem(
            icon: Icons.event,
            color: const Color(0xFF0891B2),
            title: '${stats.recentActivity.upcomingExams} exams',
            subtitle: 'Scheduled this week',
          ),
          const Divider(height: 24),
          _buildActivityItem(
            icon: Icons.trending_up,
            color: const Color(0xFF059669),
            title: '${stats.courses} active courses',
            subtitle: 'Running across batches',
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentOverview(BuildContext context, AcStudentStats students) {
    return _buildInfoCard(
      title: 'Students',
      icon: Icons.people_alt_rounded,
      color: const Color(0xFF4F46E5),
      children: [
        _buildStatRow('Active', '${students.active}', const Color(0xFF059669)),
        _buildStatRow(
          'New This Month',
          '+${students.newThisMonth}',
          const Color(0xFF0891B2),
        ),
        _buildStatRow(
          'Inactive',
          '${students.inactive}',
          const Color(0xFF64748B),
        ),
        const Divider(height: 20),
        _buildStatRow(
          'Total',
          '${students.total}',
          const Color(0xFF0F172A),
          isBold: true,
        ),
      ],
    );
  }

  Widget _buildAttendanceCard(
    BuildContext context,
    AcTodayAttendance attendance,
  ) {
    final percentage = attendance.percentage;
    final isGood = percentage >= 75;

    return _buildInfoCard(
      title: "Today's Attendance",
      icon: Icons.fact_check_rounded,
      color: isGood ? const Color(0xFF059669) : const Color(0xFFF59E0B),
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isGood
                  ? const Color(0xFF059669).withOpacity(0.1)
                  : const Color(0xFFF59E0B).withOpacity(0.1),
              border: Border.all(
                color: isGood
                    ? const Color(0xFF059669)
                    : const Color(0xFFF59E0B),
                width: 3,
              ),
            ),
            child: Center(
              child: Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: responsiveValue<double>(
                    context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20, // PRESERVED: Desktop uses exactly 20 as before
                  ),
                  fontWeight: FontWeight.bold,
                  color: isGood
                      ? const Color(0xFF059669)
                      : const Color(0xFFF59E0B),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildStatRow(
          'Present',
          '${attendance.present}',
          const Color(0xFF059669),
        ),
        _buildStatRow(
          'Absent',
          '${attendance.absent}',
          const Color(0xFFDC2626),
        ),
        _buildStatRow('Total', '${attendance.total}', const Color(0xFF64748B)),
      ],
    );
  }

  Widget _buildBatchOverview(BuildContext context, AcBatchStats batches) {
    return _buildInfoCard(
      title: 'Batches',
      icon: Icons.class_rounded,
      color: const Color(0xFF0891B2),
      children: [
        _buildStatRow('Active', '${batches.active}', const Color(0xFF059669)),
        _buildStatRow(
          'Upcoming',
          '${batches.upcoming}',
          const Color(0xFF0891B2),
        ),
        _buildStatRow(
          'Completed',
          '${batches.completed}',
          const Color(0xFF64748B),
        ),
        const Divider(height: 20),
        _buildStatRow(
          'Total',
          '${batches.total}',
          const Color(0xFF0F172A),
          isBold: true,
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStatRow(
    String label,
    String value,
    Color color, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: const Color(0xFF64748B),
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    // Requirement 5.8: Show a loading indicator while a query is in progress
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisExtent: 120,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: 6,
          itemBuilder: (ctx, i) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text(
            'Loading dashboard...',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    // Requirement 5.9: Show error indication on query failure, never a fabricated count
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
          const SizedBox(height: 16),
          Text(
            'Failed to load dashboard',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '$error',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Consumer(
            builder: (context, ref, _) => TextButton.icon(
              onPressed: () => ref.invalidate(acDashboardProvider),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  _KpiItem(this.label, this.value, this.icon, this.color, this.subtitle);
}
