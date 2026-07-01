// ============================================================================
// RESPONSIVE TEST HARNESS — Task 2.1
// Feature: mobile-text-scale-responsive-hardening
// ============================================================================
// The shared regression gate that the prior responsive specs lacked. It pumps
// any widget/screen across the required (Mobile_Viewport x Elevated_Text_Scale)
// matrix, fails on RenderFlex overflow (naming the offending viewport+scale),
// and fails if a test does not exercise the full required matrix (totality).
//
// Every target is rendered through the app's REAL single text-scale pipeline
// (`applyTextScaleClamp` from package:dukanx/app/app.dart, forced non-Windows)
// so tests render exactly as production would on Android — including that an
// Above_Cap_Scale request is capped at kMaxTextScaleFactor (1.3).
//
// The FlutterError.onError overflow-capture pattern is reused from
// test/widget/widget_test_harness.dart.
//
// Requirements: 10.1, 10.2, 10.3, 10.4, 10.6
// ============================================================================

import 'package:dukanx/app/app.dart' show applyTextScaleClamp;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Required matrix constants (defined once, R10.2 / R10.3) ────────────────

/// The required Mobile_Viewport set — common Android phone logical sizes.
/// Defined once here so individual tests can never under-specify it (R10.3).
const List<Size> kRequiredViewports = <Size>[
  Size(360, 640),
  Size(393, 851),
  Size(412, 915),
];

/// Baseline (default) text scale.
const double kBaselineScale = 1.0;

/// At-cap text scale — equals `kMaxTextScaleFactor`.
const double kCapScale = 1.3;

/// An Above_Cap_Scale — a requested factor strictly greater than the cap, used
/// to prove the clamp holds (the pipeline must collapse this to the cap on
/// non-Windows platforms).
const double kAboveCapScale = 2.6;

/// The required Elevated_Text_Scale set: baseline, at-cap, and above-cap (R10.2).
const List<double> kRequiredScales = <double>[
  kBaselineScale,
  kCapScale,
  kAboveCapScale,
];

/// The five explicitly named hardening cases (R10.5). A harness suite must
/// register all of these; `assertCasesCovered` enforces it.
const Set<String> kRequiredCases = <String>{
  'Totals_Card',
  'PO_Info_Banner',
  'GST_Reports_Screen',
  'App_Bar_Header',
  'Process Return search',
};

// ─── Pair / matrix helpers ──────────────────────────────────────────────────

/// A canonical, comparable key for a single (viewport, scale) pair so the set
/// of exercised pairs can be compared against the required matrix.
String responsiveMatrixKey(Size viewport, double scale) =>
    '${viewport.width.toStringAsFixed(1)}x'
    '${viewport.height.toStringAsFixed(1)}@'
    '${scale.toStringAsFixed(4)}';

/// The full required matrix as a set of pair keys (viewports x scales). Built
/// from the canonical constants so totality checks are anchored to the spec,
/// not to whatever subset a caller happened to pass.
Set<String> requiredMatrixKeys({
  List<Size> viewports = kRequiredViewports,
  List<double> scales = kRequiredScales,
}) {
  final keys = <String>{};
  for (final v in viewports) {
    for (final s in scales) {
      keys.add(responsiveMatrixKey(v, s));
    }
  }
  return keys;
}

/// Returns the required matrix pairs that are NOT present in [exercised] — the
/// totality gap. An empty result means [exercised] covers the full required
/// matrix; a non-empty result means coverage is incomplete, so a hardening test
/// driven through [pumpResponsiveMatrix] must fail (R10.6 / Property 12).
///
/// This is the single pure set-logic helper that BOTH the harness and its
/// property test consume, so the test validates exactly the totality rule the
/// harness enforces at runtime.
Set<String> missingMatrixPairs(
  Set<String> exercised, {
  List<Size> viewports = kRequiredViewports,
  List<double> scales = kRequiredScales,
}) => requiredMatrixKeys(
  viewports: viewports,
  scales: scales,
).difference(exercised);

// ─── wrapWithPipeline ───────────────────────────────────────────────────────

/// Wraps [child] in a [MaterialApp] and applies the app's REAL single
/// text-scale pipeline so the widget renders exactly as production would.
///
/// The [requestedScale] is injected into the [MediaQuery] (mirroring a system /
/// app font-size request) and then routed through `applyTextScaleClamp` with
/// `isWindowsOverride: false`, so above-cap requests are capped at
/// `kMaxTextScaleFactor` just like on a real Android device.
///
/// A [Scaffold] is provided so primitives (which need a [Material] ancestor)
/// render without extra boilerplate, matching `widget_test_harness.dart`.
Widget wrapWithPipeline(
  Widget child, {
  required double requestedScale,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? ThemeData.light(useMaterial3: true),
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: child),
    builder: (context, widget) {
      // Inject the requested scale, then run the production clamp on top of it
      // so the effective TextScaler reaching the tree is exactly what the app
      // would apply on a non-Windows platform.
      final injected = MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(requestedScale));
      final clamped = applyTextScaleClamp(injected, isWindowsOverride: false);
      return MediaQuery(data: clamped, child: widget!);
    },
  );
}

// ─── pumpResponsiveMatrix ───────────────────────────────────────────────────

/// Pumps [builder] under every (viewport x scale) combination in the required
/// matrix.
///
/// For each pair this:
///   * sets `tester.view.physicalSize` / `devicePixelRatio` for the viewport,
///     registering `addTearDown` resets so state never leaks between tests;
///   * routes the requested scale through the real `applyTextScaleClamp`
///     (via [wrapWithPipeline], `isWindowsOverride: false`);
///   * installs a scoped `FlutterError.onError` handler that captures overflow
///     (messages containing `overflowed`), always restored in a `finally`;
///   * fails immediately — naming the offending viewport + scale — on overflow
///     (R10.4).
///
/// After exercising every pair it asserts that the set of pairs actually pumped
/// equals the full required matrix (`kRequiredViewports` x `kRequiredScales`),
/// so a test that omits any required pair fails the coverage check (totality,
/// R10.6 / Property 12).
Future<void> pumpResponsiveMatrix(
  WidgetTester tester, {
  required Widget Function() builder,
  List<Size> viewports = kRequiredViewports,
  List<double> scales = kRequiredScales,
  ThemeData? theme,
}) async {
  final exercised = <String>{};

  // Reset view state after the test regardless of how it ends.
  addTearDown(() => tester.view.resetPhysicalSize());
  addTearDown(() => tester.view.resetDevicePixelRatio());

  for (final viewport in viewports) {
    for (final scale in scales) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = viewport;

      final errors = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      try {
        await tester.pumpWidget(
          wrapWithPipeline(builder(), requestedScale: scale, theme: theme),
        );
        // Force a layout/paint pass so overflow is reported, without
        // pumpAndSettle (which would time out on infinite animations).
        await tester.pump();
      } finally {
        FlutterError.onError = oldHandler;
      }

      exercised.add(responsiveMatrixKey(viewport, scale));

      final overflowErrors = errors
          .where((e) => e.toString().contains('overflowed'))
          .toList();
      if (overflowErrors.isNotEmpty) {
        fail(
          'Overflow_Failure at viewport '
          '${viewport.width.toStringAsFixed(0)}x'
          '${viewport.height.toStringAsFixed(0)}, '
          'requested scale $scale:\n${overflowErrors.first}',
        );
      }

      // Surface any non-overflow build/layout exceptions so genuine errors are
      // not silently swallowed by the scoped handler.
      final otherErrors = errors
          .where((e) => !e.toString().contains('overflowed'))
          .toList();
      if (otherErrors.isNotEmpty) {
        fail(
          'Unexpected error at viewport '
          '${viewport.width.toStringAsFixed(0)}x'
          '${viewport.height.toStringAsFixed(0)}, '
          'requested scale $scale:\n${otherErrors.first}',
        );
      }
    }
  }

  // Totality (R10.6): the exercised pair-set must equal the full required
  // matrix. A subset (a test that omits any required viewport/scale) fails.
  final missing = missingMatrixPairs(exercised);
  expect(
    missing,
    isEmpty,
    reason:
        'Responsive matrix incomplete — these required (viewport@scale) pairs '
        'were not exercised: ${missing.toList()..sort()}. The harness must '
        'cover viewports $kRequiredViewports x scales $kRequiredScales.',
  );
}

// ─── assertCasesCovered ─────────────────────────────────────────────────────

/// Asserts that every case in [requiredCases] is present in [registeredCases]
/// (R10.5). Used by the harness suite to guarantee the five explicitly named
/// cases — Totals_Card, PO_Info_Banner, GST_Reports_Screen, App_Bar_Header,
/// and Process Return search — are all registered; any missing case fails the
/// suite.
void assertCasesCovered(
  Set<String> requiredCases,
  Set<String> registeredCases,
) {
  final missing = requiredCases.difference(registeredCases);
  expect(
    missing,
    isEmpty,
    reason:
        'Required hardening cases not covered: ${missing.toList()..sort()}. '
        'Registered cases: ${registeredCases.toList()..sort()}.',
  );
}
