// AUDIT_SYSTEM — COMPLETED-SCREENS REGISTRY (Task 11.1)
//
// The running record of which Screens are `done` per Business_Type across all
// Iterations. It is the single source of truth the Advance Decision and the
// Final-Validation-Checklist consult to decide when the whole initiative is
// complete (Req 16.1).
//
// Three responsibilities:
//   * recordDone — register a `done` Screen so each completed Screen appears at
//     most once per Business_Type; calling it again is a no-op (Req 15.4).
//   * reopen — when a regression is discovered in a previously completed Screen,
//     reclassify it as NOT done, log the triggering Gap id + timestamp, and
//     schedule a dedicated remediation Iteration_Target so the regression is
//     fixed before reporting that no targets remain (Req 14.5, 15.6).
//   * allDone — true iff every Screen of every non-template Business_Type in the
//     universe is recorded `done` (Req 16.1).
//
// Persistence (Req 15.4, design "Completed-Screens Registry (persisted JSON)"):
// the canonical persisted form is a map of `businessType -> [screenPath, ...]`,
// with the invariant that each `screenPath` appears at most once within its
// Business_Type array. Reopen events and the targets they schedule are tracked
// as runtime scheduling state and serialized alongside the done-map.
//
// This file is PURE, dependency-light Dart (only `dart:convert` plus the
// Audit_System core models), so it imports cleanly into `flutter_test` +
// `dartproptest` VM suites, mirroring the rest of the governance core.
//
// Part of: per-screen-business-type-audit-remediation (Task 11.1)
// _Requirements: 14.5, 15.4, 15.6, 16.1_

import 'dart:convert';

import 'types.dart' show IterationTarget, ScreenUniverse;

/// A record of a previously-completed Screen being reopened after a regression.
///
/// Captures the triggering Gap identifier and the ISO-8601 timestamp at which
/// the reclassification happened, satisfying the audit-trail requirement that a
/// reopen be recorded with its triggering Gap id and timestamp (Req 14.5).
class ReopenEvent {
  ReopenEvent({
    required this.businessType,
    required this.screenPath,
    required this.gapId,
    required this.timestamp,
  });

  /// Module folder under `lib/modules/`, never `_template`.
  final String businessType;

  /// Forward-slash, package-relative `.dart` path of the regressed Screen.
  final String screenPath;

  /// Identifier of the Gap whose regression triggered the reopen.
  final String gapId;

  /// ISO-8601 (UTC) instant the reopen was recorded.
  final String timestamp;

  /// The (businessType, screen) pair this reopen scheduled for remediation.
  IterationTarget get target =>
      IterationTarget(businessType: businessType, screenPath: screenPath);

  Map<String, Object?> toJson() => <String, Object?>{
    'businessType': businessType,
    'screenPath': screenPath,
    'gapId': gapId,
    'timestamp': timestamp,
  };

  static ReopenEvent fromJson(Map<String, Object?> json) => ReopenEvent(
    businessType: json['businessType'] as String,
    screenPath: json['screenPath'] as String,
    gapId: json['gapId'] as String,
    timestamp: json['timestamp'] as String,
  );

  @override
  String toString() =>
      'ReopenEvent($businessType, $screenPath, gap=$gapId, at=$timestamp)';
}

/// The running record of `done` Screens per Business_Type (Req 15.4, 16.1).
///
/// Pure governance state with no I/O and no hidden globals, so it imports
/// cleanly into property and unit tests.
class CompletedRegistry {
  CompletedRegistry();

  // businessType -> ordered set of done screenPaths. A `Set` enforces the
  // "at most once per Business_Type" invariant directly (Req 15.4).
  final Map<String, Set<String>> _done = <String, Set<String>>{};

  // Reopen audit trail, newest appended last (Req 14.5).
  final List<ReopenEvent> _reopens = <ReopenEvent>[];

  // Dedicated remediation targets scheduled by reopen, de-duplicated (Req 15.6).
  final List<IterationTarget> _scheduled = <IterationTarget>[];

  /// Record [screenPath] as done for [businessType].
  ///
  /// Idempotent: recording the same pair again leaves the registry unchanged,
  /// so each completed Screen appears at most once per Business_Type across all
  /// Iterations (Req 15.4). Recording a Screen also clears any prior reopen
  /// schedule for it — the regression has been remediated.
  void recordDone(String businessType, String screenPath) {
    (_done[businessType] ??= <String>{}).add(screenPath);
    // Once re-completed, drop the dedicated remediation target it was waiting on.
    _scheduled.removeWhere(
      (t) => t.businessType == businessType && t.screenPath == screenPath,
    );
  }

  /// Reopen a previously-completed Screen after a regression (Req 14.5, 15.6).
  ///
  /// Reclassifies the Screen as NOT done (removing it from the done record),
  /// appends a [ReopenEvent] capturing the triggering [gapId] and a timestamp,
  /// and schedules exactly one dedicated remediation [IterationTarget] for the
  /// Screen (de-duplicated if already scheduled). Pass [at] to supply a
  /// deterministic timestamp; otherwise the current UTC instant is used.
  void reopen(
    String businessType,
    String screenPath,
    String gapId, {
    DateTime? at,
  }) {
    // Reclassify as not done — removal is a no-op if it was never recorded.
    _done[businessType]?.remove(screenPath);

    final when = (at ?? DateTime.now()).toUtc().toIso8601String();
    _reopens.add(
      ReopenEvent(
        businessType: businessType,
        screenPath: screenPath,
        gapId: gapId,
        timestamp: when,
      ),
    );

    // Schedule a dedicated remediation target, at most once per (type, screen).
    final already = _scheduled.any(
      (t) => t.businessType == businessType && t.screenPath == screenPath,
    );
    if (!already) {
      _scheduled.add(
        IterationTarget(businessType: businessType, screenPath: screenPath),
      );
    }
  }

  /// True iff [businessType]/[screenPath] is currently recorded as done.
  bool isDone(String businessType, String screenPath) =>
      _done[businessType]?.contains(screenPath) ?? false;

  /// Done Screens for [businessType], sorted; empty when none are recorded.
  List<String> doneScreens(String businessType) {
    final set = _done[businessType];
    if (set == null) return const <String>[];
    return set.toList()..sort();
  }

  /// The reopen audit trail in the order events were recorded (Req 14.5).
  List<ReopenEvent> get reopenEvents =>
      List<ReopenEvent>.unmodifiable(_reopens);

  /// The dedicated remediation targets scheduled by [reopen] and not yet
  /// re-completed, in scheduling order (Req 15.6).
  List<IterationTarget> get scheduledTargets =>
      List<IterationTarget>.unmodifiable(_scheduled);

  /// True iff a regression-remediation target is still outstanding. The
  /// Advance Decision MUST schedule these before reporting no targets remain
  /// (Req 15.6).
  bool get hasPendingReopens => _scheduled.isNotEmpty;

  /// True iff every Screen of every non-template Business_Type in [universe] is
  /// recorded as done (Req 16.1).
  ///
  /// A reopened Screen is no longer in the done record, so [allDone] is false
  /// until it is re-completed. An empty universe is vacuously all done.
  bool allDone(ScreenUniverse universe) {
    for (final businessType in universe.businessTypes) {
      final done = _done[businessType] ?? const <String>{};
      for (final screen in universe.screensFor(businessType)) {
        if (!done.contains(screen.screenPath)) return false;
      }
    }
    return true;
  }

  /// Serialize to the canonical persisted form (design "Completed-Screens
  /// Registry (persisted JSON)"): a map of `businessType -> [screenPath, ...]`
  /// with each Business_Type's screens sorted and unique. Reopen events and the
  /// targets they scheduled are carried under reserved `_` keys so the done-map
  /// stays the dominant, diff-friendly structure (Req 15.4).
  Map<String, Object?> toJson() {
    final out = <String, Object?>{};
    final types = _done.keys.toList()..sort();
    for (final type in types) {
      final screens = _done[type]!;
      if (screens.isEmpty) continue;
      out[type] = screens.toList()..sort();
    }
    if (_reopens.isNotEmpty) {
      out['_reopens'] = _reopens.map((e) => e.toJson()).toList();
    }
    if (_scheduled.isNotEmpty) {
      out['_scheduled'] = _scheduled.map((t) => t.toJson()).toList();
    }
    return out;
  }

  /// Encode [toJson] as a pretty-printed JSON string for persistence.
  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Rebuild a registry from its [toJson] form. Tolerates both the bare
  /// done-map and the extended form carrying `_reopens`/`_scheduled`.
  static CompletedRegistry fromJson(Map<String, Object?> json) {
    final registry = CompletedRegistry();
    for (final entry in json.entries) {
      if (entry.key == '_reopens') {
        for (final raw in entry.value as List<Object?>) {
          registry._reopens.add(
            ReopenEvent.fromJson((raw as Map).cast<String, Object?>()),
          );
        }
        continue;
      }
      if (entry.key == '_scheduled') {
        for (final raw in entry.value as List<Object?>) {
          registry._scheduled.add(
            IterationTarget.fromJson((raw as Map).cast<String, Object?>()),
          );
        }
        continue;
      }
      // Ordinary Business_Type -> [screenPath, ...] entry.
      final screens = (entry.value as List<Object?>).cast<String>();
      registry._done[entry.key] = <String>{...screens};
    }
    return registry;
  }

  /// Decode a JSON string produced by [toJsonString] back into a registry.
  static CompletedRegistry fromJsonString(String source) =>
      fromJson((jsonDecode(source) as Map).cast<String, Object?>());
}
