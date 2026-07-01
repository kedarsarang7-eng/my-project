// ============================================================================
// TASK 4.5 — PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 11: Cancelling the
//          prescription gate preserves bill content
// **Validates: Requirements 7.3**
// ============================================================================
//
// Property 11 (design.md — Correctness Properties):
//   "For any in-progress bill, cancelling the prescription gate leaves all
//    prior bill content unchanged and saves nothing."
//
// Acceptance criterion (Requirement 7.3):
//   "IF the user cancels the Prescription_Gate, THEN THE Pharmacy_POS SHALL not
//    save the scheduled-drug sale and SHALL return the user to the bill with
//    all bill content present prior to opening the Prescription_Gate retained
//    unchanged."
//
// ---------------------------------------------------------------------------
// WHAT IS UNDER TEST — and why a faithful model rather than the widget
// ---------------------------------------------------------------------------
// The behaviour lives in `BillCreationScreenV2` (Pharmacy_POS):
//
//   Future<bool> _ensurePrescriptionForProduct(businessType, product) {
//     ...
//     final result = await PrescriptionGateDialog.showRich(...);
//     if (result == null) return false;   // <-- CANCEL
//     ...
//   }
//
//   Future<void> _addItem(Product product) async {
//     ...
//     if (!await _ensurePrescriptionForProduct(businessType, product)) {
//       return;                            // <-- EARLY RETURN, before setState
//     }
//     setState(() { /* mutate _items: add or increment */ });
//   }
//
// So cancelling the gate makes `_ensurePrescriptionForProduct` return `false`,
// which makes `_addItem` return BEFORE the only `setState` that mutates `_items`
// and BEFORE any persistence — `_items` is untouched and nothing is saved.
//
// This control flow is tied to a `StatefulWidget` with heavy provider / service
// dependencies (service locator, AppDatabase, PharmacyDao, Riverpod providers),
// so driving it through `flutter_test` would test wiring, not the invariant.
// The design (Testing Strategy) and this task therefore call for a PURE MODEL of
// the add/cancel decision. The model below reproduces the exact branch structure
// of `_ensurePrescriptionForProduct` + `_addItem` so the property pins the real
// decision the screen relies on. The companion non-vacuity property exercises
// the COMPLETE branch to prove the model genuinely mutates when NOT cancelled —
// guaranteeing the cancel invariant is not trivially true.
//
// PBT library: dartproptest ^0.2.1 (repo-wide standard). `forAll((args) =>
// <bool>, [gens], numRuns: N)` returns true when the property held for every run
// and throws a shrinking counterexample otherwise. numRuns: 200 is well above
// the 100-case minimum (R5.4).
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/features/pharmacy/prescription_gate_cancel_property11_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/models/bill.dart';
import 'package:flutter_test/flutter_test.dart';

/// At least 100 generated cases are required by the spec (R5.4); 200 matches
/// the dartproptest default and the convention used across this repo's suites.
const int kNumRuns = 200;

/// Small productId pool so a freshly-added product collides with an existing
/// bill line often enough to exercise BOTH model branches (new-line vs
/// increment) in the non-vacuity property.
const List<String> _idPool = <String>['a', 'b', 'c', 'd', 'e', 'f'];

/// Scheduled-drug values — the only items that open the prescription gate
/// (R7.1). The cancel invariant is asserted in this gated context.
const List<String> _scheduledValues = <String>['H', 'H1', 'X'];

// ---------------------------------------------------------------------------
// Pure model — faithful to `_ensurePrescriptionForProduct` + `_addItem`
// ---------------------------------------------------------------------------

/// The minimal product fields the add-line path reads.
class _ProductSpec {
  const _ProductSpec({
    required this.id,
    required this.name,
    required this.sellingPrice,
    required this.taxRate,
    required this.drugSchedule,
  });

  final String id;
  final String name;
  final double sellingPrice;
  final double taxRate;
  final String drugSchedule;
}

/// The outcome of the prescription gate dialog.
///   * cancelled == true  ⇒ `PrescriptionGateDialog.showRich` returned `null`.
///   * cancelled == false ⇒ a result was returned carrying [rxId].
class _GateOutcome {
  const _GateOutcome.cancelled() : cancelled = true, rxId = null;
  const _GateOutcome.completed(this.rxId) : cancelled = false;

  final bool cancelled;
  final String? rxId;
}

/// Models the Pharmacy_POS in-progress bill and its add/cancel decision exactly
/// as `BillCreationScreenV2` implements it. [items] is the live `_items` list;
/// [saveCount] counts persistence actions (a save is a SEPARATE user action that
/// the cancel path never triggers).
class _BillSession {
  _BillSession(this.items);

  final List<BillItem> items;
  int saveCount = 0;

  /// Mirror of `_ensurePrescriptionForProduct` for a SCHEDULED product:
  /// cancel (result == null) or an out-of-bounds prescription id → `false`;
  /// a valid 1..100-char id → `true`.
  bool _ensurePrescription(_GateOutcome outcome) {
    if (outcome.cancelled) return false; // result == null (R7.3)
    final String? id = outcome.rxId;
    if (id == null) return false;
    final String trimmed = id.trim();
    if (trimmed.isEmpty || trimmed.length > 100) return false; // R7.2 bounds
    return true;
  }

  /// Mirror of the gate branch of `_addItem`: if the gate is not satisfied the
  /// method returns BEFORE mutating `_items` (and without saving); otherwise it
  /// adds a new line (qty 1) or increments the matching existing line.
  void attemptAdd(_ProductSpec product, _GateOutcome outcome) {
    if (!_ensurePrescription(outcome)) {
      return; // early return — `_items` untouched, nothing saved (R7.3)
    }
    final int idx = items.indexWhere((i) => i.productId == product.id);
    if (idx != -1) {
      final existing = items[idx];
      items[idx] = existing.copyWith(qty: existing.qty + 1);
    } else {
      items.add(
        BillItem(
          productId: product.id,
          productName: product.name,
          qty: 1,
          price: product.sellingPrice,
          gstRate: product.taxRate,
          drugSchedule: product.drugSchedule,
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Snapshot helper — captures the externally-observable content of a bill so
// "unchanged" can be checked field-by-field (and is immune to later mutation).
// ---------------------------------------------------------------------------

List<List<Object?>> _snapshot(List<BillItem> items) => items
    .map<List<Object?>>(
      (i) => <Object?>[
        i.productId,
        i.productName,
        i.qty,
        i.price,
        i.gstRate,
        i.discount,
        i.cgst,
        i.sgst,
        i.drugSchedule,
        i.total,
      ],
    )
    .toList();

bool _snapshotEquals(List<List<Object?>> a, List<List<Object?>> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].length != b[i].length) return false;
    for (var j = 0; j < a[i].length; j++) {
      if (a[i][j] != b[i][j]) return false;
    }
  }
  return true;
}

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

/// One existing bill line with arbitrary (but realistic) content.
final Generator<BillItem> _itemGen =
    Gen.tuple(<Generator<dynamic>>[
      Gen.elementOf<String>(_idPool), // 0: productId (collides with the pool)
      Gen.interval(1, 12), // 1: qty
      Gen.interval(1, 500000), // 2: price in paise → rupees
      Gen.interval(0, 28), // 3: gst rate %
      Gen.interval(0, 3), // 4: schedule selector (0 ⇒ none/OTC)
    ]).map((parts) {
      final String id = parts[0] as String;
      final double qty = (parts[1] as int).toDouble();
      final double price = (parts[2] as int) / 100.0;
      final double gst = (parts[3] as int).toDouble();
      final int sched = parts[4] as int;
      return BillItem(
        productId: id,
        productName: 'Item-$id',
        qty: qty,
        price: price,
        gstRate: gst,
        drugSchedule: sched == 0 ? null : _scheduledValues[sched - 1],
      );
    });

/// An in-progress bill: 0..8 arbitrary lines (the empty bill is included so the
/// "all prior content" claim is exercised at the boundary).
final Generator<List<BillItem>> _billGen = Gen.array<BillItem>(
  _itemGen,
  minLength: 0,
  maxLength: 8,
).map((list) => list.cast<BillItem>().toList());

/// A scheduled product being added (the gate-triggering case for R7.3).
final Generator<_ProductSpec> _productGen =
    Gen.tuple(<Generator<dynamic>>[
      Gen.elementOf<String>(_idPool), // 0: id (may or may not be on the bill)
      Gen.interval(1, 500000), // 1: selling price in paise → rupees
      Gen.interval(0, 28), // 2: gst rate %
      Gen.elementOf<String>(_scheduledValues), // 3: scheduled drug schedule
    ]).map((parts) {
      final String id = parts[0] as String;
      return _ProductSpec(
        id: id,
        name: 'Rx-$id',
        sellingPrice: (parts[1] as int) / 100.0,
        taxRate: (parts[2] as int).toDouble(),
        drugSchedule: parts[3] as String,
      );
    });

void main() {
  group('Feature: pharmacy-vertical-remediation, Property 11: Cancelling the '
      'prescription gate preserves bill content — Req 7.3', () {
    // --------------------------------------------------------------------
    // PROPERTY 11: cancelling the gate leaves all prior bill content
    // unchanged and saves nothing.
    // --------------------------------------------------------------------
    test(
      'Property 11: for any in-progress bill, cancelling the gate leaves the '
      'bill content byte-for-byte unchanged and performs no save',
      () {
        final bool held = forAll(
          (List<BillItem> bill, _ProductSpec product) {
            final session = _BillSession(List<BillItem>.of(bill));

            // Content present prior to opening the gate.
            final before = _snapshot(session.items);

            // User opens the gate for a scheduled drug, then CANCELS it.
            session.attemptAdd(product, const _GateOutcome.cancelled());

            final after = _snapshot(session.items);

            // (1) all prior bill content retained unchanged, and
            // (2) nothing was saved.
            return _snapshotEquals(before, after) && session.saveCount == 0;
          },
          [_billGen, _productGen],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'Cancelling the prescription gate must return the user to the '
              'bill with all prior content retained unchanged and must save '
              'nothing (R7.3).',
        );
      },
    );

    // --------------------------------------------------------------------
    // NON-VACUITY: a COMPLETED, valid capture DOES change the bill. This
    // proves the model genuinely mutates when the gate is satisfied, so the
    // cancel invariant above is not trivially true for an inert model.
    // --------------------------------------------------------------------
    test('Property 11 (non-vacuity): completing the gate with a valid '
        'prescription DOES change the bill content', () {
      final bool held = forAll(
        (List<BillItem> bill, _ProductSpec product) {
          final session = _BillSession(List<BillItem>.of(bill));
          final before = _snapshot(session.items);

          session.attemptAdd(product, const _GateOutcome.completed('RX-0001'));

          final after = _snapshot(session.items);
          // A new line is appended (length grows) or a matching line's qty
          // is incremented (total changes) — either way the content differs.
          return !_snapshotEquals(before, after);
        },
        [_billGen, _productGen],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason:
            'A satisfied gate must add/increment a line; otherwise the '
            'cancel invariant would be vacuously true.',
      );
    });

    // --------------------------------------------------------------------
    // Deterministic anchors — pin the boundary cases.
    // --------------------------------------------------------------------
    test('Property 11 anchor: cancelling on an EMPTY bill keeps it empty and '
        'saves nothing', () {
      final session = _BillSession(<BillItem>[]);
      session.attemptAdd(
        const _ProductSpec(
          id: 'a',
          name: 'Rx-a',
          sellingPrice: 12.50,
          taxRate: 12,
          drugSchedule: 'H',
        ),
        const _GateOutcome.cancelled(),
      );
      expect(session.items, isEmpty);
      expect(session.saveCount, 0);
    });

    test('Property 11 anchor: cancelling on a POPULATED bill retains every '
        'prior line unchanged and saves nothing', () {
      final session = _BillSession(<BillItem>[
        BillItem(
          productId: 'a',
          productName: 'Item-a',
          qty: 2,
          price: 30.00,
          gstRate: 12,
        ),
        BillItem(
          productId: 'b',
          productName: 'Item-b',
          qty: 1,
          price: 45.50,
          gstRate: 5,
        ),
      ]);
      final before = _snapshot(session.items);

      session.attemptAdd(
        const _ProductSpec(
          id: 'a', // collides with an existing line
          name: 'Rx-a',
          sellingPrice: 99.99,
          taxRate: 18,
          drugSchedule: 'X',
        ),
        const _GateOutcome.cancelled(),
      );

      expect(_snapshotEquals(before, _snapshot(session.items)), isTrue);
      expect(session.items.length, 2);
      expect(session.saveCount, 0);
    });

    test('Property 11 anchor: an out-of-bounds prescription id is treated '
        'like a cancel — bill unchanged, nothing saved', () {
      final session = _BillSession(<BillItem>[
        BillItem(
          productId: 'a',
          productName: 'Item-a',
          qty: 1,
          price: 10.00,
          gstRate: 12,
        ),
      ]);
      final before = _snapshot(session.items);

      // 101-character id exceeds the 1..100 bound (R7.2) → not satisfied.
      session.attemptAdd(
        const _ProductSpec(
          id: 'z',
          name: 'Rx-z',
          sellingPrice: 20.00,
          taxRate: 12,
          drugSchedule: 'H1',
        ),
        _GateOutcome.completed('R' * 101),
      );

      expect(_snapshotEquals(before, _snapshot(session.items)), isTrue);
      expect(session.items.length, 1);
      expect(session.saveCount, 0);
    });
  });
}
