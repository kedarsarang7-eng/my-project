// ============================================================================
// Feature: pharmacy-vertical-remediation — Task 16.4 EXAMPLE test
// Credit note linkage for the supplier expiry-return flow.
//
// **Validates: Requirements 19.6**
//
// R19.6 requires an automated test verifying that a created supplier
// expiry-return credit note EXISTS and is LINKED to the originating supplier id
// and batch id. This example test performs one valid expiry-return creation and
// asserts:
//   1. the service reports success and returns a credit note carrying the
//      originating supplierId, batchId, and the active tenantId (R19.1, R19.5);
//   2. the credit note EXISTS — it can be read back from the credit_notes
//      repository by its RID id after creation;
//   3. the persisted record is LINKED to the originating supplier (counterparty
//      = supplierId) and to the originating batch (recoverable via the
//      `SupplierBatchLink` reason encoding), under the active tenant scope.
//
// SEAM: the service's three injectable dependencies are wired to test-only
// stand-ins — a `TenantScope` over a `FakeSessionManager` (the repo-wide
// pattern), a real `RidGenerator`, and an in-memory-backed
// `CreditNoteRepository` fake that genuinely stores each created credit note so
// it can be read back. This mirrors the sibling supplier-return property tests
// (`supplier_return_property26_amount_bounds_test.dart`) which fake the
// repository to keep the test pure (no DB/DI/sync-queue coupling), while still
// proving real persistence-and-retrieval of the linked record. No production
// code is modified.
//
// Run: flutter test test/features/pharmacy/supplier_return_linkage_test.dart
// ============================================================================

import 'package:dukanx/core/services/rid_generator.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/features/credit_notes/data/models/credit_note_model.dart';
import 'package:dukanx/features/credit_notes/data/repositories/credit_note_repository.dart';
import 'package:dukanx/features/pharmacy/services/supplier_expiry_return_service.dart';
import 'package:dukanx/features/pharmacy/utils/tenant_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

/// A lightweight fake [SessionManager] whose `currentBusinessId` (the active
/// tenantId) is fixed via the constructor. `Mock` supplies no-op
/// `noSuchMethod` for every other member; `TenantScope` only reads
/// `currentBusinessId`, which we override.
class FakeSessionManager extends Mock implements SessionManager {
  FakeSessionManager(this._businessId);

  final String? _businessId;

  @override
  String? get currentBusinessId => _businessId;
}

/// An in-memory-backed [CreditNoteRepository] that genuinely stores each
/// created credit note keyed by id, so the test can read it back exactly as the
/// production repository would (`getCreditNoteById`, `getCreditNotesForCustomer`,
/// `getAllCreditNotes`). Unlike a closed/no-op fake, this lets the test assert
/// the created note EXISTS and is retrievable through the supplier and tenant
/// query paths, without coupling to the Drift database or the SyncManager
/// singleton.
class _InMemoryCreditNoteRepository extends Fake
    implements CreditNoteRepository {
  final Map<String, CreditNote> _store = <String, CreditNote>{};

  @override
  Future<CreditNoteResult<CreditNote>> createCreditNote(
    CreditNote creditNote,
  ) async {
    _store[creditNote.id] = creditNote;
    return CreditNoteResult.success(creditNote);
  }

  @override
  Future<CreditNote?> getCreditNoteById(String id) async => _store[id];

  @override
  Future<List<CreditNote>> getCreditNotesForCustomer(
    String userId,
    String customerId,
  ) async {
    return _store.values
        .where((c) => c.userId == userId && c.customerId == customerId)
        .toList();
  }

  @override
  Future<List<CreditNote>> getAllCreditNotes({
    required String userId,
    DateTime? fromDate,
    DateTime? toDate,
    CreditNoteStatus? status,
  }) async {
    return _store.values.where((c) => c.userId == userId).toList();
  }
}

void main() {
  const tenantId = 'tenant-alpha';
  const supplierId = 'supplier-77';
  const batchId = 'batch-xyz-001';

  late _InMemoryCreditNoteRepository repository;
  late SupplierExpiryReturnService service;

  setUp(() {
    repository = _InMemoryCreditNoteRepository();
    service = SupplierExpiryReturnService(
      tenantScope: TenantScope(session: FakeSessionManager(tenantId)),
      ridGenerator: RidGenerator(),
      repository: repository,
    );
  });

  group('Feature: pharmacy-vertical-remediation, Task 16.4: credit note linkage '
      '(R19.6)', () {
    test(
      'a valid expiry-return creates a credit note linked to the originating '
      'supplier and batch under the active tenant',
      () async {
        // A batch that expired yesterday (eligible — R19.1), a valid quantity
        // within the available stock (R19.3), and a valid non-negative paise
        // amount within bounds (R19.4).
        final expiredYesterday = DateTime.now().subtract(
          const Duration(days: 1),
        );

        final result = await service.createExpiryReturn(
          supplierId: supplierId,
          batchId: batchId,
          batchExpiryDate: expiredYesterday,
          quantity: 5,
          availableQuantity: 20,
          amountPaise: 123450, // ₹1,234.50
        );

        // (1) The flow succeeded and returned a credit note carrying the
        // originating supplier, batch, and active tenant (R19.1, R19.5).
        expect(result.created, isTrue);
        expect(result.error, isNull);
        final note = result.creditNote;
        expect(note, isNotNull);
        expect(note!.supplierId, supplierId);
        expect(note.batchId, batchId);
        expect(note.tenantId, tenantId);
        expect(note.amountPaise, 123450);
        expect(note.quantity, 5);
        // RID id is tenant-scoped: it begins with the active tenantId segment.
        expect(note.id, startsWith('$tenantId-'));

        // (2) The credit note EXISTS — it was persisted and can be read back
        // by its RID id from the credit_notes repository.
        final persisted = await repository.getCreditNoteById(note.id);
        expect(
          persisted,
          isNotNull,
          reason: 'the created credit note must exist in the repository',
        );

        // (3) It is LINKED to the originating supplier and tenant, and the
        // originating batch id is recoverable from the stored linkage.
        expect(
          persisted!.userId,
          tenantId,
          reason: 'persisted record must be scoped to the active tenant',
        );
        expect(
          persisted.customerId,
          supplierId,
          reason: 'counterparty linkage must be the originating supplier',
        );

        final link = SupplierBatchLink.decodeReason(persisted.reason);
        expect(
          link,
          isNotNull,
          reason: 'stored reason must carry the supplier/batch linkage',
        );
        expect(link!['supplierId'], supplierId);
        expect(link['batchId'], batchId);
        expect(link['quantity'], 5);
        expect(link['amountPaise'], 123450);
      },
    );

    test(
      'the linked credit note is discoverable through the supplier and tenant '
      'query paths',
      () async {
        final result = await service.createExpiryReturn(
          supplierId: supplierId,
          batchId: batchId,
          batchExpiryDate: DateTime.now().subtract(const Duration(days: 3)),
          quantity: 2,
          availableQuantity: 2,
          amountPaise: 5000,
        );
        expect(result.created, isTrue);
        final noteId = result.creditNote!.id;

        // Discoverable by the supplier (counterparty) under the tenant scope.
        final forSupplier = await repository.getCreditNotesForCustomer(
          tenantId,
          supplierId,
        );
        expect(forSupplier.map((c) => c.id), contains(noteId));

        // Discoverable in the tenant's full credit-note list (tenant scope).
        final forTenant = await repository.getAllCreditNotes(userId: tenantId);
        expect(forTenant.map((c) => c.id), contains(noteId));
      },
    );
  });
}
