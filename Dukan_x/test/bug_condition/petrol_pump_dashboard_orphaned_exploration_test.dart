/// Bug Condition Exploration Test — dashboard.orphaned
///
/// **Validates: Requirements 1.4**
///
/// Property 4: Bug Condition — Dashboard Reachability
///
/// This test confirms that `SidebarNavigationHandler.getScreenForItem('petrol_dashboard')`
/// currently returns `PetrolPumpManagementScreen` (a bare 4-tile menu) instead of the
/// fully-built KPI dashboard (`RevenueDashboardScreen`) or the dashboard widget bundle
/// (`PetrolPumpDashboardWidgets`).
///
/// Additionally, it verifies that `RevenueDashboardScreen` and `PetrolPumpDashboardWidgets`
/// have ZERO navigation references anywhere in the petrol_pump feature — they are fully
/// implemented but completely orphaned.
///
/// On UNFIXED code this test FAILS — proving the bug exists.
/// After the fix (wiring `RevenueDashboardScreen` into the `petrol_dashboard` sidebar route)
/// this same test PASSES.
///
/// Run: flutter test test/bug_condition/petrol_pump_dashboard_orphaned_exploration_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads a source file relative to the package root.
/// Returns '' if the file is missing.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

/// Recursively collects all .dart file paths under a directory.
List<String> _dartFilesUnder(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => f.path)
      .toList();
}

void main() {
  // ===========================================================================
  // dashboard.orphaned / 1.4 / 2.4 — petrol_dashboard sidebar item shows
  // PetrolPumpManagementScreen (bare 4-tile menu) instead of the fully-built
  // RevenueDashboardScreen KPI dashboard.
  // ===========================================================================
  group('Bug Condition 1.4 — dashboard.orphaned', () {
    late String sidebarHandlerSrc;

    setUpAll(() {
      sidebarHandlerSrc = _readSource(
        'lib/widgets/desktop/sidebar_navigation_handler.dart',
      );
      assert(
        sidebarHandlerSrc.isNotEmpty,
        'sidebar_navigation_handler.dart must exist',
      );
    });

    test(
      'petrol_dashboard route returns RevenueDashboardScreen, not PetrolPumpManagementScreen',
      () {
        // Locate the case 'petrol_dashboard': branch in the switch statement.
        final caseStart = sidebarHandlerSrc.indexOf("case 'petrol_dashboard':");
        expect(
          caseStart,
          isNot(-1),
          reason: "case 'petrol_dashboard': must exist in the sidebar handler",
        );

        // Extract a slice after the case to find what it returns.
        final caseSlice = sidebarHandlerSrc.substring(
          caseStart,
          (caseStart + 500).clamp(0, sidebarHandlerSrc.length),
        );

        // On FIXED code: the case should return RevenueDashboardScreen.
        // On UNFIXED code: it returns PetrolPumpManagementScreen (a bare menu).
        final returnsRevenueDashboard = caseSlice.contains(
          'RevenueDashboardScreen',
        );

        expect(
          returnsRevenueDashboard,
          isTrue,
          reason:
              'COUNTEREXAMPLE (1.4): case \'petrol_dashboard\' returns '
              'PetrolPumpManagementScreen (a bare 4-tile menu: Fuel '
              'Configuration, Dispenser & Nozzles, Shift Management, Tank & '
              'Stock) instead of RevenueDashboardScreen (the fully-built KPI '
              'dashboard with revenue/txns/litres/avg-ticket/hourly chart/'
              'fuel pie/payment split/staff leaderboard). The KPI dashboard '
              'exists and is fully implemented but is never navigated to.',
        );
      },
    );

    test(
      'RevenueDashboardScreen has navigation references in the petrol_pump feature',
      () {
        // Collect all .dart files under the petrol_pump feature directory,
        // EXCLUDING the RevenueDashboardScreen's own definition file.
        final petrolPumpFiles = _dartFilesUnder('lib/features/petrol_pump');

        final definitionFile = 'revenue_dashboard_screen.dart';

        int referenceCount = 0;
        for (final filePath in petrolPumpFiles) {
          // Skip the screen's own definition file
          if (filePath.endsWith(definitionFile)) continue;

          final content = File(filePath).readAsStringSync();
          if (content.contains('RevenueDashboardScreen')) {
            referenceCount++;
          }
        }

        // Also check the sidebar handler itself (outside petrol_pump feature).
        if (sidebarHandlerSrc.contains('RevenueDashboardScreen')) {
          referenceCount++;
        }

        // On FIXED code: at least one reference exists (the sidebar route or
        // a navigation call from within the feature).
        // On UNFIXED code: ZERO references — the screen is fully orphaned.
        expect(
          referenceCount,
          greaterThan(0),
          reason:
              'COUNTEREXAMPLE (1.4): RevenueDashboardScreen has ZERO '
              'navigation references anywhere in the petrol_pump feature or '
              'the sidebar handler. The fully-built KPI dashboard (revenue, '
              'transactions, litres sold, avg ticket, hourly chart, fuel pie, '
              'payment split, staff leaderboard) is completely orphaned — '
              'no code anywhere navigates to it.',
        );
      },
    );

    test(
      'PetrolPumpDashboardWidgets has navigation references in the petrol_pump feature',
      () {
        // Collect all .dart files under the petrol_pump feature directory,
        // EXCLUDING the widget bundle's own definition file.
        final petrolPumpFiles = _dartFilesUnder('lib/features/petrol_pump');

        final definitionFile = 'petrol_pump_dashboard_widgets.dart';

        int referenceCount = 0;
        for (final filePath in petrolPumpFiles) {
          // Skip the widget's own definition file
          if (filePath.endsWith(definitionFile)) continue;

          final content = File(filePath).readAsStringSync();
          if (content.contains('PetrolPumpDashboardWidgets')) {
            referenceCount++;
          }
        }

        // Also check the sidebar handler.
        if (sidebarHandlerSrc.contains('PetrolPumpDashboardWidgets')) {
          referenceCount++;
        }

        // On FIXED code: at least one reference exists (used by the dashboard
        // screen or integrated into a parent layout).
        // On UNFIXED code: ZERO references — the widget bundle is orphaned.
        expect(
          referenceCount,
          greaterThan(0),
          reason:
              'COUNTEREXAMPLE (1.4): PetrolPumpDashboardWidgets has ZERO '
              'navigation references anywhere in the petrol_pump feature or '
              'the sidebar handler. The dashboard widget bundle (shift status '
              'card, fuel-rate ticker, low-tank summary) is fully implemented '
              'but completely orphaned — no code anywhere instantiates it.',
        );
      },
    );
  });
}
