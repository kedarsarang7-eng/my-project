// AUDIT_SYSTEM — DEFINITION-OF-DONE EVALUATOR (Task 9.1)
//
// The Definition_Of_Done is the checklist every Screen SHALL satisfy before an
// Iteration advances. A Screen is classified `done` if and only if EVERY one of
// the 10 Definition_Of_Done items (a..j) has a recorded result of `pass` or
// `not-applicable` in the Iteration_Report (Req 14.1). If any item is `unmet`,
// `pending`, or `absent` — including an item entirely missing from the recorded
// map — the Screen is classified NOT done, advancement is blocked, and every
// offending item is listed so the engineer knows exactly what remains
// (Req 14.2).
//
// This file is PURE, dependency-light Dart (only `dart:core` plus the
// Audit_System core models), so it imports cleanly into `flutter_test` +
// `dartproptest` VM suites, mirroring the rest of the governance core.
//
// Part of: per-screen-business-type-audit-remediation (Task 9.1)
// _Requirements: 14.1, 14.2, 14.4_

import 'audit_categories.dart'
    show CategoryResult, AuditCategoryEvaluator, AuditPhaseStatus;
import 'gap_registry.dart' show Gap, GapStatus;

/// The 10 Definition_Of_Done items (a)..(j) from Req 14.1.
///
/// The membership and order of this enum is the single source of truth for the
/// completeness check in [DefinitionOfDone.classify]:
///   (a) [categories]          — every Audit_Category evaluated or not-applicable
///   (b) [gaps]                — every identified Gap resolved
///   (c) [responsive]          — Responsive_Bar passes on each Supported_Platform
///   (d) [navigation]          — navigation, deep links, back nav, transitions pass
///   (e) [parity]              — online/offline parity passes
///   (f) [licenseActivation]   — license-gated offline activation passes
///   (g) [syncConflict]        — synchronization and conflict safety pass
///   (h) [gating]              — subscription gating and RBAC gating pass
///   (i) [backend]             — backend integration passes
///   (j) [securityValidation]  — security and input validation pass
enum DodItem {
  categories,
  gaps,
  responsive,
  navigation,
  parity,
  licenseActivation,
  syncConflict,
  gating,
  backend,
  securityValidation,
}

/// The result recorded for a Definition_Of_Done item in the Iteration_Report.
///
/// An item counts as satisfied only when its result is [pass] or
/// [notApplicable]. The remaining values each block completion (Req 14.1):
///   * [unmet]   — the item was evaluated and failed.
///   * [pending] — the item is still awaiting a result.
///   * [absent]  — no result has been recorded for the item.
///
/// Note: an item entirely missing from a recorded map is treated exactly like
/// an explicit [absent] result by [DefinitionOfDone.classify].
enum DodResult { pass, notApplicable, unmet, pending, absent }

/// The classification of a Screen against the Definition_Of_Done.
///
/// [done] is true iff every one of the 10 [DodItem]s is satisfied. When [done]
/// is false, [blockingItems] lists every item whose recorded result is
/// `unmet`, `pending`, or `absent` (including items missing from the recorded
/// map), in canonical [DodItem] order (Req 14.2).
class DoneClassification {
  DoneClassification({required this.done, required List<DodItem> blockingItems})
    : blockingItems = List<DodItem>.unmodifiable(blockingItems);

  /// True iff all 10 Definition_Of_Done items are satisfied.
  final bool done;

  /// The unmet/pending/absent items blocking completion; empty when [done].
  final List<DodItem> blockingItems;

  @override
  String toString() => done
      ? 'DoneClassification(done)'
      : 'DoneClassification(not done, blocking: '
            '${blockingItems.map((i) => i.name).join(', ')})';
}

/// Evaluates the per-Screen Definition_Of_Done.
///
/// Pure governance logic with no I/O and no shared mutable state, so it imports
/// cleanly into property and unit tests.
class DefinitionOfDone {
  const DefinitionOfDone();

  /// Classify a Screen from its [recorded] Definition_Of_Done results.
  ///
  /// The Screen is `done` **iff** every one of the 10 [DodItem]s has a recorded
  /// result of [DodResult.pass] or [DodResult.notApplicable]. Any item that is
  /// [DodResult.unmet], [DodResult.pending], [DodResult.absent], or entirely
  /// missing from [recorded] blocks completion and is reported in
  /// [DoneClassification.blockingItems] in canonical [DodItem] order
  /// (Req 14.1, 14.2).
  DoneClassification classify(Map<DodItem, DodResult> recorded) {
    final blocking = <DodItem>[];
    for (final item in DodItem.values) {
      // A missing entry is treated exactly like an explicit `absent` result.
      final result = recorded[item] ?? DodResult.absent;
      if (!_isSatisfied(result)) {
        blocking.add(item);
      }
    }
    return DoneClassification(done: blocking.isEmpty, blockingItems: blocking);
  }

  /// Derive the results for items (a) [DodItem.categories] and (b)
  /// [DodItem.gaps] from the raw audit evidence.
  ///
  /// When a Screen has zero identified Gaps and every Audit_Category is recorded
  /// as evaluated or not-applicable, items (a) and (b) are treated as satisfied
  /// (pass) (Req 14.4). Otherwise each item carries the result that reflects its
  /// outstanding work so [classify] can surface it as a blocking item:
  ///   * (a) categories — [DodResult.pass] when all 13 categories are covered;
  ///     [DodResult.pending] while coverage is incomplete.
  ///   * (b) gaps — [DodResult.pass] when every Gap is resolved (or none exist);
  ///     [DodResult.unmet] when any Gap is unresolved; otherwise
  ///     [DodResult.pending] while Gaps remain open.
  Map<DodItem, DodResult> deriveAB(List<CategoryResult> cats, List<Gap> gaps) {
    return <DodItem, DodResult>{
      DodItem.categories: _categoriesResult(cats),
      DodItem.gaps: _gapsResult(gaps),
    };
  }

  /// Item (a): every Audit_Category recorded as evaluated or not-applicable.
  DodResult _categoriesResult(List<CategoryResult> cats) {
    final status = AuditCategoryEvaluator.phaseStatus(cats);
    return status == AuditPhaseStatus.complete
        ? DodResult.pass
        : DodResult.pending;
  }

  /// Item (b): every identified Gap recorded as resolved.
  DodResult _gapsResult(List<Gap> gaps) {
    // Zero identified Gaps satisfies item (b) outright (Req 14.4).
    if (gaps.isEmpty) return DodResult.pass;
    if (gaps.any((g) => g.status == GapStatus.unresolved)) {
      return DodResult.unmet;
    }
    if (gaps.every((g) => g.status == GapStatus.resolved)) {
      return DodResult.pass;
    }
    // Some Gaps are still open and awaiting a fix-verify outcome.
    return DodResult.pending;
  }

  /// An item is satisfied only by a pass or not-applicable result (Req 14.1).
  static bool _isSatisfied(DodResult result) =>
      result == DodResult.pass || result == DodResult.notApplicable;
}
