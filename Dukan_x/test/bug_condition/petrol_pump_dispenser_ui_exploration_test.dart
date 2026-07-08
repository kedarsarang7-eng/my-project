/// Bug Condition Exploration Test — ui.dispenserNozzleReadingEntry
///
/// **Validates: Requirements 1.3**
///
/// Property 3: Bug Condition — Dispenser/Nozzle/Reading Entry UI
///
/// This test confirms that `DispenserListScreen` currently has NO
/// FloatingActionButton (for adding a dispenser), NO "Add Nozzle" affordance
/// per dispenser card, and NO reading-entry dialog/screen anywhere in
/// `lib/features/petrol_pump/presentation/`.
///
/// Specifically:
///   - `dispenser_list_screen.dart`'s FAB is commented out with
///     "FAB removed until Add Dispenser is fully implemented"
///   - The "Add Nozzle" button in each dispenser card's trailing is
///     commented out with "Add Nozzle button removed until fully implemented"
///   - No file named *reading* (e.g., `nozzle_reading_dialog.dart`,
///     `reading_entry_screen.dart`) exists in the presentation folder,
///     meaning there is no UI for recording opening/closing meter readings.
///
/// On UNFIXED code this test FAILS — proving the bug exists.
/// After the fix (restoring FAB, Add Nozzle, and adding a reading-entry dialog)
/// this same test PASSES.
///
/// Run: flutter test test/bug_condition/petrol_pump_dispenser_ui_exploration_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads a source file relative to the package root.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

/// Lists all .dart files in a directory (non-recursive).
List<String> _dartFilesIn(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => f.path.replaceAll('\\', '/'))
      .toList();
}

void main() {
  // ===========================================================================
  // ui.dispenserNozzleReadingEntry / 1.3 / 2.3 — No UI exists for adding a
  // dispenser, adding a nozzle, or recording meter readings
  // ===========================================================================
  group('Bug Condition 1.3 — ui.dispenserNozzleReadingEntry', () {
    late String dispenserListSrc;

    setUpAll(() {
      dispenserListSrc = _readSource(
        'lib/features/petrol_pump/presentation/screens/dispenser_list_screen.dart',
      );
      assert(
        dispenserListSrc.isNotEmpty,
        'dispenser_list_screen.dart must exist',
      );
    });

    test(
      'DispenserListScreen has a FloatingActionButton for adding dispensers',
      () {
        // On FIXED code: The Scaffold should have a floatingActionButton
        // property set to a FAB that opens an "Add Dispenser" flow.
        //
        // On UNFIXED code: The FAB is commented out with the comment
        // "FAB removed until Add Dispenser is fully implemented"

        final hasFab =
            dispenserListSrc.contains('FloatingActionButton') ||
            dispenserListSrc.contains('floatingActionButton:');

        // The FAB must be a real widget assignment, not just a comment
        final fabIsCommentedOut = RegExp(
          r'//.*FAB\s+removed',
          caseSensitive: false,
        ).hasMatch(dispenserListSrc);

        expect(
          hasFab && !fabIsCommentedOut,
          isTrue,
          reason:
              'COUNTEREXAMPLE (1.3): DispenserListScreen does NOT have a '
              'FloatingActionButton. The FAB is commented out with the note '
              '"FAB removed until Add Dispenser is fully implemented". '
              'Station operators have no way to add new dispensers from the UI.',
        );
      },
    );

    test('Each dispenser card has an "Add Nozzle" affordance', () {
      // On FIXED code: Each dispenser card's ListTile trailing (or
      // similar widget) should include a button/icon to add a nozzle
      // to that dispenser.
      //
      // On UNFIXED code: The "Add Nozzle" button is commented out with
      // "Add Nozzle button removed until fully implemented"

      final hasAddNozzleWidget =
          dispenserListSrc.contains('Add Nozzle') ||
          dispenserListSrc.contains('addNozzle') ||
          dispenserListSrc.contains('trailing:');

      final addNozzleIsCommentedOut = RegExp(
        r'//.*Add Nozzle.*removed',
        caseSensitive: false,
      ).hasMatch(dispenserListSrc);

      expect(
        hasAddNozzleWidget && !addNozzleIsCommentedOut,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.3): DispenserListScreen does NOT have an '
            '"Add Nozzle" affordance in dispenser cards. The button is '
            'commented out with "Add Nozzle button removed until fully '
            'implemented". Station operators cannot attach nozzles to '
            'dispensers from the UI.',
      );
    });

    test('A reading-entry dialog/screen exists in petrol_pump presentation', () {
      // On FIXED code: There MUST be a file in
      // lib/features/petrol_pump/presentation/ (screens/ or dialogs/)
      // that provides UI for recording opening/closing meter readings
      // (e.g., nozzle_reading_dialog.dart, reading_entry_screen.dart,
      // meter_reading_dialog.dart).
      //
      // On UNFIXED code: No such file exists — only add_stock_dialog,
      // add_tank_dialog, and dip_reading_dialog are present. None of
      // these handle nozzle meter readings.

      final presentationDir = 'lib/features/petrol_pump/presentation';
      final allDartFiles = _dartFilesIn(presentationDir);

      // Look for any file whose name suggests reading-entry/meter-reading
      final readingEntryFiles = allDartFiles.where((path) {
        final fileName = path.split('/').last.toLowerCase();
        return fileName.contains('reading') &&
            (fileName.contains('nozzle') ||
                fileName.contains('meter') ||
                fileName.contains('entry') ||
                fileName.contains('opening') ||
                fileName.contains('closing'));
      }).toList();

      // Also check if the dispenser_list_screen itself has a reading
      // entry dialog/bottom sheet inline (i.e., a form/dialog that WRITES
      // readings, not merely displays them). Look for update/record/submit
      // patterns related to readings.
      final hasInlineReadingEntry =
          dispenserListSrc.contains('updateOpeningReading') ||
          dispenserListSrc.contains('updateClosingReading') ||
          dispenserListSrc.contains('recordReading') ||
          dispenserListSrc.contains('MeterReadingDialog') ||
          dispenserListSrc.contains('NozzleReadingDialog') ||
          dispenserListSrc.contains('ReadingEntryDialog');

      final readingEntryExists =
          readingEntryFiles.isNotEmpty || hasInlineReadingEntry;

      expect(
        readingEntryExists,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.3): No reading-entry screen or dialog exists '
            'anywhere in lib/features/petrol_pump/presentation/. The only '
            'dialogs present are add_stock_dialog.dart, add_tank_dialog.dart, '
            'and dip_reading_dialog.dart — none of which handle nozzle meter '
            'readings. Station operators have NO UI to record opening/closing '
            'meter readings for nozzles, making shift reconciliation impossible '
            'from the user interface.',
      );
    });
  });
}
