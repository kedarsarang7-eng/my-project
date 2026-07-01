// AUDIT_SYSTEM — FINAL-VALIDATION-CHECKLIST EVALUATOR (Task 20.1)
//
// The Final_Validation_Checklist is the cross-cutting gate evaluated once EVERY
// Screen of EVERY non-template Business_Type has been remediated and recorded
// `done` (Req 16.1). It aggregates the per-item Definition_Of_Done results that
// each Iteration_Report already carries and decides whether platform-wide
// readiness can be confirmed.
//
// Confirmation is all-or-nothing (Req 16.2–16.7, Property 47):
//   * Platform readiness is confirmed IFF every checklist item has a recorded
//     `pass`/`not-applicable` for EVERY remediated Screen AND every identified
//     Gap is resolved (zero placeholder/mock/stub/TODO Gaps remain, Req 16.2).
//   * If ANY item fails for ANY Screen, confirmation is withheld, each failing
//     item is recorded with the affected Screen and Business_Type, and a
//     dedicated remediation Iteration_Target is scheduled per affected Screen
//     (Req 16.7).
//
// The 10 Definition_Of_Done items (a..j) map one-to-one onto the checklist
// items named in Req 16.2–16.5 / Property 47:
//   gaps + categories  -> zero placeholder/mock/stub/TODO Gaps (Req 16.2)
//   responsive         -> Responsive_Bar on each platform/orientation (Req 16.3)
//   parity             -> online/offline parity (Req 16.4)
//   licenseActivation  -> license-gated offline activation (Req 16.4)
//   syncConflict       -> synchronization conflict safety (Req 16.4)
//   gating             -> subscription gating + RBAC (Req 16.5)
//   backend            -> backend integration (Req 16.5)
//   securityValidation -> security + input validation (Req 16.5)
//   navigation         -> navigation / deep links / back nav / transitions
//
// Guard (Req 16.1): the evaluator is intended to run only when
// `CompletedRegistry.allDone` is true. It does not trust that precondition
// blindly — it independently verifies that the supplied Iteration_Reports cover
// every Screen in the universe. Any universe Screen with no report is treated
// as not-yet-remediated: confirmation is withheld and a remediation target is
// scheduled for it.
//
// This file is PURE, dependency-light Dart (only `dart:core` plus the
// Audit_System core models), so it imports cleanly into `flutter_test` +
// `dartproptest` VM suites, mirroring the rest of the governance core.
//
// Part of: per-screen-business-type-audit-remediation (Task 20.1)
// _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5, 16.6, 16.7_

import 'definition_of_done.dart' show DodItem, DodResult, DefinitionOfDone;
import 'gap_registry.dart' show GapStatus;
import 'iteration_report.dart' show IterationReport;
import 'types.dart' show IterationTarget, ScreenRef, ScreenUniverse;

/// A single Final_Validation_Checklist failure: a checklist item that did not
/// pass for a specific remediated Screen (Req 16.7).
///
/// [failedItem] identifies which checklist item failed, or is `null` when the
/// failure is that the Screen has no Iteration_Report at all — i.e. it was
/// never remediated even though the evaluator was invoked (the Req 16.1 guard).
class ChecklistFailure implements Comparable<ChecklistFailure> {
  ChecklistFailure({
    required this.businessType,
    required this.screenPath,
    required this.failedItem,
  });

  /// Module folder under `lib/modules/`, never `_template` (Req 16.7).
  final String businessType;

  /// Forward-slash, package-relative `.dart` path of the affected Screen.
  final String screenPath;

  /// The checklist item that failed, or `null` when no Iteration_Report exists
  /// for this Screen (the Screen was not remediated; Req 16.1 guard).
  final DodItem? failedItem;

  /// The (Business_Type, Screen) pair this failure affects.
  ScreenRef get screenRef =>
      ScreenRef(businessType: businessType, screenPath: screenPath);

  @override
  bool operator ==(Object other) =>
      other is ChecklistFailure &&
      other.businessType == businessType &&
      other.screenPath == screenPath &&
      other.failedItem == failedItem;

  @override
  int get hashCode => Object.hash(businessType, screenPath, failedItem);

  @override
  int compareTo(ChecklistFailure other) {
    final byType = businessType.compareTo(other.businessType);
    if (byType != 0) return byType;
    final byPath = screenPath.compareTo(other.screenPath);
    if (byPath != 0) return byPath;
    // Order missing-report failures (null item) ahead of item failures, then by
    // canonical DodItem order so the output is stable and diff-friendly.
    final a = failedItem?.index ?? -1;
    final b = other.failedItem?.index ?? -1;
    return a.compareTo(b);
  }

  @override
  String toString() {
    final item = failedItem == null
        ? 'no Iteration_Report (not remediated)'
        : failedItem!.name;
    return 'ChecklistFailure($businessType, $screenPath, $item)';
  }
}

/// The outcome of evaluating the Final_Validation_Checklist (Req 16.6, 16.7).
///
/// When [confirmed] is true, every checklist item passed for every remediated
/// Screen and the universe was fully covered — platform-wide readiness is
/// confirmed and [failures]/[scheduledRemediationTargets] are empty (Req 16.6).
///
/// When [confirmed] is false, [failures] lists every failing (Screen, item)
/// pair (Req 16.7) and [scheduledRemediationTargets] holds exactly one
/// remediation [IterationTarget] per affected Screen, de-duplicated and sorted.
class FinalValidationResult {
  FinalValidationResult({
    required this.confirmed,
    required List<ChecklistFailure> failures,
    required List<IterationTarget> scheduledRemediationTargets,
  }) : failures = List<ChecklistFailure>.unmodifiable(failures),
       scheduledRemediationTargets = List<IterationTarget>.unmodifiable(
         scheduledRemediationTargets,
       );

  /// True iff platform-wide readiness is confirmed (Req 16.6). Always false
  /// when [failures] is non-empty.
  final bool confirmed;

  /// Every failing checklist item with its affected Screen/Business_Type,
  /// sorted; empty when [confirmed] (Req 16.7).
  final List<ChecklistFailure> failures;

  /// One remediation [IterationTarget] per affected Screen, de-duplicated and
  /// sorted; empty when [confirmed] (Req 16.7).
  final List<IterationTarget> scheduledRemediationTargets;

  @override
  String toString() => confirmed
      ? 'FinalValidationResult(confirmed)'
      : 'FinalValidationResult(withheld, ${failures.length} failure(s), '
            '${scheduledRemediationTargets.length} target(s) scheduled)';
}

/// Evaluates the Final_Validation_Checklist across all Iteration_Reports.
///
/// Pure governance logic with no I/O and no shared mutable state, so it imports
/// cleanly into property and unit tests.
class FinalChecklistEvaluator {
  const FinalChecklistEvaluator();

  static const DefinitionOfDone _dod = DefinitionOfDone();

  /// Evaluate platform-wide readiness from [allReports] against [universe].
  ///
  /// Intended to run only once every Screen is recorded `done`
  /// (`CompletedRegistry.allDone`, Req 16.1); the evaluator additionally
  /// verifies that [allReports] cover every Screen in [universe] and treats any
  /// uncovered Screen as not-yet-remediated.
  ///
  /// Readiness is confirmed IFF every checklist item passes for every
  /// remediated Screen and the universe is fully covered (Req 16.6); otherwise
  /// confirmation is withheld, each failing item is recorded with its affected
  /// Screen/Business_Type, and one remediation [IterationTarget] is scheduled
  /// per affected Screen (Req 16.7).
  FinalValidationResult evaluate(
    List<IterationReport> allReports,
    ScreenUniverse universe,
  ) {
    // Keep the latest Iteration_Report per (Business_Type, Screen): a later
    // report supersedes an earlier one for the same Screen (reopen + redo).
    final latest = <ScreenRef, IterationReport>{};
    for (final report in allReports) {
      latest[ScreenRef(
            businessType: report.businessType,
            screenPath: report.screenPath,
          )] =
          report;
    }

    final failures = <ChecklistFailure>[];
    // Affected Screens collected as a set so each is scheduled at most once.
    final affected = <ScreenRef>{};

    // Req 16.1 guard: every Screen in the universe MUST have an Iteration_Report
    // (be remediated). A Screen with no report is not done — withhold and
    // schedule it.
    for (final screen in universe.allScreens) {
      if (!latest.containsKey(screen)) {
        failures.add(
          ChecklistFailure(
            businessType: screen.businessType,
            screenPath: screen.screenPath,
            failedItem: null,
          ),
        );
        affected.add(screen);
      }
    }

    // Req 16.2–16.5: every checklist item must pass for every remediated Screen.
    for (final entry in latest.entries) {
      final screen = entry.key;
      final report = entry.value;

      for (final item in _failingItems(report)) {
        failures.add(
          ChecklistFailure(
            businessType: screen.businessType,
            screenPath: screen.screenPath,
            failedItem: item,
          ),
        );
        affected.add(screen);
      }
    }

    failures.sort();

    final targets =
        affected
            .map(
              (s) => IterationTarget(
                businessType: s.businessType,
                screenPath: s.screenPath,
              ),
            )
            .toList()
          ..sort();

    // Req 16.6: confirmed IFF nothing failed (which also implies full coverage).
    return FinalValidationResult(
      confirmed: failures.isEmpty,
      failures: failures,
      scheduledRemediationTargets: targets,
    );
  }

  /// The checklist items that fail for a single remediated Screen's [report].
  ///
  /// Returns items in canonical [DodItem] order. An item fails when its recorded
  /// Definition_Of_Done result is anything other than `pass`/`not-applicable`
  /// (Req 16.3–16.5). Additionally — independent of the recorded `gaps` result
  /// — if any identified Gap is not `resolved`, the `gaps` item fails so that
  /// "zero placeholder/mock/stub/TODO Gaps remain" is enforced from the actual
  /// Gap evidence (Req 16.2).
  List<DodItem> _failingItems(IterationReport report) {
    // Reduce the per-item DodResultRecord map to a plain DodItem -> DodResult
    // map so the shared Definition_Of_Done classifier can be reused verbatim.
    final recorded = <DodItem, DodResult>{
      for (final e in report.dodResults.entries) e.key: e.value.result,
    };

    final blocking = <DodItem>{..._dod.classify(recorded).blockingItems};

    // Cross-check the actual Gaps: any unresolved/open Gap fails item (b),
    // evidencing that no placeholder/mock/stub/TODO work remains (Req 16.2).
    final allGapsResolved = report.gaps.every(
      (g) => g.status == GapStatus.resolved,
    );
    if (!allGapsResolved) {
      blocking.add(DodItem.gaps);
    }

    // Emit in canonical DodItem order for stable, diff-friendly output.
    return DodItem.values.where(blocking.contains).toList(growable: false);
  }
}
