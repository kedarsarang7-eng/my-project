// AUDIT_SYSTEM — ITERATION STATE MACHINE (Task 3.1)
//
// The forward-only governor of an Iteration_Target's lifecycle. Two pure,
// dependency-free pieces of logic live here:
//
//   * The STATUS state machine — every selected Iteration_Target carries a
//     status that is always exactly one of five values (Req 1.8). Status may
//     only move one step forward along
//         not started → in audit → in fix → in verification → done
//     Any skip or reversal is rejected and the current status is preserved
//     (Req 1.9). Modeling this as a transition function makes illegal moves
//     un-representable and trivially property-testable (design "Forward-only
//     state machine").
//
//   * The PHASE ordering check — an Iteration runs its workflow phases strictly
//     in order Identify → Audit → Fix → Verify → Report-and-Advance, each phase
//     completing before the next begins (Req 2.1). `phaseOrderValid` validates
//     a recorded executed sequence against that order with no phase skipped,
//     reordered, or begun before its predecessor.
//
// Pure `dart:core` only — no Flutter, no I/O — so it imports cleanly into
// `flutter_test` + `dartproptest` VM suites, exactly like `types.dart`.
//
// Part of: per-screen-business-type-audit-remediation (Task 3.1)
// _Requirements: 1.8, 1.9, 2.1_

/// The five — and only five — values an Iteration_Target's status may hold
/// (Req 1.8). Declaration order matches the legal forward progression.
enum IterationStatus { notStarted, inAudit, inFix, inVerification, done }

/// The strict forward order of statuses (Req 1.9). A status's index in this
/// list defines its position; a transition is legal iff it advances by exactly
/// one position. This is the single source of truth for legal progression.
const List<IterationStatus> kStatusOrder = <IterationStatus>[
  IterationStatus.notStarted,
  IterationStatus.inAudit,
  IterationStatus.inFix,
  IterationStatus.inVerification,
  IterationStatus.done,
];

/// The workflow phases of a single Iteration, in the strict order they must
/// execute (Req 2.1). Declaration order matches the required execution order.
enum WorkflowPhase { identify, audit, fix, verify, reportAndAdvance }

/// The canonical forward order of workflow phases (Req 2.1).
const List<WorkflowPhase> kPhaseOrder = <WorkflowPhase>[
  WorkflowPhase.identify,
  WorkflowPhase.audit,
  WorkflowPhase.fix,
  WorkflowPhase.verify,
  WorkflowPhase.reportAndAdvance,
];

/// The outcome of attempting a status transition.
///
/// A transition either succeeds — moving the target one step forward — or is
/// rejected, in which case [status] is unchanged from the `from` status and
/// [rejectionReason] explains why. [status] is ALWAYS one of the five
/// [IterationStatus] values (Req 1.8), whether the transition was permitted or
/// rejected.
class TransitionResult {
  TransitionResult._({
    required this.permitted,
    required this.status,
    this.rejectionReason,
  });

  /// A permitted transition; the resulting status is [to].
  factory TransitionResult.permitted(IterationStatus to) =>
      TransitionResult._(permitted: true, status: to);

  /// A rejected transition; the status is retained as [from] (Req 1.9).
  factory TransitionResult.rejected(IterationStatus from, String reason) =>
      TransitionResult._(
        permitted: false,
        status: from,
        rejectionReason: reason,
      );

  /// True iff the transition was allowed and applied.
  final bool permitted;

  /// The status after the attempt — the new status when [permitted], otherwise
  /// the unchanged `from` status. Always one of the five enumerated values.
  final IterationStatus status;

  /// Human-readable reason, present iff the transition was rejected.
  final String? rejectionReason;

  @override
  String toString() => permitted
      ? 'TransitionResult.permitted($status)'
      : 'TransitionResult.rejected($status, $rejectionReason)';
}

/// Pure governor for Iteration_Target status and workflow-phase ordering.
///
/// Stateless: every method is a deterministic function of its inputs, so it is
/// safe to treat as a value/utility and to hammer with property tests.
class IterationStateMachine {
  const IterationStateMachine();

  /// Attempts to move a target's status from [from] to [to].
  ///
  /// Permits the transition IFF [to] is exactly one position after [from] in
  /// [kStatusOrder]; rejects every skip (advancing by more than one) and every
  /// reversal (including a no-op self-transition), preserving [from] as the
  /// current status (Req 1.9). The returned status is always one of the five
  /// [IterationStatus] values (Req 1.8).
  TransitionResult transition(IterationStatus from, IterationStatus to) {
    final fromIndex = kStatusOrder.indexOf(from);
    final toIndex = kStatusOrder.indexOf(to);

    // Both must be members of the canonical order. (Defensive: every enum value
    // is listed in kStatusOrder, so this only guards against future drift.)
    if (fromIndex == -1 || toIndex == -1) {
      return TransitionResult.rejected(
        from,
        'Unknown status outside the forward order',
      );
    }

    if (toIndex == fromIndex + 1) {
      return TransitionResult.permitted(to);
    }

    if (toIndex <= fromIndex) {
      return TransitionResult.rejected(
        from,
        'Reversing or repeating transition from $from to $to is not allowed; '
        'status may only move forward',
      );
    }

    // toIndex > fromIndex + 1 — a forward skip.
    return TransitionResult.rejected(
      from,
      'Skipping transition from $from to $to is not allowed; status may only '
      'advance one step at a time',
    );
  }

  /// True iff [executedSequence] follows the workflow phase order strictly.
  ///
  /// Valid IFF the sequence is exactly a prefix of, or equal to, [kPhaseOrder]:
  /// Identify → Audit → Fix → Verify → Report-and-Advance, with no phase
  /// skipped, reordered, repeated, or begun before its predecessor (Req 2.1).
  /// An empty sequence is vacuously valid (no phase has run out of order yet).
  bool phaseOrderValid(List<WorkflowPhase> executedSequence) {
    // A sequence longer than the full phase set must contain a repeat or an
    // out-of-order entry, so it cannot be a valid in-order execution.
    if (executedSequence.length > kPhaseOrder.length) return false;

    for (var i = 0; i < executedSequence.length; i++) {
      // Each executed phase must equal the canonical phase at the same index:
      // this rejects skips, reorderings, repeats, and starting later phases
      // before their predecessors completed.
      if (executedSequence[i] != kPhaseOrder[i]) return false;
    }
    return true;
  }
}
