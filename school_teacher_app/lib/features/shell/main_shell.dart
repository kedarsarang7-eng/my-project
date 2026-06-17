import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;
  const _NavItem({required this.label, required this.icon, required this.activeIcon, required this.path});
}

const _bottomNav = [
  _NavItem(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home_rounded, path: '/dashboard'),
  _NavItem(label: 'Attendance', icon: Icons.fact_check_outlined, activeIcon: Icons.fact_check_rounded, path: '/attendance'),
  _NavItem(label: 'Homework', icon: Icons.assignment_outlined, activeIcon: Icons.assignment_rounded, path: '/homework'),
  _NavItem(label: 'Timetable', icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today_rounded, path: '/timetable'),
  _NavItem(label: 'More', icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, path: '/more'),
];

const _allNav = [
  _NavItem(label: 'Dashboard', icon: Icons.home_outlined, activeIcon: Icons.home_rounded, path: '/dashboard'),
  _NavItem(label: 'Mark Attendance', icon: Icons.fact_check_outlined, activeIcon: Icons.fact_check_rounded, path: '/attendance'),
  _NavItem(label: 'Timetable', icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today_rounded, path: '/timetable'),
  _NavItem(label: 'My Students', icon: Icons.people_outlined, activeIcon: Icons.people_rounded, path: '/students'),
  _NavItem(label: 'Homework', icon: Icons.assignment_outlined, activeIcon: Icons.assignment_rounded, path: '/homework'),
  _NavItem(label: 'Lesson Plans', icon: Icons.auto_stories_outlined, activeIcon: Icons.auto_stories_rounded, path: '/lesson-plans'),
  _NavItem(label: 'Exams & Results', icon: Icons.quiz_outlined, activeIcon: Icons.quiz_rounded, path: '/exams'),
  _NavItem(label: 'Study Materials', icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book_rounded, path: '/materials'),
  _NavItem(label: 'Leave', icon: Icons.event_busy_outlined, activeIcon: Icons.event_busy_rounded, path: '/leave'),
  _NavItem(label: 'Announcements', icon: Icons.campaign_outlined, activeIcon: Icons.campaign_rounded, path: '/announcements'),
  _NavItem(label: 'Payslip', icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, path: '/payslip'),
  _NavItem(label: 'Profile', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, path: '/profile'),
];

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isWide = MediaQuery.of(context).size.width >= 720;

    if (isWide) {
      return Scaffold(
        body: Row(children: [
          _SideNav(selectedPath: location),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ]),
      );
    }

    int selected = _bottomNav.indexWhere((n) => location.startsWith(n.path));
    if (selected < 0) selected = 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: _BottomNav(selectedIndex: selected),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  const _BottomNav({required this.selectedIndex});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.divider)), color: AppTheme.cardBg),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_bottomNav.length, (i) {
            final item = _bottomNav[i];
            final sel = i == selectedIndex;
            return GestureDetector(
              onTap: () => item.path == '/more'
                  ? showModalBottomSheet(context: context, builder: (_) => const _MoreSheet())
                  : context.go(item.path),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: sel ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(sel ? item.activeIcon : item.icon, color: sel ? AppTheme.primary : AppTheme.textSecondary, size: 24),
                  const SizedBox(height: 3),
                  Text(item.label, style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? AppTheme.primary : AppTheme.textSecondary)),
                ]),
              ),
            );
          }),
        ),
      ),
    ),
  );
}

class _SideNav extends StatelessWidget {
  final String selectedPath;
  const _SideNav({required this.selectedPath});

  @override
  Widget build(BuildContext context) => Container(
    width: 240,
    color: AppTheme.navBg,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 24),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.secondary]), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.school_rounded, size: 20, color: Colors.white)),
          const SizedBox(width: 10),
          const Text('EduConnect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
      ),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text('Teacher Portal', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
      ),
      const SizedBox(height: 24),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: _allNav.map((item) {
            final sel = selectedPath.startsWith(item.path);
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: InkWell(
                onTap: () => context.go(item.path),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: sel ? Colors.white.withValues(alpha: 0.12) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Icon(sel ? item.activeIcon : item.icon, size: 20, color: sel ? Colors.white : Colors.white.withValues(alpha: 0.6)),
                    const SizedBox(width: 12),
                    Text(item.label, style: TextStyle(color: sel ? Colors.white : Colors.white.withValues(alpha: 0.6), fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ]),
  );
}

class _MoreSheet extends StatelessWidget {
  const _MoreSheet();
  @override
  Widget build(BuildContext context) {
    final overflow = _allNav.skip(4).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('More', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12, runSpacing: 12,
          children: overflow.map((item) => GestureDetector(
            onTap: () { Navigator.pop(context); context.go(item.path); },
            child: Container(
              width: (MediaQuery.of(context).size.width - 52) / 3,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(children: [
                Icon(item.icon, color: AppTheme.primary, size: 26),
                const SizedBox(height: 8),
                Text(item.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
              ]),
            ),
          )).toList(),
        ),
      ]),
    );
  }
}
