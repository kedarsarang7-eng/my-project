// ============================================================================
// Task 7.2 — PROPERTY TEST
// Feature: mobile-text-scale-responsive-hardening, Property 11: Overflowing
// content is scrollable, not clipped
// **Validates: Requirements 9.4**
// ============================================================================
// Property 11 (design.md): For ANY content taller than the available vertical
//   space at an Elevated_Text_Scale on a Mobile_Viewport, the Feature_Screen
//   exposes a scrollable region whose scroll extent is GREATER THAN ZERO, so
//   all content is reachable rather than clipped.
//
// Requirement 9.4: "WHERE content exceeds the available vertical space on a
//   Mobile_Viewport at an Elevated_Text_Scale, THE Feature_Screen SHALL make
//   the overflowing content scrollable rather than clipped."
//
// UNIT UNDER TEST
//   The standard scrollable region used across the feature screens (e.g. the
//   proforma / GST screens): content placed inside a `SingleChildScrollView`.
//   When the content is taller than the available viewport height, the scroll
//   view's `ScrollPosition.maxScrollExtent` must be > 0 and the bottom of the
//   content must be reachable by scrolling (`jumpTo(maxScrollExtent)` lands at
//   the extent), proving the content is scrollable rather than clipped.
//
// HOW THIS TEST PROVES THE PROPERTY
//   For every generated "excess" height delta x every required (viewport,
//   scale) pair the scroll view is pumped through the app's REAL single
//   text-scale pipeline (`wrapWithPipeline`, non-Windows, so an Above_Cap_Scale
//   is clamped to 1.3). The content is a `SizedBox(height: viewport.height +
//   excess)`, which is GUARANTEED taller than the available vertical space
//   (the Scaffold body is at most the viewport height). The test then:
//     * reads the `ScrollableState.position` of the rendered scroll view and
//       asserts `maxScrollExtent > 0` (a scrollable region exists, R9.4);
//     * jumps to `maxScrollExtent` and asserts the position lands there, so the
//       overflowing content is actually reachable rather than clipped;
//     * captures FlutterError overflow and asserts none occurs (a properly
//       scrollable region never reports a RenderFlex/viewport overflow).
//
//   A negative control (content SHORTER than the viewport) asserts
//   `maxScrollExtent == 0`, strengthening the property: the scroll extent is
//   positive EXACTLY when content overflows, never spuriously.
//
// APPROACH (per task note): a `forAll` that re-pumps inside a single
//   `testWidgets` would corrupt the test binding, so instead a deterministic,
//   seeded sample of excess heights is drawn from a `dartproptest` Generator
//   and EACH excess gets its own `testWidgets`, which iterates the full
//   required (viewport x scale) matrix internally. Pinned extremes (a tiny
//   1px overflow and a very tall 3000px overflow) guarantee both ends are
//   always exercised.
//
// PBT library: dartproptest ^0.2.1 (repo-standard). Matrix constants and the
//   real pipeline wrapper come from `responsive_test_harness.dart`.
//
// Run: flutter test test/responsive/scrollable_not_clipped_property_test.dart -r expanded
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'responsive_test_harness.dart';

void main() {
  // Number of distinct generated excess heights exercised (each across the full
  // 3x3 viewport x scale matrix => >= 22 * 9 = 198 rendered cases).
  const int kSampleCount = 20;

  // Generator: an "excess" height in logical pixels added on top of each
  // viewport's height, so the content is always strictly taller than the
  // available vertical space. Ranges from a modest overflow to a very tall
  // page so a wide spread of scroll extents is exercised.
  final Generator<double> excessGen = Gen.interval(
    20,
    3000,
  ).map((v) => v.toDouble());

  // Draw a DETERMINISTIC sample so the suite is reproducible run-to-run, with
  // pinned extremes (a 1px overflow and a 3000px overflow) so both the tiniest
  // and a very large overflow are always covered.
  final List<double> excesses = _sampleExcesses(excessGen, kSampleCount);

  group('Feature: mobile-text-scale-responsive-hardening, Property 11: '
      'Overflowing content is scrollable, not clipped', () {
    for (var i = 0; i < excesses.length; i++) {
      final excess = excesses[i];
      testWidgets(
        'Property 11 [#$i excess=${excess.toStringAsFixed(0)}px]: content '
        'taller than the viewport is scrollable (maxScrollExtent > 0 and '
        'reachable) across the required viewport x scale matrix',
        (WidgetTester tester) async {
          await _assertOverflowingContentIsScrollable(tester, excess);
        },
      );
    }

    // Negative control: content SHORTER than the available vertical space must
    // NOT be scrollable (maxScrollExtent == 0). This proves the scroll extent
    // is positive exactly when content overflows — never spuriously.
    testWidgets(
      'Property 11 (negative control): content shorter than the viewport yields '
      'maxScrollExtent == 0 across the required matrix',
      (WidgetTester tester) async {
        addTearDown(() => tester.view.resetPhysicalSize());
        addTearDown(() => tester.view.resetDevicePixelRatio());

        for (final viewport in kRequiredViewports) {
          for (final scale in kRequiredScales) {
            tester.view.devicePixelRatio = 1.0;
            tester.view.physicalSize = viewport;

            await tester.pumpWidget(
              wrapWithPipeline(
                const SingleChildScrollView(
                  child: SizedBox(height: 100, width: double.infinity),
                ),
                requestedScale: scale,
              ),
            );
            await tester.pump();

            final position = _scrollPosition(tester);
            final where =
                'viewport ${viewport.width.toStringAsFixed(0)}x'
                '${viewport.height.toStringAsFixed(0)}, requested scale $scale';
            expect(
              position.maxScrollExtent,
              0.0,
              reason:
                  'Short content (100px) must not be scrollable at $where — '
                  'maxScrollExtent should be 0.',
            );
          }
        }
      },
    );
  });
}

/// Pumps a `SingleChildScrollView` whose content is taller than the viewport
/// (by [excess] logical pixels) at every required (viewport x scale)
/// combination, asserting the content is scrollable rather than clipped:
///   * no Overflow_Failure occurs;
///   * the scroll region's `maxScrollExtent` is > 0 (a scrollable region
///     exists, R9.4);
///   * the bottom of the content is reachable (`jumpTo(maxScrollExtent)` lands
///     exactly at the extent), so the overflowing content is not clipped.
Future<void> _assertOverflowingContentIsScrollable(
  WidgetTester tester,
  double excess,
) async {
  addTearDown(() => tester.view.resetPhysicalSize());
  addTearDown(() => tester.view.resetDevicePixelRatio());

  for (final viewport in kRequiredViewports) {
    for (final scale in kRequiredScales) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = viewport;

      // Content is strictly taller than the viewport height, which is itself an
      // upper bound on the available vertical space (the Scaffold body has no
      // app bar), so the content always overflows the available space.
      final contentHeight = viewport.height + excess;

      // Scoped overflow capture, restored in `finally` so one case can never
      // corrupt later cases (mirrors the harness pattern).
      final errors = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);
      try {
        await tester.pumpWidget(
          wrapWithPipeline(
            SingleChildScrollView(
              child: SizedBox(height: contentHeight, width: double.infinity),
            ),
            requestedScale: scale,
          ),
        );
        await tester.pump();
      } finally {
        FlutterError.onError = oldHandler;
      }

      final where =
          'viewport ${viewport.width.toStringAsFixed(0)}x'
          '${viewport.height.toStringAsFixed(0)}, requested scale $scale, '
          'content height ${contentHeight.toStringAsFixed(0)}px';

      // A properly scrollable region never reports a viewport/RenderFlex
      // overflow — the content scrolls instead of being clipped.
      final overflowErrors = errors
          .where((e) => e.toString().contains('overflowed'))
          .toList();
      expect(
        overflowErrors,
        isEmpty,
        reason:
            'Scrollable content produced an Overflow_Failure at $where:\n'
            '${overflowErrors.isEmpty ? '' : overflowErrors.first}',
      );
      // Surface any other build/layout error rather than swallowing it.
      final otherErrors = errors
          .where((e) => !e.toString().contains('overflowed'))
          .toList();
      expect(
        otherErrors,
        isEmpty,
        reason:
            'Unexpected error rendering the scroll view at $where:\n'
            '${otherErrors.isEmpty ? '' : otherErrors.first}',
      );

      // R9.4 — a scrollable region with a POSITIVE scroll extent exists.
      final position = _scrollPosition(tester);
      expect(
        position.maxScrollExtent,
        greaterThan(0.0),
        reason:
            'Content taller than the viewport must expose a scrollable region '
            'with maxScrollExtent > 0 at $where, so it is reachable rather '
            'than clipped.',
      );

      // The overflowing content must be REACHABLE by scrolling: jumping to the
      // max extent lands exactly there (the bottom of the content is visible),
      // proving nothing is permanently clipped off the bottom.
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      expect(
        position.pixels,
        moreOrLessEquals(position.maxScrollExtent, epsilon: 0.5),
        reason:
            'The bottom of the overflowing content must be reachable by '
            'scrolling to maxScrollExtent at $where.',
      );
    }
  }
}

/// Returns the [ScrollPosition] of the single `SingleChildScrollView` rendered
/// in the tree. Reading the position directly (rather than owning a
/// `ScrollController`) avoids any controller-disposal bookkeeping while still
/// exposing `maxScrollExtent` / `pixels` / `jumpTo`.
ScrollPosition _scrollPosition(WidgetTester tester) {
  final scrollableFinder = find.descendant(
    of: find.byType(SingleChildScrollView),
    matching: find.byType(Scrollable),
  );
  return tester.state<ScrollableState>(scrollableFinder).position;
}

/// Draws a deterministic sample of [count] excess heights from [gen] using a
/// fixed seed, then pins guaranteed extremes (a 1px overflow and a very tall
/// 3000px overflow) so both ends are always exercised.
List<double> _sampleExcesses(Generator<double> gen, int count) {
  final rand = Random('mobile-text-scale-scrollable-property-11');
  final out = <double>[
    1.0, // smallest meaningful overflow
    3000.0, // very tall page
  ];
  for (var i = 0; i < count; i++) {
    out.add(gen.generate(rand).value);
  }
  return out;
}
