import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/data/datasources/auth_remote_datasource_provider.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../providers/license_provider.dart';
import '../theme/fuelpos_theme.dart';

/// Sidebar navigation widget for FuelPOS
class SidebarNavWidget extends ConsumerWidget {
  final String currentRoute;

  const SidebarNavWidget({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final license = ref.watch(licenseProvider).profile;
    final stationName = license?.stationName ?? 'Unknown Station';

    return Container(
      width: 220,
      color: FuelPOSTheme.sidebarDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo and brand
          _buildHeader(),

          // Station name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              stationName,
              style: const TextStyle(
                color: FuelPOSTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const Divider(color: FuelPOSTheme.borderDark, height: 1),

          const SizedBox(height: 16),

          // Navigation items
          _buildNavItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            route: '/dashboard/petrol-pump',
            isActive: currentRoute == '/dashboard/petrol-pump',
            onTap: () => context.go('/dashboard/petrol-pump'),
          ),
          _buildNavItem(
            icon: Icons.qr_code_scanner,
            label: 'New Payment',
            route: '/qr/entry',
            isActive: currentRoute.startsWith('/qr'),
            onTap: () => context.go('/qr/entry'),
          ),
          _buildNavItem(
            icon: Icons.receipt_long_outlined,
            label: 'Sales',
            route: '/sales',
            isActive: currentRoute.startsWith('/sales'),
            onTap: () => context.go('/sales'),
          ),
          _buildNavItem(
            icon: Icons.inventory_2_outlined,
            label: 'Inventory',
            route: '/inventory',
            isActive: currentRoute.startsWith('/inventory'),
            onTap: () => context.go('/inventory'),
          ),
          _buildNavItem(
            icon: Icons.people_outline,
            label: 'Customers',
            route: '/customers',
            isActive: currentRoute.startsWith('/customers'),
            onTap: () => context.go('/customers'),
          ),
          _buildNavItem(
            icon: Icons.groups_outlined,
            label: 'Staff',
            route: '/staff',
            isActive: currentRoute.startsWith('/staff'),
            onTap: () => context.go('/staff'),
          ),
          _buildNavItem(
            icon: Icons.bar_chart_outlined,
            label: 'Reports',
            route: '/reports',
            isActive: currentRoute.startsWith('/reports'),
            onTap: () => context.go('/reports'),
          ),
          _buildNavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            route: '/settings',
            isActive: currentRoute.startsWith('/settings'),
            onTap: () => context.go('/settings'),
          ),

          const Spacer(),

          const Divider(color: FuelPOSTheme.borderDark, height: 1),

          // Admin profile section
          _buildAdminSection(context, ref),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [FuelPOSTheme.petrolBlue, FuelPOSTheme.dieselOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_gas_station,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FuelPOS',
                style: TextStyle(
                  color: FuelPOSTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Station Manager',
                style: TextStyle(
                  color: FuelPOSTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required String route,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isActive ? FuelPOSTheme.sidebarActiveBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: isActive
                  ? const Border(
                      left: BorderSide(
                        color: FuelPOSTheme.sidebarActiveBorder,
                        width: 3,
                      ),
                    )
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive
                      ? FuelPOSTheme.primaryBlue
                      : FuelPOSTheme.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive
                        ? FuelPOSTheme.textPrimary
                        : FuelPOSTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminSection(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: FuelPOSTheme.cardDark,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: FuelPOSTheme.borderDark),
            ),
            child: const Icon(
              Icons.person,
              color: FuelPOSTheme.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin',
                  style: TextStyle(
                    color: FuelPOSTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'John Doe',
                  style: TextStyle(
                    color: FuelPOSTheme.textSecondary,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              color: FuelPOSTheme.textSecondary,
              size: 20,
            ),
            color: FuelPOSTheme.cardDark,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 18, color: FuelPOSTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text('Profile',
                        style: TextStyle(color: FuelPOSTheme.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: FuelPOSTheme.errorRed),
                    const SizedBox(width: 8),
                    Text('Logout',
                        style: TextStyle(color: FuelPOSTheme.errorRed)),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'logout') {
                try {
                  await ref.read(authRemoteDataSourceProvider).logout();
                  ref.read(authNotifierProvider.notifier).signOut();
                  if (context.mounted) {
                    context.go('/login');
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Logout failed: ${e.toString().replaceAll('Exception: ', '')}'),
                        backgroundColor: FuelPOSTheme.errorRed,
                      ),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
