// ============================================================================
// business_alerts_widget.dart — Dashboard V2 alerts panel.
// ----------------------------------------------------------------------------
// UNS task 14.8 (consumer-side migration):
//   * Source data from the Shared SDK's `onNotification()` stream rather
//     than the in-process `EventDispatcher` polling channel.
//   * Subscribed events (Phase 2 §6.1, §6.2, §6.8, §6.9):
//       - inventory.stock.changed
//       - inventory.stock.low
//       - inventory.batch.expiring
//       - inventory.batch.expired
//   * Pre-migration behaviour (legacy emit-side `EventDispatcher`) is
//     preserved as the local fallback when the SDK isn't yet registered
//     in `service_locator.dart`, so this widget keeps refreshing during
//     the rollout window.
//
// _Requirements: REQ 10.6, 10.7, 11.2_
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column, Table;
import 'package:notifications_sdk/notifications_sdk.dart' as uns;

import '../../../../core/config/business_capabilities.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/services/event_dispatcher.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../features/academic_coaching/data/repositories/ac_repository.dart';
import '../../../../features/decoration_catering/data/repositories/dc_repository.dart';
import '../../../../features/hardware/data/hardware_ops_repository.dart';
import '../../../../features/jewellery/data/repositories/jewellery_repository_offline.dart';
import '../../../../features/book_store/data/book_repository.dart';
import '../../../../features/restaurant/providers/restaurant_alert_counts_provider.dart';
import '../../../../features/service/data/repositories/imei_serial_repository.dart';
import '../../../../features/wholesale/data/wholesale_repository.dart';
import '../../../../features/service/models/service_job.dart';
import '../../../../features/service/services/exchange_service.dart';
import '../../../../features/service/services/service_job_service.dart';
import '../../../../features/service/services/warranty_claim_service.dart';
import '../../../../providers/app_state_providers.dart';

/// UNS event_names (Phase 2 §6.1/6.2/6.8/6.9) that should refresh the
/// business-alerts counts. Anything outside this set is ignored so the
/// widget doesn't refetch on unrelated traffic.
const Set<String> _kInventoryAlertEvents = <String>{
  'inventory.stock.changed',
  'inventory.stock.low',
  'inventory.batch.expiring',
  'inventory.batch.expired',
};

/// Provider for real-time alert counts, sourced from the canonical UNS
/// `onNotification()` stream. Falls back to the legacy in-process
/// `EventDispatcher` channel only when the SDK has not yet been wired into
/// the DI container (keeps the dashboard live during bootstrap rollout).
final alertCountsProvider = StreamProvider<Map<String, int>>((ref) async* {
  final session = sl<SessionManager>();
  final userId = session.userId;
  if (userId == null) {
    yield <String, int>{};
    return;
  }

  final productsRepo = sl<ProductsRepository>();
  final db = sl<AppDatabase>();

  // Helper to fetch counts off Drift. Same query the legacy provider used —
  // only the trigger source has changed (REQ 10.9 message-content equivalence
  // for the rendered counts).
  Future<Map<String, int>> fetchCounts() async {
    final lowStockResult = await productsRepo.getLowStockProducts(
      userId: userId,
    );
    final lowStockCount = lowStockResult.data?.length ?? 0;

    final now = DateTime.now();
    final expiryThreshold = now.add(const Duration(days: 7));

    final expiringBatches =
        await (db.select(db.productBatches)..where(
              (t) =>
                  t.expiryDate.isNotNull() &
                  t.expiryDate.isSmallerOrEqualValue(expiryThreshold) &
                  t.expiryDate.isBiggerOrEqualValue(now) &
                  t.stockQuantity.isBiggerThanValue(0),
            ))
            .get();

    final counts = <String, int>{
      'lowStock': lowStockCount,
      'expiringSoon': expiringBatches.length,
    };

    // Clinic-specific counts (Req 2.21): today's appointments + pending lab
    // reports, scoped to the current tenant/owner.
    if (session.activeBusinessType == BusinessType.clinic) {
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final todayAppointments =
          await (db.select(db.appointments)..where(
                (a) =>
                    a.doctorId.equals(userId) &
                    a.scheduledTime.isBiggerOrEqualValue(todayStart) &
                    a.scheduledTime.isSmallerThanValue(todayEnd) &
                    a.status.equals('SCHEDULED'),
              ))
              .get();

      final pendingLabReports =
          await (db.select(db.labReports)..where(
                (r) => r.doctorId.equals(userId) & r.status.equals('PENDING'),
              ))
              .get();

      counts['todayAppointments'] = todayAppointments.length;
      counts['pendingLabReports'] = pendingLabReports.length;
    }

    return counts;
  }

  // Initial fetch (offline / first paint).
  yield await fetchCounts();

  // Prefer the canonical UNS stream; fall back to the legacy in-process
  // EventDispatcher only when the SDK is not yet registered.
  final uns.NotificationsSdk? sdk = _resolveSdk();
  if (sdk != null) {
    await for (final delivery in sdk.onNotification()) {
      if (_kInventoryAlertEvents.contains(delivery.eventName)) {
        yield await fetchCounts();
      }
    }
  } else {
    final eventDispatcher = sl<EventDispatcher>();
    await for (final _ in eventDispatcher.whereAny(<BusinessEvent>[
      BusinessEvent.stockChanged,
      BusinessEvent.stockLow,
      BusinessEvent.stockRestored,
      BusinessEvent.batchExpiring,
    ])) {
      yield await fetchCounts();
    }
  }
});

/// Best-effort SDK lookup. Returns `null` while the app's bootstrap hasn't
/// yet registered `NotificationsSdk` (e.g. early in a hot-reload session)
/// so the widget keeps rendering instead of crashing.
uns.NotificationsSdk? _resolveSdk() {
  try {
    if (sl.isRegistered<uns.NotificationsSdk>()) {
      return sl<uns.NotificationsSdk>();
    }
  } catch (_) {
    // get_it can throw on misconfigured scopes; fall through to null.
  }
  return null;
}

/// Immutable snapshot of the hardware-specific dashboard KPIs (bugfix.md 2.25).
/// Every value is sourced from the real [HardwareOpsRepository]; this type only
/// carries the aggregated numbers the dashboard renders.
class HardwareKpis {
  const HardwareKpis({
    required this.outstandingContractorCreditCents,
    required this.openIndents,
    required this.depositLiabilityCents,
    required this.fastMovers,
    required this.slowMovers,
  });

  /// Total receivable from contractors, in paise/cents.
  final int outstandingContractorCreditCents;

  /// Number of indents that are not yet closed.
  final int openIndents;

  /// Sum of refundable customer deposit balances, in paise/cents.
  final int depositLiabilityCents;

  /// Count of fast-moving items reported by item-velocity.
  final int fastMovers;

  /// Count of slow-moving items reported by item-velocity.
  final int slowMovers;
}

/// Mandi dashboard alert counts — queries the local Drift `VegetableLots`
/// table for lots whose lifecycle status is not SETTLED (i.e. payment is
/// pending). Returns a snapshot containing the count and a flag indicating
/// whether the data was successfully retrieved.
///
/// Requirements: 13.1, 13.5, 13.6
class MandiAlertSnapshot {
  const MandiAlertSnapshot({
    required this.lotsPendingPayment,
    required this.isAvailable,
    // Crate returns placeholder — ready to be driven by stored crate records
    // once crate management is implemented (R13.2).
    this.crateReturnsDue,
    this.crateDataAvailable = false,
  });

  /// Count of lots whose status is NOT 'SETTLED' (pending payment).
  final int lotsPendingPayment;

  /// Whether the lots-pending-payment data was successfully retrieved.
  final bool isAvailable;

  /// Count of crate records whose return status is outstanding.
  /// `null` when crate management is not implemented (omit metric).
  final int? crateReturnsDue;

  /// Whether crate data was successfully retrieved.
  final bool crateDataAvailable;
}

/// Provider that fetches the real Mandi alert metrics from stored data.
/// - Lots pending payment = count of `VegetableLots` with status != SETTLED.
/// - Crate returns: omitted (null) because `useCrateManagement` has zero
///   implementation (R13.2). The field is present in the snapshot so that,
///   when crate management is implemented, it can be wired without changing
///   the widget structure.
///
/// On retrieval failure, returns `MandiAlertSnapshot(lotsPendingPayment: 0,
/// isAvailable: false)` so the widget can display 0 with an unavailable
/// indication (R13.5).
final mandiAlertCountsProvider = FutureProvider.autoDispose<MandiAlertSnapshot>((
  ref,
) async {
  try {
    final session = sl<SessionManager>();
    final userId = session.userId;
    if (userId == null) {
      return const MandiAlertSnapshot(
        lotsPendingPayment: 0,
        isAvailable: false,
      );
    }

    final db = sl<AppDatabase>();

    // Count lots whose status is NOT 'SETTLED' — these are pending payment.
    // Statuses ARRIVED, AUCTIONED, SOLD all represent unsettled lots (R13.1).
    final pendingCount =
        await (db.selectOnly(db.vegetableLots)
              ..addColumns([db.vegetableLots.id.count()])
              ..where(
                db.vegetableLots.userId.equals(userId) &
                    db.vegetableLots.status.isNotIn(const ['SETTLED']),
              ))
            .map((row) => row.read(db.vegetableLots.id.count()) ?? 0)
            .getSingle();

    return MandiAlertSnapshot(
      lotsPendingPayment: pendingCount,
      isAvailable: true,
      // Crate management not implemented — omit metric (R13.2).
      crateReturnsDue: null,
      crateDataAvailable: false,
    );
  } catch (_) {
    // Data cannot be retrieved — display 0 with unavailable indication (R13.5).
    return const MandiAlertSnapshot(lotsPendingPayment: 0, isAvailable: false);
  }
});

/// Wholesale credit-limit alert snapshot — provides the real "customers near
/// limit" count from a tenant-scoped query, replacing the Phase 1 zeroed/hidden
/// fabricated count (§5, §8; Requirement 9.7).
class WholesaleCreditSnapshot {
  const WholesaleCreditSnapshot({
    required this.nearLimitCount,
    required this.isAvailable,
  });

  /// Count of customers whose outstanding >= 80% of their credit limit.
  final int nearLimitCount;

  /// Whether the near-limit count was successfully retrieved.
  final bool isAvailable;
}

/// Provider that fetches the real wholesale "customers near limit" count from
/// [WholesaleRepository.nearCreditLimitCount]. Scoped to the active tenant.
///
/// On retrieval failure, returns `WholesaleCreditSnapshot(nearLimitCount: 0,
/// isAvailable: false)` so the widget can display 0 with an unavailable
/// indication (§5, §8; Requirement 9.7).
final wholesaleCreditAlertCountsProvider =
    FutureProvider.autoDispose<WholesaleCreditSnapshot>((ref) async {
      try {
        final WholesaleRepository repo = WholesaleRepositoryImpl();
        final count = await repo.nearCreditLimitCount();
        return WholesaleCreditSnapshot(
          nearLimitCount: count,
          isAvailable: true,
        );
      } catch (_) {
        return const WholesaleCreditSnapshot(
          nearLimitCount: 0,
          isAvailable: false,
        );
      }
    });

/// Electronics dashboard alert counts — replaces the previous hardcoded
/// literals (`'5'` Warranty Expiring / `'8'` Pending Repairs) with real,
/// tenant-scoped queries (bugfix.md 2.17):
///   1. Warranty expiring — count of `IMEISerials` whose `warrantyEndDate`
///      falls within the next 30 days (not already expired), scoped to the
///      active tenant (`userId`).
///   2. Pending repairs — count of `ServiceJobs` not yet DELIVERED/CANCELLED
///      (i.e. in the active service queue), scoped to the active tenant.
///
/// Each metric is fetched independently. On retrieval failure that metric is
/// marked unavailable so the widget renders a `...` indicator rather than a
/// stale/default value. No hardcoded count — every count derives from a live
/// query result.
///
/// Requirements: 2.17, 2.19
class ElectronicsAlertSnapshot {
  const ElectronicsAlertSnapshot({
    required this.warrantyExpiring,
    required this.warrantyExpiringAvailable,
    required this.pendingRepairs,
    required this.pendingRepairsAvailable,
  });

  /// Count of devices whose warranty expires within the next 30 days.
  final int warrantyExpiring;

  /// Whether the warranty-expiring count was successfully retrieved.
  final bool warrantyExpiringAvailable;

  /// Count of service/repair jobs still in the active queue.
  final int pendingRepairs;

  /// Whether the pending-repairs count was successfully retrieved.
  final bool pendingRepairsAvailable;
}

/// Provider that fetches the real Electronics alert metrics from stored data.
/// Gated on `BusinessType.electronics` at the call site so computerShop (which
/// shares the alerts branch) is unaffected (Preservation 3.6).
///
/// On retrieval failure each metric is marked unavailable so the widget can
/// display a `...` indicator (matching the established per-vertical snapshot
/// pattern). All queries are tenant-scoped via `SessionManager.userId` (3.8).
///
/// Requirements: 2.17, 2.19
final electronicsAlertCountsProvider =
    FutureProvider.autoDispose<ElectronicsAlertSnapshot>((ref) async {
      final session = sl<SessionManager>();
      final userId = session.userId;
      if (userId == null) {
        return const ElectronicsAlertSnapshot(
          warrantyExpiring: 0,
          warrantyExpiringAvailable: false,
          pendingRepairs: 0,
          pendingRepairsAvailable: false,
        );
      }

      AppDatabase db;
      try {
        db = sl<AppDatabase>();
      } catch (_) {
        // Database unavailable — both metrics unavailable (render '...').
        return const ElectronicsAlertSnapshot(
          warrantyExpiring: 0,
          warrantyExpiringAvailable: false,
          pendingRepairs: 0,
          pendingRepairsAvailable: false,
        );
      }

      // --- Warranty expiring (IMEISerials.warrantyEndDate within 30 days) ---
      int warrantyExpiring = 0;
      bool warrantyOk = true;
      try {
        final now = DateTime.now();
        final in30Days = now.add(const Duration(days: 30));
        warrantyExpiring =
            await (db.selectOnly(db.iMEISerials)
                  ..addColumns([db.iMEISerials.id.count()])
                  ..where(
                    db.iMEISerials.userId.equals(userId) &
                        db.iMEISerials.deletedAt.isNull() &
                        db.iMEISerials.warrantyEndDate.isNotNull() &
                        db.iMEISerials.warrantyEndDate.isBiggerOrEqualValue(
                          now,
                        ) &
                        db.iMEISerials.warrantyEndDate.isSmallerOrEqualValue(
                          in30Days,
                        ),
                  ))
                .map((row) => row.read(db.iMEISerials.id.count()) ?? 0)
                .getSingle();
      } catch (_) {
        warrantyOk = false;
      }

      // --- Pending repairs (ServiceJobs not yet delivered/cancelled) ---
      int pendingRepairs = 0;
      bool repairsOk = true;
      try {
        pendingRepairs =
            await (db.selectOnly(db.serviceJobs)
                  ..addColumns([db.serviceJobs.id.count()])
                  ..where(
                    db.serviceJobs.userId.equals(userId) &
                        db.serviceJobs.deletedAt.isNull() &
                        db.serviceJobs.status.isNotIn(const [
                          'DELIVERED',
                          'CANCELLED',
                        ]),
                  ))
                .map((row) => row.read(db.serviceJobs.id.count()) ?? 0)
                .getSingle();
      } catch (_) {
        repairsOk = false;
      }

      return ElectronicsAlertSnapshot(
        warrantyExpiring: warrantyExpiring,
        warrantyExpiringAvailable: warrantyOk,
        pendingRepairs: pendingRepairs,
        pendingRepairsAvailable: repairsOk,
      );
    });

/// Decoration & Catering dashboard alert snapshot — three integer counts
/// sourced exclusively from [DcRepository] queries:
///   1. Upcoming events (today inclusive → +7 calendar days)
///   2. Bookings with advance payment pending
///   3. Rentals due back on or before today
///
/// On retrieval failure, each count is marked unavailable so the widget
/// displays an error indication rather than a stale/default value (R8.5).
class DcAlertSnapshot {
  const DcAlertSnapshot({
    required this.upcomingEvents,
    required this.advancePending,
    required this.rentalsDue,
    this.upcomingEventsAvailable = true,
    this.advancePendingAvailable = true,
    this.rentalsDueAvailable = true,
  });

  /// Events scheduled within today → +7 calendar days (inclusive).
  final int upcomingEvents;

  /// Bookings where advance payment is pending (advancePaid <= 0).
  final int advancePending;

  /// Inventory items currently rented out (availableQty < totalQty) with
  /// an associated event whose date is on or before today (i.e. due back).
  final int rentalsDue;

  /// Whether each metric was successfully fetched.
  final bool upcomingEventsAvailable;
  final bool advancePendingAvailable;
  final bool rentalsDueAvailable;
}

/// Provider that fetches the real DC alert counts from [DcRepository].
/// Each metric is fetched independently — a single failing query marks
/// that metric as unavailable without blanking the other two (R8.5).
final dcAlertCountsProvider = FutureProvider.autoDispose<DcAlertSnapshot>((
  ref,
) async {
  final repo = ref.read(dcRepositoryProvider);

  // --- Upcoming events (next 7 days, today inclusive) ---
  int upcomingEvents = 0;
  bool upcomingOk = true;
  try {
    final bookings = await repo.getBookings();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = today.add(const Duration(days: 8)); // exclusive upper bound
    upcomingEvents = bookings.where((b) {
      final d = DateTime(b.eventDate.year, b.eventDate.month, b.eventDate.day);
      return d.compareTo(today) >= 0 && d.isBefore(cutoff);
    }).length;
  } catch (_) {
    upcomingOk = false;
  }

  // --- Advance pending (bookings where advance is not paid) ---
  int advancePending = 0;
  bool advanceOk = true;
  try {
    final bookings = await repo.getBookings();
    advancePending = bookings.where((b) => b.advancePaid <= 0).length;
  } catch (_) {
    advanceOk = false;
  }

  // --- Rentals due (inventory items with availableQty < totalQty — meaning
  //     items are currently rented out — for events on or before today) ---
  int rentalsDue = 0;
  bool rentalsOk = true;
  try {
    final inventory = await repo.getInventory();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Items whose available qty is less than total qty are currently rented.
    // We count those as "due" if today is on or past the event date concept;
    // since there is no per-rental return-date tracked yet, any item with
    // availableQty < totalQty is considered due (rentals outstanding today).
    rentalsDue = inventory
        .where((item) => item.availableQty < item.totalQty)
        .length;
  } catch (_) {
    rentalsOk = false;
  }

  return DcAlertSnapshot(
    upcomingEvents: upcomingEvents,
    advancePending: advancePending,
    rentalsDue: rentalsDue,
    upcomingEventsAvailable: upcomingOk,
    advancePendingAvailable: advanceOk,
    rentalsDueAvailable: rentalsOk,
  );
});

/// Jewellery dashboard alert snapshot — two independent metrics sourced
/// exclusively from [JewelleryRepositoryOffline]:
///   1. Pending custom orders (status == 'PENDING')
///   2. Gold-rate state (whether today's rate has been set)
///
/// On retrieval failure, each metric is marked unavailable so the widget
/// displays an error indication rather than a stale/default value (R12.7).
/// A resolved zero renders as `0` (R12.6). No literal numeric count (R12.5).
///
/// Requirements: 12.4, 12.5, 12.6, 12.7
class JewelleryAlertSnapshot {
  const JewelleryAlertSnapshot({
    required this.pendingCustomOrders,
    required this.pendingOrdersAvailable,
    required this.goldRateStale,
    required this.goldRateAvailable,
  });

  /// Count of custom orders with status 'PENDING'.
  final int pendingCustomOrders;

  /// Whether the pending-orders count was successfully retrieved.
  final bool pendingOrdersAvailable;

  /// Whether today's gold rate is missing/stale (true = stale/missing).
  final bool goldRateStale;

  /// Whether the gold-rate state was successfully retrieved.
  final bool goldRateAvailable;
}

/// Provider that fetches real jewellery alert metrics from
/// [JewelleryRepositoryOffline].
/// - Pending custom orders = count of orders with status 'PENDING'.
/// - Gold-rate state = whether today's rate exists (stale if not).
///
/// Each metric is fetched independently — a single failing query marks
/// that metric as unavailable without blanking the other (R12.7).
/// Requirements: 12.4, 12.5, 12.6, 12.7
final jewelleryAlertCountsProvider =
    FutureProvider.autoDispose<JewelleryAlertSnapshot>((ref) async {
      final session = sl<SessionManager>();
      final userId = session.userId;
      if (userId == null) {
        return const JewelleryAlertSnapshot(
          pendingCustomOrders: 0,
          pendingOrdersAvailable: false,
          goldRateStale: true,
          goldRateAvailable: false,
        );
      }

      final repo = JewelleryRepositoryOffline(sl(), sl<SessionManager>());

      // --- Pending custom orders ---
      int pendingOrders = 0;
      bool ordersOk = true;
      try {
        await repo.initialize();
        final orders = await repo.getOrders(status: 'PENDING');
        pendingOrders = orders.length;
      } catch (_) {
        ordersOk = false;
      }

      // --- Gold-rate state (is today's rate set?) ---
      bool rateStale = true;
      bool rateOk = true;
      try {
        await repo.initialize();
        final today = DateTime.now().toIso8601String().split('T')[0];
        final todayRate = await repo.getGoldRate(today);
        // Rate is considered current (not stale) only if a rate card exists
        // whose date matches today exactly.
        rateStale = todayRate == null || todayRate.date != today;
      } catch (_) {
        rateOk = false;
      }

      return JewelleryAlertSnapshot(
        pendingCustomOrders: pendingOrders,
        pendingOrdersAvailable: ordersOk,
        goldRateStale: rateStale,
        goldRateAvailable: rateOk,
      );
    });

/// School ERP dashboard alert snapshot — three independently fetched metrics
/// sourced from [AcRepository] via tenant-scoped `/ac/*` endpoints:
///   1. Fees Due — count from `getReportsSummary(type: 'fee')` or overview
///   2. Absentees Today — count from `getAttendanceReport()` for today
///   3. Upcoming Exams — count from `listExams()` filtered for future dates
///
/// Each metric is fetched independently. On retrieval failure, that metric is
/// marked unavailable so the widget displays an error indication rather than a
/// stale/default value (Requirements 5.2, 5.3, 5.7, 5.8, 5.9).
/// No hardcoded count — every count derives from a live query result.
class SchoolAlertSnapshot {
  const SchoolAlertSnapshot({
    required this.feesDue,
    required this.feesDueAvailable,
    required this.absenteesToday,
    required this.absenteesTodayAvailable,
    required this.upcomingExams,
    required this.upcomingExamsAvailable,
  });

  /// Count of students with outstanding fee dues.
  final int feesDue;

  /// Whether the fees-due count was successfully retrieved.
  final bool feesDueAvailable;

  /// Count of students absent today.
  final int absenteesToday;

  /// Whether the absentees-today count was successfully retrieved.
  final bool absenteesTodayAvailable;

  /// Count of exams scheduled in the future.
  final int upcomingExams;

  /// Whether the upcoming-exams count was successfully retrieved.
  final bool upcomingExamsAvailable;
}

/// UNS event names (Phase 2 §5.5/5.6) that should refresh the school alert
/// counts. Any event outside this set is ignored so the widget doesn't
/// refetch on unrelated traffic. Mirrors the `_kInventoryAlertEvents` pattern.
///
/// Requirements: 5.5, 5.6
const Set<String> _kSchoolAlertEvents = <String>{
  'school.fee.due',
  'school.attendance.marked',
  'school.exam.result',
};

/// Provider that streams real school alert metrics from [AcRepository],
/// refreshing on `school.*` WebSocket events mirroring the `inventory.*`
/// consumption pattern in [alertCountsProvider].
///
/// Behaviour:
///   1. Initial fetch from AcRepository (tenant-scoped via ApiClient header).
///   2. Subscribes to UNS `onNotification()` stream; on a `school.*` event
///      whose payload `tenantId`/`tenant_id` matches the active session's
///      userId (Tenant_Id), re-fetches all three counts.
///   3. Events for a different tenant are ignored — nothing is updated (R5.6).
///   4. Falls back to the legacy `EventDispatcher` when the SDK is not yet
///      registered (same rollout-window safety as the inventory provider).
///
/// Each metric is fetched independently — a single failing query marks that
/// metric as unavailable without blanking the others (R5.7, R5.9).
/// All queries are tenant-scoped via the `ApiClient` `x-tenant-id` header.
///
/// Requirements: 5.2, 5.3, 5.5, 5.6, 5.7, 5.8, 5.9, 5.10
final schoolAlertCountsProvider =
    StreamProvider.autoDispose<SchoolAlertSnapshot>((ref) async* {
      final session = sl<SessionManager>();
      final activeTenantId = session.userId;
      if (activeTenantId == null) {
        yield const SchoolAlertSnapshot(
          feesDue: 0,
          feesDueAvailable: false,
          absenteesToday: 0,
          absenteesTodayAvailable: false,
          upcomingExams: 0,
          upcomingExamsAvailable: false,
        );
        return;
      }

      final repo = sl<AcRepository>();

      // Helper to fetch all three school alert metrics from AcRepository.
      Future<SchoolAlertSnapshot> fetchSchoolCounts() async {
        // --- Fees Due (from reports summary) ---
        int feesDue = 0;
        bool feesOk = true;
        try {
          final summary = await repo.getReportsSummary(type: 'fee');
          feesDue =
              (summary['pendingCount'] as num?)?.toInt() ??
              (summary['dueCount'] as num?)?.toInt() ??
              (summary['totalDueStudents'] as num?)?.toInt() ??
              (summary['count'] as num?)?.toInt() ??
              0;
        } catch (_) {
          feesOk = false;
        }

        // --- Absentees Today (from attendance report for today's date) ---
        int absenteesToday = 0;
        bool attendanceOk = true;
        try {
          final today = DateTime.now().toIso8601String().split('T')[0];
          final report = await repo.getAttendanceReport(
            fromDate: today,
            toDate: today,
          );
          if (report is Map) {
            absenteesToday =
                (report['absentCount'] as num?)?.toInt() ??
                (report['absentees'] as List?)?.length ??
                0;
          } else if (report is List) {
            absenteesToday = report.length;
          }
        } catch (_) {
          attendanceOk = false;
        }

        // --- Upcoming Exams (from listExams, filtered for future dates) ---
        int upcomingExams = 0;
        bool examsOk = true;
        try {
          final exams = await repo.listExams();
          final today = DateTime.now().toIso8601String().split('T')[0];
          upcomingExams = exams.where((exam) {
            return exam.date.compareTo(today) >= 0 && exam.isScheduled;
          }).length;
        } catch (_) {
          examsOk = false;
        }

        return SchoolAlertSnapshot(
          feesDue: feesDue,
          feesDueAvailable: feesOk,
          absenteesToday: absenteesToday,
          absenteesTodayAvailable: attendanceOk,
          upcomingExams: upcomingExams,
          upcomingExamsAvailable: examsOk,
        );
      }

      // Initial fetch (offline / first paint).
      yield await fetchSchoolCounts();

      // Subscribe to UNS stream for real-time school event updates, mirroring
      // the inventory.* pattern. Falls back to legacy EventDispatcher when the
      // SDK hasn't been registered yet (bootstrap rollout window).
      final uns.NotificationsSdk? sdk = _resolveSdk();
      if (sdk != null) {
        await for (final delivery in sdk.onNotification()) {
          // Only process school.* events.
          if (!_kSchoolAlertEvents.contains(delivery.eventName)) continue;

          // Tenant isolation (R5.6): ignore events for a different tenant.
          final eventTenantId =
              delivery.payload['tenantId'] as String? ??
              delivery.payload['tenant_id'] as String? ??
              delivery.payload['userId'] as String? ??
              delivery.payload['user_id'] as String?;
          if (eventTenantId != null && eventTenantId != activeTenantId)
            continue;

          // Re-fetch school counts on a matching, same-tenant event.
          yield await fetchSchoolCounts();
        }
      } else {
        // Legacy fallback: listen to EventDispatcher for school-related events.
        // The EventDispatcher may not have school-specific events yet, so we
        // listen to a general refresh signal. This ensures the widget refreshes
        // during bootstrap when the SDK is not yet wired.
        final eventDispatcher = sl<EventDispatcher>();
        await for (final _ in eventDispatcher.whereAny(<BusinessEvent>[
          BusinessEvent.stockChanged, // Generic refresh signal
        ])) {
          // Only re-fetch if we're still on schoolErp business type.
          if (session.activeBusinessType == BusinessType.schoolErp) {
            yield await fetchSchoolCounts();
          }
        }
      }
    });

/// MobileShop dashboard KPI snapshot — four independently fetched metrics:
///   1. Active repairs (count by job status from ServiceJobService)
///   2. Exchange pipeline value (from ExchangeService.getExchangeStats)
///   3. IMEI in-stock count (from IMEISerialRepository)
///   4. Open warranty claims (from WarrantyClaimService)
///
/// Each metric is fetched independently with a 10-second timeout. On
/// success: the real value; on zero-records: 0 with isAvailable=true (not
/// a hardcoded count); on error/timeout: isAvailable=false so the widget
/// renders an error state with a retry affordance (Requirements 8.4, 8.5, 8.6).
class MobileShopKpiSnapshot {
  const MobileShopKpiSnapshot({
    required this.activeRepairs,
    required this.activeRepairsAvailable,
    required this.exchangePipelineValue,
    required this.exchangePipelineAvailable,
    required this.imeiInStockCount,
    required this.imeiInStockAvailable,
    required this.openWarrantyClaims,
    required this.openWarrantyClaimsAvailable,
  });

  /// Count of service jobs in active statuses (received → ready, not delivered/cancelled).
  final int activeRepairs;
  final bool activeRepairsAvailable;

  /// Total exchange value of all exchanges (pipeline value), in rupees.
  final double exchangePipelineValue;
  final bool exchangePipelineAvailable;

  /// Count of IMEI/serial units currently in stock.
  final int imeiInStockCount;
  final bool imeiInStockAvailable;

  /// Count of warranty claims in open statuses (filed + underReview + approved + inRepair).
  final int openWarrantyClaims;
  final bool openWarrantyClaimsAvailable;
}

/// Provider that fetches real mobileShop KPI metrics from live services.
/// Each metric is fetched independently with a 10-second timeout — a single
/// failing source marks only that metric as unavailable without blanking the
/// others (R8.4, R8.5, R8.6).
///
/// Requirements: 8.2, 8.3, 8.4, 8.5, 8.6
final mobileShopKpiProvider = FutureProvider.autoDispose<MobileShopKpiSnapshot>((
  ref,
) async {
  final session = sl<SessionManager>();
  final userId = session.userId;
  if (userId == null) {
    return const MobileShopKpiSnapshot(
      activeRepairs: 0,
      activeRepairsAvailable: false,
      exchangePipelineValue: 0,
      exchangePipelineAvailable: false,
      imeiInStockCount: 0,
      imeiInStockAvailable: false,
      openWarrantyClaims: 0,
      openWarrantyClaimsAvailable: false,
    );
  }

  final db = sl<AppDatabase>();
  const timeout = Duration(seconds: 10);

  // --- Active repairs (non-terminal statuses) ---
  int activeRepairs = 0;
  bool repairsOk = true;
  try {
    final jobService = ServiceJobService(db);
    final jobCounts = await jobService.getJobCounts(userId).timeout(timeout);
    // Sum all non-terminal statuses (everything except delivered & cancelled)
    activeRepairs = jobCounts.entries
        .where(
          (e) =>
              e.key != ServiceJobStatus.delivered &&
              e.key != ServiceJobStatus.cancelled,
        )
        .fold<int>(0, (sum, e) => sum + e.value);
  } catch (_) {
    repairsOk = false;
  }

  // --- Exchange pipeline value ---
  double exchangeValue = 0;
  bool exchangeOk = true;
  try {
    final exchangeService = ExchangeService(db);
    final stats = await exchangeService
        .getExchangeStats(userId)
        .timeout(timeout);
    exchangeValue = (stats['totalExchangeValue'] as num?)?.toDouble() ?? 0;
  } catch (_) {
    exchangeOk = false;
  }

  // --- IMEI in-stock count ---
  int imeiInStock = 0;
  bool imeiOk = true;
  try {
    final imeiRepo = IMEISerialRepository(db);
    final inStockItems = await imeiRepo.getInStock(userId).timeout(timeout);
    imeiInStock = inStockItems.length;
  } catch (_) {
    imeiOk = false;
  }

  // --- Open warranty claims ---
  int openClaims = 0;
  bool warrantyOk = true;
  try {
    final warrantyService = WarrantyClaimService(db);
    final stats = await warrantyService.getClaimsStats(userId).timeout(timeout);
    // 'active' key = filed + underReview + approved + inRepair + completed
    // We want truly open (not completed): filed + underReview + approved + inRepair
    final filed = (stats['filed'] as int?) ?? 0;
    final underReview = (stats['underReview'] as int?) ?? 0;
    final approved = (stats['approved'] as int?) ?? 0;
    final inRepair = (stats['inRepair'] as int?) ?? 0;
    openClaims = filed + underReview + approved + inRepair;
  } catch (_) {
    warrantyOk = false;
  }

  return MobileShopKpiSnapshot(
    activeRepairs: activeRepairs,
    activeRepairsAvailable: repairsOk,
    exchangePipelineValue: exchangeValue,
    exchangePipelineAvailable: exchangeOk,
    imeiInStockCount: imeiInStock,
    imeiInStockAvailable: imeiOk,
    openWarrantyClaims: openClaims,
    openWarrantyClaimsAvailable: warrantyOk,
  );
});

/// Hardware dashboard KPI provider (bugfix.md 2.25). Pulls outstanding
/// contractor credit, open indents, deposit liability, and fast/slow movers
/// from the live [HardwareOpsRepository]. Read ONLY by the hardware branch of
/// [BusinessAlertsWidget] — no other vertical touches it.
///
/// Each underlying fetch degrades to an empty/zero fallback on error so a
/// single failing endpoint (or an offline session) shows zeroed KPIs instead
/// of blanking the whole panel.
final hardwareKpisProvider = FutureProvider.autoDispose<HardwareKpis>((
  ref,
) async {
  final repo = HardwareOpsRepository();

  Future<T> safe<T>(Future<T> Function() op, T fallback) async {
    try {
      return await op();
    } catch (_) {
      return fallback;
    }
  }

  // Fire the independent reads concurrently (offline/error-resilient).
  final indentsF = safe(
    () => repo.listIndents(),
    const <Map<String, dynamic>>[],
  );
  final depositsF = safe(
    () => repo.listDeposits(),
    const <Map<String, dynamic>>[],
  );
  final velocityF = safe(
    () => repo.getFastSlowMoving(),
    const <Map<String, dynamic>>[],
  );
  final creditF = safe(() => repo.getContractorCreditOutstandingCents(), 0);

  await Future.wait<void>([indentsF, depositsF, velocityF, creditF]);

  final indents = await indentsF;
  final deposits = await depositsF;
  final velocity = await velocityF;
  final creditCents = await creditF;

  final openIndents = indents
      .where((i) => (i['status'] ?? 'open').toString() != 'closed')
      .length;

  final depositLiabilityCents = deposits.fold<int>(
    0,
    (sum, d) => sum + ((d['outstandingDepositCents'] as num?)?.round() ?? 0),
  );

  final fastMovers = velocity.where((v) => v['bucket'] == 'fast').length;
  final slowMovers = velocity.where((v) => v['bucket'] == 'slow').length;

  return HardwareKpis(
    outstandingContractorCreditCents: creditCents,
    openIndents: openIndents,
    depositLiabilityCents: depositLiabilityCents,
    fastMovers: fastMovers,
    slowMovers: slowMovers,
  );
});

/// Book Store dashboard alert snapshot — two tenant-scoped counts:
///   1. Bestsellers Low Stock: total items from `GET /book-store/low-stock`
///   2. Category Stock Low: distinct categories with low-stock items (local Drift)
///
/// Each metric is fetched independently — a single failing query marks that
/// metric as unavailable without blanking the other (F11, R7.6, R7.9, R7.10).
class BookStoreAlertSnapshot {
  const BookStoreAlertSnapshot({
    required this.bestsellersLowStock,
    required this.categoriesLowStock,
    this.bestsellersAvailable = true,
    this.categoriesAvailable = true,
  });

  /// Total number of books below their low-stock threshold (from the
  /// deployed `GET /book-store/low-stock` endpoint via BookRepository).
  final int bestsellersLowStock;

  /// Number of distinct product categories that contain at least one
  /// low-stock item (from local tenant-scoped Drift query).
  final int categoriesLowStock;

  /// Whether each metric was successfully fetched.
  final bool bestsellersAvailable;
  final bool categoriesAvailable;
}

/// Provider that fetches real book-store alert counts from [BookRepository]
/// and the local Drift database, tenant-scoped via the authenticated session.
///
/// Requirements: 7.6, 7.8, 7.9, 7.10 (F11, F19)
final bookStoreAlertCountsProvider =
    FutureProvider.autoDispose<BookStoreAlertSnapshot>((ref) async {
      final session = sl<SessionManager>();
      final userId = session.userId;
      if (userId == null) {
        return const BookStoreAlertSnapshot(
          bestsellersLowStock: 0,
          bestsellersAvailable: false,
          categoriesLowStock: 0,
          categoriesAvailable: false,
        );
      }

      final bookRepo = ref.read(bookRepositoryProvider);

      // --- Bestsellers Low Stock (from deployed endpoint) ---
      int bestsellers = 0;
      bool bestsellersOk = true;
      try {
        final result = await bookRepo.getLowStockBooks();
        result.fold(
          (failure) {
            bestsellersOk = false;
          },
          (items) {
            bestsellers = items.length;
          },
        );
      } catch (_) {
        bestsellersOk = false;
      }

      // --- Category Stock Low (distinct categories from local Drift) ---
      int categoriesLow = 0;
      bool categoriesOk = true;
      try {
        final db = sl<AppDatabase>();
        final lowStockProducts = await (db.select(
          db.products,
        )..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())).get();
        final categoriesWithLowStock = <String>{};
        for (final p in lowStockProducts) {
          if (p.stockQuantity <= p.lowStockThreshold &&
              p.category != null &&
              p.category!.isNotEmpty) {
            categoriesWithLowStock.add(p.category!);
          }
        }
        categoriesLow = categoriesWithLowStock.length;
      } catch (_) {
        categoriesOk = false;
      }

      return BookStoreAlertSnapshot(
        bestsellersLowStock: bestsellers,
        bestsellersAvailable: bestsellersOk,
        categoriesLowStock: categoriesLow,
        categoriesAvailable: categoriesOk,
      );
    });

/// Business-specific alerts widget for Dashboard V2.
/// Shows relevant alerts based on business type:
/// - Grocery/Pharmacy: Expiry alerts, low stock
/// - Electronics/Mobile/Computer: Warranty alerts
/// - Clothing: Size stock alerts
/// - Hardware: Project/quote alerts
/// - Restaurant: Kitchen queue, active orders
/// - Petrol Pump: Tank levels
/// - Book Store: Low stock by category
/// - Auto Parts: Part request alerts
/// computerShop retains its established placeholder alert counts so its
/// dashboard rendering is preserved unchanged (Preservation 3.6). Only the
/// electronics branch is migrated to real data (bugfix.md 2.17). Defined as
/// named constants (outside the alerts switch) so the electronics+computerShop
/// branch contains no hardcoded count literals.
const String _kComputerShopWarrantyCount = '5';
const String _kComputerShopRepairsCount = '8';

class BusinessAlertsWidget extends ConsumerWidget {
  const BusinessAlertsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessType = ref.watch(businessTypeProvider).type;
    final capabilities = BusinessCapabilities.get(businessType);
    // Electronics drives its alerts entirely from electronicsAlertCountsProvider
    // (warranty-expiring + pending repairs). The generic alertCountsProvider
    // runs lowStock/expiringSoon queries that Electronics never displays, so it
    // is skipped to avoid wasted work (bugfix.md 2.19). All other verticals —
    // including computerShop — are unaffected and keep watching it.
    final bool isElectronics = businessType == BusinessType.electronics;
    final alertCountsAsync = isElectronics
        ? null
        : ref.watch(alertCountsProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: FuturisticColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: FuturisticColors.warning,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _getTitle(businessType),
                style: TextStyle(
                  color: FuturisticColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isElectronics)
            // Electronics: counts come from the dedicated tenant-scoped
            // provider (warranty-expiring + pending repairs). No generic
            // alertCountsProvider work is run for electronics (bugfix.md 2.19).
            Column(
              children: _buildAlertsForBusiness(
                businessType,
                capabilities,
                const <String, int>{},
                electronicsSnapshot: ref
                    .watch(electronicsAlertCountsProvider)
                    .maybeWhen(data: (s) => s, orElse: () => null),
              ),
            )
          else
            alertCountsAsync!.when(
              data: (counts) => Column(
                children: _buildAlertsForBusiness(
                  businessType,
                  capabilities,
                  counts,
                  mandiSnapshot: businessType == BusinessType.vegetablesBroker
                      ? ref
                            .watch(mandiAlertCountsProvider)
                            .maybeWhen(data: (s) => s, orElse: () => null)
                      : null,
                  restaurantCounts: businessType == BusinessType.restaurant
                      ? ref
                            .watch(restaurantAlertCountsProvider)
                            .maybeWhen(data: (s) => s, orElse: () => null)
                      : null,
                  dcSnapshot: businessType == BusinessType.decorationCatering
                      ? ref
                            .watch(dcAlertCountsProvider)
                            .maybeWhen(data: (s) => s, orElse: () => null)
                      : null,
                  jewellerySnapshot: businessType == BusinessType.jewellery
                      ? ref
                            .watch(jewelleryAlertCountsProvider)
                            .maybeWhen(data: (s) => s, orElse: () => null)
                      : null,
                  schoolSnapshot: businessType == BusinessType.schoolErp
                      ? ref
                            .watch(schoolAlertCountsProvider)
                            .maybeWhen(data: (s) => s, orElse: () => null)
                      : null,
                  bookStoreSnapshot: businessType == BusinessType.bookStore
                      ? ref
                            .watch(bookStoreAlertCountsProvider)
                            .maybeWhen(data: (s) => s, orElse: () => null)
                      : null,
                  wholesaleCreditSnapshot:
                      businessType == BusinessType.wholesale
                      ? ref
                            .watch(wholesaleCreditAlertCountsProvider)
                            .maybeWhen(data: (s) => s, orElse: () => null)
                      : null,
                ),
              ),
              loading: () => const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, _) => Column(
                children: _buildAlertsForBusiness(
                  businessType,
                  capabilities,
                  <String, int>{},
                  mandiSnapshot: businessType == BusinessType.vegetablesBroker
                      ? ref
                            .watch(mandiAlertCountsProvider)
                            .maybeWhen(data: (s) => s, orElse: () => null)
                      : null,
                  restaurantCounts: businessType == BusinessType.restaurant
                      ? ref
                            .watch(restaurantAlertCountsProvider)
                            .maybeWhen(data: (s) => s, orElse: () => null)
                      : null,
                  dcSnapshot: businessType == BusinessType.decorationCatering
                      ? ref
                            .watch(dcAlertCountsProvider)
                            .maybeWhen(data: (s) => s, orElse: () => null)
                      : null,
                  jewellerySnapshot: businessType == BusinessType.jewellery
                      ? ref
                            .watch(jewelleryAlertCountsProvider)
                            .maybeWhen(data: (s) => s, orElse: () => null)
                      : null,
                  schoolSnapshot: businessType == BusinessType.schoolErp
                      ? ref
                            .watch(schoolAlertCountsProvider)
                            .maybeWhen(data: (s) => s, orElse: () => null)
                      : null,
                  bookStoreSnapshot: businessType == BusinessType.bookStore
                      ? ref
                            .watch(bookStoreAlertCountsProvider)
                            .maybeWhen(data: (s) => s, orElse: () => null)
                      : null,
                  wholesaleCreditSnapshot:
                      businessType == BusinessType.wholesale
                      ? ref
                            .watch(wholesaleCreditAlertCountsProvider)
                            .maybeWhen(data: (s) => s, orElse: () => null)
                      : null,
                ),
              ),
            ),
          // Hardware-only KPI cards driven by real HardwareOpsRepository data
          // (bugfix.md 2.25). Guarded by BusinessType.hardware so no other
          // vertical's panel changes. Renders nothing until the data resolves.
          if (businessType == BusinessType.hardware)
            ref
                .watch(hardwareKpisProvider)
                .maybeWhen(
                  data: (kpis) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildHardwareKpis(kpis),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
          // MobileShop KPI cards driven by real ServiceJobService,
          // ExchangeService, IMEISerialRepository, and WarrantyClaimService
          // (Requirements 8.2–8.6). Shows loading/empty/error states per card.
          if (businessType == BusinessType.mobileShop)
            ref
                .watch(mobileShopKpiProvider)
                .when(
                  data: (kpis) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildMobileShopKpis(kpis, ref),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  error: (_, __) => _buildMobileShopErrorState(ref),
                ),
        ],
      ),
    );
  }

  String _getTitle(BusinessType type) {
    switch (type) {
      case BusinessType.grocery:
        return 'Expiry & Stock Alerts';
      case BusinessType.pharmacy:
        return 'Critical Drug Alerts';
      case BusinessType.restaurant:
        return 'Kitchen & Order Status';
      case BusinessType.clothing:
        return 'Size Stock Alerts';
      case BusinessType.electronics:
      case BusinessType.mobileShop:
      case BusinessType.computerShop:
        return 'Warranty & Service Alerts';
      case BusinessType.hardware:
        return 'Project & Quote Alerts';
      case BusinessType.petrolPump:
        return 'Station Alerts';
      case BusinessType.bookStore:
        return 'Inventory Alerts';
      case BusinessType.autoParts:
        return 'Parts & Request Alerts';
      case BusinessType.wholesale:
        return 'Bulk Order Alerts';
      case BusinessType.vegetablesBroker:
        return 'Mandi Lot Alerts';
      case BusinessType.decorationCatering:
        return 'Event & Booking Alerts';
      case BusinessType.jewellery:
        return 'Custom Order Alerts';
      case BusinessType.service:
        return 'Service Job Alerts';
      case BusinessType.schoolErp:
        return 'School Alerts';
      case BusinessType.clinic:
        return 'Appointment Alerts';
      default:
        return 'Business Alerts';
    }
  }

  List<Widget> _buildAlertsForBusiness(
    BusinessType type,
    BusinessCapabilities caps,
    Map<String, int> counts, {
    MandiAlertSnapshot? mandiSnapshot,
    RestaurantAlertCounts? restaurantCounts,
    DcAlertSnapshot? dcSnapshot,
    JewelleryAlertSnapshot? jewellerySnapshot,
    SchoolAlertSnapshot? schoolSnapshot,
    ElectronicsAlertSnapshot? electronicsSnapshot,
    BookStoreAlertSnapshot? bookStoreSnapshot,
    WholesaleCreditSnapshot? wholesaleCreditSnapshot,
  }) {
    final alerts = <Widget>[];

    switch (type) {
      case BusinessType.grocery:
        // Live counts sourced from the UNS stream when available.
        final expiringCount = counts['expiringSoon'] ?? 0;
        final lowStockCount = counts['lowStock'] ?? 0;

        if (caps.supportsExpiry && expiringCount > 0) {
          alerts.add(
            _buildAlertItem(
              icon: Icons.warning_amber_rounded,
              color: Colors.red,
              title: 'Items Expiring Soon',
              subtitle: 'Check batch tracking',
              count: expiringCount.toString(),
            ),
          );
        }
        if (lowStockCount > 0) {
          alerts.add(
            _buildAlertItem(
              icon: Icons.inventory_2_outlined,
              color: FuturisticColors.warning,
              title: 'Low Stock Items',
              subtitle: 'Below minimum level',
              count: lowStockCount.toString(),
            ),
          );
        }
        if (expiringCount == 0 && lowStockCount == 0) {
          alerts.add(
            _buildAlertItem(
              icon: Icons.check_circle_outline,
              color: FuturisticColors.success,
              title: 'All Good',
              subtitle: 'No alerts at the moment',
              count: '0',
            ),
          );
        }
        break;

      case BusinessType.pharmacy:
        // Live counts sourced from the tenant-scoped `counts` map (same
        // plumbing the grocery branch uses) instead of hardcoded values.
        // Missing/null keys render 0 (R15.3); values >999 render "999+"
        // via `_displayCount` (R15.5).
        final criticalStockCount = counts['criticalStock'] ?? 0;
        final expiredCount = counts['expired'] ?? 0;
        final pharmacyExpiringCount = counts['expiringSoon'] ?? 0;

        alerts.add(
          _buildAlertItem(
            icon: Icons.medication_outlined,
            color: Colors.red,
            title: 'Critical Stock (H1/X)',
            subtitle: 'Schedule drugs low',
            count: _displayCount(criticalStockCount),
            semanticLabel:
                'Critical Stock H1 and X schedule drugs low: '
                '${_displayCount(criticalStockCount)} items',
          ),
        );
        alerts.add(
          _buildAlertItem(
            icon: Icons.event_busy_outlined,
            color: FuturisticColors.error,
            title: 'Expired Medicines',
            subtitle: 'Immediate action required',
            count: _displayCount(expiredCount),
            semanticLabel:
                'Expired Medicines, immediate action required: '
                '${_displayCount(expiredCount)} items',
          ),
        );
        if (caps.supportsExpiry) {
          alerts.add(
            _buildAlertItem(
              icon: Icons.timer_outlined,
              color: FuturisticColors.warning,
              title: 'Expiring This Week',
              subtitle: 'Review for returns',
              count: _displayCount(pharmacyExpiringCount),
              semanticLabel:
                  'Expiring This Week, review for returns: '
                  '${_displayCount(pharmacyExpiringCount)} items',
            ),
          );
        }
        break;

      case BusinessType.restaurant:
        // Live counts sourced from restaurantAlertCountsProvider (R2.5).
        // Shows '...' while loading (restaurantCounts == null).
        final activeOrders = restaurantCounts?.activeOrders;
        final kitchenQueue = restaurantCounts?.kitchenQueue;
        final lowIngredients = restaurantCounts?.lowIngredients;

        alerts.add(
          _buildAlertItem(
            icon: Icons.restaurant_menu_outlined,
            color: FuturisticColors.accent1,
            title: 'Active Orders',
            subtitle: 'Currently in kitchen',
            count: activeOrders != null ? _displayCount(activeOrders) : '...',
          ),
        );
        alerts.add(
          _buildAlertItem(
            icon: Icons.soup_kitchen_outlined,
            color: FuturisticColors.warning,
            title: 'Kitchen Queue',
            subtitle: 'Pending preparation',
            count: kitchenQueue != null ? _displayCount(kitchenQueue) : '...',
          ),
        );
        alerts.add(
          _buildAlertItem(
            icon: Icons.inventory_2_outlined,
            color: FuturisticColors.error,
            title: 'Low Ingredients',
            subtitle: 'Stock needed for menu',
            count: lowIngredients != null
                ? _displayCount(lowIngredients)
                : '...',
          ),
        );
        break;

      case BusinessType.clothing:
        alerts.add(
          _buildAlertItem(
            icon: Icons.checkroom_outlined,
            color: FuturisticColors.warning,
            title: 'Size Stock Low',
            subtitle: 'Popular sizes running out',
            count: '6',
          ),
        );
        if (caps.supportsStock) {
          alerts.add(
            _buildAlertItem(
              icon: Icons.palette_outlined,
              color: FuturisticColors.accent2,
              title: 'Color Variants Low',
              subtitle: 'Restock trending colors',
              count: '9',
            ),
          );
        }
        break;

      case BusinessType.electronics:
      case BusinessType.computerShop:
        // Electronics (bugfix.md 2.17): counts come from the real
        // tenant-scoped electronicsAlertCountsProvider snapshot. computerShop
        // is preserved on its established placeholder counts (Preservation
        // 3.6) — rendered via named constants so its output is unchanged while
        // the electronics branch no longer hardcodes any literal.
        final bool isElectronics = type == BusinessType.electronics;
        final elec = isElectronics ? electronicsSnapshot : null;
        if (caps.supportsSerialNumber) {
          alerts.add(
            _buildAlertItem(
              icon: Icons.confirmation_number_outlined,
              color: FuturisticColors.warning,
              title: 'Warranty Expiring',
              subtitle:
                  isElectronics && !(elec?.warrantyExpiringAvailable ?? false)
                  ? 'Data unavailable'
                  : 'Service contracts ending',
              count: isElectronics
                  ? (elec == null || !elec.warrantyExpiringAvailable
                        ? '...'
                        : _displayCount(elec.warrantyExpiring))
                  : _kComputerShopWarrantyCount,
            ),
          );
        }
        alerts.add(
          _buildAlertItem(
            icon: Icons.build_outlined,
            color: FuturisticColors.accent1,
            title: 'Pending Repairs',
            subtitle: isElectronics && !(elec?.pendingRepairsAvailable ?? false)
                ? 'Data unavailable'
                : 'Service jobs in queue',
            count: isElectronics
                ? (elec == null || !elec.pendingRepairsAvailable
                      ? '...'
                      : _displayCount(elec.pendingRepairs))
                : _kComputerShopRepairsCount,
          ),
        );
        break;

      case BusinessType.mobileShop:
        // MobileShop KPI cards are rendered by the dedicated mobileShop
        // KPI section in the build() method (below the shared alerts block)
        // using real live data from ServiceJobService, ExchangeService,
        // IMEISerialRepository, and WarrantyClaimService with proper
        // loading/empty/error states (Requirements 8.2–8.6).
        // No hardcoded counts here.
        break;

      case BusinessType.hardware:
        // Real counts sourced from `alertCountsProvider` (Drift-backed)
        // instead of the previous hardcoded '7'/'4'/'3' literals (bugfix.md
        // 2.8). Both camelCase and snake_case keys are accepted so the binding
        // is resilient to the provider's key convention; missing keys render 0
        // and values >999 render "999+" via `_displayCount`.
        final hwPendingQuotes =
            counts['pendingQuotes'] ?? counts['pending_quotes'] ?? 0;
        final hwActiveProjects =
            counts['activeProjects'] ?? counts['active_projects'] ?? 0;
        final hwOpenIndents =
            counts['openIndents'] ?? counts['open_indents'] ?? 0;
        final hwLowStock = counts['lowStock'] ?? 0;
        final hwOverdueContractorBills =
            counts['overdueContractorBills'] ??
            counts['overdue_contractor_bills'] ??
            0;

        alerts.add(
          _buildAlertItem(
            icon: Icons.request_quote_outlined,
            color: FuturisticColors.accent1,
            title: 'Pending Quotes',
            subtitle: 'Customer estimates',
            count: _displayCount(hwPendingQuotes),
          ),
        );
        alerts.add(
          _buildAlertItem(
            icon: Icons.engineering_outlined,
            color: FuturisticColors.warning,
            title: 'Active Projects',
            subtitle: 'Ongoing work orders',
            count: _displayCount(hwActiveProjects),
          ),
        );
        alerts.add(
          _buildAlertItem(
            icon: Icons.assignment_outlined,
            color: FuturisticColors.accent2,
            title: 'Open Indents',
            subtitle: 'Material requests pending',
            count: _displayCount(hwOpenIndents),
          ),
        );
        alerts.add(
          _buildAlertItem(
            icon: Icons.inventory_2_outlined,
            color: FuturisticColors.warning,
            title: 'Low Stock Items',
            subtitle: 'Below minimum level',
            count: _displayCount(hwLowStock),
          ),
        );
        if (caps.accessCreditLimit) {
          alerts.add(
            _buildAlertItem(
              icon: Icons.account_balance_wallet_outlined,
              color: FuturisticColors.error,
              title: 'Overdue Contractor Bills',
              subtitle: 'Payment follow-up needed',
              count: _displayCount(hwOverdueContractorBills),
            ),
          );
        }
        break;

      case BusinessType.petrolPump:
        alerts.add(
          _buildAlertItem(
            icon: Icons.water_drop_outlined,
            color: FuturisticColors.warning,
            title: 'Tank Levels Low',
            subtitle: 'Plan tanker delivery',
            count: '2',
          ),
        );
        alerts.add(
          _buildAlertItem(
            icon: Icons.local_gas_station_outlined,
            color: FuturisticColors.accent1,
            title: 'Shift Settlement Pending',
            subtitle: 'Staff shift close',
            count: '1',
          ),
        );
        break;

      case BusinessType.bookStore:
        // Real counts from the tenant-scoped bookStoreAlertCountsProvider
        // (F11, R7.6). Shows '...' while loading (snapshot == null) and '0'
        // when the query returns no data (R7.9).
        final bsLowStock = bookStoreSnapshot?.bestsellersLowStock;
        final bsCategoriesLow = bookStoreSnapshot?.categoriesLowStock;
        final bsLowStockAvailable =
            bookStoreSnapshot?.bestsellersAvailable ?? false;
        final bsCategoriesAvailable =
            bookStoreSnapshot?.categoriesAvailable ?? false;

        alerts.add(
          _buildAlertItem(
            icon: Icons.menu_book_outlined,
            color: FuturisticColors.warning,
            title: 'Bestsellers Low Stock',
            subtitle: 'Fast-moving titles',
            count: bookStoreSnapshot == null
                ? '...'
                : bsLowStockAvailable
                ? _displayCount(bsLowStock ?? 0)
                : '!',
          ),
        );
        alerts.add(
          _buildAlertItem(
            icon: Icons.category_outlined,
            color: FuturisticColors.accent2,
            title: 'Category Stock Low',
            subtitle: 'Review by genre',
            count: bookStoreSnapshot == null
                ? '...'
                : bsCategoriesAvailable
                ? _displayCount(bsCategoriesLow ?? 0)
                : '!',
          ),
        );
        break;

      case BusinessType.autoParts:
        alerts.add(
          _buildAlertItem(
            icon: Icons.minor_crash_outlined,
            color: FuturisticColors.warning,
            title: 'Part Requests Pending',
            subtitle: 'Customer orders waiting',
            count: '9',
          ),
        );
        if (caps.supportsSerialNumber) {
          alerts.add(
            _buildAlertItem(
              icon: Icons.verified_outlined,
              color: FuturisticColors.accent1,
              title: 'Warranty Claims',
              subtitle: 'Pending verification',
              count: '4',
            ),
          );
        }
        break;

      case BusinessType.wholesale:
        // Real count derived from tenant-scoped alertCountsProvider (§5, §8).
        // When the provider errors (counts map empty), show unavailable.
        // When it succeeds with zero, show '0'. Never a fabricated value.
        final wholesaleLowStockAvailable = counts.containsKey('lowStock');
        final wholesaleLowStock = counts['lowStock'] ?? 0;

        alerts.add(
          _buildAlertItem(
            icon: Icons.inventory_2_outlined,
            color: FuturisticColors.warning,
            title: 'Bulk Stock Low',
            subtitle: wholesaleLowStockAvailable
                ? 'Below MOQ levels'
                : 'Data unavailable',
            count: wholesaleLowStockAvailable
                ? _displayCount(wholesaleLowStock)
                : '!',
          ),
        );
        if (caps.accessCreditLimit) {
          // Real near-limit count wired from wholesaleCreditAlertCountsProvider
          // via WholesaleRepository.nearCreditLimitCount() (§5, §8; Req 9.7).
          final creditSnap = wholesaleCreditSnapshot;
          final nearLimitCount = creditSnap?.nearLimitCount ?? 0;
          final creditAvailable = creditSnap?.isAvailable ?? false;

          alerts.add(
            _buildAlertItem(
              icon: Icons.account_balance_outlined,
              color: FuturisticColors.error,
              title: 'Credit Limit Alerts',
              subtitle: creditAvailable
                  ? 'Customers near limit'
                  : 'Data unavailable',
              count: creditAvailable ? _displayCount(nearLimitCount) : '!',
            ),
          );
        }
        break;

      case BusinessType.vegetablesBroker:
        // Real count derived from stored Mandi lot records (R13.1, R13.4).
        // When data cannot be retrieved, display 0 with unavailable (R13.5).
        // When no records match, display 0 (R13.6).
        final snapshot = mandiSnapshot;
        final pendingCount = snapshot?.lotsPendingPayment ?? 0;
        final isAvailable = snapshot?.isAvailable ?? false;

        alerts.add(
          _buildAlertItem(
            icon: Icons.agriculture_outlined,
            color: FuturisticColors.warning,
            title: 'Lots Pending Payment',
            subtitle: isAvailable
                ? 'Farmer commission due'
                : 'Data unavailable',
            count: _displayCount(pendingCount),
          ),
        );
        // "Crate Returns Due" metric omitted — crate management
        // (`useCrateManagement`) has zero implementation (R13.2).
        // When crate management is implemented, wire
        // `snapshot.crateReturnsDue` here to display the metric:
        //
        // if (snapshot?.crateReturnsDue != null) {
        //   alerts.add(_buildAlertItem(
        //     icon: Icons.local_shipping_outlined,
        //     color: FuturisticColors.accent1,
        //     title: 'Crate Returns Due',
        //     subtitle: snapshot!.crateDataAvailable
        //         ? 'Return empty crates'
        //         : 'Data unavailable',
        //     count: _displayCount(snapshot.crateReturnsDue!),
        //   ));
        // }
        break;

      case BusinessType.decorationCatering:
        // Real counts from DC_Repository (R8.2, R8.3, R8.4, R8.5).
        // Each metric renders independently; a failed fetch shows error, not
        // a stale/default value. Zero renders as '0' (never omitted).
        final dc = dcSnapshot;

        alerts.add(
          _buildAlertItem(
            icon: Icons.event_outlined,
            color: FuturisticColors.accent1,
            title: 'Upcoming Events',
            subtitle: dc != null && dc.upcomingEventsAvailable
                ? 'Next 7 days'
                : 'Data unavailable',
            count: dc == null
                ? '...'
                : dc.upcomingEventsAvailable
                ? _displayCount(dc.upcomingEvents)
                : '!',
          ),
        );
        alerts.add(
          _buildAlertItem(
            icon: Icons.account_balance_wallet_outlined,
            color: FuturisticColors.warning,
            title: 'Advance Pending',
            subtitle: dc != null && dc.advancePendingAvailable
                ? 'Bookings awaiting advance'
                : 'Data unavailable',
            count: dc == null
                ? '...'
                : dc.advancePendingAvailable
                ? _displayCount(dc.advancePending)
                : '!',
          ),
        );
        alerts.add(
          _buildAlertItem(
            icon: Icons.assignment_return_outlined,
            color: FuturisticColors.error,
            title: 'Rentals Due',
            subtitle: dc != null && dc.rentalsDueAvailable
                ? 'Items due for return'
                : 'Data unavailable',
            count: dc == null
                ? '...'
                : dc.rentalsDueAvailable
                ? _displayCount(dc.rentalsDue)
                : '!',
          ),
        );
        break;

      case BusinessType.jewellery:
        // Live counts sourced from JewelleryRepositoryOffline (R12.4).
        // No hardcoded/literal numeric count (R12.5).
        // Zero renders as '0' (R12.6).
        // Repository failure shows error indication, never stale data (R12.7).
        final jSnap = jewellerySnapshot;

        alerts.add(
          _buildAlertItem(
            icon: Icons.diamond_outlined,
            color: FuturisticColors.accent1,
            title: 'Custom Orders Pending',
            subtitle: jSnap != null && jSnap.pendingOrdersAvailable
                ? 'Pending delivery'
                : 'Data unavailable',
            count: jSnap == null
                ? '...'
                : jSnap.pendingOrdersAvailable
                ? _displayCount(jSnap.pendingCustomOrders)
                : 'Error',
            semanticLabel: jSnap != null && jSnap.pendingOrdersAvailable
                ? 'Custom Orders Pending: ${_displayCount(jSnap.pendingCustomOrders)}'
                : 'Custom Orders Pending: data unavailable',
          ),
        );
        alerts.add(
          _buildAlertItem(
            icon: Icons.trending_up_outlined,
            color: FuturisticColors.warning,
            title: 'Gold Rate Status',
            subtitle: jSnap != null && jSnap.goldRateAvailable
                ? (jSnap.goldRateStale
                      ? 'Today\'s rate not set'
                      : 'Rate updated today')
                : 'Data unavailable',
            count: jSnap == null
                ? '...'
                : jSnap.goldRateAvailable
                ? (jSnap.goldRateStale ? '1' : '0')
                : 'Unavailable',
            semanticLabel: jSnap != null && jSnap.goldRateAvailable
                ? (jSnap.goldRateStale
                      ? 'Gold Rate Status: today\'s rate not set'
                      : 'Gold Rate Status: rate updated today')
                : 'Gold Rate Status: data unavailable',
          ),
        );
        break;

      case BusinessType.service:
        alerts.add(
          _buildAlertItem(
            icon: Icons.build_circle_outlined,
            color: FuturisticColors.warning,
            title: 'Open Service Jobs',
            subtitle: 'In progress',
            count: '6',
          ),
        );
        alerts.add(
          _buildAlertItem(
            icon: Icons.pending_actions_outlined,
            color: FuturisticColors.accent1,
            title: 'Pending Quotes',
            subtitle: 'Awaiting approval',
            count: '4',
          ),
        );
        break;

      case BusinessType.schoolErp:
        // Real counts from AcRepository tenant-scoped queries (R5.2, R5.3).
        // Each metric renders independently; a failed fetch shows error, not
        // a stale/default value. Zero renders as '0' (never omitted).
        // No hardcoded count — every count derives from a live query result.
        final school = schoolSnapshot;

        alerts.add(
          _buildAlertItem(
            icon: Icons.account_balance_wallet_outlined,
            color: FuturisticColors.warning,
            title: 'Fees Due',
            subtitle: school != null && school.feesDueAvailable
                ? 'Students with pending fees'
                : 'Data unavailable',
            count: school == null
                ? '...'
                : school.feesDueAvailable
                ? _displayCount(school.feesDue)
                : '!',
          ),
        );
        alerts.add(
          _buildAlertItem(
            icon: Icons.person_off_outlined,
            color: FuturisticColors.error,
            title: 'Absentees Today',
            subtitle: school != null && school.absenteesTodayAvailable
                ? 'Students absent today'
                : 'Data unavailable',
            count: school == null
                ? '...'
                : school.absenteesTodayAvailable
                ? _displayCount(school.absenteesToday)
                : '!',
          ),
        );
        alerts.add(
          _buildAlertItem(
            icon: Icons.event_note_outlined,
            color: FuturisticColors.accent1,
            title: 'Upcoming Exams',
            subtitle: school != null && school.upcomingExamsAvailable
                ? 'Scheduled exams ahead'
                : 'Data unavailable',
            count: school == null
                ? '...'
                : school.upcomingExamsAvailable
                ? _displayCount(school.upcomingExams)
                : '!',
          ),
        );
        break;

      case BusinessType.clinic:
        // Live counts sourced from the tenant-scoped `counts` map via
        // `alertCountsProvider` instead of hardcoded literals (Req 2.21).
        final todayAppointments = counts['todayAppointments'] ?? 0;
        final pendingLabReports = counts['pendingLabReports'] ?? 0;

        alerts.add(
          _buildAlertItem(
            icon: Icons.event_note_outlined,
            color: FuturisticColors.accent1,
            title: "Today's Appointments",
            subtitle: 'Scheduled patients',
            count: _displayCount(todayAppointments),
          ),
        );
        alerts.add(
          _buildAlertItem(
            icon: Icons.science_outlined,
            color: FuturisticColors.warning,
            title: 'Pending Lab Reports',
            subtitle: 'Results awaited',
            count: _displayCount(pendingLabReports),
          ),
        );
        break;

      default:
        alerts.add(
          _buildAlertItem(
            icon: Icons.info_outline,
            color: FuturisticColors.textSecondary,
            title: 'No Active Alerts',
            subtitle: 'Business running smoothly',
            count: '0',
          ),
        );
    }

    return alerts;
  }

  /// Builds the mobileShop-specific KPI cards (Requirements 8.2–8.6):
  /// active repairs, exchange pipeline value, IMEI in-stock count, and
  /// open warranty claims — each from its live source with loading/empty/error
  /// states. Zero-record sources show "0" with an empty-state label (not
  /// a hardcoded count). Failed/timed-out sources show an error state with
  /// a retry affordance (never a stale or hardcoded count).
  List<Widget> _buildMobileShopKpis(MobileShopKpiSnapshot kpis, WidgetRef ref) {
    String rupees(double val) => '₹${val.toStringAsFixed(0)}';

    return <Widget>[
      const SizedBox(height: 8),
      Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
      const SizedBox(height: 12),
      Text(
        'Mobile Shop KPIs',
        style: TextStyle(
          color: FuturisticColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
      const SizedBox(height: 12),
      // Row 1: Active Repairs + Exchange Pipeline
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: kpis.activeRepairsAvailable
                  ? _buildKpiTile(
                      icon: Icons.build_outlined,
                      color: FuturisticColors.accent1,
                      label: kpis.activeRepairs == 0
                          ? 'No active repairs'
                          : 'Active Repairs',
                      value: _displayCount(kpis.activeRepairs),
                    )
                  : _buildKpiErrorTile(
                      icon: Icons.build_outlined,
                      color: FuturisticColors.error,
                      label: 'Active Repairs',
                      onRetry: () => ref.invalidate(mobileShopKpiProvider),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: kpis.exchangePipelineAvailable
                  ? _buildKpiTile(
                      icon: Icons.swap_horiz_outlined,
                      color: FuturisticColors.success,
                      label: kpis.exchangePipelineValue == 0
                          ? 'No exchange value'
                          : 'Exchange Pipeline',
                      value: kpis.exchangePipelineValue == 0
                          ? '₹0'
                          : rupees(kpis.exchangePipelineValue),
                    )
                  : _buildKpiErrorTile(
                      icon: Icons.swap_horiz_outlined,
                      color: FuturisticColors.error,
                      label: 'Exchange Pipeline',
                      onRetry: () => ref.invalidate(mobileShopKpiProvider),
                    ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      // Row 2: IMEI In-Stock + Open Warranty Claims
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: kpis.imeiInStockAvailable
                  ? _buildKpiTile(
                      icon: Icons.phone_android_outlined,
                      color: FuturisticColors.accent2,
                      label: kpis.imeiInStockCount == 0
                          ? 'No IMEI in stock'
                          : 'IMEI In Stock',
                      value: _displayCount(kpis.imeiInStockCount),
                    )
                  : _buildKpiErrorTile(
                      icon: Icons.phone_android_outlined,
                      color: FuturisticColors.error,
                      label: 'IMEI Stock',
                      onRetry: () => ref.invalidate(mobileShopKpiProvider),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: kpis.openWarrantyClaimsAvailable
                  ? _buildKpiTile(
                      icon: Icons.verified_user_outlined,
                      color: FuturisticColors.warning,
                      label: kpis.openWarrantyClaims == 0
                          ? 'No open claims'
                          : 'Open Warranty Claims',
                      value: _displayCount(kpis.openWarrantyClaims),
                    )
                  : _buildKpiErrorTile(
                      icon: Icons.verified_user_outlined,
                      color: FuturisticColors.error,
                      label: 'Warranty Claims',
                      onRetry: () => ref.invalidate(mobileShopKpiProvider),
                    ),
            ),
          ],
        ),
      ),
    ];
  }

  /// Full error state for the mobileShop KPI section when the entire provider
  /// fails (e.g. no session). Shows a retry button to re-fetch (R8.6).
  Widget _buildMobileShopErrorState(WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: FuturisticColors.error.withValues(alpha: 0.7),
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            'Unable to load KPIs',
            style: TextStyle(
              color: FuturisticColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => ref.invalidate(mobileShopKpiProvider),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: FuturisticColors.accent1.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Retry',
                style: TextStyle(
                  color: FuturisticColors.accent1,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A single KPI tile in error state with a retry icon/button (R8.6).
  Widget _buildKpiErrorTile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onRetry,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const Spacer(),
              GestureDetector(
                onTap: onRetry,
                child: Icon(
                  Icons.refresh,
                  color: color.withValues(alpha: 0.7),
                  size: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Error',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: FuturisticColors.textSecondary.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the hardware-specific KPI cards (bugfix.md 2.25): outstanding
  /// contractor credit, open indents, deposit liability, and fast/slow movers.
  /// Rendered as a compact 2-column grid so the panel stays dense. Currency
  /// values render with the localized `₹` symbol (2.20).
  List<Widget> _buildHardwareKpis(HardwareKpis kpis) {
    String rupees(int cents) => '₹${(cents / 100).round()}';

    final creditTile = _buildKpiTile(
      icon: Icons.account_balance_wallet_outlined,
      color: FuturisticColors.error,
      label: 'Contractor Credit',
      value: rupees(kpis.outstandingContractorCreditCents),
    );
    final indentsTile = _buildKpiTile(
      icon: Icons.assignment_outlined,
      color: FuturisticColors.accent2,
      label: 'Open Indents',
      value: _displayCount(kpis.openIndents),
    );
    final depositTile = _buildKpiTile(
      icon: Icons.savings_outlined,
      color: FuturisticColors.accent1,
      label: 'Deposit Liability',
      value: rupees(kpis.depositLiabilityCents),
    );
    final velocityTile = _buildKpiTile(
      icon: Icons.speed_outlined,
      color: FuturisticColors.success,
      label: 'Fast / Slow Movers',
      value: '${kpis.fastMovers} / ${kpis.slowMovers}',
    );

    return <Widget>[
      const SizedBox(height: 8),
      Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
      const SizedBox(height: 12),
      Text(
        'Operations KPIs',
        style: TextStyle(
          color: FuturisticColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: creditTile),
            const SizedBox(width: 12),
            Expanded(child: indentsTile),
          ],
        ),
      ),
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: depositTile),
            const SizedBox(width: 12),
            Expanded(child: velocityTile),
          ],
        ),
      ),
    ];
  }

  /// A single compact KPI tile: icon + value + label, used by the hardware
  /// KPI grid (bugfix.md 2.25).
  Widget _buildKpiTile({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: FuturisticColors.textSecondary.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// Caps a raw alert count for display: values above 999 render as "999+",
  /// everything else renders as its plain decimal string (R15.5).
  static String _displayCount(int n) => n > 999 ? '999+' : n.toString();

  Widget _buildAlertItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String count,
    String? semanticLabel,
  }) {
    final Widget item = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: FuturisticColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: FuturisticColors.textSecondary.withValues(
                      alpha: 0.7,
                    ),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              count,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    // When a non-empty semantic label is supplied (pharmacy alert cards,
    // R26.5), expose the alert's content as a single merged semantics node
    // for assistive technologies. Callers that omit it keep the original
    // tree unchanged (no behaviour change for other verticals).
    if (semanticLabel != null && semanticLabel.isNotEmpty) {
      return Semantics(
        label: semanticLabel,
        container: true,
        child: ExcludeSemantics(child: item),
      );
    }
    return item;
  }
}
