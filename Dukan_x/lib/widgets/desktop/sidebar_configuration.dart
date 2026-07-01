import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/futuristic_colors.dart';
import '../../providers/app_state_providers.dart';
import '../../core/isolation/business_capability.dart';
import '../../core/isolation/feature_resolver.dart';
import '../../core/session/session_manager.dart';

/// Sidebar mode enum for expand/collapse/mini states
enum SidebarMode { expanded, collapsed, mini }

/// Sidebar menu item model
class SidebarMenuItem {
  final String id;
  final IconData icon;
  final String label;
  final String? route;
  final VoidCallback? onTap;
  final bool badge;
  final int? badgeCount;
  final BusinessCapability? capability; // Capability required for this item
  final String? permission; // Permission string (future RBAC)

  const SidebarMenuItem({
    required this.id,
    required this.icon,
    required this.label,
    this.route,
    this.onTap,
    this.badge = false,
    this.badgeCount,
    this.capability,
    this.permission,
  });
}

/// Sidebar section model
class SidebarSection {
  final int index;
  final IconData icon;
  final String title;
  final Color? accentColor;
  final List<SidebarMenuItem> items;
  final String? shortcutHint;

  const SidebarSection({
    required this.index,
    required this.icon,
    required this.title,
    this.accentColor,
    required this.items,
    this.shortcutHint,
  });
}

/// Riverpod provider exposing the current user's effective staff-level [UserRole]
/// from the active session.
///
/// Reads from [authStateProvider] so it updates reactively when the session
/// changes (e.g., after role selection or real-time role update).
/// Returns [UserRole.unknown] when no session is available.
final currentUserRoleProvider = Provider<UserRole>((ref) {
  final authState = ref.watch(authStateProvider);
  final session = authState.session;
  if (session == null) return UserRole.unknown;
  return session.effectiveRole;
});

/// Provider that returns the list of sidebar sections filtered by:
/// 1. Business Type (Clinic, Retail, etc.)
/// 2. User Permissions (via Session)
/// 3. Feature Flags (Capabilities)
///
/// This is memoized by Riverpod, so it ONLY re-runs if [businessTypeProvider]
/// or [authStateProvider] changes, NOT on every hover/frame.
final sidebarSectionsProvider = Provider<List<SidebarSection>>((ref) {
  final businessTypeState = ref.watch(businessTypeProvider);
  final authState = ref.watch(authStateProvider);
  final session = authState.session;
  final userRole = ref.watch(currentUserRoleProvider);

  // 1. Get Base Sections
  final allSections = _getSectionsForBusiness(businessTypeState.type);

  // 2. Filter by Capabilities & Permissions
  final typeStr = businessTypeState.type.name;

  return allSections
      .map((section) {
        final filteredItems = section.items.where((item) {
          // Check Capability (FeatureResolver gates — applied BEFORE RBAC)
          if (item.capability != null) {
            if (!FeatureResolver.canAccess(typeStr, item.capability!)) {
              return false;
            }
          }
          // Check Permission (RBAC) — uses RolePermissions.hasPermission()
          if (item.permission != null) {
            if (session == null) return false;
            // Map the permission string to the Permission enum
            final permission = Permission.values.firstWhere(
              (p) => p.name == item.permission,
              orElse: () => Permission
                  .manageSettings, // fallback to restrictive permission
            );
            // Evaluate against user's effective role via RolePermissions matrix
            if (!RolePermissions.hasPermission(userRole, permission)) {
              return false;
            }
          }
          return true;
        }).toList();

        return SidebarSection(
          index: section.index,
          icon: section.icon,
          title: section.title,
          accentColor: section.accentColor,
          shortcutHint: section.shortcutHint,
          items: filteredItems,
        );
      })
      .where((section) => section.items.isNotEmpty)
      .toList();
});

// --- INTERNAL HELPER FUNCTIONS (Extracted from UI) ---

List<SidebarSection> _getSectionsForBusiness(BusinessType type) {
  switch (type) {
    case BusinessType.clinic:
      return _getClinicSections();
    case BusinessType.pharmacy:
      return _getPharmacySections();
    case BusinessType.restaurant:
      return _getRestaurantSections();
    case BusinessType.petrolPump:
      return _getPetrolPumpSections();
    // ELECTRONICS VERTICAL (Phase 4, Task 14 — bugfix.md 2.14, 2.15, 2.16).
    // Electronics is split OUT of the former `electronics + computerShop`
    // grouped case (D5) into its own dedicated `_getElectronicsSections()`,
    // mirroring the structure of `_getMobileShopSections()`. It surfaces the
    // device-relevant entries (Serial/IMEI Tracking, Warranty Register,
    // Service/Repair Jobs, Returns-with-serial) plus the shared common
    // sections, and omits clearly-irrelevant retail-only items by virtue of
    // NOT including the full `_getRetailSections()` list.
    // BLAST RADIUS: Only the electronics case changes. The `computerShop` case
    // below still returns `_getRetailSections()` byte-for-byte unchanged, and
    // `_getRetailSections()` / `_getMobileShopSections()` / the `default`
    // branch are untouched (Preservation 3.1, 3.6).
    case BusinessType.electronics:
      return _getElectronicsSections();
    case BusinessType.computerShop:
      return _getRetailSections();
    // MOBILE SHOP VERTICAL (Task 9.1 — Requirements 7.1, 7.8, 7.10, 1.9, 1.12).
    // Explicit case so the mobile-shop sidebar no longer falls through to
    // `_getRetailSections()`. Returns exactly five mobile-specific entries
    // (Service Jobs, Exchanges, IMEI Tracking, Warranty, Second-Hand Intake)
    // plus the same shared common sections every type receives. Unsupported
    // retail items (proforma_bids, dispatch_notes, return_inwards) are excluded
    // by omission from the dedicated section.
    // BLAST RADIUS: Only this case is added. computerShop keeps its own
    // `_getRetailSections()` case unchanged; electronics now has its own
    // dedicated `_getElectronicsSections()` (Phase 4, Task 14). The `default`
    // branch and every other business-type case remain byte-for-byte unchanged.
    case BusinessType.mobileShop:
      return _getMobileShopSections();
    case BusinessType.service:
      return _getServiceSections();
    // HARDWARE VERTICAL (Task 3.2 — bugfix.md 2.4, 2.11). Additive case so the
    // hardware sidebar no longer falls through to `default: _getRetailSections()`
    // (Bug_Condition 1.4). The `default` branch and `_getRetailSections()` are
    // left UNCHANGED, so every other vertical resolves exactly as before
    // (Preservation 3.1, 3.2).
    case BusinessType.hardware:
      return _getHardwareSections();
    // VEGETABLES BROKER / MANDI VERTICAL (Task 18.1 — Requirement 12.1).
    // Explicit case so the broker sidebar no longer falls through to
    // `default: _getRetailSections()`. Returns exactly five Mandi-specific
    // sections and zero retail sections.
    case BusinessType.vegetablesBroker:
      return _getVegetablesBrokerSections();
    // DECORATION & CATERING VERTICAL (Task 3.5 — Requirements 3.1, 3.2, 3.3).
    // Explicit case so the DC sidebar no longer falls through to
    // `default: _getRetailSections()`. Returns exactly 14 DC-specific sections.
    case BusinessType.decorationCatering:
      return _getDecorationCateringSections();
    // JEWELLERY VERTICAL (Task 2.1 — Requirements 3.1, 3.2, 3.3, 3.4, 1.9, 1.10, 1.12).
    // Explicit case so the jewellery sidebar no longer falls through to
    // `default: _getRetailSections()`. Returns jewellery-specific sections covering
    // Daily Rates, Billing, Inventory, Old Gold Exchange, Custom Orders, Repairs,
    // Gold Schemes, and Making-Charges Calculator.
    // BLAST RADIUS: Only this case is added. The `default` branch and every other
    // business-type case remain byte-for-byte unchanged.
    case BusinessType.jewellery:
      return _getJewellerySections();
    // CLOTHING VERTICAL (Task 5.1 — Requirements 5.1, 5.2, 5.3, 1.8, 1.9).
    // Explicit case so the clothing sidebar no longer falls through to
    // `default: _getRetailSections()`. Returns exactly one dedicated clothing
    // section (Variant Matrix, Tailoring/Alterations, Size & Color Stock
    // Overview, Price-Tag/Barcode Printing) plus the same shared common
    // sections returned for every other type.
    // BLAST RADIUS: Only this case is added. The `default` branch and every
    // other business-type case remain byte-for-byte unchanged.
    case BusinessType.clothing:
      return _getClothingSections();
    // SCHOOL ERP VERTICAL (Task 3.1 — Requirements 4.1, 4.2, 4.3, 4.10, 1.11, 1.12).
    // Explicit case so the school ERP sidebar no longer falls through to
    // `default: _getRetailSections()`. Returns 19 school-specific items
    // across 12 sections (Dashboard, Students & Admissions, Fees, Attendance,
    // Exams & Report Cards, Timetable, Faculty, Transport, Library,
    // Communication, Reports, Certificates). Each item carries a capability gate
    // applied by `sidebarSectionsProvider` via `FeatureResolver.canAccess`.
    // BLAST RADIUS: Only this case is added. The `default` branch and every
    // other business-type case remain byte-for-byte unchanged.
    case BusinessType.schoolErp:
      return _getSchoolSections();
    // BOOK STORE VERTICAL (Task 5.1 — Requirements 5.1, 5.2, 5.3, 1.11, 1.12).
    // Explicit case so the bookStore sidebar no longer falls through to
    // `default: _getRetailSections()` (F1). Returns 5 book-specific items
    // (Book Catalogue, Book POS, Consignments, School Orders, Publisher Returns)
    // each with a stable id, a non-whitespace label, and a BusinessCapability gate.
    // Phase 8 sign-off: Dev_Flag removed — bookStore sidebar is now always live.
    // BLAST RADIUS: Only this case is added. The `default` branch and every
    // other business-type case remain byte-for-byte unchanged.
    case BusinessType.bookStore:
      return _getBookStoreSections();
    default:
      return _getRetailSections();
  }
}

/// Dedicated sidebar for `BusinessType.hardware` (bugfix.md 2.4, 2.11).
///
/// Surfaces the hardware-specific surfaces — Projects/Indents/Deposits,
/// Estimates→Invoice, Delivery Challans, Contractor Credit, Supplier Rate
/// Compare, and Inventory — each item carrying the correct [BusinessCapability]
/// gate. The `sidebarSectionsProvider` applies these gates via
/// `FeatureResolver.canAccess`, so items whose capability is NOT granted to
/// hardware (hard-isolation denials) are filtered out automatically.
///
/// Per bugfix.md 2.11, `proforma_bids` (useProformaInvoice), `dispatch_notes`
/// (useDispatchNote) and `return_inwards` (useSalesReturn) carry their capability
/// gate here so they are hidden for hardware (none of those three capabilities
/// are granted to hardware in `business_capability.dart`). Every screen id below
/// resolves through `SidebarNavigationHandler.getScreenForItem` (the hardware
/// ids were wired in Task 3.1).
List<SidebarSection> _getHardwareSections() {
  return [
    // Projects / Indents / Deposits — the core hardware operations surfaces.
    SidebarSection(
      index: 0,
      icon: Icons.engineering_rounded,
      title: 'Projects, Indents & Deposits',
      accentColor: FuturisticColors.accent1,
      shortcutHint: 'Ctrl+1',
      items: [
        SidebarMenuItem(
          id: 'hardware_operations',
          icon: Icons.account_tree_outlined,
          label: 'Projects & Indents',
        ),
        SidebarMenuItem(
          id: 'hardware_command_center',
          icon: Icons.hub_outlined,
          label: 'Operations Command Center',
        ),
        SidebarMenuItem(
          id: 'hardware_phase12_workspace',
          icon: Icons.dashboard_customize_outlined,
          label: 'Project Workspace',
        ),
      ],
    ),
    // Estimates → Invoice. `proforma_bids` and `return_inwards` are gated by
    // capabilities hardware does NOT hold, so they are filtered out (2.11); the
    // invoice-profile and create-invoice items keep the section reachable.
    SidebarSection(
      index: 1,
      icon: Icons.request_quote_rounded,
      title: 'Estimates → Invoice',
      accentColor: FuturisticColors.success,
      shortcutHint: 'Ctrl+2',
      items: [
        SidebarMenuItem(
          id: 'proforma_bids',
          icon: Icons.description_outlined,
          label: 'Estimates / Quotations',
          capability: BusinessCapability.useProformaInvoice,
        ),
        SidebarMenuItem(
          id: 'hardware_invoice_profile',
          icon: Icons.receipt_outlined,
          label: 'Invoice Profile',
        ),
        SidebarMenuItem(
          id: 'new_sale',
          icon: Icons.point_of_sale_outlined,
          label: 'Convert to Invoice',
          capability: BusinessCapability.useInvoiceCreate,
        ),
        SidebarMenuItem(
          id: 'return_inwards',
          icon: Icons.assignment_return_outlined,
          label: 'Return Inwards',
          capability: BusinessCapability.useSalesReturn,
        ),
      ],
    ),
    // Delivery Challans. `dispatch_notes` is gated by useDispatchNote (not
    // granted to hardware) and filtered out (2.11); `delivery_challans` is gated
    // by useTransportDetails, which hardware DOES hold, so it stays reachable.
    SidebarSection(
      index: 2,
      icon: Icons.local_shipping_rounded,
      title: 'Delivery Challans',
      accentColor: FuturisticColors.warning,
      shortcutHint: 'Ctrl+3',
      items: [
        SidebarMenuItem(
          id: 'delivery_challans',
          icon: Icons.local_shipping_outlined,
          label: 'Delivery Challans',
          capability: BusinessCapability.useTransportDetails,
        ),
        SidebarMenuItem(
          id: 'dispatch_notes',
          icon: Icons.outbox_outlined,
          label: 'Dispatch Notes',
          capability: BusinessCapability.useDispatchNote,
        ),
        // e-Way bill for bulk dispatches exceeding ₹50,000 (bugfix.md 2.14).
        // Gated by useTransportDetails (hardware holds it); the ₹50,000 trigger
        // is enforced inside the screen.
        SidebarMenuItem(
          id: 'eway_bill',
          icon: Icons.fact_check_outlined,
          label: 'e-Way Bill',
          capability: BusinessCapability.useTransportDetails,
        ),
      ],
    ),
    // Contractor Credit. The credit-control screen is gated by useCreditLimit
    // (the contractor-credit feature gate); Party Ledger and Outstanding keep
    // the section reachable regardless of the credit gate decision (Task 3.3).
    SidebarSection(
      index: 3,
      icon: Icons.handshake_rounded,
      title: 'Contractor Credit',
      accentColor: FuturisticColors.error,
      shortcutHint: 'Ctrl+4',
      items: [
        SidebarMenuItem(
          id: 'hardware_credit_control',
          icon: Icons.credit_score_outlined,
          label: 'Contractor Credit Control',
          capability: BusinessCapability.useCreditLimit,
        ),
        SidebarMenuItem(
          id: 'party_ledger',
          icon: Icons.account_balance_wallet_outlined,
          label: 'Party Ledger',
        ),
        SidebarMenuItem(
          id: 'outstanding',
          icon: Icons.pending_actions_outlined,
          label: 'Outstanding Reports',
        ),
      ],
    ),
    // Supplier Rate Compare. Gated by useSupplierBill, which hardware holds.
    SidebarSection(
      index: 4,
      icon: Icons.compare_arrows_rounded,
      title: 'Supplier Rate Compare',
      accentColor: FuturisticColors.accent2,
      shortcutHint: 'Ctrl+5',
      items: [
        SidebarMenuItem(
          id: 'hardware_supplier_management',
          icon: Icons.price_change_outlined,
          label: 'Supplier Rate Compare',
          capability: BusinessCapability.useSupplierBill,
        ),
        SidebarMenuItem(
          id: 'supplier_bills',
          icon: Icons.request_quote_outlined,
          label: 'Supplier Bills',
          capability: BusinessCapability.useSupplierBill,
        ),
        SidebarMenuItem(
          id: 'suppliers',
          icon: Icons.storefront_outlined,
          label: 'Suppliers',
        ),
      ],
    ),
    // Inventory. Gated by the inventory/stock capabilities hardware holds.
    SidebarSection(
      index: 5,
      icon: Icons.inventory_2_rounded,
      title: 'Inventory',
      accentColor: FuturisticColors.primary,
      shortcutHint: 'Ctrl+6',
      items: [
        SidebarMenuItem(
          id: 'stock_summary',
          icon: Icons.summarize_outlined,
          label: 'Stock Summary',
          capability: BusinessCapability.useInventoryList,
        ),
        SidebarMenuItem(
          id: 'item_stock',
          icon: Icons.category_outlined,
          label: 'Item-wise Stock',
          capability: BusinessCapability.useInventoryList,
        ),
        SidebarMenuItem(
          id: 'low_stock',
          icon: Icons.warning_amber_outlined,
          label: 'Low Stock Alerts',
          capability: BusinessCapability.useLowStockAlert,
          badge: true,
        ),
        SidebarMenuItem(
          id: 'stock_valuation',
          icon: Icons.price_check_outlined,
          label: 'Stock Valuation',
        ),
      ],
    ),
  ];
}

/// Dedicated sidebar for `BusinessType.vegetablesBroker` (Requirement 12.1).
///
/// Returns exactly five Mandi-specific sections — Lot Register, Farmer Ledger,
/// Commission Report, Settlement/Patti, Rate Board — and zero retail sections.
/// Each item id will be wired to the corresponding Phase 3 screen via
/// `SidebarNavigationHandler` in task 18.2.
List<SidebarSection> _getVegetablesBrokerSections() {
  return [
    SidebarSection(
      index: 0,
      icon: Icons.agriculture_rounded,
      title: 'Lot Register',
      accentColor: FuturisticColors.accent1,
      shortcutHint: 'Ctrl+1',
      items: [
        SidebarMenuItem(
          id: 'mandi_lot_register',
          icon: Icons.list_alt_outlined,
          label: 'Lot Register',
        ),
      ],
    ),
    SidebarSection(
      index: 1,
      icon: Icons.people_alt_rounded,
      title: 'Farmer Ledger',
      accentColor: FuturisticColors.primary,
      shortcutHint: 'Ctrl+2',
      items: [
        SidebarMenuItem(
          id: 'mandi_farmer_ledger',
          icon: Icons.account_balance_wallet_outlined,
          label: 'Farmer Ledger',
        ),
      ],
    ),
    SidebarSection(
      index: 2,
      icon: Icons.receipt_long_rounded,
      title: 'Commission Report',
      accentColor: FuturisticColors.success,
      shortcutHint: 'Ctrl+3',
      items: [
        SidebarMenuItem(
          id: 'mandi_commission_report',
          icon: Icons.analytics_outlined,
          label: 'Commission Report',
        ),
      ],
    ),
    SidebarSection(
      index: 3,
      icon: Icons.handshake_rounded,
      title: 'Settlement / Patti',
      accentColor: FuturisticColors.warning,
      shortcutHint: 'Ctrl+4',
      items: [
        SidebarMenuItem(
          id: 'mandi_settlement',
          icon: Icons.summarize_outlined,
          label: 'Settlement / Patti',
        ),
      ],
    ),
    SidebarSection(
      index: 4,
      icon: Icons.show_chart_rounded,
      title: 'Rate Board',
      accentColor: FuturisticColors.accent2,
      shortcutHint: 'Ctrl+5',
      items: [
        SidebarMenuItem(
          id: 'mandi_rate_board',
          icon: Icons.price_change_outlined,
          label: 'Rate Board',
        ),
      ],
    ),
  ];
}

/// Dedicated sidebar for `BusinessType.decorationCatering` (Requirements 3.1, 3.2, 3.3).
///
/// Returns exactly 14 sections — Dashboard, Bookings, Calendar, Quotes,
/// Catering/Menu, Decoration/Themes, Staff, Attendance, Vendors & Payments,
/// Inventory/Rentals, Shopping List, Billing, Profitability, Reports — each
/// with a non-empty label and a sidebar-reachable navigation target.
/// Item ids will be wired in `SidebarNavigationHandler` (task 3.9).
List<SidebarSection> _getDecorationCateringSections() {
  return [
    SidebarSection(
      index: 0,
      icon: Icons.space_dashboard_rounded,
      title: 'Dashboard',
      accentColor: FuturisticColors.accent1,
      shortcutHint: 'Ctrl+1',
      items: [
        SidebarMenuItem(
          id: 'dc_dashboard',
          icon: Icons.dashboard_customize_outlined,
          label: 'Dashboard',
        ),
      ],
    ),
    SidebarSection(
      index: 1,
      icon: Icons.event_available_rounded,
      title: 'Bookings',
      accentColor: FuturisticColors.primary,
      shortcutHint: 'Ctrl+2',
      items: [
        SidebarMenuItem(
          id: 'dc_bookings',
          icon: Icons.event_note_outlined,
          label: 'Bookings',
        ),
      ],
    ),
    SidebarSection(
      index: 2,
      icon: Icons.calendar_month_rounded,
      title: 'Calendar',
      accentColor: FuturisticColors.success,
      shortcutHint: 'Ctrl+3',
      items: [
        SidebarMenuItem(
          id: 'dc_calendar',
          icon: Icons.calendar_today_outlined,
          label: 'Calendar',
        ),
      ],
    ),
    SidebarSection(
      index: 3,
      icon: Icons.request_quote_rounded,
      title: 'Quotes',
      accentColor: FuturisticColors.warning,
      items: [
        SidebarMenuItem(
          id: 'dc_quotes',
          icon: Icons.description_outlined,
          label: 'Quotes',
        ),
      ],
    ),
    SidebarSection(
      index: 4,
      icon: Icons.restaurant_menu_rounded,
      title: 'Catering / Menu',
      accentColor: FuturisticColors.error,
      items: [
        SidebarMenuItem(
          id: 'dc_catering_menu',
          icon: Icons.menu_book_outlined,
          label: 'Catering / Menu',
        ),
      ],
    ),
    SidebarSection(
      index: 5,
      icon: Icons.palette_rounded,
      title: 'Decoration / Themes',
      accentColor: FuturisticColors.accent2,
      items: [
        SidebarMenuItem(
          id: 'dc_decoration_themes',
          icon: Icons.color_lens_outlined,
          label: 'Decoration / Themes',
        ),
      ],
    ),
    SidebarSection(
      index: 6,
      icon: Icons.people_alt_rounded,
      title: 'Staff',
      accentColor: FuturisticColors.primary,
      items: [
        SidebarMenuItem(
          id: 'dc_staff',
          icon: Icons.badge_outlined,
          label: 'Staff',
        ),
      ],
    ),
    SidebarSection(
      index: 7,
      icon: Icons.fact_check_rounded,
      title: 'Attendance',
      accentColor: FuturisticColors.success,
      items: [
        SidebarMenuItem(
          id: 'dc_attendance',
          icon: Icons.checklist_outlined,
          label: 'Attendance',
        ),
      ],
    ),
    SidebarSection(
      index: 8,
      icon: Icons.handshake_rounded,
      title: 'Vendors & Payments',
      accentColor: FuturisticColors.warning,
      items: [
        SidebarMenuItem(
          id: 'dc_vendor_payments',
          icon: Icons.payments_outlined,
          label: 'Vendors & Payments',
        ),
      ],
    ),
    SidebarSection(
      index: 9,
      icon: Icons.inventory_2_rounded,
      title: 'Inventory / Rentals',
      accentColor: FuturisticColors.accent1,
      items: [
        SidebarMenuItem(
          id: 'dc_inventory_rentals',
          icon: Icons.category_outlined,
          label: 'Inventory / Rentals',
        ),
      ],
    ),
    SidebarSection(
      index: 10,
      icon: Icons.shopping_cart_rounded,
      title: 'Shopping List',
      accentColor: FuturisticColors.error,
      items: [
        SidebarMenuItem(
          id: 'dc_shopping_list',
          icon: Icons.checklist_rtl_outlined,
          label: 'Shopping List',
        ),
      ],
    ),
    SidebarSection(
      index: 11,
      icon: Icons.receipt_long_rounded,
      title: 'Billing',
      accentColor: FuturisticColors.accent2,
      items: [
        SidebarMenuItem(
          id: 'dc_billing',
          icon: Icons.receipt_outlined,
          label: 'Billing',
        ),
      ],
    ),
    SidebarSection(
      index: 12,
      icon: Icons.trending_up_rounded,
      title: 'Profitability',
      accentColor: FuturisticColors.success,
      items: [
        SidebarMenuItem(
          id: 'dc_profitability',
          icon: Icons.analytics_outlined,
          label: 'Profitability',
        ),
      ],
    ),
    SidebarSection(
      index: 13,
      icon: Icons.assessment_rounded,
      title: 'Reports',
      accentColor: FuturisticColors.primary,
      items: [
        SidebarMenuItem(
          id: 'dc_reports',
          icon: Icons.summarize_outlined,
          label: 'Reports',
        ),
      ],
    ),
  ];
}

/// Dedicated sidebar for `BusinessType.clothing` (Task 5.1 — Requirements 5.1, 5.2, 5.3).
///
/// Returns exactly one dedicated clothing section containing 4 items — Variant Matrix,
/// Tailoring / Alterations, Size & Color Stock Overview, Price-Tag / Barcode Printing —
/// plus the same shared common sections (`_getCommonSections`) returned for every other
/// `BusinessType` (petrol pump, pharmacy, etc.).
///
/// Each item carries a non-empty label and a sidebar id that resolves via
/// `SidebarNavigationHandler.getScreenForItem` to an existing screen (no placeholder
/// routes). Capability gates are applied in the next task (5.2).
///
/// BLAST RADIUS: This function is NEW. It does not modify any other business type's
/// section list, the `default` branch, or `_getRetailSections()`.
/// Shared file touched: `sidebar_configuration.dart` — added `case BusinessType.clothing`
/// and this function. No other case or the default branch was modified.
List<SidebarSection> _getClothingSections() {
  return [
    // Dedicated clothing section — the 4 clothing-specific items.
    SidebarSection(
      index: 0,
      icon: Icons.checkroom_rounded,
      title: 'Clothing Management',
      accentColor: FuturisticColors.accent1,
      shortcutHint: 'Ctrl+1',
      items: [
        SidebarMenuItem(
          id: 'clothing_variant_matrix',
          icon: Icons.grid_view_outlined,
          label: 'Variant Matrix',
          capability: BusinessCapability.useVariants,
        ),
        SidebarMenuItem(
          id: 'clothing_tailoring',
          icon: Icons.straighten_outlined,
          label: 'Tailoring / Alterations',
          capability: BusinessCapability.useTailoringNotes,
        ),
        SidebarMenuItem(
          id: 'clothing_stock_overview',
          icon: Icons.inventory_2_outlined,
          label: 'Size & Color Stock Overview',
          capability: BusinessCapability.useVariants,
        ),
        SidebarMenuItem(
          id: 'clothing_tag_printing',
          icon: Icons.label_outlined,
          label: 'Price-Tag / Barcode Printing',
          capability: BusinessCapability.useBarcodeScanner,
        ),
      ],
    ),
    // Shared common sections — identical to what petrol pump, pharmacy, etc. get.
    ..._getCommonSections(startingIndex: 1),
  ];
}

/// Dedicated sidebar for `BusinessType.jewellery` (Requirements 3.1, 3.2, 3.3, 3.4).
///
/// Returns jewellery-specific sections covering exactly: Daily Rates (gold rate,
/// gold-rate alert), Billing, Inventory (hallmark + weight stock), Old Gold Exchange,
/// Custom Orders, Repairs, Gold Schemes, and Making-Charges Calculator. Each item
/// carries a non-empty label and a navigation target (item id) that resolves in
/// `SidebarNavigationHandler.getScreenForItem` (wired in task 2.3).
///
/// Each gated item carries the matching [BusinessCapability] so that
/// `FeatureResolver.canAccess` in [sidebarSectionsProvider] permits granted items
/// and filters ungranted ones (Requirements 9.3, 9.4 — task 6.2).
///
/// BLAST RADIUS: This function is NEW. It does not modify any other business type's
/// section list, the `default` branch, or `_getRetailSections()`.
///
/// ---
/// RETAIL-ORIGIN ITEM RECONCILIATION REPORT (Task 6.3 — Requirements 10.1, 10.2, 10.4)
///
/// Since `_getJewellerySections()` REPLACES the retail section list for
/// `BusinessType.jewellery`, the following retail-origin items are ABSENT from
/// the jewellery sidebar by design — they cannot leak because they are never
/// included in this function's return value:
///
///   | Retail Item       | Status  | Reason                                       |
///   |-------------------|---------|----------------------------------------------|
///   | return_inwards    | REMOVED | Not present in _getJewellerySections()       |
///   | proforma_bids     | REMOVED | Not present in _getJewellerySections()       |
///   | dispatch_notes    | REMOVED | Not present in _getJewellerySections()       |
///   | booking_orders    | REMOVED | Not present in _getJewellerySections()       |
///   | low_stock         | REMOVED | Not present in _getJewellerySections()       |
///
/// Reconciliation status: COMPLETE — all 5 items accounted for (removed).
/// None of the 5 items are "neither gated nor removed"; no unresolved items.
///
/// ROUTE GUARD RE-VERIFICATION (Task 6.3 — Requirement 10.3)
///
/// All 8 jewellery GoRoutes in `lib/core/routing/legacy_routes.dart` (lines
/// 2491–2583) verified to carry BOTH:
///   1. VendorRoleGuard (with requiredPermission: Permissions.viewInvoices)
///   2. BusinessGuard(allowedTypes: const [BusinessType.jewellery])
///
///   | Route path                    | VendorRoleGuard | BusinessGuard(jewellery) |
///   |-------------------------------|:---------------:|:-----------------------:|
///   | /jewellery-gold-rate          |       ✓         |           ✓             |
///   | /jewellery-gold-rate-alert    |       ✓         |           ✓             |
///   | /jewellery-making-charges     |       ✓         |           ✓             |
///   | /jewellery-hallmark           |       ✓         |           ✓             |
///   | /jewellery-old-gold-exchange  |       ✓         |           ✓             |
///   | /jewellery-custom-orders      |       ✓         |           ✓             |
///   | /jewellery-repair             |       ✓         |           ✓             |
///   | /jewellery-gold-scheme        |       ✓         |           ✓             |
///
/// Guard re-verification status: PASS — all 8 routes carry both guards.
/// ---
List<SidebarSection> _getJewellerySections() {
  return [
    // Daily Rates — gold rate management and gold-rate alerts.
    SidebarSection(
      index: 0,
      icon: Icons.currency_rupee_rounded,
      title: 'Daily Rates',
      accentColor: FuturisticColors.accent1,
      shortcutHint: 'Ctrl+1',
      items: [
        SidebarMenuItem(
          id: 'jewellery_gold_rate',
          icon: Icons.price_change_outlined,
          label: 'Gold Rate Management',
          capability: BusinessCapability.useGoldRate,
        ),
        SidebarMenuItem(
          id: 'jewellery_gold_rate_alert',
          icon: Icons.notifications_active_outlined,
          label: 'Gold Rate Alerts',
          capability: BusinessCapability.useGoldRateAlert,
        ),
      ],
    ),
    // Billing — shared live billing surface for jewellery.
    SidebarSection(
      index: 1,
      icon: Icons.point_of_sale_rounded,
      title: 'Billing',
      accentColor: FuturisticColors.success,
      shortcutHint: 'Ctrl+2',
      items: [
        SidebarMenuItem(
          id: 'new_sale',
          icon: Icons.receipt_long_outlined,
          label: 'Create Invoice',
          capability: BusinessCapability.useInvoiceCreate,
        ),
      ],
    ),
    // Inventory — hallmark register and weight-based stock.
    SidebarSection(
      index: 2,
      icon: Icons.inventory_2_rounded,
      title: 'Inventory',
      accentColor: FuturisticColors.primary,
      shortcutHint: 'Ctrl+3',
      items: [
        SidebarMenuItem(
          id: 'jewellery_hallmark',
          icon: Icons.verified_outlined,
          label: 'Hallmark Register',
          capability: BusinessCapability.useHallmark,
        ),
        SidebarMenuItem(
          id: 'stock_summary',
          icon: Icons.summarize_outlined,
          label: 'Stock by Weight',
          capability: BusinessCapability.useInventoryList,
        ),
      ],
    ),
    // Old Gold Exchange — purchase/exchange of old gold from customers.
    SidebarSection(
      index: 3,
      icon: Icons.swap_horiz_rounded,
      title: 'Old Gold Exchange',
      accentColor: FuturisticColors.warning,
      shortcutHint: 'Ctrl+4',
      items: [
        SidebarMenuItem(
          id: 'jewellery_old_gold_exchange',
          icon: Icons.currency_exchange_outlined,
          label: 'Old Gold Exchange',
          capability: BusinessCapability.useOldGoldExchange,
        ),
      ],
    ),
    // Custom Orders — manage custom jewellery orders.
    SidebarSection(
      index: 4,
      icon: Icons.design_services_rounded,
      title: 'Custom Orders',
      accentColor: FuturisticColors.accent2,
      shortcutHint: 'Ctrl+5',
      items: [
        SidebarMenuItem(
          id: 'jewellery_custom_orders',
          icon: Icons.architecture_outlined,
          label: 'Custom Orders',
          capability: BusinessCapability.useCustomOrders,
        ),
      ],
    ),
    // Repairs — jewellery repair job tracking.
    SidebarSection(
      index: 5,
      icon: Icons.build_rounded,
      title: 'Repairs',
      accentColor: FuturisticColors.error,
      shortcutHint: 'Ctrl+6',
      items: [
        SidebarMenuItem(
          id: 'jewellery_repair',
          icon: Icons.build_circle_outlined,
          label: 'Jewellery Repairs',
          capability: BusinessCapability.useJewelleryRepair,
        ),
      ],
    ),
    // Gold Schemes — recurring gold savings schemes.
    SidebarSection(
      index: 6,
      icon: Icons.savings_rounded,
      title: 'Gold Schemes',
      accentColor: FuturisticColors.accent1,
      shortcutHint: 'Ctrl+7',
      items: [
        SidebarMenuItem(
          id: 'jewellery_gold_scheme',
          icon: Icons.account_balance_outlined,
          label: 'Gold Schemes',
          capability: BusinessCapability.useGoldSchemes,
        ),
      ],
    ),
    // Making-Charges Calculator — calculate making charges for jewellery items.
    SidebarSection(
      index: 7,
      icon: Icons.calculate_rounded,
      title: 'Making-Charges Calculator',
      accentColor: FuturisticColors.textSecondary,
      shortcutHint: 'Ctrl+8',
      items: [
        SidebarMenuItem(
          id: 'jewellery_making_charges',
          icon: Icons.calculate_outlined,
          label: 'Making Charges Calculator',
          capability: BusinessCapability.useMakingCharges,
        ),
      ],
    ),
  ];
}

List<SidebarSection> _getClinicSections() {
  return [
    SidebarSection(
      index: 0,
      icon: Icons.space_dashboard_rounded,
      title: 'Clinic Dashboard',
      accentColor: FuturisticColors.accent1,
      shortcutHint: 'Ctrl+1',
      items: [
        SidebarMenuItem(
          id: 'clinic_dashboard',
          icon: Icons.dashboard_customize_outlined,
          label: 'Overview',
        ),
        SidebarMenuItem(
          id: 'daily_appointments',
          icon: Icons.calendar_today_outlined,
          label: 'Today\'s Schedule',
          badge: true,
        ),
      ],
    ),
    SidebarSection(
      index: 1,
      icon: Icons.personal_injury_outlined,
      title: 'Patient Management',
      accentColor: FuturisticColors.primary,
      shortcutHint: 'Ctrl+2',
      items: [
        SidebarMenuItem(
          id: 'patients_list',
          icon: Icons.people_outline,
          label: 'All Patients',
        ),
        SidebarMenuItem(
          id: 'add_patient',
          icon: Icons.person_add_outlined,
          label: 'Register Patient',
        ),
        SidebarMenuItem(
          id: 'patient_history',
          icon: Icons.history_edu_outlined,
          label: 'Patient History',
        ),
        SidebarMenuItem(
          id: 'scan_qr',
          icon: Icons.qr_code_scanner_outlined,
          label: 'Scan Patient QR',
          capability: BusinessCapability.usePatientRegistry,
        ),
      ],
    ),
    SidebarSection(
      index: 2,
      icon: Icons.medical_services_outlined,
      title: 'Clinical Desk',
      accentColor: FuturisticColors.error,
      shortcutHint: 'Ctrl+3',
      items: [
        SidebarMenuItem(
          id: 'appointments',
          icon: Icons.event_note_outlined,
          label: 'Appointments',
        ),
        SidebarMenuItem(
          id: 'patient_queue',
          icon: Icons.format_list_numbered_outlined,
          label: 'Token / Queue',
          capability: BusinessCapability.usePatientRegistry,
        ),
        SidebarMenuItem(
          id: 'clinic_calendar',
          icon: Icons.calendar_month_outlined,
          label: 'Calendar',
          capability: BusinessCapability.usePatientRegistry,
        ),
        SidebarMenuItem(
          id: 'prescriptions',
          icon: Icons.description_outlined,
          label: 'Prescriptions',
          capability: BusinessCapability.usePrescription,
        ),
        SidebarMenuItem(
          id: 'medicine_master',
          icon: Icons.medication_outlined,
          label: 'Medicine Master',
          capability: BusinessCapability.usePrescription,
        ),
        SidebarMenuItem(
          id: 'lab_reports',
          icon: Icons.science_outlined,
          label: 'Lab Reports',
        ),
        SidebarMenuItem(
          id: 'doctor_revenue',
          icon: Icons.monetization_on_outlined,
          label: 'Revenue Analytics',
        ),
      ],
    ),
    SidebarSection(
      index: 3,
      icon: Icons.point_of_sale_rounded,
      title: 'Billing & Revenue',
      accentColor: FuturisticColors.success,
      shortcutHint: 'Ctrl+4',
      items: [
        SidebarMenuItem(
          id: 'new_sale',
          icon: Icons.receipt_long_outlined,
          label: 'Create Bill',
        ),
        SidebarMenuItem(
          id: 'revenue_overview',
          icon: Icons.analytics_outlined,
          label: 'Revenue Overview',
        ),
      ],
    ),
    // Reports & Accounts (Phase 3, Req 2.17). These ids already resolve in
    // SidebarNavigationHandler — this is config-only exposure for the clinic
    // vertical so financial/operational tooling is reachable from the sidebar.
    SidebarSection(
      index: 4,
      icon: Icons.account_balance_rounded,
      title: 'Reports & Accounts',
      accentColor: FuturisticColors.accent2,
      shortcutHint: 'Ctrl+5',
      items: [
        SidebarMenuItem(
          id: 'expenses',
          icon: Icons.money_off_outlined,
          label: 'Expenses',
          permission: 'viewReports',
        ),
        SidebarMenuItem(
          id: 'daybook',
          icon: Icons.menu_book_outlined,
          label: 'Day Book',
        ),
        SidebarMenuItem(
          id: 'accounting_reports',
          icon: Icons.summarize_outlined,
          label: 'Accounting Reports',
          permission: 'viewReports',
        ),
        SidebarMenuItem(
          id: 'outstanding',
          icon: Icons.pending_actions_outlined,
          label: 'Receivables',
        ),
        SidebarMenuItem(
          id: 'backup',
          icon: Icons.backup_outlined,
          label: 'Backup',
          permission: 'manageSettings',
        ),
      ],
    ),
    // Utilities
    SidebarSection(
      index: 5,
      icon: Icons.settings_applications_rounded,
      title: 'System',
      accentColor: FuturisticColors.textSecondary,
      items: [
        SidebarMenuItem(
          // Relabeled (Phase 6, Req 9.3): opens BackupScreen (titled "Backup &
          // Sync"), not a standalone sync-status dashboard. itemId/route kept.
          id: 'sync_status',
          icon: Icons.cloud_sync_outlined,
          label: 'Backup & Sync',
        ),
        SidebarMenuItem(
          id: 'device_settings',
          icon: Icons.devices_outlined,
          label: 'Settings',
        ),
      ],
    ),
  ];
}

List<SidebarSection> _getServiceSections() {
  return [
    SidebarSection(
      index: 0,
      icon: Icons.space_dashboard_rounded,
      title: 'Service Dashboard',
      accentColor: FuturisticColors.accent1,
      shortcutHint: 'Ctrl+1',
      items: [
        SidebarMenuItem(
          id: 'executive_dashboard',
          icon: Icons.dashboard_customize_outlined,
          label: 'Overview',
        ),
        SidebarMenuItem(
          id: 'daily_activity',
          icon: Icons.calendar_today_outlined,
          label: 'Daily Activity',
          badge: true,
        ),
        SidebarMenuItem(
          id: 'daily_snapshot',
          icon: Icons.today_outlined,
          label: 'Daily Snapshot',
        ),
      ],
    ),
    SidebarSection(
      index: 1,
      icon: Icons.point_of_sale_rounded,
      title: 'Billing Desk',
      accentColor: FuturisticColors.success,
      shortcutHint: 'Ctrl+2',
      items: [
        SidebarMenuItem(
          id: 'new_sale',
          icon: Icons.receipt_long_outlined,
          label: 'Create Invoice',
        ),
        SidebarMenuItem(
          id: 'revenue_overview',
          icon: Icons.analytics_outlined,
          label: 'Revenue Overview',
        ),
        SidebarMenuItem(
          id: 'receipt_entry',
          icon: Icons.payment_outlined,
          label: 'Receipt Entry',
        ),
        SidebarMenuItem(
          id: 'sales_register',
          icon: Icons.menu_book_outlined,
          label: 'Invoice History',
        ),
        SidebarMenuItem(
          id: 'proforma_bids',
          icon: Icons.description_outlined,
          label: 'Quotes / Estimates',
        ),
      ],
    ),
    SidebarSection(
      index: 2,
      icon: Icons.build_rounded,
      title: 'Service & Repairs',
      accentColor: FuturisticColors.warning,
      shortcutHint: 'Ctrl+3',
      items: [
        SidebarMenuItem(
          id: 'service_jobs',
          icon: Icons.build_circle_outlined,
          label: 'Service Jobs',
        ),
        SidebarMenuItem(
          id: 'exchanges',
          icon: Icons.swap_horiz_outlined,
          label: 'Device Exchanges',
        ),
      ],
    ),
    ..._getCommonSections(startingIndex: 3),
  ];
}

List<SidebarSection> _getRetailSections() {
  return [
    SidebarSection(
      index: 0,
      icon: Icons.space_dashboard_rounded,
      title: 'Dashboard & Control',
      accentColor: FuturisticColors.accent1,
      shortcutHint: 'Ctrl+1',
      items: [
        SidebarMenuItem(
          id: 'executive_dashboard',
          icon: Icons.dashboard_customize_outlined,
          label: 'Executive Dashboard',
        ),
        SidebarMenuItem(
          id: 'live_health',
          icon: Icons.monitor_heart_outlined,
          label: 'Live Business Health',
        ),
        SidebarMenuItem(
          id: 'alerts',
          icon: Icons.notifications_active_outlined,
          label: 'Alerts & Notifications',
          badge: true,
        ),
        SidebarMenuItem(
          id: 'daily_snapshot',
          icon: Icons.today_outlined,
          label: 'Daily Snapshot',
        ),
      ],
    ),
    SidebarSection(
      index: 1,
      icon: Icons.point_of_sale_rounded,
      title: 'Revenue Desk',
      accentColor: FuturisticColors.success,
      shortcutHint: 'Ctrl+2',
      items: [
        SidebarMenuItem(
          id: 'revenue_overview',
          icon: Icons.analytics_outlined,
          label: 'Revenue Overview',
        ),
        SidebarMenuItem(
          id: 'new_sale',
          icon: Icons.add_shopping_cart_outlined,
          label: 'Invoice / Bill Creation',
        ),
        SidebarMenuItem(
          id: 'receipt_entry',
          icon: Icons.receipt_long_outlined,
          label: 'Receipt Entry',
        ),
        SidebarMenuItem(
          id: 'return_inwards',
          icon: Icons.assignment_return_outlined,
          label: 'Return Inwards',
        ),
        SidebarMenuItem(
          id: 'proforma_bids',
          icon: Icons.description_outlined,
          label: 'Proforma & Bids',
        ),
        SidebarMenuItem(
          id: 'booking_orders',
          icon: Icons.bookmark_add_outlined,
          label: 'Booking Orders',
        ),
        SidebarMenuItem(
          id: 'dispatch_notes',
          icon: Icons.local_shipping_outlined,
          label: 'Dispatch Notes',
        ),
        SidebarMenuItem(
          id: 'sales_register',
          icon: Icons.menu_book_outlined,
          label: 'Sales Register',
        ),
      ],
    ),
    SidebarSection(
      index: 2,
      icon: Icons.shopping_bag_rounded,
      title: 'BuyFlow',
      accentColor: FuturisticColors.warning,
      shortcutHint: 'Ctrl+3',
      items: [
        SidebarMenuItem(
          id: 'buyflow_dashboard',
          icon: Icons.dashboard_outlined,
          label: 'BuyFlow Dashboard',
        ),
        SidebarMenuItem(
          id: 'purchase_orders',
          icon: Icons.shopping_cart_checkout_outlined,
          label: 'Purchase Orders',
        ),
        SidebarMenuItem(
          id: 'stock_entry',
          icon: Icons.add_box_outlined,
          label: 'Stock Entry',
        ),
        SidebarMenuItem(
          id: 'stock_reversal',
          icon: Icons.replay_outlined,
          label: 'Stock Reversal',
        ),
        SidebarMenuItem(
          id: 'procurement_log',
          icon: Icons.history_outlined,
          label: 'Procurement Log',
        ),
        SidebarMenuItem(
          id: 'supplier_bills',
          icon: Icons.request_quote_outlined,
          label: 'Supplier Bills',
        ),
        SidebarMenuItem(
          id: 'purchase_register',
          icon: Icons.menu_book_outlined,
          label: 'Purchase Register',
        ),
        // OCR "Scan Bill / Purchase Entry" (Phase 5, Task 6.2). Reuses the
        // existing AWS Textract Smart Inventory Import pipeline via the
        // go_router `scan_bill` route. Capability-gated by `useScanOCR`, so
        // `sidebarSectionsProvider` shows it ONLY to retail-default types
        // granted that capability (grocery, clothing, electronics, bookStore)
        // and hides it for the rest — additive, no other type's menu changes.
        SidebarMenuItem(
          id: 'scan_bill',
          icon: Icons.document_scanner_outlined,
          label: 'Scan Bill / Purchase Entry',
          capability: BusinessCapability.useScanOCR,
        ),
      ],
    ),
    SidebarSection(
      index: 3,
      icon: Icons.inventory_2_rounded,
      title: 'Inventory & Stock',
      accentColor: FuturisticColors.primary,
      shortcutHint: 'Ctrl+4',
      items: [
        SidebarMenuItem(
          id: 'stock_summary',
          icon: Icons.summarize_outlined,
          label: 'Stock Summary',
        ),
        SidebarMenuItem(
          id: 'item_stock',
          icon: Icons.category_outlined,
          label: 'Item-wise Stock',
        ),
        SidebarMenuItem(
          id: 'batch_tracking',
          icon: Icons.layers_outlined,
          label: 'Batch / Variant Tracking',
          capability: BusinessCapability.useBatchExpiry,
        ),
        SidebarMenuItem(
          id: 'low_stock',
          icon: Icons.warning_amber_outlined,
          label: 'Low Stock Alerts',
          badge: true,
        ),
        SidebarMenuItem(
          id: 'stock_valuation',
          icon: Icons.price_check_outlined,
          label: 'Stock Valuation',
        ),
        SidebarMenuItem(
          id: 'damage_logs',
          icon: Icons.delete_sweep_outlined,
          label: 'Damage / Adjustment',
        ),
      ],
    ),
    SidebarSection(
      index: 4,
      icon: Icons.people_alt_rounded,
      title: 'Parties & Ledger',
      accentColor: FuturisticColors.accent2,
      shortcutHint: 'Ctrl+5',
      items: [
        SidebarMenuItem(
          id: 'customers',
          icon: Icons.person_outline,
          label: 'Customers',
        ),
        SidebarMenuItem(
          id: 'suppliers',
          icon: Icons.storefront_outlined,
          label: 'Suppliers',
        ),
        SidebarMenuItem(
          id: 'party_ledger',
          icon: Icons.account_balance_wallet_outlined,
          label: 'Party Ledger',
        ),
        SidebarMenuItem(
          id: 'ledger_history',
          icon: Icons.history_edu_outlined,
          label: 'Master Ledger History',
        ),
        SidebarMenuItem(
          id: 'ledger_abstract',
          icon: Icons.list_alt_outlined,
          label: 'Ledger Abstract',
        ),
        SidebarMenuItem(
          id: 'outstanding',
          icon: Icons.pending_actions_outlined,
          label: 'Outstanding Reports',
        ),
      ],
    ),
    SidebarSection(
      index: 5,
      icon: Icons.insights_rounded,
      title: 'Business Intelligence',
      accentColor: const Color(0xFF00D4FF),
      shortcutHint: 'Ctrl+6',
      items: [
        SidebarMenuItem(
          id: 'analytics_hub',
          icon: Icons.hub_outlined,
          label: 'Analytics Hub',
        ),
        SidebarMenuItem(
          id: 'turnover_analysis',
          icon: Icons.trending_up_outlined,
          label: 'Turnover Analysis',
        ),
        SidebarMenuItem(
          id: 'product_performance',
          icon: Icons.auto_graph_outlined,
          label: 'Product Performance',
        ),
        SidebarMenuItem(
          id: 'daily_activity',
          icon: Icons.calendar_today_outlined,
          label: 'Daily Activity Register',
        ),
        SidebarMenuItem(
          id: 'procurement_insights',
          icon: Icons.insights_outlined,
          label: 'Procurement Insights',
        ),
        SidebarMenuItem(
          id: 'margin_analysis',
          icon: Icons.pie_chart_outline,
          label: 'Margin Analysis',
        ),
        SidebarMenuItem(
          id: 'insights',
          icon: Icons.auto_awesome_outlined,
          label: 'AI Insights',
        ),
        SidebarMenuItem(
          id: 'catalogue',
          icon: Icons.collections_bookmark_outlined,
          label: 'Share Catalogue',
        ),
      ],
    ),
    SidebarSection(
      index: 6,
      icon: Icons.account_balance_rounded,
      title: 'Financial Reports',
      accentColor: FuturisticColors.success,
      shortcutHint: 'Ctrl+7',
      items: [
        SidebarMenuItem(
          id: 'invoice_margin',
          icon: Icons.money_outlined,
          label: 'Invoice Margin View',
          permission: 'viewReports',
        ),
        SidebarMenuItem(
          id: 'income_statement',
          icon: Icons.assessment_outlined,
          label: 'Income Statement (P&L)',
          permission: 'viewReports',
        ),
        SidebarMenuItem(
          id: 'funds_flow',
          icon: Icons.swap_horiz_outlined,
          label: 'Funds Flow Analysis',
          permission: 'viewReports',
        ),
        SidebarMenuItem(
          id: 'financial_position',
          icon: Icons.account_balance_outlined,
          label: 'Financial Position',
          permission: 'viewReports',
        ),
        SidebarMenuItem(
          id: 'cash_bank',
          icon: Icons.savings_outlined,
          label: 'Cash / Bank Summary',
          permission: 'viewReports',
        ),
        SidebarMenuItem(
          id: 'accounting_reports',
          icon: Icons.calculate_outlined,
          label: 'Trial Balance / P&L',
          permission: 'viewReports',
        ),
        SidebarMenuItem(
          id: 'bank_accounts',
          icon: Icons.account_balance_outlined,
          label: 'Bank Accounts',
          permission: 'viewCashBook',
        ),
        SidebarMenuItem(
          id: 'daybook',
          icon: Icons.book_outlined,
          label: 'Day Book',
          permission: 'viewReports',
        ),
        SidebarMenuItem(
          id: 'credit_notes',
          icon: Icons.note_outlined,
          label: 'Credit Notes',
          permission: 'viewReports',
        ),
        SidebarMenuItem(
          id: 'expenses',
          icon: Icons.money_off_outlined,
          label: 'Expenses',
          permission: 'viewReports',
        ),
      ],
    ),
    SidebarSection(
      index: 7,
      icon: Icons.policy_rounded,
      title: 'Tax & Compliance',
      accentColor: FuturisticColors.error,
      shortcutHint: 'Ctrl+8',
      items: [
        SidebarMenuItem(
          id: 'gstr1',
          icon: Icons.receipt_outlined,
          label: 'GSTR-1 Reports',
          permission: 'viewGstReports',
        ),
        SidebarMenuItem(
          id: 'b2b_b2c',
          icon: Icons.compare_arrows_outlined,
          label: 'B2B / B2C Summary',
          permission: 'viewGstReports',
        ),
        SidebarMenuItem(
          id: 'hsn_reports',
          icon: Icons.qr_code_outlined,
          label: 'HSN Reports',
          permission: 'viewGstReports',
        ),
        SidebarMenuItem(
          id: 'tax_liability',
          icon: Icons.percent_outlined,
          label: 'Tax Liability',
          permission: 'viewGstReports',
        ),
        SidebarMenuItem(
          id: 'filing_status',
          icon: Icons.fact_check_outlined,
          label: 'Filing Readiness',
          permission: 'viewGstReports',
        ),
      ],
    ),
    SidebarSection(
      index: 8,
      icon: Icons.engineering_rounded,
      title: 'Operations & Logs',
      accentColor: FuturisticColors.textSecondary,
      shortcutHint: 'Ctrl+9',
      items: [
        SidebarMenuItem(
          id: 'transaction_reports',
          icon: Icons.receipt_long_outlined,
          label: 'Transaction Reports',
          permission: 'viewAuditLog',
        ),
        SidebarMenuItem(
          id: 'activity_logs',
          icon: Icons.history_outlined,
          label: 'Master Activity Logs',
          permission: 'viewAuditLog',
        ),
        SidebarMenuItem(
          // Relabeled (Phase 6, Req 9.2): this item opens AllTransactionsScreen
          // (a sales/purchase/expense ledger), NOT a real immutable audit log.
          // Label/icon made truthful; itemId/route unchanged for nav parity.
          id: 'audit_trail',
          icon: Icons.list_alt_outlined,
          label: 'All Transactions',
          permission: 'viewAuditLog',
        ),
        SidebarMenuItem(
          id: 'error_logs',
          icon: Icons.error_outline,
          label: 'Error & Sync Logs',
          permission: 'viewAuditLog',
        ),
      ],
    ),
    SidebarSection(
      index: 9,
      icon: Icons.settings_applications_rounded,
      title: 'Utilities & System',
      accentColor: FuturisticColors.textSecondary,
      shortcutHint: 'Ctrl+0',
      items: [
        SidebarMenuItem(
          id: 'print_settings',
          icon: Icons.print_outlined,
          label: 'Print Settings',
          permission: 'manageSettings',
        ),
        SidebarMenuItem(
          id: 'doc_templates',
          icon: Icons.article_outlined,
          label: 'Document Templates',
          permission: 'manageSettings',
        ),
        SidebarMenuItem(
          id: 'backup',
          icon: Icons.backup_outlined,
          label: 'Backup & Restore',
          permission: 'manageSettings',
        ),
        SidebarMenuItem(
          // Relabeled (Phase 6, Req 9.3): opens BackupScreen (titled "Backup &
          // Sync"), not a standalone sync-status dashboard. itemId/route kept.
          // NOTE: `backup` above opens the same screen — redundant retail item
          // flagged for a product-decision de-dup follow-up (out of scope here).
          id: 'sync_status',
          icon: Icons.cloud_sync_outlined,
          label: 'Backup & Sync',
          permission: 'manageSettings',
        ),
        SidebarMenuItem(
          id: 'device_settings',
          icon: Icons.devices_outlined,
          label: 'Device Settings',
          permission: 'manageSettings',
        ),
      ],
    ),
  ];
}

List<SidebarSection> _getRestaurantSections() {
  return [
    SidebarSection(
      index: 0,
      icon: Icons.restaurant_menu_rounded,
      title: 'Restaurant Operations',
      accentColor: FuturisticColors.accent1,
      shortcutHint: 'Ctrl+1',
      items: [
        SidebarMenuItem(
          id: 'executive_dashboard',
          icon: Icons.dashboard_outlined,
          label: 'Dashboard',
        ),
        SidebarMenuItem(
          id: 'restaurant_tables',
          icon: Icons.table_restaurant_outlined,
          label: 'Table Management',
          capability: BusinessCapability.useTableManagement,
        ),
        SidebarMenuItem(
          id: 'kitchen_display',
          icon: Icons.soup_kitchen_outlined,
          label: 'Kitchen / KOT View',
        ),
        SidebarMenuItem(
          id: 'menu_management',
          icon: Icons.restaurant_menu_outlined,
          label: 'Menu Management',
        ),
        SidebarMenuItem(
          id: 'daily_summary',
          icon: Icons.summarize_outlined,
          label: 'Daily Summary',
        ),
      ],
    ),
    SidebarSection(
      index: 1,
      icon: Icons.point_of_sale_rounded,
      title: 'Billing & Cashier',
      accentColor: FuturisticColors.success,
      shortcutHint: 'Ctrl+2',
      items: [
        SidebarMenuItem(
          id: 'new_sale',
          icon: Icons.receipt_long_outlined,
          label: 'Quick Bill / Invoice',
        ),
        SidebarMenuItem(
          id: 'revenue_overview',
          icon: Icons.analytics_outlined,
          label: 'Live Sales',
        ),
        SidebarMenuItem(
          id: 'sales_register',
          icon: Icons.menu_book_outlined,
          label: 'Sales History',
        ),
      ],
    ),
    SidebarSection(
      index: 2,
      icon: Icons.inventory_2_rounded,
      title: 'Inventory & Stock',
      accentColor: FuturisticColors.primary,
      shortcutHint: 'Ctrl+3',
      items: [
        SidebarMenuItem(
          id: 'stock_summary',
          icon: Icons.summarize_outlined,
          label: 'Stock Summary',
        ),
        SidebarMenuItem(
          id: 'item_stock',
          icon: Icons.category_outlined,
          label: 'Stock Dashboard',
        ),
        SidebarMenuItem(
          id: 'low_stock',
          icon: Icons.warning_amber_outlined,
          label: 'Low Stock Alerts',
          badge: true,
        ),
      ],
    ),
    SidebarSection(
      index: 3,
      icon: Icons.settings_suggest_rounded,
      title: 'Advanced Operations',
      accentColor: FuturisticColors.warning,
      shortcutHint: 'Ctrl+4',
      items: [
        SidebarMenuItem(
          id: 'floor_management',
          icon: Icons.grid_view_outlined,
          label: 'Floor Management',
          capability: BusinessCapability.useTableManagement,
        ),
        SidebarMenuItem(
          id: 'kot_report',
          icon: Icons.receipt_outlined,
          label: 'KOT Report',
          capability: BusinessCapability.useKOT,
        ),
        SidebarMenuItem(
          id: 'recipe_management',
          icon: Icons.menu_book_outlined,
          label: 'Recipe Management',
        ),
        SidebarMenuItem(
          id: 'delivery_ops',
          icon: Icons.delivery_dining_outlined,
          label: 'Delivery Operations',
        ),
        SidebarMenuItem(
          id: 'restaurant_command_center',
          icon: Icons.hub_outlined,
          label: 'Command Center',
        ),
      ],
    ),
    // Restaurant-specific common sections (inlined to allow label customization
    // without affecting other business types — Task 12.2, Req 2.24).
    SidebarSection(
      index: 4,
      icon: Icons.people_alt_rounded,
      title: 'Parties & Ledger',
      accentColor: FuturisticColors.accent2,
      items: [
        SidebarMenuItem(
          id: 'customers',
          icon: Icons.person_outline,
          label: 'Customers',
        ),
        SidebarMenuItem(
          id: 'suppliers',
          icon: Icons.storefront_outlined,
          label: 'Suppliers',
        ),
        SidebarMenuItem(
          id: 'party_ledger',
          icon: Icons.account_balance_wallet_outlined,
          label: 'Party Ledger',
        ),
        SidebarMenuItem(
          id: 'outstanding',
          icon: Icons.pending_actions_outlined,
          label: 'Outstanding',
        ),
      ],
    ),
    SidebarSection(
      index: 5,
      icon: Icons.insights_rounded,
      title: 'Reports & Analytics',
      accentColor: const Color(0xFF00D4FF),
      items: [
        SidebarMenuItem(
          id: 'analytics_hub',
          icon: Icons.hub_outlined,
          label: 'Analytics Hub',
        ),
        SidebarMenuItem(
          id: 'product_performance',
          icon: Icons.auto_graph_outlined,
          label: 'Product Performance',
        ),
        SidebarMenuItem(
          id: 'invoice_margin',
          icon: Icons.money_outlined,
          label: 'P&L Report',
        ),
        SidebarMenuItem(
          id: 'gstr1',
          icon: Icons.receipt_outlined,
          label: 'GST Reports',
          permission: 'viewGstReports',
        ),
      ],
    ),
    SidebarSection(
      index: 6,
      icon: Icons.settings_applications_rounded,
      title: 'System',
      accentColor: FuturisticColors.textSecondary,
      items: [
        SidebarMenuItem(
          id: 'print_settings',
          icon: Icons.print_outlined,
          label: 'Printing',
        ),
        SidebarMenuItem(
          id: 'backup',
          icon: Icons.backup_outlined,
          label: 'Backup',
          permission: 'manageSettings',
        ),
        SidebarMenuItem(
          id: 'error_logs',
          icon: Icons.error_outline,
          label: 'System Logs',
        ),
        SidebarMenuItem(
          id: 'device_settings',
          icon: Icons.devices_outlined,
          label: 'Settings',
        ),
      ],
    ),
  ];
}

List<SidebarSection> _getPetrolPumpSections() {
  return [
    SidebarSection(
      index: 0,
      icon: Icons.local_gas_station_rounded,
      title: 'Fuel Station Ops',
      accentColor: FuturisticColors.accent1,
      shortcutHint: 'Ctrl+1',
      items: [
        SidebarMenuItem(
          id: 'petrol_dashboard',
          icon: Icons.dashboard_outlined,
          label: 'Station Dashboard',
        ),
        SidebarMenuItem(
          id: 'shift_management',
          icon: Icons.schedule_outlined,
          label: 'Shift Management',
        ),
        SidebarMenuItem(
          id: 'dispenser_management',
          icon: Icons.ev_station_outlined,
          label: 'Dispensers / Nozzles',
        ),
        SidebarMenuItem(
          id: 'tank_management',
          icon: Icons.water_drop_outlined,
          label: 'Tank Levels',
        ),
      ],
    ),
    SidebarSection(
      index: 1,
      icon: Icons.point_of_sale_rounded,
      title: 'Billing & Sales',
      accentColor: FuturisticColors.success,
      shortcutHint: 'Ctrl+2',
      items: [
        SidebarMenuItem(
          id: 'new_sale',
          icon: Icons.receipt_long_outlined,
          label: 'Create Invoice',
        ),
        SidebarMenuItem(
          id: 'revenue_overview',
          icon: Icons.analytics_outlined,
          label: 'Revenue Overview',
        ),
        SidebarMenuItem(
          id: 'sales_register',
          icon: Icons.menu_book_outlined,
          label: 'Sales Register',
        ),
      ],
    ),
    SidebarSection(
      index: 2,
      icon: Icons.assessment_rounded,
      title: 'Reports & Analytics',
      accentColor: FuturisticColors.primary,
      shortcutHint: 'Ctrl+3',
      items: [
        SidebarMenuItem(
          id: 'fuel_rates',
          icon: Icons.price_change_outlined,
          label: 'Fuel Rates Config',
        ),
        SidebarMenuItem(
          id: 'fuel_profit_report',
          icon: Icons.trending_up_outlined,
          label: 'Profit Analysis',
        ),
        SidebarMenuItem(
          id: 'nozzle_sales_report',
          icon: Icons.local_gas_station_outlined,
          label: 'Nozzle Sales',
        ),
        SidebarMenuItem(
          id: 'shift_report',
          icon: Icons.schedule_outlined,
          label: 'Shift Reports',
        ),
        SidebarMenuItem(
          id: 'tank_stock_report',
          icon: Icons.water_drop_outlined,
          label: 'Tank Stock',
        ),
      ],
    ),
    ..._getCommonSections(startingIndex: 3),
  ];
}

List<SidebarSection> _getPharmacySections() {
  return [
    SidebarSection(
      index: 0,
      icon: Icons.local_pharmacy_rounded,
      title: 'Pharmacy Control',
      accentColor: FuturisticColors.accent1,
      shortcutHint: 'Ctrl+1',
      items: [
        SidebarMenuItem(
          id: 'executive_dashboard',
          icon: Icons.dashboard_customize_outlined,
          label: 'Dashboard',
        ),
        SidebarMenuItem(
          id: 'live_health',
          icon: Icons.monitor_heart_outlined,
          label: 'Live Health',
        ),
        SidebarMenuItem(
          id: 'daily_snapshot',
          icon: Icons.today_outlined,
          label: 'Daily Snapshot',
        ),
      ],
    ),
    SidebarSection(
      index: 1,
      icon: Icons.medication_rounded,
      title: 'Dispensing & Sales',
      accentColor: FuturisticColors.success,
      shortcutHint: 'Ctrl+2',
      items: [
        SidebarMenuItem(
          id: 'new_sale',
          icon: Icons.point_of_sale_outlined,
          label: 'New Sale (POS)',
        ),
        SidebarMenuItem(
          id: 'prescriptions',
          icon: Icons.description_outlined,
          label: 'Prescriptions',
          capability: BusinessCapability.usePrescription,
        ),
        SidebarMenuItem(
          id: 'revenue_overview',
          icon: Icons.analytics_outlined,
          label: 'Revenue Overview',
        ),
        SidebarMenuItem(
          id: 'sales_register',
          icon: Icons.menu_book_outlined,
          label: 'Sales Register',
        ),
      ],
    ),
    SidebarSection(
      index: 2,
      icon: Icons.inventory_2_rounded,
      title: 'Inventory & Expiry',
      accentColor: FuturisticColors.warning,
      shortcutHint: 'Ctrl+3',
      items: [
        SidebarMenuItem(
          id: 'item_stock',
          icon: Icons.category_outlined,
          label: 'Medicine Stock',
        ),
        SidebarMenuItem(
          id: 'batch_tracking',
          icon: Icons.layers_outlined,
          label: 'Batch / Expiry View',
          capability: BusinessCapability.useBatchExpiry,
        ),
        SidebarMenuItem(
          id: 'low_stock',
          icon: Icons.warning_amber_outlined,
          label: 'Low Stock / Expiry',
          badge: true,
        ),
        SidebarMenuItem(
          id: 'stock_valuation',
          icon: Icons.price_check_outlined,
          label: 'Stock Valuation',
        ),
      ],
    ),
    SidebarSection(
      index: 3,
      icon: Icons.shopping_bag_rounded,
      title: 'Procurement',
      accentColor: FuturisticColors.primary,
      shortcutHint: 'Ctrl+4',
      items: [
        SidebarMenuItem(
          id: 'purchase_orders',
          icon: Icons.shopping_cart_checkout_outlined,
          label: 'Purchase Orders',
        ),
        SidebarMenuItem(
          id: 'stock_entry',
          icon: Icons.add_box_outlined,
          label: 'Stock Entry',
        ),
        SidebarMenuItem(
          id: 'supplier_bills',
          icon: Icons.request_quote_outlined,
          label: 'Supplier Bills',
        ),
      ],
    ),
    // Compliance, statutory registers, and pharmacy lookups (Req 13.1). The four
    // entries below surface previously orphaned pharmacy screens. Each is
    // capability-gated via the Capability_Gate (FeatureResolver) in
    // `sidebarSectionsProvider`, so an entry is shown only when the pharmacy
    // business type grants the backing capability (Req 13.4, 13.5) and each id
    // resolves through `SidebarNavigationHandler` to its screen (Req 13.2).
    SidebarSection(
      index: 4,
      icon: Icons.verified_user_rounded,
      title: 'Compliance & Lookups',
      accentColor: FuturisticColors.error,
      shortcutHint: 'Ctrl+5',
      items: [
        SidebarMenuItem(
          id: 'salt_search',
          icon: Icons.science_outlined,
          label: 'Salt Search',
          capability: BusinessCapability.useSaltSearch,
        ),
        SidebarMenuItem(
          id: 'patient_registry',
          icon: Icons.contact_page_outlined,
          label: 'Patient Registry',
          capability: BusinessCapability.usePatientRegistry,
        ),
        SidebarMenuItem(
          id: 'narcotic_register',
          icon: Icons.shield_outlined,
          label: 'Narcotic Register',
          capability: BusinessCapability.useDrugSchedule,
        ),
        SidebarMenuItem(
          id: 'h1_register',
          icon: Icons.menu_book_outlined,
          label: 'H1 Register',
          capability: BusinessCapability.useDrugSchedule,
        ),
      ],
    ),
    // Finance & cash flow (Req 16.1, 16.2). Surfaces Expenses and Bank/Cash in
    // the pharmacy sidebar so owners can manage cash flow without leaving the
    // pharmacy experience. Both ids resolve through `SidebarNavigationHandler`
    // to the existing `ExpensesScreen` and `BankScreen` (Req 16.3, 16.4); an
    // unresolved target stays on the current screen with an error indication,
    // handled centrally by the handler (Req 16.5). These are general financial
    // screens (no pharmacy-specific capability gate), matching retail.
    SidebarSection(
      index: 5,
      icon: Icons.account_balance_wallet_rounded,
      title: 'Finance & Cash Flow',
      accentColor: FuturisticColors.success,
      shortcutHint: 'Ctrl+6',
      items: [
        SidebarMenuItem(
          id: 'expenses',
          icon: Icons.money_off_outlined,
          label: 'Expenses',
          permission: 'viewReports',
        ),
        SidebarMenuItem(
          id: 'bank_accounts',
          icon: Icons.account_balance_outlined,
          label: 'Bank / Cash',
          permission: 'viewCashBook',
        ),
      ],
    ),
    ..._getCommonSections(startingIndex: 6),
  ];
}

/// Dedicated sidebar for `BusinessType.mobileShop` (Task 9.1 — Requirements 7.1, 7.8, 7.10).
///
/// Returns exactly five mobile-specific entries — Service Jobs, Exchanges,
/// IMEI Tracking, Warranty, Second-Hand Intake — plus the same shared common
/// sections (`_getCommonSections`) returned for every other `BusinessType`.
///
/// Each item carries a [BusinessCapability] gate so that
/// `FeatureResolver.canAccess` in [sidebarSectionsProvider] permits granted
/// items and filters ungranted ones (Requirement 7.2, 7.8).
///
/// Unsupported retail items (`proforma_bids`, `dispatch_notes`,
/// `return_inwards`) are excluded by omission — they are simply not present
/// in this function's return value (Requirement 7.8, 7.10).
///
/// BLAST RADIUS: This function is NEW. It does not modify any other business
/// type's section list, the `default` branch, or `_getRetailSections()`.
/// Shared file touched: `sidebar_configuration.dart` — added
/// `case BusinessType.mobileShop` and this function. The electronics and
/// computerShop case now groups only those two (no behavioral change for them).
/// No other case or the default branch was modified.
List<SidebarSection> _getMobileShopSections() {
  return [
    // Dedicated mobile-shop section — the 5 mobile-specific items.
    SidebarSection(
      index: 0,
      icon: Icons.build_rounded,
      title: 'Service & Repairs',
      accentColor: FuturisticColors.warning,
      shortcutHint: 'Ctrl+1',
      items: [
        SidebarMenuItem(
          id: 'service_jobs',
          icon: Icons.build_circle_outlined,
          label: 'Service Jobs',
          capability: BusinessCapability.useJobSheets,
        ),
        SidebarMenuItem(
          id: 'exchanges',
          icon: Icons.swap_horiz_outlined,
          label: 'Exchanges',
          capability: BusinessCapability.useExchange,
        ),
        SidebarMenuItem(
          id: 'imei_tracking',
          icon: Icons.qr_code_scanner_outlined,
          label: 'IMEI Tracking',
          capability: BusinessCapability.useIMEI,
        ),
        SidebarMenuItem(
          id: 'warranty',
          icon: Icons.verified_user_outlined,
          label: 'Warranty',
          capability: BusinessCapability.useWarranty,
        ),
        SidebarMenuItem(
          id: 'second_hand_intake',
          icon: Icons.phone_android_outlined,
          label: 'Second-Hand Intake',
          capability: BusinessCapability.useBuyback,
        ),
      ],
    ),
    // Shared common sections — identical to what petrol pump, pharmacy, etc. get.
    ..._getCommonSections(startingIndex: 1),
  ];
}

/// Dedicated sidebar for `BusinessType.electronics` (Phase 4, Task 14 —
/// bugfix.md 2.14, 2.15, 2.16).
///
/// Electronics was previously grouped with `computerShop` on the shared
/// `_getRetailSections()` (D5), so it inherited a generic retail menu missing
/// every device-specific surface. This dedicated builder mirrors the structure
/// of `_getMobileShopSections()`: one dedicated device section followed by the
/// same shared common sections (`_getCommonSections`) every other type receives.
///
/// Device entries (2.15) — each id reuses the proven `_getMobileShopSections()`
/// resolution so navigation is identical to the mobile-shop family:
///   - `service_jobs`  → Service/Repair Jobs (maps to the manageStaff-guarded
///                       ServiceJobListScreen; `/job/*` routes already allow
///                       electronics — D7, Phase 2 task 8.3). Capability
///                       `useJobSheets`.
///   - `imei_tracking` → Serial/IMEI Tracking (the IMEI/serial tracking surface
///                       backed by the new `/electronics/imei-tracking` route
///                       added in Phase 2 task 8.2). Capability `useIMEI`.
///   - `warranty`      → Warranty Register (the `/computer-shop/warranty`
///                       WarrantyScreen, now reachable for electronics after the
///                       Phase 2 task 8.1 guard widening). Capability
///                       `useWarranty`.
///   - `return_inwards`→ Returns-with-serial (resolves to ReturnInwardsScreen;
///                       Phase 7 deepens it with serial validation). Generic
///                       returns id for now.
///
/// id resolution / aliasing (2.16): the clearly-irrelevant retail-only ids
/// (`funds_flow`, `filing_status`, `ledger_abstract`, `b2b_b2c`) are omitted by
/// NOT including the full `_getRetailSections()` list. The `audit_trail`
/// item — which aliases `AllTransactionsScreen` (a transactions ledger, not a
/// real immutable audit log) — is likewise NOT carried into this section; a
/// real audit log remains Phase 8/parked unless backed by one.
///
/// BLAST RADIUS: This function is NEW. It does not modify any other business
/// type's section list, the `default` branch, `_getRetailSections()`, or
/// `_getMobileShopSections()`. Shared file touched: `sidebar_configuration.dart`
/// — added `case BusinessType.electronics` and this function (Preservation 3.1,
/// 3.6).
List<SidebarSection> _getElectronicsSections() {
  return [
    // Dedicated electronics device section — the device-relevant entries.
    SidebarSection(
      index: 0,
      icon: Icons.devices_other_rounded,
      title: 'Devices & Service',
      accentColor: FuturisticColors.warning,
      shortcutHint: 'Ctrl+1',
      items: [
        SidebarMenuItem(
          id: 'imei_tracking',
          icon: Icons.qr_code_scanner_outlined,
          label: 'Serial / IMEI Tracking',
          capability: BusinessCapability.useIMEI,
        ),
        SidebarMenuItem(
          id: 'warranty',
          icon: Icons.verified_user_outlined,
          label: 'Warranty Register',
          capability: BusinessCapability.useWarranty,
        ),
        SidebarMenuItem(
          id: 'service_jobs',
          icon: Icons.build_circle_outlined,
          label: 'Service / Repair Jobs',
          capability: BusinessCapability.useJobSheets,
        ),
        SidebarMenuItem(
          id: 'return_inwards',
          icon: Icons.assignment_return_outlined,
          label: 'Returns (with serial)',
        ),
        // Serial-wise stock view (Phase 7, Task 23.2 — Requirement 2.23).
        // Shows IMEISerials filtered by status (in-stock) so the user can
        // see individual device units available for sale. Resolves to
        // ImeiTrackingStatementScreen with a stock filter context. Other
        // verticals' sections unchanged (Preservation 3.6, 3.7).
        SidebarMenuItem(
          id: 'serial_stock',
          icon: Icons.inventory_2_outlined,
          label: 'Serial-wise Stock',
          capability: BusinessCapability.useIMEI,
        ),
      ],
    ),
    // Shared common sections — identical to what petrol pump, pharmacy, etc. get.
    ..._getCommonSections(startingIndex: 1),
  ];
}

List<SidebarSection> _getCommonSections({required int startingIndex}) {
  int idx = startingIndex;
  return [
    SidebarSection(
      index: idx++,
      icon: Icons.people_alt_rounded,
      title: 'Parties & Ledger',
      accentColor: FuturisticColors.accent2,
      items: [
        SidebarMenuItem(
          id: 'customers',
          icon: Icons.person_outline,
          label: 'Customers',
        ),
        SidebarMenuItem(
          id: 'suppliers',
          icon: Icons.storefront_outlined,
          label: 'Suppliers',
        ),
        SidebarMenuItem(
          id: 'party_ledger',
          icon: Icons.account_balance_wallet_outlined,
          label: 'Party Ledger',
        ),
        SidebarMenuItem(
          id: 'outstanding',
          icon: Icons.pending_actions_outlined,
          label: 'Outstanding',
        ),
      ],
    ),
    SidebarSection(
      index: idx++,
      icon: Icons.insights_rounded,
      title: 'Reports & Analytics',
      accentColor: const Color(0xFF00D4FF),
      items: [
        SidebarMenuItem(
          id: 'analytics_hub',
          icon: Icons.hub_outlined,
          label: 'Analytics Hub',
        ),
        SidebarMenuItem(
          id: 'product_performance',
          icon: Icons.auto_graph_outlined,
          label: 'Product Performance',
        ),
        SidebarMenuItem(
          id: 'invoice_margin',
          icon: Icons.money_outlined,
          label: 'Profit & Loss',
          permission: 'viewReports',
        ),
        SidebarMenuItem(
          id: 'gstr1',
          icon: Icons.receipt_outlined,
          label: 'GST Reports',
          permission: 'viewGstReports',
        ),
      ],
    ),
    SidebarSection(
      index: idx++,
      icon: Icons.settings_applications_rounded,
      title: 'System',
      accentColor: FuturisticColors.textSecondary,
      items: [
        SidebarMenuItem(
          id: 'print_settings',
          icon: Icons.print_outlined,
          label: 'Printing',
          permission: 'manageSettings',
        ),
        SidebarMenuItem(
          id: 'backup',
          icon: Icons.backup_outlined,
          label: 'Backup',
          permission: 'manageSettings',
        ),
        SidebarMenuItem(
          id: 'error_logs',
          icon: Icons.error_outline,
          label: 'System Logs',
          permission: 'viewAuditLog',
        ),
        SidebarMenuItem(
          id: 'device_settings',
          icon: Icons.devices_outlined,
          label: 'Settings',
          permission: 'manageSettings',
        ),
      ],
    ),
  ];
}

// ---------------------------------------------------------------------------
// BOOK STORE VERTICAL — sidebar sections (Task 5.1).
// ---------------------------------------------------------------------------

/// Dedicated sidebar for `BusinessType.bookStore` (Requirements 5.1, 5.2, 5.3, 1.11, 1.12).
///
/// Returns 5 book-specific items across 5 sections — Book Catalogue, Book POS,
/// Consignments, School/Institution Orders, and Publisher Returns. Each item carries
/// a non-empty label, a stable `book_*` id, and a [BusinessCapability] gate so that
/// `FeatureResolver.canAccess` in [sidebarSectionsProvider] permits granted items and
/// filters ungranted ones.
///
/// For Consignments and School Orders, new dedicated capabilities are added in Phase 9
/// (task 19.1). Until then they use `useStockManagement` as a general gate — the item
/// will still be visible to bookStore operators since that capability is granted.
///
/// BLAST RADIUS: This function is NEW. It does not modify any other business type's
/// section list, the `default` branch, or `_getRetailSections()`.
/// Shared file touched: `sidebar_configuration.dart` — added
/// `case BusinessType.bookStore` and this function. No other case or the default
/// branch was modified.
List<SidebarSection> _getBookStoreSections() {
  return [
    // Book Catalogue — inventory/catalogue screen.
    SidebarSection(
      index: 0,
      icon: Icons.menu_book_rounded,
      title: 'Book Catalogue',
      accentColor: FuturisticColors.accent1,
      shortcutHint: 'Ctrl+1',
      items: [
        SidebarMenuItem(
          id: 'book_catalogue',
          icon: Icons.library_books_outlined,
          label: 'Book Catalogue',
          capability: BusinessCapability.useStockManagement,
        ),
      ],
    ),
    // Book POS — point of sale screen.
    SidebarSection(
      index: 1,
      icon: Icons.point_of_sale_rounded,
      title: 'Book POS',
      accentColor: FuturisticColors.primary,
      shortcutHint: 'Ctrl+2',
      items: [
        SidebarMenuItem(
          id: 'book_pos',
          icon: Icons.point_of_sale_outlined,
          label: 'Book POS',
          capability: BusinessCapability.useBarcodeScanner,
        ),
      ],
    ),
    // Consignments — consignment settlement screen.
    SidebarSection(
      index: 2,
      icon: Icons.local_shipping_rounded,
      title: 'Consignments',
      accentColor: FuturisticColors.success,
      shortcutHint: 'Ctrl+3',
      items: [
        SidebarMenuItem(
          id: 'book_consignments',
          icon: Icons.inventory_outlined,
          label: 'Consignments',
          capability: BusinessCapability.useConsignmentSettlement,
        ),
      ],
    ),
    // School / Institution Orders — school order screen.
    SidebarSection(
      index: 3,
      icon: Icons.school_rounded,
      title: 'School / Institution Orders',
      accentColor: FuturisticColors.warning,
      shortcutHint: 'Ctrl+4',
      items: [
        SidebarMenuItem(
          id: 'book_school_orders',
          icon: Icons.school_outlined,
          label: 'School Orders',
          capability: BusinessCapability.useSchoolOrders,
        ),
      ],
    ),
    // Publisher Returns — supplier returns screen.
    SidebarSection(
      index: 4,
      icon: Icons.assignment_return_rounded,
      title: 'Publisher Returns',
      accentColor: FuturisticColors.error,
      shortcutHint: 'Ctrl+5',
      items: [
        SidebarMenuItem(
          id: 'book_publisher_returns',
          icon: Icons.assignment_return_outlined,
          label: 'Publisher Returns',
          capability: BusinessCapability.usePublisherReturns,
        ),
      ],
    ),
  ];
}

// ---------------------------------------------------------------------------
// SCHOOL ERP VERTICAL — sidebar sections (Task 3.1).
// ---------------------------------------------------------------------------

/// Dedicated sidebar for `BusinessType.schoolErp` (Requirements 4.1, 4.2, 4.3, 4.10, 1.11, 1.12).
///
/// Returns 19 school-specific items across 12 sections — Dashboard,
/// Students & Admissions, Fees, Attendance, Exams & Report Cards, Timetable,
/// Faculty, Transport, Library, Communication, Reports, Certificates. Each item
/// carries a [BusinessCapability] gate so that `FeatureResolver.canAccess` in
/// [sidebarSectionsProvider] permits granted items and filters ungranted ones.
///
/// All item ids follow the `school_*` pattern.
///
/// BLAST RADIUS: This function is NEW. It does not modify any other business
/// type's section list, the `default` branch, or `_getRetailSections()`.
/// Shared file touched: `sidebar_configuration.dart` — added
/// `case BusinessType.schoolErp` and this function. No other case or the default
/// branch was modified.
List<SidebarSection> _getSchoolSections() {
  return [
    // Dashboard
    SidebarSection(
      index: 0,
      icon: Icons.space_dashboard_rounded,
      title: 'Dashboard',
      accentColor: FuturisticColors.accent1,
      shortcutHint: 'Ctrl+1',
      items: [
        SidebarMenuItem(
          id: 'school_dashboard',
          icon: Icons.dashboard_customize_outlined,
          label: 'Dashboard',
          capability: BusinessCapability.useDailySnapshot,
        ),
      ],
    ),
    // Students & Admissions
    SidebarSection(
      index: 1,
      icon: Icons.school_rounded,
      title: 'Students & Admissions',
      accentColor: FuturisticColors.primary,
      shortcutHint: 'Ctrl+2',
      items: [
        SidebarMenuItem(
          id: 'school_students',
          icon: Icons.people_outlined,
          label: 'Students',
          capability: BusinessCapability.useStudentRegistry,
        ),
        SidebarMenuItem(
          id: 'school_classes',
          icon: Icons.class_outlined,
          label: 'Classes & Sections',
          capability: BusinessCapability.useStudentRegistry,
        ),
        // Phase 6, Task 13.1 (Req 9.1, 9.2, 9.6) — Production-Ready orphaned screen.
        SidebarMenuItem(
          id: 'school_admissions',
          icon: Icons.how_to_reg_outlined,
          label: 'Admissions',
          capability: BusinessCapability.useStudentRegistry,
          permission: 'viewStudents',
        ),
        // Phase 6, Task 13.1 (Req 9.1, 9.2, 9.6) — Production-Ready orphaned screen.
        SidebarMenuItem(
          id: 'school_id_cards',
          icon: Icons.badge_outlined,
          label: 'ID Cards',
          capability: BusinessCapability.useStudentRegistry,
          permission: 'viewStudents',
        ),
      ],
    ),
    // Fees
    SidebarSection(
      index: 2,
      icon: Icons.currency_rupee_rounded,
      title: 'Fees',
      accentColor: FuturisticColors.success,
      shortcutHint: 'Ctrl+3',
      items: [
        SidebarMenuItem(
          id: 'school_fees',
          icon: Icons.payment_outlined,
          label: 'Fee Collection',
          capability: BusinessCapability.useFeeCollection,
        ),
        SidebarMenuItem(
          id: 'school_fee_structure',
          icon: Icons.account_tree_outlined,
          label: 'Classwise Fee Structure',
          capability: BusinessCapability.useFeeCollection,
        ),
      ],
    ),
    // Attendance
    SidebarSection(
      index: 3,
      icon: Icons.fact_check_rounded,
      title: 'Attendance',
      accentColor: FuturisticColors.warning,
      shortcutHint: 'Ctrl+4',
      items: [
        SidebarMenuItem(
          id: 'school_attendance',
          icon: Icons.checklist_outlined,
          label: 'Attendance',
          capability: BusinessCapability.useAttendanceTracking,
        ),
      ],
    ),
    // Exams & Report Cards
    SidebarSection(
      index: 4,
      icon: Icons.quiz_rounded,
      title: 'Exams & Report Cards',
      accentColor: FuturisticColors.error,
      shortcutHint: 'Ctrl+5',
      items: [
        SidebarMenuItem(
          id: 'school_exams',
          icon: Icons.assignment_outlined,
          label: 'Exams',
          capability: BusinessCapability.useTestResults,
        ),
        SidebarMenuItem(
          id: 'school_report_cards',
          icon: Icons.grading_outlined,
          label: 'Report Cards',
          capability: BusinessCapability.useTestResults,
        ),
        // Phase 6, Task 13.1 (Req 9.1, 9.2, 9.6) — Production-Ready orphaned screen.
        SidebarMenuItem(
          id: 'school_lesson_plans',
          icon: Icons.auto_stories_outlined,
          label: 'Lesson Plans',
          capability: BusinessCapability.useTestResults,
          permission: 'viewStudents',
        ),
        // Phase 6, Task 13.1 (Req 9.1, 9.2, 9.6) — Production-Ready orphaned screen.
        SidebarMenuItem(
          id: 'school_homework',
          icon: Icons.menu_book_outlined,
          label: 'Homework',
          capability: BusinessCapability.useTestResults,
          permission: 'viewStudents',
        ),
      ],
    ),
    // Timetable
    SidebarSection(
      index: 5,
      icon: Icons.calendar_month_rounded,
      title: 'Timetable',
      accentColor: FuturisticColors.accent2,
      shortcutHint: 'Ctrl+6',
      items: [
        SidebarMenuItem(
          id: 'school_timetable',
          icon: Icons.schedule_outlined,
          label: 'Timetable',
          capability: BusinessCapability.useTimetable,
        ),
      ],
    ),
    // Faculty
    SidebarSection(
      index: 6,
      icon: Icons.badge_rounded,
      title: 'Faculty',
      accentColor: FuturisticColors.primary,
      items: [
        SidebarMenuItem(
          id: 'school_faculty',
          icon: Icons.person_pin_outlined,
          label: 'Faculty',
          capability: BusinessCapability.useStaffManagement,
        ),
      ],
    ),
    // Transport
    SidebarSection(
      index: 7,
      icon: Icons.directions_bus_rounded,
      title: 'Transport',
      accentColor: FuturisticColors.warning,
      items: [
        SidebarMenuItem(
          id: 'school_transport',
          icon: Icons.directions_bus_outlined,
          label: 'Transport',
          capability: BusinessCapability.useStudentRegistry,
        ),
      ],
    ),
    // Library
    SidebarSection(
      index: 8,
      icon: Icons.local_library_rounded,
      title: 'Library',
      accentColor: FuturisticColors.accent1,
      items: [
        SidebarMenuItem(
          id: 'school_library',
          icon: Icons.menu_book_outlined,
          label: 'Library',
          capability: BusinessCapability.useStudentRegistry,
        ),
      ],
    ),
    // Communication
    SidebarSection(
      index: 9,
      icon: Icons.notifications_rounded,
      title: 'Communication',
      accentColor: FuturisticColors.success,
      items: [
        SidebarMenuItem(
          id: 'school_notifications',
          icon: Icons.campaign_outlined,
          label: 'Notifications',
          capability: BusinessCapability.useParentNotifications,
        ),
      ],
    ),
    // Reports
    SidebarSection(
      index: 10,
      icon: Icons.assessment_rounded,
      title: 'Reports',
      accentColor: FuturisticColors.accent2,
      items: [
        SidebarMenuItem(
          id: 'school_reports',
          icon: Icons.summarize_outlined,
          label: 'Reports',
          capability: BusinessCapability.useRevenueOverview,
        ),
      ],
    ),
    // Certificates
    SidebarSection(
      index: 11,
      icon: Icons.workspace_premium_rounded,
      title: 'Certificates',
      accentColor: FuturisticColors.primary,
      items: [
        SidebarMenuItem(
          id: 'school_certificates',
          icon: Icons.card_membership_outlined,
          label: 'Certificates',
          capability: BusinessCapability.useCertificates,
        ),
      ],
    ),
  ];
}

// ---------------------------------------------------------------------------
// TEST HELPER — exposes sidebar sections by business type for unit tests.
// ---------------------------------------------------------------------------

/// Returns the unfiltered sidebar sections for the given [BusinessType].
///
/// This is a thin wrapper over the private [_getSectionsForBusiness] helper,
/// exposed exclusively for unit tests that need to verify sidebar labels,
/// item IDs, or section structure without Riverpod widget infrastructure.
@visibleForTesting
List<SidebarSection> getSectionsForBusinessType(BusinessType type) {
  return _getSectionsForBusiness(type);
}
