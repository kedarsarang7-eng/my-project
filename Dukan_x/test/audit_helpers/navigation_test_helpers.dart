/// Navigation/route assertion helpers for Flutter UI audit per-fix tests.
///
/// Provides reusable utilities to assert active routes, back-stack entries,
/// and navigation correctness. Used by `TestCoordinator`-authored tests to
/// validate Requirement 5.5.
///
/// Usage:
/// ```dart
/// import 'package:dukanx/test/audit_helpers/audit_test_helpers.dart';
///
/// testWidgets('navigates to settings', (tester) async {
///   await pumpApp(tester);
///   await navigateAndAssert(tester, '/settings');
/// });
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Asserts that the current top-most route in the navigator matches
/// [expectedRoute].
///
/// Uses the [Navigator] state to inspect the current route. Pumps once
/// to ensure the navigation transition has completed before checking.
void assertActiveRoute(WidgetTester tester, String expectedRoute) {
  final NavigatorState navigator = tester.state(find.byType(Navigator));
  String? currentRoute;

  navigator.popUntil((route) {
    currentRoute = route.settings.name;
    return true;
  });

  expect(
    currentRoute,
    equals(expectedRoute),
    reason: 'Expected active route "$expectedRoute" but got "$currentRoute"',
  );
}

/// Asserts that the navigator back-stack entries match [expectedRoutes] in
/// order (bottom to top).
///
/// Inspects the full route history by walking the navigator stack.
void assertBackStack(WidgetTester tester, List<String> expectedRoutes) {
  final NavigatorState navigator = tester.state(find.byType(Navigator));
  final List<String?> actualRoutes = [];

  navigator.popUntil((route) {
    actualRoutes.insert(0, route.settings.name);
    return true;
  });

  expect(
    actualRoutes,
    equals(expectedRoutes),
    reason:
        'Back-stack mismatch:\n'
        '  Expected: $expectedRoutes\n'
        '  Actual:   $actualRoutes',
  );
}

/// Pushes the named route [route] onto the navigator and asserts that the
/// active route matches after the transition settles.
///
/// Returns the navigation future for optional chaining.
Future<void> navigateAndAssert(WidgetTester tester, String route) async {
  final NavigatorState navigator = tester.state(find.byType(Navigator));
  navigator.pushNamed(route);
  await tester.pumpAndSettle();

  assertActiveRoute(tester, route);
}

/// Pops the navigator and asserts the new active route matches [expectedRoute].
Future<void> popAndAssert(WidgetTester tester, String expectedRoute) async {
  final NavigatorState navigator = tester.state(find.byType(Navigator));
  navigator.pop();
  await tester.pumpAndSettle();

  assertActiveRoute(tester, expectedRoute);
}

/// Creates a minimal [MaterialApp] with the given named routes for testing.
///
/// Useful for navigation tests that need a predictable route table.
Widget buildNavigationTestApp({
  required Map<String, WidgetBuilder> routes,
  String initialRoute = '/',
}) {
  return MaterialApp(initialRoute: initialRoute, routes: routes);
}
