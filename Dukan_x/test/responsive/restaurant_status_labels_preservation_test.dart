// ============================================================================
// Task 28.2 — PRESERVATION TEST
// Feature: restaurant-audit-fixes
// Existing text/icon status labels unaffected by contrast fixes
// **Validates: Requirements 3.20**
// ============================================================================
// Requirement 3.20: WHEN table cards and KDS columns already display text/icon
//   status labels alongside color THEN the system SHALL CONTINUE TO show those
//   existing text/icon labels unchanged after contrast improvements are made.
//
// APPROACH: Structural source-code analysis.
//   1. Verify `table_management_screen.dart` has text AND icon labels for each
//      table status (Available/Occupied/Reserved/Cleaning) — these are the
//      accessible alternatives to color that must survive Task 28.3's changes.
//   2. Verify `kitchen_display_screen.dart` has text column headers (NEW,
//      COOKING, READY), action button labels (ACCEPT, READY, SERVED, CANCEL),
//      and order-count badges for each column.
//   3. These text/icon labels must still be present after the contrast fix
//      (Task 28.3). This test PASSES on current (unfixed) code and should
//      continue to PASS after contrast adjustments.
//
// Run: flutter test test/responsive/restaurant_status_labels_preservation_test.dart -r expanded
// ============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String tableSource;
  late String kdsSource;

  setUpAll(() {
    final tableFile = File(
      'lib/features/restaurant/presentation/screens/table_management_screen.dart',
    );
    final kdsFile = File(
      'lib/features/restaurant/presentation/screens/kitchen_display_screen.dart',
    );
    expect(
      tableFile.existsSync(),
      isTrue,
      reason: 'table_management_screen.dart must exist.',
    );
    expect(
      kdsFile.existsSync(),
      isTrue,
      reason: 'kitchen_display_screen.dart must exist.',
    );

    tableSource = tableFile.readAsStringSync();
    kdsSource = kdsFile.readAsStringSync();
  });

  // ──────────────────────────────────────────────────────────────────────────
  // TABLE MANAGEMENT SCREEN — Text/Icon Status Labels
  // ──────────────────────────────────────────────────────────────────────────

  group('Preservation 3.20: Table management status text labels', () {
    test('table card displays status displayName text for each status', () {
      // The table card renders `table.status.displayName` as a Text widget
      // in the status header row. This must remain present.
      expect(
        tableSource.contains('table.status.displayName') ||
            tableSource.contains('.status.displayName'),
        isTrue,
        reason:
            'Table card must render status.displayName as a text label '
            '(accessible alternative to status color).',
      );
    });

    test('table card displays status icon via _getStatusIcon', () {
      // The table card renders a status-specific icon alongside the text.
      // The _getStatusIcon method must exist and map each status to an icon.
      expect(
        tableSource.contains('_getStatusIcon'),
        isTrue,
        reason:
            'Table card must use _getStatusIcon to render a status-specific '
            'icon (accessible alternative to status color).',
      );
    });

    test('_getStatusIcon maps all four statuses to distinct icons', () {
      // Each table status must have a distinct icon:
      //   available → check_circle
      //   occupied → people
      //   reserved → schedule
      //   cleaning → cleaning_services
      expect(
        tableSource.contains('Icons.check_circle'),
        isTrue,
        reason: 'Available status must have Icons.check_circle icon.',
      );
      expect(
        tableSource.contains('Icons.people'),
        isTrue,
        reason: 'Occupied status must have Icons.people icon.',
      );
      expect(
        tableSource.contains('Icons.schedule'),
        isTrue,
        reason: 'Reserved status must have Icons.schedule icon.',
      );
      expect(
        tableSource.contains('Icons.cleaning_services'),
        isTrue,
        reason: 'Cleaning status must have Icons.cleaning_services icon.',
      );
    });

    test('status icon and text are rendered together in card header', () {
      // The status header row must contain both Icon and Text for the status.
      // Pattern: Icon(statusIcon, ...) followed by Text(table.status.displayName)
      // in the same status header container.
      final hasIconInRow = tableSource.contains('Icon(statusIcon');
      final hasDisplayNameText = tableSource.contains(
        'table.status.displayName',
      );
      expect(
        hasIconInRow && hasDisplayNameText,
        isTrue,
        reason:
            'Table card status header must render both an Icon (statusIcon) '
            'and a Text (table.status.displayName) together — both are '
            'accessible alternatives to color that must survive contrast fixes.',
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // KITCHEN DISPLAY SCREEN — Text Column Headers & Action Labels
  // ──────────────────────────────────────────────────────────────────────────

  group('Preservation 3.20: KDS column text labels', () {
    test('KDS renders "NEW" column header text', () {
      // The NEW column has a text label that serves as accessible
      // identification independent of color.
      expect(
        kdsSource.contains("'NEW'"),
        isTrue,
        reason:
            'KDS must have a "NEW" text column header label '
            '(accessible alternative to column accent color).',
      );
    });

    test('KDS renders "COOKING" column header text', () {
      expect(
        kdsSource.contains("'COOKING'"),
        isTrue,
        reason:
            'KDS must have a "COOKING" text column header label '
            '(accessible alternative to column accent color).',
      );
    });

    test('KDS renders "READY" column header text', () {
      expect(
        kdsSource.contains("'READY'"),
        isTrue,
        reason:
            'KDS must have a "READY" text column header label '
            '(accessible alternative to column accent color).',
      );
    });

    test('KDS columns show order count badge', () {
      // Each column header shows a count badge: '${orders.length}'
      expect(
        kdsSource.contains('orders.length'),
        isTrue,
        reason:
            'KDS columns must show order count badges (text-based status '
            'indicator independent of color).',
      );
    });
  });

  group('Preservation 3.20: KDS action button text labels', () {
    test('KDS renders "ACCEPT" action button label', () {
      expect(
        kdsSource.contains("'ACCEPT'"),
        isTrue,
        reason:
            'KDS must have an "ACCEPT" text label on the accept action button.',
      );
    });

    test('KDS renders "READY" action button label', () {
      // The READY button label (distinct from the column header)
      // is passed as label: 'READY' to _buildActionButton
      final hasReadyButton = RegExp(r"label:\s*'READY'").hasMatch(kdsSource);
      expect(
        hasReadyButton,
        isTrue,
        reason:
            'KDS must have a "READY" text label on the mark-ready action button.',
      );
    });

    test('KDS renders "SERVED" action button label', () {
      expect(
        kdsSource.contains("'SERVED'"),
        isTrue,
        reason:
            'KDS must have a "SERVED" text label on the serve action button.',
      );
    });

    test('KDS renders "CANCEL" action button label', () {
      expect(
        kdsSource.contains("'CANCEL'"),
        isTrue,
        reason:
            'KDS must have a "CANCEL" text label on the cancel action button.',
      );
    });
  });

  group('Preservation 3.20: KDS action button icons', () {
    test('KDS action buttons have distinct icons alongside text', () {
      // Each action button has both an icon and a text label:
      //   ACCEPT → Icons.check
      //   READY → Icons.done_all
      //   SERVED → Icons.room_service
      //   CANCEL → Icons.cancel_outlined
      expect(
        kdsSource.contains('Icons.check'),
        isTrue,
        reason: 'ACCEPT button must have Icons.check icon.',
      );
      expect(
        kdsSource.contains('Icons.done_all'),
        isTrue,
        reason: 'READY button must have Icons.done_all icon.',
      );
      expect(
        kdsSource.contains('Icons.room_service'),
        isTrue,
        reason: 'SERVED button must have Icons.room_service icon.',
      );
      expect(
        kdsSource.contains('Icons.cancel_outlined'),
        isTrue,
        reason: 'CANCEL button must have Icons.cancel_outlined icon.',
      );
    });
  });

  group('Preservation 3.20: KDS order card text indicators', () {
    test('KDS shows wait time as text (not only color)', () {
      // The wait time indicator shows "$waitTime min" text
      expect(
        kdsSource.contains(r"'$waitTime min'") ||
            kdsSource.contains(r"${waitTime}") ||
            kdsSource.contains("waitTime") && kdsSource.contains("min"),
        isTrue,
        reason:
            'KDS order cards must display wait time as text '
            '(accessible alternative to urgent color indicator).',
      );
    });

    test('KDS shows timer icon alongside wait time text', () {
      expect(
        kdsSource.contains('Icons.timer_outlined'),
        isTrue,
        reason:
            'KDS must show a timer icon alongside the wait time text '
            '(accessible alternative to the urgent color border).',
      );
    });

    test('KDS shows "No orders" text when column is empty', () {
      expect(
        kdsSource.contains("'No orders'"),
        isTrue,
        reason:
            'KDS must show "No orders" text in empty columns '
            '(text-based empty state).',
      );
    });

    test('KDS shows order type icon for takeaway orders', () {
      expect(
        kdsSource.contains('Icons.takeout_dining'),
        isTrue,
        reason:
            'KDS must show a takeout_dining icon for takeaway orders '
            '(icon-based order type indicator).',
      );
    });
  });
}
