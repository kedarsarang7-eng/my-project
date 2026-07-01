// AUDIT_SYSTEM — FIX-VERIFY CONTROLLER (Task 8.1)
//
// The Fix-Verify Controller drives the bounded Fix→Verify loop for a single
// Screen. After the Audit phase produces a list of Gaps, the controller applies
// fixes and re-verifies, repeating up to a maximum of 3 cycles (Req 2.5). It
// stops early the moment every Gap is resolved. If any Gap is still failing
// after the 3rd cycle, that Gap is recorded as `unresolved`, the Screen is
// marked not done, and advancement to the next Iteration_Target is blocked
// (Req 2.7, 4.6).
//
// This file is PURE, dependency-light Dart (only `dart:core` + the Gap model),
// so it imports cleanly into `flutter_test` + `dartproptest` VM suites, mirroring
// the rest of the Audit_System core. It performs NO I/O and applies NO fixes
// itself — the act of fixing + verifying is supplied by the caller as a
// [VerifyFn], keeping this controller a pure, testable decision engine.
//
// Part of: per-screen-business-type-audit-remediation (Task 8.1)
// _Requirements: 2.5, 2.7, 4.6_

import 'gap_registry.dart' show Gap, GapStatus;

/// The fix-and-verify callback the controller invokes once per cycle.
///
/// On each cycle the controller hands the verifier the Gaps that are still
/// outstanding (those not yet resolved) along with the 1-based [cycle] number.
/// The caller applies its fixes for that cycle and then verifies, returning the
/// subset of those Gaps that REMAIN unresolved. An empty return means every
/// outstanding Gap was resolved this cycle and the loop can stop early (Req 2.5).
///
/// The returned list is interpreted by Gap [Gap.id]; only Gaps whose id is
/// present in the input [outstanding] list are considered.
typedef VerifyFn = List<Gap> Function(List<Gap> outstanding, int cycle);

/// The result of running the bounded Fix-Verify loop for a single Screen.
///
/// Exposes whether every Gap was resolved ([allResolved]), how many cycles were
/// actually used ([cyclesUsed], 0 when there were no Gaps to begin with), the
/// final Gap list with each Gap's terminal status applied ([finalGaps]), and
/// whether advancement to the next Iteration_Target must be blocked
/// ([advancementBlocked]) because at least one Gap is unresolved (Req 2.7, 4.6).
class FixVerifyOutcome {
  FixVerifyOutcome._({
    required this.allResolved,
    required this.cyclesUsed,
    required List<Gap> finalGaps,
    required this.advancementBlocked,
  }) : finalGaps = List<Gap>.unmodifiable(finalGaps);

  /// True iff every input Gap reached [GapStatus.resolved]. Trivially true when
  /// there were no Gaps to resolve.
  final bool allResolved;

  /// Number of Fix-Verify cycles actually executed (0..[FixVerifyController.maxCycles]).
  /// Zero when the input Gap list was empty.
  final int cyclesUsed;

  /// The input Gaps with their terminal status applied: [GapStatus.resolved]
  /// for fixed Gaps and [GapStatus.unresolved] for those still failing after
  /// the final cycle (Req 2.7). Order matches the input order. Unmodifiable.
  final List<Gap> finalGaps;

  /// True iff at least one Gap is unresolved, meaning the Screen is NOT done and
  /// the workflow must not advance to the next Iteration_Target (Req 2.7, 4.6).
  /// Always the logical inverse of [allResolved].
  final bool advancementBlocked;

  /// The unresolved Gaps from [finalGaps] (empty when [allResolved]).
  List<Gap> get unresolvedGaps =>
      finalGaps.where((g) => g.status == GapStatus.unresolved).toList();

  @override
  String toString() =>
      'FixVerifyOutcome(allResolved: $allResolved, cyclesUsed: $cyclesUsed, '
      'advancementBlocked: $advancementBlocked, gaps: ${finalGaps.length})';
}

/// Drives the bounded Fix→Verify loop for a single Screen (Req 2.5, 2.7, 4.6).
class FixVerifyController {
  /// The maximum number of Fix-Verify cycles before advancing (Req 2.5).
  static const int maxCycles = 3;

  /// Run fix→verify for [gaps], calling [verify] once per cycle, up to
  /// [maxCycles] times. Stops early as soon as no Gap remains unresolved.
  ///
  /// On completion every Gap is reported with its terminal status: resolved
  /// Gaps as [GapStatus.resolved] and any Gap still failing after the final
  /// cycle as [GapStatus.unresolved]. When any Gap is unresolved the returned
  /// [FixVerifyOutcome] marks advancement as blocked (Req 2.7, 4.6).
  FixVerifyOutcome run(List<Gap> gaps, VerifyFn verify) {
    // No Gaps to fix: trivially resolved, zero cycles, advancement allowed.
    if (gaps.isEmpty) {
      return FixVerifyOutcome._(
        allResolved: true,
        cyclesUsed: 0,
        finalGaps: const <Gap>[],
        advancementBlocked: false,
      );
    }

    // The Gaps still outstanding at the start of the current cycle. We begin
    // with all of them and narrow down to whatever the verifier still reports.
    var outstanding = List<Gap>.from(gaps);
    var cyclesUsed = 0;

    for (var cycle = 1; cycle <= maxCycles; cycle++) {
      cyclesUsed = cycle;

      // The caller applies its fixes for this cycle, then verifies, returning
      // the Gaps that REMAIN unresolved. Constrain the result to the Gaps we
      // actually handed in, matched by id, so a stray return can't widen scope.
      final outstandingIds = outstanding.map((g) => g.id).toSet();
      final stillFailing = verify(
        List<Gap>.unmodifiable(outstanding),
        cycle,
      ).where((g) => outstandingIds.contains(g.id)).toList();

      // Early stop: every outstanding Gap was resolved this cycle (Req 2.5).
      if (stillFailing.isEmpty) {
        outstanding = const <Gap>[];
        break;
      }

      outstanding = stillFailing;
    }

    // Anything still outstanding after the loop is permanently unresolved.
    final unresolvedIds = outstanding.map((g) => g.id).toSet();
    final allResolved = unresolvedIds.isEmpty;

    // Apply terminal statuses to the original Gaps, preserving input order.
    final finalGaps = gaps
        .map(
          (g) => _withStatus(
            g,
            unresolvedIds.contains(g.id)
                ? GapStatus.unresolved
                : GapStatus.resolved,
          ),
        )
        .toList();

    return FixVerifyOutcome._(
      allResolved: allResolved,
      cyclesUsed: cyclesUsed,
      finalGaps: finalGaps,
      // Block advancement whenever any Gap is unresolved (Req 2.7, 4.6).
      advancementBlocked: !allResolved,
    );
  }

  /// Build a copy of [gap] carrying [status]; all other fields are preserved.
  /// Gap is immutable and has no copyWith, so we reconstruct it here.
  static Gap _withStatus(Gap gap, GapStatus status) => Gap(
    id: gap.id,
    screenPath: gap.screenPath,
    businessType: gap.businessType,
    categories: gap.categories,
    status: status,
    description: gap.description,
    fileLocation: gap.fileLocation,
  );
}
