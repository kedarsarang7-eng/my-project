/// Phase 4 Bug-Condition Exploration Test — Electronics Sidebar & Navigation
///
/// **Validates: Requirements 2.14, 2.15, 2.16**
///
/// **Property 6: Bug Condition** — Dedicated Electronics sidebar and correct
/// id resolution.
///
/// This test encodes the EXPECTED behavior (what SHOULD happen after the fix).
/// It is run on UNFIXED code and is EXPECTED TO FAIL — failure confirms the bug
/// exists.
///
/// Bug condition (from design):
///   `SidebarRender` where `businessType == electronics AND
///    sidebarIs(_getRetailSections) AND missingDeviceEntries(input)`
///
/// Expected behavior asserted:
///   - Electronics renders a DEDICATED section with the device-relevant entries
///     (Serial/IMEI Tracking, Warranty Register, Service/Repair Jobs,
///     Returns-with-serial).
///   - The clearly-irrelevant retail-only ids are ABSENT (`funds_flow`,
///     `filing_status`, `ledger_abstract`, `b2b_b2c`).
///   - `audit_trail` is NOT presented as a real audit log (either absent, or
///     not aliased to `AllTransactionsScreen`).
///
/// EXPECTED OUTCOME on UNFIXED code: Test FAILS because Electronics falls into
/// the shared retail case (D5):
///   `case BusinessType.electronics: case BusinessType.computerShop:
///      return _getRetailSections();`
/// so device entries are missing, retail-only items are present, and
/// `audit_trail` aliases `AllTransactionsScreen`.
///
/// PBT library: dartproptest ^0.2.1
///
/// Run: flutter test test/bug_condition/electronics_phase4_sidebar_exploration_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';
import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Collects all sidebar item ids for a given [BusinessType] using the
/// `@visibleForTesting` `getSectionsForBusinessType` entry point — the same
/// mechanism the preservation test uses to read sidebar sections.
Set<String> _sidebarItemIds(BusinessType type) {
  final sections = getSectionsForBusinessType(type);
  final ids = <String>{};
  for (final section in sections) {
    for (final item in section.items) {
      ids.add(item.id);
    }
  }
  return ids;
}

/// The clearly-irrelevant retail-only ids that must NOT surface on a small
/// electronics counter (bugfix.md 1.15 / 2.15).
const List<String> _retailOnlyIds = <String>[
  'funds_flow',
  'filing_status',
  'ledger_abstract',
  'b2b_b2c',
];

/// Predicate matchers for the four device-relevant entries Phase 4 requires
/// in the dedicated Electronics section (bugfix.md 2.15). Each is a tolerant
/// id-substring match so the fix can choose its exact id naming.
bool _hasImeiOrSerialTracking(Set<String> ids) =>
    ids.any((id) => id.contains('imei') || id.contains('serial'));
bool _hasWarrantyRegister(Set<String> ids) =>
    ids.any((id) => id.contains('warranty'));
bool _hasServiceRepairJobs(Set<String> ids) =>
    ids.any((id) => id.contains('service_job') || id.contains('job'));
bool _hasReturnsWithSerial(Set<String> ids) =>
    ids.any((id) => id.contains('return'));

void main() {
  // =========================================================================
  // (1) Dedicated Electronics section — device entries present (2.14, 2.15)
  //
  // Bug: Electronics is grouped with computerShop on `_getRetailSections()`
  //   (D5), so it has NO dedicated device section and the four device entries
  //   are missing.
  // Expected (post-fix): a dedicated `_getElectronicsSections()` includes
  //   Serial/IMEI Tracking, Warranty Register, Service/Repair Jobs, and
  //   Returns-with-serial.
  // =========================================================================
  group('Phase 4 Bug Condition — device entries present (2.14, 2.15)', () {
    test('Electronics sidebar contains a Serial/IMEI Tracking entry', () {
      final ids = _sidebarItemIds(BusinessType.electronics);
      expect(
        _hasImeiOrSerialTracking(ids),
        isTrue,
        reason:
            'Electronics sidebar must contain a Serial/IMEI Tracking entry. '
            'Bug: Electronics uses _getRetailSections() (D5) which has no such '
            'device entry. Counterexample: missing IMEI/Serial Tracking; '
            'electronics sidebar ids: $ids',
      );
    });

    test('Electronics sidebar contains a Warranty Register entry', () {
      final ids = _sidebarItemIds(BusinessType.electronics);
      expect(
        _hasWarrantyRegister(ids),
        isTrue,
        reason:
            'Electronics sidebar must contain a Warranty Register entry. '
            'Bug: _getRetailSections() has no warranty item. '
            'Counterexample: missing Warranty Register; ids: $ids',
      );
    });

    test('Electronics sidebar contains a Service/Repair Jobs entry', () {
      final ids = _sidebarItemIds(BusinessType.electronics);
      expect(
        _hasServiceRepairJobs(ids),
        isTrue,
        reason:
            'Electronics sidebar must contain a Service/Repair Jobs entry. '
            'Bug: _getRetailSections() has no service-job item. '
            'Counterexample: missing Service/Repair Jobs; ids: $ids',
      );
    });

    test('Electronics sidebar contains a Returns-with-serial entry', () {
      final ids = _sidebarItemIds(BusinessType.electronics);
      expect(
        _hasReturnsWithSerial(ids),
        isTrue,
        reason:
            'Electronics sidebar must contain a Returns-with-serial entry. '
            'Counterexample: missing Returns entry; ids: $ids',
      );
    });
  });

  // =========================================================================
  // (2) Irrelevant retail-only ids absent (2.15)
  //
  // Bug: the shared retail sidebar surfaces `funds_flow`, `filing_status`,
  //   `ledger_abstract`, `b2b_b2c` — irrelevant to a small electronics
  //   counter.
  // Expected (post-fix): none of those ids appear in the Electronics sidebar.
  // =========================================================================
  group('Phase 4 Bug Condition — retail-only ids absent (2.15)', () {
    test('Electronics sidebar omits funds_flow/filing_status/'
        'ledger_abstract/b2b_b2c', () {
      final ids = _sidebarItemIds(BusinessType.electronics);
      final present = _retailOnlyIds.where(ids.contains).toList();
      expect(
        present,
        isEmpty,
        reason:
            'Electronics sidebar must omit clearly-irrelevant retail-only ids. '
            'Bug: Electronics uses _getRetailSections() which surfaces them. '
            'Counterexample: electronics sidebar contains $present',
      );
    });
  });

  // =========================================================================
  // (3) audit_trail is not presented as a real audit log (2.16)
  //
  // Bug: `audit_trail` is in `_getRetailSections()` and resolves to
  //   `AllTransactionsScreen` via SidebarNavigationHandler — a transactions
  //   ledger, not a real immutable audit log.
  // Expected (post-fix): `audit_trail` is either ABSENT from the Electronics
  //   sidebar, or it does NOT resolve to `AllTransactionsScreen`.
  // =========================================================================
  group('Phase 4 Bug Condition — audit_trail not a faked audit log (2.16)', () {
    testWidgets(
      'audit_trail is absent or not aliased to AllTransactionsScreen',
      (tester) async {
        late BuildContext ctx;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox();
              },
            ),
          ),
        );

        final ids = _sidebarItemIds(BusinessType.electronics);
        if (!ids.contains('audit_trail')) {
          // Absent — acceptable per 2.16. Property holds.
          return;
        }

        // Present — it must NOT resolve to the AllTransactionsScreen alias.
        final screen = SidebarNavigationHandler.tryGetScreenForItem(
          'audit_trail',
          ctx,
        );
        final screenType = screen.runtimeType.toString();
        expect(
          screenType,
          isNot('AllTransactionsScreen'),
          reason:
              'audit_trail must not be presented as a real audit log. '
              'Bug: it is carried into the Electronics sidebar via '
              '_getRetailSections() and aliases AllTransactionsScreen (a '
              'transactions ledger, not a real audit log). '
              'Counterexample: audit_trail resolves to $screenType',
        );
      },
    );
  });

  // =========================================================================
  // (4) Scoped property — every required device entry present AND every
  //     retail-only id absent for the Electronics sidebar.
  //
  // This combines the per-entry assertions into a single property over the
  // device-entry checks and the retail-only id set. It WILL FAIL on unfixed
  // code because Electronics renders the generic retail menu.
  // =========================================================================
  group('Phase 4 Bug Condition — PBT: dedicated electronics sidebar', () {
    test('PBT: device entries present and retail-only ids absent (2.14–2.16)', () {
      final ids = _sidebarItemIds(BusinessType.electronics);

      // index 0..3 → device entries that must be PRESENT.
      // index 4..7 → retail-only ids that must be ABSENT.
      forAll(
        (int idx) {
          if (idx < 4) {
            late bool present;
            late String label;
            switch (idx) {
              case 0:
                label = 'Serial/IMEI Tracking';
                present = _hasImeiOrSerialTracking(ids);
              case 1:
                label = 'Warranty Register';
                present = _hasWarrantyRegister(ids);
              case 2:
                label = 'Service/Repair Jobs';
                present = _hasServiceRepairJobs(ids);
              default:
                label = 'Returns-with-serial';
                present = _hasReturnsWithSerial(ids);
            }
            expect(
              present,
              isTrue,
              reason:
                  'Property violated: Electronics sidebar must contain the '
                  '"$label" device entry. Bug: Electronics falls into the '
                  'shared retail case (D5). Counterexample: "$label" missing; '
                  'electronics sidebar ids: $ids',
            );
          } else {
            final retailId = _retailOnlyIds[idx - 4];
            expect(
              ids.contains(retailId),
              isFalse,
              reason:
                  'Property violated: Electronics sidebar must NOT surface the '
                  'retail-only id "$retailId". Bug: Electronics uses '
                  '_getRetailSections(). Counterexample: electronics sidebar '
                  'contains "$retailId"',
            );
          }
          return true;
        },
        [Gen.interval(0, 7)],
        numRuns: 8,
      );
    });
  });
}
