/// Bug Condition Exploration Test — Crate Management No Consumer
///
/// **Validates: Requirements 2.13**
///
/// Property 1: Expected Behavior — `useCrateManagement` Revoked for vegetablesBroker
///
/// After the fix (Task 7.1), this test verifies the FIXED state:
/// 1. `businessCapabilityRegistry['vegetablesBroker']` does NOT contain
///    `BusinessCapability.useCrateManagement` (revoked — no consumer exists)
/// 2. `plan_mapping_builder.dart`'s broker/mandi plan mapping does NOT contain it
/// 3. A repo-wide source scan under `lib/` still finds zero files that reference a
///    crate table, crate screen, or crate sidebar item (no consumer exists)
///
/// **Control case** (must NOT show the same defect):
/// - `businessCapabilityRegistry['vegetablesBroker']` contains `useDailyRates`
/// - `rate_board_screen.dart` exists and queries `rate_history` table
/// This passes on current code, confirming `useDailyRates` is correctly out of
/// scope for this fix.
///
/// Run: flutter test test/bug_condition/vegetable_broker_crate_management_no_consumer_exploration_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/isolation/business_capability.dart';

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
  // FIX VERIFIED: useCrateManagement is NO LONGER in the capability registry
  // ===========================================================================
  group('Fix Verified — useCrateManagement revoked from capability registry', () {
    test(
      'businessCapabilityRegistry["vegetablesBroker"] does NOT contain useCrateManagement',
      () {
        final vegBrokerCaps = businessCapabilityRegistry['vegetablesBroker'];

        expect(
          vegBrokerCaps,
          isNotNull,
          reason:
              'businessCapabilityRegistry must have a "vegetablesBroker" entry.',
        );

        // After the fix (Task 7.1): useCrateManagement has been revoked from
        // the vegetablesBroker registry. This assertion confirms the fix.
        expect(
          vegBrokerCaps!.contains(BusinessCapability.useCrateManagement),
          isFalse,
          reason:
              'CONFIRMS FIX: useCrateManagement must NOT be present in '
              'businessCapabilityRegistry["vegetablesBroker"] — the capability '
              'has been revoked because it had zero consumers (no crate table, '
              'screen, or sidebar item exists).',
        );
      },
    );
  });

  // ===========================================================================
  // FIX VERIFIED: useCrateManagement is NO LONGER in plan_mapping_builder.dart's
  // broker/mandi plan mapping
  // ===========================================================================
  group(
    'Fix Verified — useCrateManagement removed from plan_mapping_builder broker/mandi mapping',
    () {
      test(
        'plan_mapping_builder.dart broker/mandi block does NOT contain useCrateManagement',
        () {
          final src = _readSource(
            'lib/core/subscription/plan_mapping_builder.dart',
          );

          expect(
            src.isNotEmpty,
            isTrue,
            reason: 'plan_mapping_builder.dart must exist.',
          );

          // Locate the "Broker / mandi" comment block and confirm
          // useCrateManagement does NOT appear in it.
          final brokerComment = src.indexOf('// Broker / mandi');
          expect(
            brokerComment,
            greaterThanOrEqualTo(0),
            reason:
                'plan_mapping_builder.dart must contain a "// Broker / mandi" '
                'comment block.',
          );

          // Check the section after the broker/mandi comment (up to the next
          // section comment) for useCrateManagement.
          final afterBroker = src.substring(brokerComment);
          final nextSection = afterBroker.indexOf('// Wholesale');
          final brokerSection = nextSection > 0
              ? afterBroker.substring(0, nextSection)
              : afterBroker.substring(0, 200);

          // After the fix (Task 7.1): useCrateManagement has been removed
          // from the broker/mandi plan mapping block.
          expect(
            brokerSection.contains('useCrateManagement'),
            isFalse,
            reason:
                'CONFIRMS FIX: useCrateManagement must NOT be present in '
                'plan_mapping_builder.dart\'s broker/mandi plan mapping block. '
                'The capability has been revoked because it had zero consumers.',
          );
        },
      );
    },
  );

  // ===========================================================================
  // BUG CONDITION: Zero crate consumers exist under lib/
  // ===========================================================================
  group('Bug Condition — zero crate consumers exist under lib/', () {
    test(
      'no file under lib/ references a crate table, crate screen, or crate sidebar item',
      () {
        final dartFiles = _listDartFiles('lib');

        // Patterns that would indicate a real crate consumer:
        // - A crate table definition (e.g. "crate" table in drift/SQL)
        // - A crate screen widget class
        // - A crate sidebar item id
        final crateConsumerPatterns = [
          RegExp(r'class\s+\w*[Cc]rate\w*Screen', multiLine: true),
          RegExp(r'class\s+\w*[Cc]rate\w*Table', multiLine: true),
          RegExp(r"'mandi_crate", multiLine: true),
          RegExp(r"'crate_management", multiLine: true),
          RegExp(r'CrateScreen', multiLine: true),
          RegExp(r'CrateListScreen', multiLine: true),
          RegExp(r'CrateTrackingScreen', multiLine: true),
          RegExp(r"CREATE TABLE.*crate", caseSensitive: false, multiLine: true),
          RegExp(r'FROM\s+crate', caseSensitive: false, multiLine: true),
        ];

        final matchingFiles = <String>[];

        for (final path in dartFiles) {
          final content = File(path).readAsStringSync();
          for (final pattern in crateConsumerPatterns) {
            if (pattern.hasMatch(content)) {
              matchingFiles.add(path);
              break;
            }
          }
        }

        // This assertion PASSES on unfixed code — demonstrating that there is
        // truly zero consumer code for the granted capability.
        expect(
          matchingFiles,
          isEmpty,
          reason:
              'DEMONSTRATES BUG: zero files under lib/ reference a crate table, '
              'crate screen, or crate sidebar item — the useCrateManagement '
              'capability grants access to a feature with no implementation. '
              'Files found: $matchingFiles',
        );
      },
    );
  });

  // ===========================================================================
  // CONTROL CASE: useDailyRates is NOT a defect (backed by a real consumer)
  // ===========================================================================
  group('Control case — useDailyRates has a real consumer (not a defect)', () {
    test(
      'businessCapabilityRegistry["vegetablesBroker"] contains useDailyRates',
      () {
        final vegBrokerCaps = businessCapabilityRegistry['vegetablesBroker'];
        expect(vegBrokerCaps, isNotNull);

        expect(
          vegBrokerCaps!.contains(BusinessCapability.useDailyRates),
          isTrue,
          reason:
              'useDailyRates must be present in the vegetablesBroker capability '
              'registry — it is correctly backed by RateBoardScreen + '
              'rate_history table.',
        );
      },
    );

    test('rate_board_screen.dart exists and queries the rate_history table', () {
      final path =
          'lib/features/vegetable_broker/presentation/screens/rate_board_screen.dart';
      final file = File(path);

      expect(
        file.existsSync(),
        isTrue,
        reason:
            'rate_board_screen.dart must exist as the real consumer for '
            'useDailyRates.',
      );

      final content = file.readAsStringSync();

      expect(
        content.contains('rate_history'),
        isTrue,
        reason:
            'rate_board_screen.dart must query the rate_history table — this '
            'confirms useDailyRates has a real consumer and is correctly out of '
            'scope for the crate-management bugfix.',
      );
    });
  });
}
