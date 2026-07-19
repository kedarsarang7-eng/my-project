// ============================================================================
// Task 16 — `_bookingFromJson` null-safety regression-lock and property test
// Feature: decoration-catering-remediation
// **Validates: Requirements 3.5**
// ============================================================================
//
// Regression-lock only — no production code change expected unless this
// test surfaces an actual regression.
//
// Per requirements.md Requirement 3.5 (Acceptance Criteria 1-3):
//   AC1. FOR ALL raw booking records missing any field other than `id`, THE
//        `_bookingFromJson` SHALL return a valid `EventBooking` with a
//        documented default for the missing field, and SHALL NOT throw.
//   AC2. IF a raw booking record is missing `id`, THEN THE
//        `_bookingFromJson` SHALL throw, and THE `_dataList` SHALL catch
//        that exception per-record and exclude only that record from the
//        returned list.
//   AC3. WHEN a response contains a mix of well-formed and malformed
//        (missing `id`) records, THE bookings list SHALL contain all
//        well-formed records and exclude only the malformed ones.
//
// Property (tasks.md, explicit): For any malformed booking record missing
// only non-id fields, `_bookingFromJson` returns a valid EventBooking with
// documented defaults and never throws.
//
// `_bookingFromJson` and `_dataList` are private, so both are exercised
// indirectly through `DcRepository.getBookings()` with a fake [ApiClient]
// double registered in the service locator — the same
// `_FixtureApiClient`/`_rawBooking`-style pattern established by
// `dc_event_end_date_test.dart` (Task 15).
//
// PBT library: dartproptest ^0.2.1 (repo-wide standard — see
// dc_advance_config_test.dart / pubspec.yaml for rationale). `forAllAsync`
// is used (rather than the sync `forAll`) because each generated case must
// await `DcRepository.getBookings()`. 200 runs matches the convention used
// across this repo's other property suites (>= 100 required by the spec).
//
// Run: flutter test test/features/decoration_catering/dc_booking_null_safety_test.dart
// ============================================================================
library;

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/api/api_client.dart';
import 'package:dukanx/core/di/service_locator.dart';
import 'package:dukanx/features/decoration_catering/data/models/dc_models.dart';
import 'package:dukanx/features/decoration_catering/data/repositories/dc_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';

/// At least 100 generated cases are required by the spec; 200 matches the
/// dartproptest default and the convention used across this repo's suites.
const int kNumRuns = 200;

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

/// The full ordered set of non-`id` fields `_bookingFromJson` reads off a
/// raw booking record. Order matters — it is the positional order of the
/// omit-flag tuple the property generator produces.
const List<String> _fieldNames = [
  'customerId',
  'customerName',
  'customerPhone',
  'customerEmail',
  'eventType',
  'eventTitle',
  'eventDate',
  'eventEndDate',
  'venueName',
  'venueAddress',
  'guestCount',
  'status',
  'totalAmountPaisa',
  'advanceAmountPaisa',
  'notes',
  'createdAt',
  'decorationThemeId',
  'cateringPackageId',
  'assignedStaffIds',
  'includesDecoration',
  'includesCatering',
  'notesList',
  'setupTime',
  'serviceStartTime',
  'serviceEndTime',
  'cleanupTime',
];

/// Well-formed ("complete") values for every non-`id` field. When a field
/// is NOT omitted for a given generated case, this is the value placed on
/// the raw record.
///
/// `eventEndDate`'s complete value is deliberately far in the future
/// (year 2099) so it is never rejected as "before eventDate" regardless of
/// whether `eventDate` itself is omitted (and therefore defaults to
/// `DateTime.now()`) or present at its own complete value — this keeps the
/// two fields' assertions independent of each other and of wall-clock time.
final Map<String, dynamic> _completeValues = {
  'customerId': 'cust_1',
  'customerName': 'Test Customer',
  'customerPhone': '9999999999',
  'customerEmail': 'test@example.com',
  'eventType': 'wedding',
  'eventTitle': 'Test Wedding',
  'eventDate': '2025-06-10',
  'eventEndDate': '2099-12-31',
  'venueName': 'Test Venue',
  'venueAddress': '123 Test Street',
  'guestCount': 150,
  'status': 'confirmed',
  'totalAmountPaisa': 1000000,
  'advanceAmountPaisa': 500000,
  'notes': 'Some notes',
  'createdAt': '2025-01-01T00:00:00.000Z',
  'decorationThemeId': 'theme_1',
  'cateringPackageId': 'pkg_1',
  'assignedStaffIds': ['staff_1', 'staff_2'],
  'includesDecoration': true,
  'includesCatering': true,
  'notesList': [
    {
      'id': 'note_1',
      'text': 'Some note',
      'createdAt': '2025-01-01T00:00:00.000Z',
      'createdBy': 'staff_1',
    },
  ],
  'setupTime': '08:00',
  'serviceStartTime': '10:00',
  'serviceEndTime': '18:00',
  'cleanupTime': '20:00',
};

/// Builds a minimal well-formed raw booking record, overridable per field,
/// so each non-property test only needs to specify the fields relevant to
/// it. Mirrors the `_rawBooking` helper established by
/// `dc_event_end_date_test.dart` (Task 15).
Map<String, dynamic> _rawBooking({String id = 'evt_1'}) {
  return {'id': id, ..._completeValues};
}

/// Sentinel meaning "do not set this key at all" (distinct from `null`,
/// which would set the key to a JSON null). Used by the missing-`id`
/// fixture below.
const Object _omit = Object();

/// Builds a raw booking record missing `id` (and otherwise well-formed) —
/// used to exercise the AC2/AC3 missing-`id` throw+skip path.
Map<String, dynamic> _rawBookingMissingId() {
  final record = _rawBooking();
  record.remove('id');
  return record;
}

void main() {
  final sl = GetIt.instance;

  tearDown(() {
    if (sl.isRegistered<ApiClient>()) {
      sl.unregister<ApiClient>();
    }
  });

  group('Requirement 3.5 AC1 — _bookingFromJson never throws and applies a '
      'documented default for any missing non-id field', () {
    test('Property: for any raw booking record with a random subset of '
        'non-id fields omitted, getBookings() returns exactly one '
        'EventBooking with documented defaults for every omitted field, '
        'and never throws (>= 100 generated cases)', () async {
      final omitFlagsGen = Gen.tuple(
        List.generate(_fieldNames.length, (_) => Gen.boolean()),
      );

      final held = await forAllAsync(
        (List<dynamic> flagsRaw) async {
          final omitFlags = flagsRaw.cast<bool>();

          const id = 'evt_prop_1';
          final raw = <String, dynamic>{'id': id};
          for (var i = 0; i < _fieldNames.length; i++) {
            if (!omitFlags[i]) {
              raw[_fieldNames[i]] = _completeValues[_fieldNames[i]];
            }
          }

          if (sl.isRegistered<ApiClient>()) {
            sl.unregister<ApiClient>();
          }
          sl.registerSingleton<ApiClient>(_FixtureApiClient([raw]));

          try {
            final repo = DcRepository();
            final bookings = await repo.getBookings();

            // Never throws + exactly one well-formed booking survives.
            if (bookings.length != 1) return false;
            final b = bookings.single;
            if (b.id != id) return false;

            bool omitted(String field) => omitFlags[_fieldNames.indexOf(field)];

            // customerId / customerName / customerPhone / customerEmail:
            // documented default is '' (`?? ''`).
            if (b.customerId != (omitted('customerId') ? '' : 'cust_1')) {
              return false;
            }
            if (b.customerName !=
                (omitted('customerName') ? '' : 'Test Customer')) {
              return false;
            }
            if (b.customerPhone !=
                (omitted('customerPhone') ? '' : '9999999999')) {
              return false;
            }
            if (b.customerEmail !=
                (omitted('customerEmail') ? '' : 'test@example.com')) {
              return false;
            }

            // eventType: documented default is EventType.other via
            // _parseEventType(null).
            if (b.eventType !=
                (omitted('eventType') ? EventType.other : EventType.wedding)) {
              return false;
            }

            // eventTitle: documented default chain is
            // `eventTitle ?? eventType (raw string) ?? ''`.
            final expectedEventTitle = omitted('eventTitle')
                ? (omitted('eventType') ? '' : 'wedding')
                : 'Test Wedding';
            if (b.eventTitle != expectedEventTitle) return false;

            // eventDate: documented default is DateTime.now() (tryParse
            // fallback) when absent — assert non-null and recent rather
            // than an exact wall-clock match.
            if (omitted('eventDate')) {
              final diff = DateTime.now().difference(b.eventDate).abs();
              if (diff.inSeconds > 60) return false;
            } else {
              if (b.eventDate != DateTime.parse('2025-06-10')) return false;
            }

            // eventEndDate: documented default is null when absent;
            // when present with a value chronologically after eventDate
            // (always true here — see _completeValues comment) it is
            // preserved as-is.
            if (omitted('eventEndDate')) {
              if (b.eventEndDate != null) return false;
            } else {
              if (b.eventEndDate != DateTime.parse('2099-12-31')) {
                return false;
              }
            }

            // venue / venueAddress: documented default is ''.
            if (b.venue != (omitted('venueName') ? '' : 'Test Venue')) {
              return false;
            }
            if (b.venueAddress !=
                (omitted('venueAddress') ? '' : '123 Test Street')) {
              return false;
            }

            // guestCount: documented default is 0.
            if (b.guestCount != (omitted('guestCount') ? 0 : 150)) {
              return false;
            }

            // status: documented default is EventStatus.inquiry via
            // _parseStatus(null).
            if (b.status !=
                (omitted('status')
                    ? EventStatus.inquiry
                    : EventStatus.confirmed)) {
              return false;
            }

            // quotedAmount / advancePaid: documented default is 0 paise
            // (0.0 rupees) via _paisa(null).
            if (b.quotedAmount !=
                (omitted('totalAmountPaisa') ? 0.0 : 10000.0)) {
              return false;
            }
            if (b.advancePaid !=
                (omitted('advanceAmountPaisa') ? 0.0 : 5000.0)) {
              return false;
            }

            // notes: documented default is null (nullable field, no
            // fallback string).
            if (b.notes != (omitted('notes') ? null : 'Some notes')) {
              return false;
            }

            // createdAt: documented default is DateTime.now() (tryParse
            // fallback) when absent.
            if (omitted('createdAt')) {
              final diff = DateTime.now().difference(b.createdAt).abs();
              if (diff.inSeconds > 60) return false;
            } else {
              if (b.createdAt != DateTime.parse('2025-01-01T00:00:00.000Z')) {
                return false;
              }
            }

            // decorationThemeId / cateringPackageId: documented default
            // is null.
            if (b.decorationThemeId !=
                (omitted('decorationThemeId') ? null : 'theme_1')) {
              return false;
            }
            if (b.cateringPackageId !=
                (omitted('cateringPackageId') ? null : 'pkg_1')) {
              return false;
            }

            // assignedStaffIds: documented default is [].
            final expectedStaffIds = omitted('assignedStaffIds')
                ? <String>[]
                : ['staff_1', 'staff_2'];
            if (b.assignedStaffIds.length != expectedStaffIds.length ||
                !b.assignedStaffIds.every(expectedStaffIds.contains)) {
              return false;
            }

            // includesDecoration / includesCatering: documented default
            // is false.
            if (b.includesDecoration != !omitted('includesDecoration')) {
              return false;
            }
            if (b.includesCatering != !omitted('includesCatering')) {
              return false;
            }

            // notesList: documented default is [].
            if (omitted('notesList')) {
              if (b.notesList.isNotEmpty) return false;
            } else {
              if (b.notesList.length != 1) return false;
              final note = b.notesList.single;
              if (note.id != 'note_1' ||
                  note.text != 'Some note' ||
                  note.createdBy != 'staff_1') {
                return false;
              }
            }

            // setupTime / serviceStartTime / serviceEndTime /
            // cleanupTime: documented default is null.
            if (b.setupTime != (omitted('setupTime') ? null : '08:00')) {
              return false;
            }
            if (b.serviceStartTime !=
                (omitted('serviceStartTime') ? null : '10:00')) {
              return false;
            }
            if (b.serviceEndTime !=
                (omitted('serviceEndTime') ? null : '18:00')) {
              return false;
            }
            if (b.cleanupTime != (omitted('cleanupTime') ? null : '20:00')) {
              return false;
            }

            return true;
          } finally {
            if (sl.isRegistered<ApiClient>()) {
              sl.unregister<ApiClient>();
            }
          }
        },
        [omitFlagsGen],
        numRuns: kNumRuns,
      );

      expect(
        held,
        isTrue,
        reason:
            'For any malformed booking record missing only non-id '
            'fields, _bookingFromJson must return a valid EventBooking '
            'with documented defaults and never throw (Requirement '
            '3.5 AC1).',
      );
    });
  });

  group('Requirement 3.5 AC2/AC3 — a record missing id throws in '
      '_bookingFromJson and is excluded per-record by _dataList', () {
    test('a response containing only a record missing id returns an empty '
        'bookings list without getBookings() itself throwing (locks in '
        'that _bookingFromJson throws for a missing id, and _dataList '
        'catches that exception per-record)', () async {
      sl.registerSingleton<ApiClient>(
        _FixtureApiClient([_rawBookingMissingId()]),
      );

      final repo = DcRepository();

      List<EventBooking> bookings = [];
      await expectLater(
        () async => bookings = await repo.getBookings(),
        returnsNormally,
      );

      expect(bookings, isEmpty);
    });

    test('a response with one record missing id and one well-formed record '
        'excludes only the malformed record: getBookings() returns exactly '
        'the well-formed EventBooking and does not throw', () async {
      sl.registerSingleton<ApiClient>(
        _FixtureApiClient([
          _rawBookingMissingId(),
          _rawBooking(id: 'evt_wellformed'),
        ]),
      );

      final repo = DcRepository();

      List<EventBooking> bookings = [];
      await expectLater(
        () async => bookings = await repo.getBookings(),
        returnsNormally,
      );

      expect(bookings, hasLength(1));
      expect(bookings.single.id, 'evt_wellformed');
      expect(bookings.single.customerName, 'Test Customer');
    });
  });
}
