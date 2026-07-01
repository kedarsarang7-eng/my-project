import 'package:flutter/material.dart';
import 'dashboard_strategies.dart';
import '../../../../models/business_type.dart';
import '../../../../core/isolation/business_capability.dart';
import '../../../../core/theme/futuristic_colors.dart';

class MenuAction {
  final String title;
  final IconData icon;
  final String route;
  final Color baseColor;
  final String? badge;

  MenuAction({
    required this.title,
    required this.icon,
    required this.route,
    required this.baseColor,
    this.badge,
  });
}

// Placeholder for Widget wrapper if needed, or just typedef
class DashboardWidget {
  // Add implementation if needed
}

// ============================================================================
// 🛒 GROCERY STRATEGY
// ============================================================================
class GroceryDashboardStrategy extends DashboardStrategy {
  BusinessType get type => BusinessType.grocery;

  @override
  String get addItemLabel => 'Add Item';

  @override
  IconData get addItemIcon => Icons.add_box_rounded;

  String get dashboardTitle => 'Grocery Dashboard';

  List<BusinessCapability> get keyCapabilities => [
    BusinessCapability.useStockManagement,
    BusinessCapability.useBarcodeScanner,
  ];

  List<MenuAction> getMenuActions(BuildContext context) {
    return [
      MenuAction(
        title: 'Add Item',
        icon: Icons.add_box_outlined,
        route: '/inventory/add',
        baseColor: FuturisticColors.primary,
      ),
      MenuAction(
        title: 'Quick Bill',
        icon: Icons.shopping_cart_checkout,
        route: '/billing',
        baseColor: FuturisticColors.accent1,
      ),
      MenuAction(
        title: 'Stock Alert',
        icon: Icons.inventory_2_outlined,
        route: '/inventory/low_stock',
        baseColor: FuturisticColors.error,
        badge: '!',
      ),
      MenuAction(
        title: 'Customers',
        icon: Icons.people_outline,
        route: '/customers',
        baseColor: FuturisticColors.secondary,
      ),
    ];
  }

  List<DashboardWidget> getWidgets(BuildContext context) => [];

  // Migration Stubs
  @override
  List<DashboardQuickAction> get quickActions => [];
  @override
  List<DashboardWidgetType> get widgets => [];
}

// ============================================================================
// 💊 PHARMACY STRATEGY
// ============================================================================
class PharmacyDashboardStrategy extends DashboardStrategy {
  BusinessType get type => BusinessType.pharmacy;

  @override
  String get addItemLabel => 'Add Medicine';

  @override
  IconData get addItemIcon => Icons.medication_rounded;

  String get dashboardTitle => 'Pharmacy Dashboard';

  List<BusinessCapability> get keyCapabilities => [
    BusinessCapability.usePrescription,
    BusinessCapability.useBatchExpiry,
  ];

  List<MenuAction> getMenuActions(BuildContext context) {
    return [
      MenuAction(
        title: 'New Invoice',
        icon: Icons.receipt_long_rounded,
        route: '/billing',
        baseColor: FuturisticColors.primary,
      ),
      MenuAction(
        title: 'Upload RX',
        icon: Icons.document_scanner_rounded,
        route: '/prescriptions/upload',
        baseColor: FuturisticColors.accent2,
        badge: 'AI',
      ),
      MenuAction(
        title: 'Expiry Check',
        icon: Icons.date_range_rounded,
        route: '/inventory/expiry',
        baseColor: FuturisticColors.error,
      ),
      MenuAction(
        title: 'Doctors',
        icon: Icons.medical_services_outlined,
        route: '/doctors',
        baseColor: FuturisticColors.secondary,
      ),
    ];
  }

  List<DashboardWidget> getWidgets(BuildContext context) => [];

  @override
  List<DashboardQuickAction> get quickActions => [];
  @override
  List<DashboardWidgetType> get widgets => [];
}

// ============================================================================
// 👨‍⚕️ CLINIC STRATEGY
// ============================================================================
class ClinicDashboardStrategy extends DashboardStrategy {
  BusinessType get type => BusinessType.clinic;

  @override
  String get addItemLabel => 'Add Patient'; // Contextual override

  @override
  IconData get addItemIcon => Icons.person_add_rounded;

  String get dashboardTitle => 'Clinic Management';

  List<BusinessCapability> get keyCapabilities => [
    BusinessCapability.useAppointments,
    BusinessCapability.usePatientRegistry,
  ];

  List<MenuAction> getMenuActions(BuildContext context) {
    return [
      MenuAction(
        title: 'New Patient',
        icon: Icons.person_add,
        route: '/patients/add',
        baseColor: FuturisticColors.primary,
      ),
      MenuAction(
        title: 'Consultation',
        icon: Icons.monitor_heart_outlined,
        route: '/consultation',
        baseColor: FuturisticColors.accent1,
      ),
      MenuAction(
        title: 'Appointments',
        icon: Icons.calendar_today_rounded,
        route: '/appointments',
        baseColor: FuturisticColors.secondary,
      ),
      MenuAction(
        title: 'Reports',
        icon: Icons.description_outlined,
        route: '/reports',
        baseColor: FuturisticColors.accent2,
      ),
    ];
  }

  List<DashboardWidget> getWidgets(BuildContext context) => [];

  @override
  List<DashboardQuickAction> get quickActions => [];
  @override
  List<DashboardWidgetType> get widgets => [];
}

// ============================================================================
// 🍽️ RESTAURANT STRATEGY
// ============================================================================
class RestaurantDashboardStrategy extends DashboardStrategy {
  BusinessType get type => BusinessType.restaurant;

  @override
  String get addItemLabel => 'Add Menu Item';

  @override
  IconData get addItemIcon => Icons.restaurant_menu_rounded;

  String get dashboardTitle => 'Restaurant Manager';

  List<BusinessCapability> get keyCapabilities => [
    BusinessCapability.useTableManagement,
    BusinessCapability.useKOT,
  ];

  List<MenuAction> getMenuActions(BuildContext context) {
    return [
      MenuAction(
        title: 'Tables',
        icon: Icons.table_restaurant_rounded,
        route: '/restaurant/tables',
        baseColor: FuturisticColors.primary,
      ),
      MenuAction(
        title: 'KOT',
        icon: Icons.receipt_rounded,
        route: '/restaurant/kot',
        baseColor: FuturisticColors.accent1,
      ),
      MenuAction(
        title: 'Online Orders',
        icon: Icons.delivery_dining_rounded,
        route: '/restaurant/orders',
        baseColor: FuturisticColors.success,
      ),
      MenuAction(
        title: 'Menu',
        icon: Icons.menu_book_rounded,
        route: '/inventory',
        baseColor: FuturisticColors.secondary,
      ),
    ];
  }

  List<DashboardWidget> getWidgets(BuildContext context) => [];

  @override
  List<DashboardQuickAction> get quickActions => [];
  @override
  List<DashboardWidgetType> get widgets => [];
}

// ============================================================================
// 🥦 VEGETABLE BROKER STRATEGY (Mandi)
// ============================================================================
class VegetableBrokerStrategy extends DashboardStrategy {
  BusinessType get type => BusinessType.vegetablesBroker;

  @override
  String get addItemLabel => 'New Entry';

  @override
  IconData get addItemIcon => Icons.eco_rounded;

  String get dashboardTitle => 'Mandi Dashboard';

  List<BusinessCapability> get keyCapabilities => [
    BusinessCapability.useStockManagement,
    BusinessCapability.useDailyRates,
  ];

  List<MenuAction> getMenuActions(BuildContext context) {
    return [
      MenuAction(
        title: 'New Entry',
        icon: Icons.add_circle,
        route: '/mandi/entry',
        baseColor: FuturisticColors.primary,
      ),
      MenuAction(
        title: 'Farmer Ledger',
        icon: Icons.person_pin,
        route: '/mandi/farmers',
        baseColor: FuturisticColors.secondary,
      ),
      MenuAction(
        title: 'Daily Rates',
        icon: Icons.currency_rupee,
        route: '/mandi/rates',
        baseColor: FuturisticColors.accent1,
      ),
      MenuAction(
        title: 'Mandi Bill',
        icon: Icons.receipt_long,
        route: '/billing',
        baseColor: FuturisticColors.accent2,
      ),
    ];
  }

  List<DashboardWidget> getWidgets(BuildContext context) => [];

  /// Returns configured Mandi quick actions derived from business config.
  /// Labels correspond to DashboardBusinessConfig for vegetablesBroker:
  /// "Mandi Sales" (revenue), "Lot Pending" (kpi2), "Commission Due" (kpi3).
  @override
  List<DashboardQuickAction> get quickActions => const [
    DashboardQuickAction(
      label: 'New Entry',
      icon: Icons.add_circle,
      route: '/mandi/entry',
    ),
    DashboardQuickAction(
      label: 'Farmer Ledger',
      icon: Icons.person_pin,
      route: '/mandi/farmers',
    ),
    DashboardQuickAction(
      label: 'Daily Rates',
      icon: Icons.currency_rupee,
      route: '/mandi/rates',
    ),
  ];

  /// Returns configured Mandi dashboard widget types.
  /// Each widget derives its displayed metric from stored Mandi records
  /// (sales summary from CommissionLedger, recent bills from Bills table).
  @override
  List<DashboardWidgetType> get widgets => [
    DashboardWidgetType.salesSummary,
    DashboardWidgetType.recentBills,
  ];
}

// ============================================================================
// 🏭 DEFAULT / OTHER STRATEGY
// ============================================================================
class DefaultDashboardStrategy extends DashboardStrategy {
  final BusinessType _type;
  DefaultDashboardStrategy(this._type);

  BusinessType get type => _type;

  @override
  String get addItemLabel => 'Add Product';

  @override
  IconData get addItemIcon => Icons.add_box_rounded;

  String get dashboardTitle => '${type.displayName} Dashboard';

  List<BusinessCapability> get keyCapabilities => [
    BusinessCapability.useStockManagement,
    BusinessCapability.useBarcodeScanner,
  ];

  List<MenuAction> getMenuActions(BuildContext context) {
    return [
      MenuAction(
        title: 'Make Bill',
        icon: Icons.receipt_long,
        route: '/billing',
        baseColor: FuturisticColors.primary,
      ),
      MenuAction(
        title: 'Stock',
        icon: Icons.inventory_2_rounded,
        route: '/inventory',
        baseColor: FuturisticColors.secondary,
      ),
      MenuAction(
        title: 'Customers',
        icon: Icons.people,
        route: '/customers',
        baseColor: FuturisticColors.accent1,
      ),
      MenuAction(
        title: 'Reports',
        icon: Icons.bar_chart,
        route: '/reports',
        baseColor: FuturisticColors.accent2,
      ),
    ];
  }

  List<DashboardWidget> getWidgets(BuildContext context) => [];

  @override
  List<DashboardQuickAction> get quickActions => [];
  @override
  List<DashboardWidgetType> get widgets => [];
}
