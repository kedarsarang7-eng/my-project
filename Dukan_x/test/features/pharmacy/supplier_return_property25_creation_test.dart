// ============================================================================
// TASK 16.2 — PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 25: Supplier expiry-return
//          creation conditions
// **Validates: Requirements 19.1, 19.2, 19.3**
// ============================================================================
//
// Property 25 (design.md — Correctness Properties):
//   "For any batch and return quantity, a credit note linked to the supplier
//    and batch is created if and only if the batch expiry is on or before the
//    current date and the quantity is between 1 and the available batch
//    quantity inclusive; otherwise the return is rejected with the appropriate
//    error (not-expired or invalid-quantity) and no credit note is created."
//
// Requirements:
//   R19.1  A batch expired on/before today creates a credit note linked to the
//          supplier id + batch id.
//   R19.2  A future-dated (not-yet-expired) batch is rejected with "not
//          expired" and NO credit note is created.
//   R19.3  Quantity < 1 or > available is rejected with an invalid-quantity
//          error and NO credit note is created.
//
// Under test: SupplierExpiryReturnService.createExpiryReturn(...)
//   (lib/features/pharmacy/services/supplier_expiry_return_service.dart)
//
// SCOPE — this is the *creation conditions* property. Amount boundedness
// (R19.4) is Property 26's job, so here the amount is always held in-bounds and
// therefore never gates creation. What decides creation is exactly:
//
//   expiredOk(e)  := e is on/before today (date-only)         -> R19.1 / R19.2
//   qtyOk(q, a)   := 1 <= q && q <= a                         -> R19.3
//   created       <=> expiredOk(e) && qtyOk(q, a)
//
// The property is proven against an INDEPENDENT ORACLE that restates the
// acceptance criteria in plain logic and never calls the production checks.
//
// REJECTION-REASON PRECEDENCE: the service evaluates expiry BEFORE quantity, so
// when a batch is both future-dated AND has an invalid quantity the surfaced
// reason is `notExpired`. The oracle models this same precedence so the
// reason assertion is exact:
//
//   reason := !expiredOk ? notExpired : (!qtyOk ? invalidQuantity : <none>)
//
// Two surfaces are exercised:
//   (A) FOCUSED — amount held valid; expiry and quantity randomised. Confirms
//       created <=> expiredOk && qtyOk, that a created note is linked to the
//       originating supplier + batch, and that a rejection carries the correct
//       reason and persists nothing.
//   (B) UNIVERSAL — same randomisation with the supplier/batch ids varied too,
//       re-confirming the iff and the no-persistence-on-rejection safety rule.
//
// Dependencies are faked so the test is pure (no DB / no DI):
//   - TenantScope over a fake SessionManager that always resolves a tenant.
//   - A fake CreditNoteRepository that captures the persisted CreditNote.
//   - A real RidGenerator (only needs a non-blank tenantId).
//
// PBT library: dartproptest (repo-wide standard). createExpiryReturn is async,
// so — mirroring the sibling Property 26 suite — generators are sampled inside
// an explicit loop rather than via the sync `forAll`. At least 100 generated
// cases are required by the spec (R5.4); 200 matches the repo convention.
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/features/pharmacy/supplier_return_property25_creation_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/services/rid_generator.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/features/credit_notes/data/models/credit_note_model.dart';
import 'package:dukanx/features/credit_notes/data/repositories/credit_note_repository.dart';
import 'package:dukanx/features/pharmacy/services/supplier_expiry_return_service.dart';
import 'package:dukanx/features/pharmacy/utils/tenant_scope.dart';
import 'package:flutter_test/flutter_test.dart';

/// At least 100 generated cases are required (R5.4); 200 matches convention.
const int kNumRuns = 200;

/// A fixed "now" so expiry comparisons are deterministic. The service compares
/// by calendar date (time-of-day ignored), so a batch expiring today (offset 0)
/// is eligible.
final DateTime kNow = DateTime(2024, 6, 15, 10, 30);

/// An always-valid in-bounds amount so the amount check (R19.4) never gates
/// creation in this property — only expiry and quantity decide.
const int kValidAmount = 12345;

// ---------------------------------------------------------------------------
// Fakes — keep the test pure (no database, no service locator)
// ---------------------------------------------------------------------------

/// Always resolves a fixed, non-blank tenant so TenantScope.require() succeeds.
class _FakeSessionManager extends Fake implements SessionManager {
  @override
  String? get currentBusinessId => 'tenant-25';
}

/// Captures the CreditNote handed to persistence so the test can assert the
/// supplier/batch linkage, and reports success without touching a database.
class _CapturingCreditNoteRepository extends Fake
    implements CreditNoteRepository {
  CreditNote? lastCreated;

  @override
  Future<CreditNoteResult<CreditNote>> createCreditNote(
    CreditNote creditNote,
  ) async {
    lastCreated = creditNote;
    return CreditNoteResult.success(creditNote);
  }
}

SupplierExpiryReturnService _buildService(_CapturingCreditNoteRepository repo) {
  return SupplierExpiryReturnService(
    tenantScope: TenantScope(session: _FakeSessionManager()),
    ridGenerator: RidGenerator(),
    repository: repo,
  );
}

// ---------------------------------------------------------------------------
// Independent oracle (pure logic; never calls the production checks)
// ---------------------------------------------------------------------------

/// Calendar-date eligibility: a batch expiring on/before today is eligible.
/// With whole-day offsets this is exactly `offsetDays <= 0`.
bool _expiredOk(int offsetDays) => offsetDays <= 0;

bool _qtyOk(int qty, int available) => qty >= 1 && qty <= available;

/// The expected rejection reason, modelling the service's check precedence
/// (expiry is evaluated before quantity). Returns null when the input should be
/// accepted.
SupplierReturnRejectionReason? _expectedReason(
  int offsetDays,
  int qty,
  int available,
) {
  if (!_expiredOk(offsetDays)) return SupplierReturnRejectionReason.notExpired;
  if (!_qtyOk(qty, available)) {
    return SupplierReturnRejectionReason.invalidQuantity;
  }
  return null;
}

DateTime _expiryFromOffset(int offsetDays) =>
    DateTime(kNow.year, kNow.month, kNow.day + offsetDays);

/// Recovers the supplier/batch linkage the service encoded into the existing
/// credit-note attributes (storage-decisions.md / R4 — no new column).
Map<String, dynamic>? _decodeLink(CreditNote note) =>
    SupplierBatchLink.decodeReason(note.reason);

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

/// Whole-day expiry offset from [kNow]: negatives/zero are expired (eligible),
/// positives are future (not expired). Extra weight near 0 probes the
/// today-boundary (R19.1 inclusivity).
final Generator<int> _offsetGen = Gen.oneOf<int>(<Generator<int>>[
  Gen.interval(-3650, 3650), // full span: long-expired through far-future
  Gen.interval(-2, 2), // around the today boundary
]);

/// Available batch quantity. 0 makes every quantity invalid; positive values
/// open a valid window.
final Generator<int> _availableGen = Gen.oneOf<int>(<Generator<int>>[
  Gen.interval(0, 100000),
  Gen.interval(0, 10), // small windows so the [1, available] edges are hit
]);

/// Requested quantity spanning invalid (<1) and the valid/over-available range.
final Generator<int> _quantityGen = Gen.oneOf<int>(<Generator<int>>[
  Gen.interval(-5, 100005),
  Gen.interval(-2, 12), // near the lower edge and small-window upper edges
]);

/// Non-blank supplier/batch identifiers derived from a small integer.
final Generator<int> _idGen = Gen.interval(1, 9999);

void main() {
  group('Feature: pharmacy-vertical-remediation, Property 25: Supplier '
      'expiry-return creation conditions — Req 19.1, 19.2, 19.3', () {
    // --------------------------------------------------------------------
    // (A) FOCUSED: amount held valid; expiry + quantity decide creation.
    //     created <=> expiredOk && qtyOk; a created note is linked to the
    //     originating supplier + batch; a rejection carries the correct
    //     reason (notExpired vs invalidQuantity) and persists nothing.
    // --------------------------------------------------------------------
    test('Property 25a: with a valid amount, a return is created iff the batch '
        'is expired on/before today AND quantity is in [1, available]; '
        'otherwise it is rejected with the matching reason and nothing is '
        'persisted', () async {
      final failures = <String>[];
      final rng = Random();

      for (var run = 0; run < kNumRuns; run++) {
        final offset = _offsetGen.generate(rng).value;
        final available = _availableGen.generate(rng).value;
        final quantity = _quantityGen.generate(rng).value;

        final supplierId = 'sup-$run';
        final batchId = 'batch-$run';

        final repo = _CapturingCreditNoteRepository();
        final service = _buildService(repo);

        final result = await service.createExpiryReturn(
          supplierId: supplierId,
          batchId: batchId,
          batchExpiryDate: _expiryFromOffset(offset),
          quantity: quantity,
          availableQuantity: available,
          amountPaise: kValidAmount,
          now: kNow,
        );

        final shouldCreate = _expiredOk(offset) && _qtyOk(quantity, available);

        if (result.created != shouldCreate) {
          failures.add(
            'offset=$offset qty=$quantity avail=$available '
            'expected created=$shouldCreate got created=${result.created} '
            '(reason=${result.reason})',
          );
          continue;
        }

        if (result.created) {
          // R19.1: a created note links the originating supplier + batch.
          final note = result.creditNote!;
          final link = _decodeLink(repo.lastCreated!);
          final linked =
              note.supplierId == supplierId &&
              note.batchId == batchId &&
              repo.lastCreated != null &&
              repo.lastCreated!.customerId == supplierId &&
              link != null &&
              link['supplierId'] == supplierId &&
              link['batchId'] == batchId;
          if (!linked) {
            failures.add(
              'created note not linked to supplier=$supplierId '
              'batch=$batchId (note.supplierId=${note.supplierId}, '
              'note.batchId=${note.batchId}, link=$link)',
            );
          }
        } else {
          // R19.2 / R19.3: correct rejection reason, nothing persisted.
          final expectedReason = _expectedReason(offset, quantity, available);
          if (result.reason != expectedReason || repo.lastCreated != null) {
            failures.add(
              'rejection mismatch offset=$offset qty=$quantity '
              'avail=$available expectedReason=$expectedReason '
              'got=${result.reason} persisted=${repo.lastCreated}',
            );
          }
        }
      }

      expect(
        failures,
        isEmpty,
        reason:
            'A supplier-return credit note is created iff the batch is '
            'expired on/before today AND the quantity is in [1, available]; '
            'otherwise it is rejected (not-expired before invalid-quantity) '
            'with no persistence. First failures: '
            '${failures.take(3).join(" | ")}',
      );
    });

    // --------------------------------------------------------------------
    // (B) UNIVERSAL: supplier/batch ids also randomised. Re-confirms the iff
    //     and the safety rule that a rejected return persists nothing.
    // --------------------------------------------------------------------
    test('Property 25b: across arbitrary supplier/batch/expiry/quantity, '
        'creation matches the expiry-and-quantity predicate and rejections '
        'never persist a credit note', () async {
      final failures = <String>[];
      final rng = Random();

      for (var run = 0; run < kNumRuns; run++) {
        final supplierId = 'sup-${_idGen.generate(rng).value}';
        final batchId = 'batch-${_idGen.generate(rng).value}';
        final offset = _offsetGen.generate(rng).value;
        final available = _availableGen.generate(rng).value;
        final quantity = _quantityGen.generate(rng).value;

        final repo = _CapturingCreditNoteRepository();
        final service = _buildService(repo);

        final result = await service.createExpiryReturn(
          supplierId: supplierId,
          batchId: batchId,
          batchExpiryDate: _expiryFromOffset(offset),
          quantity: quantity,
          availableQuantity: available,
          amountPaise: kValidAmount,
          now: kNow,
        );

        final shouldCreate = _expiredOk(offset) && _qtyOk(quantity, available);

        if (result.created != shouldCreate) {
          failures.add(
            'sup=$supplierId batch=$batchId offset=$offset qty=$quantity '
            'avail=$available expected created=$shouldCreate '
            'got created=${result.created} (reason=${result.reason})',
          );
          continue;
        }

        if (result.created) {
          if (repo.lastCreated == null) {
            failures.add('created return persisted nothing (run=$run)');
          }
        } else {
          final expectedReason = _expectedReason(offset, quantity, available);
          if (result.reason != expectedReason) {
            failures.add(
              'wrong reason sup=$supplierId batch=$batchId offset=$offset '
              'qty=$quantity avail=$available expected=$expectedReason '
              'got=${result.reason}',
            );
          } else if (repo.lastCreated != null) {
            failures.add(
              'rejected return must persist nothing but did '
              '(offset=$offset qty=$quantity avail=$available)',
            );
          }
        }
      }

      expect(
        failures,
        isEmpty,
        reason:
            'Creation must match (expired on/before today) AND '
            '(1 <= qty <= available); rejected returns persist nothing. '
            'First failures: ${failures.take(3).join(" | ")}',
      );
    });

    // --------------------------------------------------------------------
    // Deterministic anchors — pin the boundaries of R19.1/R19.2/R19.3.
    // --------------------------------------------------------------------
    test('Property 25 anchors: today-expiry is eligible; future-dated rejects '
        'as not-expired; qty 0 and qty>available reject as invalid-quantity; '
        'expiry precedence over quantity', () async {
      Future<({SupplierExpiryReturnResult res, CreditNote? saved})> attempt({
        required int offset,
        required int quantity,
        required int available,
      }) async {
        final repo = _CapturingCreditNoteRepository();
        final res = await _buildService(repo).createExpiryReturn(
          supplierId: 's1',
          batchId: 'b1',
          batchExpiryDate: _expiryFromOffset(offset),
          quantity: quantity,
          availableQuantity: available,
          amountPaise: kValidAmount,
          now: kNow,
        );
        return (res: res, saved: repo.lastCreated);
      }

      // R19.1: a batch expiring TODAY (offset 0) with a valid quantity is
      // created and linked to the supplier + batch.
      final today = await attempt(offset: 0, quantity: 3, available: 10);
      expect(today.res.created, isTrue);
      expect(today.res.creditNote!.supplierId, 's1');
      expect(today.res.creditNote!.batchId, 'b1');
      expect(today.saved, isNotNull);
      expect(today.saved!.customerId, 's1');

      // A past batch with a valid quantity is also created.
      final past = await attempt(offset: -1, quantity: 1, available: 1);
      expect(past.res.created, isTrue);

      // R19.2: a future-dated batch rejects as not-expired, no note.
      final future = await attempt(offset: 1, quantity: 3, available: 10);
      expect(future.res.created, isFalse);
      expect(future.res.reason, SupplierReturnRejectionReason.notExpired);
      expect(future.saved, isNull);

      // R19.3: quantity below 1 rejects as invalid-quantity, no note.
      final zeroQty = await attempt(offset: -1, quantity: 0, available: 10);
      expect(zeroQty.res.created, isFalse);
      expect(zeroQty.res.reason, SupplierReturnRejectionReason.invalidQuantity);
      expect(zeroQty.saved, isNull);

      // R19.3: quantity above available rejects as invalid-quantity.
      final overQty = await attempt(offset: -1, quantity: 11, available: 10);
      expect(overQty.res.created, isFalse);
      expect(overQty.res.reason, SupplierReturnRejectionReason.invalidQuantity);
      expect(overQty.saved, isNull);

      // Quantity exactly at the available bound is accepted (inclusive).
      final atBound = await attempt(offset: -1, quantity: 10, available: 10);
      expect(atBound.res.created, isTrue);

      // Precedence: future-dated AND invalid quantity surfaces not-expired
      // (expiry is checked before quantity).
      final both = await attempt(offset: 5, quantity: 0, available: 10);
      expect(both.res.created, isFalse);
      expect(both.res.reason, SupplierReturnRejectionReason.notExpired);
      expect(both.saved, isNull);
    });
  });
}
