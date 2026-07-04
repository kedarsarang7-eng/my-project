/// Prioritizer — orders Findings for the Fix Log and counts completed work.
///
/// Pure-function component: all methods are deterministic over their inputs.
///
/// Requirements: 7.4, 7.5, 7.6
library;

import '../models/audit_engine_models.dart';

/// Provides Fix Log ordering and completed-work counting for Findings.
class Prioritizer {
  /// Stable sort by Severity descending (Critical → High → Medium → Low).
  ///
  /// Equal-severity findings retain their original discovery order
  /// ([Finding.discoveryIndex]). Returns a new list — the input is not mutated.
  ///
  /// Dart's [List.sort] is a stable sort, so comparing by severity index first
  /// and discoveryIndex second preserves insertion order for ties.
  ///
  /// Severity enum indices: critical=0, high=1, medium=2, low=3.
  /// Sorting ascending by index yields Critical first (highest priority).
  ///
  /// Validates: Requirements 7.5, 7.6
  List<Finding> orderForFixLog(List<Finding> findings) {
    final sorted = List<Finding>.of(findings);
    sorted.sort((a, b) {
      final severityCompare = a.severity.index.compareTo(b.severity.index);
      if (severityCompare != 0) return severityCompare;
      return a.discoveryIndex.compareTo(b.discoveryIndex);
    });
    return sorted;
  }

  /// Count of Findings that are neither [FindingState.blocked] nor
  /// [FindingState.deferred].
  ///
  /// This counts findings in [FindingState.open] or [FindingState.resolved]
  /// states — i.e. work that is actionable or already done, excluding items
  /// that cannot be counted as completed work.
  ///
  /// Validates: Requirements 7.4
  int completedCount(List<Finding> findings) {
    return findings
        .where(
          (f) =>
              f.state != FindingState.blocked &&
              f.state != FindingState.deferred,
        )
        .length;
  }
}
