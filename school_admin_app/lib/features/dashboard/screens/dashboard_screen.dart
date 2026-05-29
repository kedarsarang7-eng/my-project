import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../widgets/analytics_charts.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final dash = ref.watch(dashboardProvider);
    final analytics = ref.watch(analyticsProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          ref.invalidate(analyticsProvider);
        },
        child: CustomScrollView(slivers: [
          _appBar(context, auth.user?.name ?? 'Admin'),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(delegate: SliverChildListDelegate([
              dash.when(
                loading: () => Column(children: List.generate(3, (_) => Padding(padding: const EdgeInsets.only(bottom: 12), child: const ShimmerBox(height: 80, radius: 16)))),
                error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(dashboardProvider)),
                data: (data) => _Body(data: data, analyticsAsync: analytics),
              ),
            ])),
          ),
        ]),
      ),
    );
  }

  SliverAppBar _appBar(BuildContext context, String name) => SliverAppBar(
    expandedHeight: 140,
    floating: false, pinned: true,
    backgroundColor: AppTheme.primary,
    flexibleSpace: FlexibleSpaceBar(
      background: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppTheme.primaryDark, AppTheme.primary], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Administration Panel', style: TextStyle(color: Colors.white60, fontSize: 12, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.warning.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Text(DateFormat('d MMM yyyy').format(DateTime.now()), style: const TextStyle(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      ),
    ),
  );
}

class _Body extends StatelessWidget {
  final Map<String, dynamic> data;
  final AsyncValue<Map<String, dynamic>> analyticsAsync;
  const _Body({required this.data, required this.analyticsAsync});

  @override
  Widget build(BuildContext context) {
    final totalStudents = data['totalStudents'] ?? 0;
    final totalFaculty = data['totalFaculty'] ?? 0;
    final pendingFees = data['totalPendingFees'] ?? 0;
    final pendingAdmissions = data['pendingAdmissions'] ?? 0;
    final todayAttendance = (data['todayAttendanceRate'] ?? 0) as num;
    final recentActivities = (data['recentActivities'] as List?) ?? [];
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // KPI Grid
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
        children: [
          StatCard(label: 'Total Students', value: '$totalStudents', icon: Icons.people_rounded, color: AppTheme.primary, onTap: () => context.go('/students')),
          StatCard(label: 'Faculty', value: '$totalFaculty', icon: Icons.badge_rounded, color: AppTheme.secondary, onTap: () => context.go('/faculty')),
          StatCard(label: 'Pending Fees', value: fmt.format(pendingFees), icon: Icons.account_balance_wallet_rounded, color: AppTheme.error, onTap: () => context.go('/fees')),
          StatCard(label: 'New Admissions', value: '$pendingAdmissions', icon: Icons.how_to_reg_rounded, color: AppTheme.warning, onTap: () => context.go('/admissions')),
        ],
      ),
      const SizedBox(height: 16),

      // Attendance banner
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppTheme.success.withOpacity(0.8), AppTheme.success], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Icon(Icons.fact_check_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Today\'s Attendance', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text('${todayAttendance.toStringAsFixed(1)}% students present', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
          ])),
          CircularProgressIndicator(value: todayAttendance / 100, strokeWidth: 6, backgroundColor: Colors.white30, valueColor: const AlwaysStoppedAnimation<Color>(Colors.white)),
        ]),
      ),
      const SizedBox(height: 16),

      // Quick actions
      const SectionHeader(title: 'Quick Actions'),
      _QuickActions(),
      const SizedBox(height: 16),

      // Analytics Charts
      analyticsAsync.when(
        loading: () => Column(children: const [ShimmerBox(height: 200), SizedBox(height: 12), ShimmerBox(height: 160)]),
        error: (_, __) => const SizedBox.shrink(),
        data: (analytics) {
          final feeCollection = ((analytics['feeCollection'] ?? []) as List).cast<Map<String, dynamic>>();
          final admissionTrend = ((analytics['admissionTrend'] ?? []) as List).cast<Map<String, dynamic>>();
          final attSummary = (analytics['attendanceSummary'] as Map?)?.cast<String, dynamic>() ?? {};
          final presentPct = (attSummary['present'] ?? todayAttendance.toDouble()) as double;
          final absentPct = (attSummary['absent'] ?? (100 - presentPct) * 0.7) as double;
          final leavePct = (attSummary['leave'] ?? (100 - presentPct) * 0.3) as double;
          return Column(children: [
            if (feeCollection.isNotEmpty) ...[FeeCollectionChart(monthlyData: feeCollection), const SizedBox(height: 12)],
            Row(children: [
              Expanded(child: AttendanceDonutChart(presentPct: presentPct, absentPct: absentPct, leavePct: leavePct)),
            ]),
            if (admissionTrend.isNotEmpty) ...[const SizedBox(height: 12), AdmissionTrendChart(trendData: admissionTrend)],
          ]);
        },
      ),
      const SizedBox(height: 8),

      // Recent activity
      if (recentActivities.isNotEmpty) ...[
        const SectionHeader(title: 'Recent Activity'),
        ...recentActivities.take(5).map((a) => _ActivityTile(activity: a as Map<String, dynamic>)),
      ],
    ]);
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.person_add_rounded, 'New Student', '/students', AppTheme.primary),
      (Icons.receipt_long_rounded, 'Collect Fee', '/fees', AppTheme.success),
      (Icons.how_to_reg_rounded, 'Admissions', '/admissions', AppTheme.warning),
      (Icons.campaign_rounded, 'Announce', '/announcements', AppTheme.secondary),
      (Icons.bar_chart_rounded, 'Reports', '/reports', AppTheme.accent),
      (Icons.settings_rounded, 'Settings', '/settings', AppTheme.textSecondary),
    ];
    return GridView.count(
      crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.0,
      children: actions.map((a) => InkWell(
        onTap: () => context.go(a.$3),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: a.$4.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(a.$1, color: a.$4, size: 20)),
            const SizedBox(height: 8),
            Text(a.$2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ]),
        ),
      )).toList(),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> activity;
  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.divider)),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(child: Text(activity['message'] ?? '', style: const TextStyle(fontSize: 13))),
        Text(activity['time'] ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      ]),
    ),
  );
}
