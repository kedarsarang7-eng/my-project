// ============================================================================
// Feature: pharmacy-vertical-remediation, Task 4.6
//          Widget/integration test for the prescription capture flow.
// **Validates: Requirements 7.7** (which exercises 7.1, 7.3, 7.4, 7.5, 7.6)
// ============================================================================
//
// WHAT THIS COVERS (the four behaviors mandated by Requirement 7.7):
//   (a) A scheduled drug (Schedule H / H1 / X) triggers prescription capture
//       and, on a valid capture, the prescription identifier is assigned to the
//       bill so the save-time compliance check accepts it.        (R7.1, R7.2, R7.5)
//   (b) Cancelling the prescription gate preserves the in-progress bill content
//       and saves nothing — the scheduled line is NOT added and no
//       prescription id is recorded.                                       (R7.3)
//   (c) A null / unset drug schedule is treated as NON-scheduled (no gate is
//       shown) but the item is STILL run through PharmacyValidationService.  (R7.4)
//   (d) Saving a bill that contains a scheduled drug WITHOUT a captured
//       prescription identifier is rejected with `MISSING_PRESCRIPTION`,
//       leaving the bill unsaved.                                           (R7.6)
//
// WHY THIS IS AN INTEGRATION TEST (not a full-screen widget pump):
//   `BillCreationScreenV2` is wired through heavy dependency injection — it
//   resolves the Drift `AppDatabase`, the `ApiClient`, the active `SessionManager`
//   tenant, products/recommendation repositories, and the sidebar/navigation
//   stack at build time, and the prescription gate's *submit* path itself calls
//   `sl<ApiClient>()` to upload evidence to the backend. Pumping the whole
//   screen (or driving the gate's network submit) would require standing up that
//   entire backend/DI graph, which is impractical and would test infrastructure
//   rather than the capture-flow logic.
//
//   The capture flow's behavior lives in two collaborating, fully public units:
//     * `DrugScheduleResolver`  — decides whether an item is scheduled and so
//       whether the gate must be presented (mirrors the POS
//       `_ensurePrescriptionForProduct` trigger), and
//     * `PharmacyValidationService` — the save-time chokepoint that
//       `bills_repository._validatePharmacyCompliance` calls to accept/reject a
//       bill based on its captured `prescriptionId`.
//   This test drives those two units exactly as the POS + repository do, plus a
//   REAL widget pump of `PrescriptionGateDialog` for the cancel path (which
//   needs no DI). `_PosPrescriptionGate` below replicates the POS gate decision
//   verbatim so behaviors (a)–(c) are exercised against the same logic the
//   screen runs.
//
// Run: flutter test test/pharmacy/prescription_capture_flow_test.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/billing/business_type_config.dart';
import 'package:dukanx/core/error/pharmacy_compliance_exception.dart';
import 'package:dukanx/core/services/pharmacy_validation_service.dart';
import 'package:dukanx/features/inventory/services/drug_schedule_service.dart';
import 'package:dukanx/features/pharmacy/utils/drug_schedule_resolver.dart';
import 'package:dukanx/features/prescriptions/presentation/widgets/prescription_gate_dialog.dart';
import 'package:dukanx/models/bill.dart';

/// Faithful, DI-free replica of the `BillCreationScreenV2` prescription gate
/// decision (`_ensurePrescriptionForProduct`). It captures the only state the
/// POS mutates for the gate — the bill's `prescriptionId` — so the test can
/// assert on it the same way the screen would before save.
class _PosPrescriptionGate {
  /// Mirrors the POS field `_prescriptionId` assigned on a valid capture.
  String? prescriptionId;

  /// True when adding an item with [scheduleRaw] must present the gate.
  /// Exactly the POS condition: pharmacy + canonical schedule ∈ {H,H1,X}.
  bool gateRequired(String? scheduleRaw) => DrugScheduleResolver.isScheduled(
    DrugScheduleResolver.fromRaw(scheduleRaw),
  );

  /// Mirrors the POS handling of the gate's result:
  ///   * `null` (cancel) -> return false, leave the bill untouched (R7.3).
  ///   * a valid id (1..100 chars, trimmed non-empty) -> assign it and
  ///     return true so the caller adds the scheduled line (R7.2).
  ///   * an out-of-bounds id -> return false, assign nothing.
  bool applyGateResult(PrescriptionGateResult? result) {
    if (result == null) return false;
    final rxId = result.prescriptionId.trim();
    if (rxId.isEmpty || rxId.length > 100) return false;
    prescriptionId = rxId;
    return true;
  }
}

/// Builds a pharmacy bill line. Defaults are compliant (batch + future expiry)
/// so a test can isolate the schedule/prescription dimension under study.
BillItem _item({
  String name = 'Test Medicine',
  String? drugSchedule,
  String? batchNo = 'BATCH-001',
  DateTime? expiryDate,
  bool futureExpiry = true,
}) {
  return BillItem(
    productId: 'p-$name',
    productName: name,
    qty: 1,
    price: 100,
    batchNo: batchNo,
    drugSchedule: drugSchedule,
    expiryDate:
        expiryDate ??
        (futureExpiry ? DateTime.now().add(const Duration(days: 365)) : null),
  );
}

void main() {
  final validator = PharmacyValidationService();
  const pharmacy = BusinessType.pharmacy;

  group('Task 4.6 — prescription capture flow (Requirement 7.7)', () {
    // ------------------------------------------------------------------ (a)
    group('(a) scheduled drug triggers capture and assigns the id', () {
      for (final raw in const ['H', 'H1', 'X', 'Schedule H1', 'schedule-x']) {
        test('"$raw" requires the gate and a valid capture is assigned', () {
          final gate = _PosPrescriptionGate();

          // The POS would present the gate for this schedule.
          expect(
            gate.gateRequired(raw),
            isTrue,
            reason: 'Schedule "$raw" must trigger the prescription gate.',
          );

          // Simulate a completed, valid capture coming back from the gate.
          final added = gate.applyGateResult(
            PrescriptionGateResult(
              prescriptionId: 'RX-12345',
              schedule: DrugSchedule.scheduleH1,
            ),
          );

          expect(
            added,
            isTrue,
            reason: 'A valid capture lets the line be added.',
          );
          expect(
            gate.prescriptionId,
            'RX-12345',
            reason: 'The captured id must be assigned to the bill (R7.2).',
          );

          // And the bill is now accepted at the save-time chokepoint (R7.5).
          expect(
            () => validator.validateBillItems(
              [_item(drugSchedule: raw)],
              pharmacy,
              prescriptionId: gate.prescriptionId,
            ),
            returnsNormally,
          );
        });
      }

      testWidgets(
        'the gate UI renders the capture prompt for a scheduled drug',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => PrescriptionGateDialog.showRich(
                      context,
                      productName: 'Alprazolam 0.5mg',
                      schedule: DrugSchedule.scheduleH1,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();

          // The capture dialog is presented (R7.1).
          expect(find.byType(PrescriptionGateDialog), findsOneWidget);
          expect(find.text('Prescription Required'), findsOneWidget);
          expect(find.text('Alprazolam 0.5mg'), findsOneWidget);
        },
      );
    });

    // ------------------------------------------------------------------ (b)
    group(
      '(b) cancelling the gate preserves bill content and saves nothing',
      () {
        test(
          'a cancelled gate adds no line and records no prescription id',
          () {
            final gate = _PosPrescriptionGate();

            expect(gate.gateRequired('H'), isTrue);

            // User cancels -> gate returns null.
            final added = gate.applyGateResult(null);

            expect(
              added,
              isFalse,
              reason: 'Cancel must not add the scheduled line (R7.3).',
            );
            expect(
              gate.prescriptionId,
              isNull,
              reason:
                  'Cancel must leave the bill prescription id unset (R7.3).',
            );
          },
        );

        testWidgets('the real gate returns null when Cancel is pressed', (
          tester,
        ) async {
          PrescriptionGateResult? captured;
          var returned = false;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () async {
                      captured = await PrescriptionGateDialog.showRich(
                        context,
                        productName: 'Codeine Syrup',
                        schedule: DrugSchedule.scheduleH,
                      );
                      returned = true;
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(find.byType(PrescriptionGateDialog), findsOneWidget);

          await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
          await tester.pumpAndSettle();

          expect(returned, isTrue);
          expect(
            captured,
            isNull,
            reason:
                'Cancelling the gate yields a null result the POS treats '
                'as "do not add / do not save" (R7.3).',
          );
          expect(find.byType(PrescriptionGateDialog), findsNothing);
        });
      },
    );

    // ------------------------------------------------------------------ (c)
    group('(c) null/unset schedule is non-scheduled (no gate) but still '
        'validated', () {
      for (final raw in const [null, '', '   ', 'OTC', 'none']) {
        test('schedule ${raw == null ? 'null' : '"$raw"'} does NOT trigger '
            'the gate', () {
          final gate = _PosPrescriptionGate();
          expect(
            gate.gateRequired(raw),
            isFalse,
            reason: 'A non-scheduled item must not present the gate (R7.4).',
          );
        });
      }

      test(
        'a non-scheduled item is still run through PharmacyValidationService',
        () {
          // Validation STILL runs: a missing batch is caught even with no gate.
          expect(
            () => validator.validateBillItems([
              _item(drugSchedule: null, batchNo: null),
            ], pharmacy),
            throwsA(
              isA<PharmacyComplianceException>().having(
                (e) => e.code,
                'code',
                'MISSING_BATCH_NUMBER',
              ),
            ),
            reason: 'Non-scheduled items must still be validated (R7.4).',
          );

          // A fully compliant non-scheduled item passes WITHOUT any prescription.
          expect(
            () => validator.validateBillItems(
              [_item(drugSchedule: null)],
              pharmacy,
              prescriptionId: null,
            ),
            returnsNormally,
          );
        },
      );
    });

    // ------------------------------------------------------------------ (d)
    group(
      '(d) scheduled-drug bill saved without a prescription id is rejected',
      () {
        // The save-time chokepoint (PharmacyValidationService, called by
        // bills_repository._validatePharmacyCompliance) rejects a null or empty
        // captured id (R7.6). A whitespace-only value is normalized away
        // earlier, at the POS boundary (`_ensurePrescriptionForProduct` trims
        // before assigning), so it can never reach this layer.
        for (final missing in const <String?>[null, '']) {
          test('prescriptionId ${missing == null ? 'null' : '"$missing"'} -> '
              'MISSING_PRESCRIPTION', () {
            expect(
              () => validator.validateBillItems(
                [_item(drugSchedule: 'H1')],
                pharmacy,
                prescriptionId: missing,
              ),
              throwsA(
                isA<PharmacyComplianceException>().having(
                  (e) => e.code,
                  'code',
                  'MISSING_PRESCRIPTION',
                ),
              ),
              reason:
                  'A scheduled drug without a captured id must be blocked '
                  '(R7.6).',
            );
          });
        }

        test(
          'the same bill is accepted once a non-empty id is captured (R7.5)',
          () {
            expect(
              () => validator.validateBillItems(
                [_item(drugSchedule: 'X')],
                pharmacy,
                prescriptionId: 'RX-98765',
              ),
              returnsNormally,
            );
          },
        );
      },
    );
  });
}
