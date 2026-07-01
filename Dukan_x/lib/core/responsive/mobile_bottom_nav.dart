// ============================================================================
// MOBILE BOTTOM NAVIGATION BAR
// ============================================================================
// Material 3 NavigationBar for mobile/tablet devices.
// Shows 5 primary sections with animated transitions.
// Integrates with NavigationController and AppScreen enum.
// ============================================================================

import 'package:flutter/material.dart';
import '../navigation/app_screens.dart';
import '../theme/futuristic_colors.dart';

// ============================================================================
// PURE INDEX <-> SCREEN MAPPING (testable without a widget tree)
// ============================================================================
// The bottom navigation exposes a fixed set of primary destinations. The
// mapping between [AppScreen] and the selected index is kept as pure,
// side-effect-free top-level functions so the active-destination behavior
// (design.md Property 7) can be unit/property tested without building a widget.
// The [MobileBottomNav] widget simply delegates to these functions.
// ============================================================================

/// Number of primary destinations shown in the bottom navigation bar.
const int kBottomNavPrimaryCount = 5;

/// The canonical primary [AppScreen] for each bottom-nav [index].
///
/// Pure mapping from a bottom-nav index (`0..kBottomNavPrimaryCount-1`) to the
/// primary screen that destination navigates to. Out-of-range indices fall back
/// to the dashboard rather than throwing, so the widget never crashes.
AppScreen screenForIndex(int index) {
  switch (index) {
    case 0:
      return AppScreen.executiveDashboard;
    case 1:
      return AppScreen.newSale;
    case 2:
      return AppScreen.stockSummary;
    case 3:
      return AppScreen.customers;
    case 4:
      return AppScreen.settings;
    default:
      return AppScreen.executiveDashboard;
  }
}

/// The bottom-nav index that should be highlighted for the given [screen].
///
/// Returns the index (`0..kBottomNavPrimaryCount-1`) of the destination whose
/// category contains [screen], or `null` when [screen] is not part of any
/// bottom-nav category (i.e. it is reachable only via the drawer). Returning
/// `null` lets callers decide on a graceful default selection instead of
/// forcing a highlight, and keeps the mapping total and exception-free.
///
/// Round-trip guarantee: for every `i` in `0..kBottomNavPrimaryCount-1`,
/// `selectedIndexForScreen(screenForIndex(i)) == i`.
int? selectedIndexForScreen(AppScreen screen) {
  switch (screen) {
    case AppScreen.executiveDashboard:
    case AppScreen.dailySnapshot:
    case AppScreen.liveHealth:
    case AppScreen.alerts:
    case AppScreen.clinicDashboard:
      return 0;

    case AppScreen.newSale:
    case AppScreen.salesRegister:
    case AppScreen.revenueOverview:
    case AppScreen.receiptEntry:
    case AppScreen.proformaBids:
    case AppScreen.bookingOrders:
    case AppScreen.dispatchNotes:
    case AppScreen.returnInwards:
    case AppScreen.creditNotes:
    // Hardware vertical (bugfix.md 2.19): surface hardware operations and
    // delivery challans in the mobile bottom-nav handled set so mobile users
    // can reach them. Grouped with the sales/dispatch destination. Additive —
    // no existing mapping changes.
    case AppScreen.hardwareOperations:
    case AppScreen.deliveryChallans:
      return 1;

    case AppScreen.stockSummary:
    case AppScreen.itemStock:
    case AppScreen.batchTracking:
    case AppScreen.lowStock:
    case AppScreen.stockValuation:
    case AppScreen.damageLogs:
    case AppScreen.categories:
    case AppScreen.catalogue:
      return 2;

    case AppScreen.customers:
    case AppScreen.suppliers:
    case AppScreen.partyLedger:
    case AppScreen.ledgerHistory:
    case AppScreen.ledgerAbstract:
    case AppScreen.outstanding:
    case AppScreen.addCustomer:
      return 3;

    case AppScreen.settings:
    case AppScreen.deviceSettings:
    case AppScreen.printSettings:
    case AppScreen.docTemplates:
    case AppScreen.backup:
    case AppScreen.syncStatus:
    case AppScreen.appManagement:
      return 4;

    default:
      return null; // Not a bottom-nav destination (drawer-only screen).
  }
}

/// Bottom navigation bar for mobile and tablet devices.
///
/// Displays the 5 most-used sections for quick access.
/// The full menu is accessible via the hamburger drawer.
class MobileBottomNav extends StatelessWidget {
  final AppScreen currentScreen;
  final void Function(AppScreen screen) onScreenSelected;

  const MobileBottomNav({
    super.key,
    required this.currentScreen,
    required this.onScreenSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return NavigationBar(
      // Highlight the destination matching the current screen. When the current
      // screen is not a bottom-nav destination (drawer-only), fall back to the
      // dashboard (index 0) so the bar always has a valid, non-throwing
      // selection (Req 9.7, 5.4).
      selectedIndex: selectedIndexForScreen(currentScreen) ?? 0,
      onDestinationSelected: (index) {
        onScreenSelected(screenForIndex(index));
      },
      backgroundColor: isDark
          ? FuturisticColors.surface
          : theme.colorScheme.surface,
      indicatorColor: theme.colorScheme.primary.withOpacity(0.15),
      animationDuration: const Duration(milliseconds: 400),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      height: 64,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.point_of_sale_outlined),
          selectedIcon: Icon(Icons.point_of_sale_rounded),
          label: 'Billing',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2_rounded),
          label: 'Inventory',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people_rounded),
          label: 'Parties',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: 'Settings',
        ),
      ],
    );
  }
}
