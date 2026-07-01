// ============================================================================
// ADAPTIVE SHELL — Cross-Platform Layout Wrapper
// ============================================================================
// This is the single entry point for the main app layout. It automatically
// selects the correct shell based on screen size:
//
//   Desktop (≥ 1100px): Existing DesktopRootShell (sidebar + topbar + content)
//   Tablet  (600-1100px): Collapsed sidebar + content OR bottom nav + drawer
//   Mobile  (< 600px): Bottom navigation bar + hamburger drawer
//
// The DESKTOP layout is 100% preserved — no changes to existing behavior.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'responsive_breakpoints.dart';
import 'responsive_context.dart';
import '../navigation/navigation_controller.dart';
import '../navigation/app_screens.dart';
import '../../widgets/desktop/desktop_root_shell.dart';
import 'mobile_bottom_nav.dart';
import 'mobile_drawer.dart';
import '../../widgets/desktop/content_host.dart';

/// The concrete shell variant chosen for a given width and orientation.
///
/// Exposed alongside [selectShell] so the selection logic can be unit- and
/// property-tested without building a widget tree (Property 4: shell selection).
enum Shell { desktop, tabletLandscape, tabletPortrait, mobile }

/// Pure shell-selection function — the single decision point for which shell
/// the [AdaptiveShell] renders.
///
/// Classification uses the single source of truth [ResponsiveBreakpoints]:
///   * [Shell.desktop]         when `width >= 1100`
///   * [Shell.tabletLandscape] when `600 <= width < 1100` and landscape
///   * [Shell.tabletPortrait]  when `600 <= width < 1100` and portrait
///   * [Shell.mobile]          when `width < 600`
///
/// It is pure and side-effect-free, so it is trivially testable in isolation
/// (no [BuildContext] or widget tree required).
Shell selectShell(double width, Orientation orientation) {
  switch (ResponsiveBreakpoints.classify(width)) {
    case FormFactor.desktop:
      return Shell.desktop;
    case FormFactor.tablet:
      return orientation == Orientation.landscape
          ? Shell.tabletLandscape
          : Shell.tabletPortrait;
    case FormFactor.mobile:
      return Shell.mobile;
  }
}

/// Adaptive Shell that renders different layouts based on screen size.
///
/// - Desktop: delegates to [DesktopRootShell] (existing, unchanged)
/// - Tablet: compact sidebar (landscape) or app bar + bottom nav + drawer (portrait)
/// - Mobile: bottom nav + drawer
class AdaptiveShell extends ConsumerWidget {
  const AdaptiveShell({super.key, this.routedChild});

  /// The go_router-routed screen body to render inside the shell content area.
  ///
  /// Non-null ONLY on the go_router path (Task 3.4): the `ShellRoute` builder
  /// passes the routed `child` here so the shell displays the routed screen in
  /// the same region the legacy `DesktopContentHost` fills. When `null` (the
  /// legacy / flag-OFF path, and every existing `const AdaptiveShell()` caller)
  /// the shell renders its own content host exactly as before — ZERO behavior
  /// change. Currently honored by the desktop shell; the mobile/tablet shells
  /// keep their `NavigationController`-driven content host (see
  /// `DesktopRootShell` for the rationale and the documented limitation).
  final Widget? routedChild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read width AND orientation so the shell re-renders both on resize
    // (breakpoint crossing) and on rotation (Req 9.2, 9.8). Both accessors
    // register a MediaQuery dependency that triggers a rebuild.
    final shell = selectShell(context.screenWidth, context.orientation);

    switch (shell) {
      case Shell.desktop:
        // 100% existing desktop layout — delegated unchanged (Req 5.1), now
        // forwarding the routed child so the go_router path renders its screen
        // body in the shell content area (Task 3.4). `routedChild` is null on
        // the legacy path, so desktop behavior is verbatim there.
        return DesktopRootShell(routedChild: routedChild);

      case Shell.tabletLandscape:
        return const _TabletShell(landscape: true);

      case Shell.tabletPortrait:
        return const _TabletShell(landscape: false);

      case Shell.mobile:
        return const _MobileShell();
    }
  }
}

/// Mobile Shell: Scaffold with BottomNavigationBar + Drawer
class _MobileShell extends ConsumerStatefulWidget {
  const _MobileShell();

  @override
  ConsumerState<_MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<_MobileShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationControllerProvider);
    final currentScreen = navState.currentScreen;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _getScreenTitle(currentScreen),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Global search — can be connected later
            },
          ),
        ],
        elevation: 0,
      ),

      // Full sidebar menu as drawer on mobile
      drawer: const MobileDrawer(),

      // Main content area — reuses existing DesktopContentHost
      body: SafeArea(child: const DesktopContentHost()),

      // Bottom navigation for quick access
      bottomNavigationBar: MobileBottomNav(
        currentScreen: currentScreen,
        onScreenSelected: (screen) {
          ref.read(navigationControllerProvider.notifier).navigateTo(screen);
        },
      ),
    );
  }

  String _getScreenTitle(AppScreen screen) {
    switch (screen) {
      case AppScreen.executiveDashboard:
        return 'Dashboard';
      case AppScreen.newSale:
        return 'New Sale';
      case AppScreen.stockSummary:
      case AppScreen.itemStock:
        return 'Inventory';
      case AppScreen.customers:
        return 'Customers';
      case AppScreen.settings:
      case AppScreen.deviceSettings:
        return 'Settings';
      case AppScreen.salesRegister:
        return 'Sales Register';
      case AppScreen.partyLedger:
        return 'Party Ledger';
      case AppScreen.expenses:
        return 'Expenses';
      case AppScreen.gstr1:
        return 'GST Reports';
      case AppScreen.paymentHistory:
        return 'Payments';
      case AppScreen.patientsList:
        return 'Patients';
      case AppScreen.appointments:
        return 'Appointments';
      case AppScreen.prescriptions:
        return 'Prescriptions';
      default:
        // Convert enum name to title case
        return screen.name
            .replaceAllMapped(
              RegExp(r'([A-Z])'),
              (match) => ' ${match.group(1)}',
            )
            .trim()
            .replaceFirst(screen.name[0], screen.name[0].toUpperCase());
    }
  }
}

/// Tablet Shell: Similar to mobile but with more space utilization.
///
/// The orientation decision is made by the pure [selectShell] function and
/// passed in via [landscape] so this widget renders deterministically:
///   * landscape -> compact icon-only sidebar + content
///   * portrait  -> app bar + bottom nav + drawer (like mobile, larger)
class _TabletShell extends ConsumerStatefulWidget {
  const _TabletShell({required this.landscape});

  /// Whether to render the landscape layout (compact sidebar) or the portrait
  /// layout (app bar + bottom nav + drawer).
  final bool landscape;

  @override
  ConsumerState<_TabletShell> createState() => _TabletShellState();
}

class _TabletShellState extends ConsumerState<_TabletShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationControllerProvider);
    final currentScreen = navState.currentScreen;

    // In landscape on tablet, show a compact sidebar
    if (widget.landscape) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Row(
          children: [
            // Compact icon-only sidebar for tablet landscape
            _TabletCompactSidebar(
              currentScreen: currentScreen,
              onScreenSelected: (screen) {
                ref
                    .read(navigationControllerProvider.notifier)
                    .navigateTo(screen);
              },
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            // Main content
            const Expanded(child: SafeArea(child: DesktopContentHost())),
          ],
        ),
        drawer: const MobileDrawer(),
      );
    }

    // Portrait tablet: same as mobile but with larger bottom nav
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _getScreenTitle(currentScreen),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [IconButton(icon: const Icon(Icons.search), onPressed: () {})],
        elevation: 0,
      ),
      drawer: const MobileDrawer(),
      body: SafeArea(child: const DesktopContentHost()),
      bottomNavigationBar: MobileBottomNav(
        currentScreen: currentScreen,
        onScreenSelected: (screen) {
          ref.read(navigationControllerProvider.notifier).navigateTo(screen);
        },
      ),
    );
  }

  String _getScreenTitle(AppScreen screen) {
    switch (screen) {
      case AppScreen.executiveDashboard:
        return 'Dashboard';
      case AppScreen.newSale:
        return 'New Sale';
      case AppScreen.stockSummary:
      case AppScreen.itemStock:
        return 'Inventory';
      case AppScreen.customers:
        return 'Customers';
      case AppScreen.settings:
        return 'Settings';
      default:
        return screen.name
            .replaceAllMapped(
              RegExp(r'([A-Z])'),
              (match) => ' ${match.group(1)}',
            )
            .trim();
    }
  }
}

/// Compact sidebar for tablet landscape mode (icon-only, ~72px wide)
class _TabletCompactSidebar extends StatelessWidget {
  final AppScreen currentScreen;
  final void Function(AppScreen) onScreenSelected;
  final VoidCallback onMenuTap;

  const _TabletCompactSidebar({
    required this.currentScreen,
    required this.onScreenSelected,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final items = [
      _SidebarItem(
        Icons.dashboard_rounded,
        'Dashboard',
        AppScreen.executiveDashboard,
      ),
      _SidebarItem(Icons.point_of_sale_rounded, 'New Sale', AppScreen.newSale),
      _SidebarItem(
        Icons.inventory_2_rounded,
        'Inventory',
        AppScreen.stockSummary,
      ),
      _SidebarItem(Icons.people_rounded, 'Customers', AppScreen.customers),
      _SidebarItem(
        Icons.account_balance_wallet_rounded,
        'Ledger',
        AppScreen.partyLedger,
      ),
      _SidebarItem(
        Icons.analytics_rounded,
        'Analytics',
        AppScreen.analyticsHub,
      ),
    ];

    return Container(
      width: 72,
      color: colorScheme.surface,
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Menu button at top
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: onMenuTap,
            tooltip: 'Full Menu',
          ),
          const Divider(),
          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: items.map((item) {
                final isSelected = currentScreen == item.screen;
                return Tooltip(
                  message: item.label,
                  preferBelow: false,
                  child: InkWell(
                    onTap: () => onScreenSelected(item.screen),
                    child: Container(
                      height: 56,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        item.icon,
                        color: isSelected
                            ? colorScheme.primary
                            : theme.iconTheme.color?.withOpacity(0.6),
                        size: 24,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Settings at bottom
          const Divider(),
          IconButton(
            icon: Icon(
              Icons.settings_rounded,
              color: currentScreen == AppScreen.settings
                  ? colorScheme.primary
                  : theme.iconTheme.color?.withOpacity(0.6),
            ),
            onPressed: () => onScreenSelected(AppScreen.settings),
            tooltip: 'Settings',
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SidebarItem {
  final IconData icon;
  final String label;
  final AppScreen screen;
  const _SidebarItem(this.icon, this.label, this.screen);
}
