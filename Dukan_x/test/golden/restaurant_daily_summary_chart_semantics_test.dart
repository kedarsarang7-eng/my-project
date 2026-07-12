// ============================================================================
// EXPLORATION TEST: Daily Summary Chart Semantics
// Feature: restaurant-audit-fixes (Task 29.1)
// **Validates: Requirements 2.31**
// ============================================================================
//
// Bug Condition:
//   The daily summary screen uses `fl_chart` (PieChart, BarChart) for data
//   visualization but provides no `Semantics` widget wrapping the chart with
//   a textual alternative, making it inaccessible to screen readers.
//
// Approach:
//   Structural source-code analysis — read restaurant_daily_summary_screen.dart
//   and assert that chart widgets (PieChart, BarChart) are wrapped in a
//   Semantics widget with a non-empty label conveying the same data as the
//   visual legend.
//
//   This test is EXPECTED TO FAIL on unfixed code, confirming the bug exists.
//
// Run: flutter test test/golden/restaurant_daily_summary_chart_semantics_test.dart
// ============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String dailySummarySource;

  setUpAll(() {
    final sourceFile = File(
      'lib/features/restaurant/presentation/screens/restaurant_daily_summary_screen.dart',
    );
    expect(
      sourceFile.existsSync(),
      isTrue,
      reason: 'restaurant_daily_summary_screen.dart must exist',
    );
    dailySummarySource = sourceFile.readAsStringSync();
  });

  // ==========================================================================
  // Exploration: PieChart has no Semantics widget wrapping (Requirement 2.31)
  // ==========================================================================
  group('Daily summary chart accessibility — semantic labels (Requirement 2.31)', () {
    test('PieChart is wrapped in a Semantics widget with a non-empty label', () {
      // The PieChart widget must be wrapped in a Semantics widget that provides
      // a textual alternative describing the order-type breakdown (dine-in,
      // takeaway, delivery, parcel counts/percentages).
      //
      // We look for a Semantics widget preceding or wrapping the PieChart call.
      // Pattern: Semantics( ... label: ... child: ... PieChart ...
      // or: Semantics( ... label: ... child: SizedBox( ... child: PieChart ...

      // First, confirm PieChart is used in the source
      expect(
        dailySummarySource.contains('PieChart('),
        isTrue,
        reason:
            'restaurant_daily_summary_screen.dart must contain a PieChart widget',
      );

      // Assert that a Semantics widget wraps the PieChart section.
      // Look for a Semantics widget in the vicinity of PieChart usage.
      // The pattern should be: Semantics(... label: '...' ... child: ... PieChart
      final semanticsBeforePieChart = RegExp(
        r'Semantics\s*\([^)]*label\s*:[^)]+\)[\s\S]{0,200}PieChart\s*\(',
        multiLine: true,
      );

      // Alternative: look for Semantics wrapping the SizedBox that contains PieChart
      final semanticsWrappingPieChartContainer = RegExp(
        r'Semantics\s*\(\s*[^)]*label\s*:[\s\S]{0,500}PieChart\s*\(',
        multiLine: true,
      );

      final hasSemanticsWrapping =
          semanticsBeforePieChart.hasMatch(dailySummarySource) ||
          semanticsWrappingPieChartContainer.hasMatch(dailySummarySource);

      expect(
        hasSemanticsWrapping,
        isTrue,
        reason:
            'PieChart in restaurant_daily_summary_screen.dart MUST be wrapped in '
            'a Semantics widget with a non-empty label providing a textual '
            'alternative for screen readers (Requirement 2.31). '
            'Currently NO Semantics widget wraps the chart.',
      );
    });

    test(
      'BarChart (orders-by-hour) is wrapped in a Semantics widget with a label',
      () {
        // The BarChart showing orders per hour should also have a Semantics
        // wrapper providing a textual alternative for screen readers.

        // First, confirm BarChart is used
        expect(
          dailySummarySource.contains('BarChart('),
          isTrue,
          reason:
              'restaurant_daily_summary_screen.dart must contain a BarChart widget',
        );

        // Assert Semantics wraps the BarChart
        final semanticsBeforeBarChart = RegExp(
          r'Semantics\s*\([^)]*label\s*:[^)]+\)[\s\S]{0,200}BarChart\s*\(',
          multiLine: true,
        );

        final semanticsWrappingBarChartContainer = RegExp(
          r'Semantics\s*\(\s*[^)]*label\s*:[\s\S]{0,500}BarChart\s*\(',
          multiLine: true,
        );

        final hasSemanticsWrapping =
            semanticsBeforeBarChart.hasMatch(dailySummarySource) ||
            semanticsWrappingBarChartContainer.hasMatch(dailySummarySource);

        expect(
          hasSemanticsWrapping,
          isTrue,
          reason:
              'BarChart in restaurant_daily_summary_screen.dart MUST be wrapped in '
              'a Semantics widget with a non-empty label providing a textual '
              'alternative for screen readers (Requirement 2.31). '
              'Currently NO Semantics widget wraps the chart.',
        );
      },
    );

    test('Semantics label for PieChart conveys order-type breakdown data', () {
      // The Semantics label should dynamically describe the chart data,
      // conveying the same information shown in the visual legend:
      // dine-in count/percent, takeaway count/percent, delivery count/percent,
      // parcel count/percent.
      //
      // We check that the label references the order type variables used in
      // the legend (_dineInCount, _takeawayCount, _deliveryCount, _parcelCount).

      // Look for a Semantics label that references the order type counts
      final semanticsWithDynamicLabel = RegExp(
        r'Semantics\s*\([^)]*label\s*:[\s\S]{0,1000}(_dineInCount|_takeawayCount|_deliveryCount|_parcelCount|dineIn|takeaway|delivery|parcel)',
        multiLine: true,
      );

      expect(
        semanticsWithDynamicLabel.hasMatch(dailySummarySource),
        isTrue,
        reason:
            'Semantics label for the PieChart must convey order-type breakdown '
            'data (dine-in, takeaway, delivery, parcel counts) matching the '
            'visual legend. Currently no such semantic label exists.',
      );
    });
  });
}
