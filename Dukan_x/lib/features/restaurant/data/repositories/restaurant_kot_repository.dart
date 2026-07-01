// ============================================================================
// RESTAURANT KOT REPOSITORY
// ============================================================================

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../models/restaurant_kot_model.dart';

/// Manages KOT (Kitchen Order Ticket) creation and lifecycle.
/// KOTs are the backbone of the kitchen order flow in the POS system.
class RestaurantKotRepository {
  final AppDatabase _db = AppDatabase.instance;
  final _uuid = const Uuid();

  // ---------------------------------------------------------------------------
  // Watch / Read
  // ---------------------------------------------------------------------------

  /// Stream all active KOTs for a vendor (today's kitchen board)
  Stream<List<RestaurantKot>> watchActiveKots(String vendorId) {
    final today = DateTime.now().subtract(const Duration(hours: 16));
    return (_db.select(_db.restaurantKots)
          ..where(
            (t) =>
                t.vendorId.equals(vendorId) &
                t.status.isNotIn(['CANCELLED']) &
                t.createdAt.isBiggerThanValue(today),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(RestaurantKot.fromEntity).toList());
  }

  /// Get KOTs for a specific table (today)
  Future<List<RestaurantKot>> getKotsForTable(
    String vendorId,
    String tableId,
  ) async {
    final today = DateTime.now().subtract(const Duration(hours: 12));
    final rows =
        await (_db.select(_db.restaurantKots)
              ..where(
                (t) =>
                    t.vendorId.equals(vendorId) &
                    t.tableId.equals(tableId) &
                    t.createdAt.isBiggerThanValue(today),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.kotNumber)]))
            .get();
    return rows.map(RestaurantKot.fromEntity).toList();
  }

  /// Get next KOT number for the day
  Future<int> getNextKotNumber(String vendorId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final rows =
        await (_db.select(_db.restaurantKots)..where(
              (t) =>
                  t.vendorId.equals(vendorId) &
                  t.createdAt.isBiggerThanValue(startOfDay),
            ))
            .get();

    if (rows.isEmpty) return 1;
    final maxKot = rows.map((e) => e.kotNumber).reduce((a, b) => a > b ? a : b);
    return maxKot + 1;
  }

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  /// Punch a new KOT — called from the POS billing screen
  Future<RestaurantKot> punchKot({
    required String vendorId,
    required List<KotItem> items,
    String? orderId,
    String? tableId,
    String? tableNumber,
    String? staffId,
    String? waiterId,
    String? specialInstructions,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final kotNumber = await getNextKotNumber(vendorId);

    final kot = RestaurantKot(
      id: id,
      vendorId: vendorId,
      orderId: orderId,
      tableId: tableId,
      tableNumber: tableNumber,
      kotNumber: kotNumber,
      items: items,
      status: KotStatus.pending,
      staffId: staffId,
      waiterId: waiterId,
      specialInstructions: specialInstructions,
      isSynced: false,
      createdAt: now,
      updatedAt: now,
    );

    await _db
        .into(_db.restaurantKots)
        .insert(
          RestaurantKotsCompanion.insert(
            id: id,
            vendorId: vendorId,
            orderId: Value(orderId),
            tableId: Value(tableId),
            tableNumber: Value(tableNumber),
            kotNumber: kotNumber,
            itemsJson: kot.itemsJson,
            status: KotStatus.pending.value,
            staffId: Value(staffId),
            waiterId: Value(waiterId),
            specialInstructions: Value(specialInstructions),
            createdAt: now,
            updatedAt: now,
          ),
        );

    return kot;
  }

  // ---------------------------------------------------------------------------
  // Status Update
  // ---------------------------------------------------------------------------

  Future<void> markKotSent(String kotId) =>
      _updateStatus(kotId, KotStatus.sent);
  Future<void> markKotPrinted(String kotId) =>
      _updateStatus(kotId, KotStatus.printed);
  Future<void> cancelKot(String kotId) =>
      _updateStatus(kotId, KotStatus.cancelled);

  Future<void> _updateStatus(String kotId, KotStatus status) async {
    await (_db.update(
      _db.restaurantKots,
    )..where((t) => t.id.equals(kotId))).write(
      RestaurantKotsCompanion(
        status: Value(status.value),
        isSynced: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
