/// Bug Condition Exploration Test — report.fuelProfitHardcoded
///
/// **Validates: Requirements 1.6**
///
/// Property 6: Bug Condition — Real Fuel Profit Figures
///
/// This test confirms that `FuelProfitReportScreen` hardcodes literal strings
/// '₹0', '0 L', '0%' for Total Sales, Total Cost, Profit, Litres Sold,
/// Revenue, and Margin — regardless of any seeded bill data — and that
/// `_selectDateRange` only shows a SnackBar with the picked range without
/// storing it or triggering any computation.
///
/// On UNFIXED code this test FAILS — the values are always the hardcoded
/// literals and no computation method exists.
/// After the fix this same test PASSES — values will be computed from real
/// bill/purchase data filtered to the selected date range.
///
/// Run: flutter test test/bug_condition/petrol_pump_fuel_profit_hardcoded_exploration_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads a source file relative to the package root.
/// Returns '' if the file is missing.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  // ===========================================================================
  // report.fuelProfitHardcoded / 1.6 / 2.6 — Fuel Profit Analysis report
  // always displays '₹0', '0 L', '0%' regardless of actual sales, and the
  // date-range picker only shows a SnackBar without filtering or computing.
  //
  // Expected (post-fix): Total Sales/Cost/Profit, per-fuel Litres Sold,
  // Revenue, and Margin are computed from real bill/purchase data, and the
  // date-range picker actually filters the displayed figures.
  //
  // Bug condition: _buildSummaryItem/_buildFuelProfitCard pass hardcoded
  // literal strings, _selectDateRange never stores the range in state or
  // calls any computation method, and no data query/computation method exists.
  // ===========================================================================
  group('Bug Condition 1.6 — report.fuelProfitHardcoded', () {
    late String reportSrc;
    late String fuelProfitCardBody;

    setUpAll(() {
      reportSrc = _readSource(
        'lib/features/petrol_pump/presentation/screens/reports/'
        'fuel_profit_report_screen.dart',
      );
      assert(reportSrc.isNotEmpty, 'fuel_profit_report_screen.dart must exist');

      // Extract the _buildFuelProfitCard method definition body.
      // Use 'Widget _buildFuelProfitCard' to find the definition, not the
      // call site (which is `_buildFuelProfitCard(fuel)`).
      final defIdx = reportSrc.indexOf('Widget _buildFuelProfitCard');
      assert(defIdx != -1, '_buildFuelProfitCard method definition must exist');
      fuelProfitCardBody = reportSrc.substring(
        defIdx,
        (defIdx + 2500).clamp(0, reportSrc.length),
      );
    });

    test('Total Sales value is computed from real data, not hardcoded ₹0', () {
      // On FIXED code: the 'Total Sales' summary item should display a
      // value computed from bill data (e.g. a variable like totalSales,
      // formattedSales, or a currency formatter call).
      //
      // On UNFIXED code: it passes the literal string '₹0'.

      // Find the Total Sales _buildSummaryItem call
      final totalSalesIdx = reportSrc.indexOf("'Total Sales'");
      expect(
        totalSalesIdx,
        isNot(-1),
        reason: '"Total Sales" label must exist in the report screen',
      );

      // Extract the _buildSummaryItem call around Total Sales
      final buildCallStart = reportSrc.lastIndexOf(
        '_buildSummaryItem',
        totalSalesIdx,
      );
      expect(
        buildCallStart,
        isNot(-1),
        reason: '_buildSummaryItem call must precede "Total Sales" text',
      );

      final buildCallSlice = reportSrc.substring(
        buildCallStart,
        (buildCallStart + 300).clamp(0, reportSrc.length),
      );

      // The value parameter (second positional arg) MUST NOT be the
      // hardcoded literal '₹0' — it should reference a computed variable.
      final hasHardcodedZero = buildCallSlice.contains("'₹0'");

      expect(
        hasHardcodedZero,
        isFalse,
        reason:
            'COUNTEREXAMPLE (1.6): "Total Sales" _buildSummaryItem passes '
            "the hardcoded literal string '₹0' as its value. The displayed "
            'Total Sales is always ₹0 regardless of actual bill data. '
            'The value must be computed from real sales records filtered '
            'to the selected date range.',
      );
    });

    test('Total Cost value is computed from real data, not hardcoded ₹0', () {
      // On FIXED code: 'Total Cost' should show a computed value from
      // purchase data (cost of fuel purchased).
      //
      // On UNFIXED code: it passes the literal string '₹0'.

      final totalCostIdx = reportSrc.indexOf("'Total Cost'");
      expect(
        totalCostIdx,
        isNot(-1),
        reason: '"Total Cost" label must exist in the report screen',
      );

      final buildCallStart = reportSrc.lastIndexOf(
        '_buildSummaryItem',
        totalCostIdx,
      );
      expect(
        buildCallStart,
        isNot(-1),
        reason: '_buildSummaryItem call must precede "Total Cost" text',
      );

      final buildCallSlice = reportSrc.substring(
        buildCallStart,
        (buildCallStart + 300).clamp(0, reportSrc.length),
      );

      final hasHardcodedZero = buildCallSlice.contains("'₹0'");

      expect(
        hasHardcodedZero,
        isFalse,
        reason:
            'COUNTEREXAMPLE (1.6): "Total Cost" _buildSummaryItem passes '
            "the hardcoded literal string '₹0' as its value. The displayed "
            'Total Cost is always ₹0 regardless of actual purchase cost '
            'data. The value must be computed from real purchase records.',
      );
    });

    test('Profit value is computed from real data, not hardcoded ₹0', () {
      // On FIXED code: 'Profit' should show sales - cost.
      //
      // On UNFIXED code: it passes the literal string '₹0'.

      final profitIdx = reportSrc.indexOf("'Profit'");
      expect(
        profitIdx,
        isNot(-1),
        reason: '"Profit" label must exist in the report screen',
      );

      final buildCallStart = reportSrc.lastIndexOf(
        '_buildSummaryItem',
        profitIdx,
      );
      expect(
        buildCallStart,
        isNot(-1),
        reason: '_buildSummaryItem call must precede "Profit" text',
      );

      final buildCallSlice = reportSrc.substring(
        buildCallStart,
        (buildCallStart + 300).clamp(0, reportSrc.length),
      );

      final hasHardcodedZero = buildCallSlice.contains("'₹0'");

      expect(
        hasHardcodedZero,
        isFalse,
        reason:
            'COUNTEREXAMPLE (1.6): "Profit" _buildSummaryItem passes '
            "the hardcoded literal string '₹0' as its value. The displayed "
            'Profit is always ₹0 regardless of actual sales minus cost. '
            'The value must be computed from real data.',
      );
    });

    test(
      'Per-fuel Litres Sold is computed from real data, not hardcoded 0 L',
      () {
        // On FIXED code: the 'Litres Sold' metric in _buildFuelProfitCard
        // should show a computed value from real nozzle/bill data.
        //
        // On UNFIXED code: it passes the literal string '0 L'.

        // Find the 'Litres Sold' _buildMetric call in the card method
        final litresSoldIdx = fuelProfitCardBody.indexOf("'Litres Sold'");
        expect(
          litresSoldIdx,
          isNot(-1),
          reason: '"Litres Sold" metric must exist in fuel profit card',
        );

        // Extract the _buildMetric call
        final metricCallStart = fuelProfitCardBody.lastIndexOf(
          '_buildMetric',
          litresSoldIdx,
        );
        final metricCallSlice = fuelProfitCardBody.substring(
          metricCallStart,
          (metricCallStart + 200).clamp(0, fuelProfitCardBody.length),
        );

        final hasHardcodedLitres = metricCallSlice.contains("'0 L'");

        expect(
          hasHardcodedLitres,
          isFalse,
          reason:
              'COUNTEREXAMPLE (1.6): "Litres Sold" _buildMetric passes '
              "the hardcoded literal string '0 L' as its value. The "
              'displayed litres sold is always 0 L regardless of actual '
              'nozzle readings or bills. The value must be computed from '
              'real dispensing/billing data.',
        );
      },
    );

    test('Per-fuel Revenue is computed from real data, not hardcoded ₹0', () {
      // On FIXED code: the 'Revenue' metric in _buildFuelProfitCard
      // should show computed revenue per fuel type.
      //
      // On UNFIXED code: it passes the literal string '₹0'.

      final revenueIdx = fuelProfitCardBody.indexOf("'Revenue'");
      expect(
        revenueIdx,
        isNot(-1),
        reason: '"Revenue" metric must exist in fuel profit card',
      );

      final metricCallStart = fuelProfitCardBody.lastIndexOf(
        '_buildMetric',
        revenueIdx,
      );
      final metricCallSlice = fuelProfitCardBody.substring(
        metricCallStart,
        (metricCallStart + 200).clamp(0, fuelProfitCardBody.length),
      );

      final hasHardcodedRevenue = metricCallSlice.contains("'₹0'");

      expect(
        hasHardcodedRevenue,
        isFalse,
        reason:
            'COUNTEREXAMPLE (1.6): "Revenue" _buildMetric passes '
            "the hardcoded literal string '₹0' as its value. The "
            'displayed revenue is always ₹0 regardless of actual fuel '
            'sales. The value must be computed from real billing data '
            'for the specific fuel type.',
      );
    });

    test('Per-fuel Margin is computed from real data, not hardcoded 0%', () {
      // On FIXED code: the 'Margin' metric in _buildFuelProfitCard
      // should show a computed profit margin percentage.
      //
      // On UNFIXED code: it passes the literal string '0%'.

      final marginIdx = fuelProfitCardBody.indexOf("'Margin'");
      expect(
        marginIdx,
        isNot(-1),
        reason: '"Margin" metric must exist in fuel profit card',
      );

      final metricCallStart = fuelProfitCardBody.lastIndexOf(
        '_buildMetric',
        marginIdx,
      );
      final metricCallSlice = fuelProfitCardBody.substring(
        metricCallStart,
        (metricCallStart + 200).clamp(0, fuelProfitCardBody.length),
      );

      final hasHardcodedMargin = metricCallSlice.contains("'0%'");

      expect(
        hasHardcodedMargin,
        isFalse,
        reason:
            'COUNTEREXAMPLE (1.6): "Margin" _buildMetric passes '
            "the hardcoded literal string '0%' as its value. The "
            'displayed margin is always 0% regardless of actual profit '
            'margin. The value must be computed from real cost/revenue data.',
      );
    });

    test(
      '_selectDateRange stores the selected range in state and triggers computation',
      () {
        // On FIXED code: _selectDateRange should store the selected range
        // in a state variable (e.g. _selectedRange, _dateRange) and call
        // setState or a computation method to re-render with filtered data.
        //
        // On UNFIXED code: it only shows a SnackBar with the date info
        // and never stores the range or triggers re-computation.

        // Find the _selectDateRange method
        final methodIdx = reportSrc.indexOf('_selectDateRange');
        expect(
          methodIdx,
          isNot(-1),
          reason: '_selectDateRange method must exist',
        );

        // Extract the method body
        final methodSlice = reportSrc.substring(
          methodIdx,
          (methodIdx + 800).clamp(0, reportSrc.length),
        );

        // Check that the method stores the range in state
        final storesRange =
            methodSlice.contains('_selectedRange') ||
            methodSlice.contains('_dateRange') ||
            methodSlice.contains('_startDate') ||
            methodSlice.contains('_endDate') ||
            methodSlice.contains('setState');

        expect(
          storesRange,
          isTrue,
          reason:
              'COUNTEREXAMPLE (1.6): _selectDateRange does NOT store the '
              'selected date range in any state variable or call setState. '
              'It only shows a SnackBar with the picked range text. The '
              'date-range selection has no filtering effect on the displayed '
              'profit figures — they remain hardcoded ₹0/0 L/0% regardless '
              'of which dates are selected.',
        );
      },
    );

    test(
      'A computation method exists to calculate profit figures from real data',
      () {
        // On FIXED code: there should be a method that queries real
        // bill/purchase data and computes sales/cost/profit/litres/margin.
        //
        // On UNFIXED code: no such method exists — all values are inline
        // hardcoded literals.

        final hasComputeMethod =
            reportSrc.contains('_computeProfit') ||
            reportSrc.contains('_calculateProfit') ||
            reportSrc.contains('_loadData') ||
            reportSrc.contains('_fetchData') ||
            reportSrc.contains('_computeSummary') ||
            reportSrc.contains('_calculateSummary') ||
            reportSrc.contains('_loadReport') ||
            reportSrc.contains('_fetchReport') ||
            reportSrc.contains('totalSales') ||
            reportSrc.contains('_totalSales') ||
            reportSrc.contains('billQuery') ||
            reportSrc.contains('_queryBills');

        expect(
          hasComputeMethod,
          isTrue,
          reason:
              'COUNTEREXAMPLE (1.6): fuel_profit_report_screen.dart has NO '
              'computation method to calculate profit figures from real data. '
              'There is no _computeProfit, _loadData, _fetchReport, or any '
              'variable holding computed totals. All displayed values are '
              'inline hardcoded literals (₹0, 0 L, 0%) passed directly to '
              '_buildSummaryItem and _buildMetric. A real computation method '
              'must exist to query bill/purchase data and derive actual '
              'sales, cost, profit, litres sold, revenue, and margin.',
        );
      },
    );
  });
}
