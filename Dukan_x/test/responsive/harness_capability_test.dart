// ============================================================================
// HARNESS CAPABILITY META-TEST — Task 2.4
// Feature: mobile-text-scale-responsive-hardening
// ============================================================================
// A plain capability/example test that proves the Responsive_Test_Harness
// actually does what every other hardening test relies on: pumping a widget at
// a chosen Mobile_Viewport and Elevated_Text_Scale must make that viewport and
// the EFFECTIVE (clamped) text scale observable through `MediaQuery`.
//
// This guards Requirement 10.1 — "THE Responsive_Test_Harness SHALL render a
// target screen or widget under a specified Mobile_Viewport and a specified
// Elevated_Text_Scale." If the harness silently failed to apply the viewport or
// routed the scale incorrectly, every downstream overflow test would be
// rendering under the wrong conditions; this meta-test fails fast in that case.
//
// `wrapWithPipeline` injects the requested scale then routes it through the real
// `applyTextScaleClamp(isWindowsOverride: false)`, so the effective textScaler
// is clamped to `kMaxTextScaleFactor` (1.3) on non-Windows:
//   requested 1.0 -> 1.0, requested 1.3 -> 1.3, requested 2.6 -> 1.3 (capped).
//
// Validates: Requirement 10.1
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'responsive_test_harness.dart';

void main() {
  group('Responsive_Test_Harness capability (Requirement 10.1)', () {
    // A representative Mobile_Viewport; with devicePixelRatio 1.0 the logical
    // size equals the physical size.
    const viewport = Size(360, 640);

    /// Pumps a [Builder] wrapped in the real pipeline at [viewport] with
    /// [requestedScale], captures the inner [BuildContext], and returns the
    /// observed logical size and effective text-scale factor.
    Future<({Size size, double effectiveScale})> pumpAndCapture(
      WidgetTester tester, {
      required double requestedScale,
    }) async {
      // Apply the viewport; reset after the test so state never leaks (mirrors
      // the harness's own teardown discipline).
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = viewport;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late Size capturedSize;
      late double capturedScale;

      await tester.pumpWidget(
        wrapWithPipeline(
          Builder(
            builder: (context) {
              capturedSize = MediaQuery.sizeOf(context);
              capturedScale = MediaQuery.textScalerOf(context).scale(1.0);
              return const SizedBox.shrink();
            },
          ),
          requestedScale: requestedScale,
        ),
      );

      return (size: capturedSize, effectiveScale: capturedScale);
    }

    testWidgets(
      'pumping sets MediaQuery.size to the logical viewport (physicalSize / dpr)',
      (tester) async {
        final observed = await pumpAndCapture(
          tester,
          requestedScale: kBaselineScale,
        );

        // devicePixelRatio is 1.0, so logical size == physical size.
        expect(observed.size, equals(viewport));
      },
    );

    testWidgets('baseline scale (1.0) reaches the tree unchanged', (
      tester,
    ) async {
      final observed = await pumpAndCapture(
        tester,
        requestedScale: kBaselineScale,
      );

      expect(observed.effectiveScale, equals(1.0));
    });

    testWidgets('at-cap scale (1.3) reaches the tree unchanged', (
      tester,
    ) async {
      final observed = await pumpAndCapture(tester, requestedScale: kCapScale);

      expect(observed.effectiveScale, equals(kCapScale));
    });

    testWidgets('above-cap scale (2.6) is clamped to the cap (1.3)', (
      tester,
    ) async {
      final observed = await pumpAndCapture(
        tester,
        requestedScale: kAboveCapScale,
      );

      // The pipeline must collapse an Above_Cap_Scale request to exactly the
      // cap on non-Windows, never letting it reach the tree unclamped.
      expect(observed.effectiveScale, equals(kCapScale));
      expect(observed.effectiveScale, lessThan(kAboveCapScale));
    });
  });
}
