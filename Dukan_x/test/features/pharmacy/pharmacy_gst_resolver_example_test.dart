// ============================================================================
// TASK 8.3 — UNIT TESTS (example-based) for PharmacyGstResolver
// Feature: pharmacy-vertical-remediation, Requirement 11.6
// **Validates: Requirements 11.6**
// ============================================================================
//
// Requirement 11.6:
//   "THE System SHALL include automated tests that verify GST resolution and
//    computed paise amounts for each of the 5%, 12%, and 18% mapped-rate cases
//    and for the unmatched-schedule/HSN fallback case."
//
// These are EXAMPLE-BASED unit tests (representative cases + edge cases) that
// complement the property tests elsewhere in this feature. They assert:
//   * resolve(...) returns the expected rate (usedFallback=false) for
//     representative 5% / 12% / 18% HSN keys from the default overlay.
//   * an unmatched HSN key (and null/empty input) resolves to the 12% fallback
//     with usedFallback=true.
//   * gstAmountPaise(...) computes the correct integer-paise amount, including
//     a round-half-up tie case (fractional .5 paise rounds toward +∞).
//   * resolveAmount(...) wires resolution + amount together.
//
// TEST-ONLY: no production code is changed by this task.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/pharmacy/pharmacy_gst_resolver.dart';

void main() {
  final resolver = PharmacyGstResolver();

  group(
    'PharmacyGstResolver.resolve — mapped HSN rates (usedFallback=false)',
    () {
      test('5% slab: HSN 3002 resolves to 5%', () {
        expect(
          resolver.resolve(hsn: '3002'),
          const GstResolution(ratePercent: 5, usedFallback: false),
        );
      });

      test('12% slab: HSN 3004 resolves to 12%', () {
        expect(
          resolver.resolve(hsn: '3004'),
          const GstResolution(ratePercent: 12, usedFallback: false),
        );
      });

      test('18% slab: HSN 3401 resolves to 18%', () {
        expect(
          resolver.resolve(hsn: '3401'),
          const GstResolution(ratePercent: 18, usedFallback: false),
        );
      });
    },
  );

  group('PharmacyGstResolver.resolve — fallback (usedFallback=true)', () {
    test('unmatched HSN key falls back to 12% and flags fallback', () {
      expect(
        resolver.resolve(hsn: '9999'),
        const GstResolution(ratePercent: 12, usedFallback: true),
      );
    });

    test('null HSN and schedule falls back to 12% and flags fallback', () {
      expect(
        resolver.resolve(),
        const GstResolution(ratePercent: 12, usedFallback: true),
      );
    });

    test('empty/whitespace HSN falls back to 12% and flags fallback', () {
      expect(
        resolver.resolve(hsn: '   '),
        const GstResolution(ratePercent: 12, usedFallback: true),
      );
    });
  });

  group('PharmacyGstResolver.gstAmountPaise — integer-paise amounts', () {
    test('taxable 10000 paise @ 5% = 500 paise', () {
      expect(
        resolver.gstAmountPaise(taxableAmountPaise: 10000, ratePercent: 5),
        500,
      );
    });

    test('taxable 10000 paise @ 12% = 1200 paise', () {
      expect(
        resolver.gstAmountPaise(taxableAmountPaise: 10000, ratePercent: 12),
        1200,
      );
    });

    test('taxable 10000 paise @ 18% = 1800 paise', () {
      expect(
        resolver.gstAmountPaise(taxableAmountPaise: 10000, ratePercent: 18),
        1800,
      );
    });

    test('round-half-up tie: 10 paise @ 5% = 0.5 paise rounds up to 1', () {
      // 10 * 5 / 100 = 0.5 -> round-half-up -> 1
      expect(
        resolver.gstAmountPaise(taxableAmountPaise: 10, ratePercent: 5),
        1,
      );
    });

    test('round-half-up tie: 25 paise @ 18% = 4.5 paise rounds up to 5', () {
      // 25 * 18 / 100 = 4.5 -> round-half-up -> 5
      expect(
        resolver.gstAmountPaise(taxableAmountPaise: 25, ratePercent: 18),
        5,
      );
    });
  });

  group('PharmacyGstResolver.resolveAmount — resolution + amount together', () {
    test(
      'HSN 3004 (12%) on taxable 10000 paise yields 1200 paise, no fallback',
      () {
        final result = resolver.resolveAmount(
          taxableAmountPaise: 10000,
          hsn: '3004',
        );
        expect(
          result.resolution,
          const GstResolution(ratePercent: 12, usedFallback: false),
        );
        expect(result.gstPaise, 1200);
      },
    );

    test(
      'unmatched HSN on taxable 10000 paise applies 12% fallback amount',
      () {
        final result = resolver.resolveAmount(
          taxableAmountPaise: 10000,
          hsn: '9999',
        );
        expect(
          result.resolution,
          const GstResolution(ratePercent: 12, usedFallback: true),
        );
        expect(result.gstPaise, 1200);
      },
    );
  });
}
