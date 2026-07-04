/// SignOffEvaluator — determines whether a Cycle's Sign_Off can be granted.
///
/// Pure-function component: [evaluate] is deterministic over its [CycleState]
/// input, producing a [SignOff] result based on three sub-conditions.
///
/// Requirements: 1.6, 1.7, 6.10, 6.11
library;

import '../models/audit_engine_models.dart';

/// Evaluates Sign_Off readiness for a completed Cycle.
///
/// Sign_Off is granted (`isComplete = true`) if and only if all three
/// sub-conditions hold:
///
/// 1. Every Finding is resolved, blocked, or deferred (no open findings).
/// 2. The Business_Type_Test_Suite reports zero failing tests.
/// 3. Every Shared_Core_Widget edit has a recorded verification result for
///    each consuming Business_Type with no unresolved fail.
///
/// When not complete, the returned [SignOff.withholdingConditions] enumerates
/// exactly which sub-conditions failed (Req 6.11).
class SignOffEvaluator {
  /// Evaluates the sign-off predicate for the given [state].
  ///
  /// Validates: Requirements 1.6, 1.7, 6.10, 6.11
  SignOff evaluate(CycleState state) {
    final conditions = <String>[];

    // Sub-condition 1: All Findings addressed (no open findings remain).
    final openFindings = state.findings
        .where((f) => f.state == FindingState.open)
        .toList();
    if (openFindings.isNotEmpty) {
      final ids = openFindings.map((f) => f.id).toList();
      conditions.add(
        '${openFindings.length} open finding(s) remain unresolved: $ids',
      );
    }

    // Sub-condition 2: Zero test failures in the Business_Type_Test_Suite.
    final failingTests = state.testLog.where((t) => !t.passed).toList();
    if (failingTests.isNotEmpty) {
      final testIds = failingTests.map((t) => t.testId).toList();
      conditions.add('${failingTests.length} test(s) failing: $testIds');
    }

    // Sub-condition 3: Shared-core verifications complete and passing.
    final sharedFailures = <String>[];
    for (final impact in state.sharedImpact) {
      for (final entry in impact.consumerVerification.entries) {
        if (entry.value == false) {
          sharedFailures.add('${impact.widgetPath} → ${entry.key.displayName}');
        }
      }
    }
    if (sharedFailures.isNotEmpty) {
      conditions.add('Shared widget verification failed for: $sharedFailures');
    }

    return SignOff(
      isComplete: conditions.isEmpty,
      withholdingConditions: conditions,
    );
  }
}
