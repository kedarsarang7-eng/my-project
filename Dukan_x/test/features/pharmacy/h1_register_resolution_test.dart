// ============================================================================
// PHASE 1 — Task 5.2: H1 REGISTER RESOLUTION TEST
// Feature: pharmacy-vertical-remediation
// **Validates: Requirements 9.4**
// ============================================================================
//
// Requirement 9.4 (requirements.md — Fix H1 Register Dead Navigation Link):
//   THE System SHALL include an automated test verifying that activating H1
//   Register navigation resolves the `h1_register` identifier to an
//   `H1RegisterScreen` instance and asserts the resolved screen is not a
//   `_PlaceholderScreen` instance.
//
// CONTEXT (Task 5.1):
//   `SidebarNavigationHandler.tryGetScreenForItem` was given an `h1_register`
//   case that returns `const H1RegisterScreen()`, so the navigation action no
//   longer dead-ends on the private `_PlaceholderScreen` fallback.
//
// WHAT THIS PROVES:
//   1. `getScreenForItem('h1_register', context)` resolves to an
//      `H1RegisterScreen` instance (R9.2).
//   2. The resolved widget is never the `_PlaceholderScreen` fallback. Since
//      `_PlaceholderScreen` is private to the handler library and cannot be
//      imported, the assertion is expressed by runtime type: the resolved
//      widget's `runtimeType` is exactly `H1RegisterScreen` and its type name
//      is not `_PlaceholderScreen`.
//
// SEAM / SETUP:
//   The `h1_register` branch returns `const H1RegisterScreen()` directly and
//   does not touch the service locator or session — only a `BuildContext` is
//   required by the resolver signature. A `Builder` inside a pumped
//   `MaterialApp` supplies a real context; the resolved screen is inspected as
//   a value object and is never itself pumped, so no `ApiClient`/Hive setup is
//   needed.
//
// Run: flutter test test/features/pharmacy/h1_register_resolution_test.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/prescriptions/presentation/screens/h1_register_screen.dart';
import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';

void main() {
  group('Feature: pharmacy-vertical-remediation, R9.4: H1 Register resolution', () {
    testWidgets(
      '`h1_register` resolves to an H1RegisterScreen and never a placeholder',
      (tester) async {
        // Capture a real BuildContext for the resolver, which requires one in
        // its signature even though the h1_register branch does not use it.
        late BuildContext capturedContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        // tryGetScreenForItem returns null on a genuine resolution miss; the
        // h1_register case must resolve to a concrete screen.
        final Widget? resolved = SidebarNavigationHandler.tryGetScreenForItem(
          'h1_register',
          capturedContext,
        );

        // R9.2: resolves to an H1RegisterScreen instance.
        expect(
          resolved,
          isNotNull,
          reason: 'h1_register must resolve to a registered screen builder.',
        );
        expect(
          resolved,
          isA<H1RegisterScreen>(),
          reason: 'h1_register must resolve to H1RegisterScreen.',
        );

        // R9.4: the resolved screen is never the private _PlaceholderScreen
        // fallback. Asserted via runtime type since the type is library-private.
        expect(resolved.runtimeType, H1RegisterScreen);
        expect(
          resolved.runtimeType.toString(),
          isNot('_PlaceholderScreen'),
          reason: 'h1_register must not dead-end on the placeholder screen.',
        );

        // The public getScreenForItem entrypoint (used by the router and the
        // desktop content host) must also resolve to the real screen rather than
        // substituting the placeholder fallback.
        final Widget resolvedPublic = SidebarNavigationHandler.getScreenForItem(
          'h1_register',
          capturedContext,
        );
        expect(resolvedPublic, isA<H1RegisterScreen>());
        expect(
          resolvedPublic.runtimeType.toString(),
          isNot('_PlaceholderScreen'),
        );
      },
    );
  });
}
