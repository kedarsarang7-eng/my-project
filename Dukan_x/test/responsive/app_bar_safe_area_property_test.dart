// ============================================================================
// Task 4.3 — PROPERTY TEST
// Feature: mobile-text-scale-responsive-hardening, Property 10: App-bar header
// respects safe-area insets
// **Validates: Requirements 7.3**
// ============================================================================
// Property 10 (design.md): For ANY simulated top safe-area inset (status bar /
//   notch height) and required (viewport x text-scale) combination, the
//   App_Bar_Header content's top offset is GREATER THAN OR EQUAL TO the inset,
//   so header text never collides with the status bar or notch.
//
// Requirement 7.3: "WHEN an App_Bar_Header is rendered on a Mobile_Viewport,
//   THE App_Bar_Header content SHALL respect the device safe-area insets so
//   that text does not collide with the status bar or notch."
//
// UNIT UNDER TEST
//   `DesktopContentContainer._buildHeader` wraps the header `Container` in
//   `SafeArea(bottom: false)`. SafeArea consumes `MediaQuery.padding.top`, so a
//   simulated top inset pushes the header (and therefore the title text) down
//   by at least that inset. The property asserts the title's painted top offset
//   is >= the injected inset across the full required matrix.
//
// HOW THE INSET IS INJECTED
//   The shared harness `wrapWithPipeline` cannot set MediaQuery padding, so this
//   test uses a local wrapper that mirrors the harness pattern but ALSO injects
//   `padding: EdgeInsets.only(top: inset)`. The requested text scale is still
//   routed through the app's REAL single pipeline (`applyTextScaleClamp`,
//   `isWindowsOverride: false`) so the effective scale reaching the tree is
//   exactly what production applies on a non-Windows device (above-cap requests
//   collapse to kMaxTextScaleFactor = 1.3). The header is hosted in a bare
//   `Material` (NOT a `Scaffold`) so nothing consumes the top padding before the
//   header's own `SafeArea` does — keeping the inset deterministic.
//
// GENERATED SWEEP (not a single forAll closure):
//   Re-pumping many generated cases inside ONE `testWidgets` and `fail()`-ing
//   mid-stream corrupts the test binding, so — exactly like
//   `harness_overflow_detection_property_test.dart` — we draw a deterministic,
//   seeded SAMPLE of insets from a `dartproptest` Generator at suite-build time
//   and run each inset in its OWN isolated `testWidgets`, iterating the full
//   required (viewport x scale) matrix inside it. This is the dartproptest
//   equivalent of a `forAll` over simulated insets, with each case isolated and
//   the seed fixed for reproducibility. Pinned extremes (0 = no inset, 80 = a
//   large notch) guarantee both ends are always exercised.
//
// PBT library: dartproptest ^0.2.1 (the repo-standard QuickCheck/Hypothesis-
//   inspired library).
//
// Run: flutter test test/responsive/app_bar_safe_area_property_test.dart -r expanded
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/app/app.dart' show applyTextScaleClamp;
import 'package:dukanx/widgets/desktop/desktop_content_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'responsive_test_harness.dart';

const String _kTitle = 'Device Settings';
const String _kSubtitle = 'Configure device-specific preferences';

/// Wraps [child] in a [MaterialApp] applying the app's REAL single text-scale
/// pipeline AND a simulated top safe-area [topInset].
///
/// Mirrors [wrapWithPipeline] but additionally injects
/// `padding: EdgeInsets.only(top: topInset)` so the header's `SafeArea` has a
/// real inset to respect. The host is a bare [Material] (not a [Scaffold]) so
/// nothing consumes the top padding before the header does, making the inset's
/// effect on the title's top offset deterministic.
Widget _wrapWithInset(
  Widget child, {
  required double requestedScale,
  required double topInset,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? ThemeData.light(useMaterial3: true),
    debugShowCheckedModeBanner: false,
    home: Material(child: child),
    builder: (context, widget) {
      // Inject the requested scale + simulated top inset, then run the
      // production clamp so the effective TextScaler is exactly what the app
      // would apply on a non-Windows platform. copyWith preserves the padding.
      final injected = MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(requestedScale),
        padding: EdgeInsets.only(top: topInset),
      );
      final clamped = applyTextScaleClamp(injected, isWindowsOverride: false);
      return MediaQuery(data: clamped, child: widget!);
    },
  );
}

/// Generator: a simulated top safe-area inset in logical pixels, spanning none
/// (0) through tall notches (~80) — the realistic range of status bar / notch
/// heights on Android phones.
final Generator<double> _insetGen = Gen.interval(
  0,
  80,
).map((v) => v.toDouble());

/// Draws [count] reproducible insets from [_insetGen] using a fixed seed, then
/// pins guaranteed extremes (0 = no inset, common status-bar / notch heights,
/// and 80 = a large notch) so both ends are always exercised.
List<double> _sampleInsets(int count) {
  final random = Random('mobile-text-scale-hardening-property-10');
  final insets = <double>[
    0.0, // no inset (e.g. desktop / no notch)
    24.0, // typical status bar
    44.0, // common notch inset
    47.0, // tall notch inset
    80.0, // large notch
  ];
  for (var i = 0; i < count; i++) {
    insets.add(_insetGen.generate(random).value);
  }
  return insets;
}

/// Pumps the App_Bar_Header (via [DesktopContentContainer]) at every required
/// (viewport x scale) combination with the given top [inset], asserting:
///   * no Overflow_Failure occurs, and
///   * the title's painted top offset is >= [inset] (header content is pushed
///     below the safe-area inset, so it never collides with the status
///     bar / notch).
Future<void> _assertHeaderRespectsInset(
  WidgetTester tester,
  double inset,
) async {
  addTearDown(() => tester.view.resetPhysicalSize());
  addTearDown(() => tester.view.resetDevicePixelRatio());

  for (final viewport in kRequiredViewports) {
    for (final scale in kRequiredScales) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = viewport;

      final errors = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      try {
        await tester.pumpWidget(
          _wrapWithInset(
            const DesktopContentContainer(
              title: _kTitle,
              subtitle: _kSubtitle,
              // No scrollbar/back button needed; keep the subject (the header)
              // isolated and free of a PrimaryScrollController dependency.
              showScrollbar: false,
              child: SizedBox(height: 200),
            ),
            requestedScale: scale,
            topInset: inset,
          ),
        );
        await tester.pump();
      } finally {
        FlutterError.onError = oldHandler;
      }

      final where =
          'viewport '
          '${viewport.width.toStringAsFixed(0)}x'
          '${viewport.height.toStringAsFixed(0)}, '
          'requested scale $scale, inset $inset';

      // No overflow at any combination (the header stays Overflow_Safe).
      final overflowErrors = errors
          .where((e) => e.toString().contains('overflowed'))
          .toList();
      expect(
        overflowErrors,
        isEmpty,
        reason:
            'App_Bar_Header overflowed at $where:\n'
            '${overflowErrors.isEmpty ? '' : overflowErrors.first}',
      );

      // The header's title must be present and pushed below the safe-area inset.
      final titleFinder = find.text(_kTitle);
      expect(
        titleFinder,
        findsOneWidget,
        reason: 'App_Bar_Header title must be rendered at $where',
      );

      final titleTop = tester.getRect(titleFinder).top;
      expect(
        titleTop,
        greaterThanOrEqualTo(inset),
        reason:
            'App_Bar_Header title top ($titleTop) must be >= the top '
            'safe-area inset ($inset) so it never collides with the status '
            'bar / notch — at $where',
      );
    }
  }
}

void main() {
  // A representative seeded sweep: 5 pinned insets (incl. 0 and a large notch)
  // plus 20 generated insets, each exercised across the full required matrix.
  final insets = _sampleInsets(20);

  group('Feature: mobile-text-scale-responsive-hardening, Property 10: App-bar '
      'header respects safe-area insets', () {
    for (var i = 0; i < insets.length; i++) {
      final inset = insets[i];
      testWidgets(
        'Property 10 [#$i inset=$inset]: header title top >= inset across '
        'the required viewport x scale matrix',
        (WidgetTester tester) async {
          await _assertHeaderRespectsInset(tester, inset);
        },
      );
    }

    // Explicit example: a tall notch must push the header strictly below the
    // inset at the smallest viewport and the above-cap scale (which the real
    // pipeline clamps to 1.3).
    testWidgets(
      'Property 10: a 60px notch pushes the header below the inset at '
      '360x640 @ above-cap scale',
      (WidgetTester tester) async {
        const inset = 60.0;
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(360, 640);
        addTearDown(() => tester.view.resetPhysicalSize());
        addTearDown(() => tester.view.resetDevicePixelRatio());

        await tester.pumpWidget(
          _wrapWithInset(
            const DesktopContentContainer(
              title: _kTitle,
              subtitle: _kSubtitle,
              showScrollbar: false,
              child: SizedBox(height: 200),
            ),
            requestedScale: kAboveCapScale,
            topInset: inset,
          ),
        );
        await tester.pump();

        final titleTop = tester.getRect(find.text(_kTitle)).top;
        expect(titleTop, greaterThanOrEqualTo(inset));
      },
    );
  });
}
