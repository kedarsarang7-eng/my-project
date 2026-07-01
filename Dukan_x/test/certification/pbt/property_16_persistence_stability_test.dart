// Feature: comprehensive-test-certification, Property 16
// ============================================================================
// Property 16: Traceability persistence is stable across no-op cycles.
// **Validates: Requirements 13.5**
// ============================================================================
// For any persisted Traceability_Matrix, running a certification cycle that
// commits no entry change leaves every prior entry unchanged; entries are
// retained until explicitly updated.
//
// Test approach: serialize → deserialize → compare entries (same requirement
// IDs, same testCaseIds, same isCoverageGap flags). A no-op persist/load cycle
// preserves all prior entries unchanged.
//
// Unit under test: `TraceabilityMatrix` from `../core/traceability_matrix.dart`.
//
// PBT library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test test/certification/pbt/property_16_persistence_stability_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/traceability_matrix.dart';
import 'generators.dart';

void main() {
  group('Feature: comprehensive-test-certification, Property 16: '
      'Traceability persistence is stable across no-op cycles', () {
    test('Property 16a: For any matrix with entries, serialize then deserialize '
        'produces entries with the same requirementIds, testCaseIds, and '
        'isCoverageGap flags', () {
      final held = forAll(
        (int entryCount, int seedA, int seedB) {
          // Generate 1–10 entries with varying data.
          final numEntries = (entryCount.abs() % 10) + 1;
          final entries = <TraceEntry>[];

          for (var i = 0; i < numEntries; i++) {
            // Generate requirement IDs deterministically from seeds.
            final reqId = 'REQ-${(seedA.abs() + i) % 10000}';

            // Some entries have test cases (not a coverage gap), others don't.
            final hasTestCases = (seedB.abs() + i) % 3 != 0;
            final testCaseIds = hasTestCases
                ? List.generate(
                    (seedA.abs() + i) % 5 + 1,
                    (j) => 'TC-${(seedA.abs() + i * 10 + j) % 9999}',
                  )
                : <String>[];

            // Generate some defect IDs and resolution links.
            final defectIds = List.generate(
              (seedB.abs() + i) % 3,
              (j) => 'DEF-${(seedB.abs() + i * 7 + j) % 9999}',
            );
            final resolutionLinks = List.generate(
              (seedA.abs() + i) % 2,
              (j) => 'RES-${(seedA.abs() + i * 3 + j) % 9999}',
            );

            // Generate latest results tied to test case IDs.
            final latestResults = testCaseIds
                .map(
                  (tcId) => TestResult(
                    testCaseId: tcId,
                    passed: (seedB.abs() + i) % 2 == 0,
                    runAt: DateTime(2025, 1, 1 + (i % 28)),
                  ),
                )
                .toList();

            entries.add(
              TraceEntry(
                requirementId: reqId,
                testCaseIds: testCaseIds,
                latestResults: latestResults,
                defectIds: defectIds,
                resolutionLinks: resolutionLinks,
              ),
            );
          }

          // Create the matrix with generated entries.
          final matrix = TraceabilityMatrix.fromEntries(entries);

          // Serialize → Deserialize (no-op persist/load cycle).
          final serialized = matrix.serialize();
          final restored = TraceabilityMatrix.deserialize(serialized);

          // Verify the same number of entries.
          if (restored.length != matrix.length) return false;

          // Verify each entry is preserved unchanged.
          for (final original in matrix.entries) {
            final restoredEntry = restored.getEntry(original.requirementId);
            if (restoredEntry == null) return false;

            // Same requirement ID.
            if (restoredEntry.requirementId != original.requirementId) {
              return false;
            }

            // Same testCaseIds.
            if (restoredEntry.testCaseIds.length !=
                original.testCaseIds.length) {
              return false;
            }
            for (var i = 0; i < original.testCaseIds.length; i++) {
              if (restoredEntry.testCaseIds[i] != original.testCaseIds[i]) {
                return false;
              }
            }

            // Same isCoverageGap flag.
            if (restoredEntry.isCoverageGap != original.isCoverageGap) {
              return false;
            }

            // Same defectIds.
            if (restoredEntry.defectIds.length != original.defectIds.length) {
              return false;
            }
            for (var i = 0; i < original.defectIds.length; i++) {
              if (restoredEntry.defectIds[i] != original.defectIds[i]) {
                return false;
              }
            }

            // Same resolutionLinks.
            if (restoredEntry.resolutionLinks.length !=
                original.resolutionLinks.length) {
              return false;
            }
            for (var i = 0; i < original.resolutionLinks.length; i++) {
              if (restoredEntry.resolutionLinks[i] !=
                  original.resolutionLinks[i]) {
                return false;
              }
            }

            // Same latestResults.
            if (restoredEntry.latestResults.length !=
                original.latestResults.length) {
              return false;
            }
            for (var i = 0; i < original.latestResults.length; i++) {
              if (restoredEntry.latestResults[i].testCaseId !=
                  original.latestResults[i].testCaseId) {
                return false;
              }
              if (restoredEntry.latestResults[i].passed !=
                  original.latestResults[i].passed) {
                return false;
              }
            }
          }

          return true;
        },
        [Gen.interval(1, 100), Gen.interval(0, 99999), Gen.interval(0, 99999)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    test('Property 16b: Multiple serialize/deserialize cycles (no-op) '
        'produce identical entries each time', () {
      final held = forAll(
        (int entryCount, int seed) {
          // Generate 1–8 entries.
          final numEntries = (entryCount.abs() % 8) + 1;
          final entries = <TraceEntry>[];

          for (var i = 0; i < numEntries; i++) {
            final reqId = 'REQ-${(seed.abs() + i * 13) % 5000}';
            final hasTests = (seed.abs() + i) % 2 == 0;
            final testCaseIds = hasTests
                ? [
                    'TC-${(seed.abs() + i) % 999}',
                    'TC-${(seed.abs() + i + 1) % 999}',
                  ]
                : <String>[];

            entries.add(
              TraceEntry(
                requirementId: reqId,
                testCaseIds: testCaseIds,
                defectIds: i % 2 == 0 ? ['DEF-${i}'] : [],
                resolutionLinks: i % 3 == 0 ? ['RES-${i}'] : [],
                latestResults: testCaseIds
                    .map(
                      (tc) => TestResult(
                        testCaseId: tc,
                        passed: true,
                        runAt: DateTime(2025, 6, 1),
                      ),
                    )
                    .toList(),
              ),
            );
          }

          final matrix = TraceabilityMatrix.fromEntries(entries);

          // Run 3 no-op serialize/deserialize cycles.
          var current = matrix;
          for (var cycle = 0; cycle < 3; cycle++) {
            final json = current.serialize();
            current = TraceabilityMatrix.deserialize(json);
          }

          // After 3 cycles, entries must still match original.
          if (current.length != matrix.length) return false;

          for (final original in matrix.entries) {
            final cycled = current.getEntry(original.requirementId);
            if (cycled == null) return false;
            if (cycled.requirementId != original.requirementId) return false;
            if (cycled.testCaseIds.length != original.testCaseIds.length) {
              return false;
            }
            if (cycled.isCoverageGap != original.isCoverageGap) return false;
            if (cycled.defectIds.length != original.defectIds.length) {
              return false;
            }
            if (cycled.resolutionLinks.length !=
                original.resolutionLinks.length) {
              return false;
            }
          }

          return true;
        },
        [Gen.interval(1, 50), Gen.interval(0, 99999)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    test('Property 16c: Coverage-gap flag is preserved exactly through '
        'serialize/deserialize when no changes are applied', () {
      final held = forAll(
        (int seed) {
          // Create entries: some with test cases (not gaps) and some without (gaps).
          final entries = <TraceEntry>[
            TraceEntry(
              requirementId: 'REQ-GAP-${seed.abs() % 1000}',
              testCaseIds: [], // coverage gap
            ),
            TraceEntry(
              requirementId: 'REQ-OK-${seed.abs() % 1000}',
              testCaseIds: ['TC-1'], // not a gap
              latestResults: [
                TestResult(
                  testCaseId: 'TC-1',
                  passed: true,
                  runAt: DateTime(2025, 1, 1),
                ),
              ],
            ),
            TraceEntry(
              requirementId: 'REQ-GAP2-${seed.abs() % 1000}',
              testCaseIds: [], // coverage gap
              defectIds: ['DEF-${seed.abs() % 100}'],
            ),
          ];

          final matrix = TraceabilityMatrix.fromEntries(entries);

          // Serialize then deserialize (no-op cycle).
          final json = matrix.serialize();
          final restored = TraceabilityMatrix.deserialize(json);

          // Verify gap flags preserved.
          final gap1 = restored.getEntry('REQ-GAP-${seed.abs() % 1000}');
          final ok1 = restored.getEntry('REQ-OK-${seed.abs() % 1000}');
          final gap2 = restored.getEntry('REQ-GAP2-${seed.abs() % 1000}');

          if (gap1 == null || ok1 == null || gap2 == null) return false;

          // Gaps remain gaps, non-gaps remain non-gaps.
          return gap1.isCoverageGap == true &&
              ok1.isCoverageGap == false &&
              gap2.isCoverageGap == true;
        },
        [Gen.interval(0, 99999)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });
  });
}
