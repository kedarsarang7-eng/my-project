// Feature: comprehensive-test-certification, Property 11
// ============================================================================
// Property 11: Performance gate is green only when every metric is measured
// and within threshold.
//
// For any set of performance measurements, the Performance Quality_Gate is
// green if and only if every required metric was measured and its measured value
// is at or within its defined threshold; otherwise the gate fails and exactly
// one Defect is recorded per offending metric, identifying the metric, its
// measured value (or not-measured), and its threshold, while all measurements
// are retained.
//
// Test directions:
//   1. FORWARD: All measurements non-null and within threshold → green
//   2. REJECTION: Any measurement null (not measured) → notGreen
//   3. REJECTION: Any measurement exceeding threshold → notGreen
//   4. For fps metric: within means measured >= threshold;
//      for time metrics: within means measured <= threshold
//
// **Validates: Requirements 9.3, 9.4, 9.6**
//
// PBT library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test test/certification/pbt/property_11_performance_gate_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/gate_reducer.dart';
import 'generators.dart';

// ============================================================================
// GENERATORS
// ============================================================================

/// The four required performance metrics.
const List<String> _timeMetrics = ['coldStart', 'reportGen', 'sync'];
const String _fpsMetric = 'fps';
const List<String> _allMetrics = [..._timeMetrics, _fpsMetric];

/// Generates a threshold source (default or tuned).
final Generator<ThresholdSource> _thresholdSourceGen =
    Gen.elementOf<ThresholdSource>(ThresholdSource.values);

/// Generates a dataset record count (realistic range).
final Generator<int> _datasetRecordsGen = Gen.interval(10000, 100000);

/// Generates a positive threshold value for time-based metrics.
final Generator<int> _timeThresholdGen = Gen.interval(1000, 120000);

/// Generates a positive threshold value for fps metric.
final Generator<int> _fpsThresholdGen = Gen.interval(15, 120);

/// Generates a "within" measured value for a time metric (measured <= threshold).
Generator<num> _withinTimeValueGen(int threshold) =>
    Gen.interval(0, threshold).map((v) => v as num);

/// Generates a "within" measured value for fps metric (measured >= threshold).
Generator<num> _withinFpsValueGen(int threshold) =>
    Gen.interval(threshold, threshold + 200).map((v) => v as num);

/// Generates a "violating" measured value for a time metric (measured > threshold).
Generator<num> _exceedingTimeValueGen(int threshold) =>
    Gen.interval(threshold + 1, threshold + 50000).map((v) => v as num);

/// Generates a "violating" measured value for fps metric (measured < threshold).
Generator<num> _belowFpsValueGen(int threshold) =>
    Gen.interval(0, threshold - 1).map((v) => v as num);

// ============================================================================
// TESTS
// ============================================================================

void main() {
  const reducer = GateStatusReducer();

  group('Property 11: Performance gate is green only when every metric is '
      'measured and within threshold', () {
    // ========================================================================
    // Direction 1: FORWARD — all measurements within threshold → green
    // ========================================================================
    test('FORWARD: All measurements non-null and within threshold → green', () {
      final held = forAll(
        (
          int coldThreshold,
          int reportThreshold,
          int syncThreshold,
          int fpsThreshold,
          int datasetRecords,
          ThresholdSource source,
        ) {
          // Build measurements where all are within their threshold.
          final measurements = <PerfMeasurement>[
            PerfMeasurement(
              metric: 'coldStart',
              measured: coldThreshold - (coldThreshold ~/ 2), // within
              threshold: coldThreshold,
              source: source,
              datasetRecords: datasetRecords,
            ),
            PerfMeasurement(
              metric: 'reportGen',
              measured: reportThreshold - (reportThreshold ~/ 2), // within
              threshold: reportThreshold,
              source: source,
              datasetRecords: datasetRecords,
            ),
            PerfMeasurement(
              metric: 'sync',
              measured: syncThreshold - (syncThreshold ~/ 2), // within
              threshold: syncThreshold,
              source: source,
              datasetRecords: datasetRecords,
            ),
            PerfMeasurement(
              metric: 'fps',
              measured:
                  fpsThreshold + 10, // within (fps: measured >= threshold)
              threshold: fpsThreshold,
              source: source,
              datasetRecords: datasetRecords,
            ),
          ];

          final status = reducer.reducePerformance(measurements);

          // All within → must be green
          return status == GateStatus.green;
        },
        [
          _timeThresholdGen,
          _timeThresholdGen,
          _timeThresholdGen,
          _fpsThresholdGen,
          _datasetRecordsGen,
          _thresholdSourceGen,
        ],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // Also test exact-at-threshold → green (boundary)
    test('FORWARD: Measurements exactly at threshold → green', () {
      final held = forAll(
        (
          int coldThreshold,
          int reportThreshold,
          int syncThreshold,
          int fpsThreshold,
          int datasetRecords,
          ThresholdSource source,
        ) {
          // Exactly at threshold for all metrics.
          final measurements = <PerfMeasurement>[
            PerfMeasurement(
              metric: 'coldStart',
              measured: coldThreshold, // exactly at
              threshold: coldThreshold,
              source: source,
              datasetRecords: datasetRecords,
            ),
            PerfMeasurement(
              metric: 'reportGen',
              measured: reportThreshold, // exactly at
              threshold: reportThreshold,
              source: source,
              datasetRecords: datasetRecords,
            ),
            PerfMeasurement(
              metric: 'sync',
              measured: syncThreshold, // exactly at
              threshold: syncThreshold,
              source: source,
              datasetRecords: datasetRecords,
            ),
            PerfMeasurement(
              metric: 'fps',
              measured: fpsThreshold, // exactly at (fps: >= threshold)
              threshold: fpsThreshold,
              source: source,
              datasetRecords: datasetRecords,
            ),
          ];

          final status = reducer.reducePerformance(measurements);
          return status == GateStatus.green;
        },
        [
          _timeThresholdGen,
          _timeThresholdGen,
          _timeThresholdGen,
          _fpsThresholdGen,
          _datasetRecordsGen,
          _thresholdSourceGen,
        ],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ========================================================================
    // Direction 2: REJECTION — any measurement null (not measured) → notGreen
    // ========================================================================
    test('REJECTION: Any measurement null (not measured) → notGreen', () {
      final held = forAll(
        (
          int metricIdx,
          int coldThreshold,
          int fpsThreshold,
          int datasetRecords,
          ThresholdSource source,
        ) {
          // Pick which metric will be null
          final nullMetricIndex = metricIdx % _allMetrics.length;

          final measurements = <PerfMeasurement>[];
          for (int i = 0; i < _allMetrics.length; i++) {
            final metric = _allMetrics[i];
            final threshold = metric == 'fps' ? fpsThreshold : coldThreshold;
            final num? measured;
            if (i == nullMetricIndex) {
              measured = null; // This one is not measured
            } else {
              // Within threshold
              measured = metric == 'fps'
                  ? fpsThreshold + 5
                  : coldThreshold - 100;
            }

            measurements.add(
              PerfMeasurement(
                metric: metric,
                measured: measured,
                threshold: threshold,
                source: source,
                datasetRecords: datasetRecords,
              ),
            );
          }

          final status = reducer.reducePerformance(measurements);

          // Must be notGreen because one metric is null
          return status == GateStatus.notGreen;
        },
        [
          Gen.interval(0, 100),
          _timeThresholdGen,
          _fpsThresholdGen,
          _datasetRecordsGen,
          _thresholdSourceGen,
        ],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ========================================================================
    // Direction 3: REJECTION — any measurement exceeding threshold → notGreen
    // ========================================================================
    test('REJECTION: Any time metric exceeding threshold → notGreen', () {
      final held = forAll(
        (
          int metricIdx,
          int coldThreshold,
          int reportThreshold,
          int syncThreshold,
          int fpsThreshold,
          int datasetRecords,
          ThresholdSource source,
        ) {
          // Pick which time metric will exceed its threshold
          final violatingIdx = metricIdx % _timeMetrics.length;

          final thresholds = [coldThreshold, reportThreshold, syncThreshold];
          final measurements = <PerfMeasurement>[];

          for (int i = 0; i < _timeMetrics.length; i++) {
            final threshold = thresholds[i];
            final num measured;
            if (i == violatingIdx) {
              measured = threshold + 1; // Exceeds threshold
            } else {
              measured = threshold - 1; // Within threshold
            }
            measurements.add(
              PerfMeasurement(
                metric: _timeMetrics[i],
                measured: measured,
                threshold: threshold,
                source: source,
                datasetRecords: datasetRecords,
              ),
            );
          }

          // Add a passing fps metric
          measurements.add(
            PerfMeasurement(
              metric: 'fps',
              measured: fpsThreshold + 5,
              threshold: fpsThreshold,
              source: source,
              datasetRecords: datasetRecords,
            ),
          );

          final status = reducer.reducePerformance(measurements);
          return status == GateStatus.notGreen;
        },
        [
          Gen.interval(0, 100),
          _timeThresholdGen,
          _timeThresholdGen,
          _timeThresholdGen,
          _fpsThresholdGen,
          _datasetRecordsGen,
          _thresholdSourceGen,
        ],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    test('REJECTION: fps metric below threshold → notGreen', () {
      final held = forAll(
        (
          int coldThreshold,
          int reportThreshold,
          int syncThreshold,
          int fpsThreshold,
          int datasetRecords,
          ThresholdSource source,
        ) {
          // Ensure fps threshold > 0 so we can go below it
          final effectiveFpsThreshold = fpsThreshold < 2 ? 2 : fpsThreshold;

          final measurements = <PerfMeasurement>[
            PerfMeasurement(
              metric: 'coldStart',
              measured: coldThreshold - 1, // within
              threshold: coldThreshold,
              source: source,
              datasetRecords: datasetRecords,
            ),
            PerfMeasurement(
              metric: 'reportGen',
              measured: reportThreshold - 1, // within
              threshold: reportThreshold,
              source: source,
              datasetRecords: datasetRecords,
            ),
            PerfMeasurement(
              metric: 'sync',
              measured: syncThreshold - 1, // within
              threshold: syncThreshold,
              source: source,
              datasetRecords: datasetRecords,
            ),
            PerfMeasurement(
              metric: 'fps',
              measured: effectiveFpsThreshold - 1, // BELOW threshold → fail
              threshold: effectiveFpsThreshold,
              source: source,
              datasetRecords: datasetRecords,
            ),
          ];

          final status = reducer.reducePerformance(measurements);
          return status == GateStatus.notGreen;
        },
        [
          _timeThresholdGen,
          _timeThresholdGen,
          _timeThresholdGen,
          _fpsThresholdGen,
          _datasetRecordsGen,
          _thresholdSourceGen,
        ],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ========================================================================
    // Direction 4: Defect generation — exactly one defect per offending metric
    // ========================================================================
    test('DEFECTS: Exactly one defect per offending metric with measurements '
        'retained', () {
      final held = forAll(
        (
          int coldThreshold,
          int fpsThreshold,
          int datasetRecords,
          ThresholdSource source,
        ) {
          // Create measurements: coldStart exceeds, fps below, others fine
          final measurements = <PerfMeasurement>[
            PerfMeasurement(
              metric: 'coldStart',
              measured: coldThreshold + 500, // exceeds
              threshold: coldThreshold,
              source: source,
              datasetRecords: datasetRecords,
            ),
            PerfMeasurement(
              metric: 'reportGen',
              measured: 100, // within (any reasonable threshold)
              threshold: coldThreshold, // reuse for simplicity, still within
              source: source,
              datasetRecords: datasetRecords,
            ),
            PerfMeasurement(
              metric: 'sync',
              measured: null, // not measured
              threshold: coldThreshold,
              source: source,
              datasetRecords: datasetRecords,
            ),
            PerfMeasurement(
              metric: 'fps',
              measured: fpsThreshold + 10, // within (fps: >= threshold)
              threshold: fpsThreshold,
              source: source,
              datasetRecords: datasetRecords,
            ),
          ];

          final defects = reducer.performanceDefects(measurements);

          // Exactly 2 offending metrics: coldStart (exceeds) and sync (null)
          if (defects.length != 2) return false;

          // Verify offending items are exactly the failing metrics
          final offendingItems = defects.map((d) => d.offendingItem).toSet();
          if (!offendingItems.contains('coldStart')) return false;
          if (!offendingItems.contains('sync')) return false;

          // Verify each defect has meaningful content
          for (final defect in defects) {
            if (defect.description.isEmpty) return false;
            if (defect.measuredValue.isEmpty) return false;
            if (defect.threshold.isEmpty) return false;
          }

          // Verify the "not measured" defect has 'not measured' as value
          final syncDefect = defects.firstWhere(
            (d) => d.offendingItem == 'sync',
          );
          if (syncDefect.measuredValue != 'not measured') return false;

          return true;
        },
        [
          _timeThresholdGen,
          _fpsThresholdGen,
          _datasetRecordsGen,
          _thresholdSourceGen,
        ],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ========================================================================
    // Direction 5: Empty measurements → notGreen
    // ========================================================================
    test('REJECTION: Empty measurement list → notGreen', () {
      final status = reducer.reducePerformance([]);
      expect(status, equals(GateStatus.notGreen));
    });
  });
}
