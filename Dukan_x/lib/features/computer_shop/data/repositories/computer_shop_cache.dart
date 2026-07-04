// ============================================================================
// COMPUTER SHOP — Offline Read Cache (Drift)
// ============================================================================
// Tenant-scoped local cache backing the computerShop module's online reads
// (job cards, warranty, serials). Written through on every successful online
// read in `ComputerRepository`; read from when the online call fails/times
// out so screens can keep working offline (Req 26.1, 26.2).
//
// Every row is scoped by `tenantId` (= SessionManager.userId) — every query
// here MUST filter by the active tenant to preserve multi-tenant isolation.
// Payloads are stored as the raw JSON the backend returned, so cached rows
// replay through the exact same `fromJson` parsing path as online reads.
// ============================================================================

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';

/// Drift-backed cache for the computerShop module's read-heavy entities.
///
/// This class owns no business logic beyond "store/retrieve the last known
/// JSON payload for a tenant" — parsing back into domain models is left to
/// the caller (`ComputerRepository`) so the cache stays a dumb mirror of the
/// backend response shape.
class ComputerShopCache {
  final AppDatabase _db;

  ComputerShopCache(this._db);

  // ==========================================================================
  // JOB CARDS
  // ==========================================================================

  /// Upserts a single job card's raw JSON payload into the cache.
  Future<void> upsertJobCard({
    required String tenantId,
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    await _db
        .into(_db.computerJobCardsCache)
        .insert(
          ComputerJobCardsCacheCompanion.insert(
            id: id,
            tenantId: tenantId,
            payloadJson: jsonEncode(payload),
            updatedAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Upserts a batch of job cards (e.g. from a list read) in one pass.
  Future<void> upsertJobCards({
    required String tenantId,
    required List<Map<String, dynamic>> payloads,
  }) async {
    for (final payload in payloads) {
      final id = payload['id']?.toString();
      if (id == null || id.isEmpty) continue;
      await upsertJobCard(tenantId: tenantId, id: id, payload: payload);
    }
  }

  /// Returns all cached job card JSON payloads for [tenantId].
  Future<List<Map<String, dynamic>>> getCachedJobCards({
    required String tenantId,
  }) async {
    final rows = await (_db.select(
      _db.computerJobCardsCache,
    )..where((t) => t.tenantId.equals(tenantId))).get();
    return rows
        .map((r) => jsonDecode(r.payloadJson) as Map<String, dynamic>)
        .toList();
  }

  /// Returns the cached JSON payload for a single job card, or null when
  /// this tenant has no cached row for that id.
  Future<Map<String, dynamic>?> getCachedJobCard({
    required String tenantId,
    required String id,
  }) async {
    final row =
        await (_db.select(_db.computerJobCardsCache)
              ..where((t) => t.tenantId.equals(tenantId) & t.id.equals(id)))
            .getSingleOrNull();
    if (row == null) return null;
    return jsonDecode(row.payloadJson) as Map<String, dynamic>;
  }

  // ==========================================================================
  // WARRANTY
  // ==========================================================================

  /// Upserts a warranty record's raw JSON payload into the cache, keyed by
  /// the warranty's own id and indexed by serial number for lookup.
  Future<void> upsertWarranty({
    required String tenantId,
    required String id,
    required String serialNumber,
    required Map<String, dynamic> payload,
    DateTime? warrantyExpiryDate,
  }) async {
    await _db
        .into(_db.computerWarrantyCache)
        .insert(
          ComputerWarrantyCacheCompanion.insert(
            id: id,
            tenantId: tenantId,
            serialNumber: serialNumber,
            payloadJson: jsonEncode(payload),
            warrantyExpiryDate: Value(warrantyExpiryDate),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Returns the cached warranty JSON payload for [serialNumber], or null
  /// when this tenant has no cached warranty for that serial.
  Future<Map<String, dynamic>?> getCachedWarrantyBySerial({
    required String tenantId,
    required String serialNumber,
  }) async {
    final row =
        await (_db.select(_db.computerWarrantyCache)..where(
              (t) =>
                  t.tenantId.equals(tenantId) &
                  t.serialNumber.equals(serialNumber),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    return jsonDecode(row.payloadJson) as Map<String, dynamic>;
  }

  /// Returns the cached warranty JSON payload for [warrantyId], or null.
  Future<Map<String, dynamic>?> getCachedWarrantyById({
    required String tenantId,
    required String warrantyId,
  }) async {
    final row =
        await (_db.select(_db.computerWarrantyCache)..where(
              (t) => t.tenantId.equals(tenantId) & t.id.equals(warrantyId),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    return jsonDecode(row.payloadJson) as Map<String, dynamic>;
  }

  // ==========================================================================
  // SERIALS
  // ==========================================================================

  /// Upserts a single component serial's raw JSON payload into the cache.
  Future<void> upsertSerial({
    required String tenantId,
    required String serialNumber,
    required Map<String, dynamic> payload,
  }) async {
    await _db
        .into(_db.computerSerialsCache)
        .insert(
          ComputerSerialsCacheCompanion.insert(
            serialNumber: serialNumber,
            tenantId: tenantId,
            payloadJson: jsonEncode(payload),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Upserts a batch of serials (e.g. from a list read) in one pass.
  Future<void> upsertSerials({
    required String tenantId,
    required List<Map<String, dynamic>> payloads,
  }) async {
    for (final payload in payloads) {
      final serial =
          payload['serialNumber']?.toString() ?? payload['serial']?.toString();
      if (serial == null || serial.isEmpty) continue;
      await upsertSerial(
        tenantId: tenantId,
        serialNumber: serial,
        payload: payload,
      );
    }
  }

  /// Returns all cached serial JSON payloads for [tenantId].
  Future<List<Map<String, dynamic>>> getCachedSerials({
    required String tenantId,
  }) async {
    final rows = await (_db.select(
      _db.computerSerialsCache,
    )..where((t) => t.tenantId.equals(tenantId))).get();
    return rows
        .map((r) => jsonDecode(r.payloadJson) as Map<String, dynamic>)
        .toList();
  }
}
