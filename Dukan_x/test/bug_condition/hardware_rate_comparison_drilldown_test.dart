/// Bug Condition Exploration Test — Rate Comparison Drill-Down (HARDWARE-024)
///
/// **Validates: Requirements 1.24, 2.24**
///
/// Property 22: A dedicated item × supplier × price view is available beyond
/// the bare count card on the workspace screen.
///
/// Bug Condition: `isBugCondition(input)` where
///   `input.surface == 'workspace.rateComparisonView'`
///
/// BEFORE fix: Only "Supplier Rate Comparison: N records" shown as a bare
/// count card with no drill-down table or sortable/filterable view.
///
/// AFTER fix: A dedicated rate-comparison section/screen showing an
/// item × supplier × price table (sortable/filterable) replaces the bare
/// count card.
///
/// Run: flutter test test/bug_condition/hardware_rate_comparison_drilldown_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bug Condition HARDWARE-024 — rate comparison drill-down', () {
    // =========================================================================
    // Source probe: The workspace screen must contain a dedicated drill-down
    // table/view for rate comparison (DataTable, ListView with item/supplier/
    // price columns, or a navigation to a dedicated screen).
    //
    // On UNFIXED code, the workspace only renders a bare _sectionCard with
    // `title: 'Supplier Rate Comparison'` and `count: _rateComparison.length`,
    // with NO drill-down table, NO sortable/filterable view, and NO navigation
    // to a detail screen.
    // =========================================================================
    test('workspace screen source contains a rate comparison drill-down view '
        '(not just a bare count card)', () {
      final src = File(
        'lib/features/hardware/presentation/screens/hardware_phase12_workspace_screen.dart',
      ).readAsStringSync();

      // The bare count card approach uses _sectionCard for "Supplier Rate
      // Comparison" — this is the bug condition. The fix should replace it
      // with a drill-down widget (DataTable, sortable list, expandable
      // section, or navigation to a detail view).

      // Check for presence of a drill-down component:
      // - A DataTable for tabular item × supplier × price display
      // - A dedicated widget/method like _rateComparisonDrillDown or
      //   _rateComparisonTable
      // - A navigation to a dedicated rate comparison screen
      final hasDrillDown =
          src.contains('_rateComparisonTable') ||
          src.contains('_rateComparisonDrillDown') ||
          src.contains('RateComparisonDrillDown') ||
          src.contains('RateComparisonTable') ||
          src.contains('_buildRateComparison') ||
          // DataTable within rate comparison context
          (src.contains('DataTable') &&
              src.contains('Supplier Rate Comparison'));

      expect(
        hasDrillDown,
        isTrue,
        reason:
            'COUNTEREXAMPLE (HARDWARE-024): '
            'HardwarePhase12WorkspaceScreen only shows a bare count card '
            'for "Supplier Rate Comparison" (via _sectionCard) with no '
            'drill-down table, no sortable/filterable item × supplier × '
            'price view, and no navigation to a detail screen. The user '
            'cannot inspect individual rate comparisons from the workspace.',
      );
    });

    test('rate comparison section supports sorting or filtering', () {
      final src = File(
        'lib/features/hardware/presentation/screens/hardware_phase12_workspace_screen.dart',
      ).readAsStringSync();

      // The fix should include sorting/filtering capability —
      // TextField for filter, sort icons, onSort callback, or a search field
      final hasSortOrFilter =
          // Sort support in DataTable
          (src.contains('onSort') && src.contains('Rate Comparison')) ||
          // Filter text field
          (src.contains('_rateFilter') ||
              src.contains('_rateSearch') ||
              src.contains('rateFilterController')) ||
          // Any filtering/sorting mechanism tied to rate comparison
          src.contains('_filteredRateComparison') ||
          src.contains('_sortedRateComparison') ||
          src.contains('_rateComparisonSortColumn') ||
          src.contains('_rateSortColumn');

      expect(
        hasSortOrFilter,
        isTrue,
        reason:
            'COUNTEREXAMPLE (HARDWARE-024): '
            'The rate comparison section has no sorting or filtering '
            'mechanism. A dedicated drill-down view should allow users to '
            'sort by item name, supplier, or price, and/or filter items.',
      );
    });

    // =========================================================================
    // Preservation: Other KPI count cards remain unchanged (3.24)
    // =========================================================================
    test(
      'other workspace KPI cards still present (Open POs, Credit Parties, Sales Orders)',
      () {
        final src = File(
          'lib/features/hardware/presentation/screens/hardware_phase12_workspace_screen.dart',
        ).readAsStringSync();

        expect(
          src.contains("'Open POs'"),
          isTrue,
          reason: 'Open POs KPI card must remain',
        );
        expect(
          src.contains("'Credit Parties'"),
          isTrue,
          reason: 'Credit Parties KPI card must remain',
        );
        expect(
          src.contains("'Sales Orders'"),
          isTrue,
          reason: 'Sales Orders KPI card must remain',
        );
      },
    );

    test(
      'other section cards remain (Pending POs, Fast/Slow Moving, Dead Stock)',
      () {
        final src = File(
          'lib/features/hardware/presentation/screens/hardware_phase12_workspace_screen.dart',
        ).readAsStringSync();

        expect(
          src.contains('Pending Purchase Orders'),
          isTrue,
          reason: 'Pending Purchase Orders card must remain',
        );
        expect(
          src.contains('Fast/Slow Moving'),
          isTrue,
          reason: 'Fast/Slow Moving card must remain',
        );
        expect(
          src.contains('Dead Stock'),
          isTrue,
          reason: 'Dead Stock card must remain',
        );
      },
    );
  });
}
