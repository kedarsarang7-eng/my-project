// ============================================================================
// DECORATION & CATERING — DcSyncHandler
// ============================================================================
// Write-through offline-read cache + WebSocket sync handler for the DC
// vertical (Requirement 2.6, AC2 + AC6).
//
// Responsibilities:
//   1. Write-through cache (AC2): on a successful live
//      `DcRepository.getBookings()` / `getInventory()` call, persist the
//      returned rows into `DcEventsTable` / `DcInventoryTable` so a later
//      offline-read fallback (Task 10) has last-synced data to serve.
//   2. WebSocket sync (AC6): applies `dc.event.confirmed`,
//      `dc.payment.received`, and `dc.staff.assigned` events — delivered by
//      the existing app-wide `WebSocketService` — to the corresponding
//      local Drift row.
//
// Design note — why this does NOT go through `SyncManager.enqueue()`:
// `SyncManager`/`sync_manager.dart` (and the `RestaurantSyncService` pattern
// it backs) is a PUSH-sync pipeline: it uploads locally-created/changed rows
// to the backend via a queue. This handler is the OPPOSITE direction — it
// caches successful REMOTE READS locally for offline fallback. There is no
// upload queue involved, so this class talks directly to `AppDatabase`'s DC
// tables instead of calling `SyncManager.enqueue()`. It is registered as a
// standalone singleton via the service locator (see
// `lib/core/di/service_locator.dart`) rather than through `SyncManager`,
// since `SyncManager`'s queue has no hook point for a read-through cache.
// ============================================================================

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/websocket_service.dart'
    show WebSocketService, WSEvent;
import '../data/models/dc_models.dart';

class DcSyncHandler {
  DcSyncHandler({AppDatabase? db, bool autoAttachWebSocket = true})
    : _db = db ?? sl<AppDatabase>() {
    if (autoAttachWebSocket) {
      attachWebSocketListeners();
    }
  }

  final AppDatabase _db;

  bool _wsAttached = false;

  static int _toPaisa(double rupees) => (rupees * 100).round();

  // ── Write-through cache (Requirement 2.6 AC2) ───────────────────────────

  /// Upserts [bookings] into `DcEventsTable`, stamping `lastSyncedAt` with
  /// the current time. Called by `DcRepository.getBookings()` after a
  /// successful live fetch.
  Future<void> cacheBookings(List<EventBooking> bookings) async {
    if (bookings.isEmpty) return;
    final now = DateTime.now();
    for (final b in bookings) {
      await _db
          .into(_db.dcEventsTable)
          .insertOnConflictUpdate(
            DcEventsTableCompanion.insert(
              id: b.id,
              customerName: b.customerName,
              customerPhone: b.customerPhone,
              eventTitle: b.eventTitle,
              eventDate: b.eventDate,
              eventEndDate: Value(b.eventEndDate),
              venue: b.venue,
              guestCount: b.guestCount,
              status: b.status.name,
              quotedAmountPaisa: _toPaisa(b.quotedAmount),
              advancePaidPaisa: _toPaisa(b.advancePaid),
              lastSyncedAt: now,
            ),
          );
    }
  }

  /// Upserts [items] into `DcInventoryTable`, stamping `lastSyncedAt` with
  /// the current time. Called by `DcRepository.getInventory()` after a
  /// successful live fetch.
  Future<void> cacheInventory(List<DcInventoryItem> items) async {
    if (items.isEmpty) return;
    final now = DateTime.now();
    for (final item in items) {
      await _db
          .into(_db.dcInventoryTable)
          .insertOnConflictUpdate(
            DcInventoryTableCompanion.insert(
              id: item.id,
              name: item.name,
              category: item.category.name,
              totalQty: item.totalQty,
              availableQty: item.availableQty,
              rentalPricePaisa: _toPaisa(item.rentalPrice),
              lastSyncedAt: now,
            ),
          );
    }
  }

  // ── Read-through offline fallback (Requirement 2.6 AC3) ─────────────────
  //
  // Reverse of `cacheBookings`/`cacheInventory` above: reads whatever rows
  // are currently in `DcEventsTable`/`DcInventoryTable` and maps them back
  // to domain objects. Used by `dcBookingsProvider`/`dcInventoryProvider`
  // (`dc_repository.dart`) when the live `getBookings()`/`getInventory()`
  // call throws, so the UI has last-synced data to show instead of an error
  // screen. Returns an empty list (never throws) if nothing has been cached
  // yet — callers tag the result `isStale: true` regardless.

  /// Reads all rows in `DcEventsTable` and maps them back to `EventBooking`.
  ///
  /// Only the fields mirrored by `DcEventsTable` are populated; fields the
  /// table does not store (e.g. `customerId`, `eventType`, `notes`) fall
  /// back to `EventBooking`'s own defaults, consistent with the table's
  /// documented "fields needed to render bookings while offline" scope.
  Future<List<EventBooking>> getCachedBookings() async {
    final rows = await _db.select(_db.dcEventsTable).get();
    return rows.map(_bookingFromCacheRow).toList();
  }

  /// Reads all rows in `DcInventoryTable` and maps them back to
  /// `DcInventoryItem`. Same fallback role as [getCachedBookings], for
  /// `dcInventoryProvider`.
  Future<List<DcInventoryItem>> getCachedInventory() async {
    final rows = await _db.select(_db.dcInventoryTable).get();
    return rows.map(_inventoryFromCacheRow).toList();
  }

  static double _fromPaisa(int paise) => paise / 100.0;

  EventBooking _bookingFromCacheRow(DcEventEntity e) {
    return EventBooking(
      id: e.id,
      customerId: '',
      customerName: e.customerName,
      customerPhone: e.customerPhone,
      eventType: EventType.other,
      eventTitle: e.eventTitle,
      eventDate: e.eventDate,
      eventEndDate: e.eventEndDate,
      venue: e.venue,
      guestCount: e.guestCount,
      status: _statusFromCacheString(e.status),
      quotedAmount: _fromPaisa(e.quotedAmountPaisa),
      advancePaid: _fromPaisa(e.advancePaidPaisa),
      createdAt: e.lastSyncedAt,
    );
  }

  static EventStatus _statusFromCacheString(String s) {
    for (final status in EventStatus.values) {
      if (status.name == s) return status;
    }
    return EventStatus.inquiry;
  }

  DcInventoryItem _inventoryFromCacheRow(DcInventoryEntity e) {
    return DcInventoryItem(
      id: e.id,
      name: e.name,
      category: _categoryFromCacheString(e.category),
      totalQty: e.totalQty,
      availableQty: e.availableQty,
      purchasePrice: 0,
      rentalPrice: _fromPaisa(e.rentalPricePaisa),
    );
  }

  static InventoryCategory _categoryFromCacheString(String s) {
    for (final category in InventoryCategory.values) {
      if (category.name == s) return category;
    }
    return InventoryCategory.furniture;
  }

  // ── WebSocket sync (Requirement 2.6 AC6) ────────────────────────────────

  /// Subscribes to `dc.event.confirmed`, `dc.payment.received`, and
  /// `dc.staff.assigned` on the app-wide [WebSocketService] singleton and
  /// applies each to the matching local Drift row. Idempotent — calling
  /// this more than once has no additional effect until [detachWebSocketListeners]
  /// is called.
  void attachWebSocketListeners() {
    if (_wsAttached) return;
    final ws = WebSocketService.instance;
    ws.subscribe('dc.event.confirmed', _onEventConfirmed);
    ws.subscribe('dc.payment.received', _onPaymentReceived);
    ws.subscribe('dc.staff.assigned', _onStaffAssigned);
    _wsAttached = true;
  }

  /// Unsubscribes all three listeners. Exposed mainly for tests/teardown.
  void detachWebSocketListeners() {
    if (!_wsAttached) return;
    final ws = WebSocketService.instance;
    ws.unsubscribe('dc.event.confirmed', _onEventConfirmed);
    ws.unsubscribe('dc.payment.received', _onPaymentReceived);
    ws.unsubscribe('dc.staff.assigned', _onStaffAssigned);
    _wsAttached = false;
  }

  /// `dc.event.confirmed`: sets the local row's `status` to `confirmed` for
  /// the event id in `event.data['eventId']` (falling back to
  /// `event.data['id']`). No-ops if no cached row exists for that id yet
  /// (nothing to update — the row will be created on the next successful
  /// `getBookings()` write-through instead).
  Future<void> _onEventConfirmed(WSEvent event) async {
    final eventId =
        event.data['eventId'] as String? ?? event.data['id'] as String?;
    if (eventId == null || eventId.isEmpty) return;
    try {
      await (_db.update(_db.dcEventsTable)..where((t) => t.id.equals(eventId)))
          .write(const DcEventsTableCompanion(status: Value('confirmed')));
    } catch (e) {
      debugPrint(
        '[DcSyncHandler] Failed to apply dc.event.confirmed for '
        '"$eventId": $e',
      );
    }
  }

  /// `dc.payment.received`: updates the local row's `advancePaidPaisa` for
  /// the event id in `event.data['eventId']`, using
  /// `event.data['advancePaidPaisa']` (falling back to
  /// `event.data['amountPaisa']`) as the new running total, mirroring the
  /// existing `EventBooking.advancePaid` semantics (a cumulative total, not
  /// a delta). No-ops if the amount field is absent/non-numeric, or if no
  /// cached row exists for that id yet.
  Future<void> _onPaymentReceived(WSEvent event) async {
    final eventId = event.data['eventId'] as String?;
    if (eventId == null || eventId.isEmpty) return;
    final rawAmount =
        event.data['advancePaidPaisa'] ?? event.data['amountPaisa'];
    if (rawAmount is! num) return;
    try {
      await (_db.update(
        _db.dcEventsTable,
      )..where((t) => t.id.equals(eventId))).write(
        DcEventsTableCompanion(advancePaidPaisa: Value(rawAmount.round())),
      );
    } catch (e) {
      debugPrint(
        '[DcSyncHandler] Failed to apply dc.payment.received for '
        '"$eventId": $e',
      );
    }
  }

  /// `dc.staff.assigned`: intentionally a no-op beyond logging.
  ///
  /// Neither `DcEventsTable` nor `DcInventoryTable` (Task 8's scope) mirrors
  /// `EventBooking.assignedStaffIds` — staff-assignment caching was not part
  /// of the offline-read cache this remediation introduces. This handler
  /// still subscribes to the event (per Requirement 2.6 AC6's named event
  /// list) so the subscription contract is honored, but there is no
  /// "corresponding local Drift row" for it to update.
  void _onStaffAssigned(WSEvent event) {
    debugPrint(
      '[DcSyncHandler] dc.staff.assigned received for event '
      '"${event.data['eventId']}"; no local Drift field to update '
      '(staff assignment is outside DcEventsTable/DcInventoryTable scope).',
    );
  }
}
