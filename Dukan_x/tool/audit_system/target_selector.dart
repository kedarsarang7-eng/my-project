// AUDIT_SYSTEM — TARGET SELECTOR + SCOPE GUARD (Task 2.2)
//
// The single-target gate of the Iteration loop. Given a proposed target and the
// enumerated `ScreenUniverse`, it accepts EXACTLY ONE (Business_Type, Screen)
// pair or rejects with a reason — never a partial selection. It also provides
// the scope guard the in-progress Iteration uses to fence audit/fix activity to
// the active target.
//
// Pure, dependency-light Dart: depends only on `dart:core` + the shared value
// types, so it imports cleanly into `flutter_test` + `dartproptest` VM suites,
// mirroring the `tool/responsive_audit.dart` pattern.
//
// Contracts implemented:
//   * select(proposal, universe) — accept iff the proposal names exactly one
//     existing, non-`_template` Business_Type AND exactly one existing Screen
//     for it; otherwise reject with `rejectionReason` and leave the caller's
//     current target unchanged (Req 1.1, 1.3, 1.5; `_template` per Req 1.4).
//   * inScope(activity, active) — true iff the activity's Business_Type AND
//     Screen both equal the active target's (Req 1.2).
//
// It also owns the Advance Decision (Task 10.3): after an Iteration completes,
// it consults the Completed-Screens Registry and the ScreenUniverse to decide
// the next move — exactly one next Iteration_Target, or none remaining — as the
// single source of truth for [AdvanceDecision] (design section "11. Advance
// Decision"; Req 2.8, 15.3).
//
// Part of: per-screen-business-type-audit-remediation (Tasks 2.2, 10.3)
// _Requirements: 1.1, 1.2, 1.3, 1.5, 2.8, 15.3_

import 'completed_registry.dart' show CompletedRegistry;
import 'types.dart';

/// A proposed Iteration_Target awaiting validation by [TargetSelector.select].
///
/// To be valid the proposal MUST name exactly one Business_Type and exactly one
/// Screen (Req 1.3); zero or multiple of either is a rejection.
class TargetProposal {
  TargetProposal({required this.businessTypes, required this.screens});

  /// Proposed Business_Type module names. Must have length exactly 1 to be
  /// valid (Req 1.1, 1.3).
  final List<String> businessTypes;

  /// Proposed Screen paths. Must have length exactly 1 to be valid
  /// (Req 1.1, 1.3).
  final List<String> screens;

  @override
  String toString() =>
      'TargetProposal(businessTypes: $businessTypes, screens: $screens)';
}

/// The outcome of validating a [TargetProposal].
///
/// Exactly one of [target] / [rejectionReason] is populated: [target] iff
/// [accepted], [rejectionReason] iff not. On rejection the caller leaves its
/// current Iteration_Target unchanged (Req 1.3, 1.5).
class SelectionResult {
  const SelectionResult._({
    required this.accepted,
    this.target,
    this.rejectionReason,
  });

  /// Build an accepted result wrapping the single validated [target].
  factory SelectionResult.accept(IterationTarget target) =>
      SelectionResult._(accepted: true, target: target);

  /// Build a rejected result carrying a human-readable [reason].
  factory SelectionResult.reject(String reason) =>
      SelectionResult._(accepted: false, rejectionReason: reason);

  /// True iff the proposal named a valid single (Business_Type, Screen) pair.
  final bool accepted;

  /// The validated single target; present iff [accepted].
  final IterationTarget? target;

  /// Why the proposal was rejected; present iff not [accepted].
  final String? rejectionReason;

  @override
  String toString() => accepted
      ? 'SelectionResult.accept($target)'
      : 'SelectionResult.reject($rejectionReason)';
}

/// Validates single-target selections and fences in-progress activity to the
/// active Iteration_Target. Stateless and pure.
class TargetSelector {
  const TargetSelector();

  /// Validate [proposal] against [universe].
  ///
  /// Accepts — returning [SelectionResult.accept] with the single
  /// [IterationTarget] — if and only if ALL of the following hold:
  ///   * the proposal names exactly one Business_Type (Req 1.1, 1.3),
  ///   * the proposal names exactly one Screen (Req 1.1, 1.3),
  ///   * that Business_Type exists in [universe] and is not `_template`
  ///     (Req 1.4, 1.5),
  ///   * that Screen exists for that Business_Type in [universe] (Req 1.5).
  ///
  /// In every other case it returns [SelectionResult.reject] with a reason and
  /// the caller leaves the current Iteration_Target unchanged (Req 1.3, 1.5).
  SelectionResult select(TargetProposal proposal, ScreenUniverse universe) {
    // Exactly one Business_Type (Req 1.1, 1.3).
    if (proposal.businessTypes.length != 1) {
      return SelectionResult.reject(
        'A single Iteration_Target requires exactly one Business_Type, '
        'but ${proposal.businessTypes.length} were proposed.',
      );
    }
    // Exactly one Screen (Req 1.1, 1.3).
    if (proposal.screens.length != 1) {
      return SelectionResult.reject(
        'A single Iteration_Target requires exactly one Screen, '
        'but ${proposal.screens.length} were proposed.',
      );
    }

    final businessType = proposal.businessTypes.single;
    final screenPath = proposal.screens.single;

    // The `_template` module is never selectable (Req 1.4, 1.5).
    if (businessType == kTemplateModule) {
      return SelectionResult.reject(
        "The '$kTemplateModule' module is excluded from selectable "
        'Business_Types.',
      );
    }

    // Business_Type must exist in the enumerated universe (Req 1.5).
    if (!universe.hasBusinessType(businessType)) {
      return SelectionResult.reject(
        "Business_Type '$businessType' was not found in the available modules.",
      );
    }

    // Screen must exist for that Business_Type (Req 1.5).
    if (!universe.hasScreen(businessType, screenPath)) {
      return SelectionResult.reject(
        "Screen '$screenPath' was not found for Business_Type "
        "'$businessType'.",
      );
    }

    return SelectionResult.accept(
      IterationTarget(businessType: businessType, screenPath: screenPath),
    );
  }

  /// True iff [activity] is in scope for the [active] Iteration_Target — that
  /// is, iff its Business_Type AND Screen both equal the active target's.
  ///
  /// Anything else is out of the current Iteration_Target scope and the caller
  /// rejects it (Req 1.2).
  bool inScope(Activity activity, IterationTarget active) =>
      activity.businessType == active.businessType &&
      activity.screenPath == active.screenPath;

  /// Decide the next move after an Iteration completes (Req 2.8, 15.3).
  ///
  /// Given the [registry] of `done` Screens and the enumerated [universe], this
  /// returns an [AdvanceDecision] whose two outcomes are mutually exclusive:
  ///   * `noTargetsRemain == true` (and `nextTarget == null`) **if and only if**
  ///     every Screen of every non-template Business_Type is recorded done
  ///     (Req 16.1, Property 44); or
  ///   * exactly one [AdvanceDecision.nextTarget] otherwise.
  ///
  /// Regression-remediation targets scheduled by a reopen take priority: while
  /// any are outstanding they are selected before fresh Screens, ensuring a
  /// reopened Screen is re-completed before reporting that no targets remain
  /// (Req 15.6). Because a reopened Screen is removed from the done record, the
  /// universe cannot be all-done while a scheduled target is pending, so the
  /// if-and-only-if relationship with [CompletedRegistry.allDone] is preserved.
  ///
  /// Within a Business_Type, Screens are visited in the universe's sorted order
  /// so the chosen next target is deterministic.
  AdvanceDecision advance(CompletedRegistry registry, ScreenUniverse universe) {
    // Outstanding regression-remediation targets are remediated first (Req 15.6).
    final scheduled = registry.scheduledTargets;
    if (scheduled.isNotEmpty) {
      return AdvanceDecision(
        nextTarget: scheduled.first,
        noTargetsRemain: false,
      );
    }

    // No pending reopens: when every Screen is done, nothing remains
    // (Req 2.8, 15.3). An empty universe is vacuously all done.
    if (registry.allDone(universe)) {
      return AdvanceDecision(noTargetsRemain: true);
    }

    // Otherwise select EXACTLY ONE next target: the first not-yet-done Screen in
    // the universe's deterministic (Business_Type, Screen) order.
    for (final businessType in universe.businessTypes) {
      for (final screen in universe.screensFor(businessType)) {
        if (!registry.isDone(businessType, screen.screenPath)) {
          return AdvanceDecision(
            nextTarget: IterationTarget(
              businessType: businessType,
              screenPath: screen.screenPath,
            ),
            noTargetsRemain: false,
          );
        }
      }
    }

    // Defensive: allDone returned false yet no not-done Screen was found. Treat
    // as nothing remaining to keep the two outcomes mutually exclusive.
    return AdvanceDecision(noTargetsRemain: true);
  }
}

/// The advance decision recorded after an Iteration completes: either exactly
/// one [nextTarget] to remediate next, or none remaining (Req 2.8, 15.3).
///
/// The two outcomes are mutually exclusive — [noTargetsRemain] is true if and
/// only if [nextTarget] is null. This is the canonical, single-source-of-truth
/// definition (design section "11. Advance Decision"); the Iteration_Report
/// model imports it from here.
///
/// `toJson()` emits the exact, stable shape
/// `{ "nextTarget": IterationTarget|null, "noTargetsRemain": bool }` and
/// `fromJson(Map)` reconstructs an equivalent value, so persisted reports stay
/// round-trippable (Req 15.2).
class AdvanceDecision {
  AdvanceDecision({this.nextTarget, required this.noTargetsRemain});

  /// The next (Business_Type, Screen) to remediate, or null when none remain.
  final IterationTarget? nextTarget;

  /// True iff [nextTarget] is null — no targets remain (Req 2.8, 15.3).
  final bool noTargetsRemain;

  @override
  bool operator ==(Object other) =>
      other is AdvanceDecision &&
      other.nextTarget == nextTarget &&
      other.noTargetsRemain == noTargetsRemain;

  @override
  int get hashCode => Object.hash(nextTarget, noTargetsRemain);

  @override
  String toString() =>
      'AdvanceDecision(${nextTarget ?? 'none'}, noTargetsRemain: $noTargetsRemain)';

  Map<String, Object?> toJson() => <String, Object?>{
    'nextTarget': nextTarget?.toJson(),
    'noTargetsRemain': noTargetsRemain,
  };

  static AdvanceDecision fromJson(Map<String, Object?> json) {
    final next = json['nextTarget'];
    return AdvanceDecision(
      nextTarget: next == null
          ? null
          : IterationTarget.fromJson((next as Map).cast<String, Object?>()),
      noTargetsRemain: json['noTargetsRemain'] as bool,
    );
  }
}
