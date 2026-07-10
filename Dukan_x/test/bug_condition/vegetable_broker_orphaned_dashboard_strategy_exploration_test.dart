/// Bug Condition Exploration Test — Orphaned VegetableBrokerStrategy/DashboardStrategyFactory
///
/// **Validates: Requirements 2.13**
///
/// Property 2: Expected Behavior — Orphaned `VegetableBrokerStrategy`/`DashboardStrategyFactory` Removed
///
/// This test VERIFIES the fix by asserting that:
/// 1. `lib/features/dashboard/logic/dashboard_strategy_factory.dart` does NOT exist
///    (the dead factory has been deleted)
/// 2. `lib/features/dashboard/logic/concrete_strategies.dart` does NOT exist
///    (the dead strategy classes have been deleted)
/// 3. Zero importers of either file remain in lib/ (trivially true now)
///
/// **Control case (live strategy unaffected)**:
/// - `home_screen.dart` imports `dashboard_strategies.dart` (not
///   `concrete_strategies.dart` or `dashboard_strategy_factory.dart`)
/// - `dashboard_strategies.dart`'s `_MandiStrategy` has non-empty
///   `widgets`/`quickActions`
/// This passes on current code, confirming the real dashboard path a user sees
/// is unaffected by the fix.
///
/// **POST-FIX**: After Task 8.1 deleted both files, these assertions confirm
/// the orphaned dead code has been successfully removed.
///
/// Run: flutter test test/bug_condition/vegetable_broker_orphaned_dashboard_strategy_exploration_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads a source file relative to the package root. Returns '' if missing.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

/// Recursively collects all `.dart` file paths under [dir].
List<String> _listDartFiles(String dir) {
  final root = Directory(dir);
  if (!root.existsSync()) return [];
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => f.path)
      .toList();
}

void main() {
  // ===========================================================================
  // POST-FIX VERIFICATION: dashboard_strategy_factory.dart no longer exists
  // ===========================================================================
  group('Post-fix — dashboard_strategy_factory.dart deleted (dead code removed)', () {
    test(
      'dashboard_strategy_factory.dart does NOT exist (orphaned factory removed)',
      () {
        const path =
            'lib/features/dashboard/logic/dashboard_strategy_factory.dart';
        final file = File(path);

        // File must NOT exist after the fix — confirms dead code removed.
        expect(
          file.existsSync(),
          isFalse,
          reason:
              'CONFIRMS FIX: dashboard_strategy_factory.dart has been deleted. '
              'The orphaned dead factory no longer exists in the codebase.',
        );
      },
    );

    test(
      'concrete_strategies.dart does NOT exist (dead strategies removed)',
      () {
        const path = 'lib/features/dashboard/logic/concrete_strategies.dart';
        final file = File(path);

        // File must NOT exist after the fix — confirms dead strategies removed.
        expect(
          file.existsSync(),
          isFalse,
          reason:
              'CONFIRMS FIX: concrete_strategies.dart has been deleted. '
              'VegetableBrokerStrategy and all sibling dead strategy classes '
              'no longer exist in the codebase.',
        );
      },
    );
  });

  // ===========================================================================
  // POST-FIX VERIFICATION: Zero references to either deleted file in lib/
  // ===========================================================================
  group(
    'Post-fix — zero references to dashboard_strategy_factory.dart or concrete_strategies.dart in lib/',
    () {
      test('no file under lib/ imports dashboard_strategy_factory.dart', () {
        final dartFiles = _listDartFiles('lib');

        // Pattern: import statement referencing dashboard_strategy_factory.dart
        final importPattern = RegExp(
          r"import\s+.*dashboard_strategy_factory\.dart",
        );

        final importers = <String>[];

        for (final path in dartFiles) {
          final content = File(path).readAsStringSync();
          if (importPattern.hasMatch(content)) {
            importers.add(path);
          }
        }

        // After the fix, no file imports the deleted factory.
        expect(
          importers,
          isEmpty,
          reason:
              'CONFIRMS FIX: dashboard_strategy_factory.dart has been deleted '
              'and no file in lib/ references it. '
              'Files importing it: $importers',
        );
      });

      test('no file under lib/ imports concrete_strategies.dart', () {
        final dartFiles = _listDartFiles('lib');

        // Pattern: import statement referencing concrete_strategies.dart
        final importPattern = RegExp(r"import\s+.*concrete_strategies\.dart");

        final importers = <String>[];

        for (final path in dartFiles) {
          final content = File(path).readAsStringSync();
          if (importPattern.hasMatch(content)) {
            importers.add(path);
          }
        }

        // After the fix, no file imports the deleted strategies file.
        expect(
          importers,
          isEmpty,
          reason:
              'CONFIRMS FIX: concrete_strategies.dart has been deleted '
              'and no file in lib/ references it. '
              'Files importing it: $importers',
        );
      });
    },
  );

  // ===========================================================================
  // CONTROL CASE: home_screen.dart imports dashboard_strategies.dart (live path)
  // ===========================================================================
  group(
    'Control case — home_screen.dart uses the live dashboard_strategies.dart',
    () {
      test('home_screen.dart imports dashboard_strategies.dart', () {
        const path =
            'lib/features/dashboard/presentation/screens/home_screen.dart';
        final content = _readSource(path);

        expect(
          content.isNotEmpty,
          isTrue,
          reason: 'home_screen.dart must exist.',
        );

        // Must import dashboard_strategies.dart (the live factory)
        expect(
          content.contains('dashboard_strategies.dart'),
          isTrue,
          reason:
              'home_screen.dart must import dashboard_strategies.dart — '
              'this is the live strategy resolution path.',
        );
      });

      test('home_screen.dart does NOT import concrete_strategies.dart', () {
        const path =
            'lib/features/dashboard/presentation/screens/home_screen.dart';
        final content = _readSource(path);

        expect(
          content.contains('concrete_strategies.dart'),
          isFalse,
          reason:
              'home_screen.dart must NOT import concrete_strategies.dart — '
              'it uses the live dashboard_strategies.dart factory instead.',
        );
      });

      test(
        'home_screen.dart does NOT import dashboard_strategy_factory.dart',
        () {
          const path =
              'lib/features/dashboard/presentation/screens/home_screen.dart';
          final content = _readSource(path);

          expect(
            content.contains('dashboard_strategy_factory.dart'),
            isFalse,
            reason:
                'home_screen.dart must NOT import '
                'dashboard_strategy_factory.dart — it uses the live '
                'dashboard_strategies.dart factory instead.',
          );
        },
      );
    },
  );

  // ===========================================================================
  // CONTROL CASE: _MandiStrategy in dashboard_strategies.dart has non-empty
  // quickActions and widgets
  // ===========================================================================
  group('Control case — _MandiStrategy has non-empty widgets/quickActions', () {
    test(
      'dashboard_strategies.dart defines _MandiStrategy with non-empty quickActions',
      () {
        const path = 'lib/features/dashboard/logic/dashboard_strategies.dart';
        final content = _readSource(path);

        expect(
          content.isNotEmpty,
          isTrue,
          reason: 'dashboard_strategies.dart must exist.',
        );

        // Confirm _MandiStrategy class exists
        expect(
          content.contains('class _MandiStrategy'),
          isTrue,
          reason:
              '_MandiStrategy must exist in dashboard_strategies.dart as the '
              'live strategy for vegetablesBroker.',
        );

        // Confirm quickActions is non-empty (contains at least one
        // DashboardQuickAction inside the _MandiStrategy definition)
        // Find the _MandiStrategy block and check for quickActions content
        final mandiStart = content.indexOf('class _MandiStrategy');
        expect(mandiStart, greaterThanOrEqualTo(0));

        final mandiSection = content.substring(mandiStart);

        // quickActions getter should have DashboardQuickAction entries
        expect(
          mandiSection.contains('DashboardQuickAction('),
          isTrue,
          reason:
              '_MandiStrategy.quickActions must be non-empty — the live '
              'strategy provides real quick actions (New Entry, Farmer '
              'Ledger, Daily Rates).',
        );
      },
    );

    test('dashboard_strategies.dart _MandiStrategy has non-empty widgets', () {
      const path = 'lib/features/dashboard/logic/dashboard_strategies.dart';
      final content = _readSource(path);

      final mandiStart = content.indexOf('class _MandiStrategy');
      expect(mandiStart, greaterThanOrEqualTo(0));

      final mandiSection = content.substring(mandiStart);

      // widgets getter should contain DashboardWidgetType entries
      expect(
        mandiSection.contains('DashboardWidgetType.salesSummary'),
        isTrue,
        reason:
            '_MandiStrategy.widgets must include salesSummary — the live '
            'strategy contributes real dashboard widgets.',
      );
      expect(
        mandiSection.contains('DashboardWidgetType.recentBills'),
        isTrue,
        reason:
            '_MandiStrategy.widgets must include recentBills — the live '
            'strategy contributes real dashboard widgets.',
      );
    });
  });
}
