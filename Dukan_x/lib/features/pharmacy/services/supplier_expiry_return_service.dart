// ============================================================================
// SUPPLIER EXPIRY-RETURN SERVICE (Requirement 19)
// ============================================================================
// Initiates a supplier return for an expired product batch and records the
// resulting credit note. The flow validates the return conditions, then
// persists a credit note linked to the originating supplier id + batch id.
//
//   R19.1  A batch expired on/before today creates a credit note linked to the
//          supplier id + batch id.
//   R19.2  A future-dated (not-yet-expired) batch is rejected with "not expired"
//          and NO credit note is created.
//   R19.3  Quantity < 1 or > available is rejected with an invalid-quantity
//          error and NO credit note is created.
//   R19.4  The amount is stored as a non-negative integer paise value within
//          the inclusive range [0, 999,999,999,999].
//   R19.5  Records are scoped by the active tenantId and identified with RIDs.
//
// CROSS-CUTTING HELPERS (Requirements 1–3):
//   - `TenantScope`  resolves the active tenantId and is the single
//     authorization-error chokepoint (R1 / R19.5).
//   - `RidGenerator` produces the `{tenantId}-{ms}-{uuidShort}` id (R3 / R19.5).
//
// STORAGE DECISION (Requirement 4 — no schema changes):
//   The existing `credit_notes` feature persists to the `ReturnInwards` Drift
//   table, which has NO `supplierId` or `batchId` column. Rather than add
//   columns (which would require written approval), the supplier id + batch id
//   linkage is encoded into EXISTING attributes (`customerId`, `reason`, and
//   `itemsJson`) via [SupplierBatchLink]. The authoritative integer-paise amount
//   is preserved inside that encoded link so no precision is lost to the
//   legacy double `amount` column. The requirement for first-class
//   `supplierId` / `batchId` attributes is recorded as a pending-approval item
//   in `storage-decisions.md`.
//
// Pharmacy-scoped service: only pharmacy code paths use it; the other 18
// verticals are untouched (Requirement 5.3).
// ============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/rid_generator.dart';
import '../../credit_notes/data/models/credit_note_model.dart';
import '../../credit_notes/data/repositories/credit_note_repository.dart';
import '../utils/tenant_scope.dart';

/// Inclusive upper bound for a credit-note amount in integer paise (R19.4).
const int kMaxCreditNoteAmountPaise = 999999999999;

/// Reason a supplier expiry-return was rejected without creating a credit note.
enum SupplierReturnRejectionReason {
  /// The batch expiry date is in the future — the batch is not expired (R19.2).
  notExpired,

  /// The requested quantity is < 1 or greater than the available quantity
  /// (R19.3).
  invalidQuantity,

  /// The amount is negative or exceeds [kMaxCreditNoteAmountPaise] (R19.4).
  invalidAmount,

  /// Validation passed but the credit note could not be persisted.
  persistenceFailed,
}

/// In-memory supplier expiry-return credit note (design Data Models §Supplier
/// Credit Note). All monetary values are integer paise; the identifier is a RID.
@immutable
class SupplierExpiryCreditNote {
  /// RID identifier `{tenantId}-{ms}-{uuidShort}` (R3, R19.5).
  final String id;

  /// Active tenant scope this record belongs to (R1, R19.5).
  final String tenantId;

  /// Supplier the expired stock is returned to (R19.1).
  final String supplierId;

  /// Batch being returned (R19.1).
  final String batchId;

  /// Credit amount as a non-negative integer paise value in
  /// [0, 999,999,999,999] (R19.4).
  final int amountPaise;

  /// Returned quantity, in [1, availableQty] (R19.3).
  final int quantity;

  /// Creation timestamp.
  final DateTime createdAt;

  const SupplierExpiryCreditNote({
    required this.id,
    required this.tenantId,
    required this.supplierId,
    required this.batchId,
    required this.amountPaise,
    required this.quantity,
    required this.createdAt,
  });
}

/// Outcome of a supplier expiry-return attempt: either a created credit note
/// or a rejection reason with a human-readable message.
@immutable
class SupplierExpiryReturnResult {
  /// True when a credit note was created and persisted.
  final bool created;

  /// The created credit note when [created]; otherwise `null`.
  final SupplierExpiryCreditNote? creditNote;

  /// The rejection reason when not [created]; otherwise `null`.
  final SupplierReturnRejectionReason? reason;

  /// A human-readable message describing a rejection; otherwise `null`.
  final String? error;

  const SupplierExpiryReturnResult.success(SupplierExpiryCreditNote note)
    : created = true,
      creditNote = note,
      reason = null,
      error = null;

  const SupplierExpiryReturnResult.rejected({
    required this.reason,
    required this.error,
  }) : created = false,
       creditNote = null;
}

/// Encodes/decodes the supplier id + batch id linkage (plus the authoritative
/// integer-paise amount and quantity) into the existing credit-note attributes,
/// since the `ReturnInwards` store has no dedicated `supplierId`/`batchId`
/// columns (see storage decision above).
class SupplierBatchLink {
  /// Marker prefix written to the credit note `reason` so an expiry-return is
  /// recognisable and its linkage recoverable.
  static const String marker = 'PHARMACY_EXPIRY_RETURN';

  const SupplierBatchLink._();

  /// Builds the `reason` string carrying the supplier/batch linkage and the
  /// authoritative integer-paise amount.
  static String encodeReason({
    required String supplierId,
    required String batchId,
    required int quantity,
    required int amountPaise,
  }) {
    final payload = jsonEncode({
      'supplierId': supplierId,
      'batchId': batchId,
      'quantity': quantity,
      'amountPaise': amountPaise,
    });
    return '$marker $payload';
  }

  /// Parses a previously [encodeReason]d string, or returns `null` when the
  /// string is not an expiry-return marker.
  static Map<String, dynamic>? decodeReason(String? reason) {
    if (reason == null || !reason.startsWith(marker)) return null;
    final json = reason.substring(marker.length).trim();
    try {
      final decoded = jsonDecode(json);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}

/// Validates supplier expiry-return conditions and records the credit note via
/// the existing `credit_notes` repository.
class SupplierExpiryReturnService {
  final TenantScope _tenantScope;
  final RidGenerator _ridGenerator;
  final CreditNoteRepository _repository;

  /// Creates the service.
  ///
  /// Dependencies default to the app's DI-registered singletons and are
  /// injectable purely to keep the service unit-testable.
  SupplierExpiryReturnService({
    TenantScope? tenantScope,
    RidGenerator? ridGenerator,
    CreditNoteRepository? repository,
    AppDatabase? db,
  }) : _tenantScope = tenantScope ?? TenantScope(),
       _ridGenerator = ridGenerator ?? RidGenerator(),
       _repository =
           repository ?? CreditNoteRepository(db ?? sl<AppDatabase>());

  /// Initiates a supplier expiry-return for [batchId] supplied by [supplierId].
  ///
  /// The credit note is created only when ALL of the following hold:
  ///   - the active tenant can be resolved (else [TenantScopeError]) — R19.5;
  ///   - [batchExpiryDate] is on/before [now] (date-only) — R19.1 / R19.2;
  ///   - [quantity] is in `[1, availableQuantity]` — R19.3;
  ///   - [amountPaise] is in `[0, kMaxCreditNoteAmountPaise]` — R19.4.
  ///
  /// On any rejection no credit note is created and the targeted records are
  /// left unchanged.
  ///
  /// [now] defaults to the current time and is injectable for testability.
  Future<SupplierExpiryReturnResult> createExpiryReturn({
    required String supplierId,
    required String batchId,
    required DateTime batchExpiryDate,
    required int quantity,
    required int availableQuantity,
    required int amountPaise,
    DateTime? now,
  }) async {
    // R19.5 / R1.3: resolve the active tenant first. A missing tenant throws a
    // TenantScopeError and no record is read or written.
    final tenantId = _tenantScope.require();
    final createdAt = now ?? DateTime.now();

    // R19.1 / R19.2: only batches expired on/before today are eligible.
    if (!_isExpiredOnOrBefore(batchExpiryDate, createdAt)) {
      return const SupplierExpiryReturnResult.rejected(
        reason: SupplierReturnRejectionReason.notExpired,
        error: 'Batch is not expired: its expiry date is in the future.',
      );
    }

    // R19.3: quantity must be at least 1 and at most the available quantity.
    if (quantity < 1 || quantity > availableQuantity) {
      return SupplierExpiryReturnResult.rejected(
        reason: SupplierReturnRejectionReason.invalidQuantity,
        error:
            'Invalid quantity $quantity: must be between 1 and '
            '$availableQuantity (available).',
      );
    }

    // R19.4: amount must be a non-negative integer paise within bounds.
    if (amountPaise < 0 || amountPaise > kMaxCreditNoteAmountPaise) {
      return SupplierExpiryReturnResult.rejected(
        reason: SupplierReturnRejectionReason.invalidAmount,
        error:
            'Invalid amount $amountPaise paise: must be between 0 and '
            '$kMaxCreditNoteAmountPaise.',
      );
    }

    // All conditions satisfied — build the tenant-scoped, RID-identified record.
    final note = SupplierExpiryCreditNote(
      id: _ridGenerator.generate(tenantId),
      tenantId: tenantId,
      supplierId: supplierId,
      batchId: batchId,
      amountPaise: amountPaise,
      quantity: quantity,
      createdAt: createdAt,
    );

    // Persist via the existing credit_notes repository (no new schema).
    final persisted = await _repository.createCreditNote(_toCreditNote(note));
    if (!persisted.isSuccess) {
      return SupplierExpiryReturnResult.rejected(
        reason: SupplierReturnRejectionReason.persistenceFailed,
        error: persisted.error ?? 'Failed to persist the supplier credit note.',
      );
    }

    return SupplierExpiryReturnResult.success(note);
  }

  /// True when [expiry] falls on or before [reference], compared by calendar
  /// date (time-of-day ignored) so a batch expiring today is eligible (R19.1).
  bool _isExpiredOnOrBefore(DateTime expiry, DateTime reference) {
    final expiryDate = DateTime(expiry.year, expiry.month, expiry.day);
    final referenceDate = DateTime(
      reference.year,
      reference.month,
      reference.day,
    );
    return !expiryDate.isAfter(referenceDate);
  }

  /// Maps the in-memory supplier credit note onto the existing [CreditNote]
  /// model, encoding the supplier/batch linkage and authoritative paise amount
  /// into existing attributes (no schema change — see storage decision).
  CreditNote _toCreditNote(SupplierExpiryCreditNote note) {
    final amountRupees = note.amountPaise / 100.0;
    final reason = SupplierBatchLink.encodeReason(
      supplierId: note.supplierId,
      batchId: note.batchId,
      quantity: note.quantity,
      amountPaise: note.amountPaise,
    );

    final item = CreditNoteItem(
      id: '${note.id}-item',
      productId: note.batchId, // links the line to the returned batch
      productName: 'Expired batch ${note.batchId}',
      originalQuantity: note.quantity.toDouble(),
      returnedQuantity: note.quantity.toDouble(),
      unitPrice: note.quantity > 0
          ? amountRupees / note.quantity
          : amountRupees,
      gstRate: 0,
      taxableValue: amountRupees,
      totalAmount: amountRupees,
    );

    return CreditNote(
      id: note.id,
      userId: note.tenantId, // tenant scope = repository userId (R19.5)
      creditNoteNumber: note.id,
      originalBillId: '', // supplier return — not tied to a sales bill
      originalBillNumber: '',
      originalBillDate: note.createdAt,
      customerId: note.supplierId, // counterparty linkage (supplier)
      customerName: 'Supplier ${note.supplierId}',
      type: CreditNoteType.fullReturn,
      status: CreditNoteStatus.confirmed,
      items: [item],
      reason: reason,
      subtotal: amountRupees,
      totalTaxableValue: amountRupees,
      totalCgst: 0,
      totalSgst: 0,
      totalIgst: 0,
      totalGst: 0,
      grandTotal: amountRupees,
      balanceAmount: amountRupees,
      date: note.createdAt,
      createdAt: note.createdAt,
      createdBy: note.tenantId,
    );
  }
}
