// ============================================================================
// TASK 16.3 — PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 26: Credit note amount is a
//          bounded non-negative integer paise
// **Validates: Requirements 19.4**
// ============================================================================
//
// Property 26 (design.md — Correctness Properties):
//   "For any created supplier-return credit note, its stored amount is a
//    non-negative integer paise value within the inclusive range
//    [0, 999,999,999,999]."
//
// Requirement 19.4:
//   "THE System SHALL compute and store each credit note monetary amount as a
//    non-negative integer value in paise within the range 0 to 999,999,999,999."
//
// Under test: SupplierExpiryReturnService.createExpiryReturn(...)
//   (lib/features/pharmacy/services/supplier_expiry_return_service.dart)
//
// The amount is carried as a Dart `int` (paise) end-to-end — the in-memory
// SupplierExpiryCreditNote keeps `amountPaise` as an `int`, and the encoded
// supplier/batch link persists that same integer paise value — so integrality
// is structural. The boundedness rule (R19.4) is the behavioural part the
// service enforces: amounts < 0 or > 999,999,999,999 are rejected with
// `invalidAmount` and NO credit note is created, so every *created* note's
// stored amount necessarily lands in [0, 999,999,999,999].
//
// The property is proven against an INDEPENDENT ORACLE that restates the
// acceptance criteria in plain integer logic and never calls the production
// bounds comparison:
//
//   amountOk(p)   := 0 <= p && p <= 999,999,999,999
//   expiredOk(e)  := the expiry day is on/before today (date-only)
//   qtyOk(q, a)   := 1 <= q && q <= a
//   created       <=> amountOk && expiredOk && qtyOk
//
// Two surfaces are exercised:
//   (A) FOCUSED — expiry and quantity held valid so the amount alone decides
//       creation. Confirms created <=> amountOk, that every created note's
//       stored amountPaise equals the (in-bounds) input, and that the persisted
//       credit note carries that exact integer paise value.
//   (B) UNIVERSAL — every input randomised. Confirms the safety direction of
//       Property 26: whenever a note IS created, its stored amount is a
//       non-negative integer paise within [0, kMax]; nothing is persisted on
//       rejection.
//
// Dependencies are faked so the test is pure (no DB / no service locator):
//   - TenantScope over a fake SessionManager that always resolves a tenant.
//   - A fake CreditNoteRepository that captures the persisted CreditNote.
//   - A real RidGenerator (only needs a non-blank tenantId).
//
// PBT library: dartproptest (repo-wide standard). `forAllAsync` returns true
// when the property held for every async run and throws a shrinking
// counterexample otherwise. At least 100 generated cases are required by the
// spec (R5.4); 200 matches the convention used across this repo's suites.
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/features/pharmacy/supplier_return_property26_amount_bounds_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/services/rid_generator.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/features/credit_notes/data/models/credit_note_model.dart';
import 'package:dukanx/features/credit_notes/data/repositories/credit_note_repository.dart';
import 'package:dukanx/features/pharmacy/services/supplier_expiry_return_service.dart';
import 'package:dukanx/features/pharmacy/utils/tenant_scope.dart';
import 'package:flutter_test/flutter_test.dart';

const int kNumRuns = 200;

/// The inclusive upper bound under test (R19.4): 999,999,999,999 paise.
const int kMax = kMaxCreditNoteAmountPaise;

/// A fixed "now" so expiry comparisons are deterministic. The service compares
/// by calendar date (time-of-day ignored), so a batch expiring today (offset 0)
/// is eligible.
final DateTime kNow = DateTime(2024, 6, 15, 10, 30);

// ---------------------------------------------------------------------------
// Fakes — keep the test pure (no database, no service locator)
// ---------------------------------------------------------------------------

/// Always resolves a fixed, non-blank tenant so TenantScope.require() succeeds.
class _FakeSessionManager extends Fake implements SessionManager {
  @override
  String? get currentBusinessId => 'tenant-26';
}

/// Captures the CreditNote handed to persistence so the test can assert the
/// stored paise value, and reports success without touching a database.
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
// Independent oracle (pure integer logic; never calls the production bounds
// comparison)
// ---------------------------------------------------------------------------

bool _amountOk(int paise) => paise >= 0 && paise <= kMax;

/// Calendar-date eligibility: a batch expiring on/before today is eligible.
/// With whole-day offsets this is exactly `offsetDays <= 0`.
bool _expiredOk(int offsetDays) => offsetDays <= 0;

bool _qtyOk(int qty, int available) => qty >= 1 && qty <= available;

DateTime _expiryFromOffset(int offsetDays) =>
    DateTime(kNow.year, kNow.month, kNow.day + offsetDays);

/// Recovers the authoritative integer-paise amount the service encoded into the
/// existing credit-note attributes (storage-decisions.md / R4 — no new column).
int? _decodeStoredAmountPaise(CreditNote note) {
  final decoded = SupplierBatchLink.decodeReason(note.reason);
  final value = decoded?['amountPaise'];
  return value is int ? value : null;
}

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

/// Amount spanning well below 0 through well above the upper bound, with extra
/// weight near both boundaries so the [0, kMax] edges are probed.
final Generator<int> _amountGen = Gen.oneOf<int>(<Generator<int>>[
  Gen.interval(-1000000000, kMax + 1000000000), // full span incl. out-of-range
  Gen.interval(-5, 5), // around the lower bound (0)
  Gen.interval(kMax - 5, kMax + 5), // around the upper bound
]);

/// Whole-day expiry offset from [kNow]: negatives/zero are expired (eligible),
/// positives are future (not expired).
final Generator<int> _offsetGen = Gen.interval(-3650, 3650);

/// Available batch quantity (0 makes every quantity invalid; positive values
/// allow a valid window).
final Generator<int> _availableGen = Gen.interval(0, 100000);

/// Requested quantity spanning invalid (<1) and the valid/over-available range.
final Generator<int> _quantityGen = Gen.interval(-5, 100005);

/// A guaranteed-positive available quantity for the focused property.
final Generator<int> _availablePositiveGen = Gen.interval(1, 5000);

/// A seed used to derive an always-valid quantity in [1, available].
final Generator<int> _quantitySeedGen = Gen.interval(0, 1000000);

/// Non-blank supplier/batch identifier seed.
final Generator<int> _idGen = Gen.interval(1, 9999);

/// (A) amount, positive-available, quantity-seed.
final Generator<List<dynamic>> _focusedCaseGen = Gen.tuple(<Generator<dynamic>>[
  _amountGen,
  _availablePositiveGen,
  _quantitySeedGen,
]);

/// (B) amount, expiry-offset, available, quantity, supplierId-seed, batchId-seed.
final Generator<List<dynamic>> _universalCaseGen = Gen.tuple(
  <Generator<dynamic>>[
    _amountGen,
    _offsetGen,
    _availableGen,
    _quantityGen,
    _idGen,
    _idGen,
  ],
);

void main() {
  group('Feature: pharmacy-vertical-remediation, Property 26: Credit note amount '
      'is a bounded non-negative integer paise — Req 19.4', () {
    // --------------------------------------------------------------------
    // (A) FOCUSED: expiry + quantity held valid so the AMOUNT alone decides
    //     creation. A created note's stored amount is exactly the in-bounds
    //     integer paise input; an out-of-bounds amount is rejected with
    //     `invalidAmount` and nothing is persisted.
    // --------------------------------------------------------------------
    test(
      'Property 26a: with valid expiry+quantity, a return is created iff the '
      'amount is in [0, 999999999999], and a created note stores exactly '
      'that non-negative integer paise',
      () async {
        final held = await forAllAsync(
          (List<dynamic> c) async {
            final amount = c[0] as int;
            final available = c[1] as int; // >= 1
            final quantity = 1 + ((c[2] as int) % available); // [1, available]

            final repo = _CapturingCreditNoteRepository();
            final service = _buildService(repo);

            final result = await service.createExpiryReturn(
              supplierId: 'sup-1',
              batchId: 'batch-1',
              batchExpiryDate: _expiryFromOffset(-1), // expired (eligible)
              quantity: quantity,
              availableQuantity: available,
              amountPaise: amount,
              now: kNow,
            );

            final expectCreated = _amountOk(amount);
            if (result.created != expectCreated) return false;

            if (result.created) {
              final note = result.creditNote!;
              // In-memory model stores the exact integer paise input, in range.
              if (note.amountPaise != amount) return false;
              if (note.amountPaise < 0 || note.amountPaise > kMax) {
                return false;
              }
              // Persisted credit note carries the same authoritative paise.
              if (_decodeStoredAmountPaise(repo.lastCreated!) != amount) {
                return false;
              }
            } else {
              // Out-of-bounds amount: rejected for amount, nothing persisted.
              if (result.reason !=
                  SupplierReturnRejectionReason.invalidAmount) {
                return false;
              }
              if (repo.lastCreated != null) return false;
            }
            return true;
          },
          [_focusedCaseGen],
          numRuns: kNumRuns,
        );

        expect(
          held,
          isTrue,
          reason:
              'A supplier-return credit note is created iff the amount is a '
              'non-negative integer paise in [0, $kMax]; the created note '
              'stores exactly that value and nothing is persisted on '
              'rejection.',
        );
      },
    );

    // --------------------------------------------------------------------
    // (B) UNIVERSAL: every input randomised. Safety direction of Property 26
    //     — whenever a credit note IS created, its stored amount is a
    //     non-negative integer paise within [0, kMax]; rejection persists
    //     nothing.
    // --------------------------------------------------------------------
    test(
      'Property 26b: across arbitrary expiry/quantity/amount, every created '
      'credit note stores a non-negative integer paise within bounds',
      () async {
        final held = await forAllAsync(
          (List<dynamic> c) async {
            final amount = c[0] as int;
            final offset = c[1] as int;
            final available = c[2] as int;
            final quantity = c[3] as int;
            final supplierId = 'sup-${c[4]}';
            final batchId = 'batch-${c[5]}';

            final repo = _CapturingCreditNoteRepository();
            final service = _buildService(repo);

            final result = await service.createExpiryReturn(
              supplierId: supplierId,
              batchId: batchId,
              batchExpiryDate: _expiryFromOffset(offset),
              quantity: quantity,
              availableQuantity: available,
              amountPaise: amount,
              now: kNow,
            );

            final shouldCreate =
                _amountOk(amount) &&
                _expiredOk(offset) &&
                _qtyOk(quantity, available);

            if (result.created != shouldCreate) return false;

            if (result.created) {
              final note = result.creditNote!;
              final stored = _decodeStoredAmountPaise(repo.lastCreated!);
              final bounded =
                  note.amountPaise >= 0 &&
                  note.amountPaise <= kMax &&
                  note.amountPaise == amount &&
                  stored == amount;
              if (!bounded) return false;
            } else {
              if (repo.lastCreated != null) return false;
            }
            return true;
          },
          [_universalCaseGen],
          numRuns: kNumRuns,
        );

        expect(
          held,
          isTrue,
          reason:
              'Whenever a supplier-return credit note is created, its stored '
              'amount is a non-negative integer paise within [0, $kMax].',
        );
      },
    );

    // --------------------------------------------------------------------
    // Deterministic anchors — pin the inclusive boundary of R19.4.
    // --------------------------------------------------------------------
    test('Property 26 anchors: 0 and 999999999999 are accepted; -1 and '
        '1000000000000 are rejected as invalidAmount', () async {
      Future<SupplierExpiryReturnResult> attempt(int amount) {
        final repo = _CapturingCreditNoteRepository();
        return _buildService(repo).createExpiryReturn(
          supplierId: 's1',
          batchId: 'b1',
          batchExpiryDate: _expiryFromOffset(-1), // expired
          quantity: 5,
          availableQuantity: 10,
          amountPaise: amount,
          now: kNow,
        );
      }

      // Lower bound: 0 paise is accepted and stored as 0.
      final atZero = await attempt(0);
      expect(atZero.created, isTrue);
      expect(atZero.creditNote!.amountPaise, 0);

      // Upper bound: exactly kMax is accepted and stored as kMax.
      final atMax = await attempt(kMax);
      expect(atMax.created, isTrue);
      expect(atMax.creditNote!.amountPaise, kMax);

      // Just below 0 → rejected for amount, no note.
      final belowZero = await attempt(-1);
      expect(belowZero.created, isFalse);
      expect(belowZero.reason, SupplierReturnRejectionReason.invalidAmount);

      // Just above the upper bound → rejected for amount, no note.
      final aboveMax = await attempt(kMax + 1);
      expect(aboveMax.created, isFalse);
      expect(aboveMax.reason, SupplierReturnRejectionReason.invalidAmount);
    });
  });
}
