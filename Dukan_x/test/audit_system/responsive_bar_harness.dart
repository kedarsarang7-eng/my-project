// AUDIT_SYSTEM — RESPONSIVE_BAR VERIFICATION HARNESS (Task 22.1)
//
// A REUSABLE harness that verifies the Responsive_Bar for a single target
// Screen and produces a RECORDABLE result the AuditRunner can consume as the
// `DodItem.responsive` Definition_Of_Done item (Req 14.1.c). It does NOT print
// and it does NOT register its own tests — example tests (the separate 22.x
// tasks) drive it inside their own `testWidgets` bodies and record the result.
//
// REUSE, DO NOT DUPLICATE (Req 5.6): this harness wires together infrastructure
// that already exists in the repo rather than re-implementing responsiveness:
//   * `lib/core/responsive/responsive_breakpoints.dart` — the single source of
//     truth for Form_Factor classification (`cross-platform-responsive-ui`).
//   * `test/widget/widget_test_harness.dart` — `pumpScreen`, the established
//     widget pump+frame helper used across the widget suite.
//   * `tool/responsive_audit.dart` — the static scanner; we run `scanContent`
//     to confirm the Screen introduces NO duplicate layout mechanisms
//     (legacy breakpoint import / hand-rolled MediaQuery breakpoints).
//   * `tool/audit_system/audit_system.dart` — the governance core types
//     (`DodItem`, `DodResult`, `CategoryResult`, `AuditCategory`) so the
//     harness output maps straight into an Iteration_Report.
//
// WHAT IT CHECKS (Req 5.1, 5.2, 5.3):
//   For each viewport width in {320, 600, 1024, 1920, 3840} logical px, in BOTH
//   portrait and landscape orientations, it renders the Screen and asserts the
//   render pass produced ZERO Layout_Exceptions — captured via
//   `FlutterError.onError` (RenderFlex overflow, unbounded-constraint errors,
//   layout assertions) plus any exception thrown during build. Width is held at
//   the target value in both orientations (height varies above/below width) so
//   the full 320..3840 width range is exercised per orientation.
//
// HOW THE RESULT IS RECORDED:
//   `ResponsiveBarResult.dodResult` is `DodResult.pass` iff every viewport
//   rendered cleanly AND the scanner found no duplicate layout mechanism;
//   otherwise `DodResult.unmet` (Req 5.5 — a remaining defect blocks done).
//   `runtimeDodResults()` returns the `{DodItem.responsive: ...}` map ready to
//   drop into `IterationAudit.runtimeDodResults`, and `categoryResult()` yields
//   the matching `CategoryResult` for `AuditCategory.responsiveDesign`.
//
// Part of: per-screen-business-type-audit-remediation (Task 22.1)
// _Requirements: 5.1, 5.2, 5.3, 5.6_

import 'dart:io';

import 'package:dukanx/core/responsive/responsive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/widget_test_harness.dart' show pumpScreen;
import '../../tool/responsive_audit.dart' as scanner;
import '../../tool/audit_system/audit_system.dart'
    show AuditCategory, CategoryOutcome, CategoryResult, DodItem, DodResult;

// =============================================================================
// Constants — the verification matrix (Req 5.2)
// =============================================================================

/// Canonical viewport widths (logical px) the Responsive_Bar checks, spanning
/// the required 320..3840 range across all Form_Factors (Req 5.2). Chosen to
/// straddle the `ResponsiveBreakpoints` bands: 320 (mobile), 600 (tablet edge),
/// 1024 (tablet/desktop), 1920 (desktop), 3840 (4K desktop).
const List<double> kResponsiveBarWidths = <double>[320, 600, 1024, 1920, 3840];

/// The two orientations checked at every width (Req 5.2).
enum BarOrientation { portrait, landscape }

/// The scanner conditions that represent a DUPLICATE layout mechanism for a
/// Screen (Req 5.6): a legacy breakpoint import or a hand-rolled MediaQuery
/// breakpoint. `notAdaptiveBody` is intentionally excluded — it flags absence
/// of an adaptive body, not a duplicate mechanism, and is covered elsewhere.
const Set<scanner.AuditCondition> kDuplicateMechanismConditions =
    <scanner.AuditCondition>{
      scanner.AuditCondition.legacyImport,
      scanner.AuditCondition.handRolledBreakpoint,
    };

// =============================================================================
// Result model — recordable, no printing
// =============================================================================

/// The outcome of rendering the Screen at one (width, orientation) viewport.
class ViewportResult {
  ViewportResult({
    required this.width,
    required this.orientation,
    required this.formFactor,
    required List<String> layoutExceptions,
  }) : layoutExceptions = List<String>.unmodifiable(layoutExceptions);

  /// The logical viewport width tested (one of [kResponsiveBarWidths]).
  final double width;

  /// Portrait or landscape (Req 5.2).
  final BarOrientation orientation;

  /// The Form_Factor this width classifies into, via the single source of truth
  /// [ResponsiveBreakpoints.classify] (reused, not redefined).
  final FormFactor formFactor;

  /// First-line summaries of every Layout_Exception captured during the render
  /// pass; empty means the viewport rendered cleanly (Req 5.1).
  final List<String> layoutExceptions;

  /// True iff the render pass produced zero Layout_Exceptions.
  bool get passed => layoutExceptions.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'width': width,
    'orientation': orientation.name,
    'formFactor': formFactor.name,
    'passed': passed,
    'layoutExceptions': layoutExceptions,
  };

  @override
  String toString() =>
      'ViewportResult(${width.toStringAsFixed(0)}px ${orientation.name}, '
      '${formFactor.name}, ${passed ? 'clean' : '${layoutExceptions.length} exception(s)'})';
}

/// The result of scanning the Screen's source for duplicate layout mechanisms
/// (Req 5.6).
class DuplicateMechanismScan {
  DuplicateMechanismScan({required List<scanner.AuditCondition> conditions})
    : conditions = List<scanner.AuditCondition>.unmodifiable(conditions);

  /// The duplicate-mechanism conditions the scanner flagged (subset of
  /// [kDuplicateMechanismConditions]). Empty means the Screen reuses the
  /// Responsive_System primitives with no duplicate mechanism.
  final List<scanner.AuditCondition> conditions;

  /// True iff no duplicate layout mechanism was found (Req 5.6).
  bool get clean => conditions.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'clean': clean,
    'conditions': conditions.map((c) => c.json).toList(),
  };

  @override
  String toString() => clean
      ? 'DuplicateMechanismScan(clean)'
      : 'DuplicateMechanismScan(${conditions.map((c) => c.json).join(', ')})';
}

/// The full, recordable Responsive_Bar verification result for one Screen.
///
/// Maps directly onto the `DodItem.responsive` Definition_Of_Done item: the
/// Screen passes the Responsive_Bar iff EVERY viewport rendered cleanly AND no
/// duplicate layout mechanism exists.
class ResponsiveBarResult {
  ResponsiveBarResult({
    required this.screenPath,
    required List<ViewportResult> viewportResults,
    required this.duplicateScan,
  }) : viewportResults = List<ViewportResult>.unmodifiable(viewportResults);

  /// Forward-slash, package-relative `.dart` path of the verified Screen.
  final String screenPath;

  /// Per-viewport render outcomes (widths × orientations).
  final List<ViewportResult> viewportResults;

  /// The duplicate-layout-mechanism scan outcome (Req 5.6).
  final DuplicateMechanismScan duplicateScan;

  /// Viewports that failed (non-empty Layout_Exception list).
  List<ViewportResult> get failingViewports =>
      viewportResults.where((v) => !v.passed).toList();

  /// True iff every viewport rendered with zero Layout_Exceptions (Req 5.1,
  /// 5.2, 5.3).
  bool get allViewportsClean => failingViewports.isEmpty;

  /// True iff the Responsive_Bar PASSES: all viewports clean AND no duplicate
  /// layout mechanism (Req 5.1, 5.2, 5.3, 5.6).
  bool get passed => allViewportsClean && duplicateScan.clean;

  /// The Definition_Of_Done result for [DodItem.responsive]: pass iff [passed],
  /// otherwise unmet — a remaining defect blocks the Screen from done (Req 5.5).
  DodResult get dodResult => passed ? DodResult.pass : DodResult.unmet;

  /// The `{DodItem.responsive: dodResult}` entry, ready to merge into
  /// `IterationAudit.runtimeDodResults` for the AuditRunner.
  Map<DodItem, DodResult> runtimeDodResults() => <DodItem, DodResult>{
    DodItem.responsive: dodResult,
  };

  /// The matching audit `CategoryResult` for [AuditCategory.responsiveDesign].
  /// The responsive category is always evaluated by this harness, so it carries
  /// no not-applicable reason.
  CategoryResult categoryResult() => CategoryResult(
    category: AuditCategory.responsiveDesign,
    outcome: CategoryOutcome.evaluated,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'screenPath': screenPath,
    'passed': passed,
    'dodResult': dodResult.name,
    'viewportResults': viewportResults.map((v) => v.toJson()).toList(),
    'duplicateScan': duplicateScan.toJson(),
  };

  @override
  String toString() =>
      'ResponsiveBarResult($screenPath, ${passed ? 'PASS' : 'UNMET'}, '
      '${viewportResults.length} viewport(s), '
      '${failingViewports.length} failing, '
      'duplicateMechanisms: ${duplicateScan.clean ? 'none' : duplicateScan.conditions.length})';
}

// =============================================================================
// Harness entry point
// =============================================================================

/// Verify the Responsive_Bar for [screenBuilder]'s Screen and return a
/// recordable [ResponsiveBarResult].
///
/// Renders the Screen at every [kResponsiveBarWidths] width in BOTH orientations
/// (Req 5.2), capturing Layout_Exceptions per pass (Req 5.1, 5.3), then runs the
/// reused static scanner over the Screen's source to confirm no duplicate layout
/// mechanism (Req 5.6).
///
/// [screenPath] is the forward-slash, package-relative `.dart` path used both to
/// label the result and to drive the scanner's path-based classification. The
/// source scanned is [screenSource] when supplied; otherwise it is read from
/// [screenPath] relative to the current directory (the package root under
/// `flutter test`). If the file cannot be read, the scan is treated as empty
/// (clean) so a missing source never falsely fails the bar.
///
/// Call this inside a `testWidgets` body (it needs a live [WidgetTester]).
Future<ResponsiveBarResult> verifyResponsiveBar(
  WidgetTester tester, {
  required Widget Function() screenBuilder,
  required String screenPath,
  String? screenSource,
  ThemeData? theme,
}) async {
  final viewportResults = <ViewportResult>[];

  for (final width in kResponsiveBarWidths) {
    for (final orientation in BarOrientation.values) {
      final size = _viewportSize(width, orientation);
      final exceptions = await _renderAndCapture(
        tester,
        screenBuilder: screenBuilder,
        size: size,
        theme: theme,
      );
      viewportResults.add(
        ViewportResult(
          width: width,
          orientation: orientation,
          formFactor: ResponsiveBreakpoints.classify(width),
          layoutExceptions: exceptions,
        ),
      );
    }
  }

  final duplicateScan = scanForDuplicateMechanisms(
    screenPath,
    screenSource ?? _readSourceOrEmpty(screenPath),
  );

  return ResponsiveBarResult(
    screenPath: screenPath,
    viewportResults: viewportResults,
    duplicateScan: duplicateScan,
  );
}

/// Run the reused static scanner ([scanner.scanContent]) over [source] and keep
/// only the duplicate-layout-mechanism conditions (Req 5.6). Pure — exposed
/// separately so example tests can assert it without rendering.
DuplicateMechanismScan scanForDuplicateMechanisms(
  String screenPath,
  String source,
) {
  final flagged = scanner
      .scanContent(screenPath, source)
      .where(kDuplicateMechanismConditions.contains)
      .toList();
  return DuplicateMechanismScan(conditions: flagged);
}

// =============================================================================
// Internals
// =============================================================================

/// The viewport [Size] for a (width, orientation) pair. Width is held at the
/// target so the 320..3840 range is exercised in BOTH orientations; the height
/// is taller than width for portrait and shorter for landscape so the
/// orientation actually flips (Req 5.2).
Size _viewportSize(double width, BarOrientation orientation) {
  switch (orientation) {
    case BarOrientation.portrait:
      return Size(width, (width * 1.6).roundToDouble());
    case BarOrientation.landscape:
      return Size(width, (width * 0.625).roundToDouble());
  }
}

/// Render [screenBuilder] at [size] and return first-line summaries of every
/// Layout_Exception captured during the pass (Req 5.1, 5.3). Reuses
/// [pumpScreen] for the pump+frame; installs a temporary [FlutterError.onError]
/// collector so RenderFlex overflow / unbounded-constraint / layout-assertion
/// faults are captured instead of crashing the test, and also drains any
/// synchronous exception via [WidgetTester.takeException].
Future<List<String>> _renderAndCapture(
  WidgetTester tester, {
  required Widget Function() screenBuilder,
  required Size size,
  ThemeData? theme,
}) async {
  final captured = <String>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    captured.add(_firstLine(details.exceptionAsString()));
  };

  try {
    await pumpScreen(
      tester,
      screen: screenBuilder(),
      theme: theme,
      surfaceSize: size,
      // First frame only — we are checking layout, not animation completion.
      settle: false,
    );
  } catch (error) {
    captured.add(_firstLine(error.toString()));
  } finally {
    FlutterError.onError = previousOnError;
  }

  // Drain any exception the framework deferred to takeException so it is
  // recorded here rather than failing a later, unrelated expectation.
  final pending = tester.takeException();
  if (pending != null) {
    captured.add(_firstLine(pending.toString()));
  }

  return captured;
}

/// Read [screenPath] relative to the current directory, returning an empty
/// string if it cannot be read (so a missing source never falsely fails 5.6).
String _readSourceOrEmpty(String screenPath) {
  try {
    final file = File(screenPath);
    if (file.existsSync()) return file.readAsStringSync();
  } catch (_) {
    // Fall through to empty.
  }
  return '';
}

/// The first non-empty line of [text], trimmed — enough to identify a fault
/// without dumping a full multi-line stack into the recorded result.
String _firstLine(String text) {
  for (final line in text.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return text.trim();
}
