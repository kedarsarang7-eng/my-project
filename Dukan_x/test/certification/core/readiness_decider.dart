/// Production-readiness decider — pure decision logic for go/no-go.
///
/// Takes all evidence (mock-data scan, debug flags, environment, crash state,
/// gate statuses, unresolved defects, unevaluatable items) and produces a
/// deterministic go or no-go decision with itemized reasons.
///
/// This is pure logic with no I/O. The decision is deterministic and
/// property-testable.
///
/// Requirements: 7.4, 12.5, 14.2, 14.3, 14.4, 14.5, 15.3, 15.4
library;

import 'defect.dart';
import 'gate_reducer.dart';

/// All evidence inputs required to make a production-readiness decision.
///
/// Each field represents a verified condition gathered by the IO shell
/// (Mock_Data_Scanner, environment checker, crash monitor, gate runners,
/// defect store, and evaluatability tracker).
class ReadinessInputs {
  /// True when the Mock_Data_Scanner found zero mock-data occurrences
  /// in the Release_Build (Req 15.3, 15.4).
  final bool mockDataAbsent;

  /// True when no debug flags (e.g. `--debug`, `kDebugMode` references,
  /// assert-only code paths) are present in the Release_Build.
  final bool debugFlagsAbsent;

  /// True when the environment configuration matches the approved
  /// production configuration values (Req 14.1, 14.4).
  final bool envMatchesProduction;

  /// True when zero unhandled exceptions or process terminations occurred
  /// during the certification run (Req 14.1, 14.4).
  final bool crashFree;

  /// Status of every Quality_Gate, keyed by gate name (e.g. 'regression',
  /// 'performance', 'security', 'dataIntegrity'). Every gate must be green
  /// for a go decision (Req 14.2).
  final Map<String, GateStatus> gateStatuses;

  /// All defects that are NOT yet resolved/closed. The decider checks for
  /// release-blocking severities (Critical, High) among these (Req 14.3, 7.4).
  final List<Defect> unresolvedDefects;

  /// Items whose status could not be determined during the certification run.
  /// Any non-empty set triggers a no-go (Req 14.5).
  final Set<String> unevaluatableItems;

  const ReadinessInputs({
    required this.mockDataAbsent,
    required this.debugFlagsAbsent,
    required this.envMatchesProduction,
    required this.crashFree,
    required this.gateStatuses,
    required this.unresolvedDefects,
    required this.unevaluatableItems,
  });
}

/// The outcome of the production-readiness decision.
///
/// [go] is true only when all conditions are met. When [go] is false,
/// [reasons] contains one entry per failing condition (itemized).
class ReadinessDecision {
  /// True = release is approved; false = release is blocked.
  final bool go;

  /// Itemized reasons for a no-go decision. Empty when [go] is true.
  final List<String> reasons;

  const ReadinessDecision({required this.go, required this.reasons});

  /// Convenience constructor for a go decision.
  const ReadinessDecision.goDecision() : go = true, reasons = const [];
}

/// Pure decision logic for production readiness.
///
/// go IFF ALL of the following hold:
/// 1. Mock data absent from the Release_Build
/// 2. Debug flags absent from the Release_Build
/// 3. Environment matches approved production configuration
/// 4. Crash-free operation during certification
/// 5. Every Quality_Gate is green
/// 6. Zero unresolved release-blocking (Critical/High) defects
/// 7. No unevaluatable items (all checklist items could be determined)
///
/// Otherwise no-go with itemized reasons listing every failing condition.
class ProductionReadinessDecider {
  const ProductionReadinessDecider();

  /// Produces a [ReadinessDecision] from the given [inputs].
  ///
  /// This is a pure function — deterministic, no side effects, no I/O.
  ReadinessDecision decide(ReadinessInputs inputs) {
    final reasons = <String>[];

    // 1. Mock data must be absent (Req 15.3, 15.4)
    if (!inputs.mockDataAbsent) {
      reasons.add('Mock data detected in Release_Build');
    }

    // 2. Debug flags must be absent
    if (!inputs.debugFlagsAbsent) {
      reasons.add('Debug flags present in Release_Build');
    }

    // 3. Environment must match production (Req 14.4)
    if (!inputs.envMatchesProduction) {
      reasons.add(
        'Environment configuration does not match approved production values',
      );
    }

    // 4. Must be crash-free (Req 14.4)
    if (!inputs.crashFree) {
      reasons.add(
        'Crash detected: unhandled exceptions or process terminations '
        'occurred during certification run',
      );
    }

    // 5. Every gate must be green (Req 14.2)
    for (final entry in inputs.gateStatuses.entries) {
      if (entry.value != GateStatus.green) {
        reasons.add('Quality gate "${entry.key}" is not green');
      }
    }

    // 6. Zero unresolved release-blocking defects (Req 14.3, 7.4)
    final releaseBlockingDefects = inputs.unresolvedDefects.where(
      (d) => d.severity == Severity.critical || d.severity == Severity.high,
    );
    for (final defect in releaseBlockingDefects) {
      reasons.add(
        'Unresolved release-blocking defect: ${defect.id} '
        '(${defect.severity.name})',
      );
    }

    // 7. No unevaluatable items (Req 14.5)
    for (final item in inputs.unevaluatableItems) {
      reasons.add('Cannot determine status of checklist item: "$item"');
    }

    // Decision: go only when all conditions pass (reasons is empty)
    if (reasons.isEmpty) {
      return const ReadinessDecision.goDecision();
    }

    return ReadinessDecision(go: false, reasons: reasons);
  }
}
