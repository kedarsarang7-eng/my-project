// ============================================================================
// SIDE NAVIGATION
// ============================================================================
// Left sidebar matching reference image:
// - Dashboard, Appointments, Patients, Staff
// - Billing, Inventory, Reports, Settings
// - Role-based item visibility
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/clinic_dashboard_providers.dart';
import '../models/clinic_dashboard_models.dart';

class SideNavigation extends ConsumerWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool collapsed;
  final VoidCallback? onToggleCollapse;

  const SideNavigation({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.collapsed = false,
    this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ClinicRole? userRole = ref.watch(clinicRoleProvider);

    final navItems = _getNavItemsForRole(userRole);

    return Container(
      width: collapsed ? 72 : 240,
      color: const Color(0xFF1565C0), // Primary blue
      child: Column(
        children: [
          // Logo area
          Container(
            padding: EdgeInsets.all(collapsed ? 16 : 24),
            child: Row(
              mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.medical_services,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MedCare',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Dashboard',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const Divider(color: Colors.white24, height: 1),

          // Navigation Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _NavItem(
                    icon: item.icon,
                    label: item.label,
                    isSelected: isSelected,
                    collapsed: collapsed,
                    onTap: () => onItemSelected(index),
                  ),
                );
              },
            ),
          ),

          // Bottom section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              border: const Border(
                top: BorderSide(color: Colors.white24),
              ),
            ),
            child: Column(
              children: [
                if (!collapsed)
                  _NavItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    isSelected: false,
                    collapsed: false,
                    onTap: () {},
                  )
                else
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                  ),
                const SizedBox(height: 8),
                if (!collapsed)
                  _NavItem(
                    icon: Icons.logout,
                    label: 'Logout',
                    isSelected: false,
                    collapsed: false,
                    onTap: () {
                      // Handle logout
                    },
                  )
                else
                  IconButton(
                    onPressed: () {
                      // Handle logout
                    },
                    icon: const Icon(Icons.logout, color: Colors.white70),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_NavItemData> _getNavItemsForRole(ClinicRole? role) {
    final allItems = [
      const _NavItemData(icon: Icons.dashboard_outlined, label: 'Dashboard'),
      const _NavItemData(icon: Icons.calendar_today_outlined, label: 'Appointments'),
      const _NavItemData(icon: Icons.people_outlined, label: 'Patients'),
      const _NavItemData(icon: Icons.person_outline, label: 'Staff'),
      const _NavItemData(icon: Icons.receipt_long_outlined, label: 'Billing'),
      const _NavItemData(icon: Icons.inventory_2_outlined, label: 'Inventory'),
      const _NavItemData(icon: Icons.bar_chart_outlined, label: 'Reports'),
    ];

    switch (role) {
      case ClinicRole.admin:
        return allItems;
      case ClinicRole.doctor:
        return allItems.where((item) =>
          !['Billing'].contains(item.label)
        ).toList();
      case ClinicRole.nurse:
        return allItems.where((item) =>
          ['Dashboard', 'Appointments', 'Patients', 'Inventory'].contains(item.label)
        ).toList();
      case ClinicRole.receptionist:
        return allItems.where((item) =>
          ['Dashboard', 'Appointments', 'Patients', 'Billing'].contains(item.label)
        ).toList();
      default:
        return allItems.sublist(0, 2); // Dashboard + Appointments only
    }
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool collapsed;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.collapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final widget = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 12 : 16,
            vertical: 12,
          ),
          decoration: isSelected
              ? BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Row(
            mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white70,
                size: 20,
              ),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
              if (isSelected && !collapsed) ...[
                const Spacer(),
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // Add tooltip for collapsed state
    if (collapsed) {
      return Tooltip(
        message: label,
        preferBelow: false,
        child: widget,
      );
    }
    return widget;
  }
}

class _NavItemData {
  final IconData icon;
  final String label;

  const _NavItemData({
    required this.icon,
    required this.label,
  });
}
