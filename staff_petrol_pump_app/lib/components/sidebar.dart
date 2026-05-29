import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../context/permission_context.dart';
import '../features/petrol_pump/providers/license_provider.dart';

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(permissionProvider);
    final licenseState = ref.watch(licenseStateProvider);
    final license = licenseState.profile;
    
    // ENHANCED: Multi-business license support
    final inventoryEnabled = license?.hasBusinessType('retail_shop') == true || 
                           license?.hasBusinessType('manufacturing') == true ||
                           <String>{'retail_shop', 'manufacturing'}.contains(p.businessType);

    final items = <({String title, IconData icon, String route})>[
      (title: 'Dashboard', icon: Icons.dashboard, route: '/dashboard'),
      if (p.can('invoice', 'view')) (title: 'Invoices', icon: Icons.receipt_long, route: '/invoices'),
      if (p.can('payments', 'view')) (title: 'Payments', icon: Icons.payments, route: '/payments'),
      if (p.can('clients', 'view')) (title: 'Clients', icon: Icons.people, route: '/clients'),
      if (p.can('inventory', 'view') && inventoryEnabled) (title: 'Inventory', icon: Icons.inventory, route: '/inventory'),
      if (p.can('reports', 'view')) (title: 'Reports', icon: Icons.bar_chart, route: '/reports'),
      if (p.can('gst', 'view')) (title: 'GST / Tax', icon: Icons.request_page, route: '/gst'),
      if (p.can('ledger', 'view')) (title: 'Ledger', icon: Icons.book, route: '/ledger'),
      if (p.can('staff', 'view')) (title: 'Staff Management', icon: Icons.badge, route: '/staff'),
      if (p.can('settings', 'view')) (title: 'Settings', icon: Icons.settings, route: '/settings'),
      if (p.can('audit', 'view')) (title: 'Audit Log', icon: Icons.history, route: '/audit'),
      
      // ENHANCED: Business-type specific modules based on license
      if (license?.hasBusinessType('petrol_pump') == true) ...[
        (title: 'Fuel POS', icon: Icons.local_gas_station, route: '/fuel-pos'),
        (title: 'Shifts', icon: Icons.work, route: '/shifts'),
        (title: 'Fuel Rates', icon: Icons.trending_up, route: '/fuel-rates'),
        (title: 'DSR Reports', icon: Icons.assessment, route: '/dsr'),
      ],
      
      if (license?.hasBusinessType('pharmacy') == true) ...[
        (title: 'Pharmacy', icon: Icons.medication, route: '/pharmacy'),
        (title: 'Drug Stock', icon: Icons.inventory_2, route: '/drug-stock'),
        (title: 'Narcotic Register', icon: Icons.security, route: '/narcotic-register'),
      ],
      
      if (license?.hasBusinessType('restaurant') == true) ...[
        (title: 'Restaurant', icon: Icons.restaurant, route: '/restaurant'),
        (title: 'Menu', icon: Icons.menu_book, route: '/menu'),
        (title: 'Orders', icon: Icons.receipt, route: '/orders'),
      ],
      
      if (license?.hasBusinessType('clinic') == true) ...[
        (title: 'Clinic', icon: Icons.local_hospital, route: '/clinic'),
        (title: 'Patients', icon: Icons.people, route: '/patients'),
        (title: 'Appointments', icon: Icons.calendar_today, route: '/appointments'),
      ],
      
      if (license?.hasBusinessType('grocery') == true) ...[
        (title: 'Grocery', icon: Icons.shopping_cart, route: '/grocery'),
        (title: 'Products', icon: Icons.category, route: '/products'),
        (title: 'Batches', icon: Icons.inventory, route: '/batches'),
      ],
    ];

    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(child: Text('Menu')),
          for (final item in items)
            ListTile(
              leading: Icon(item.icon),
              title: Text(item.title),
              onTap: () => context.go(item.route),
            ),
        ],
      ),
    );
  }
}
