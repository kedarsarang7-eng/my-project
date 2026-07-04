/// FindingRecorder — records audit findings with exactly one Severity each.
///
/// Maps `audit_rules.json` priority codes (P0–P3) to [Severity] values and
/// maintains an ordered list of all recorded findings with stable discovery
/// indices and auto-assigned unique IDs.
///
/// Requirements: 3.8, 7.5
library;

import '../models/audit_engine_models.dart';

/// Records audit findings during a Cycle, assigning each a unique ID and
/// exactly one [Severity] (invariant from Req 7.5).
///
/// Usage:
/// ```dart
/// final recorder = FindingRecorder();
/// final finding = recorder.record(
///   screen: screenRef,
///   category: ChecklistCategory.layoutAndOverflow,
///   severity: Severity.high,
///   description: 'RenderFlex overflow in populated state',
///   fileLine: 'lib/features/grocery/screens/dashboard.dart:42',
/// );
/// ```
class FindingRecorder {
  /// Internal sequence counter for generating unique Finding IDs.
  int _sequence = 0;

  /// Internal list of all recorded findings in discovery order.
  final List<Finding> _findings = [];

  /// All recorded findings in discovery order (unmodifiable view).
  List<Finding> get findings => List.unmodifiable(_findings);

  /// Records a new [Finding] with exactly one [Severity], auto-assigning
  /// a unique `id` (format: `F-{sequence}`) and incrementing `discoveryIndex`
  /// for stable ordering.
  ///
  /// Parameters:
  /// - [screen]: The screen where the issue was found.
  /// - [category]: Which checklist category this finding belongs to.
  /// - [severity]: Exactly one severity level (Req 7.5).
  /// - [description]: Human-readable description of the issue.
  /// - [fileLine]: File:line reference to the issue location.
  ///
  /// Returns the newly created [Finding].
  Finding record({
    required ScreenRef screen,
    required ChecklistCategory category,
    required Severity severity,
    required String description,
    required String fileLine,
  }) {
    _sequence++;
    final finding = Finding(
      id: 'F-$_sequence',
      screen: screen,
      category: category,
      severity: severity,
      description: description,
      fileLine: fileLine,
      state: FindingState.open,
      discoveryIndex: _sequence,
    );
    _findings.add(finding);
    return finding;
  }

  /// Maps an `audit_rules.json` priority code to a [Severity] value.
  ///
  /// - P0 → Critical
  /// - P1 → High
  /// - P2 → Medium
  /// - P3 → Low
  ///
  /// Throws [ArgumentError] if [priorityCode] is not one of P0, P1, P2, P3.
  Severity mapPriority(String priorityCode) {
    return switch (priorityCode) {
      'P0' => Severity.critical,
      'P1' => Severity.high,
      'P2' => Severity.medium,
      'P3' => Severity.low,
      _ => throw ArgumentError(
        'Unknown priority code "$priorityCode". '
        'Expected one of: P0, P1, P2, P3.',
      ),
    };
  }

  /// Resets the recorder state for starting a new cycle.
  ///
  /// Clears all recorded findings and resets the sequence counter to zero.
  void reset() {
    _sequence = 0;
    _findings.clear();
  }
}
