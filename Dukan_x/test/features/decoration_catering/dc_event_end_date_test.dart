// ============================================================================
// Task 15 — Multi-day event (`eventEndDate`) regression-lock test
// Feature: decoration-catering-remediation
// **Validates: Requirements 3.4**
// ============================================================================
//
// Regression-lock only — no production code change expected unless this
// test surfaces an actual regression.
//
// Locks in (per requirements.md Requirement 3.4, AC1-3):
//   1. `EventBooking` exposes a nullable `eventEndDate` field (AC1).
//   2. A raw record missing `eventEndDate` parses to `EventBooking` with
//      `eventEndDate == null`, without throwing (AC2).
//   3. A raw record whose `eventEndDate` is chronologically before its
//      `eventDate` is treated as invalid per the EXISTING parsing behavior
//      in `DcRepository._bookingFromJson` (AC3). Per that code (read
//      directly, not assumed): the out-of-order `eventEndDate` is logged
//      via `debugPrint` and discarded — the resulting `EventBooking` has
//      `eventEndDate == null` rather than throwing or keeping the invalid
//      value. This test locks in that exact behavior.
//
// Multi-day profitability correctness is explicitly out of scope (OQ-7).
//
// `_bookingFromJson` is a private static method, so it is exercised
// indirectly through `DcRepository.getBookings()` with a fake [ApiClient]
// double registered in the service locator, matching the pattern already
// established by `dc_reachability_gate_test.dart`'s `FakeDcApiClient`.
//
// Run: flutter test test/features/decoration_catering/dc_event_end_date_test.dart
// ============================================================================
library;

import 'package:dukanx/core/api/api_client.dart';
import 'package:dukanx/core/di/service_locator.dart';
import 'package:dukanx/features/decoration_catering/data/models/dc_models.dart';
import 'package:dukanx/features/decoration_catering/data/repositories/dc_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';

/// A fake [ApiClient] whose `get('/dc/events', ...)` returns a
/// caller-supplied raw JSON payload instead of hitting the network. Every
/// other verb throws, since this test never calls them.
class _FixtureApiClient extends Mock implements ApiClient {
  _FixtureApiClient(this._rawEventRecords);

  final List<Map<String, dynamic>> _rawEventRecords;

  @override
  Future<ApiResponse<Map<String, dynamic>>> get(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    bool requireAuth = true,
  }) async {
    return ApiResponse<Map<String, dynamic>>.success(200, {
      'data': _rawEventRecords,
    });
  }
}

/// Builds a minimal well-formed raw booking record, overridable per field,
/// so each test only needs to specify the fields relevant to it.
Map<String, dynamic> _rawBooking({
  String id = 'evt_1',
  String? eventDate,
  Object? eventEndDate = _omit,
}) {
  final record = <String, dynamic>{
    'id': id,
    'customerId': 'cust_1',
    'customerName': 'Test Customer',
    'customerPhone': '9999999999',
    'eventType': 'wedding',
    'eventTitle': 'Test Wedding',
    'eventDate': eventDate ?? '2025-06-10',
    'venueName': 'Test Venue',
    'guestCount': 100,
    'status': 'confirmed',
    'totalAmountPaisa': 10000000,
    'advanceAmountPaisa': 5000000,
    'createdAt': '2025-01-01T00:00:00.000Z',
  };
  if (eventEndDate != _omit) {
    record['eventEndDate'] = eventEndDate;
  }
  return record;
}

/// Sentinel meaning "do not set this key at all" (distinct from `null`,
/// which would set the key to a JSON null).
const Object _omit = Object();

void main() {
  final sl = GetIt.instance;

  tearDown(() {
    if (sl.isRegistered<ApiClient>()) {
      sl.unregister<ApiClient>();
    }
  });

  group('EventBooking.eventEndDate (Requirement 3.4 AC1)', () {
    test('is exposed as a nullable field and can be constructed as null '
        'without throwing', () {
      expect(
        () => EventBooking(
          id: 'evt_direct',
          customerId: 'cust_1',
          customerName: 'Direct Customer',
          customerPhone: '9999999999',
          eventType: EventType.birthday,
          eventTitle: 'Direct Birthday',
          eventDate: DateTime(2025, 6, 10),
          eventEndDate: null,
          venue: 'Direct Venue',
          guestCount: 10,
          quotedAmount: 1000,
          createdAt: DateTime(2025, 1, 1),
        ),
        returnsNormally,
      );

      final booking = EventBooking(
        id: 'evt_direct',
        customerId: 'cust_1',
        customerName: 'Direct Customer',
        customerPhone: '9999999999',
        eventType: EventType.birthday,
        eventTitle: 'Direct Birthday',
        eventDate: DateTime(2025, 6, 10),
        eventEndDate: null,
        venue: 'Direct Venue',
        guestCount: 10,
        quotedAmount: 1000,
        createdAt: DateTime(2025, 1, 1),
      );

      expect(booking.eventEndDate, isNull);
    });

    test('can also be constructed with a non-null DateTime value', () {
      final booking = EventBooking(
        id: 'evt_direct_2',
        customerId: 'cust_1',
        customerName: 'Direct Customer',
        customerPhone: '9999999999',
        eventType: EventType.birthday,
        eventTitle: 'Direct Birthday',
        eventDate: DateTime(2025, 6, 10),
        eventEndDate: DateTime(2025, 6, 12),
        venue: 'Direct Venue',
        guestCount: 10,
        quotedAmount: 1000,
        createdAt: DateTime(2025, 1, 1),
      );

      expect(booking.eventEndDate, DateTime(2025, 6, 12));
    });
  });

  group(
    'DcRepository.getBookings() -> _bookingFromJson (Requirement 3.4 AC2)',
    () {
      test('a raw record missing eventEndDate parses to eventEndDate == null '
          'without throwing', () async {
        sl.registerSingleton<ApiClient>(
          _FixtureApiClient([_rawBooking(eventEndDate: _omit)]),
        );

        final repo = DcRepository();

        List<EventBooking> bookings = [];
        await expectLater(
          () async => bookings = await repo.getBookings(),
          returnsNormally,
        );

        expect(bookings, hasLength(1));
        expect(bookings.single.eventEndDate, isNull);
      });

      test('a raw record with eventEndDate == null (explicit JSON null) also '
          'parses to eventEndDate == null without throwing', () async {
        sl.registerSingleton<ApiClient>(
          _FixtureApiClient([_rawBooking(eventEndDate: null)]),
        );

        final repo = DcRepository();
        final bookings = await repo.getBookings();

        expect(bookings, hasLength(1));
        expect(bookings.single.eventEndDate, isNull);
      });
    },
  );

  group(
    'DcRepository.getBookings() -> _bookingFromJson (Requirement 3.4 AC3)',
    () {
      test(
        'a raw record whose eventEndDate is chronologically before '
        'eventDate is treated as invalid per existing behavior: the '
        'invalid eventEndDate is discarded (parsed EventBooking.eventEndDate '
        'is null) rather than throwing or retaining the invalid value',
        () async {
          sl.registerSingleton<ApiClient>(
            _FixtureApiClient([
              _rawBooking(
                eventDate: '2025-06-10',
                eventEndDate: '2025-06-05', // before eventDate
              ),
            ]),
          );

          final repo = DcRepository();

          List<EventBooking> bookings = [];
          await expectLater(
            () async => bookings = await repo.getBookings(),
            returnsNormally,
          );

          // Locks in current DcRepository._bookingFromJson behavior: an
          // out-of-order eventEndDate is NOT an exception and does NOT
          // exclude the record (id is still present/valid) — it is
          // silently discarded, leaving eventEndDate null on the parsed
          // EventBooking.
          expect(bookings, hasLength(1));
          expect(bookings.single.id, 'evt_1');
          expect(bookings.single.eventEndDate, isNull);
          expect(bookings.single.eventDate, DateTime.parse('2025-06-10'));
        },
      );

      test(
        'a raw record whose eventEndDate equals eventDate is accepted '
        '(not treated as invalid — only strictly-before is rejected)',
        () async {
          sl.registerSingleton<ApiClient>(
            _FixtureApiClient([
              _rawBooking(eventDate: '2025-06-10', eventEndDate: '2025-06-10'),
            ]),
          );

          final repo = DcRepository();
          final bookings = await repo.getBookings();

          expect(bookings, hasLength(1));
          expect(bookings.single.eventEndDate, DateTime.parse('2025-06-10'));
        },
      );

      test('a raw record whose eventEndDate is after eventDate is accepted '
          'and preserved as-is', () async {
        sl.registerSingleton<ApiClient>(
          _FixtureApiClient([
            _rawBooking(eventDate: '2025-06-10', eventEndDate: '2025-06-12'),
          ]),
        );

        final repo = DcRepository();
        final bookings = await repo.getBookings();

        expect(bookings, hasLength(1));
        expect(bookings.single.eventEndDate, DateTime.parse('2025-06-12'));
      });
    },
  );
}
