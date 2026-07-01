// =============================================================================
// Sidebar dispatch — sidebar-tap navigation (DukanX go_router migration)
// =============================================================================
//
// Feature: gorouter-navigation-migration
// Task 3.4 (PHASE 2) — introduced this single dispatch seam.
// Task 9.3 (PHASE 8) — legacy removal. The `useGoRouterShell` flag and the
// legacy `NavigationController` dispatch branch have been removed; go_router is
// now the SOLE navigation path. A sidebar tap always navigates via
// `context.go(RoutePaths.navPathForItemId(itemId))`, and the `ShellRoute`
// builder renders the resolved child into the shell content area.
//
// WHY A STANDALONE FUNCTION (not a method on the shell or on AppRouter):
//   * Keeping the decision out of the shell widget makes it unit-testable in
//     isolation (no need to pump the heavyweight `DesktopRootShell` + sidebar
//     + content host) — see `phase2_sidebar_dispatch_test.dart`.
//   * It intentionally does NOT import any shell widget, so it introduces no
//     import cycle (the shell imports this; this imports only routing).
// =============================================================================

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'route_paths.dart';

/// Dispatches a sidebar item selection through go_router.
///
/// Navigates to the named route for [itemId]; the `ShellRoute` renders the
/// resolved child into the shell content area. `navPathForItemId` resolves BOTH
/// legacy items and new post-legacy routes (e.g. `scan_bill`), so newly-added
/// routes navigate too.
///
/// [context] must be the shell's tap-handler context — a descendant of the
/// app's `GoRouter`, so `context.go` resolves correctly.
void dispatchSidebarItem(BuildContext context, String itemId) {
  context.go(RoutePaths.navPathForItemId(itemId));
}
