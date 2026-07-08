/// Bug Condition Exploration Test — alerts.hardcodedCounts
///
/// **Validates: Requirements 1.5**
///
/// Property 5: Bug Condition — Live Alert Counts
///
/// This test confirms that the petrolPump case in `BusinessAlertsWidget`
/// uses hardcoded literal strings ('2' and '1') for the "Tank Levels Low" and
/// "Shift Settlement Pending" alert counts, instead of deriving them from a
/// live provider via the `_displayCount()` pattern used by every other
/// business type in the same file.
///
/// On UNFIXED code this test FAILS — the count values are always the literal
/// strings '2' and '1' regardless of actual tank levels or pending settlements.
/// After the fix this same test PASSES — counts will be derived from live
/// provider data.
///
/// Run: flutter test test/bug_condition/petrol_pump_alerts_hardcoded_exploration_test.dart
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
  // alerts.hardcodedCounts / 1.5 / 2.5 — Dashboard alert counts are hardcoded
  // literals '2' and '1' for petrolPump, not derived from live providers like
  // every other business type.
  //
  // Expected (post-fix): the petrolPump case uses _displayCount() with values
  // sourced from a live tank-level query and a live pending-settlement query.
  //
  // Bug condition: the petrolPump case passes raw string literals ('2', '1')
  // directly to the count parameter of _buildAlertItem, bypassing _displayCount
  // and any provider data entirely.
  // ===========================================================================
  group('Bug Condition 1.5 — alerts.hardcodedCounts', () {
    late String alertsSrc;
    late String petrolPumpCaseSlice;

    setUpAll(() {
      alertsSrc = _readSource(
        'lib/features/dashboard/v2/widgets/business_alerts_widget.dart',
      );
      assert(alertsSrc.isNotEmpty, 'business_alerts_widget.dart must exist');

      // There are multiple `case BusinessType.petrolPump:` in the file
      // (one returns a title string, another builds the alerts list).
      // We need the one that calls _buildAlertItem / alerts.add.
      int searchFrom = 0;
      int petrolPumpCaseStart = -1;
      while (true) {
        final idx = alertsSrc.indexOf(
          'case BusinessType.petrolPump:',
          searchFrom,
        );
        if (idx == -1) break;
        // Check if this is the alerts-building case
        final after = alertsSrc.substring(
          idx,
          (idx + 400).clamp(0, alertsSrc.length),
        );
        if (after.contains('_buildAlertItem') || after.contains('alerts.add')) {
          petrolPumpCaseStart = idx;
          break;
        }
        searchFrom = idx + 1;
      }

      assert(
        petrolPumpCaseStart != -1,
        'petrolPump alerts case must exist in business_alerts_widget.dart',
      );

      // Extract only the petrolPump case block (up to its `break;`)
      // so we don't accidentally include content from the next case.
      final rawSlice = alertsSrc.substring(
        petrolPumpCaseStart,
        (petrolPumpCaseStart + 1200).clamp(0, alertsSrc.length),
      );
      final breakIdx = rawSlice.indexOf('break;');
      petrolPumpCaseSlice = breakIdx != -1
          ? rawSlice.substring(0, breakIdx + 'break;'.length)
          : rawSlice;
    });

    test(
      'Tank Levels Low count is derived from a live provider, not hardcoded',
      () {
        // On FIXED code: the "Tank Levels Low" alert's count parameter
        // should use _displayCount() with a provider-supplied integer,
        // like every other business type.
        //
        // On UNFIXED code: the count is the literal string '2'.

        // Find the "Tank Levels Low" alert item in the petrolPump case
        final tankLevelsIdx = petrolPumpCaseSlice.indexOf('Tank Levels Low');
        expect(
          tankLevelsIdx,
          isNot(-1),
          reason: '"Tank Levels Low" alert must exist in petrolPump case',
        );

        // Extract the _buildAlertItem call surrounding "Tank Levels Low"
        final buildCallStart = petrolPumpCaseSlice.lastIndexOf(
          '_buildAlertItem',
          tankLevelsIdx,
        );
        expect(
          buildCallStart,
          isNot(-1),
          reason: '_buildAlertItem call must precede "Tank Levels Low" text',
        );

        final buildCallSlice = petrolPumpCaseSlice.substring(
          buildCallStart,
          (buildCallStart + 400).clamp(0, petrolPumpCaseSlice.length),
        );

        // The count parameter MUST use _displayCount() — i.e. it should
        // derive the value from a live provider query, not be a raw literal.
        final usesDisplayCount = buildCallSlice.contains('_displayCount');

        expect(
          usesDisplayCount,
          isTrue,
          reason:
              'COUNTEREXAMPLE (1.5): "Tank Levels Low" alert count does NOT '
              'use _displayCount(). The petrolPump case passes the hardcoded '
              "literal string '2' directly as the count parameter, meaning "
              'the displayed count is always 2 regardless of how many tanks '
              'actually have low levels. Every other business type in the '
              'same file uses _displayCount() with a live provider value.',
        );
      },
    );

    test(
      'Shift Settlement Pending count is derived from a live provider, not hardcoded',
      () {
        // On FIXED code: the "Shift Settlement Pending" alert's count
        // parameter should use _displayCount() with a provider-supplied
        // integer.
        //
        // On UNFIXED code: the count is the literal string '1'.

        final shiftIdx = petrolPumpCaseSlice.indexOf(
          'Shift Settlement Pending',
        );
        expect(
          shiftIdx,
          isNot(-1),
          reason:
              '"Shift Settlement Pending" alert must exist in petrolPump case',
        );

        // Extract the _buildAlertItem call for shift settlement
        final buildCallStart = petrolPumpCaseSlice.lastIndexOf(
          '_buildAlertItem',
          shiftIdx,
        );
        expect(
          buildCallStart,
          isNot(-1),
          reason:
              '_buildAlertItem call must precede "Shift Settlement Pending"',
        );

        final buildCallSlice = petrolPumpCaseSlice.substring(
          buildCallStart,
          (buildCallStart + 400).clamp(0, petrolPumpCaseSlice.length),
        );

        // The count parameter MUST use _displayCount()
        final usesDisplayCount = buildCallSlice.contains('_displayCount');

        expect(
          usesDisplayCount,
          isTrue,
          reason:
              'COUNTEREXAMPLE (1.5): "Shift Settlement Pending" alert count '
              'does NOT use _displayCount(). The petrolPump case passes the '
              "hardcoded literal string '1' directly as the count parameter, "
              'meaning the displayed count is always 1 regardless of how many '
              'shifts actually need settlement. Every other business type uses '
              '_displayCount() with a live provider value.',
        );
      },
    );

    test(
      'petrolPump case does NOT use hardcoded string literals for counts',
      () {
        // On FIXED code: no raw string literals like '2' or '1' should
        // appear as count values in the petrolPump case.
        //
        // On UNFIXED code: count: '2' and count: '1' are present.

        // Check for the specific hardcoded pattern: count: '2' or count: '1'
        final hasHardcodedTwo = RegExp(
          r"count:\s*'2'",
        ).hasMatch(petrolPumpCaseSlice);

        final hasHardcodedOne = RegExp(
          r"count:\s*'1'",
        ).hasMatch(petrolPumpCaseSlice);

        expect(
          hasHardcodedTwo,
          isFalse,
          reason:
              "COUNTEREXAMPLE (1.5): petrolPump case contains count: '2' — "
              'a hardcoded literal for "Tank Levels Low" that never changes '
              'regardless of actual tank state. The count must be computed '
              'from a live tank-level query.',
        );

        expect(
          hasHardcodedOne,
          isFalse,
          reason:
              "COUNTEREXAMPLE (1.5): petrolPump case contains count: '1' — "
              'a hardcoded literal for "Shift Settlement Pending" that never '
              'changes regardless of actual pending settlements. The count '
              'must be computed from a live settlement query.',
        );
      },
    );

    test('petrolPump case references a provider/snapshot for alert data', () {
      // On FIXED code: the petrolPump case should reference some form of
      // provider/snapshot variable (like other verticals use e.g.
      // bookStoreSnapshot, elec, dc, school, wholesaleSnapshot, etc.)
      // to source live alert counts.
      //
      // On UNFIXED code: there is NO provider reference at all — just
      // raw hardcoded literals.

      // Check for ANY provider/snapshot pattern typical of alert data
      final hasProviderRef =
          petrolPumpCaseSlice.contains('Snapshot') ||
          petrolPumpCaseSlice.contains('snapshot') ||
          petrolPumpCaseSlice.contains('Provider') ||
          petrolPumpCaseSlice.contains('provider') ||
          petrolPumpCaseSlice.contains('counts[') ||
          petrolPumpCaseSlice.contains('tankLevel') ||
          petrolPumpCaseSlice.contains('pendingSettlement') ||
          petrolPumpCaseSlice.contains('lowTank');

      expect(
        hasProviderRef,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.5): the petrolPump case in '
            'business_alerts_widget.dart has NO reference to any '
            'provider, snapshot, or live-query variable for alert data. '
            'Unlike every other business type (which uses snapshot '
            'providers like bookStoreSnapshot, elec, dc, school, etc.), '
            'petrolPump simply hardcodes literal strings. Alert counts '
            'must be derived from live data queries.',
      );
    });
  });
}
