// ============================================================================
// RESTAURANT TABLE REPOSITORY
// ============================================================================

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/error/error_handler.dart';
import '../models/restaurant_table_model.dart';

/// Repository for managing restaurant tables
class RestaurantTableRepository {
  final AppDatabase _db;
  final ErrorHandler _errorHandler;
  static const _uuid = Uuid();

  RestaurantTableRepository({AppDatabase? db, ErrorHandler? errorHandler})
    : _db = db ?? AppDatabase.instance,
      _errorHandler = errorHandler ?? ErrorHandler.instance;

  // ============================================================================
  // TABLE CRUD OPERATIONS
  // ============================================================================

  /// Create a new table
  Future<RepositoryResult<RestaurantTable>> createTable({
    required String vendorId,
    required String tableNumber,
    int capacity = 4,
    String? section,
  }) async {
    return await _errorHandler.runSafe<RestaurantTable>(() async {
      final now = DateTime.now();
      final id = _uuid.v4();

      await _db
          .into(_db.restaurantTables)
          .insert(
            RestaurantTablesCompanion.insert(
              id: id,
              vendorId: vendorId,
              tableNumber: tableNumber,
              capacity: Value(capacity),
              section: Value(section),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final entity = await (_db.select(
        _db.restaurantTables,
      )..where((t) => t.id.equals(id))).getSingle();

      return RestaurantTable.fromEntity(entity);
    }, 'createTable');
  }

  /// Update a table
  Future<RepositoryResult<RestaurantTable>> updateTable({
    required String id,
    String? tableNumber,
    int? capacity,
    String? section,
  }) async {
    return await _errorHandler.runSafe<RestaurantTable>(() async {
      await (_db.update(
        _db.restaurantTables,
      )..where((t) => t.id.equals(id))).write(
        RestaurantTablesCompanion(
          tableNumber: tableNumber != null
              ? Value(tableNumber)
              : const Value.absent(),
          capacity: capacity != null ? Value(capacity) : const Value.absent(),
          section: section != null ? Value(section) : const Value.absent(),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );

      final entity = await (_db.select(
        _db.restaurantTables,
      )..where((t) => t.id.equals(id))).getSingle();

      return RestaurantTable.fromEntity(entity);
    }, 'updateTable');
  }

  /// Soft delete a table
  Future<RepositoryResult<void>> deleteTable(String id) async {
    return await _errorHandler.runSafe<void>(() async {
      await (_db.update(
        _db.restaurantTables,
      )..where((t) => t.id.equals(id))).write(
        RestaurantTablesCompanion(
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );
    }, 'deleteTable');
  }

  // ============================================================================
  // TABLE QUERIES
  // ============================================================================

  /// Get table by ID
  Future<RepositoryResult<RestaurantTable?>> getTableById(String id) async {
    return await _errorHandler.runSafe<RestaurantTable?>(() async {
      final entity = await (_db.select(
        _db.restaurantTables,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      return entity != null ? RestaurantTable.fromEntity(entity) : null;
    }, 'getTableById');
  }

  /// Get all tables for a vendor
  Future<RepositoryResult<List<RestaurantTable>>> getTablesByVendor(
    String vendorId,
  ) async {
    return await _errorHandler.runSafe<List<RestaurantTable>>(() async {
      final entities =
          await (_db.select(_db.restaurantTables)
                ..where(
                  (t) =>
                      t.vendorId.equals(vendorId) &
                      t.isActive.equals(true) &
                      t.deletedAt.isNull(),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.tableNumber)]))
              .get();

      return entities.map((e) => RestaurantTable.fromEntity(e)).toList();
    }, 'getTablesByVendor');
  }

  /// Get table by number
  Future<RepositoryResult<RestaurantTable?>> getTableByNumber(
    String vendorId,
    String tableNumber,
  ) async {
    return await _errorHandler.runSafe<RestaurantTable?>(() async {
      final entity =
          await (_db.select(_db.restaurantTables)..where(
                (t) =>
                    t.vendorId.equals(vendorId) &
                    t.tableNumber.equals(tableNumber) &
                    t.deletedAt.isNull(),
              ))
              .getSingleOrNull();

      return entity != null ? RestaurantTable.fromEntity(entity) : null;
    }, 'getTableByNumber');
  }

  /// Get tables by section
  Future<RepositoryResult<List<RestaurantTable>>> getTablesBySection(
    String vendorId,
    String section,
  ) async {
    return await _errorHandler.runSafe<List<RestaurantTable>>(() async {
      final entities =
          await (_db.select(_db.restaurantTables)
                ..where(
                  (t) =>
                      t.vendorId.equals(vendorId) &
                      t.section.equals(section) &
                      t.isActive.equals(true) &
                      t.deletedAt.isNull(),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.tableNumber)]))
              .get();

      return entities.map((e) => RestaurantTable.fromEntity(e)).toList();
    }, 'getTablesBySection');
  }

  /// Get available tables
  Future<RepositoryResult<List<RestaurantTable>>> getAvailableTables(
    String vendorId,
  ) async {
    return await _errorHandler.runSafe<List<RestaurantTable>>(() async {
      final entities =
          await (_db.select(_db.restaurantTables)
                ..where(
                  (t) =>
                      t.vendorId.equals(vendorId) &
                      t.status.equals(TableStatus.available.value) &
                      t.isActive.equals(true) &
                      t.deletedAt.isNull(),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.tableNumber)]))
              .get();

      return entities.map((e) => RestaurantTable.fromEntity(e)).toList();
    }, 'getAvailableTables');
  }

  // ============================================================================
  // REAL-TIME STREAMS
  // ============================================================================

  /// Watch all tables for a vendor
  Stream<List<RestaurantTable>> watchTables(String vendorId) {
    return (_db.select(_db.restaurantTables)
          ..where(
            (t) =>
                t.vendorId.equals(vendorId) &
                t.isActive.equals(true) &
                t.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.tableNumber)]))
        .watch()
        .map((rows) => rows.map((e) => RestaurantTable.fromEntity(e)).toList());
  }

  // ============================================================================
  // STATUS MANAGEMENT
  // ============================================================================

  /// Update table status
  Future<RepositoryResult<void>> updateTableStatus(
    String tableId,
    TableStatus status,
  ) async {
    return await _errorHandler.runSafe<void>(() async {
      await (_db.update(
        _db.restaurantTables,
      )..where((t) => t.id.equals(tableId))).write(
        RestaurantTablesCompanion(
          status: Value(status.value),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );
    }, 'updateTableStatus');
  }

  /// Mark table as occupied
  Future<RepositoryResult<void>> occupyTable(String tableId) async {
    return updateTableStatus(tableId, TableStatus.occupied);
  }

  /// Mark table as available
  Future<RepositoryResult<void>> releaseTable(String tableId) async {
    return updateTableStatus(tableId, TableStatus.available);
  }

  /// Mark table as cleaning
  Future<RepositoryResult<void>> setTableCleaning(String tableId) async {
    return updateTableStatus(tableId, TableStatus.cleaning);
  }

  /// Mark table as reserved
  Future<RepositoryResult<void>> reserveTable(String tableId) async {
    return updateTableStatus(tableId, TableStatus.reserved);
  }

  // ============================================================================
  // QR CODE LINKING
  // ============================================================================

  /// Link QR code to table
  Future<RepositoryResult<void>> linkQrCode(
    String tableId,
    String qrCodeId,
  ) async {
    return await _errorHandler.runSafe<void>(() async {
      await (_db.update(
        _db.restaurantTables,
      )..where((t) => t.id.equals(tableId))).write(
        RestaurantTablesCompanion(
          qrCodeId: Value(qrCodeId),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );
    }, 'linkQrCode');
  }

  // ============================================================================
  // SYNC OPERATIONS
  // ============================================================================

  /// Get unsynced tables
  Future<List<RestaurantTable>> getUnsyncedTables(String vendorId) async {
    final entities =
        await (_db.select(_db.restaurantTables)..where(
              (t) => t.vendorId.equals(vendorId) & t.isSynced.equals(false),
            ))
            .get();

    return entities.map((e) => RestaurantTable.fromEntity(e)).toList();
  }

  /// Mark table as synced
  Future<void> markTableSynced(String tableId) async {
    await (_db.update(_db.restaurantTables)..where((t) => t.id.equals(tableId)))
        .write(const RestaurantTablesCompanion(isSynced: Value(true)));
  }

  // ============================================================================
  // BULK OPERATIONS
  // ============================================================================

  /// Create multiple tables at once
  Future<RepositoryResult<List<RestaurantTable>>> createMultipleTables({
    required String vendorId,
    required int count,
    int startNumber = 1,
    int capacity = 4,
    String? section,
  }) async {
    return await _errorHandler.runSafe<List<RestaurantTable>>(() async {
      final tables = <RestaurantTable>[];
      final now = DateTime.now();

      for (int i = 0; i < count; i++) {
        final tableNumber = (startNumber + i).toString();
        final id = _uuid.v4();

        await _db
            .into(_db.restaurantTables)
            .insert(
              RestaurantTablesCompanion.insert(
                id: id,
                vendorId: vendorId,
                tableNumber: tableNumber,
                capacity: Value(capacity),
                section: Value(section),
                createdAt: now,
                updatedAt: now,
              ),
            );

        final entity = await (_db.select(
          _db.restaurantTables,
        )..where((t) => t.id.equals(id))).getSingle();

        tables.add(RestaurantTable.fromEntity(entity));
      }

      return tables;
    }, 'createMultipleTables');
  }
}
