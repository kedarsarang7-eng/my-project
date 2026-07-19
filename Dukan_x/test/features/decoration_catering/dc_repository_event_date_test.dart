// ============================================================================
// Task 19 — `eventDate`/`eventEndDate` date-only truncation regression-lock
// Feature: decoration-catering-remediation
// **Validates: Requirements 3.8**
// ============================================================================
//
// Locks in (per requirements.md Requirement 3.8, AC1-4):
//   The `substring(0, 10)` date-only truncation applied to `eventDate` (and
//   `eventEndDate`, which follows the identical rationale) in
//   `DcRepository.createBooking()`/`updateBooking()` is INTENTIONAL —
//   time-of-day scheduling is tracked independently via
//   `setupTime`/`serviceStartTime`/`serviceEndTime`/`cleanupTime` on
//   `EventBooking`.
//
// NOTE (OQ-5): this locks in an INFERRED reading of the truncation
// decision, not a confirmed product sign-off. If the truncation behavior
// is ever intentionally changed, update this test AND the comment at the
// call site in `dc_repository.dart` together.
//
// A fake [ApiClient] is registered in the service locator (mirroring the
// pattern in `dc_event_end_date_test.dart`) so the request body passed to
// `post`/`put` can be captured and asserted directly, without hitting the
// network.
//
// Run: flutter test test/features/decoration_catering/dc_repository_event_date_test.dart
// ============================================================================
library;

import 'package:dukanx/core/api/api_client.dart';
import 'package:dukanx/core/di/service_locator.dart';
import 'package:dukanx/features/decoration_catering/data/models/dc_models.dart';
import 'package:dukanx/features/decoration_catering/data/repositories/dc_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';

/// A fake [ApiClient] that records the `body` passed to [post]/[put] and
/// returns a minimal well-formed booking record so
/// `DcRepository.createBooking()`/`updateBooking()` can parse a result
/// without throwing. Every other verb throws, since this test never calls
/// them.
class _CapturingApiClient extends Mock implements ApiClient {
  Map<String, dynamic>? lastPostBody;
  Map<String, dynamic>? lastPutBody;

  @override
  Future<ApiResponse<Map<String, dynamic>>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool requireAuth = true,
    String? idempotencyKey,
  }) async {
    lastPostBody = body;
    return ApiResponse<Map<String, dynamic>>.success(200, {
      'data': _minimalRawBooking(),
    });
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool requireAuth = true,
    String? idempotencyKey,
  }) async {
    lastPutBody = body;
    return ApiResponse<Map<String, dynamic>>.success(200, {
      'data': _minimalRawBooking(),
    });
  }
}

/// Minimal well-formed raw booking record, used only so
/// `_bookingFromJson` (invoked on the mocked response) doesn't throw.
Map<String, dynamic> _minimalRawBooking() => <String, dynamic>{
  'id': 'evt_1',
  'customerName': 'Test Customer',
  'customerPhone': '9999999999',
  'eventType': 'wedding',
  'eventTitle': 'Test Wedding',
  'eventDate': '2025-06-10',
  'venueName': 'Test Venue',
  'guestCount': 100,
  'status': 'confirmed',
  'totalAmountPaisa': 10000000,
  'advanceAmountPaisa': 5000000,
  'createdAt': '2025-01-01T00:00:00.000Z',
};

/// Builds an [EventBooking] with a non-midnight `eventDate`/`eventEndDate`
/// time component, so the test can prove truncation strips it.
EventBooking _bookingWithTimeComponent({DateTime? eventEndDate}) {
  return EventBooking(
    id: 'evt_1',
    customerId: 'cust_1',
    customerName: 'Test Customer',
    customerPhone: '9999999999',
    eventType: EventType.wedding,
    eventTitle: 'Test Wedding',
    eventDate: DateTime(2025, 6, 10, 14, 30, 0),
    eventEndDate: eventEndDate,
    venue: 'Test Venue',
    guestCount: 100,
    quotedAmount: 100000,
    createdAt: DateTime(2025, 1, 1),
  );
}

void main() {
  final sl = GetIt.instance;
  late _CapturingApiClient fakeApi;

  setUp(() {
    fakeApi = _CapturingApiClient();
    sl.registerSingleton<ApiClient>(fakeApi);
  });

  tearDown(() {
    if (sl.isRegistered<ApiClient>()) {
      sl.unregister<ApiClient>();
    }
  });

  group(
    'DcRepository.createBooking() eventDate truncation (Requirement 3.8)',
    () {
      test('serializes eventDate with a non-midnight time component as a '
          'date-only string (10 chars, no time component)', () async {
        final repo = DcRepository();
        await repo.createBooking(_bookingWithTimeComponent());

        final sentEventDate = fakeApi.lastPostBody?['eventDate'];
        expect(sentEventDate, '2025-06-10');
        expect(sentEventDate, hasLength(10));
      });

      test(
        'serializes eventEndDate (when present) with a non-midnight time '
        'component as a date-only string (10 chars, no time component)',
        () async {
          final repo = DcRepository();
          await repo.createBooking(
            _bookingWithTimeComponent(
              eventEndDate: DateTime(2025, 6, 12, 9, 15, 0),
            ),
          );

          final sentEventEndDate = fakeApi.lastPostBody?['eventEndDate'];
          expect(sentEventEndDate, '2025-06-12');
          expect(sentEventEndDate, hasLength(10));
        },
      );

      test('omits eventEndDate from the request body when null', () async {
        final repo = DcRepository();
        await repo.createBooking(_bookingWithTimeComponent());

        expect(fakeApi.lastPostBody?.containsKey('eventEndDate'), isFalse);
      });
    },
  );

  group(
    'DcRepository.updateBooking() eventDate truncation (Requirement 3.8)',
    () {
      test('serializes eventDate with a non-midnight time component as a '
          'date-only string (10 chars, no time component)', () async {
        final repo = DcRepository();
        await repo.updateBooking(_bookingWithTimeComponent());

        final sentEventDate = fakeApi.lastPutBody?['eventDate'];
        expect(sentEventDate, '2025-06-10');
        expect(sentEventDate, hasLength(10));
      });

      test(
        'serializes eventEndDate (when present) with a non-midnight time '
        'component as a date-only string (10 chars, no time component)',
        () async {
          final repo = DcRepository();
          await repo.updateBooking(
            _bookingWithTimeComponent(
              eventEndDate: DateTime(2025, 6, 12, 9, 15, 0),
            ),
          );

          final sentEventEndDate = fakeApi.lastPutBody?['eventEndDate'];
          expect(sentEventEndDate, '2025-06-12');
          expect(sentEventEndDate, hasLength(10));
        },
      );

      test('omits eventEndDate from the request body when null', () async {
        final repo = DcRepository();
        await repo.updateBooking(_bookingWithTimeComponent());

        expect(fakeApi.lastPutBody?.containsKey('eventEndDate'), isFalse);
      });
    },
  );
}
