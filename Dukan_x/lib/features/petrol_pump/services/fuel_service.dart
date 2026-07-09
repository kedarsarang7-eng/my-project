import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_queue_state_machine.dart';
import '../models/fuel_type.dart';

/// FuelService - Manages fuel types and rates
///
/// Refactored for Offline-First using Drift (SQLite).
/// Single Source of Truth: Local Database.
class FuelService {
  late final AppDatabase _db;
  late final SessionManager _sessionManager;

  FuelService({AppDatabase? db, SessionManager? sessionManager}) {
    _db = db ?? sl<AppDatabase>();
    _sessionManager = sessionManager ?? sl<SessionManager>();
  }

  String get _ownerId => _sessionManager.ownerId ?? '';

  /// Add default fuel types for a new petrol pump setup
  Future<void> initializeDefaultFuels() async {
    final defaults = FuelType.defaultFuelTypes(_ownerId);

    for (var fuel in defaults) {
      // Only insert if not already present
      final existing =
          await (_db.select(_db.fuelTypes)..where(
                (t) =>
                    t.fuelId.equals(fuel.fuelId) & t.ownerId.equals(_ownerId),
              ))
              .getSingleOrNull();

      if (existing == null) {
        await _db
            .into(_db.fuelTypes)
            .insert(
              FuelTypesCompanion(
                fuelId: Value(fuel.fuelId),
                ownerId: Value(_ownerId),
                fuelName: Value(fuel.fuelName),
                currentRatePerLitre: Value(fuel.currentRatePerLitre),
                rateHistoryJson: Value(
                  jsonEncode(fuel.rateHistory.map((e) => e.toMap()).toList()),
                ),
                linkedGSTRate: Value(fuel.linkedGSTRate),
                isActive: Value(fuel.isActive),
                isSynced: const Value(false),
                createdAt: Value(fuel.createdAt),
                updatedAt: Value(fuel.updatedAt),
              ),
            );

        await _enqueueSync(
          operationType: SyncOperationType.create,
          targetCollection: 'fuelTypes',
          documentId: fuel.fuelId,
          payload: fuel.toMap(),
        );
      }
    }
  }

  /// Get all fuel types as a stream (for StreamBuilder compatibility)
  Stream<List<FuelType>> getFuelTypes() {
    return (_db.select(_db.fuelTypes)..where((t) => t.ownerId.equals(_ownerId)))
        .watch()
        .map((entities) => entities.map(_mapEntityToDomain).toList());
  }

  /// Update fuel rate
  Future<void> updateFuelRate(
    String fuelId,
    double newRate, {
    String? updatedBy,
  }) async {
    final entity = await (_db.select(
      _db.fuelTypes,
    )..where((t) => t.fuelId.equals(fuelId))).getSingleOrNull();

    if (entity != null) {
      final fuel = _mapEntityToDomain(entity);
      final updatedFuel = fuel.updateRate(newRate, updatedBy: updatedBy);

      await (_db.update(
        _db.fuelTypes,
      )..where((t) => t.fuelId.equals(fuelId))).write(
        FuelTypesCompanion(
          currentRatePerLitre: Value(updatedFuel.currentRatePerLitre),
          rateHistoryJson: Value(
            jsonEncode(updatedFuel.rateHistory.map((e) => e.toMap()).toList()),
          ),
          isSynced: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await _enqueueSync(
        operationType: SyncOperationType.update,
        targetCollection: 'fuelTypes',
        documentId: fuelId,
        payload: updatedFuel.toMap(),
      );
    }
  }

  /// Add new custom fuel type
  Future<void> addFuelType(FuelType fuel) async {
    final now = DateTime.now();
    await _db
        .into(_db.fuelTypes)
        .insert(
          FuelTypesCompanion(
            fuelId: Value(fuel.fuelId),
            ownerId: Value(_ownerId),
            fuelName: Value(fuel.fuelName),
            currentRatePerLitre: Value(fuel.currentRatePerLitre),
            rateHistoryJson: Value(
              jsonEncode(fuel.rateHistory.map((e) => e.toMap()).toList()),
            ),
            linkedGSTRate: Value(fuel.linkedGSTRate),
            isActive: Value(fuel.isActive),
            isSynced: const Value(false),
            createdAt: Value(fuel.createdAt),
            updatedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );

    await _enqueueSync(
      operationType: SyncOperationType.create,
      targetCollection: 'fuelTypes',
      documentId: fuel.fuelId,
      payload: fuel.toMap(),
    );
  }

  /// Toggle fuel active status
  Future<void> toggleFuelStatus(String fuelId, bool isActive) async {
    await (_db.update(
      _db.fuelTypes,
    )..where((t) => t.fuelId.equals(fuelId))).write(
      FuelTypesCompanion(
        isActive: Value(isActive),
        isSynced: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );

    await _enqueueSync(
      operationType: SyncOperationType.update,
      targetCollection: 'fuelTypes',
      documentId: fuelId,
      payload: {'fuelId': fuelId, 'isActive': isActive},
    );
  }

  // --- Helpers ---

  /// Map Drift FuelTypeEntity to domain FuelType model
  FuelType _mapEntityToDomain(FuelTypeEntity entity) {
    List<RateHistoryEntry> history = [];
    try {
      final historyRaw = jsonDecode(entity.rateHistoryJson) as List<dynamic>;
      history = historyRaw
          .map((e) => RateHistoryEntry.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {}

    return FuelType(
      fuelId: entity.fuelId,
      fuelName: entity.fuelName,
      currentRatePerLitre: entity.currentRatePerLitre,
      rateHistory: history,
      linkedGSTRate: entity.linkedGSTRate,
      ownerId: entity.ownerId,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Enqueue a sync operation for offline-first sync
  Future<void> _enqueueSync({
    required SyncOperationType operationType,
    required String targetCollection,
    required String documentId,
    required Map<String, dynamic> payload,
  }) async {
    final safeDocId = documentId.length >= 4
        ? documentId.substring(0, 4)
        : documentId;
    final opId = '${DateTime.now().microsecondsSinceEpoch}_$safeDocId';

    final syncItem = SyncQueueCompanion(
      operationId: Value(opId),
      operationType: Value(operationType.name),
      targetCollection: Value(targetCollection),
      documentId: Value(documentId),
      payload: Value(jsonEncode(payload)),
      status: const Value('PENDING'),
      createdAt: Value(DateTime.now()),
      retryCount: const Value(0),
      ownerId: Value(_ownerId),
      userId: Value(_ownerId),
      priority: const Value(1),
    );

    await _db.into(_db.syncQueue).insert(syncItem);
  }
}
