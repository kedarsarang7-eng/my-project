// ============================================================================
// DECORATION & CATERING — DcInventoryTable (offline-read cache)
// ============================================================================
// Write-through Drift cache mirroring the fields of `DcInventoryItem`
// (lib/features/decoration_catering/data/models/dc_models.dart) that are
// needed to render inventory while offline. Money fields are stored as
// integer paise (Ground Rule 3), even though `DcInventoryItem` itself still
// carries `double` rupee fields at the UI boundary.
//
// Populated by `DcSyncHandler` on a successful `DcRepository.getInventory()`
// call and read as a fallback by `dcInventoryProvider` when the live API
// call throws (Requirement 2.6).
// ============================================================================

import 'package:drift/drift.dart';

/// Local offline-read cache of `DcInventoryItem` rows.
///
/// Primary key: `id` (same id as the remote `DcInventoryItem.id`).
@DataClassName('DcInventoryEntity')
class DcInventoryTable extends Table {
  /// Same id as the remote `DcInventoryItem.id`.
  TextColumn get id => text()();

  TextColumn get name => text()();

  /// Mirrors `DcInventoryItem.category.name` (e.g. `furniture`, `lighting`).
  TextColumn get category => text()();

  IntColumn get totalQty => integer()();
  IntColumn get availableQty => integer()();

  /// Integer-paise mirror of `DcInventoryItem.rentalPrice` (rupees).
  IntColumn get rentalPricePaisa => integer()();

  /// Timestamp of the last successful write-through sync for this row.
  DateTimeColumn get lastSyncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
