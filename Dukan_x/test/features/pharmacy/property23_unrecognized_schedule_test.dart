// ============================================================================
// PHASE 1 — Task 2.3: PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 23: Unrecognized schedule
//          strings are rejected
// **Validates: Requirements 22.4**
// ============================================================================
//
// Property 23 (design.md — Correctness Properties):
//   *For any* non-empty schedule string that matches no defined `DrugSchedule`
//   value, the resolver classifies it as unrecognized, enforcement evaluation
//   for that item is rejected with a resolution-failure indication, and the
//   item's original data is preserved unchanged.
//
// WHAT IS PROVEN HERE (pure-logic surface):
//   `DrugScheduleResolver.fromRaw(String?)` is the canonical reconciliation
//   point. For any NON-EMPTY raw string whose normalized token (lowercased,
//   trimmed, with whitespace + `-`/`_` stripped) is itself non-empty and is NOT
//   one of the recognized tokens {otc, none, nonscheduled, h, scheduleh, h1,
//   scheduleh1, x, schedulex}, the resolver MUST return
//   `CanonicalDrugSchedule.unrecognized`, and `isScheduled(unrecognized)` MUST
//   be false — i.e. an unrecognized schedule is never treated as a dispensable
//   scheduled drug; callers must surface it as an explicit resolution failure
//   rather than silently dispensing or skipping it (Requirement 22.4).
//
// SAMPLING + PRECONDITION FILTER:
//   We draw arbitrary strings from `Gen.string`. The property only concerns
//   non-empty strings that do NOT collapse to a recognized token, so the
//   predicate computes the same normalization the resolver uses and SKIPS
//   (returns true) any sample that is empty/whitespace-only after normalization
//   or that lands on a known token. Random strings almost never collapse to the
//   short known tokens, so the sampled space remains overwhelmingly meaningful
//   (non-vacuous). Deterministic anchors below pin representative unrecognized
//   inputs so the suite cannot pass vacuously.
//
// PBT library: dartproptest ^0.2.1 (repo-standard; see pubspec.yaml note on why
//   `glados` is not used). Idiomatic usage: `forAll((arg) => <bool>, [gen],
//   numRuns: N)` returns true iff the property held for every run, else throws a
//   shrinking Exception with a counterexample.
//
// Run: flutter test test/features/pharmacy/property23_unrecognized_schedule_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/features/pharmacy/utils/drug_schedule_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// At least 100 generated cases are required by the spec; 200 is the
/// dartproptest default and the convention used across this repo's suites.
const int kNumRuns = 200;

/// The recognized normalized tokens `fromRaw` maps to a defined schedule.
/// Any non-empty normalized value OUTSIDE this set must resolve to
/// `unrecognized` (Requirement 22.4).
const Set<String> _recognizedTokens = <String>{
  'otc',
  'none',
  'nonscheduled',
  'h',
  'scheduleh',
  'h1',
  'scheduleh1',
  'x',
  'schedulex',
};

/// Normalize exactly as `DrugScheduleResolver.fromRaw` does: lowercase, then
/// strip whitespace and `-`/`_` separators. Used only to express the property's
/// precondition (is this sample a non-empty, non-recognized token?).
String _normalize(String raw) =>
    raw.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');

void main() {
  group('Feature: pharmacy-vertical-remediation, Property 23: Unrecognized '
      'schedule strings are rejected', () {
    // Arbitrary strings probe the unrecognized boundary. The predicate guards
    // the rare sample that normalizes to empty or to a recognized token.
    final Generator<String> arbitraryStringGen = Gen.string(
      minLength: 1,
      maxLength: 24,
    );

    test('Property 23: any non-empty string that does not normalize to a known '
        'token resolves to CanonicalDrugSchedule.unrecognized and is not '
        'scheduled', () {
      final bool held = forAll(
        (String raw) {
          final String normalized = _normalize(raw);

          // Precondition filter: the property concerns ONLY non-empty
          // strings that do not collapse to a recognized token.
          //  * empty after normalization -> resolver returns nonScheduled
          //    (Requirement 7.4), outside this property's scope.
          //  * a recognized token -> resolver returns a defined schedule,
          //    covered by Property 22, not here.
          if (normalized.isEmpty || _recognizedTokens.contains(normalized)) {
            return true; // skip — precondition not met
          }

          final CanonicalDrugSchedule resolved = DrugScheduleResolver.fromRaw(
            raw,
          );

          // (a) Unrecognized strings are classified as such.
          if (resolved != CanonicalDrugSchedule.unrecognized) return false;

          // (b) An unrecognized schedule is NOT a dispensable scheduled
          //     drug — enforcement must reject it, not treat it as
          //     scheduled (Requirement 22.4).
          if (DrugScheduleResolver.isScheduled(resolved)) return false;

          return true;
        },
        [arbitraryStringGen],
        numRuns: kNumRuns,
      );

      expect(
        held,
        isTrue,
        reason:
            'Every non-empty, non-recognized schedule string must resolve '
            'to CanonicalDrugSchedule.unrecognized and report isScheduled '
            '== false (Property 23 / Requirement 22.4).',
      );
    });

    // -- Deterministic anchors: representative unrecognized inputs, so the
    //    property is demonstrably non-vacuous on real garbage values. ------
    test('Property 23 anchor: representative unrecognized strings map to '
        'unrecognized and are never scheduled', () {
      const List<String> unrecognizedInputs = <String>[
        'h2', // looks schedule-like but undefined
        'scheduleY', // undefined schedule letter
        'g', // single letter, not a schedule
        'controlled', // descriptive word, not a token
        'schedule', // bare prefix, no letter
        '123', // numeric junk
        'h11', // near-miss of h1
        'xx', // near-miss of x
        'otcx', // concatenated near-miss
        ' sched ule ', // collapses to "schedule" (no letter)
      ];

      for (final input in unrecognizedInputs) {
        final resolved = DrugScheduleResolver.fromRaw(input);
        expect(
          resolved,
          CanonicalDrugSchedule.unrecognized,
          reason: '"$input" must resolve to unrecognized.',
        );
        expect(
          DrugScheduleResolver.isScheduled(resolved),
          isFalse,
          reason: '"$input" (unrecognized) must not be scheduled.',
        );
      }
    });
  });
}
