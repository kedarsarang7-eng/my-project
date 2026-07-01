// ============================================================================
// Task 11.2 — WIDGET TESTS
// Feature: cross-platform-responsive-ui — Stability behaviors
// Requirements: 10.3, 10.4, 10.5, 11.7
// ============================================================================
// Units under test:
//   • `FeatureErrorBoundary` (lib/widgets/feature_error_boundary.dart) — wraps
//     each screen in the DesktopContentHost so a render error is *isolated* to
//     that screen's subtree. The boundary intentionally does NOT intercept the
//     subtree error itself (its internal `_ErrorCatcher` is a no-op); instead a
//     failing build is caught by Flutter's framework and replaced via the
//     global `ErrorWidget.builder`, which the app wires to `MainErrorFallback`
//     (see lib/app/error_handlers.dart -> installGlobalErrorHandlers). These
//     tests reproduce that exact global wiring so the asserted "recovery UI" is
//     the same recoverable error screen the End_User actually sees.
//   • `AsyncFeedback` (lib/core/responsive/async_feedback.dart) —
//       - showError(): consistent, dismissible SnackBar error channel (Req 10.4)
//       - runWithProgress(): inserts an AppLoadingIndicator overlay only after a
//         latency threshold elapses (Req 10.5 / Req 11.7).
//   • `AppLoadingIndicator` (lib/widgets/loading/loading_states.dart).
//
// Time is driven deterministically with `tester.pump(Duration(...))` rather than
// real waits. `pumpAndSettle` is deliberately avoided while the loading
// indicator is on screen, because its CircularProgressIndicator animates forever
// and would never settle.
//
// Run: flutter test test/widgets/stability_test.dart
// ============================================================================

import 'package:dukanx/core/navigation/app_screens.dart';
import 'package:dukanx/core/responsive/async_feedback.dart';
import 'package:dukanx/widgets/error_boundary.dart' show MainErrorFallback;
import 'package:dukanx/widgets/feature_error_boundary.dart';
import 'package:dukanx/widgets/loading/loading_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Feature: cross-platform-responsive-ui — Stability behaviors', () {
    // ------------------------------------------------------------------
    // Req 10.3 — A render error is contained to the affected screen, which
    // shows a recoverable error state, while other destinations stay
    // navigable and operable.
    // ------------------------------------------------------------------
    group('per-screen render error isolation + recovery (Req 10.3)', () {
      late ErrorWidgetBuilder originalBuilder;

      setUp(() {
        // Reproduce the app's global recovery wiring so a failing subtree is
        // replaced with the recoverable error UI instead of the red screen.
        originalBuilder = ErrorWidget.builder;
        ErrorWidget.builder = (FlutterErrorDetails details) =>
            MainErrorFallback(details: details);
      });

      tearDown(() {
        ErrorWidget.builder = originalBuilder;
      });

      testWidgets(
        'a throwing screen shows recovery UI while a sibling destination '
        'stays operable',
        (tester) async {
          // A tall surface so the recovery UI renders comfortably in its half
          // of the column (avoids an unrelated RenderFlex overflow).
          tester.view.physicalSize = const Size(1200, 2000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          var healthyTaps = 0;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    // Destination A: deliberately throws during build.
                    Expanded(
                      child: FeatureErrorBoundary(
                        screen: AppScreen.newSale,
                        child: Builder(
                          builder: (_) => throw StateError('boom'),
                        ),
                      ),
                    ),
                    // Destination B: a healthy, interactive screen.
                    Expanded(
                      child: FeatureErrorBoundary(
                        screen: AppScreen.customers,
                        child: Center(
                          child: ElevatedButton(
                            onPressed: () => healthyTaps++,
                            child: const Text('Healthy destination'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          // The render error was caught by the framework (no hard crash).
          expect(tester.takeException(), isA<StateError>());

          // The crashed screen is replaced by the recoverable error state.
          expect(find.byType(MainErrorFallback), findsOneWidget);
          expect(find.text('Application Error'), findsOneWidget);

          // The other destination still renders and remains operable.
          expect(find.text('Healthy destination'), findsOneWidget);
          await tester.tap(find.text('Healthy destination'));
          await tester.pump();
          expect(healthyTaps, 1);
        },
      );
    });

    // ------------------------------------------------------------------
    // Req 10.4 — An operation failure surfaces a dismissible message and the
    // app stays usable (no restart required).
    // ------------------------------------------------------------------
    testWidgets(
      'an operation failure shows a dismissible message and the app stays '
      'usable (Req 10.4)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () =>
                        AsyncFeedback.showError(context, 'Something failed'),
                    child: const Text('Trigger failure'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Trigger failure'));
        await tester.pump(); // schedule the SnackBar
        await tester.pump(const Duration(milliseconds: 750)); // animate in

        // The failure message is shown through the consistent error channel.
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Something failed'), findsOneWidget);

        // It is dismissible (explicit Dismiss action) and the app stays usable:
        // the triggering control is still present and interactive.
        expect(find.text('Dismiss'), findsOneWidget);
        expect(find.text('Trigger failure'), findsOneWidget);

        // Dismissing removes the message without restarting the app.
        await tester.tap(find.text('Dismiss'));
        await tester.pump(); // start dismiss animation
        await tester.pump(const Duration(milliseconds: 750)); // animate out
        expect(find.byType(SnackBar), findsNothing);

        // The app is still usable afterwards.
        expect(find.text('Trigger failure'), findsOneWidget);
      },
    );

    // ------------------------------------------------------------------
    // Req 10.5 / Req 11.7 — A long operation shows a progress indicator that
    // stays visible until it completes; a fast operation never flashes one.
    // ------------------------------------------------------------------
    testWidgets(
      'a long operation shows a progress indicator until it completes '
      '(Req 10.5, Req 11.7)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => AsyncFeedback.runWithProgress<String>(
                      context,
                      () async {
                        await Future<void>.delayed(
                          const Duration(milliseconds: 300),
                        );
                        return 'done';
                      },
                      threshold: const Duration(milliseconds: 50),
                    ),
                    child: const Text('Run long op'),
                  ),
                ),
              ),
            ),
          ),
        );

        // No indicator before the operation begins.
        expect(find.byType(AppLoadingIndicator), findsNothing);

        await tester.tap(find.text('Run long op'));
        await tester.pump(); // start operation + arm the threshold timer

        // Before the threshold elapses, the operation stays spinner-free.
        await tester.pump(const Duration(milliseconds: 20));
        expect(find.byType(AppLoadingIndicator), findsNothing);

        // Once the latency threshold passes, the progress indicator appears.
        await tester.pump(const Duration(milliseconds: 50)); // ~70ms > 50ms
        expect(find.byType(AppLoadingIndicator), findsOneWidget);

        // It remains visible while the operation is still running.
        await tester.pump(const Duration(milliseconds: 100)); // ~170ms < 300ms
        expect(find.byType(AppLoadingIndicator), findsOneWidget);

        // After the operation completes, the indicator is removed.
        await tester.pump(const Duration(milliseconds: 200)); // ~370ms > 300ms
        await tester.pump(); // rebuild overlay after the entry is removed
        expect(find.byType(AppLoadingIndicator), findsNothing);
      },
    );

    testWidgets(
      'a fast operation does not flash a progress indicator (Req 10.5)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => AsyncFeedback.runWithProgress<String>(
                      context,
                      () async => 'instant',
                      threshold: const Duration(milliseconds: 50),
                    ),
                    child: const Text('Run fast op'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Run fast op'));
        await tester.pump(); // operation resolves before the threshold timer

        // Even after the threshold window passes, no indicator was inserted.
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(AppLoadingIndicator), findsNothing);
      },
    );
  });
}
