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

const _navItems = [
  _NavItem(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home_rounded, path: '/dashboard'),
  _NavItem(label: 'Timetable', icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today_rounded, path: '/timetable'),
  _NavItem(label: 'Attendance', icon: Icons.fact_check_outlined, activeIcon: Icons.fact_check_rounded, path: '/attendance'),
  _NavItem(label: 'Results', icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded, path: '/exams'),
  _NavItem(label: 'More', icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, path: '/more'),
];

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    int selected = _navItems.indexWhere((n) => location.startsWith(n.path));
    if (selected < 0) selected = 0;

    // On wider screens use sidebar, on narrow use bottom nav
    final isWide = MediaQuery.of(context).size.width >= 720;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            _SideNav(selectedPath: location),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: _BottomNav(selectedIndex: selected),
    );
  }
}

// ── Bottom Navigation ──────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  const _BottomNav({required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.divider)),
        color: AppTheme.cardBg,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (i) {
              final item = _navItems[i];
              final isSelected = i == selectedIndex;
              return _BottomNavItem(
                item: item,
                isSelected: isSelected,
                onTap: () {
                  if (item.path == '/more') {
                    showModalBottomSheet(context: context, builder: (_) => const _MoreSheet());
                  } else {
                    context.go(item.path);
                  }
                },
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  const _BottomNavItem({required this.item, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sidebar for wide screens ───────────────────────────────────────────────

const _allNavItems = [
  _NavItem(label: 'Dashboard', icon: Icons.home_outlined, activeIcon: Icons.home_rounded, path: '/dashboard'),
  _NavItem(label: 'Timetable', icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today_rounded, path: '/timetable'),
  _NavItem(label: 'Attendance', icon: Icons.fact_check_outlined, activeIcon: Icons.fact_check_rounded, path: '/attendance'),
  _NavItem(label: 'Exams & Results', icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded, path: '/exams'),
  _NavItem(label: 'Fee Payments', icon: Icons.payment_outlined, activeIcon: Icons.payment_rounded, path: '/fees'),
  _NavItem(label: 'Study Materials', icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book_rounded, path: '/materials'),
  _NavItem(label: 'Homework', icon: Icons.assignment_outlined, activeIcon: Icons.assignment_rounded, path: '/homework'),
  _NavItem(label: 'Leave', icon: Icons.event_busy_outlined, activeIcon: Icons.event_busy_rounded, path: '/leave'),
  _NavItem(label: 'Library', icon: Icons.local_library_outlined, activeIcon: Icons.local_library_rounded, path: '/library'),
  _NavItem(label: 'Transport', icon: Icons.directions_bus_outlined, activeIcon: Icons.directions_bus_rounded, path: '/transport'),
  _NavItem(label: 'Results', icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded, path: '/results'),
  _NavItem(label: 'Fee Payment', icon: Icons.payment_outlined, activeIcon: Icons.payment_rounded, path: '/fee-payment'),
  _NavItem(label: 'Notifications', icon: Icons.notifications_outlined, activeIcon: Icons.notifications_rounded, path: '/notifications'),
  _NavItem(label: 'Profile', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, path: '/profile'),
];

class _SideNav extends StatelessWidget {
  final String selectedPath;
  const _SideNav({required this.selectedPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppTheme.navBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.secondary]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school_rounded, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Text('EduConnect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Student Portal', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _allNavItems.map((item) {
                final isSelected = selectedPath.startsWith(item.path);
                return _SideNavItem(item: item, isSelected: isSelected);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  const _SideNavItem({required this.item, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: () => context.go(item.path),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? item.activeIcon : item.icon,
                size: 20,
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
              ),
              const SizedBox(width: 12),
              Text(
                item.label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── More sheet (overflow nav items on mobile) ──────────────────────────────

class _MoreSheet extends StatelessWidget {
  const _MoreSheet();

  @override
  Widget build(BuildContext context) {
    final overflow = _allNavItems.skip(4).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('More', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: overflow.map((item) => _MoreTile(item: item)).toList(),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final _NavItem item;
  const _MoreTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        context.go(item.path);
      },
      child: Container(
        width: (MediaQuery.of(context).size.width - 52) / 3,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          children: [
            Icon(item.icon, color: AppTheme.primary, size: 26),
            const SizedBox(height: 8),
            Text(item.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
