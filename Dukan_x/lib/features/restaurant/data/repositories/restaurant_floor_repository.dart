// ============================================================================
// RESTAURANT FLOOR REPOSITORY
// ============================================================================

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../models/restaurant_floor_model.dart';

/// Manages CRUD operations for restaurant floors/zones.
/// Supports offline-first via local Drift DB + isSynced flag.
class RestaurantFloorRepository {
  final AppDatabase _db = AppDatabase.instance;
  final _uuid = const Uuid();

  // ---------------------------------------------------------------------------
  // Watch / Read
  // ---------------------------------------------------------------------------

  /// Stream all active floors for a vendor
  Stream<List<RestaurantFloor>> watchFloors(String vendorId) {
    return (_db.select(_db.restaurantFloors)
          ..where((t) => t.vendorId.equals(vendorId) & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch()
        .map((rows) => rows.map(RestaurantFloor.fromEntity).toList());
  }

  /// Get all floors (one-shot)
  Future<List<RestaurantFloor>> getFloors(String vendorId) async {
    final rows =
        await (_db.select(_db.restaurantFloors)
              ..where(
                (t) => t.vendorId.equals(vendorId) & t.isActive.equals(true),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    return rows.map(RestaurantFloor.fromEntity).toList();
  }

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  Future<RestaurantFloor> createFloor({
    required String vendorId,
    required String name,
    FloorType floorType = FloorType.custom,
    String? description,
    int sortOrder = 0,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();

    await _db
        .into(_db.restaurantFloors)
        .insert(
          RestaurantFloorsCompanion.insert(
            id: id,
            vendorId: vendorId,
            name: name,
            floorType: floorType.value,
            description: Value(description),
            sortOrder: sortOrder,
            createdAt: now,
            updatedAt: now,
          ),
        );

    return RestaurantFloor(
      id: id,
      vendorId: vendorId,
      name: name,
      floorType: floorType,
      description: description,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );
  }

  // ---------------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------------

  Future<void> updateFloor({
    required String id,
    String? name,
    FloorType? floorType,
    String? description,
    int? sortOrder,
  }) async {
    await (_db.update(
      _db.restaurantFloors,
    )..where((t) => t.id.equals(id))).write(
      RestaurantFloorsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        floorType: floorType != null
            ? Value(floorType.value)
            : const Value.absent(),
        description: description != null
            ? Value(description)
            : const Value.absent(),
        sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
        isSynced: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Delete (soft delete)
  // ---------------------------------------------------------------------------

  Future<void> deleteFloor(String id) async {
    await (_db.update(
      _db.restaurantFloors,
    )..where((t) => t.id.equals(id))).write(
      RestaurantFloorsCompanion(
        isActive: const Value(false),
        isSynced: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
