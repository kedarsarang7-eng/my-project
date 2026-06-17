import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final dash = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardProvider),
        child: CustomScrollView(
          slivers: [
            _buildAppBar(context, auth.user?.name ?? 'Student'),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  dash.when(
                    loading: () => _buildSkeleton(),
                    error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(dashboardProvider)),
                    data: (data) => _buildContent(context, data),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, String name) {
    final now = DateTime.now();
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                _greeting(now.hour),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                DateFormat('EEEE, d MMMM yyyy').format(now),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting(int h) {
    if (h < 12) return 'Good Morning 🌅';
    if (h < 17) return 'Good Afternoon ☀️';
    return 'Good Evening 🌙';
  }

  Widget _buildSkeleton() {
    return Column(
      children: List.generate(3, (_) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: const ShimmerBox(height: 80, radius: 16),
      )),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
    final att = (data['attendancePercentage'] ?? 0) as num;
    final feeAmt = (data['pendingFeeAmount'] ?? 0) as num;
    final homework = (data['pendingHomework'] ?? 0) as num;
    final announcements = (data['announcements'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI row
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            StatCard(
              label: 'Attendance',
              value: '${att.toStringAsFixed(0)}%',
              icon: Icons.fact_check_rounded,
              color: att >= 75 ? AppTheme.success : AppTheme.warning,
              subtitle: att >= 75 ? 'Good standing' : 'Below minimum',
            ),
            StatCard(
              label: 'Pending Fees',
              value: feeAmt > 0 ? '₹${_fmt(feeAmt.toInt())}' : 'Clear',
              icon: Icons.payment_rounded,
              color: feeAmt > 0 ? AppTheme.error : AppTheme.success,
            ),
            StatCard(
              label: 'Homework Due',
              value: '$homework',
              icon: Icons.assignment_rounded,
              color: AppTheme.warning,
            ),
            StatCard(
              label: 'Notifications',
              value: '${data['unreadNotifications'] ?? 0}',
              icon: Icons.notifications_rounded,
              color: AppTheme.accent,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Quick actions
        const SectionHeader(title: 'Quick Actions'),
        _QuickActions(),
        const SizedBox(height: 8),

        // Announcements
        if (announcements.isNotEmpty) ...[
          const SectionHeader(title: 'Announcements'),
          ...announcements.take(3).map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AnnouncementCard(data: a as Map<String, dynamic>),
          )),
        ],
      ],
    );
  }

  String _fmt(int n) {
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.payment_rounded, 'Pay Fees', '/fees', AppTheme.error),
      (Icons.calendar_today_rounded, 'Timetable', '/timetable', AppTheme.primary),
      (Icons.menu_book_rounded, 'Materials', '/materials', AppTheme.success),
      (Icons.assignment_rounded, 'Homework', '/homework', AppTheme.warning),
      (Icons.event_busy_rounded, 'Apply Leave', '/leave', AppTheme.secondary),
      (Icons.bar_chart_rounded, 'Results', '/exams', AppTheme.accent),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: items.map((item) => _QuickActionTile(
        icon: item.$1,
        label: item.$2,
        path: item.$3,
        color: item.$4,
      )).toList(),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String path;
  final Color color;
  const _QuickActionTile({required this.icon, required this.label, required this.path, required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(path),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AnnouncementCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.campaign_outlined, color: AppTheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['subject'] ?? 'Announcement', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 3),
                Text(data['body'] ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
