// ============================================================================
// DECORATION & CATERING — DcEventsTable (offline-read cache)
// ============================================================================
// Write-through Drift cache mirroring the fields of `EventBooking`
// (lib/features/decoration_catering/data/models/dc_models.dart) that are
// needed to render bookings while offline. Money fields are stored as
// integer paise (Ground Rule 3), even though `EventBooking` itself still
// carries `double` rupee fields at the UI boundary.
//
// Populated by `DcSyncHandler` on a successful `DcRepository.getBookings()`
// call and read as a fallback by `dcBookingsProvider` when the live API call
// throws (Requirement 2.6).
// ============================================================================

import 'package:drift/drift.dart';

/// Local offline-read cache of `EventBooking` rows.
///
/// Primary key: `id` (same id as the remote `EventBooking.id`).
@DataClassName('DcEventEntity')
class DcEventsTable extends Table {
  /// Same id as the remote `EventBooking.id`.
  TextColumn get id => text()();

  TextColumn get customerName => text()();
  TextColumn get customerPhone => text()();
  TextColumn get eventTitle => text()();
  DateTimeColumn get eventDate => dateTime()();
  DateTimeColumn get eventEndDate => dateTime().nullable()();
  TextColumn get venue => text()();
  IntColumn get guestCount => integer()();

  /// Mirrors `EventBooking.status.name` (e.g. `inquiry`, `confirmed`).
  TextColumn get status => text()();

  /// Integer-paise mirror of `EventBooking.quotedAmount` (rupees).
  IntColumn get quotedAmountPaisa => integer()();

  /// Integer-paise mirror of `EventBooking.advancePaid` (rupees).
  IntColumn get advancePaidPaisa => integer()();

  /// Timestamp of the last successful write-through sync for this row.
  DateTimeColumn get lastSyncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
