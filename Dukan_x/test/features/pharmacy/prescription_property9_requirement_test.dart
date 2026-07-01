// ============================================================================
// TASK 4.3 — PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 9: Scheduled-drug sales require a captured prescription
// **Validates: Requirements 7.1, 7.5, 7.6**
// ============================================================================
//
// Property 9 (design.md — Correctness Properties):
//   "For any bill containing at least one item whose resolved schedule is in
//    {H, H1, X}, the bill is accepted and persisted if and only if a non-empty
//    captured prescription identifier is present; otherwise the save is
//    rejected with `MISSING_PRESCRIPTION` and the bill remains unsaved with its
//    in-progress content retained."
//
// SURFACE UNDER TEST
//   `PharmacyValidationService.validateBillItems(items, businessType,
//   prescriptionId:)` is the pure-logic compliance gate the bills repository
//   delegates to (design.md — `bills_repository._validatePharmacyCompliance`).
//   "Accepted/persisted" maps to "validation returns without throwing"; a
//   rejection maps to a thrown `PharmacyComplianceException` whose code is
//   `MISSING_PRESCRIPTION`. The repository wrapper that turns that exception
//   into an unsaved bill is covered by the example/integration tests; this
//   property pins the gate itself.
//
// INDEPENDENT ORACLE (never calls DrugScheduleResolver / the production gate)
//   Each generated item carries a raw `drugSchedule` string drawn from a pool
//   whose scheduled-ness ({H,H1,X} ⇒ true, everything else ⇒ false) is encoded
//   alongside the string by the test itself. The oracle is therefore plain
//   boolean logic over the generated labels:
//
//     anyScheduled    := items.any((i) => i.scheduledByConstruction)
//     hasPrescription := prescriptionId != null && prescriptionId.isNotEmpty
//     shouldReject     := anyScheduled && !hasPrescription
//
//   The bill must be REJECTED with `MISSING_PRESCRIPTION` iff `shouldReject`,
//   and ACCEPTED (no throw) otherwise.
//
// ISOLATION
//   Every generated item is given a valid batch number and a future expiry so
//   the only compliance dimension that can change the accept/reject outcome is
//   the prescription requirement (Rule 0 of the validation service, evaluated
//   before the batch/expiry checks). This keeps the property strictly about
//   Property 9 and not about expiry/batch validation (Property 24, Task 18).
//
// NON-MUTATION
//   Validation must not alter in-progress bill content (R7.6 "retains all
//   in-progress bill content"). Each run snapshots every item's schedule,
//   batch, and expiry and asserts they are unchanged after validation.
//
// PBT library: dartproptest ^0.2.1 (repo-wide standard). `forAll` returns true
//   when the property held for every run and throws a shrinking counterexample
//   otherwise.
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/features/pharmacy/prescription_property9_requirement_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/billing/business_type_config.dart';
import 'package:dukanx/core/error/pharmacy_compliance_exception.dart';
import 'package:dukanx/core/services/pharmacy_validation_service.dart';
import 'package:dukanx/models/bill.dart';
import 'package:flutter_test/flutter_test.dart';

/// At least 100 generated cases are required by the spec (R5.4); 200 matches
/// the dartproptest default and the convention used across this repo's suites.
const int kNumRuns = 200;

/// A fixed future expiry and a non-empty batch number so the batch/expiry
/// branches of the validation service never fire — the prescription gate is
/// the only dimension under test.
final DateTime _futureExpiry = DateTime.now().add(const Duration(days: 365));
const String _validBatch = 'BATCH-001';

// ---------------------------------------------------------------------------
// Schedule pool — each entry pairs a raw `drugSchedule` string with the
// test's INDEPENDENT knowledge of whether it is a {H,H1,X} scheduled drug.
// Includes mixed casing / whitespace / separators (all canonically scheduled),
// OTC / empty / null / unrecognized values (all non-scheduled for gating).
// ---------------------------------------------------------------------------

class _Sched {
  const _Sched(this.raw, this.scheduled);
  final String? raw;
  final bool scheduled;
}

const List<_Sched> _schedPool = <_Sched>[
  // Scheduled (resolve to H / H1 / X — prescription required).
  _Sched('H', true),
  _Sched('h', true),
  _Sched(' H1 ', true),
  _Sched('H1', true),
  _Sched('X', true),
  _Sched('Schedule-H', true),
  _Sched('scheduleH1', true),
  _Sched('schedule x', true),
  // Non-scheduled (OTC / empty / null / unrecognized — no prescription needed).
  _Sched('OTC', false),
  _Sched('none', false),
  _Sched('', false),
  _Sched(null, false),
  _Sched('G', false), // unrecognized → not scheduled for gating
  _Sched('Schedule K', false), // unrecognized
  _Sched('random-value', false), // unrecognized
];

// ---------------------------------------------------------------------------
// Case model + generators
// ---------------------------------------------------------------------------

class _BillCase {
  const _BillCase(this.scheds, this.prescriptionId);
  final List<_Sched> scheds;
  final String? prescriptionId;

  bool get anyScheduled => scheds.any((s) => s.scheduled);
  bool get hasPrescription =>
      prescriptionId != null && prescriptionId!.isNotEmpty;
  bool get shouldReject => anyScheduled && !hasPrescription;
}

/// One item's schedule, indexed into [_schedPool].
final Generator<_Sched> _schedGen = Gen.interval(
  0,
  _schedPool.length - 1,
).map((i) => _schedPool[i as int]);

/// 1..6 items so single-item, all-scheduled, all-OTC, and mixed bills all occur.
final Generator<List<_Sched>> _itemsGen = Gen.array<_Sched>(
  _schedGen,
  minLength: 1,
  maxLength: 6,
).map((list) => list.cast<_Sched>().toList());

/// Prescription identifier: 0 ⇒ null (absent), 1 ⇒ '' (empty), 2 ⇒ non-empty.
/// The numeric suffix varies the non-empty value across runs.
final Generator<String?> _prescriptionGen =
    Gen.tuple(<Generator<dynamic>>[
      Gen.interval(0, 2),
      Gen.interval(1, 1000000),
    ]).map((parts) {
      final kind = parts[0] as int;
      final suffix = parts[1] as int;
      switch (kind) {
        case 0:
          return null;
        case 1:
          return '';
        default:
          return 'RX-$suffix';
      }
    });

final Generator<_BillCase> _billCaseGen =
    Gen.tuple(<Generator<dynamic>>[_itemsGen, _prescriptionGen]).map((parts) {
      final scheds = (parts[0] as List).cast<_Sched>();
      final presc = parts[1] as String?;
      return _BillCase(scheds, presc);
    });

// ---------------------------------------------------------------------------
// Builder — each item carries a valid batch + future expiry so only the
// prescription gate can change the accept/reject outcome.
// ---------------------------------------------------------------------------

List<BillItem> _buildItems(_BillCase c) {
  final items = <BillItem>[];
  for (var i = 0; i < c.scheds.length; i++) {
    items.add(
      BillItem(
        productId: 'p$i',
        productName: 'Item $i',
        qty: 1,
        price: 10.0,
        batchNo: _validBatch,
        expiryDate: _futureExpiry,
        drugSchedule: c.scheds[i].raw,
      ),
    );
  }
  return items;
}

void main() {
  final service = PharmacyValidationService();

  group(
    'Feature: pharmacy-vertical-remediation, Property 9: Scheduled-drug sales '
    'require a captured prescription — Req 7.1, 7.5, 7.6',
    () {
      // --------------------------------------------------------------------
      // Core property: accepted iff (no scheduled item) OR (non-empty
      // prescription); otherwise rejected with MISSING_PRESCRIPTION, and the
      // in-progress bill content is left unchanged.
      // --------------------------------------------------------------------
      test('Property 9: a scheduled-drug bill is accepted iff a non-empty '
          'prescription id is present, else rejected with MISSING_PRESCRIPTION '
          'without mutating bill content', () {
        final bool held = forAll(
          (_BillCase c) {
            final items = _buildItems(c);

            // Snapshot in-progress content to prove non-mutation (R7.6).
            final beforeSchedules = items.map((e) => e.drugSchedule).toList();
            final beforeBatches = items.map((e) => e.batchNo).toList();
            final beforeExpiries = items.map((e) => e.expiryDate).toList();

            bool threw = false;
            String? thrownCode;
            try {
              service.validateBillItems(
                items,
                BusinessType.pharmacy,
                prescriptionId: c.prescriptionId,
              );
            } on PharmacyComplianceException catch (e) {
              threw = true;
              thrownCode = e.code;
            }

            // 1. Accept/reject decision matches the oracle.
            if (c.shouldReject) {
              if (!threw) return false;
              if (thrownCode != 'MISSING_PRESCRIPTION') return false;
            } else {
              if (threw) return false;
            }

            // 2. Validation never mutated the in-progress bill content.
            for (var i = 0; i < items.length; i++) {
              if (items[i].drugSchedule != beforeSchedules[i]) return false;
              if (items[i].batchNo != beforeBatches[i]) return false;
              if (items[i].expiryDate != beforeExpiries[i]) return false;
            }

            return true;
          },
          [_billCaseGen],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'A bill with a Schedule H/H1/X item must be rejected with '
              'MISSING_PRESCRIPTION unless a non-empty prescription id is '
              'supplied; all other bills are accepted, and validation never '
              'alters the in-progress bill content.',
        );
      });

      // --------------------------------------------------------------------
      // Deterministic anchors — pin each clause and prove non-vacuity.
      // --------------------------------------------------------------------
      test('Property 9 anchor: scheduled item without prescription is rejected '
          '(null and empty id)', () {
        for (final presc in <String?>[null, '']) {
          final items = [
            BillItem(
              productId: 'p0',
              productName: 'Alprazolam',
              qty: 1,
              price: 10.0,
              batchNo: _validBatch,
              expiryDate: _futureExpiry,
              drugSchedule: 'H1',
            ),
          ];
          expect(
            () => service.validateBillItems(
              items,
              BusinessType.pharmacy,
              prescriptionId: presc,
            ),
            throwsA(
              isA<PharmacyComplianceException>().having(
                (e) => e.code,
                'code',
                'MISSING_PRESCRIPTION',
              ),
            ),
            reason:
                'scheduled drug + ${presc == null ? 'null' : 'empty'} '
                'prescription must be rejected',
          );
        }
      });

      test('Property 9 anchor: scheduled item WITH a non-empty prescription is '
          'accepted', () {
        final items = [
          BillItem(
            productId: 'p0',
            productName: 'Alprazolam',
            qty: 1,
            price: 10.0,
            batchNo: _validBatch,
            expiryDate: _futureExpiry,
            drugSchedule: 'X',
          ),
        ];
        expect(
          () => service.validateBillItems(
            items,
            BusinessType.pharmacy,
            prescriptionId: 'RX-2024-001',
          ),
          returnsNormally,
        );
      });

      test('Property 9 anchor: bill of only non-scheduled / unrecognized items '
          'is accepted with no prescription', () {
        final items = [
          BillItem(
            productId: 'p0',
            productName: 'Paracetamol (OTC)',
            qty: 1,
            price: 10.0,
            batchNo: _validBatch,
            expiryDate: _futureExpiry,
            drugSchedule: 'OTC',
          ),
          BillItem(
            productId: 'p1',
            productName: 'Unrecognized schedule',
            qty: 1,
            price: 10.0,
            batchNo: _validBatch,
            expiryDate: _futureExpiry,
            drugSchedule: 'Schedule K',
          ),
          BillItem(
            productId: 'p2',
            productName: 'No schedule',
            qty: 1,
            price: 10.0,
            batchNo: _validBatch,
            expiryDate: _futureExpiry,
            drugSchedule: null,
          ),
        ];
        expect(
          () => service.validateBillItems(
            items,
            BusinessType.pharmacy,
            prescriptionId: null,
          ),
          returnsNormally,
        );
      });

      test('Property 9 anchor: a mixed bill (scheduled + OTC) needs only one '
          'prescription to be accepted', () {
        final items = [
          BillItem(
            productId: 'p0',
            productName: 'OTC item',
            qty: 1,
            price: 10.0,
            batchNo: _validBatch,
            expiryDate: _futureExpiry,
            drugSchedule: 'OTC',
          ),
          BillItem(
            productId: 'p1',
            productName: 'Schedule H item',
            qty: 1,
            price: 10.0,
            batchNo: _validBatch,
            expiryDate: _futureExpiry,
            drugSchedule: 'H',
          ),
        ];
        // Without a prescription → rejected because of the scheduled line.
        expect(
          () => service.validateBillItems(
            items,
            BusinessType.pharmacy,
            prescriptionId: '',
          ),
          throwsA(
            isA<PharmacyComplianceException>().having(
              (e) => e.code,
              'code',
              'MISSING_PRESCRIPTION',
            ),
          ),
        );
        // With a prescription → accepted.
        expect(
          () => service.validateBillItems(
            items,
            BusinessType.pharmacy,
            prescriptionId: 'RX-9',
          ),
          returnsNormally,
        );
      });
    },
  );
}
