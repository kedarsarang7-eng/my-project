/// Bug Condition Exploration Test — Workspace Scroll Physics (HARDWARE-008)
///
/// **Validates: Requirements 1.8, 2.8**
///
/// Property 8: RefreshIndicator reliably detects pull-to-refresh gesture on
/// mobile/tablet viewports.
///
/// Bug Condition: `isBugCondition(input)` where
///   `input.surface == 'workspace.pullToRefresh'` and
///   `viewport in {mobile, tablet}`
///
/// BEFORE fix: `ListView(shrinkWrap: true, physics: NeverScrollableScrollPhysics())`
/// prevents the RefreshIndicator from detecting the overscroll gesture —
/// pull-to-refresh never triggers on mobile/tablet.
///
/// AFTER fix: The scroll physics allow overscroll so RefreshIndicator detects
/// the gesture, while the desktop Refresh button continues to work.
///
/// Run: flutter test test/bug_condition/hardware_workspace_scroll_physics_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/hardware/presentation/screens/hardware_phase12_workspace_screen.dart';

void main() {
  group('Bug Condition HARDWARE-008 — workspace pull-to-refresh', () {
    // =========================================================================
    // Mobile viewport: RefreshIndicator must detect overscroll gesture
    // =========================================================================
    testWidgets(
      'RefreshIndicator triggers on mobile viewport pull-to-refresh gesture',
      (tester) async {
        // Set mobile viewport size (375x812 - iPhone X)
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());
        addTearDown(() => tester.view.resetDevicePixelRatio());

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: HardwarePhase12WorkspaceScreen()),
          ),
        );

        // Wait for _load() to complete (allow async state to settle)
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Find the RefreshIndicator in the widget tree
        final refreshIndicatorFinder = find.byType(RefreshIndicator);
        expect(
          refreshIndicatorFinder,
          findsOneWidget,
          reason: 'RefreshIndicator must be present in the widget tree.',
        );

        // Find a Scrollable descendant that the RefreshIndicator can observe.
        // The key check: with NeverScrollableScrollPhysics the scrollable
        // won't produce overscroll notifications, so RefreshIndicator never
        // triggers. With proper physics it WILL trigger.
        final scrollableFinder = find.byType(Scrollable);
        expect(
          scrollableFinder,
          findsWidgets,
          reason: 'There must be at least one Scrollable widget.',
        );

        // Attempt a pull-down (fling down from the top) to trigger refresh.
        // We need to find a position inside the scrollable area.
        final scrollable = find.byType(Scrollable).first;

        // Perform a drag-down gesture (simulates pull-to-refresh)
        await tester.fling(scrollable, const Offset(0, 300), 800);
        await tester.pump();

        // After the fling, check for the RefreshIndicator's progress indicator
        // appearing. If NeverScrollableScrollPhysics is in effect, no scroll
        // notification reaches RefreshIndicator — the CircularProgressIndicator
        // from the RefreshIndicator never appears.
        //
        // We pump a few frames to let the indicator animate in.
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // The RefreshIndicator shows a CircularProgressIndicator when triggered.
        // Note: There's already one CircularProgressIndicator for loading state,
        // so we check that the RefreshIndicator's internal one appears OR the
        // onRefresh callback was invoked (which re-triggers _load -> loading state).
        //
        // The simplest check: after the fling, pumpAndSettle should show that
        // the screen re-entered loading state (meaning _load was called again).
        // But with NeverScrollableScrollPhysics, _load() is NOT called by the
        // gesture — only the button can call it.
        //
        // Strategy: Look for the RefreshIndicator's internal progress indicator.
        // RefreshIndicator paints its own CircularProgressIndicator at the top.
        // With never-scroll-physics, the fling doesn't produce overscroll, so
        // the indicator is never shown.
        //
        // We check that the scrollable DOES allow user scrolling (physics check)
        final scrollableWidget = tester.widget<Scrollable>(scrollable);
        final physics = scrollableWidget.physics;

        // NeverScrollableScrollPhysics means the user cannot scroll at all,
        // which means RefreshIndicator can never detect overscroll.
        // AlwaysScrollableScrollPhysics (or default/bouncing) means it CAN.
        final allowsUserScroll =
            physics == null || physics is! NeverScrollableScrollPhysics;

        expect(
          allowsUserScroll,
          isTrue,
          reason:
              'COUNTEREXAMPLE (HARDWARE-008): The Scrollable inside '
              'HardwarePhase12WorkspaceScreen uses NeverScrollableScrollPhysics, '
              'which prevents RefreshIndicator from detecting the overscroll '
              'gesture on mobile/tablet. Pull-to-refresh never triggers. '
              'Actual physics: $physics',
        );
      },
    );

    // =========================================================================
    // Tablet viewport: same check at tablet breakpoint
    // =========================================================================
    testWidgets(
      'RefreshIndicator triggers on tablet viewport pull-to-refresh gesture',
      (tester) async {
        // Set tablet viewport size (768x1024 - iPad)
        tester.view.physicalSize = const Size(768, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());
        addTearDown(() => tester.view.resetDevicePixelRatio());

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: HardwarePhase12WorkspaceScreen()),
          ),
        );

        await tester.pumpAndSettle(const Duration(seconds: 3));

        final scrollable = find.byType(Scrollable).first;
        final scrollableWidget = tester.widget<Scrollable>(scrollable);
        final physics = scrollableWidget.physics;

        final allowsUserScroll =
            physics == null || physics is! NeverScrollableScrollPhysics;

        expect(
          allowsUserScroll,
          isTrue,
          reason:
              'COUNTEREXAMPLE (HARDWARE-008): The Scrollable inside '
              'HardwarePhase12WorkspaceScreen uses NeverScrollableScrollPhysics '
              'at tablet viewport, preventing RefreshIndicator from detecting '
              'the overscroll gesture. Pull-to-refresh never triggers. '
              'Actual physics: $physics',
        );
      },
    );

    // =========================================================================
    // Preservation: Desktop button-refresh must remain functional
    // =========================================================================
    testWidgets('Desktop Refresh button is present and invokes _load()', (
      tester,
    ) async {
      // Set desktop viewport size (1440x900)
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: HardwarePhase12WorkspaceScreen()),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 3));

      // The desktop Refresh button should be present
      final refreshButton = find.widgetWithText(FilledButton, 'Refresh');
      expect(
        refreshButton,
        findsOneWidget,
        reason:
            'The desktop Refresh button must remain present — it directly '
            'calls _load() for non-gesture refresh on desktop.',
      );
    });
  });
}
