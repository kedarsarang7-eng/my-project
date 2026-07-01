// ============================================================================
// PHARMACY VERTICAL REMEDIATION — Task 17.2: PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 27: Batch tracking loads in
//          bounded page segments
// **Validates: Requirements 20.1**
// ============================================================================
//
// Implementation under test:
//   lib/features/inventory/utils/batch_pagination.dart — the pure segment
//   arithmetic used by `BatchTrackingScreen` (which wires its private
//   `_pageSize` / `_visibleCount` / `_hasMore` logic to these helpers).
//
// Requirement 20.1: BatchTrackingScreen retrieves records in paginated
// segments of a FIXED page size between 20 and 50 records per segment rather
// than loading all records in a single request.
//
// Property 27 (for any total record count N and the fixed page size P):
//   (a) P is fixed and lies within the inclusive range [20, 50];
//   (b) every loaded segment has size <= P (bounded segments);
//   (c) the segments partition the N records with no gaps and no overlaps;
//   (d) the number of segments equals ceil(N / P);
//   (e) the revealed-window / hasMore arithmetic is consistent for any N:
//       after the final segment the window equals N and hasMore is false.
//
// PBT library: dartproptest ^0.2.1 (the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide). `forAll((args) => <bool>, [gens], numRuns: N)` returns
//   true when the property held for every run and throws a shrinking Exception
//   with a counterexample otherwise. numRuns: 200 (> the 100-case minimum).
//
// Run: flutter test test/features/inventory/batch_pagination_property27_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/features/inventory/utils/batch_pagination.dart';
import 'package:flutter_test/flutter_test.dart';

/// At least 100 iterations are required; 200 is the repo convention.
const int kNumRuns = 200;

void main() {
  // Any total record count from an empty catalog up to a large pharmacy
  // inventory. Includes 0 and values that are exact and non-exact multiples
  // of the page size.
  final Generator<int> totalCountGen = Gen.interval(0, 5000);

  const int pageSize = kBatchTrackingPageSize;

  group('Feature: pharmacy-vertical-remediation, Property 27: Batch tracking '
      'loads in bounded page segments', () {
    test('Property 27a: the fixed page size lies within [20, 50] (R20.1)', () {
      expect(pageSize, greaterThanOrEqualTo(20));
      expect(pageSize, lessThanOrEqualTo(50));
    });

    test(
      'Property 27b: every loaded segment has size <= the fixed page size',
      () {
        final bool held = forAll(
          (int total) {
            final segments = batchSegments(total);
            return segments.every((s) => s.limit <= pageSize && s.limit > 0);
          },
          [totalCountGen],
          numRuns: kNumRuns,
        );

        expect(
          held,
          isTrue,
          reason:
              'No segment may exceed the fixed page size; segments are '
              'bounded so the catalog never loads in one request (R20.1).',
        );
      },
    );

    test(
      'Property 27c: segments partition the records with no gaps/overlaps',
      () {
        final bool held = forAll(
          (int total) {
            final segments = batchSegments(total);

            // First segment starts at 0 (when any records exist).
            if (total > 0 && segments.first.offset != 0) return false;

            // Contiguous & non-overlapping: each segment begins exactly where
            // the previous one ended.
            var cursor = 0;
            for (final s in segments) {
              if (s.offset != cursor) return false; // gap or overlap
              cursor = s.end;
            }

            // The union of all segments covers exactly [0, total).
            return cursor == total;
          },
          [totalCountGen],
          numRuns: kNumRuns,
        );

        expect(
          held,
          isTrue,
          reason:
              'Segments must tile the record range [0, N) contiguously with '
              'no gaps and no overlaps for any total record count.',
        );
      },
    );

    test('Property 27d: the number of segments equals ceil(N / P)', () {
      final bool held = forAll(
        (int total) {
          final expected = total <= 0
              ? 0
              : (total + pageSize - 1) ~/ pageSize; // ceil
          return batchSegments(total).length == expected &&
              batchSegmentCount(total) == expected;
        },
        [totalCountGen],
        numRuns: kNumRuns,
      );

      expect(
        held,
        isTrue,
        reason: 'The segment count must be ceil(N / P) for any total N.',
      );
    });

    test('Property 27e: revealed-window / hasMore arithmetic is consistent for '
        'any N (window grows one page per load, ends exactly at N)', () {
      final bool held = forAll(
        (int total) {
          final segmentCount = batchSegmentCount(total);

          // Walk the window one segment at a time, mirroring the screen's
          // _visibleCount growth and _hasMore decision.
          for (var loaded = 0; loaded <= segmentCount; loaded++) {
            final visible = batchVisibleCount(total, loaded);

            // The revealed window never exceeds the total or a whole-page step.
            if (visible > total) return false;
            if (visible > loaded * pageSize) return false;

            final hasMore = batchHasMore(total, visible);
            final isFinal = loaded >= segmentCount;

            // hasMore must be true exactly while unrevealed records remain.
            if (isFinal) {
              if (visible != total || hasMore) return false;
            } else {
              if (!hasMore) return false;
            }
          }
          return true;
        },
        [totalCountGen],
        numRuns: kNumRuns,
      );

      expect(
        held,
        isTrue,
        reason:
            'After the final segment the window must equal N with '
            'hasMore=false; before that hasMore must remain true (R20.1).',
      );
    });
  });
}
