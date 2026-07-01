import 'package:flutter/material.dart';
import '../../../../models/business_type.dart';

/// Abstract Strategy for Dynamic Dashboard UI
abstract class DashboardStrategy {
  String get addItemLabel;
  IconData get addItemIcon;
  List<DashboardQuickAction> get quickActions;
  List<DashboardWidgetType> get widgets;

  /// Returns the specific label for "Customers" (e.g. "Patients" for Clinic)
  String get customerLabel => "Customers";
  IconData get customerIcon => Icons.people_alt_outlined;

  /// Returns the specific label for "Suppliers" (e.g. "Farmers" for Mandi)
  String get supplierLabel => "Suppliers";
}

enum DashboardWidgetType {
  salesSummary,
  lowStockAlert,
  expiringSoon,
  recentBills,
  kotStatus, // Restaurant
  pendingJobs, // Service/Repair
  activeTables, // Restaurant
  todaysAppointments, // Clinic
  fastMovingItems,
}

class DashboardQuickAction {
  final String label;
  final IconData icon;
  final String route;
  final Color? color;

  const DashboardQuickAction({
    required this.label,
    required this.icon,
    required this.route,
    this.color,
  });
}

class DashboardStrategyFactory {
  static final Map<BusinessType, DashboardStrategy> _strategies = {
    // 1. Grocery
    BusinessType.grocery: _GroceryStrategy(),
    // 2. Pharmacy
    BusinessType.pharmacy: _PharmacyStrategy(),
    // 3. Restaurant
    BusinessType.restaurant: _RestaurantStrategy(),
    // 4. Electronics
    BusinessType.electronics: _ElectronicsStrategy(),
    // 5. Mobile Shop
    BusinessType.mobileShop:
        _ElectronicsStrategy(), // Reuse electronics for now
    // 6. Computer Shop
    BusinessType.computerShop: _ServiceStrategy(), // Reuse Service for repairs
    // 7. Hardware
    BusinessType.hardware: _HardwareStrategy(),
    // 8. Service
    BusinessType.service: _ServiceStrategy(),
    // 9. Wholesale
    BusinessType.wholesale: _WholesaleStrategy(),
    // 10. Petrol Pump
    BusinessType.petrolPump: _PetrolPumpStrategy(),
    // 11. Mandi
    BusinessType.vegetablesBroker: _MandiStrategy(),
    // 12. Clinic
    BusinessType.clinic: _ClinicStrategy(),
    // 13. Clothing
    BusinessType.clothing: _ClothingStrategy(),
    // 14. Other
    BusinessType.other: _GroceryStrategy(), // Default
  };

  static DashboardStrategy getStrategy(BusinessType type) {
    return _strategies[type] ?? _GroceryStrategy();
  }
}

// ============================================================================
// CONCRETE STRATEGIES
// ============================================================================

class _GroceryStrategy extends DashboardStrategy {
  @override
  String get addItemLabel => "Add Item";
  @override
  IconData get addItemIcon => Icons.add_shopping_cart;

  @override
  List<DashboardQuickAction> get quickActions => [
    const DashboardQuickAction(
      label: "New Bill",
      icon: Icons.receipt_long,
      route: '/billing',
    ),
    const DashboardQuickAction(
      label: "Stock In",
      icon: Icons.inventory,
      route: '/purchase',
    ),
    const DashboardQuickAction(
      label: "Expiring",
      icon: Icons.timer_off_outlined,
      route: '/expiry',
    ),
  ];

  @override
  List<DashboardWidgetType> get widgets => [
    DashboardWidgetType.salesSummary,
    DashboardWidgetType.lowStockAlert,
    DashboardWidgetType.expiringSoon,
    DashboardWidgetType.recentBills,
  ];
}

class _PharmacyStrategy extends DashboardStrategy {
  @override
  String get addItemLabel => "Add Medicine";
  @override
  IconData get addItemIcon => Icons.medication;
  @override
  String get customerLabel => "Patients";

  @override
  List<DashboardQuickAction> get quickActions => [
    const DashboardQuickAction(
      label: "New Sale",
      icon: Icons.receipt_long,
      route: '/billing',
    ),
    const DashboardQuickAction(
      label: "Upload Rx",
      icon: Icons.upload_file,
      route: '/prescription',
    ),
    const DashboardQuickAction(
      label: "Shortage",
      icon: Icons.warning_amber_rounded,
      route: '/shortage',
    ),
  ];

  @override
  List<DashboardWidgetType> get widgets => [
    DashboardWidgetType.salesSummary,
    DashboardWidgetType.expiringSoon, // Critical for Pharmacy
    DashboardWidgetType.lowStockAlert,
    DashboardWidgetType.recentBills,
  ];
}

class _RestaurantStrategy extends DashboardStrategy {
  @override
  String get addItemLabel => "Add Dish";
  @override
  IconData get addItemIcon => Icons.restaurant_menu;
  @override
  String get customerLabel => "Guests";

  @override
  List<DashboardQuickAction> get quickActions => [
    const DashboardQuickAction(
      label: "Table View",
      icon: Icons.table_restaurant,
      route: '/tables',
    ),
    const DashboardQuickAction(
      label: "KOT",
      icon: Icons.kitchen,
      route: '/kot',
    ),
    const DashboardQuickAction(
      label: "Online Orders",
      icon: Icons.delivery_dining,
      route: '/orders',
    ),
  ];

  @override
  List<DashboardWidgetType> get widgets => [
    DashboardWidgetType.activeTables, // Specific to Restaurant
    DashboardWidgetType.kotStatus,
    DashboardWidgetType.salesSummary,
    DashboardWidgetType.recentBills,
  ];
}

class _ElectronicsStrategy extends DashboardStrategy {
  @override
  String get addItemLabel => "Add Product";
  @override
  IconData get addItemIcon => Icons.devices;

  @override
  List<DashboardQuickAction> get quickActions => [
    const DashboardQuickAction(
      label: "New Bill",
      icon: Icons.receipt_long,
      route: '/billing',
    ),
    const DashboardQuickAction(
      label: "Add IMEI",
      icon: Icons.qr_code_scanner,
      route: '/purchase',
    ),
    const DashboardQuickAction(
      label: "Warranty Check",
      icon: Icons.verified_user,
      route: '/warranty',
    ),
  ];

  @override
  List<DashboardWidgetType> get widgets => [
    DashboardWidgetType.salesSummary,
    DashboardWidgetType.lowStockAlert,
    DashboardWidgetType.recentBills,
  ];
}

class _ServiceStrategy extends DashboardStrategy {
  @override
  String get addItemLabel => "New Job";
  @override
  IconData get addItemIcon => Icons.build;

  @override
  List<DashboardQuickAction> get quickActions => [
    const DashboardQuickAction(
      label: "Create Job",
      icon: Icons.note_add,
      route: '/job/create',
    ),
    const DashboardQuickAction(
      label: "Update Status",
      icon: Icons.update,
      route: '/job/status',
    ),
    const DashboardQuickAction(
      label: "Deliver",
      icon: Icons.done_all,
      route: '/job/deliver',
    ),
  ];

  @override
  List<DashboardWidgetType> get widgets => [
    DashboardWidgetType.pendingJobs, // Specific to Service
    DashboardWidgetType.salesSummary,
    DashboardWidgetType.recentBills,
  ];
}

class _HardwareStrategy extends DashboardStrategy {
  @override
  String get addItemLabel => "Add Item";
  @override
  IconData get addItemIcon => Icons.hardware;

  @override
  List<DashboardQuickAction> get quickActions => [
    const DashboardQuickAction(
      label: "New Invoice",
      icon: Icons.receipt_long,
      route: '/billing',
    ),
    const DashboardQuickAction(
      label: "Estimates",
      icon: Icons.calculate,
      route: '/estimates',
    ),
  ];

  @override
  List<DashboardWidgetType> get widgets => [
    DashboardWidgetType.salesSummary,
    DashboardWidgetType.lowStockAlert,
    DashboardWidgetType.recentBills,
  ];
}

class _WholesaleStrategy extends DashboardStrategy {
  @override
  String get addItemLabel => "Add Bulk Item";
  @override
  IconData get addItemIcon => Icons.layers;
  @override
  String get customerLabel => "Retailers";

  @override
  List<DashboardQuickAction> get quickActions => [
    const DashboardQuickAction(
      label: "New Invoice",
      icon: Icons.receipt_long,
      route: '/billing',
    ),
    const DashboardQuickAction(
      label: "Credit Ledger",
      icon: Icons.account_balance_wallet,
      route: '/ledger',
    ),
    const DashboardQuickAction(
      label: "Challan",
      icon: Icons.local_shipping,
      route: '/challan',
    ),
  ];

  @override
  List<DashboardWidgetType> get widgets => [
    DashboardWidgetType.salesSummary,
    DashboardWidgetType.lowStockAlert,
    DashboardWidgetType.fastMovingItems,
  ];
}

class _MandiStrategy extends DashboardStrategy {
  @override
  String get addItemLabel => "New Entry";
  @override
  IconData get addItemIcon => Icons.eco;
  @override
  String get supplierLabel => "Farmers";

  @override
  List<DashboardQuickAction> get quickActions => [
    const DashboardQuickAction(
      label: "New Entry",
      icon: Icons.add_circle,
      route: '/mandi/entry',
    ),
    const DashboardQuickAction(
      label: "Farmer Ledger",
      icon: Icons.person_pin,
      route: '/mandi/farmers',
    ),
    const DashboardQuickAction(
      label: "Daily Rates",
      icon: Icons.currency_rupee,
      route: '/mandi/rates',
    ),
  ];

  @override
  List<DashboardWidgetType> get widgets => [
    DashboardWidgetType.salesSummary,
    DashboardWidgetType.recentBills,
  ];
}

class _ClinicStrategy extends DashboardStrategy {
  @override
  String get addItemLabel => "Add Patient";
  @override
  IconData get addItemIcon => Icons.person_add;
  @override
  String get customerLabel => "Patients";

  @override
  List<DashboardQuickAction> get quickActions => [
    const DashboardQuickAction(
      label: "New Appt",
      icon: Icons.calendar_today,
      route: '/clinic/appointment',
    ),
    const DashboardQuickAction(
      label: "Prescription",
      icon: Icons.description,
      route: '/clinic/prescription',
    ),
    const DashboardQuickAction(
      label: "Queue",
      icon: Icons.people_outline,
      route: '/clinic/queue',
    ),
  ];

  @override
  List<DashboardWidgetType> get widgets => [
    DashboardWidgetType.todaysAppointments,
    DashboardWidgetType.recentBills,
    DashboardWidgetType.salesSummary,
  ];
}

class _ClothingStrategy extends DashboardStrategy {
  @override
  String get addItemLabel => "Add Apparel";
  @override
  IconData get addItemIcon => Icons.checkroom;

  @override
  List<DashboardQuickAction> get quickActions => [
    const DashboardQuickAction(
      label: "New Sale",
      icon: Icons.receipt_long,
      route: '/billing',
    ),
    const DashboardQuickAction(
      label: "Variants",
      icon: Icons.style,
      route: '/variants',
    ),
    const DashboardQuickAction(
      label: "Stock Check",
      icon: Icons.qr_code,
      route: '/stock_check',
    ),
  ];

  @override
  List<DashboardWidgetType> get widgets => [
    DashboardWidgetType.salesSummary,
    DashboardWidgetType.fastMovingItems,
    DashboardWidgetType.lowStockAlert,
  ];
}

class _PetrolPumpStrategy extends DashboardStrategy {
  @override
  String get addItemLabel => "Add Fuel";
  @override
  IconData get addItemIcon => Icons.local_gas_station;

  @override
  List<DashboardQuickAction> get quickActions => [
    const DashboardQuickAction(
      label: "New Sale",
      icon: Icons.receipt_long,
      route: '/billing',
    ),
    const DashboardQuickAction(
      label: "Reading",
      icon: Icons.speed,
      route: '/pump/reading',
    ),
    const DashboardQuickAction(
      label: "Density",
      icon: Icons.science,
      route: '/pump/density',
    ),
  ];

  @override
  List<DashboardWidgetType> get widgets => [
    DashboardWidgetType.salesSummary,
    DashboardWidgetType.lowStockAlert, // Fuel stock
  ];
}
