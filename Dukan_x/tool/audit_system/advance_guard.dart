// AUDIT_SYSTEM — ADVANCE GUARD (Task 12.1)
//
// The final gate of an Iteration. After Verify completes, the Advance Guard
// decides whether the loop may move on to the next Iteration_Target. It ties
// together three pieces of the governance core so the decision is enforced in
// one place:
//
//   * the Iteration State Machine status (`iteration_state_machine.dart`) —
//     advancement requires the current target's status to equal
//     `IterationStatus.done`;
//   * the Definition-of-Done classification (`definition_of_done.dart`) — the
//     Screen must be classified `done` (every Definition_Of_Done item satisfied),
//     otherwise the offending items are surfaced as the reason advancement is
//     blocked; and
//   * the Completed-Screens Registry + Target Selector (`completed_registry.dart`,
//     `target_selector.dart`) — once advancement is permitted, the next move is
//     computed from the registry and the enumerated universe.
//
// The contract (Property 5; Req 1.6, 1.7): advancement is permitted IF AND ONLY
// IF the current target's status equals `done` AND its Definition-of-Done
// classification is `done`. In every other case advancement is BLOCKED and the
// current Iteration_Target is retained as active so the engineer keeps working
// the same Screen until it genuinely meets the bar.
//
// Pure, dependency-light Dart (only `dart:core` plus Audit_System core models),
// so it imports cleanly into `flutter_test` + `dartproptest` VM suites, exactly
// like the rest of the governance core.
//
// Part of: per-screen-business-type-audit-remediation (Task 12.1)
// _Requirements: 1.6, 1.7_

import 'completed_registry.dart' show CompletedRegistry;
import 'definition_of_done.dart' show DoneClassification, DodItem;
import 'iteration_state_machine.dart' show IterationStatus;
import 'target_selector.dart' show AdvanceDecision, TargetSelector;
import 'types.dart' show IterationTarget, ScreenUniverse;

/// Why the Advance Guard blocked (or permitted) advancement.
///
/// When advancement is [permitted] the reason is [none]. Otherwise the reason
/// names the dominant cause; both [statusNotDone] and [dodNotSatisfied] can
/// hold at once, in which case [statusNotDone] is reported first because a
/// not-`done` status is the more fundamental block.
enum AdvanceBlockReason {
  /// Advancement was permitted; nothing blocks it.
  none,

  /// The current Iteration_Target's status is not `IterationStatus.done`.
  statusNotDone,

  /// The Definition-of-Done classification is not `done`; see
  /// [AdvanceGuardDecision.blockingItems] for the offending items.
  dodNotSatisfied,
}

/// The outcome of consulting the [AdvanceGuard].
///
/// Advancement is [permitted] iff the current status equals
/// [IterationStatus.done] AND the Definition-of-Done classification is `done`
/// (Property 5; Req 1.6). When not [permitted], advancement is blocked, the
/// current Iteration_Target is held in [retainedTarget] so it stays active
/// (Req 1.7), [reason] names why, and [blockingItems] lists the Definition_Of_Done
/// items still outstanding (empty when the only cause is the status). When
/// [permitted], [advance] carries the next move computed from the registry and
/// universe (null for the status/DoD-only [evaluate] entry point).
class AdvanceGuardDecision {
  AdvanceGuardDecision._({
    required this.permitted,
    required this.currentStatus,
    required this.statusIsDone,
    required this.dodIsDone,
    required this.reason,
    required List<DodItem> blockingItems,
    this.retainedTarget,
    this.advance,
  }) : blockingItems = List<DodItem>.unmodifiable(blockingItems);

  /// True iff advancement to the next Iteration_Target is allowed.
  final bool permitted;

  /// The status that was evaluated. Always one of the five enumerated values.
  final IterationStatus currentStatus;

  /// True iff [currentStatus] equals [IterationStatus.done].
  final bool statusIsDone;

  /// True iff the Definition-of-Done classification was `done`.
  final bool dodIsDone;

  /// Why advancement was blocked, or [AdvanceBlockReason.none] when permitted.
  final AdvanceBlockReason reason;

  /// The Definition_Of_Done items still blocking completion (Req 14.2); empty
  /// when the DoD is satisfied or no DoD classification constrained the call.
  final List<DodItem> blockingItems;

  /// The Iteration_Target retained as active because advancement was blocked
  /// (Req 1.7); null when [permitted] or when no current target was supplied.
  final IterationTarget? retainedTarget;

  /// The next move once advancement is permitted (Req 1.6); present only for
  /// [AdvanceGuard.evaluateAdvance], null otherwise.
  final AdvanceDecision? advance;

  /// A human-readable explanation of the decision.
  String get explanation {
    if (permitted) {
      return 'Advancement permitted: status is done and the Definition-of-Done '
          'is satisfied.';
    }
    switch (reason) {
      case AdvanceBlockReason.statusNotDone:
        return 'Advancement blocked: current status is $currentStatus, not '
            '${IterationStatus.done}; the current Iteration_Target is retained '
            'as active.';
      case AdvanceBlockReason.dodNotSatisfied:
        return 'Advancement blocked: the Definition-of-Done is not satisfied '
            '(${blockingItems.map((i) => i.name).join(', ')}); the current '
            'Iteration_Target is retained as active.';
      case AdvanceBlockReason.none:
        return 'Advancement blocked.';
    }
  }

  @override
  String toString() => permitted
      ? 'AdvanceGuardDecision.permitted(${advance ?? 'next undetermined'})'
      : 'AdvanceGuardDecision.blocked($reason, retained: $retainedTarget)';
}

/// Pure governor that permits Iteration advancement only when a Screen is
/// genuinely `done`.
///
/// Stateless: every method is a deterministic function of its inputs, safe to
/// treat as a value/utility and to hammer with property tests.
class AdvanceGuard {
  const AdvanceGuard();

  /// Decide whether advancement is permitted from [currentStatus] and the
  /// Definition-of-Done classification [dod].
  ///
  /// Advancement is permitted IF AND ONLY IF [currentStatus] equals
  /// [IterationStatus.done] AND [dod] is `done` (Property 5; Req 1.6).
  /// Otherwise advancement is blocked, [currentTarget] (when supplied) is
  /// retained as the active Iteration_Target (Req 1.7), and the returned
  /// decision explains why — a not-`done` status, or the outstanding
  /// Definition_Of_Done items, or both.
  AdvanceGuardDecision evaluate({
    required IterationStatus currentStatus,
    required DoneClassification dod,
    IterationTarget? currentTarget,
  }) {
    final statusIsDone = currentStatus == IterationStatus.done;
    final dodIsDone = dod.done;
    final permitted = statusIsDone && dodIsDone;

    final reason = permitted
        ? AdvanceBlockReason.none
        // A not-done status is the more fundamental block, so report it first.
        : (!statusIsDone
              ? AdvanceBlockReason.statusNotDone
              : AdvanceBlockReason.dodNotSatisfied);

    return AdvanceGuardDecision._(
      permitted: permitted,
      currentStatus: currentStatus,
      statusIsDone: statusIsDone,
      dodIsDone: dodIsDone,
      reason: reason,
      // Surface the outstanding DoD items whenever the DoD is unsatisfied.
      blockingItems: dodIsDone ? const <DodItem>[] : dod.blockingItems,
      // Retain the current target as active only when advancement is blocked.
      retainedTarget: permitted ? null : currentTarget,
    );
  }

  /// Decide advancement and, when permitted, compute the next Iteration_Target.
  ///
  /// Applies the same permit-IFF-`done` gate as [evaluate] for [currentTarget].
  /// When permitted, the next move is delegated to [TargetSelector.advance],
  /// which consults the [registry] and [universe] to yield exactly one next
  /// target or signal that none remain (Req 1.6, 2.8, 15.3); the result is
  /// carried in [AdvanceGuardDecision.advance]. When blocked, no advance is
  /// computed and [currentTarget] is retained as active (Req 1.7).
  AdvanceGuardDecision evaluateAdvance({
    required IterationStatus currentStatus,
    required DoneClassification dod,
    required IterationTarget currentTarget,
    required CompletedRegistry registry,
    required ScreenUniverse universe,
    TargetSelector selector = const TargetSelector(),
  }) {
    final gate = evaluate(
      currentStatus: currentStatus,
      dod: dod,
      currentTarget: currentTarget,
    );

    // Blocked: hold the current target; do not compute a next move (Req 1.7).
    if (!gate.permitted) return gate;

    // Permitted: the loop may move on — compute the single next target (Req 1.6).
    final next = selector.advance(registry, universe);
    return AdvanceGuardDecision._(
      permitted: true,
      currentStatus: gate.currentStatus,
      statusIsDone: gate.statusIsDone,
      dodIsDone: gate.dodIsDone,
      reason: AdvanceBlockReason.none,
      blockingItems: const <DodItem>[],
      advance: next,
    );
  }
}
