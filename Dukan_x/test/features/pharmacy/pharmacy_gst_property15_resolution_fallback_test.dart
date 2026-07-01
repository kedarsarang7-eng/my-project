// ============================================================================
// TASK 8.2 — PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 15: GST rate resolution
//          with fallback
// **Validates: Requirements 11.2, 11.3, 11.4**
// ============================================================================
//
// Property 15 (design.md — Correctness Properties):
//   "For any schedule/HSN key, the resolved GST rate equals the mapped rate
//    when the key matches an entry in the pharmacy mapping; for an unmatched,
//    null, empty, or missing key, the resolved rate is the 12% fallback and the
//    result is flagged as having used the fallback."
//
// HOW THIS IS PROVEN AS A PROPERTY (controlled, injected mappings):
//   `PharmacyGstResolver` takes optional `hsnOverlay`/`scheduleOverlay`
//   constructor maps, so we inject KNOWN mappings whose keys and rates we fully
//   control. The injected rates are drawn from the supported slabs {0,5,18,28}
//   (deliberately excluding 12 so a "matched" hit can never be confused with
//   the 12% fallback). We then generate keys both INSIDE and OUTSIDE the map:
//
//     * Matched HSN keys  → resolved rate == injected rate, usedFallback==false.
//       (The HSN overlay takes precedence over the shared statutory table, so a
//        matched overlay key resolves deterministically regardless of it.)
//     * Matched schedule keys (HSN null) → resolved rate == injected rate,
//       usedFallback==false.
//     * Unmatched keys (smart generator guarantees no overlay match, HSN null
//       so the shared table is never consulted) → 12% fallback, flagged true.
//
//   The unmatched generator is constrained to the input space intelligently: a
//   guaranteed-non-matching prefix is prepended so the normalized schedule can
//   never collide with an injected overlay key (which are length ≤ 3 and never
//   start with the prefix). This proves fallback for arbitrary out-of-map keys
//   without re-implementing the resolver's matching logic.
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide. `forAll((a) => <bool>, [genA], numRuns: N)` returns true
//   when the property held for every run and throws a shrinking counterexample
//   otherwise.
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/features/pharmacy/pharmacy_gst_property15_resolution_fallback_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/pharmacy/pharmacy_gst_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// At least 100 generated cases are required by the spec (R5.4); 200 matches
/// the dartproptest default and the convention used across this repo's suites.
const int kNumRuns = 200;

void main() {
  group('Feature: pharmacy-vertical-remediation, Property 15: GST rate resolution '
      'with fallback — Req 11.2, 11.3, 11.4', () {
    // ----------------------------------------------------------------------
    // Injected, fully-controlled mappings. Rates are drawn from the supported
    // slabs but DELIBERATELY EXCLUDE 12 so a genuine match can never be mistaken
    // for the 12% fallback. Keys are short (≤3 chars) and lowercase-normalizable.
    // ----------------------------------------------------------------------
    const Map<String, int> hsnOverlay = <String, int>{
      'AAAA': 5,
      'BBBB': 18,
      'CCCC': 28,
      'DDDD': 0,
      'EEEE': 5,
    };
    // Schedule overlay keys are stored normalized (lowercase, no separators,
    // no 'schedule' token), matching how `_resolveSchedule` normalizes input.
    const Map<String, int> scheduleOverlay = <String, int>{
      'h': 5,
      'h1': 18,
      'x': 28,
      'otc': 0,
    };

    final resolver = PharmacyGstResolver(
      hsnOverlay: hsnOverlay,
      scheduleOverlay: scheduleOverlay,
    );

    final List<String> hsnKeys = hsnOverlay.keys.toList();
    final List<String> scheduleKeys = scheduleOverlay.keys.toList();

    // ----------------------------------------------------------------------
    // Property 15.1 — Matched HSN key resolves to the mapped rate (R11.2).
    // ----------------------------------------------------------------------
    test('Property 15a: a key matching an HSN mapping entry resolves to that '
        "entry's rate with usedFallback == false", () {
      final bool held = forAll(
        (String key) {
          final result = resolver.resolve(hsn: key);
          return result.ratePercent == hsnOverlay[key] &&
              result.usedFallback == false;
        },
        [Gen.elementOf<String>(hsnKeys)],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason:
            'A matched HSN key must resolve to its mapped rate and must '
            'not be flagged as a fallback.',
      );
    });

    // ----------------------------------------------------------------------
    // Property 15.2 — Matched schedule key resolves to the mapped rate (R11.2).
    // HSN is null so resolution falls through to the schedule overlay.
    // ----------------------------------------------------------------------
    test(
      'Property 15b: a key matching a schedule mapping entry resolves to that '
      "entry's rate with usedFallback == false",
      () {
        final bool held = forAll(
          (String key) {
            final result = resolver.resolve(schedule: key);
            return result.ratePercent == scheduleOverlay[key] &&
                result.usedFallback == false;
          },
          [Gen.elementOf<String>(scheduleKeys)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'A matched schedule key must resolve to its mapped rate and '
              'must not be flagged as a fallback.',
        );
      },
    );

    // ----------------------------------------------------------------------
    // Property 15.3 — Unmatched key falls back to 12% flagged (R11.3).
    // The generated key carries a guaranteed-non-matching prefix and is passed
    // as the schedule (HSN null), so the shared statutory table is never
    // consulted and the input can never collide with an injected overlay key.
    // ----------------------------------------------------------------------
    test(
      'Property 15c: any key outside the mapping resolves to the 12% fallback '
      'with usedFallback == true',
      () {
        final bool held = forAll(
          (String suffix) {
            // 'zq' guarantees the normalized value starts with 'zq', so it can
            // never equal an injected overlay key ('h', 'h1', 'x', 'otc').
            final String unmatchedKey = 'zq$suffix';
            final result = resolver.resolve(schedule: unmatchedKey);
            return result.ratePercent ==
                    PharmacyGstResolver.fallbackRatePercent &&
                result.usedFallback == true;
          },
          [Gen.string(minLength: 0, maxLength: 12)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'An unmatched key must resolve to the 12% fallback flagged as '
              'usedFallback == true.',
        );
      },
    );

    // ----------------------------------------------------------------------
    // Property 15.4 — null / empty / missing keys fall back to 12% (R11.4).
    // ----------------------------------------------------------------------
    test('Property 15d: null, empty, whitespace, and missing keys resolve to '
        'the 12% flagged fallback', () {
      const int fallback = PharmacyGstResolver.fallbackRatePercent;

      // Both missing (the "missing key" case).
      expect(
        resolver.resolve(),
        const GstResolution(ratePercent: fallback, usedFallback: true),
      );
      // Explicit nulls.
      expect(
        resolver.resolve(hsn: null, schedule: null),
        const GstResolution(ratePercent: fallback, usedFallback: true),
      );
      // Empty strings.
      expect(
        resolver.resolve(hsn: ''),
        const GstResolution(ratePercent: fallback, usedFallback: true),
      );
      expect(
        resolver.resolve(schedule: ''),
        const GstResolution(ratePercent: fallback, usedFallback: true),
      );
      // Whitespace-only (normalizes/trims to empty).
      expect(
        resolver.resolve(hsn: '   '),
        const GstResolution(ratePercent: fallback, usedFallback: true),
      );
      expect(
        resolver.resolve(schedule: '   '),
        const GstResolution(ratePercent: fallback, usedFallback: true),
      );
    });

    // ----------------------------------------------------------------------
    // Deterministic anchors — prove the property is non-vacuous and pin
    // precedence + schedule normalization behavior exactly.
    // ----------------------------------------------------------------------
    test('Property 15 anchors: matched precedence and normalization', () {
      // HSN match (exact key).
      expect(resolver.resolve(hsn: 'AAAA').ratePercent, 5);
      expect(resolver.resolve(hsn: 'AAAA').usedFallback, isFalse);
      expect(resolver.resolve(hsn: 'CCCC').ratePercent, 28);

      // Schedule match with normalization (case/separator/'schedule' token).
      expect(resolver.resolve(schedule: 'h').ratePercent, 5);
      expect(resolver.resolve(schedule: 'Schedule-H1').ratePercent, 18);
      expect(resolver.resolve(schedule: ' X ').ratePercent, 28);
      expect(resolver.resolve(schedule: 'OTC').ratePercent, 0);

      // HSN takes precedence over schedule when both match.
      final both = resolver.resolve(hsn: 'BBBB', schedule: 'h');
      expect(both.ratePercent, 18); // BBBB -> 18, not schedule 'h' -> 5
      expect(both.usedFallback, isFalse);

      // Every resolved rate is a supported statutory slab.
      for (final key in [...hsnOverlay.keys]) {
        expect(
          PharmacyGstResolver.supportedRates.contains(
            resolver.resolve(hsn: key).ratePercent,
          ),
          isTrue,
        );
      }
    });
  });
}
