// =============================================================================
// LegacyRoutes — legacy-compatible go_router layer (DukanX navigation)
// =============================================================================
//
// Single source of truth for the legacy-compatible top-level `GoRoute`s and the
// alias redirects that close the imperative-navigation gap (design.md,
// Component 1 / AD-1, AD-6). The just-completed `gorouter-navigation-migration`
// spec made `MaterialApp.router` the SOLE navigation root, leaving the old
// `MaterialApp.routes` table (`buildAppRoutes()`) unwired. ~20+ files still
// navigate imperatively against the legacy named-route strings; this layer
// re-registers each one as a top-level `GoRoute` whose `path` is the same
// string, with its guard/argument body lifted verbatim from `buildAppRoutes()`.
//
// SCOPE OF THIS FILE (Task 2.2 — SKELETON ONLY):
//   This is the structural skeleton. It establishes the public interface and
//   the pure `aliasTargetFor` decision function (AD-6). The 121 legacy
//   `GoRoute` registrations and the populated `knownLegacyPaths` set are filled
//   by LATER tasks (see the TODOs on `routes()` / `_knownLegacyPaths`). The
//   wiring into `AppRouter` (spreading `routes()` and consulting
//   `aliasTargetFor` in the redirect callback) is Task 2.6 and is NOT done
//   here.
//
// DESIGN NOTES:
//   * `aliasTargetFor` is a PURE TOTAL function over `String` (AD-6): it returns
//     the canonical target for a legacy alias path, or `null` for non-aliases.
//     It uses `RoutePaths` constants (no hardcoded canonical strings) so the
//     alias targets stay in sync with the foundation routes.
//   * `knownLegacyPaths` is derived from a SINGLE private constant set so that
//     `isKnownLegacyPath` and `routes()` stay consistent by construction. It is
//     intentionally empty for now and is extended as routes are registered by
//     the later route tasks.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Guards / permissions (lifted verbatim from lib/app/routes.dart).
import '../../components/auth/protected_route.dart';
import '../../config/permissions.dart';
import '../auth/role_guard.dart';

// Auth / entry screens.
import '../../features/auth/presentation/screens/license_screen.dart';
import '../../features/onboarding/vendor_onboarding_screen.dart';

// Dashboards / shells.
import '../navigation/owner_dashboard_redirect.dart';
import '../responsive/adaptive_shell.dart';
import '../../features/dashboard/presentation/screens/dashboard_selection_screen.dart';
import '../../features/dashboard/v2/screens/pharmacy_dashboard_screen.dart';
import '../../features/pharmacy/screens/patient_registry_screen.dart';
import '../../features/pharmacy/screens/salt_search_screen.dart';

// Billing family screens (Task 4.3).
import '../../screens/pending_screen.dart';
import '../../screens/billing_flow.dart';
import '../../screens/customer_bills.dart';
import '../../screens/bill_search_screen.dart';
import '../../screens/advanced_billing_screen.dart';
import '../../screens/blacklist_management_screen.dart';
import '../../screens/billing_reports_screen.dart';
import '../../features/customers/presentation/screens/add_customer_screen.dart';
import '../../screens/total_bills_screen.dart';
import '../../screens/total_paid_screen.dart';
import '../../screens/pending_dues_screen.dart';
import '../../features/customers/presentation/screens/customers_list_screen.dart';
import '../../features/billing/presentation/screens/bill_scan_screen.dart';
import '../../features/inventory/presentation/screens/barcode_scanner_screen.dart';
import '../../features/inventory/presentation/screens/inventory_dashboard_screen.dart';
import '../../features/delivery_challan/presentation/screens/delivery_challan_list_screen.dart';
import '../../features/revenue/screens/proforma_screen.dart';
import '../../screens/payment_history_screen.dart';

// Settings / admin family screens (Task 4.4).
import '../../features/settings/business_settings_screen.dart';
import '../../features/profile/screens/vendor_profile_screen.dart';
import '../../features/settings/presentation/screens/main_settings_screen.dart';
import '../../features/settings/presentation/screens/printer_settings_screen.dart';
import '../../features/invoice/screens/invoice_settings_screen.dart';
import '../../features/settings/screens/tax_config_screen.dart';
import '../../features/settings/screens/currency_settings_screen.dart';
import '../../features/payment/presentation/screens/payment_gateway_settings_screen.dart';
import '../../features/settings/presentation/screens/device_settings_screen.dart';
import '../../features/settings/presentation/screens/server_settings_screen.dart';
import '../../features/settings/presentation/screens/database_management_screen.dart';
import '../../features/settings/presentation/screens/storage_management_screen.dart';
import '../../features/settings/presentation/screens/data_import_export_screen.dart';
import '../../features/customers/presentation/screens/security_settings_screen.dart';
import '../../features/customers/presentation/screens/notification_settings_screen.dart';
import '../../features/billing/screens/dunning_config_screen.dart';
import '../../screens/admin_migrations_screen.dart';
import '../../screens/developer_health_screen.dart';
import '../../screens/dev_business_type_switcher_screen.dart';
import '../../screens/app_management_screen.dart';
import '../../features/settings/presentation/screens/template_designer_screen.dart';

// Reports / analytics / sync family screens (Task 4.4).
import '../../features/insights/presentation/screens/insights_screen.dart';
import '../../features/alerts/presentation/screens/alerts_screen.dart';
import '../../features/analytics/analytics_dashboard_screen.dart';
import '../../features/backup/screens/backup_screen.dart';
import '../../features/gst/screens/gst_reports_screen.dart';
import '../../features/daybook/presentation/screens/day_book_screen.dart';
import '../../features/party_ledger/party_ledger.dart';
import '../../features/catalogue/presentation/screens/catalogue_screen.dart';
import '../../screens/real_sync_screen.dart';

// Vertical-family guards (Task 4.5). BusinessGuard is the business-type gate
// wrapped INSIDE VendorRoleGuard for most vertical routes; BusinessType is the
// enum used in its `allowedTypes` list. Lifted verbatim from routes.dart.
import '../../models/business_type.dart';
import '../../features/core/auth/business_type_guard.dart';

// Hardware vertical screens (Task 4.5).
import '../../features/hardware/presentation/screens/hardware_credit_control_screen.dart';
import '../../features/hardware/presentation/screens/hardware_invoice_profile_screen.dart';
import '../../features/billing/presentation/screens/bill_creation_screen_v2.dart';

// Clinic vertical screens (Task 4.5).
import '../../features/clinic/presentation/screens/patient_queue_screen.dart';
import '../../features/doctor/presentation/screens/add_prescription_screen.dart';
import '../../features/doctor/presentation/screens/appointment_screen.dart';

// Book store vertical screens (Task 4.5).
import '../../features/book_store/presentation/screens/consignment_settlement_screen.dart';
import '../../features/book_store/presentation/screens/school_order_screen.dart';

// Petrol pump vertical screens (Task 4.5).
import '../../features/petrol_pump/presentation/screens/dispenser_list_screen.dart';
import '../../features/petrol_pump/presentation/screens/fuel_rates_screen.dart';

// Service / repair vertical screens (Task 4.5).
import '../../features/service/service.dart';

// Decoration & Catering vertical screens (Task 4.5).
import '../../features/decoration_catering/decoration_catering.dart';

// School / Coaching ERP vertical screens (Task 4.5).
import '../../features/academic_coaching/academic_coaching.dart';

// School-specific permission guard (Phase 3 — schoolerp-vertical-remediation, Req 6.3–6.7).
// Replaces generic retail VendorRoleGuard(viewInvoices/viewClients) for /ac/* routes.
import '../../features/academic_coaching/utils/school_permission_guard.dart';
import '../../features/academic_coaching/utils/school_permissions.dart';

// Computer shop vertical screens (Task 4.5).
import '../../features/computer_shop/computer_shop.dart';

// Electronics vertical — IMEI Tracking (Phase 2, electronics-vertical-remediation Req 2.9).
import '../../features/statements/presentation/screens/imei_tracking_statement_screen.dart';

// Jewellery vertical screens (Phase 1 — jewellery-vertical-remediation).
import '../../features/jewellery/presentation/screens/gold_rate_management_screen.dart';
import '../../features/jewellery/presentation/screens/gold_rate_alert_screen.dart';
import '../../features/jewellery/presentation/screens/making_charges_calculator_screen.dart';
import '../../features/jewellery/presentation/screens/hallmark_inventory_screen.dart';
import '../../features/jewellery/presentation/screens/old_gold_exchange_screen.dart';
import '../../features/jewellery/presentation/screens/custom_order_management_screen.dart';
import '../../features/jewellery/presentation/screens/jewellery_repair_screen.dart';
import '../../features/jewellery/presentation/screens/gold_scheme_screen.dart';

// Linking screens (Task 4.5).
import '../../screens/vendor_qr_code_screen.dart';
import '../../screens/customer_link_shop_screen.dart';
import '../../screens/owner_link_screen.dart';
import '../../screens/customer_link_accept_screen.dart';
import '../../screens/shop_selection_screen.dart';
import '../auth/auth_gate.dart';
import '../../features/customers/presentation/screens/my_linked_shops_screen.dart';

// Argument-bearing routes (Task 6.2). Screens/models referenced by the
// arg-bearing legacy builders DEFERRED from Phase B. Their builder bodies are
// lifted CHARACTER-FOR-CHARACTER from `lib/app/routes.dart`, swapping only the
// arguments-read (`ModalRoute.of(context)?.settings.arguments` -> `state.extra`)
// per design.md AD-3. Import paths mirror routes.dart (rebased `../` -> `../../`).
import '../../models/bill.dart' show Bill;
import '../../models/invoice_editable.dart';
import '../../core/repository/customers_repository.dart' show Customer;
import '../../components/auth/login_page.dart';
import '../../screens/advanced_bill_creation_screen.dart';
import '../../screens/invoice_preview_screen.dart';
import '../../screens/customer_report_screen.dart';
import '../../screens/editable_invoice_screen.dart';
import '../../screens/cloud_sync_settings_screen.dart';
import '../../features/hardware/presentation/screens/hardware_operations_screen.dart';
import '../../features/clinic/presentation/screens/consultation_screen.dart';
import '../../features/clinic/presentation/screens/patient_history_screen.dart';
import '../../features/clinic/presentation/screens/lab_order_screen.dart';
import '../../features/clothing/presentation/screens/variant_management_screen.dart';
import '../../features/clothing/presentation/screens/tailoring_measurements_screen.dart';
import '../../features/customers/presentation/screens/customer_dashboard_screen.dart';
import '../../features/customers/presentation/screens/customer_notifications_screen.dart';
// Purchase / Scan Bill arg routes (Task 6.2) — DEFERRED from Task 4.5. Barrel
// export mirrors routes.dart; provides ScanBillImagePickerScreen,
// ScanBillReviewScreen, PurchaseEntriesListScreen.
import '../../features/purchase/scan_bill.dart';

// New routes absent from the legacy buildAppRoutes() table (Task 7.1 — design
// AD-8). `/super-admin/*` target screens discovered in
// lib/features/super_admin/presentation/screens/. (`/upgrade` has NO target
// screen in the codebase — see the FLAGGED placeholder in routes(), Req 9.3.)
import '../../features/super_admin/presentation/screens/tenant_management_screen.dart';
import '../../features/super_admin/presentation/screens/license_list_screen.dart';
import '../../features/super_admin/presentation/screens/audit_viewer_screen.dart';
import '../../features/super_admin/presentation/screens/usage_dashboard_screen.dart';

// Capability gating (Phase 3 — mobileshop-vertical-remediation, Requirement 6).
// CapabilityGate wraps a screen and checks FeatureResolver.canAccess before
// render; BusinessCapability provides the enum values for the gate.
import '../isolation/capability_gate.dart';
import '../isolation/business_capability.dart';

import 'route_paths.dart';

/// Single source of truth for the legacy-compatible top-level [GoRoute]s and
/// the alias redirects (design.md, Component 1).
///
/// Pure helpers ([aliasTargetFor], [knownLegacyPaths], [isKnownLegacyPath]) are
/// unit-testable without pumping widgets; [routes] supplies the `RouteBase`
/// list to spread into `AppRouter` (Task 2.6).
abstract final class LegacyRoutes {
  const LegacyRoutes._();

  // ---------------------------------------------------------------------------
  // Alias mapping (AD-6) — pure, total.
  // ---------------------------------------------------------------------------

  /// Returns the canonical go_router target for a legacy alias [path], or
  /// `null` when [path] is not an alias.
  ///
  /// This is a PURE, TOTAL function (same input always yields the same output,
  /// no side effects, defined for every `String`) so the `GoRouter.redirect`
  /// callback can consult it and tests can assert it directly. Canonical
  /// targets come from [RoutePaths] constants — never hardcoded — so they track
  /// the foundation routes (AD-6):
  ///
  ///   * `/auth_gate` (underscore) -> [RoutePaths.authGate] (`/auth-gate`)
  ///   * `/`          (logout/splash) -> [RoutePaths.splash]  (`/splash`)
  ///   * `/startup`   (legacy AuthGate entry) -> [RoutePaths.authGate]
  ///   * `/owner_login`    -> [RoutePaths.login] (`/login`)
  ///   * `/customer_login` -> [RoutePaths.login]
  ///   * `/signup`         -> [RoutePaths.login]
  ///   * anything else     -> `null` (not an alias)
  static String? aliasTargetFor(String path) {
    switch (path) {
      case '/auth_gate':
        return RoutePaths.authGate;
      case '/':
        return RoutePaths.splash;
      case '/startup':
        return RoutePaths.authGate;
      case '/owner_login':
      case '/customer_login':
      case '/signup':
        return RoutePaths.login;
      default:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Registered legacy paths (parity / inventory + dynamic-navigation net).
  // ---------------------------------------------------------------------------

  /// The single backing set of legacy named strings registered by [routes].
  ///
  /// Kept as ONE private constant so [knownLegacyPaths] and [isKnownLegacyPath]
  /// stay consistent with what [routes] actually registers (no drift).
  ///
  /// TODO(tasks 4.3-4.5, 6.2, 7.1): extend with each legacy named string as its
  /// `GoRoute` is registered in [routes]. See INVENTORY.md §2 for the full list
  /// of 121 legacy routes.
  ///
  /// Task 4.2 — auth/entry/dashboard family (INVENTORY.md §2 "Auth/entry" +
  /// "Core / dashboards"). Each entry below has a matching `GoRoute` in
  /// [routes] (parity by construction).
  static const Set<String> _knownLegacyPaths = <String>{
    // Auth / entry.
    '/license',
    '/onboarding',
    '/dashboard_selection',
    // Core / dashboards.
    '/home',
    '/home_modern',
    '/enhanced_dashboard',
    '/specialized_dashboard/restaurant',
    '/specialized_dashboard/clinic',
    '/owner_dashboard',
    // Pharmacy.
    '/pharmacy/dashboard',
    '/pharmacy/patients',
    '/pharmacy/salt-search',
    // Billing (Task 4.3 — no-arg billing family; arg routes
    // '/advanced_bill_creation' & '/invoice_preview' deferred to Task 6.2).
    '/pending',
    '/billing_flow',
    '/customer_bills',
    '/bill_search',
    '/advanced_billing',
    '/blacklist',
    '/reports',
    '/add_customer',
    '/total_bills',
    '/total_paid',
    '/pending_dues',
    '/customers_list',
    '/bill_scan',
    '/barcode_scanner',
    '/inventory',
    '/delivery_challans',
    '/proforma',
    '/payment-history',
    // Settings / admin (Task 4.4 — no-arg `systemSettings` family unless noted;
    // arg routes '/cloud_sync_settings' & '/editable_invoice' deferred to 6.2).
    '/business_settings',
    '/vendor_profile',
    '/settings',
    '/printer-settings',
    '/settings/invoice',
    '/settings/tax',
    '/settings/currency',
    '/settings/payment_gateway',
    '/settings/device',
    '/settings/server',
    '/settings/database',
    '/settings/storage',
    '/settings/data_import_export',
    '/settings/security',
    '/settings/notifications',
    '/settings/dunning',
    '/admin/recompute_dues',
    '/dev_health',
    '/dev_business_type_switcher',
    '/app_management',
    '/bill_template',
    // Reports / analytics / sync (Task 4.4 — no-arg family; arg routes
    // '/notifications', '/customer_report', '/customer_app' deferred to 6.2).
    '/insights',
    '/alerts',
    '/analytics',
    '/backup',
    '/gst-reports',
    '/daybook',
    '/party_ledger',
    '/catalogue',
    '/sync-status',
    // Vertical families (Task 4.5 — no-arg routes). Arg routes deferred to 6.2.
    // Hardware.
    '/hardware/credit-control',
    '/hardware/fast-billing',
    '/hardware/invoice-profiles',
    // Clinic.
    '/clinic/appointment',
    '/clinic/prescription',
    '/clinic/queue',
    // Book store.
    '/book_store/school_orders',
    '/book_store/consignments',
    // Service / repair.
    '/service_jobs',
    '/exchanges',
    '/job/create',
    '/job/status',
    '/job/deliver',
    // Petrol pump.
    '/pump/reading',
    '/pump/density',
    // Decoration & Catering.
    '/dc/dashboard',
    '/dc/bookings',
    '/dc/bookings/new',
    '/dc/decoration',
    '/dc/catering',
    '/dc/staff',
    '/dc/vendors',
    '/dc/inventory',
    '/dc/inventory_low',
    '/dc/reports',
    '/dc/expense_report',
    '/dc/billing',
    '/dc/kitchen',
    '/dc/venue',
    '/dc/calendar',
    '/dc/quotes',
    '/dc/profitability',
    '/dc/shopping_list',
    '/dc/vendor_payments',
    '/dc/event_detail',
    '/dc/quote_conversion',
    '/dc/staff_attendance',
    // School / Coaching ERP.
    '/ac/dashboard',
    '/ac/students',
    '/ac/students/register',
    '/ac/classes',
    '/ac/academic-year',
    '/ac/batches',
    '/ac/courses',
    '/ac/faculty',
    '/ac/fees',
    '/ac/attendance',
    '/ac/timetable',
    '/ac/exams',
    '/ac/report-cards',
    '/ac/materials',
    '/ac/library',
    '/ac/transport',
    '/ac/risk',
    '/ac/notifications',
    '/ac/bulk',
    '/ac/financial',
    '/ac/certificates',
    '/ac/fee-structure',
    // Computer shop.
    '/computer-shop/job-cards',
    '/computer-shop/warranty',
    '/computer-shop/serial-history',
    '/computer-shop/job-card-detail',
    '/computer-shop/create-job-card',
    '/computer-shop/multi-unit',
    // Electronics (Phase 2 — electronics-vertical-remediation).
    '/electronics/imei-tracking',
    // Jewellery (Phase 1 — jewellery-vertical-remediation).
    '/jewellery-gold-rate',
    '/jewellery-gold-rate-alert',
    '/jewellery-making-charges',
    '/jewellery-hallmark',
    '/jewellery-old-gold-exchange',
    '/jewellery-custom-orders',
    '/jewellery-repair',
    '/jewellery-gold-scheme',
    // Linking.
    '/vendor_qr_code',
    '/customer_link_shop',
    '/owner_link',
    '/customer_link_accept',
    '/shop_selection',
    '/business_type_selection',
    '/my-linked-shops',
    // Argument-bearing routes (Task 6.2) — DEFERRED from Phase B. Each has a
    // matching arg-bearing `GoRoute` in [routes] (parity by construction).
    '/clinic/consultation',
    '/clinic/history',
    '/clinic/labs',
    '/clothing/variants',
    '/clothing/tailoring',
    '/advanced_bill_creation',
    '/invoice_preview',
    '/hardware/operations',
    '/customer_portal',
    '/customer_report',
    '/customer_app',
    '/notifications',
    '/cloud_sync_settings',
    '/editable_invoice',
    // Purchase / Scan Bill arg routes (Task 6.2) — DEFERRED from Task 4.5.
    // Read settings.arguments in legacy; migrated to GoRouterState.extra.
    '/purchase/scan-bill',
    '/purchase/scan-bill/review',
    '/purchase/entries',
    // New routes absent from the legacy table (Task 7.1 — design AD-8). Pushed
    // imperatively (trial widgets / admin dashboard) but never registered in
    // buildAppRoutes(), so they failed even under the legacy table. Registered
    // here as first-class GoRoutes (parity by construction).
    '/upgrade',
    '/super-admin/tenants',
    '/super-admin/licenses',
    '/super-admin/audit',
    '/super-admin/usage',
  };

  /// Every legacy named string this layer registers (immutable view), for
  /// parity/inventory tests and the dynamic-navigation safety net (AD-7).
  ///
  /// Derived from [_knownLegacyPaths] so it always reflects the registered
  /// routes. Currently empty; extended by the later route tasks.
  static Set<String> get knownLegacyPaths =>
      Set<String>.unmodifiable(_knownLegacyPaths);

  /// Whether [path] resolves to a registered legacy route (vs. not-found).
  ///
  /// Pure predicate: returns `true` iff [path] is in [knownLegacyPaths]. Used
  /// by the dynamic-navigation safety net (AD-7) and parity tests.
  static bool isKnownLegacyPath(String path) =>
      _knownLegacyPaths.contains(path);

  // ---------------------------------------------------------------------------
  // Route registrations.
  // ---------------------------------------------------------------------------

  /// All top-level [GoRoute]s for the migrated legacy named strings (guards and
  /// defensive argument handling lifted verbatim from `buildAppRoutes()`).
  ///
  /// Spread into the existing `routes:` list in `AppRouter.build` (Task 2.6).
  ///
  /// TODO(tasks 4.3-4.5, 6.2, 7.1): register the remaining legacy named strings
  /// (see INVENTORY.md §2 and design.md AD-2/AD-3). Each route added here MUST
  /// also be recorded in [_knownLegacyPaths] to keep parity.
  ///
  /// Task 4.2 — auth/entry/dashboard family. Builder bodies (incl.
  /// `ProtectedRoute` wrapper TYPE, `requiredPermission` constants, and
  /// constructor args) are lifted CHARACTER-FOR-CHARACTER from
  /// `lib/app/routes.dart`'s `buildAppRoutes()` table (design.md AD-2). All
  /// routes in this family have argument shape `none`, so no `extra`/`state`
  /// conversion is required.
  static List<RouteBase> routes() => <RouteBase>[
    // ---- Auth / entry --------------------------------------------------------
    // '/license': (context) => const LicenseScreen(),
    GoRoute(
      path: '/license',
      builder: (BuildContext context, GoRouterState state) =>
          const LicenseScreen(),
    ),
    // '/onboarding': (context) => const VendorOnboardingScreen(),
    GoRoute(
      path: '/onboarding',
      builder: (BuildContext context, GoRouterState state) =>
          const VendorOnboardingScreen(),
    ),
    // '/dashboard_selection': (context) => const DashboardSelectionScreen(),
    GoRoute(
      path: '/dashboard_selection',
      builder: (BuildContext context, GoRouterState state) =>
          const DashboardSelectionScreen(),
    ),

    // ---- Core / dashboards ---------------------------------------------------
    // '/home': (context) => const ProtectedRoute(
    //     requiredPermission: Permissions.viewInvoices, child: AdaptiveShell()),
    GoRoute(
      path: '/home',
      builder: (BuildContext context, GoRouterState state) =>
          const ProtectedRoute(
            requiredPermission: Permissions.viewInvoices,
            child: AdaptiveShell(),
          ),
    ),
    // '/home_modern': (context) => const ProtectedRoute(
    //     requiredPermission: Permissions.viewInvoices, child: AdaptiveShell()),
    GoRoute(
      path: '/home_modern',
      builder: (BuildContext context, GoRouterState state) =>
          const ProtectedRoute(
            requiredPermission: Permissions.viewInvoices,
            child: AdaptiveShell(),
          ),
    ),
    // '/enhanced_dashboard': (context) => const OwnerDashboardRedirect(),
    GoRoute(
      path: '/enhanced_dashboard',
      builder: (BuildContext context, GoRouterState state) =>
          const OwnerDashboardRedirect(),
    ),
    // '/specialized_dashboard/restaurant': (context) =>
    //     const SpecializedDashboardRedirect(businessType: 'restaurant'),
    GoRoute(
      path: '/specialized_dashboard/restaurant',
      builder: (BuildContext context, GoRouterState state) =>
          const SpecializedDashboardRedirect(businessType: 'restaurant'),
    ),
    // '/specialized_dashboard/clinic': (context) =>
    //     const SpecializedDashboardRedirect(businessType: 'clinic'),
    GoRoute(
      path: '/specialized_dashboard/clinic',
      builder: (BuildContext context, GoRouterState state) =>
          const SpecializedDashboardRedirect(businessType: 'clinic'),
    ),
    // '/owner_dashboard': (context) => const ProtectedRoute(
    //     requiredPermission: Permissions.viewInvoices, child: AdaptiveShell()),
    GoRoute(
      path: '/owner_dashboard',
      builder: (BuildContext context, GoRouterState state) =>
          const ProtectedRoute(
            requiredPermission: Permissions.viewInvoices,
            child: AdaptiveShell(),
          ),
    ),

    // ---- Pharmacy (business-type specific) -----------------------------------
    // '/pharmacy/dashboard': (context) => const ProtectedRoute(
    //     requiredPermission: Permissions.viewInvoices,
    //     child: PharmacyDashboardScreen()),
    GoRoute(
      path: '/pharmacy/dashboard',
      builder: (BuildContext context, GoRouterState state) =>
          const ProtectedRoute(
            requiredPermission: Permissions.viewInvoices,
            child: PharmacyDashboardScreen(),
          ),
    ),
    // '/pharmacy/patients': (context) => const ProtectedRoute(
    //     requiredPermission: Permissions.viewCustomers,
    //     child: PatientRegistryScreen()),
    GoRoute(
      path: '/pharmacy/patients',
      builder: (BuildContext context, GoRouterState state) =>
          const ProtectedRoute(
            requiredPermission: Permissions.viewCustomers,
            child: PatientRegistryScreen(),
          ),
    ),
    // '/pharmacy/salt-search': (context) => const ProtectedRoute(
    //     requiredPermission: Permissions.viewProducts,
    //     child: SaltSearchScreen()),
    GoRoute(
      path: '/pharmacy/salt-search',
      builder: (BuildContext context, GoRouterState state) =>
          const ProtectedRoute(
            requiredPermission: Permissions.viewProducts,
            child: SaltSearchScreen(),
          ),
    ),

    // ---- Billing (Owner protected) -------------------------------------------
    // Task 4.3 — no-arg billing family. Builder bodies (incl. `VendorRoleGuard`
    // wrapper TYPE, `requiredPermission` constants, and child screen) are lifted
    // CHARACTER-FOR-CHARACTER from `lib/app/routes.dart`'s `buildAppRoutes()`
    // table (design.md AD-2). All routes in this family have argument shape
    // `none`. The two ARG billing routes — `/advanced_bill_creation` (Bill) and
    // `/invoice_preview` (EditableInvoice) — are DEFERRED to Task 6.2.
    // '/pending': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: const PendingScreen(),
    //     ),
    GoRoute(
      path: '/pending',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: const PendingScreen(),
      ),
    ),
    // '/billing_flow': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.createInvoices,
    //       child: const BillingFlow(),
    //     ),
    // Phase 2 (Task 5.2): BuyFlow is retail-only; DC has its own billing at
    // /dc/billing. BusinessGuard denies decorationCatering access.
    GoRoute(
      path: '/billing_flow',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.createInvoices,
        child: const BusinessGuard(
          allowedTypes: [
            BusinessType.grocery,
            BusinessType.pharmacy,
            BusinessType.restaurant,
            BusinessType.clothing,
            BusinessType.electronics,
            BusinessType.mobileShop,
            BusinessType.computerShop,
            BusinessType.hardware,
            BusinessType.service,
            BusinessType.wholesale,
            BusinessType.petrolPump,
            BusinessType.vegetablesBroker,
            BusinessType.clinic,
            BusinessType.bookStore,
            BusinessType.jewellery,
            BusinessType.autoParts,
            BusinessType.schoolErp,
            BusinessType.other,
          ],
          denialMessage:
              'Billing Flow is not available for Decoration & Catering businesses. Use DC Billing instead.',
          child: BillingFlow(),
        ),
      ),
    ),
    // '/customer_bills': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: const CustomerBillsScreen(),
    //     ),
    GoRoute(
      path: '/customer_bills',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: const CustomerBillsScreen(),
      ),
    ),
    // '/bill_search': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: const BillSearchScreen(),
    //     ),
    GoRoute(
      path: '/bill_search',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: const BillSearchScreen(),
      ),
    ),
    // '/advanced_billing': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.createInvoices,
    //       child: const AdvancedBillingScreen(),
    //     ),
    GoRoute(
      path: '/advanced_billing',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.createInvoices,
        child: const AdvancedBillingScreen(),
      ),
    ),
    // '/blacklist': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.manageStaff,
    //       child: const BlacklistManagementScreen(),
    //     ),
    GoRoute(
      path: '/blacklist',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.manageStaff,
        child: const BlacklistManagementScreen(),
      ),
    ),
    // '/reports': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewReports,
    //       child: const BillingReportsScreen(),
    //     ),
    GoRoute(
      path: '/reports',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewReports,
        child: const BillingReportsScreen(),
      ),
    ),
    // '/add_customer': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewClients,
    //       child: const AddCustomerScreen(),
    //     ),
    GoRoute(
      path: '/add_customer',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewClients,
        child: const AddCustomerScreen(),
      ),
    ),
    // '/total_bills': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: const TotalBillsScreen(),
    //     ),
    GoRoute(
      path: '/total_bills',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: const TotalBillsScreen(),
      ),
    ),
    // '/total_paid': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: const TotalPaidScreen(),
    //     ),
    GoRoute(
      path: '/total_paid',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: const TotalPaidScreen(),
      ),
    ),
    // '/pending_dues': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: const PendingDuesScreen(),
    //     ),
    GoRoute(
      path: '/pending_dues',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: const PendingDuesScreen(),
      ),
    ),
    // '/customers_list': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewClients,
    //       child: const CustomersListScreen(),
    //     ),
    GoRoute(
      path: '/customers_list',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewClients,
        child: const CustomersListScreen(),
      ),
    ),
    // '/bill_scan': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.createInvoices,
    //       child: const BillScanScreen(),
    //     ),
    GoRoute(
      path: '/bill_scan',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.createInvoices,
        child: const BillScanScreen(),
      ),
    ),
    // '/barcode_scanner': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.createInvoices,
    //       child: const BarcodeScannerScreen(),
    //     ),
    // Phase 2 (Task 5.2): Barcode scanning is retail product-specific; outside
    // DC scope. BusinessGuard denies decorationCatering access.
    GoRoute(
      path: '/barcode_scanner',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.createInvoices,
        child: const BusinessGuard(
          allowedTypes: [
            BusinessType.grocery,
            BusinessType.pharmacy,
            BusinessType.restaurant,
            BusinessType.clothing,
            BusinessType.electronics,
            BusinessType.mobileShop,
            BusinessType.computerShop,
            BusinessType.hardware,
            BusinessType.service,
            BusinessType.wholesale,
            BusinessType.petrolPump,
            BusinessType.vegetablesBroker,
            BusinessType.clinic,
            BusinessType.bookStore,
            BusinessType.jewellery,
            BusinessType.autoParts,
            BusinessType.schoolErp,
            BusinessType.other,
          ],
          denialMessage:
              'Barcode scanning is not available for Decoration & Catering businesses.',
          child: BarcodeScannerScreen(),
        ),
      ),
    ),
    // '/inventory': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: const InventoryDashboardScreen(),
    //     ),
    // Phase 2 (Task 5.2): Retail inventory dashboard is outside DC scope; DC
    // has its own inventory at /dc/inventory. BusinessGuard denies DC access.
    GoRoute(
      path: '/inventory',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: const BusinessGuard(
          allowedTypes: [
            BusinessType.grocery,
            BusinessType.pharmacy,
            BusinessType.restaurant,
            BusinessType.clothing,
            BusinessType.electronics,
            BusinessType.mobileShop,
            BusinessType.computerShop,
            BusinessType.hardware,
            BusinessType.service,
            BusinessType.wholesale,
            BusinessType.petrolPump,
            BusinessType.vegetablesBroker,
            BusinessType.clinic,
            BusinessType.bookStore,
            BusinessType.jewellery,
            BusinessType.autoParts,
            BusinessType.schoolErp,
            BusinessType.other,
          ],
          denialMessage:
              'Retail inventory is not available for Decoration & Catering businesses. Use DC Inventory instead.',
          child: InventoryDashboardScreen(),
        ),
      ),
    ),
    // '/delivery_challans': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: const DeliveryChallanListScreen(),
    //     ),
    // Phase 2 (Task 5.2): Delivery challans are retail goods-specific; outside
    // DC scope. BusinessGuard denies decorationCatering access.
    GoRoute(
      path: '/delivery_challans',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: const BusinessGuard(
          allowedTypes: [
            BusinessType.grocery,
            BusinessType.pharmacy,
            BusinessType.restaurant,
            BusinessType.clothing,
            BusinessType.electronics,
            BusinessType.mobileShop,
            BusinessType.computerShop,
            BusinessType.hardware,
            BusinessType.service,
            BusinessType.wholesale,
            BusinessType.petrolPump,
            BusinessType.vegetablesBroker,
            BusinessType.clinic,
            BusinessType.bookStore,
            BusinessType.jewellery,
            BusinessType.autoParts,
            BusinessType.schoolErp,
            BusinessType.other,
          ],
          denialMessage:
              'Delivery challans are not available for Decoration & Catering businesses.',
          child: DeliveryChallanListScreen(),
        ),
      ),
    ),
    // '/proforma': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.createInvoices,
    //       child: const ProformaScreen(),
    //     ),
    // Phase 2 (Task 5.2): Proforma invoices are retail-goods-specific; outside
    // DC scope. BusinessGuard denies decorationCatering access.
    GoRoute(
      path: '/proforma',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.createInvoices,
        child: const BusinessGuard(
          allowedTypes: [
            BusinessType.grocery,
            BusinessType.pharmacy,
            BusinessType.restaurant,
            BusinessType.clothing,
            BusinessType.electronics,
            BusinessType.mobileShop,
            BusinessType.computerShop,
            BusinessType.hardware,
            BusinessType.service,
            BusinessType.wholesale,
            BusinessType.petrolPump,
            BusinessType.vegetablesBroker,
            BusinessType.clinic,
            BusinessType.bookStore,
            BusinessType.jewellery,
            BusinessType.autoParts,
            BusinessType.schoolErp,
            BusinessType.other,
          ],
          denialMessage:
              'Proforma invoices are not available for Decoration & Catering businesses.',
          child: ProformaScreen(),
        ),
      ),
    ),
    // '/payment-history': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: const PaymentHistoryScreen(),
    //     ),
    GoRoute(
      path: '/payment-history',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: const PaymentHistoryScreen(),
      ),
    ),

    // ---- Settings / admin ----------------------------------------------------
    // Task 4.4 — no-arg settings/admin family. Builder bodies (incl.
    // `VendorRoleGuard` wrapper TYPE, `requiredPermission` constants, and child
    // screen) are lifted CHARACTER-FOR-CHARACTER from `lib/app/routes.dart`'s
    // `buildAppRoutes()` table (design.md AD-2). All routes in this family have
    // argument shape `none` and use `systemSettings` EXCEPT `/admin/recompute_dues`
    // (`manageStaff`) and `/dev_business_type_switcher` (NO guard — DEV/TEST only).
    // The two ARG settings routes — `/cloud_sync_settings` (String ownerId) and
    // `/editable_invoice` (Map) — are DEFERRED to Task 6.2.
    // '/business_settings': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.systemSettings,
    //       child: const BusinessSettingsScreen(),
    //     ),
    GoRoute(
      path: '/business_settings',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const BusinessSettingsScreen(),
      ),
    ),
    // '/vendor_profile': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.systemSettings,
    //       child: const VendorProfileScreen(),
    //     ),
    GoRoute(
      path: '/vendor_profile',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const VendorProfileScreen(),
      ),
    ),
    // '/settings': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.systemSettings,
    //       child: const SettingsScreen(),
    //     ),
    GoRoute(
      path: '/settings',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const SettingsScreen(),
      ),
    ),
    // '/printer-settings': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.systemSettings,
    //       child: const PrinterSettingsScreen(),
    //     ),
    GoRoute(
      path: '/printer-settings',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const PrinterSettingsScreen(),
      ),
    ),
    // '/settings/invoice': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.systemSettings,
    //       child: const InvoiceSettingsScreen(),
    //     ),
    GoRoute(
      path: '/settings/invoice',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const InvoiceSettingsScreen(),
      ),
    ),
    // '/settings/tax': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.systemSettings,
    //       child: const TaxConfigScreen(),
    //     ),
    GoRoute(
      path: '/settings/tax',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const TaxConfigScreen(),
      ),
    ),
    // '/settings/currency': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.systemSettings,
    //       child: const CurrencySettingsScreen(),
    //     ),
    GoRoute(
      path: '/settings/currency',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const CurrencySettingsScreen(),
      ),
    ),
    // '/settings/payment_gateway': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.systemSettings,
    //       child: const PaymentGatewaySettingsScreen(),
    //     ),
    GoRoute(
      path: '/settings/payment_gateway',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const PaymentGatewaySettingsScreen(),
      ),
    ),
    // '/settings/device': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.systemSettings,
    //       child: const DeviceSettingsScreen(),
    //     ),
    GoRoute(
      path: '/settings/device',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const DeviceSettingsScreen(),
      ),
    ),
    // '/settings/server': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.systemSettings,
    //       child: const ServerSettingsScreen(),
    //     ),
    GoRoute(
      path: '/settings/server',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const ServerSettingsScreen(),
      ),
    ),
    // '/settings/database': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.systemSettings,
    //       child: const DatabaseManagementScreen(),
    //     ),
    GoRoute(
      path: '/settings/database',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const DatabaseManagementScreen(),
      ),
    ),
    // '/settings/storage': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.systemSettings,
    //       child: const StorageManagementScreen(),
    //     ),
    GoRoute(
      path: '/settings/storage',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const StorageManagementScreen(),
      ),
    ),
    // '/settings/data_import_export': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.systemSettings,
    //       child: const DataImportExportScreen(),
    //     ),
    GoRoute(
      path: '/settings/data_import_export',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const DataImportExportScreen(),
      ),
    ),
    // '/settings/security': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.systemSettings,
    //       child: const SecuritySettingsScreen(),
    //     ),
    GoRoute(
      path: '/settings/security',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const SecuritySettingsScreen(),
      ),
    ),
    // '/settings/notifications': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.systemSettings,
    //       child: const NotificationSettingsScreen(),
    //     ),
    GoRoute(
      path: '/settings/notifications',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const NotificationSettingsScreen(),
      ),
    ),
    // '/settings/dunning': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.systemSettings,
    //       child: const DunningConfigScreen(),
    //     ),
    GoRoute(
      path: '/settings/dunning',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const DunningConfigScreen(),
      ),
    ),
    // '/admin/recompute_dues': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.manageStaff,
    //       child: const AdminMigrationsScreen(),
    //     ),
    GoRoute(
      path: '/admin/recompute_dues',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.manageStaff,
        child: const AdminMigrationsScreen(),
      ),
    ),
    // '/dev_health': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.systemSettings,
    //       child: const DeveloperHealthScreen(),
    //     ),
    GoRoute(
      path: '/dev_health',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const DeveloperHealthScreen(),
      ),
    ),
    // ⚠️ DEV/TEST ONLY — Remove before production release
    // '/dev_business_type_switcher': (context) =>
    //     const DevBusinessTypeSwitcherScreen(),
    GoRoute(
      path: '/dev_business_type_switcher',
      builder: (BuildContext context, GoRouterState state) =>
          const DevBusinessTypeSwitcherScreen(),
    ),
    // '/app_management': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.systemSettings,
    //       child: const AppManagementScreen(),
    //     ),
    GoRoute(
      path: '/app_management',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const AppManagementScreen(),
      ),
    ),
    // '/bill_template': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.systemSettings,
    //       child: const BillTemplateDesignerScreen(),
    //     ),
    GoRoute(
      path: '/bill_template',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const BillTemplateDesignerScreen(),
      ),
    ),

    // ---- Reports / analytics / sync ------------------------------------------
    // Task 4.4 — no-arg reports/analytics/sync family. Builder bodies (incl.
    // `VendorRoleGuard` wrapper TYPE, `requiredPermission` constants, and child
    // screen) are lifted CHARACTER-FOR-CHARACTER from `lib/app/routes.dart`'s
    // `buildAppRoutes()` table (design.md AD-2). All routes in this family have
    // argument shape `none`. The three ARG routes — `/notifications` (String
    // customerId), `/customer_report` (Map), `/customer_app` (Customer) — are
    // DEFERRED to Task 6.2.
    // '/insights': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewAnalytics,
    //       child: const InsightsScreen(),
    //     ),
    GoRoute(
      path: '/insights',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewAnalytics,
        child: const InsightsScreen(),
      ),
    ),
    // '/alerts': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewAnalytics,
    //       child: const AlertsScreen(),
    //     ),
    GoRoute(
      path: '/alerts',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewAnalytics,
        child: const AlertsScreen(),
      ),
    ),
    // '/analytics': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewAnalytics,
    //       child: const AnalyticsDashboardScreen(),
    //     ),
    GoRoute(
      path: '/analytics',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewAnalytics,
        child: const AnalyticsDashboardScreen(),
      ),
    ),
    // '/backup': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.exportReports,
    //       child: const BackupScreen(),
    //     ),
    GoRoute(
      path: '/backup',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.exportReports,
        child: const BackupScreen(),
      ),
    ),
    // '/gst-reports': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewReports,
    //       child: const GstReportsScreen(),
    //     ),
    GoRoute(
      path: '/gst-reports',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewReports,
        child: const GstReportsScreen(),
      ),
    ),
    // '/daybook': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewReports,
    //       child: const DayBookScreen(),
    //     ),
    GoRoute(
      path: '/daybook',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewReports,
        child: const DayBookScreen(),
      ),
    ),
    // '/party_ledger': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewClients,
    //       child: const PartyLedgerListScreen(),
    //     ),
    GoRoute(
      path: '/party_ledger',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewClients,
        child: const PartyLedgerListScreen(),
      ),
    ),
    // '/catalogue': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewClients,
    //       child: const CatalogueScreen(),
    //     ),
    GoRoute(
      path: '/catalogue',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewClients,
        child: const CatalogueScreen(),
      ),
    ),
    // '/sync-status': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewReports,
    //       child: const RealSyncScreen(),
    //     ),
    GoRoute(
      path: '/sync-status',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewReports,
        child: const RealSyncScreen(),
      ),
    ),

    // ---- Hardware (vertical) -------------------------------------------------
    // Task 4.5 — no-arg vertical family. Builder bodies (incl. `VendorRoleGuard`
    // + nested `BusinessGuard` wrapper TYPES, `requiredPermission` constants,
    // `allowedTypes` lists, and `denialMessage` text) are lifted
    // CHARACTER-FOR-CHARACTER from `lib/app/routes.dart`'s `buildAppRoutes()`
    // table (design.md AD-2). Arg routes are DEFERRED to Task 6.2:
    //   `/hardware/operations` (Map), `/clinic/consultation|history|labs` (Map),
    //   `/clothing/variants` (Map), `/computer-shop/create-job-card`,
    //   `/computer-shop/job-card-detail`, `/computer-shop/serial-history` (Map),
    //   `/customer_portal` (String), `/purchase/scan-bill` &
    //   `/purchase/entries` (read settings.arguments → AD-3 defer).
    // '/hardware/credit-control': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewReports,
    //       child: const BusinessGuard(
    //         allowedTypes: [BusinessType.hardware],
    //         denialMessage:
    //             'Contractor credit control is available for Hardware business type only.',
    //         child: HardwareCreditControlScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/hardware/credit-control',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewReports,
        child: const BusinessGuard(
          allowedTypes: [BusinessType.hardware],
          denialMessage:
              'Contractor credit control is available for Hardware business type only.',
          child: HardwareCreditControlScreen(),
        ),
      ),
    ),
    // '/hardware/fast-billing': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.createInvoices,
    //       child: const BusinessGuard(
    //         allowedTypes: [BusinessType.hardware],
    //         denialMessage:
    //             'Fast billing is available for Hardware business type only.',
    //         child: BillCreationScreenV2(),
    //       ),
    //     ),
    GoRoute(
      path: '/hardware/fast-billing',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.createInvoices,
        child: const BusinessGuard(
          allowedTypes: [BusinessType.hardware],
          denialMessage:
              'Fast billing is available for Hardware business type only.',
          child: BillCreationScreenV2(),
        ),
      ),
    ),
    // '/hardware/invoice-profiles': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.systemSettings,
    //       child: const BusinessGuard(
    //         allowedTypes: [BusinessType.hardware],
    //         denialMessage:
    //             'Invoice profile customization is available for Hardware business type only.',
    //         child: HardwareInvoiceProfileScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/hardware/invoice-profiles',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const BusinessGuard(
          allowedTypes: [BusinessType.hardware],
          denialMessage:
              'Invoice profile customization is available for Hardware business type only.',
          child: HardwareInvoiceProfileScreen(),
        ),
      ),
    ),

    // ---- Clinic (vertical) ---------------------------------------------------
    // '/clinic/appointment': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewClients,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.clinic],
    //         denialMessage: 'Only Clinics can access Appointments',
    //         child: const AppointmentScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/clinic/appointment',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewClients,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.clinic],
          denialMessage: 'Only Clinics can access Appointments',
          child: const AppointmentScreen(),
        ),
      ),
    ),
    // '/clinic/prescription': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewClients,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.clinic],
    //         denialMessage: 'Only Clinics can access Prescriptions',
    //         child: const AddPrescriptionScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/clinic/prescription',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewClients,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.clinic],
          denialMessage: 'Only Clinics can access Prescriptions',
          child: const AddPrescriptionScreen(),
        ),
      ),
    ),
    // '/clinic/queue': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewClients,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.clinic],
    //         denialMessage: 'Only Clinics can access Patient Queue',
    //         child: const PatientQueueScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/clinic/queue',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewClients,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.clinic],
          denialMessage: 'Only Clinics can access Patient Queue',
          child: const PatientQueueScreen(),
        ),
      ),
    ),

    // ---- Book store (vertical) -----------------------------------------------
    // '/book_store/school_orders': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewReports,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.bookStore],
    //         denialMessage: 'Only Book Stores can access School Orders',
    //         child: const SchoolOrderScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/book_store/school_orders',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewReports,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.bookStore],
          denialMessage: 'Only Book Stores can access School Orders',
          child: const SchoolOrderScreen(),
        ),
      ),
    ),
    // '/book_store/consignments': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewReports,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.bookStore],
    //         denialMessage: 'Only Book Stores can access Consignments',
    //         child: const ConsignmentSettlementScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/book_store/consignments',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewReports,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.bookStore],
          denialMessage: 'Only Book Stores can access Consignments',
          child: const ConsignmentSettlementScreen(),
        ),
      ),
    ),

    // ---- Service / repair (vertical) -----------------------------------------
    // '/service_jobs': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.manageStaff,
    //       child: const ServiceJobListScreen(),
    //     ),
    GoRoute(
      path: '/service_jobs',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.manageStaff,
        child: const ServiceJobListScreen(),
      ),
    ),
    // '/exchanges': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.manageStaff,
    //       child: const ExchangeListScreen(),
    //     ),
    GoRoute(
      path: '/exchanges',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.manageStaff,
        child: const ExchangeListScreen(),
      ),
    ),
    // '/job/create': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.manageStaff,
    //       child: BusinessGuard(
    //         allowedTypes: const [
    //           BusinessType.mobileShop,
    //           BusinessType.computerShop,
    //           BusinessType.service,
    //           BusinessType.electronics,
    //         ],
    //         denialMessage: 'This feature is for Service/Repair businesses only',
    //         child: const CreateServiceJobScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/job/create',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.manageStaff,
        child: BusinessGuard(
          allowedTypes: const [
            BusinessType.mobileShop,
            BusinessType.computerShop,
            BusinessType.service,
            BusinessType.electronics,
          ],
          denialMessage: 'This feature is for Service/Repair businesses only',
          child: const CreateServiceJobScreen(),
        ),
      ),
    ),
    // '/job/status': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.manageStaff,
    //       child: BusinessGuard(
    //         allowedTypes: const [
    //           BusinessType.mobileShop,
    //           BusinessType.computerShop,
    //           BusinessType.service,
    //           BusinessType.electronics,
    //         ],
    //         child: const ServiceJobListScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/job/status',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.manageStaff,
        child: BusinessGuard(
          allowedTypes: const [
            BusinessType.mobileShop,
            BusinessType.computerShop,
            BusinessType.service,
            BusinessType.electronics,
          ],
          child: const ServiceJobListScreen(),
        ),
      ),
    ),
    // '/job/deliver': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.manageStaff,
    //       child: BusinessGuard(
    //         allowedTypes: const [
    //           BusinessType.mobileShop,
    //           BusinessType.computerShop,
    //           BusinessType.service,
    //           BusinessType.electronics,
    //         ],
    //         child: const ServiceJobListScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/job/deliver',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.manageStaff,
        child: BusinessGuard(
          allowedTypes: const [
            BusinessType.mobileShop,
            BusinessType.computerShop,
            BusinessType.service,
            BusinessType.electronics,
          ],
          child: const ServiceJobListScreen(),
        ),
      ),
    ),

    // ---- Petrol pump (vertical) ----------------------------------------------
    // '/pump/reading': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewReports,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.petrolPump],
    //         denialMessage: 'Only Petrol Pumps can access Meter Readings',
    //         child: const DispenserListScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/pump/reading',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewReports,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.petrolPump],
          denialMessage: 'Only Petrol Pumps can access Meter Readings',
          child: const DispenserListScreen(),
        ),
      ),
    ),
    // '/pump/density': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewReports,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.petrolPump],
    //         child: const FuelRatesScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/pump/density',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewReports,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.petrolPump],
          child: const FuelRatesScreen(),
        ),
      ),
    ),

    // ---- Decoration & Catering (vertical) ------------------------------------
    // '/dc/dashboard': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.decorationCatering],
    //         denialMessage: 'Only Decoration & Catering businesses can access this module.',
    //         child: const DcDashboardScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/dc/dashboard',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.decorationCatering],
          denialMessage:
              'Only Decoration & Catering businesses can access this module.',
          child: const DcDashboardScreen(),
        ),
      ),
    ),
    // '/dc/bookings': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.decorationCatering],
    //         denialMessage: 'Only Decoration & Catering businesses can access Event Bookings.',
    //         child: const DcBookingsScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/dc/bookings',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.decorationCatering],
          denialMessage:
              'Only Decoration & Catering businesses can access Event Bookings.',
          child: const DcBookingsScreen(),
        ),
      ),
    ),
    // '/dc/bookings/new': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.createInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.decorationCatering],
    //         denialMessage: 'Only Decoration & Catering businesses can create bookings.',
    //         child: const DcBookingsScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/dc/bookings/new',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.createInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.decorationCatering],
          denialMessage:
              'Only Decoration & Catering businesses can create bookings.',
          child: const DcBookingsScreen(),
        ),
      ),
    ),
    // '/dc/decoration': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.decorationCatering],
    //         denialMessage: 'Only Decoration & Catering businesses can access Decoration.',
    //         child: const DcDecorationScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/dc/decoration',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.decorationCatering],
          denialMessage:
              'Only Decoration & Catering businesses can access Decoration.',
          child: const DcDecorationScreen(),
        ),
      ),
    ),
    // '/dc/catering': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.decorationCatering],
    //         denialMessage: 'Only Decoration & Catering businesses can access Catering.',
    //         child: const DcCateringScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/dc/catering',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.decorationCatering],
          denialMessage:
              'Only Decoration & Catering businesses can access Catering.',
          child: const DcCateringScreen(),
        ),
      ),
    ),
    // '/dc/staff': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.decorationCatering],
    //         denialMessage: 'Only Decoration & Catering businesses can access Staff.',
    //         child: const DcStaffScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/dc/staff',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.decorationCatering],
          denialMessage:
              'Only Decoration & Catering businesses can access Staff.',
          child: const DcStaffScreen(),
        ),
      ),
    ),
    // '/dc/vendors': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.decorationCatering],
    //         denialMessage: 'Only Decoration & Catering businesses can access Vendors.',
    //         child: const DcStaffScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/dc/vendors',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.decorationCatering],
          denialMessage:
              'Only Decoration & Catering businesses can access Vendors.',
          child: const DcVendorPaymentsScreen(),
        ),
      ),
    ),
    // '/dc/inventory': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.decorationCatering],
    //         denialMessage: 'Only Decoration & Catering businesses can access Inventory.',
    //         child: const DcInventoryScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/dc/inventory',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.decorationCatering],
          denialMessage:
              'Only Decoration & Catering businesses can access Inventory.',
          child: const DcInventoryScreen(),
        ),
      ),
    ),
    // '/dc/inventory_low': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.decorationCatering],
    //         denialMessage: 'Only Decoration & Catering businesses can access Inventory.',
    //         child: const DcInventoryScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/dc/inventory_low',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.decorationCatering],
          denialMessage:
              'Only Decoration & Catering businesses can access Inventory.',
          child: const DcInventoryScreen(),
        ),
      ),
    ),
    // '/dc/reports': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewReports,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.decorationCatering],
    //         denialMessage: 'Only Decoration & Catering businesses can access Reports.',
    //         child: const DcReportsScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/dc/reports',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewReports,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.decorationCatering],
          denialMessage:
              'Only Decoration & Catering businesses can access Reports.',
          child: const DcReportsScreen(),
        ),
      ),
    ),
    // '/dc/expense_report': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewReports,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.decorationCatering],
    //         denialMessage: 'Only Decoration & Catering businesses can access Reports.',
    //         child: const DcReportsScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/dc/expense_report',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewReports,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.decorationCatering],
          denialMessage:
              'Only Decoration & Catering businesses can access Reports.',
          child: const DcReportsScreen(),
        ),
      ),
    ),
    // '/dc/billing': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.createInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.decorationCatering],
    //         denialMessage: 'Only Decoration & Catering businesses can access Billing.',
    //         child: const DcBillingScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/dc/billing',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.createInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.decorationCatering],
          denialMessage:
              'Only Decoration & Catering businesses can access Billing.',
          child: const DcBillingScreen(),
        ),
      ),
    ),
    // '/dc/kitchen': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.decorationCatering],
    //         denialMessage: 'Only Decoration & Catering businesses can access Kitchen Planning.',
    //         child: const DcCateringScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/dc/kitchen',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.decorationCatering],
          denialMessage:
              'Only Decoration & Catering businesses can access Kitchen Planning.',
          child: const DcCateringScreen(),
        ),
      ),
    ),
    // '/dc/venue': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.decorationCatering],
    //         denialMessage: 'Only Decoration & Catering businesses can access Venue Management.',
    //         child: const DcDecorationScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/dc/venue',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.decorationCatering],
          denialMessage:
              'Only Decoration & Catering businesses can access Venue Management.',
          child: const DcDecorationScreen(),
        ),
      ),
    ),
    // '/dc/calendar': registered per Phase 1 reachability (Task 3.11).
    GoRoute(
      path: '/dc/calendar',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.decorationCatering],
          denialMessage:
              'Only Decoration & Catering businesses can access Calendar.',
          child: const DcCalendarScreen(),
        ),
      ),
    ),
    // '/dc/quotes': registered per Phase 1 reachability (Task 3.11).
    GoRoute(
      path: '/dc/quotes',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.decorationCatering],
          denialMessage:
              'Only Decoration & Catering businesses can access Quotes.',
          child: const DcQuotesScreen(),
        ),
      ),
    ),
    // '/dc/profitability': registered per Phase 1 reachability (Task 3.11).
    GoRoute(
      path: '/dc/profitability',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewReports,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.decorationCatering],
          denialMessage:
              'Only Decoration & Catering businesses can access Profitability.',
          child: const DcProfitabilityScreen(),
        ),
      ),
    ),
    // '/dc/shopping_list': registered per Phase 1 reachability (Task 3.11).
    GoRoute(
      path: '/dc/shopping_list',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.decorationCatering],
          denialMessage:
              'Only Decoration & Catering businesses can access Shopping List.',
          child: const DcShoppingListScreen(),
        ),
      ),
    ),
    // '/dc/vendor_payments': registered per Phase 1 reachability (Task 3.11).
    GoRoute(
      path: '/dc/vendor_payments',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.decorationCatering],
          denialMessage:
              'Only Decoration & Catering businesses can access Vendor Payments.',
          child: const DcVendorPaymentsScreen(),
        ),
      ),
    ),
    // '/dc/event_detail': registered per Phase 1 reachability (Task 3.11).
    // Accepts eventId via GoRouterState.extra (safe cast with fallback).
    GoRoute(
      path: '/dc/event_detail',
      builder: (BuildContext context, GoRouterState state) {
        final args = state.extra;
        final String eventId = args is String && args.isNotEmpty ? args : '';
        return VendorRoleGuard(
          requiredPermission: Permissions.viewInvoices,
          child: BusinessGuard(
            allowedTypes: const [BusinessType.decorationCatering],
            denialMessage:
                'Only Decoration & Catering businesses can access Event Details.',
            child: DcEventDetailScreen(eventId: eventId),
          ),
        );
      },
    ),
    // '/dc/quote_conversion': registered per Phase 1 reachability (Task 3.11).
    // Accepts DcQuote via GoRouterState.extra (safe cast with fallback).
    GoRoute(
      path: '/dc/quote_conversion',
      builder: (BuildContext context, GoRouterState state) {
        final args = state.extra;
        if (args is DcQuote) {
          return VendorRoleGuard(
            requiredPermission: Permissions.createInvoices,
            child: BusinessGuard(
              allowedTypes: const [BusinessType.decorationCatering],
              denialMessage:
                  'Only Decoration & Catering businesses can access Quote Conversion.',
              child: DcQuoteConversionScreen(quote: args),
            ),
          );
        }
        // Fallback: if no valid quote passed, show the quotes list.
        return VendorRoleGuard(
          requiredPermission: Permissions.viewInvoices,
          child: BusinessGuard(
            allowedTypes: const [BusinessType.decorationCatering],
            denialMessage:
                'Only Decoration & Catering businesses can access Quotes.',
            child: const DcQuotesScreen(),
          ),
        );
      },
    ),
    // '/dc/staff_attendance': registered per Phase 1 reachability (Task 3.11).
    GoRoute(
      path: '/dc/staff_attendance',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.decorationCatering],
          denialMessage:
              'Only Decoration & Catering businesses can access Staff Attendance.',
          child: const DcStaffAttendanceScreen(),
        ),
      ),
    ),

    // ---- School / Coaching ERP (vertical) ------------------------------------
    // PHASE 1 ALIGNMENT NOTES (Task 3.3):
    // • `/ac/students` → AcStudentsScreen (CONFIRMED more feature-complete, Phase 0 §3.9).
    // • `/ac/students/register` → AcStudentRegistrationScreen (new distinct route, Req 4.6).
    // • All dormant GoRouter `/ac/*` entries below ARE the live bindings (GoRouter is
    //   the sole nav root per gorouter-navigation-migration spec). Each entry already
    //   references the same target screen as its binding — alignment confirmed (Req 4.7).
    // • REDUNDANCY FLAG (Req 4.9): The backend `school-erp` module manifest
    //   (`my-backend/src/modules/school-erp/manifest.ts`) defines navItems/features that
    //   duplicate navigation already provided by `sidebarSectionsProvider`. This is flagged
    //   as the "SchoolErpModule.navItems" redundancy for Phase 9 cleanup — DO NOT DELETE
    //   in this phase. Navigation is sourced ONLY from `sidebarSectionsProvider` (Req 4.8).
    // '/ac/dashboard': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.schoolErp],
    //         denialMessage: 'Only School / Coaching ERP businesses can access this module.',
    //         child: const AcDashboardScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/ac/dashboard',
      builder: (BuildContext context, GoRouterState state) =>
          SchoolPermissionGuard(
            permission: SchoolPermission.viewStudents,
            child: BusinessGuard(
              allowedTypes: const [BusinessType.schoolErp],
              denialMessage:
                  'Only School / Coaching ERP businesses can access this module.',
              child: const AcDashboardScreen(),
            ),
          ),
    ),
    // '/ac/students': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewClients,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.schoolErp],
    //         denialMessage: 'Only School / Coaching ERP businesses can access Students.',
    //         child: const AcStudentsScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/ac/students',
      builder: (BuildContext context, GoRouterState state) =>
          SchoolPermissionGuard(
            permission: SchoolPermission.viewStudents,
            child: BusinessGuard(
              allowedTypes: const [BusinessType.schoolErp],
              denialMessage:
                  'Only School / Coaching ERP businesses can access Students.',
              child: const AcStudentsScreen(),
            ),
          ),
    ),
    // '/ac/students/register': Distinct non-colliding path for
    // AcStudentRegistrationScreen (resolves the latent /ac/students collision
    // per Phase 0 §3.9 — Requirement 4.6). Guarded by SchoolPermission.viewStudents
    // (Phase 3 — Requirement 6.3).
    GoRoute(
      path: '/ac/students/register',
      builder: (BuildContext context, GoRouterState state) => SchoolPermissionGuard(
        permission: SchoolPermission.viewStudents,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.schoolErp],
          denialMessage:
              'Only School / Coaching ERP businesses can access Student Registration.',
          child: const AcStudentRegistrationScreen(),
        ),
      ),
    ),
    // '/ac/classes': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.schoolErp],
    //         denialMessage: 'Only School / Coaching ERP businesses can access Classes & Sections.',
    //         child: const AcClassSectionsScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/ac/classes',
      builder: (BuildContext context, GoRouterState state) => SchoolPermissionGuard(
        permission: SchoolPermission.viewStudents,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.schoolErp],
          denialMessage:
              'Only School / Coaching ERP businesses can access Classes & Sections.',
          child: const AcClassSectionsScreen(),
        ),
      ),
    ),
    // '/ac/academic-year': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.schoolErp],
    //         denialMessage: 'Only School / Coaching ERP businesses can access Academic Year.',
    //         child: const AcAcademicYearScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/ac/academic-year',
      builder: (BuildContext context, GoRouterState state) => SchoolPermissionGuard(
        permission: SchoolPermission.viewStudents,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.schoolErp],
          denialMessage:
              'Only School / Coaching ERP businesses can access Academic Year.',
          child: const AcAcademicYearScreen(),
        ),
      ),
    ),
    // '/ac/batches': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.schoolErp],
    //         denialMessage: 'Only School / Coaching ERP businesses can access Batches.',
    //         child: const AcBatchesScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/ac/batches',
      builder: (BuildContext context, GoRouterState state) =>
          SchoolPermissionGuard(
            permission: SchoolPermission.viewStudents,
            child: BusinessGuard(
              allowedTypes: const [BusinessType.schoolErp],
              denialMessage:
                  'Only School / Coaching ERP businesses can access Batches.',
              child: const AcBatchesScreen(),
            ),
          ),
    ),
    // '/ac/courses': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.schoolErp],
    //         denialMessage: 'Only School / Coaching ERP businesses can access Courses.',
    //         child: const AcCoursesScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/ac/courses',
      builder: (BuildContext context, GoRouterState state) =>
          SchoolPermissionGuard(
            permission: SchoolPermission.viewStudents,
            child: BusinessGuard(
              allowedTypes: const [BusinessType.schoolErp],
              denialMessage:
                  'Only School / Coaching ERP businesses can access Courses.',
              child: const AcCoursesScreen(),
            ),
          ),
    ),
    // '/ac/faculty': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.schoolErp],
    //         denialMessage: 'Only School / Coaching ERP businesses can access Faculty.',
    //         child: const AcFacultyScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/ac/faculty',
      builder: (BuildContext context, GoRouterState state) =>
          SchoolPermissionGuard(
            permission: SchoolPermission.viewStudents,
            child: BusinessGuard(
              allowedTypes: const [BusinessType.schoolErp],
              denialMessage:
                  'Only School / Coaching ERP businesses can access Faculty.',
              child: const AcFacultyScreen(),
            ),
          ),
    ),
    // '/ac/fees': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.schoolErp],
    //         denialMessage: 'Only School / Coaching ERP businesses can access Fee Collection.',
    //         child: const AcFeeCollectionScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/ac/fees',
      builder: (BuildContext context, GoRouterState state) => SchoolPermissionGuard(
        permission: SchoolPermission.viewFees,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.schoolErp],
          denialMessage:
              'Only School / Coaching ERP businesses can access Fee Collection.',
          child: const AcFeeCollectionScreen(),
        ),
      ),
    ),
    // '/ac/attendance': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.schoolErp],
    //         denialMessage: 'Only School / Coaching ERP businesses can access Attendance.',
    //         child: const AcAttendanceScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/ac/attendance',
      builder: (BuildContext context, GoRouterState state) =>
          SchoolPermissionGuard(
            permission: SchoolPermission.markAttendance,
            child: BusinessGuard(
              allowedTypes: const [BusinessType.schoolErp],
              denialMessage:
                  'Only School / Coaching ERP businesses can access Attendance.',
              child: const AcAttendanceScreen(),
            ),
          ),
    ),
    // '/ac/timetable': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.schoolErp],
    //         denialMessage: 'Only School / Coaching ERP businesses can access Timetable.',
    //         child: const AcTimetableScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/ac/timetable',
      builder: (BuildContext context, GoRouterState state) =>
          SchoolPermissionGuard(
            permission: SchoolPermission.viewStudents,
            child: BusinessGuard(
              allowedTypes: const [BusinessType.schoolErp],
              denialMessage:
                  'Only School / Coaching ERP businesses can access Timetable.',
              child: const AcTimetableScreen(),
            ),
          ),
    ),
    // '/ac/exams': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.schoolErp],
    //         denialMessage: 'Only School / Coaching ERP businesses can access Exams.',
    //         child: const AcExamsScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/ac/exams',
      builder: (BuildContext context, GoRouterState state) =>
          SchoolPermissionGuard(
            permission: SchoolPermission.enterMarks,
            child: BusinessGuard(
              allowedTypes: const [BusinessType.schoolErp],
              denialMessage:
                  'Only School / Coaching ERP businesses can access Exams.',
              child: const AcExamsScreen(),
            ),
          ),
    ),
    // '/ac/report-cards': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewReports,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.schoolErp],
    //         denialMessage: 'Only School / Coaching ERP businesses can access Report Cards.',
    //         child: const AcReportCardsScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/ac/report-cards',
      builder: (BuildContext context, GoRouterState state) =>
          SchoolPermissionGuard(
            permission: SchoolPermission.enterMarks,
            child: BusinessGuard(
              allowedTypes: const [BusinessType.schoolErp],
              denialMessage:
                  'Only School / Coaching ERP businesses can access Report Cards.',
              child: const AcReportCardsScreen(),
            ),
          ),
    ),
    // '/ac/materials': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.schoolErp],
    //         denialMessage: 'Only School / Coaching ERP businesses can access Study Materials.',
    //         child: const AcMaterialsScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/ac/materials',
      builder: (BuildContext context, GoRouterState state) => SchoolPermissionGuard(
        permission: SchoolPermission.viewStudents,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.schoolErp],
          denialMessage:
              'Only School / Coaching ERP businesses can access Study Materials.',
          child: const AcMaterialsScreen(),
        ),
      ),
    ),
    // '/ac/library': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.schoolErp],
    //         denialMessage: 'Only School / Coaching ERP businesses can access Library.',
    //         child: const AcLibraryScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/ac/library',
      builder: (BuildContext context, GoRouterState state) =>
          SchoolPermissionGuard(
            permission: SchoolPermission.viewStudents,
            child: BusinessGuard(
              allowedTypes: const [BusinessType.schoolErp],
              denialMessage:
                  'Only School / Coaching ERP businesses can access Library.',
              child: const AcLibraryScreen(),
            ),
          ),
    ),
    // '/ac/transport': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.schoolErp],
    //         denialMessage: 'Only School / Coaching ERP businesses can access Transport.',
    //         child: const AcTransportScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/ac/transport',
      builder: (BuildContext context, GoRouterState state) =>
          SchoolPermissionGuard(
            permission: SchoolPermission.viewStudents,
            child: BusinessGuard(
              allowedTypes: const [BusinessType.schoolErp],
              denialMessage:
                  'Only School / Coaching ERP businesses can access Transport.',
              child: const AcTransportScreen(),
            ),
          ),
    ),
    // '/ac/risk': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewReports,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.schoolErp],
    //         denialMessage: 'Only School / Coaching ERP businesses can access Risk Detection.',
    //         child: const AcRiskDetectionScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/ac/risk',
      builder: (BuildContext context, GoRouterState state) => SchoolPermissionGuard(
        permission: SchoolPermission.viewFees,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.schoolErp],
          denialMessage:
              'Only School / Coaching ERP businesses can access Risk Detection.',
          child: const AcRiskDetectionScreen(),
        ),
      ),
    ),
    // '/ac/notifications': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.schoolErp],
    //         denialMessage: 'Only School / Coaching ERP businesses can access Notifications.',
    //         child: const AcNotificationsScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/ac/notifications',
      builder: (BuildContext context, GoRouterState state) => SchoolPermissionGuard(
        permission: SchoolPermission.viewStudents,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.schoolErp],
          denialMessage:
              'Only School / Coaching ERP businesses can access Notifications.',
          child: const AcNotificationsScreen(),
        ),
      ),
    ),
    // '/ac/bulk': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.createInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.schoolErp],
    //         denialMessage: 'Only School / Coaching ERP businesses can access Bulk Operations.',
    //         child: const AcBulkOperationsScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/ac/bulk',
      builder: (BuildContext context, GoRouterState state) => SchoolPermissionGuard(
        permission: SchoolPermission.viewStudents,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.schoolErp],
          denialMessage:
              'Only School / Coaching ERP businesses can access Bulk Operations.',
          child: const AcBulkOperationsScreen(),
        ),
      ),
    ),
    // '/ac/financial': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewReports,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.schoolErp],
    //         denialMessage: 'Only School / Coaching ERP businesses can access Financial Reports.',
    //         child: const AcFinancialReportsScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/ac/financial',
      builder: (BuildContext context, GoRouterState state) => SchoolPermissionGuard(
        permission: SchoolPermission.viewFees,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.schoolErp],
          denialMessage:
              'Only School / Coaching ERP businesses can access Financial Reports.',
          child: const AcFinancialReportsScreen(),
        ),
      ),
    ),
    // '/ac/certificates': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.createInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.schoolErp],
    //         denialMessage: 'Only School / Coaching ERP businesses can access Certificates.',
    //         child: const AcCertificateGeneratorScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/ac/certificates',
      builder: (BuildContext context, GoRouterState state) =>
          SchoolPermissionGuard(
            permission: SchoolPermission.viewStudents,
            child: BusinessGuard(
              allowedTypes: const [BusinessType.schoolErp],
              denialMessage:
                  'Only School / Coaching ERP businesses can access Certificates.',
              child: const AcCertificateGeneratorScreen(),
            ),
          ),
    ),
    // '/ac/fee-structure': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.schoolErp],
    //         denialMessage: 'Only School / Coaching ERP businesses can access Fee Structure.',
    //         child: const AcClasswiseFeeScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/ac/fee-structure',
      builder: (BuildContext context, GoRouterState state) => SchoolPermissionGuard(
        permission: SchoolPermission.viewFees,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.schoolErp],
          denialMessage:
              'Only School / Coaching ERP businesses can access Fee Structure.',
          child: const AcClasswiseFeeScreen(),
        ),
      ),
    ),

    // ---- Phase 6 — Production-Ready orphaned screens (Task 13.1, Req 9.1, 9.2, 9.6) ----
    // Each of the 4 remaining Production-Ready screens rated in Phase 0 §3.8
    // gets exactly one GoRoute + SchoolPermissionGuard + BusinessGuard.
    // AcStudentRegistrationScreen was already wired in Phase 1 (task 3.3).
    GoRoute(
      path: '/ac/admissions',
      builder: (BuildContext context, GoRouterState state) =>
          SchoolPermissionGuard(
            permission: SchoolPermission.viewStudents,
            child: BusinessGuard(
              allowedTypes: const [BusinessType.schoolErp],
              denialMessage:
                  'Only School / Coaching ERP businesses can access Admissions.',
              child: const AcAdmissionsScreen(),
            ),
          ),
    ),
    GoRoute(
      path: '/ac/lesson-plans',
      builder: (BuildContext context, GoRouterState state) =>
          SchoolPermissionGuard(
            permission: SchoolPermission.viewStudents,
            child: BusinessGuard(
              allowedTypes: const [BusinessType.schoolErp],
              denialMessage:
                  'Only School / Coaching ERP businesses can access Lesson Plans.',
              child: const AcLessonPlansScreen(),
            ),
          ),
    ),
    GoRoute(
      path: '/ac/homework',
      builder: (BuildContext context, GoRouterState state) =>
          SchoolPermissionGuard(
            permission: SchoolPermission.viewStudents,
            child: BusinessGuard(
              allowedTypes: const [BusinessType.schoolErp],
              denialMessage:
                  'Only School / Coaching ERP businesses can access Homework.',
              child: const AcHomeworkScreen(),
            ),
          ),
    ),
    GoRoute(
      path: '/ac/id-cards',
      builder: (BuildContext context, GoRouterState state) =>
          SchoolPermissionGuard(
            permission: SchoolPermission.viewStudents,
            child: BusinessGuard(
              allowedTypes: const [BusinessType.schoolErp],
              denialMessage:
                  'Only School / Coaching ERP businesses can access ID Cards.',
              child: const AcIdCardsScreen(),
            ),
          ),
    ),

    // ---- Computer shop (vertical) --------------------------------------------
    // '/computer-shop/job-cards': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.computerShop],
    //         denialMessage: 'Only Computer Shop businesses can access Job Cards.',
    //         child: const JobCardListScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/computer-shop/job-cards',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [
            BusinessType.computerShop,
            BusinessType.mobileShop,
          ],
          denialMessage:
              'Job Cards are available for: Computer Shop, Mobile Phone Shop.',
          child: const CapabilityGate(
            capability: BusinessCapability.useJobSheets,
            allowedTypes: [BusinessType.computerShop, BusinessType.mobileShop],
            child: JobCardListScreen(),
          ),
        ),
      ),
    ),
    // '/computer-shop/warranty': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.viewInvoices,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.computerShop],
    //         denialMessage: 'Only Computer Shop businesses can access Warranty.',
    //         child: const WarrantyScreen(),
    //       ),
    //     ),
    GoRoute(
      path: '/computer-shop/warranty',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [
            BusinessType.computerShop,
            BusinessType.mobileShop,
            BusinessType.electronics,
          ],
          denialMessage:
              'Warranty is available for: Computer Shop, Mobile Phone Shop, Electronics.',
          child: const CapabilityGate(
            capability: BusinessCapability.useWarranty,
            allowedTypes: [
              BusinessType.computerShop,
              BusinessType.mobileShop,
              BusinessType.electronics,
            ],
            child: WarrantyScreen(),
          ),
        ),
      ),
    ),
    // Phase 3 — mobileshop-vertical-remediation (Requirement 6.7).
    // Previously deferred arg routes, now registered with widened guards to
    // include mobileShop alongside computerShop.
    GoRoute(
      path: '/computer-shop/serial-history',
      builder: (BuildContext context, GoRouterState state) {
        final extra = state.extra as Map<String, dynamic>?;
        final serialNumber = extra?['serialNumber'] as String? ?? '';
        return VendorRoleGuard(
          requiredPermission: Permissions.viewInvoices,
          child: BusinessGuard(
            allowedTypes: const [
              BusinessType.computerShop,
              BusinessType.mobileShop,
              BusinessType.electronics,
            ],
            denialMessage:
                'Serial History is available for: Computer Shop, Mobile Phone Shop, Electronics.',
            child: CapabilityGate(
              capability: BusinessCapability.useIMEI,
              allowedTypes: const [
                BusinessType.computerShop,
                BusinessType.mobileShop,
                BusinessType.electronics,
              ],
              child: SerialHistoryScreen(serialNumber: serialNumber),
            ),
          ),
        );
      },
    ),
    GoRoute(
      path: '/computer-shop/job-card-detail',
      builder: (BuildContext context, GoRouterState state) {
        final extra = state.extra as Map<String, dynamic>?;
        final jobId = extra?['jobId'] as String? ?? '';
        return VendorRoleGuard(
          requiredPermission: Permissions.viewInvoices,
          child: BusinessGuard(
            allowedTypes: const [
              BusinessType.computerShop,
              BusinessType.mobileShop,
            ],
            denialMessage:
                'Job Card Detail is available for: Computer Shop, Mobile Phone Shop.',
            child: CapabilityGate(
              capability: BusinessCapability.useJobSheets,
              allowedTypes: const [
                BusinessType.computerShop,
                BusinessType.mobileShop,
              ],
              child: JobCardDetailScreen(jobId: jobId),
            ),
          ),
        );
      },
    ),
    GoRoute(
      path: '/computer-shop/create-job-card',
      builder: (BuildContext context, GoRouterState state) {
        final extra = state.extra as Map<String, dynamic>?;
        final serialNumber = extra?['serialNumber'] as String?;
        return VendorRoleGuard(
          requiredPermission: Permissions.viewInvoices,
          child: BusinessGuard(
            allowedTypes: const [
              BusinessType.computerShop,
              BusinessType.mobileShop,
            ],
            denialMessage:
                'Job Card creation is available for: Computer Shop, Mobile Phone Shop.',
            child: CapabilityGate(
              capability: BusinessCapability.useJobSheets,
              allowedTypes: const [
                BusinessType.computerShop,
                BusinessType.mobileShop,
              ],
              child: CreateJobCardScreen(serialNumber: serialNumber),
            ),
          ),
        );
      },
    ),
    // '/computer-shop/multi-unit': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.systemSettings,
    //       child: BusinessGuard(
    //         allowedTypes: const [BusinessType.computerShop],
    //         denialMessage: 'Only Computer Shop businesses can access Multi-Unit config.',
    //         child: const MultiUnitScreen(),
    //       ),
    //     ),
    // Multi-Unit: PARKED for electronics (Phase 0 decision — lacks useMultiUnit capability)
    GoRoute(
      path: '/computer-shop/multi-unit',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.computerShop],
          denialMessage:
              'Only Computer Shop businesses can access Multi-Unit config.',
          child: const MultiUnitScreen(),
        ),
      ),
    ),

    // Phase 2 — electronics-vertical-remediation (Requirement 2.9).
    // Exposes ImeiTrackingStatementScreen via a real route, backed by the
    // tenant-scoped getImeiTrackingStatement query (Phase 0, 2.3 confirmed).
    GoRoute(
      path: '/electronics/imei-tracking',
      builder: (BuildContext context, GoRouterState state) {
        final extra = state.extra as Map<String, dynamic>?;
        final productId = extra?['productId'] as String?;
        final productName = extra?['productName'] as String?;
        return VendorRoleGuard(
          requiredPermission: Permissions.viewInvoices,
          child: BusinessGuard(
            allowedTypes: const [
              BusinessType.electronics,
              BusinessType.mobileShop,
              BusinessType.computerShop,
            ],
            denialMessage:
                'IMEI/Serial Tracking is available for: Electronics, Mobile Phone Shop, Computer Shop.',
            child: CapabilityGate(
              capability: BusinessCapability.useIMEI,
              allowedTypes: const [
                BusinessType.electronics,
                BusinessType.mobileShop,
                BusinessType.computerShop,
              ],
              child: ImeiTrackingStatementScreen(
                productId: productId,
                productName: productName,
              ),
            ),
          ),
        );
      },
    ),

    // === JEWELLERY VERTICAL ROUTES ===
    // Phase 1 — jewellery-vertical-remediation (Requirements 4.1, 4.2, 4.3,
    // 4.4, 4.5). Each route wraps in VendorRoleGuard → BusinessGuard(jewellery)
    // → screen, matching the clinic/bookStore pattern. The reachable set equals
    // exactly The_Eight_Screens.
    //
    // Blast radius: NONE on other business types. Only BusinessType.jewellery
    // is granted access; no other vertical's routing is touched.
    GoRoute(
      path: '/jewellery-gold-rate',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.jewellery],
          denialMessage:
              'Only Jewellery businesses can access Gold Rate Management.',
          child: const GoldRateManagementScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/jewellery-gold-rate-alert',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.jewellery],
          denialMessage:
              'Only Jewellery businesses can access Gold Rate Alerts.',
          child: const GoldRateAlertScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/jewellery-making-charges',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.jewellery],
          denialMessage:
              'Only Jewellery businesses can access Making Charges Calculator.',
          child: const MakingChargesCalculatorScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/jewellery-hallmark',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.jewellery],
          denialMessage:
              'Only Jewellery businesses can access Hallmark Inventory.',
          child: const HallmarkInventoryScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/jewellery-old-gold-exchange',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.jewellery],
          denialMessage:
              'Only Jewellery businesses can access Old Gold Exchange.',
          child: const OldGoldExchangeScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/jewellery-custom-orders',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.jewellery],
          denialMessage: 'Only Jewellery businesses can access Custom Orders.',
          child: const CustomOrderManagementScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/jewellery-repair',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.jewellery],
          denialMessage:
              'Only Jewellery businesses can access Jewellery Repairs.',
          child: const JewelleryRepairScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/jewellery-gold-scheme',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewInvoices,
        child: BusinessGuard(
          allowedTypes: const [BusinessType.jewellery],
          denialMessage: 'Only Jewellery businesses can access Gold Schemes.',
          child: const GoldSchemeScreen(),
        ),
      ),
    ),

    // ---- Linking -------------------------------------------------------------
    // '/vendor_qr_code': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.manageStaff,
    //       child: const VendorQRCodeScreen(),
    //     ),
    GoRoute(
      path: '/vendor_qr_code',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.manageStaff,
        child: const VendorQRCodeScreen(),
      ),
    ),
    // '/customer_link_shop': (context) => const CustomerLinkShopScreen(),
    GoRoute(
      path: '/customer_link_shop',
      builder: (BuildContext context, GoRouterState state) =>
          const CustomerLinkShopScreen(),
    ),
    // '/owner_link': (context) => VendorRoleGuard(
    //       requiredPermission: Permissions.manageStaff,
    //       child: const OwnerLinkScreen(),
    //     ),
    GoRoute(
      path: '/owner_link',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.manageStaff,
        child: const OwnerLinkScreen(),
      ),
    ),
    // '/customer_link_accept': (context) => const CustomerLinkAcceptScreen(),
    GoRoute(
      path: '/customer_link_accept',
      builder: (BuildContext context, GoRouterState state) =>
          const CustomerLinkAcceptScreen(),
    ),
    // '/shop_selection': (context) => const ShopSelectionScreen(),
    GoRoute(
      path: '/shop_selection',
      builder: (BuildContext context, GoRouterState state) =>
          const ShopSelectionScreen(),
    ),
    // '/business_type_selection': (context) => const AuthGate(),
    GoRoute(
      path: '/business_type_selection',
      builder: (BuildContext context, GoRouterState state) => const AuthGate(),
    ),
    // '/my-linked-shops': (context) =>
    //     CustomerRoleGuard(child: const MyLinkedShopsScreen()),
    GoRoute(
      path: '/my-linked-shops',
      builder: (BuildContext context, GoRouterState state) =>
          CustomerRoleGuard(child: const MyLinkedShopsScreen()),
    ),

    // ---- Argument-bearing routes (Task 6.2) ----------------------------------
    // DEFERRED from Phase B. Builder bodies (guard wrapper TYPES,
    // `requiredPermission` constants, `BusinessGuard` allowedTypes/denialMessage,
    // the `is`-type-check, and the safe fallback screen/sentinel defaults) are
    // lifted CHARACTER-FOR-CHARACTER from `lib/app/routes.dart`. The ONLY
    // transform vs. the legacy builder is the arguments-read:
    // `ModalRoute.of(context)?.settings.arguments` -> `state.extra` (design.md
    // AD-3). `extra` is NEVER cast unconditionally — every `args is <Type>`
    // check is preserved exactly.

    // '/clinic/consultation': Map<String,String> else {}; ConsultationScreen
    // with patientId/patientName safe defaults; VendorRoleGuard(viewClients) +
    // BusinessGuard(clinic, NO denialMessage).
    GoRoute(
      path: '/clinic/consultation',
      builder: (BuildContext context, GoRouterState state) {
        final args = state.extra;
        final Map<String, String> safeArgs = args is Map<String, String>
            ? args
            : {};
        return VendorRoleGuard(
          requiredPermission: Permissions.viewClients,
          child: BusinessGuard(
            allowedTypes: const [BusinessType.clinic],
            child: ConsultationScreen(
              patientId: safeArgs['patientId'] ?? 'unknown',
              patientName: safeArgs['patientName'] ?? 'Unknown Patient',
            ),
          ),
        );
      },
    ),
    // '/clinic/history': Map<String,String> else {}; PatientHistoryScreen with
    // patientId safe default; VendorRoleGuard(viewClients) +
    // BusinessGuard(clinic, NO denialMessage).
    GoRoute(
      path: '/clinic/history',
      builder: (BuildContext context, GoRouterState state) {
        final args = state.extra;
        final Map<String, String> safeArgs = args is Map<String, String>
            ? args
            : {};
        return VendorRoleGuard(
          requiredPermission: Permissions.viewClients,
          child: BusinessGuard(
            allowedTypes: const [BusinessType.clinic],
            child: PatientHistoryScreen(
              patientId: safeArgs['patientId'] ?? 'unknown',
            ),
          ),
        );
      },
    ),
    // '/clinic/labs': Map<String,String> else {}; LabOrderScreen with
    // patientId/patientName safe defaults; VendorRoleGuard(viewClients) +
    // BusinessGuard(clinic, NO denialMessage).
    GoRoute(
      path: '/clinic/labs',
      builder: (BuildContext context, GoRouterState state) {
        final args = state.extra;
        final Map<String, String> safeArgs = args is Map<String, String>
            ? args
            : {};
        return VendorRoleGuard(
          requiredPermission: Permissions.viewClients,
          child: BusinessGuard(
            allowedTypes: const [BusinessType.clinic],
            child: LabOrderScreen(
              patientId: safeArgs['patientId'] ?? 'unknown',
              patientName: safeArgs['patientName'] ?? 'Unknown Patient',
            ),
          ),
        );
      },
    ),
    // '/clothing/variants': Map<String,String> else {}; VariantManagementScreen
    // with productId safe default; VendorRoleGuard(manageStaff) +
    // BusinessGuard(clothing, NO denialMessage).
    GoRoute(
      path: '/clothing/variants',
      builder: (BuildContext context, GoRouterState state) {
        final args = state.extra;
        final Map<String, String> safeArgs = args is Map<String, String>
            ? args
            : {};
        return VendorRoleGuard(
          requiredPermission: Permissions.viewProducts,
          child: BusinessGuard(
            allowedTypes: const [BusinessType.clothing],
            child: VariantManagementScreen(
              productId: safeArgs['productId'] ?? 'unknown',
            ),
          ),
        );
      },
    ),
    // '/clothing/tailoring': Map<String,String> with customerId + invoiceId;
    // BusinessGuard(clothing). Opens TailoringMeasurementsScreen with the
    // originating customerId/invoiceId from a bill/customer context. If either
    // is missing or empty, shows an error scaffold naming the missing context
    // and does NOT open the screen (Requirement 9.7).
    GoRoute(
      path: '/clothing/tailoring',
      builder: (BuildContext context, GoRouterState state) {
        final args = state.extra;
        final Map<String, String> safeArgs = args is Map<String, String>
            ? args
            : <String, String>{};
        final customerId = safeArgs['customerId'];
        final invoiceId = safeArgs['invoiceId'];

        // Validate: both customerId and invoiceId must be non-null and non-empty.
        final missingFields = <String>[];
        if (customerId == null || customerId.isEmpty) {
          missingFields.add('customerId');
        }
        if (invoiceId == null || invoiceId.isEmpty) {
          missingFields.add('invoiceId');
        }

        if (missingFields.isNotEmpty) {
          // Error: missing context — do not open the screen.
          return BusinessGuard(
            allowedTypes: const [BusinessType.clothing],
            child: Scaffold(
              appBar: AppBar(title: const Text('Take Measurements')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Cannot open Tailoring Measurements',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Missing required context: ${missingFields.join(', ')}. '
                        'Please navigate from a bill or customer to provide the '
                        'originating customer and invoice.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return BusinessGuard(
          allowedTypes: const [BusinessType.clothing],
          child: TailoringMeasurementsScreen(
            customerId: customerId,
            invoiceId: invoiceId,
          ),
        );
      },
    ),
    // '/advanced_bill_creation': optional Bill (edit vs create);
    // VendorRoleGuard(createInvoices).
    GoRoute(
      path: '/advanced_bill_creation',
      builder: (BuildContext context, GoRouterState state) {
        final args = state.extra;
        if (args is Bill) {
          return VendorRoleGuard(
            requiredPermission: Permissions.createInvoices,
            child: AdvancedBillCreationScreen(editingBill: args),
          );
        }
        return VendorRoleGuard(
          requiredPermission: Permissions.createInvoices,
          child: AdvancedBillCreationScreen(),
        );
      },
    ),
    // '/invoice_preview': EditableInvoice else error scaffold;
    // VendorRoleGuard(viewReports).
    GoRoute(
      path: '/invoice_preview',
      builder: (BuildContext context, GoRouterState state) {
        final args = state.extra;
        if (args is EditableInvoice) {
          return VendorRoleGuard(
            requiredPermission: Permissions.viewReports,
            child: InvoicePreviewScreen(invoice: args),
          );
        }
        return const VendorRoleGuard(
          requiredPermission: Permissions.viewReports,
          child: Scaffold(
            body: Center(
              child: Text(
                'No invoice data provided for preview',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        );
      },
    ),
    // '/hardware/operations': Map -> Map<String,dynamic> else {}; initialTab
    // (num?)->int default 0, depositStatus String?; VendorRoleGuard(viewReports)
    // + BusinessGuard(hardware, WITH denialMessage).
    GoRoute(
      path: '/hardware/operations',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.viewReports,
        child: Builder(
          builder: (context) {
            final args = state.extra;
            final map = args is Map
                ? Map<String, dynamic>.from(args)
                : const <String, dynamic>{};
            return BusinessGuard(
              allowedTypes: const [BusinessType.hardware],
              denialMessage:
                  'Projects, site indents, and material-on-deposit are available for Hardware business type only.',
              child: HardwareOperationsScreen(
                initialTab: (map['initialTab'] as num?)?.toInt() ?? 0,
                initialDepositStatus: map['depositStatus']?.toString(),
              ),
            );
          },
        ),
      ),
    ),
    // '/customer_portal': non-empty String customerId else error scaffold;
    // CustomerRoleGuard.
    GoRoute(
      path: '/customer_portal',
      builder: (BuildContext context, GoRouterState state) {
        final args = state.extra;
        if (args is String && args.isNotEmpty) {
          return CustomerRoleGuard(
            child: CustomerDashboardScreen(customerId: args),
          );
        }
        return const Scaffold(
          body: Center(
            child: Text(
              'Invalid customer portal access. Please login again.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        );
      },
    ),
    // '/customer_report': Map<String,String> with customerId else error
    // scaffold; VendorRoleGuard(viewReports).
    GoRoute(
      path: '/customer_report',
      builder: (BuildContext context, GoRouterState state) {
        final args = state.extra;
        final Map<String, String>? safeArgs = args is Map<String, String>
            ? args
            : null;
        if (safeArgs != null && safeArgs.containsKey('customerId')) {
          return VendorRoleGuard(
            requiredPermission: Permissions.viewReports,
            child: CustomerReportScreen(
              customerId: safeArgs['customerId']!,
              customerName: safeArgs['customerName'],
            ),
          );
        }
        return const VendorRoleGuard(
          requiredPermission: Permissions.viewReports,
          child: Scaffold(
            body: Center(
              child: Text(
                'No customer selected for report',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        );
      },
    ),
    // '/customer_app': Customer else LoginPage(); CustomerRoleGuard.
    GoRoute(
      path: '/customer_app',
      builder: (BuildContext context, GoRouterState state) {
        final args = state.extra;
        if (args is Customer) {
          return CustomerRoleGuard(
            child: CustomerDashboardScreen(customerId: args.id),
          );
        }
        return const LoginPage();
      },
    ),
    // '/notifications': non-empty String customerId else error scaffold;
    // VendorRoleGuard(viewClients).
    GoRoute(
      path: '/notifications',
      builder: (BuildContext context, GoRouterState state) {
        final args = state.extra;
        if (args is String && args.isNotEmpty) {
          return VendorRoleGuard(
            requiredPermission: Permissions.viewClients,
            child: CustomerNotificationsScreen(customerId: args),
          );
        }
        return const VendorRoleGuard(
          requiredPermission: Permissions.viewClients,
          child: Scaffold(
            body: Center(
              child: Text(
                'No customer selected for notifications',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        );
      },
    ),
    // '/cloud_sync_settings': String ownerId else SettingsScreen();
    // VendorRoleGuard(systemSettings).
    GoRoute(
      path: '/cloud_sync_settings',
      builder: (BuildContext context, GoRouterState state) {
        final args = state.extra;
        if (args is String) {
          return VendorRoleGuard(
            requiredPermission: Permissions.systemSettings,
            child: CloudSyncSettingsScreen(ownerId: args),
          );
        }
        return VendorRoleGuard(
          requiredPermission: Permissions.systemSettings,
          child: const SettingsScreen(),
        );
      },
    ),
    // '/editable_invoice': Map<String,String> else null; EditableInvoiceScreen
    // with sentinel '' defaults; VendorRoleGuard(systemSettings).
    GoRoute(
      path: '/editable_invoice',
      builder: (BuildContext context, GoRouterState state) {
        final args = state.extra;
        final Map<String, String>? safeArgs = args is Map<String, String>
            ? args
            : null;
        return VendorRoleGuard(
          requiredPermission: Permissions.systemSettings,
          child: EditableInvoiceScreen(
            ownerName: safeArgs?['ownerName'] ?? '',
            shopName: safeArgs?['shopName'] ?? '',
            ownerPhone: safeArgs?['ownerPhone'] ?? '',
            ownerAddress: safeArgs?['ownerAddress'] ?? '',
          ),
        );
      },
    ),

    // ---- Purchase / Scan Bill (Task 6.2) -------------------------------------
    // DEFERRED from Task 4.5. The legacy builders read
    // `ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?`;
    // per design.md AD-3 ("type-check `extra` with `is` before use; never cast
    // unconditionally") the migration reads `state.extra` defensively (mirroring
    // the `/hardware/operations` pattern) while preserving the SAME
    // `verticalType` default ('grocery') and `VendorRoleGuard` permissions.
    // '/purchase/scan-bill': Map (verticalType default 'grocery');
    // VendorRoleGuard(createInvoices); ScanBillImagePickerScreen.
    // Phase 2 (Task 5.2): Purchase/scan-bill is retail-only; outside DC scope.
    // BusinessGuard denies decorationCatering access.
    GoRoute(
      path: '/purchase/scan-bill',
      builder: (BuildContext context, GoRouterState state) {
        final args = state.extra is Map
            ? Map<String, dynamic>.from(state.extra as Map)
            : const <String, dynamic>{};
        final verticalType = args['verticalType'] as String? ?? 'grocery';
        return VendorRoleGuard(
          requiredPermission: Permissions.createInvoices,
          child: BusinessGuard(
            allowedTypes: const [
              BusinessType.grocery,
              BusinessType.pharmacy,
              BusinessType.restaurant,
              BusinessType.clothing,
              BusinessType.electronics,
              BusinessType.mobileShop,
              BusinessType.computerShop,
              BusinessType.hardware,
              BusinessType.service,
              BusinessType.wholesale,
              BusinessType.petrolPump,
              BusinessType.vegetablesBroker,
              BusinessType.clinic,
              BusinessType.bookStore,
              BusinessType.jewellery,
              BusinessType.autoParts,
              BusinessType.schoolErp,
              BusinessType.other,
            ],
            denialMessage:
                'Purchase scanning is not available for Decoration & Catering businesses.',
            child: ScanBillImagePickerScreen(verticalType: verticalType),
          ),
        );
      },
    ),
    // '/purchase/scan-bill/review': Map (verticalType default 'grocery');
    // VendorRoleGuard(createInvoices); ScanBillReviewScreen.
    // Phase 2 (Task 5.2): Purchase bill review is retail-only; outside DC scope.
    // BusinessGuard denies decorationCatering access.
    GoRoute(
      path: '/purchase/scan-bill/review',
      builder: (BuildContext context, GoRouterState state) {
        final args = state.extra is Map
            ? Map<String, dynamic>.from(state.extra as Map)
            : const <String, dynamic>{};
        final verticalType = args['verticalType'] as String? ?? 'grocery';
        return VendorRoleGuard(
          requiredPermission: Permissions.createInvoices,
          child: BusinessGuard(
            allowedTypes: const [
              BusinessType.grocery,
              BusinessType.pharmacy,
              BusinessType.restaurant,
              BusinessType.clothing,
              BusinessType.electronics,
              BusinessType.mobileShop,
              BusinessType.computerShop,
              BusinessType.hardware,
              BusinessType.service,
              BusinessType.wholesale,
              BusinessType.petrolPump,
              BusinessType.vegetablesBroker,
              BusinessType.clinic,
              BusinessType.bookStore,
              BusinessType.jewellery,
              BusinessType.autoParts,
              BusinessType.schoolErp,
              BusinessType.other,
            ],
            denialMessage:
                'Purchase scanning is not available for Decoration & Catering businesses.',
            child: ScanBillReviewScreen(verticalType: verticalType),
          ),
        );
      },
    ),
    // '/purchase/entries': Map (verticalType default 'grocery');
    // VendorRoleGuard(viewReports); PurchaseEntriesListScreen.
    // Phase 2 (Task 5.2): Purchase entries are retail-only; outside DC scope.
    // BusinessGuard denies decorationCatering access.
    GoRoute(
      path: '/purchase/entries',
      builder: (BuildContext context, GoRouterState state) {
        final args = state.extra is Map
            ? Map<String, dynamic>.from(state.extra as Map)
            : const <String, dynamic>{};
        final verticalType = args['verticalType'] as String? ?? 'grocery';
        return VendorRoleGuard(
          requiredPermission: Permissions.viewReports,
          child: BusinessGuard(
            allowedTypes: const [
              BusinessType.grocery,
              BusinessType.pharmacy,
              BusinessType.restaurant,
              BusinessType.clothing,
              BusinessType.electronics,
              BusinessType.mobileShop,
              BusinessType.computerShop,
              BusinessType.hardware,
              BusinessType.service,
              BusinessType.wholesale,
              BusinessType.petrolPump,
              BusinessType.vegetablesBroker,
              BusinessType.clinic,
              BusinessType.bookStore,
              BusinessType.jewellery,
              BusinessType.autoParts,
              BusinessType.schoolErp,
              BusinessType.other,
            ],
            denialMessage:
                'Purchase entries are not available for Decoration & Catering businesses.',
            child: PurchaseEntriesListScreen(verticalType: verticalType),
          ),
        );
      },
    ),

    // ---- New routes absent from the legacy table (Task 7.1 — design AD-8) ----
    // These paths are pushed imperatively (trial/subscription widgets and the
    // super-admin dashboard) but were NEVER registered in buildAppRoutes(), so
    // they failed at runtime even under the legacy table. They are registered
    // here as first-class top-level GoRoutes mapping to the real target screens
    // discovered in the codebase, each wrapped in the appropriate guard.
    //
    // GUARD RATIONALE (super-admin): `admin_dashboard_screen.dart` (the only
    // call site) navigates to these via plain `Navigator.pushNamed` with NO
    // in-widget guard, and there is no dedicated super-admin guard widget in the
    // codebase. Per Task 7.1 these are wrapped in `VendorRoleGuard` with
    // `Permissions.systemSettings` — the same permission the legacy table uses
    // for every other admin / system surface (`/business_settings`,
    // `/app_management`, `/dev_health`, `/settings/*`, etc.). This is the most
    // appropriate existing permission for system-administration screens.

    // '/super-admin/tenants' -> TenantManagementScreen.
    GoRoute(
      path: '/super-admin/tenants',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const TenantManagementScreen(),
      ),
    ),
    // '/super-admin/licenses' -> LicenseListScreen (license management).
    GoRoute(
      path: '/super-admin/licenses',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const LicenseListScreen(),
      ),
    ),
    // '/super-admin/audit' -> AuditViewerScreen (audit log viewer).
    GoRoute(
      path: '/super-admin/audit',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const AuditViewerScreen(),
      ),
    ),
    // '/super-admin/usage' -> UsageDashboardScreen.
    GoRoute(
      path: '/super-admin/usage',
      builder: (BuildContext context, GoRouterState state) => VendorRoleGuard(
        requiredPermission: Permissions.systemSettings,
        child: const UsageDashboardScreen(),
      ),
    ),

    // ⚠️ FLAGGED (Req 9.3 / design AD-8): '/upgrade' has NO target screen.
    // The trial widgets (`trial_banner_widget.dart`,
    // `trial_expired_gate_widget.dart`) push '/upgrade' expecting an app
    // plan-upgrade screen, but NO such screen exists in the codebase. The only
    // subscription-related screens are `ManageSubscriptionsScreen` (manages the
    // vendor's OWN customer subscriptions — a different domain) and the
    // `TrialUpgradeDialog` (a dialog, not a routable screen). Rather than crash
    // or silently mis-map to an unrelated screen, '/upgrade' resolves to the
    // theme-aware not-found placeholder below (mirroring the AppRouter
    // `errorBuilder` -> `_RouteNotFoundScreen`). Replace this with the real
    // upgrade screen when one is built.
    GoRoute(
      path: '/upgrade',
      builder: (BuildContext context, GoRouterState state) =>
          const _UpgradeRouteNotFoundScreen(),
    ),
  ];
}

/// ⚠️ FLAGGED placeholder for the unimplemented `/upgrade` route (Task 7.1 /
/// Req 9.3 / design AD-8). Mirrors the AppRouter `errorBuilder`
/// `_RouteNotFoundScreen` (theme-aware "Feature Not Found") so navigating to
/// `/upgrade` degrades gracefully instead of crashing. There is currently no
/// app plan-upgrade screen in the codebase; swap this for the real screen when
/// it exists.
class _UpgradeRouteNotFoundScreen extends StatelessWidget {
  const _UpgradeRouteNotFoundScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor, width: 1),
              ),
              child: Icon(
                Icons.help_outline,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unknown Screen',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Text(
                'Feature Not Found',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.hintColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
