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
        child: CustomScrollView(slivers: [
          _buildAppBar(context, auth.user?.name ?? 'Teacher'),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(delegate: SliverChildListDelegate([
              dash.when(
                loading: () => Column(children: List.generate(3, (_) => Padding(padding: const EdgeInsets.only(bottom: 12), child: const ShimmerBox(height: 80, radius: 16)))),
                error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(dashboardProvider)),
                data: (data) => _buildBody(context, data),
              ),
            ])),
          ),
        ]),
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, String name) {
    final now = DateTime.now();
    return SliverAppBar(
      expandedHeight: 150,
      floating: false, pinned: true,
      backgroundColor: AppTheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight)),
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
            Text(_greeting(now.hour), style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            Text(DateFormat('EEEE, d MMMM').format(now), style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ]),
        ),
      ),
    );
  }

  String _greeting(int h) => h < 12 ? 'Good Morning ☀️' : h < 17 ? 'Good Afternoon 🌤️' : 'Good Evening 🌙';

  Widget _buildBody(BuildContext context, Map<String, dynamic> data) {
    final todayClasses = data['todayClasses'] ?? 0;
    final totalStudents = data['totalStudents'] ?? 0;
    final pendingHomework = data['pendingHomework'] ?? 0;
    final pendingLeaves = data['pendingLeaveApprovals'] ?? 0;
    final todaySchedule = (data['todaySchedule'] as List?) ?? [];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // KPI cards
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
        children: [
          StatCard(label: 'Classes Today', value: '$todayClasses', icon: Icons.class_outlined, color: AppTheme.primary),
          StatCard(label: 'My Students', value: '$totalStudents', icon: Icons.people_rounded, color: AppTheme.secondary),
          StatCard(label: 'Pending HW', value: '$pendingHomework', icon: Icons.assignment_outlined, color: AppTheme.warning),
          StatCard(label: 'Leave Requests', value: '$pendingLeaves', icon: Icons.event_busy_outlined, color: AppTheme.error),
        ],
      ),
      const SizedBox(height: 16),

      // Quick actions
      const SectionHeader(title: 'Quick Actions'),
      _QuickActions(),
      const SizedBox(height: 8),

      // Today's schedule
      if (todaySchedule.isNotEmpty) ...[
        SectionHeader(title: "Today's Schedule", action: 'Full Timetable', onAction: () => context.go('/timetable')),
        ...todaySchedule.take(4).map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ScheduleTile(slot: s as Map<String, dynamic>),
        )),
      ],
    ]);
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.fact_check_rounded, 'Mark\nAttendance', '/attendance', AppTheme.primary),
      (Icons.assignment_add, 'Assign\nHomework', '/homework', AppTheme.warning),
      (Icons.quiz_outlined, 'Schedule\nExam', '/exams', AppTheme.secondary),
      (Icons.campaign_rounded, 'Send\nAnnouncement', '/announcements', AppTheme.accent),
      (Icons.auto_stories_rounded, 'Lesson\nPlan', '/lesson-plans', AppTheme.success),
      (Icons.event_busy_rounded, 'Apply\nLeave', '/leave', AppTheme.error),
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
            Container(width: 42, height: 42, decoration: BoxDecoration(color: a.$4.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(a.$1, color: a.$4, size: 20)),
            const SizedBox(height: 8),
            Text(a.$2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ]),
        ),
      )).toList(),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  final Map<String, dynamic> slot;
  const _ScheduleTile({required this.slot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.divider)),
      child: Row(children: [
        Container(width: 4, height: 40, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(slot['subjectName'] ?? 'Class', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text('${slot['batchName'] ?? ''} · Room ${slot['room'] ?? '—'}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ])),
        Text('${slot['startTime'] ?? ''} - ${slot['endTime'] ?? ''}', style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
