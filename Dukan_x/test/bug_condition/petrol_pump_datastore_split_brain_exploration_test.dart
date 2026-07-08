/// Bug Condition Exploration Test — datastore.splitBrain
///
/// **Validates: Requirements 1.2**
///
/// Property 2: Bug Condition — Unified Datastore
///
/// This test confirms that `TankService` currently writes to the Firestore-compat
/// (API-backed) store instead of the same Drift tables that
/// `ShiftService`/`PetrolPumpBillingService` read via `_db.select(_db.tanks)`.
///
/// Specifically:
///   - `TankService` uses `_firestore`, `_tankCollection`, `.collection()`,
///     `.doc().set/update()` patterns — i.e., it writes to the Firestore-compat
///     shim (→ API Gateway → DynamoDB), NOT to the local Drift SQLite DB.
///   - `PetrolPumpBillingService` reads from `_db.select(_db.tanks)` (Drift).
///   - A tank written through `TankService.saveTank` is therefore INVISIBLE to
///     `PetrolPumpBillingService`'s reads — the two services operate on
///     disconnected datastores (split-brain).
///
/// On UNFIXED code this test FAILS — proving the split-brain bug exists.
/// After the fix (migrating TankService onto Drift) this same test PASSES.
///
/// Run: flutter test test/bug_condition/petrol_pump_datastore_split_brain_exploration_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads a source file relative to the package root.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  // ===========================================================================
  // datastore.splitBrain / 1.2 / 2.2 — TankService writes to Firestore-compat
  // while PetrolPumpBillingService reads from Drift. Cross-service writes are
  // invisible to the other service's reads.
  // ===========================================================================
  group('Bug Condition 1.2 — datastore.splitBrain', () {
    late String tankServiceSrc;
    late String billingServiceSrc;

    setUpAll(() {
      tankServiceSrc = _readSource(
        'lib/features/petrol_pump/services/tank_service.dart',
      );
      assert(tankServiceSrc.isNotEmpty, 'tank_service.dart must exist');

      billingServiceSrc = _readSource(
        'lib/features/petrol_pump/services/petrol_pump_billing_service.dart',
      );
      assert(
        billingServiceSrc.isNotEmpty,
        'petrol_pump_billing_service.dart must exist',
      );
    });

    test('TankService.saveTank writes to Drift (not Firestore-compat)', () {
      // On FIXED code: TankService should use Drift patterns (_db.select,
      // _db.into, _db.update, _db.transaction) to write tanks directly to
      // the local SQLite database — the same tables PetrolPumpBillingService
      // reads.
      //
      // On UNFIXED code: TankService uses _firestore, _tankCollection,
      // .doc().set() — the Firestore-compat shim that routes through
      // ApiClient to DynamoDB, completely disconnected from Drift.

      // Check that TankService uses Drift patterns for persistence
      final usesDriftDb = RegExp(
        r'_db\.(select|into|update|transaction|customStatement)',
      ).hasMatch(tankServiceSrc);

      expect(
        usesDriftDb,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.2): TankService does NOT use Drift '
            '(_db.select/_db.into/_db.update/_db.transaction). '
            'Instead, it uses FirebaseFirestore/Firestore-compat patterns. '
            'A tank saved via TankService.saveTank is written to the API-backed '
            'DynamoDB store but is INVISIBLE to PetrolPumpBillingService which '
            'reads from _db.select(_db.tanks) (Drift/SQLite). This is the '
            'split-brain: two disconnected records of the same physical tanks.',
      );
    });

    test('TankService does NOT use Firestore-compat patterns for tank persistence', () {
      // On FIXED code: TankService should NOT import or use firestore_compat.
      // On UNFIXED code: TankService imports and heavily uses it.

      final usesFirestoreCompat =
          tankServiceSrc.contains('firestore_compat.dart') ||
          tankServiceSrc.contains('FirebaseFirestore') ||
          tankServiceSrc.contains('_firestore') ||
          tankServiceSrc.contains('_tankCollection');

      expect(
        usesFirestoreCompat,
        isFalse,
        reason:
            'COUNTEREXAMPLE (1.2): TankService imports and uses '
            'firestore_compat.dart (FirebaseFirestore/_firestore/_tankCollection). '
            'This Firestore-compat shim routes through ApiClient to DynamoDB — '
            'a completely separate datastore from the Drift/SQLite database that '
            'PetrolPumpBillingService and ShiftService read. Any tank written '
            'through TankService is invisible to billing/shift reconciliation.',
      );
    });

    test(
      'PetrolPumpBillingService reads tanks from the same store TankService writes to',
      () {
        // PetrolPumpBillingService reads via _db.select(_db.tanks) — Drift.
        // TankService SHOULD also write to Drift. If TankService writes to
        // Firestore-compat instead, the data is disconnected.

        // Confirm PetrolPumpBillingService reads tanks from Drift
        final billingReadsDriftTanks = RegExp(
          r'_db\.select\(_db\.tanks\)',
        ).hasMatch(billingServiceSrc);

        expect(
          billingReadsDriftTanks,
          isTrue,
          reason:
              'Precondition: PetrolPumpBillingService must read tanks '
              'from Drift (_db.select(_db.tanks)). This confirms the billing '
              'service uses the Drift store.',
        );

        // Now verify TankService writes to the SAME Drift store (not Firestore)
        // On unfixed code: TankService uses .doc().set() (Firestore-compat)
        // On fixed code: TankService uses _db.into/_db.update (Drift)
        final tankServiceWritesDrift = RegExp(
          r'_db\.(into|update)\(_db\.tanks\)',
        ).hasMatch(tankServiceSrc);

        final tankServiceWritesFirestore =
            RegExp(r'\.(doc|set|update)\(').hasMatch(tankServiceSrc) &&
            tankServiceSrc.contains('_tankCollection');

        // The tank written through TankService must be visible to
        // PetrolPumpBillingService's reads. This is only possible if both
        // use the same Drift store.
        expect(
          tankServiceWritesDrift && !tankServiceWritesFirestore,
          isTrue,
          reason:
              'COUNTEREXAMPLE (1.2): TankService writes to Firestore-compat '
              '(_tankCollection.doc(tankId).set()) while PetrolPumpBillingService '
              'reads from Drift (_db.select(_db.tanks)). A tank saved via '
              'TankService.saveTank is written to API/DynamoDB but has NO row '
              'in the Drift tanks table — cross-service writes are invisible. '
              'ShiftService and PetrolPumpBillingService will never see tanks '
              'created/updated through TankService.',
        );
      },
    );

    test('TankService enqueues changes to SyncQueue for offline-first sync', () {
      // On FIXED code: TankService should follow the same offline-first
      // pattern as ShiftService — write to Drift locally AND enqueue a sync
      // entry to the SyncQueue table for eventual cloud sync.
      //
      // On UNFIXED code: TankService does NOT reference SyncQueue or
      // _enqueueSync at all — it routes directly through the Firestore-compat
      // online-only shim.

      final usesSyncQueue =
          tankServiceSrc.contains('syncQueue') ||
          tankServiceSrc.contains('SyncQueue') ||
          tankServiceSrc.contains('_enqueueSync') ||
          tankServiceSrc.contains('enqueueSync');

      expect(
        usesSyncQueue,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.2): TankService does NOT use SyncQueue or '
            '_enqueueSync. It routes all writes through the Firestore-compat '
            'shim (online-only API calls to DynamoDB). Unlike ShiftService '
            'and PetrolPumpBillingService which write locally to Drift and '
            'enqueue sync entries for offline-first operation, TankService '
            'requires an active network connection and writes to a completely '
            'disconnected datastore.',
      );
    });
  });
}
