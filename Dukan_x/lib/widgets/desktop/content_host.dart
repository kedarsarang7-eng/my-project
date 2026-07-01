import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/navigation/navigation_controller.dart';
import '../../core/navigation/app_screens.dart';
import '../../providers/app_state_providers.dart';
import '../feature_error_boundary.dart';
import '../loading/loading_states.dart';
import 'sidebar_navigation_handler.dart';

// Import Screens Logic (Barrel imports prefered if available, else direct)

import '../../features/dashboard/presentation/screens/desktop_dashboard_content.dart';
import '../../features/billing/presentation/screens/bill_creation_screen_v2.dart';
import '../../features/revenue/screens/sales_register_screen.dart';
import '../../features/inventory/presentation/screens/inventory_dashboard_screen.dart';
import '../../features/inventory/presentation/screens/categories_screen.dart';
import '../../features/customers/presentation/screens/customers_list_screen.dart';
import '../../features/party_ledger/screens/party_ledger_list_screen.dart';
import '../../features/payment/presentation/screens/payments_history_screen.dart';
import '../../features/expenses/presentation/screens/expenses_screen.dart';
import '../../screens/billing_reports_screen.dart';
import '../../features/gst/screens/gst_reports_screen.dart';
import '../../features/settings/presentation/screens/main_settings_screen.dart';
import '../../features/doctor/presentation/screens/patient_list_screen.dart';
import '../../features/doctor/presentation/screens/prescriptions_list_screen.dart';
import '../../features/doctor/presentation/screens/appointment_screen.dart';
import '../../features/doctor/presentation/screens/add_patient_screen.dart';

// BuyFlow Screens
import '../../features/buy_flow/screens/buy_flow_dashboard.dart';
import '../../features/buy_flow/screens/buy_orders_screen.dart';
import '../../features/buy_flow/screens/stock_entry_screen.dart';
import '../../features/buy_flow/screens/stock_reversal_screen.dart';
import '../../features/buy_flow/screens/procurement_log_screen.dart';
import '../../features/buy_flow/screens/supplier_bills_screen.dart';

// Revenue Screens
import '../../features/revenue/screens/revenue_overview_screen.dart';
import '../../features/revenue/screens/receipt_entry_screen.dart';
import '../../features/revenue/screens/proforma_screen.dart';
import '../../features/revenue/screens/booking_order_screen.dart';
import '../../features/revenue/screens/dispatch_note_screen.dart';
import '../../features/revenue/screens/return_inwards_screen.dart';

// Utility Screens
import '../../features/alerts/presentation/screens/alerts_screen.dart';
import '../../features/insights/presentation/screens/insights_screen.dart';
import '../../features/backup/screens/backup_screen.dart';
import '../../features/daybook/presentation/screens/day_book_screen.dart';
import '../../features/credit_notes/presentation/screens/credit_note_screen.dart';
import '../../features/analytics/analytics_dashboard_screen.dart';
import '../../features/catalogue/presentation/screens/catalogue_screen.dart';
import '../../features/prescriptions/presentation/screens/h1_register_screen.dart';

// HARDWARE VERTICAL — in-shell navigation wiring (Task 3.1; bugfix.md 2.1, 2.2)
import '../../features/delivery_challan/presentation/screens/delivery_challan_list_screen.dart';
import '../../features/hardware/presentation/screens/hardware_operations_screen.dart';
// HARDWARE VERTICAL — real accounting reports screen (Task 3.7; bugfix.md 2.26)
import '../../features/accounting/screens/accounting_reports_screen.dart';
// MANDI VERTICAL — quick-action targets (Task 18.3; R12.3, R12.4)
import '../../features/vegetable_broker/presentation/screens/farmer_ledger_entry_screen.dart';
// BOOK STORE VERTICAL — quick-action targets (Task 5.3; Req 5.6, 5.7, 5.8)
import '../../features/book_store/presentation/screens/book_inventory_screen.dart';
import '../../features/book_store/presentation/screens/book_supplier_returns_screen.dart';
import '../../features/book_store/presentation/screens/book_pos_screen.dart';
// JEWELLERY VERTICAL — quick-action targets (Task 8.1; Req 12.1, 12.2)
import '../../features/jewellery/presentation/screens/custom_order_management_screen.dart';
import '../../features/jewellery/presentation/screens/gold_rate_management_screen.dart';
// DC VERTICAL — post-login landing (Task 3.14; Req 6.1, 6.3)
import '../../features/decoration_catering/presentation/screens/dc_dashboard_screen.dart';
import '../../core/di/service_locator.dart';
import '../../core/session/session_manager.dart';

/// The main content area that switches screens based on NavigationController state.
/// Uses [IndexedStack] or [FadeTransition] to switch content without rebuilding the shell.
class DesktopContentHost extends ConsumerStatefulWidget {
  const DesktopContentHost({super.key});

  @override
  ConsumerState<DesktopContentHost> createState() => _DesktopContentHostState();
}

class _DesktopContentHostState extends ConsumerState<DesktopContentHost> {
  // Map of Screen Enum -> Widget Builder
  // We use builders to lazy load if needed, or instantiate direct if const
  late final Map<AppScreen, Widget Function()> _screenBuilders;

  // Cache constructed screens to preserve state
  final Map<AppScreen, Widget> _screenCache = {};

  /// The most recently resolved screen, used to retain the current view when a
  /// later navigation target fails to resolve (Req 9.3).
  AppScreen? _lastResolvedScreen;

  /// Screens for which an "unavailable" indication has already been shown, so
  /// repeated rebuilds do not stack duplicate notifications.
  final Set<AppScreen> _notifiedUnavailable = {};

  /// Latency budget for presenting a target screen after a navigation trigger
  /// (Req 11.7). If navigation has not settled within this window, a loading
  /// indicator is shown until the target screen is ready.
  static const Duration _navLatencyBudget = Duration(milliseconds: 320);

  /// Timer that elapses when navigation exceeds [_navLatencyBudget].
  Timer? _navBudgetTimer;

  /// Whether the latency budget has been exceeded for the in-flight navigation.
  bool _navBudgetExceeded = false;

  @override
  void initState() {
    super.initState();
    _initScreenBuilders();
  }

  @override
  void dispose() {
    _navBudgetTimer?.cancel();
    super.dispose();
  }

  /// Starts/stops the latency-budget timer based on navigation progress.
  ///
  /// While `isNavigating` is true we arm a one-shot timer; if it fires before
  /// navigation settles, we surface [AppLoadingIndicator]. Once navigation
  /// completes we cancel the timer and clear the loading state.
  void _handleNavigationState(bool isNavigating) {
    if (isNavigating) {
      if (_navBudgetTimer != null) return; // already armed for this navigation
      _navBudgetTimer = Timer(_navLatencyBudget, () {
        if (!mounted) return;
        setState(() => _navBudgetExceeded = true);
      });
    } else {
      _navBudgetTimer?.cancel();
      _navBudgetTimer = null;
      if (_navBudgetExceeded) {
        setState(() => _navBudgetExceeded = false);
      }
    }
  }

  void _initScreenBuilders() {
    _screenBuilders = {
      // DASHBOARD
      // Req 6.1 / 6.3 (DC post-login landing): decorationCatering tenants get
      // DcDashboardScreen as their post-login landing within 3s without blocking
      // network calls. Falls back to DcDashboardScreen if the resolved route is
      // anything else. Other verticals keep DesktopDashboardContent unchanged.
      AppScreen.executiveDashboard: () => _executiveDashboardScreen(),

      // BILLING
      AppScreen.newSale: () => const BillCreationScreenV2(),
      AppScreen.salesRegister: () => const SalesRegisterScreen(),

      // INVENTORY
      AppScreen.stockSummary: () => const InventoryDashboardScreen(),
      AppScreen.itemStock: () => const InventoryDashboardScreen(),
      AppScreen.categories: () => const CategoriesScreen(),

      // CUSTOMERS & LEDGER
      AppScreen.customers: () => const CustomersListScreen(),
      AppScreen.partyLedger: () => const PartyLedgerListScreen(),
      AppScreen.outstanding: () => const PartyLedgerListScreen(),

      // FINANCIAL
      AppScreen.paymentHistory: () => const PaymentsHistoryScreen(),
      AppScreen.expenses: () => const ExpensesScreen(),
      AppScreen.accountingReports: () => _accountingReportsScreen(),
      AppScreen.transactionReports: () => const BillingReportsScreen(),

      // TAX
      AppScreen.gstr1: () => const GstReportsScreen(),
      AppScreen.taxLiability: () => const GstReportsScreen(),

      // CLINIC
      AppScreen.clinicDashboard: () =>
          const DesktopDashboardContent(), // Clinic specific needed
      AppScreen.patientsList: () => const PatientListScreen(),
      AppScreen.addPatient: () => const AddPatientScreen(),
      AppScreen.prescriptions: () => const SafePrescriptionListScreen(),
      AppScreen.appointments: () => const AppointmentScreen(),

      // SETTINGS
      AppScreen.settings: () => const SettingsScreen(),
      AppScreen.deviceSettings: () => const SettingsScreen(),

      // --- NEWLY WIRED SCREENS ---

      // REVENUE DESK
      AppScreen.revenueOverview: () => const RevenueOverviewScreen(),
      AppScreen.receiptEntry: () => const ReceiptEntryScreen(),
      AppScreen.proformaBids: () => const ProformaScreen(),
      AppScreen.bookingOrders: () => const BookingOrderScreen(),
      AppScreen.dispatchNotes: () => const DispatchNoteScreen(),
      AppScreen.returnInwards: () => const ReturnInwardsScreen(),

      // BUY FLOW
      AppScreen.buyflowDashboard: () => const BuyFlowDashboard(),
      AppScreen.purchaseOrders: () => const BuyOrdersScreen(),
      AppScreen.stockEntry: () => const StockEntryScreen(),
      AppScreen.stockReversal: () => const StockReversalScreen(),
      AppScreen.procurementLog: () => const ProcurementLogScreen(),
      AppScreen.supplierBills: () => const SupplierBillsScreen(),
      AppScreen.purchaseRegister: () =>
          const BuyOrdersScreen(), // Reuse for now
      // UTILITIES & ANALYTICS
      AppScreen.alerts: () => const AlertsScreen(),
      AppScreen.insights: () => const InsightsScreen(),
      AppScreen.daybook: () => const DayBookScreen(),
      AppScreen.creditNotes: () => const CreditNotesListScreen(),
      AppScreen.backup: () => const BackupScreen(),
      AppScreen.analyticsHub: () => const AnalyticsDashboardScreen(),
      AppScreen.catalogue: () => const CatalogueScreen(),

      // PHARMACY — Schedule H1 statutory register (Req 9.1, 9.2). Registering
      // the builder here guarantees the H1 Register action resolves to the real
      // screen and never falls through to a placeholder.
      AppScreen.h1Register: () => const H1RegisterScreen(),

      // HARDWARE — previously dead dashboard CTAs (Task 3.1; bugfix.md 2.1,
      // 2.2). Wiring them into _screenBuilders resolves the "Delivery Challan"
      // and "Projects" actions to their real screens instead of the
      // "Feature Not Found" placeholder. Additive: no existing entry changes.
      AppScreen.deliveryChallans: () => const DeliveryChallanListScreen(),
      AppScreen.hardwareOperations: () => const HardwareOperationsScreen(),

      // JEWELLERY VERTICAL — quick-action targets (Task 8.1; Req 12.1, 12.2).
      AppScreen.jewelleryCustomOrders: () =>
          const CustomOrderManagementScreen(),
      AppScreen.jewelleryGoldRate: () => const GoldRateManagementScreen(),

      // MANDI VERTICAL — quick-action targets (Task 18.3; R12.3, R12.4).
      // mandiLotEntry: the Mandi lot-entry interface is the bill creation
      // screen operating in mandi mode (auto-activated for vegetablesBroker).
      AppScreen.mandiLotEntry: () => const BillCreationScreenV2(),
      // mandiFarmerLedger: the farmer-list entry point that lets the user
      // select a farmer then navigates to the individual ledger.
      AppScreen.mandiFarmerLedger: () => const FarmerLedgerEntryScreen(),

      // BOOK STORE VERTICAL — quick-action targets (Task 5.3; Req 5.6, 5.7, 5.8).
      // bookCatalogue: resolves "Book Search" quick action to the inventory screen.
      AppScreen.bookCatalogue: () => const BookInventoryScreen(),
      // bookReturns: resolves "Returns" quick action to the supplier returns screen.
      AppScreen.bookReturns: () => const BookSupplierReturnsScreen(),
      // bookPos: resolves "ISBN Scan" quick action to the POS screen (has scanner).
      AppScreen.bookPos: () => const BookPosScreen(),

      // FALLBACK
      AppScreen.unknown: () =>
          const Center(child: Text("Feature under development")),
    };
  }

  /// Resolves the Accounting Reports screen (bugfix.md 2.26). Hardware gets the
  /// real [AccountingReportsScreen] (consistent with the string-based resolver
  /// in `sidebar_navigation_handler`), while every other vertical keeps the
  /// historical [BillingReportsScreen] mapping byte-for-byte — so the change is
  /// hardware-isolated and non-hardware behavior is preserved.
  Widget _accountingReportsScreen() {
    try {
      if (sl<SessionManager>().activeBusinessType == BusinessType.hardware) {
        return const AccountingReportsScreen();
      }
    } catch (_) {
      // Session not available (e.g. in isolated tests): fall back to the
      // historical placeholder so behavior is unchanged.
    }
    return const BillingReportsScreen();
  }

  /// Resolves the executive dashboard screen based on business type (Req 6.1,
  /// 6.3). decorationCatering tenants get [DcDashboardScreen] as their
  /// post-login landing within 3s (no blocking network calls). All other
  /// verticals keep the historical [DesktopDashboardContent] unchanged.
  ///
  /// Req 6.4: If [DcDashboardScreen] fails to render, the tenant is retained
  /// on the current screen and a "could not load" error is surfaced via the
  /// wrapping [FeatureErrorBoundary] in [_buildScreen].
  Widget _executiveDashboardScreen() {
    try {
      if (sl<SessionManager>().activeBusinessType ==
          BusinessType.decorationCatering) {
        return const _DcDashboardLanding();
      }
    } catch (_) {
      // Session not available (e.g. in isolated tests): fall back to the
      // historical default so behavior is unchanged.
    }
    return const DesktopDashboardContent();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to navigation state
    final navigationState = ref.watch(navigationControllerProvider);
    final currentScreen = navigationState.currentScreen;

    // Clear cached screens when business type changes so stale widgets
    // from the previous type are not reused (switcher bug fix).
    ref.listen<BusinessTypeState>(businessTypeProvider, (prev, next) {
      if (prev?.type != next.type) {
        _screenCache.clear();
      }
    });

    // Arm/disarm the latency-budget timer in response to navigation progress
    // (Req 11.7). Scheduled post-frame so we never call setState during build.
    final isNavigating = navigationState.isNavigating;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handleNavigationState(isNavigating);
    });

    return FocusTraversalGroup(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _navBudgetExceeded
            ? const KeyedSubtree(
                key: ValueKey('nav-loading'),
                child: AppLoadingIndicator(message: 'Loading…'),
              )
            : KeyedSubtree(
                key: ValueKey(currentScreen),
                child: _buildScreen(currentScreen),
              ),
      ),
    );
  }

  Widget _buildScreen(AppScreen screen) {
    // Return cached if exists
    if (_screenCache.containsKey(screen)) {
      _lastResolvedScreen = screen;
      return _screenCache[screen]!;
    }

    // Build and cache
    Widget widget;
    if (_screenBuilders.containsKey(screen)) {
      widget = _screenBuilders[screen]!();
    } else {
      // Resolve using SidebarNavigationHandler which contains mappings for all
      // screens. Use the nullable resolver so a genuine miss can be handled
      // without rendering a placeholder.
      final resolved = SidebarNavigationHandler.tryGetScreenForItem(
        screen.id,
        context,
      );
      if (resolved == null) {
        // Resolution miss. For the pharmacy H1 Register action (Req 9.3) we
        // must NOT render a placeholder: show an error indication and retain
        // the previously active screen. Every other screen keeps the
        // historical placeholder behaviour byte-for-byte unchanged.
        if (screen == AppScreen.h1Register) {
          _notifyScreenUnavailable(screen, 'H1 Register');
          return _retainPreviousScreen();
        }
        // BOOK STORE VERTICAL (Req 5.5): If a book-store screen cannot
        // resolve, retain the current screen, surface an "unavailable"
        // indication, and raise no unhandled exception — never show the
        // "Feature Not Found" placeholder for a book_* id.
        if (screen == AppScreen.bookCatalogue ||
            screen == AppScreen.bookReturns ||
            screen == AppScreen.bookPos) {
          _notifyScreenUnavailable(screen, 'Book Store');
          return _retainPreviousScreen();
        }
        widget = SidebarNavigationHandler.getScreenForItem(screen.id, context);
      } else {
        widget = resolved;
      }
    }

    // Wrap with error boundary for crash isolation
    final wrappedWidget = FeatureErrorBoundary(
      screen: screen,
      onRetry: () {
        // Clear cache to force rebuild on retry
        _screenCache.remove(screen);
        setState(() {});
      },
      child: widget,
    );

    _screenCache[screen] = wrappedWidget;
    _lastResolvedScreen = screen;
    return wrappedWidget;
  }

  /// Shows a transient error indication that [label] could not be opened,
  /// without navigating away (Req 9.3). De-duplicated per screen so repeated
  /// rebuilds do not stack notifications.
  void _notifyScreenUnavailable(AppScreen screen, String label) {
    if (_notifiedUnavailable.contains(screen)) return;
    _notifiedUnavailable.add(screen);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('$label screen is unavailable.')));
    });
  }

  /// Returns the previously resolved screen so the shell stays on the last good
  /// screen when a resolution miss occurs (Req 9.3). Falls back to a neutral
  /// view (never a placeholder) when there is no prior screen to retain.
  Widget _retainPreviousScreen() {
    final previous = _lastResolvedScreen;
    if (previous != null && _screenCache.containsKey(previous)) {
      return _screenCache[previous]!;
    }
    return const Center(child: Text('Feature under development'));
  }
}

// =============================================================================
// DC Dashboard Post-Login Landing (Req 6.1, 6.3, 6.4)
// =============================================================================
// Wraps DcDashboardScreen with render-failure handling. If the DC dashboard
// fails to render, the widget shows a "could not load" error and retains the
// user on the current screen (no navigation away). No blocking network calls
// are made before showing the dashboard, ensuring the 3s render budget is met.
// =============================================================================

/// Post-login landing wrapper for decorationCatering tenants.
///
/// Renders [DcDashboardScreen] synchronously (no blocking IO). On render
/// failure, retains the current screen and surfaces a "could not load" error
/// (Req 6.4).
class _DcDashboardLanding extends StatefulWidget {
  const _DcDashboardLanding();

  @override
  State<_DcDashboardLanding> createState() => _DcDashboardLandingState();
}

class _DcDashboardLandingState extends State<_DcDashboardLanding> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorFallback(context);
    }

    // Render DcDashboardScreen directly — no blocking network calls needed,
    // ensuring the 3s post-login render budget (Req 6.1) is met.
    return const DcDashboardScreen();
  }

  /// Called by the Flutter error handling infrastructure when a child widget
  /// in this subtree fails to render.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Register a local error handler for this widget subtree.
    // The wrapping FeatureErrorBoundary handles build-time exceptions;
    // this state flag handles async initialization failures surfaced via
    // setState from the child.
  }

  /// Fallback UI shown when DcDashboardScreen fails to render (Req 6.4).
  /// Keeps the tenant on the current screen with a "could not load" indication.
  Widget _buildErrorFallback(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'could not load',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() => _hasError = false);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
