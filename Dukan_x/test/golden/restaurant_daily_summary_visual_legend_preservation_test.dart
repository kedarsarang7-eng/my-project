// ============================================================================
// PRESERVATION TEST: Visual Legend Unaffected by Semantics Wrappers
// Feature: restaurant-audit-fixes (Task 29.2)
// **Validates: Requirements 3.14**
// ============================================================================
//
// Preservation:
//   The visual legend (text labels showing order type counts/percentages)
//   in restaurant_daily_summary_screen.dart must remain present and functional
//   after Semantics wrappers are added to the charts. The metrics grid, orders
//   chart, and pie chart must continue guarding against empty-data crashes
//   (isEmpty before reduce, total==0 before pie render) exactly as before.
//
// Approach:
//   Structural source-code analysis — verify the screen source still contains
//   the legend items, the _buildLegendItem helper, and the empty-data guards.
//   This test must PASS on unfixed code (legend already exists).
//
// Run: flutter test test/golden/restaurant_daily_summary_visual_legend_preservation_test.dart
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
  // Preservation: Visual legend text labels remain present (Requirement 3.14)
  // ==========================================================================
  group('Daily summary visual legend preservation (Requirement 3.14)', () {
    test('_buildLegendItem helper method exists', () {
      // The legend is built by _buildLegendItem which renders a colored dot +
      // text label with count and percentage for each order type.
      expect(
        dailySummarySource.contains('_buildLegendItem'),
        isTrue,
        reason:
            '_buildLegendItem helper must exist to render order type legend items',
      );
    });

    test('legend displays all four order type labels', () {
      // The legend must show Dine-In, Takeaway, Delivery, and Parcel labels
      expect(
        dailySummarySource.contains("'Dine-In'"),
        isTrue,
        reason: 'Visual legend must include Dine-In label',
      );
      expect(
        dailySummarySource.contains("'Takeaway'"),
        isTrue,
        reason: 'Visual legend must include Takeaway label',
      );
      expect(
        dailySummarySource.contains("'Delivery'"),
        isTrue,
        reason: 'Visual legend must include Delivery label',
      );
      expect(
        dailySummarySource.contains("'Parcel'"),
        isTrue,
        reason: 'Visual legend must include Parcel label',
      );
    });

    test(
      'legend items include count values (_dineInCount, _takeawayCount, etc.)',
      () {
        // Each legend item receives its count variable for display
        expect(
          dailySummarySource.contains('_dineInCount'),
          isTrue,
          reason:
              'Legend must reference _dineInCount for dine-in count display',
        );
        expect(
          dailySummarySource.contains('_takeawayCount'),
          isTrue,
          reason:
              'Legend must reference _takeawayCount for takeaway count display',
        );
        expect(
          dailySummarySource.contains('_deliveryCount'),
          isTrue,
          reason:
              'Legend must reference _deliveryCount for delivery count display',
        );
        expect(
          dailySummarySource.contains('_parcelCount'),
          isTrue,
          reason: 'Legend must reference _parcelCount for parcel count display',
        );
      },
    );

    test('legend items show percentage values', () {
      // The legend items display percentage text (computed as count/total * 100).
      // Pattern: ((_dineInCount / total) * 100).toStringAsFixed(0)
      final percentPattern = RegExp(
        r'\(\s*\(_\w+Count\s*/\s*total\s*\)\s*\*\s*100\s*\)',
      );
      expect(
        percentPattern.hasMatch(dailySummarySource),
        isTrue,
        reason:
            'Legend items must compute and display percentage values '
            '(count/total * 100)',
      );

      // Verify the percent sign is included in the legend text.
      // Source contains: Text('$label: $count ($percent%)')
      // In the raw file text, this literally has the characters: percent%)
      expect(
        dailySummarySource.contains(r'percent%)'),
        isTrue,
        reason:
            'Legend text must render the percent value with a % sign suffix',
      );
    });

    test('legend items have colored indicators', () {
      // Each legend item has a colored Container (12x12) as a visual indicator.
      // Pattern: Container(width: 12, height: 12, decoration: BoxDecoration(color: ...
      final colorIndicatorPattern = RegExp(
        r'Container\s*\(\s*width:\s*12\s*,\s*height:\s*12',
      );
      expect(
        colorIndicatorPattern.hasMatch(dailySummarySource),
        isTrue,
        reason:
            'Legend items must have a colored indicator (12x12 Container) '
            'to visually associate with pie chart sections',
      );
    });

    test('legend is rendered alongside the PieChart in a Row', () {
      // The pie chart and legend are laid out side by side in a Row.
      // The PieChart is on the left, the legend Column is on the right.
      // Pattern: Row( children: [ SizedBox(... PieChart ...), ... Column(... _buildLegendItem ...

      // Verify the _buildOrderTypeBreakdown method exists and uses Row layout
      expect(
        dailySummarySource.contains('_buildOrderTypeBreakdown'),
        isTrue,
        reason:
            '_buildOrderTypeBreakdown must exist as the method rendering '
            'the pie chart + legend',
      );

      // Verify PieChart and legend Column coexist within the breakdown widget
      final pieChartIdx = dailySummarySource.indexOf('PieChart(');
      final legendColumnIdx = dailySummarySource.indexOf(
        '_buildLegendItem',
        pieChartIdx > 0 ? pieChartIdx : 0,
      );

      expect(
        pieChartIdx,
        greaterThan(-1),
        reason: 'PieChart widget must exist in the source',
      );
      expect(
        legendColumnIdx,
        greaterThan(pieChartIdx),
        reason:
            'Visual legend (_buildLegendItem calls) must appear after the '
            'PieChart in the source, confirming side-by-side layout',
      );
    });
  });

  // ==========================================================================
  // Preservation: Empty-data guards remain in place (Requirement 3.14)
  // ==========================================================================
  group('Daily summary empty-data guards preservation (Requirement 3.14)', () {
    test('pie chart guarded by total == 0 check before rendering', () {
      // The _buildOrderTypeBreakdown method must check total == 0 and return
      // a "No orders today" placeholder rather than attempting to render a
      // pie chart with zero data (which would cause division-by-zero in
      // percentage calculations).
      final totalZeroGuard = RegExp(r'if\s*\(\s*total\s*==\s*0\s*\)');
      expect(
        totalZeroGuard.hasMatch(dailySummarySource),
        isTrue,
        reason:
            'Pie chart section must guard against empty data with a '
            '"total == 0" check before rendering',
      );
    });

    test('orders-per-hour chart guarded by isEmpty check', () {
      // The _buildOrdersChart method must check _ordersPerHour.isEmpty and
      // return a "No orders today" placeholder rather than attempting to
      // compute maxY via reduce on an empty map.
      expect(
        dailySummarySource.contains('_ordersPerHour.isEmpty'),
        isTrue,
        reason:
            'Orders chart must guard against empty data with an isEmpty check '
            'before using reduce to compute maxY',
      );
    });

    test('top items section guarded by isEmpty check', () {
      // The _buildTopItems method must check _topItems.isEmpty.
      expect(
        dailySummarySource.contains('_topItems.isEmpty'),
        isTrue,
        reason:
            'Top items section must guard against empty data with isEmpty check',
      );
    });

    test('maxY computation uses reduce only after isEmpty guard', () {
      // The pattern: _ordersPerHour.values.reduce((a, b) => a > b ? a : b)
      // must only execute when _ordersPerHour is not empty (guarded earlier).
      final reducePattern = RegExp(r'_ordersPerHour\.values\.reduce');
      expect(
        reducePattern.hasMatch(dailySummarySource),
        isTrue,
        reason: 'Bar chart maxY must be computed via reduce on ordersPerHour',
      );

      // Verify the isEmpty guard appears BEFORE the reduce call
      final isEmptyIdx = dailySummarySource.indexOf('_ordersPerHour.isEmpty');
      final reduceIdx = dailySummarySource.indexOf(
        '_ordersPerHour.values.reduce',
      );
      expect(
        isEmptyIdx,
        lessThan(reduceIdx),
        reason:
            'isEmpty guard must appear before reduce to prevent '
            'calling reduce on an empty collection',
      );
    });

    test('average prep time computation guarded by isNotEmpty check', () {
      // _processOrders guards avgPrepTime with completedWithPrepTime.isNotEmpty
      expect(
        dailySummarySource.contains('completedWithPrepTime.isNotEmpty'),
        isTrue,
        reason:
            'Average prep time computation must be guarded by isNotEmpty check '
            'to prevent division by zero',
      );
    });

    test('top items maxCount computation uses reduce safely', () {
      // _buildTopItems uses: _topItems.values.reduce((a, b) => a > b ? a : b)
      // This must only execute after the isEmpty guard.
      final topItemsReducePattern = RegExp(r'_topItems\.values\.reduce');
      expect(
        topItemsReducePattern.hasMatch(dailySummarySource),
        isTrue,
        reason:
            'Top items progress bar computation must use reduce for maxCount',
      );

      // Verify the isEmpty guard appears BEFORE the reduce call
      final isEmptyIdx = dailySummarySource.indexOf('_topItems.isEmpty');
      final reduceIdx = dailySummarySource.indexOf('_topItems.values.reduce');
      expect(
        isEmptyIdx,
        lessThan(reduceIdx),
        reason:
            'isEmpty guard must appear before top items reduce to prevent '
            'calling reduce on an empty map',
      );
    });
  });
}
