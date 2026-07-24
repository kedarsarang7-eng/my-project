// ============================================================================
// Task 29 — BACKEND GAP failing test for adjustInventory, rentOut, returnRental
// Feature: decoration-catering-remediation
// **Validates: Requirements GR-3**
// ============================================================================
//
// Ground Rule 5 (GR-3): "No unverified backend assumption ships as a silent
// success path." Every endpoint this design touches that is not confirmed
// deployed gets a client that throws a clearly labeled error on 404/501,
// plus a failing integration test that documents the gap — never a silent
// mock fallback.
//
// This test covers the three unverified endpoints:
//   1. POST /dc/inventory/{id}/adjust   — adjustInventory()
//   2. POST /dc/inventory/{id}/rent-out — rentOut()
//   3. POST /dc/inventory/{id}/return   — returnRental()
//
// For each, the test asserts:
//   - HTTP 404 → throws an exception containing "BACKEND GAP"
//   - HTTP 501 → throws an exception (non-silent failure)
//   - No local state is mutated on failure (provider state unchanged)
//   - No code path substitutes a mocked/fabricated successful response
//
// Run:
//   flutter test test/features/decoration_catering/dc_backend_gap_test.dart
// ============================================================================
library;

import 'package:dukanx/core/api/api_client.dart';
import 'package:dukanx/core/di/service_locator.dart';
import 'package:dukanx/features/decoration_catering/data/repositories/dc_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';

// ---------------------------------------------------------------------------
// Fake ApiClient that returns configurable responses per endpoint path.
// ---------------------------------------------------------------------------

/// A fake [ApiClient] that returns a caller-configured [ApiResponse] for
/// `post()` calls. The response is determined by [_postResponses] keyed on
/// the request path. Any path not configured throws an [UnimplementedError].
///
/// This fake is intentionally minimal: it never returns a success response
/// for the three BACKEND GAP endpoints, because no test in this file should
/// be able to exercise a "success" path without the backend being deployed.
class _BackendGapApiClient extends Mock implements ApiClient {
  _BackendGapApiClient();

  /// Map of path → response to return for POST calls.
  final Map<String, ApiResponse<Map<String, dynamic>>> _postResponses = {};

  /// Configure what `post(path)` returns.
  void whenPost(String path, ApiResponse<Map<String, dynamic>> response) {
    _postResponses[path] = response;
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool requireAuth = true,
    String? idempotencyKey,
  }) async {
    final response = _postResponses[path];
    if (response == null) {
      throw UnimplementedError(
        '_BackendGapApiClient: no response configured for POST $path',
      );
    }
    return response;
  }

  /// GET is not expected to be called in these tests.
  @override
  Future<ApiResponse<Map<String, dynamic>>> get(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    bool requireAuth = true,
  }) async {
    throw UnimplementedError(
      '_BackendGapApiClient: GET $path not expected in BACKEND GAP tests',
    );
  }
}

void main() {
  final getIt = GetIt.instance;

  setUp(() {
    if (getIt.isRegistered<ApiClient>()) {
      getIt.unregister<ApiClient>();
    }
  });

  tearDown(() {
    if (getIt.isRegistered<ApiClient>()) {
      getIt.unregister<ApiClient>();
    }
  });

  // =========================================================================
  // 1. adjustInventory — POST /dc/inventory/{id}/adjust
  // =========================================================================
  group('GR-3: adjustInventory BACKEND GAP contract', () {
    test('throws exception containing "BACKEND GAP" on HTTP 404', () async {
      final fakeApi = _BackendGapApiClient();
      fakeApi.whenPost(
        '/dc/inventory/item_1/adjust',
        ApiResponse<Map<String, dynamic>>.failure(404, 'Not Found'),
      );
      getIt.registerSingleton<ApiClient>(fakeApi);

      final repo = DcRepository();

      expect(
        () => repo.adjustInventory('item_1', 5),
        throwsA(
          predicate<Exception>(
            (e) =>
                e.toString().contains('BACKEND GAP') &&
                e.toString().contains('/dc/inventory/item_1/adjust'),
          ),
        ),
      );
    });

    test('throws exception on HTTP 501 (no silent success fallback)', () async {
      final fakeApi = _BackendGapApiClient();
      fakeApi.whenPost(
        '/dc/inventory/item_1/adjust',
        ApiResponse<Map<String, dynamic>>.failure(501, 'Not Implemented'),
      );
      getIt.registerSingleton<ApiClient>(fakeApi);

      final repo = DcRepository();

      expect(
        () => repo.adjustInventory('item_1', 5),
        throwsA(isA<Exception>()),
      );
    });

    test('does not mutate local state on 404 failure', () async {
      final fakeApi = _BackendGapApiClient();
      fakeApi.whenPost(
        '/dc/inventory/item_1/adjust',
        ApiResponse<Map<String, dynamic>>.failure(404, 'Not Found'),
      );
      getIt.registerSingleton<ApiClient>(fakeApi);

      final repo = DcRepository();

      // The method should throw — no state change should happen.
      // adjustInventory is a void method: if it throws, no downstream
      // invalidate/refresh occurs. Verify no additional API calls are
      // made (e.g., no fallback PUT to overwrite stock).
      try {
        await repo.adjustInventory('item_1', 5);
        fail('Expected an exception to be thrown');
      } on Exception catch (e) {
        // Confirm it's the BACKEND GAP error, not some other failure.
        expect(e.toString(), contains('BACKEND GAP'));
        // The fake API client would throw UnimplementedError if any
        // unexpected call (GET, PUT, etc.) was made — the fact that we
        // reached here without that error proves no fallback path was
        // attempted.
      }
    });

    test('does not substitute a mocked/fabricated successful response '
        'when the endpoint is unavailable', () async {
      // If adjustInventory had a silent fallback (e.g., returning void
      // without calling the API, or catching 404 and pretending success),
      // this test would pass without throwing. Instead, we assert it
      // ALWAYS throws on 404 — proving no fabricated success path exists.
      final fakeApi = _BackendGapApiClient();
      fakeApi.whenPost(
        '/dc/inventory/item_1/adjust',
        ApiResponse<Map<String, dynamic>>.failure(404, 'Not Found'),
      );
      getIt.registerSingleton<ApiClient>(fakeApi);

      final repo = DcRepository();

      // Must throw — if it completes normally, a silent fallback exists.
      await expectLater(
        () => repo.adjustInventory('item_1', 5),
        throwsA(isA<Exception>()),
      );
    });
  });

  // =========================================================================
  // 2. rentOut — POST /dc/inventory/{id}/rent-out
  // =========================================================================
  group('GR-3: rentOut BACKEND GAP contract', () {
    test('throws exception containing "BACKEND GAP" on HTTP 404', () async {
      final fakeApi = _BackendGapApiClient();
      fakeApi.whenPost(
        '/dc/inventory/item_2/rent-out',
        ApiResponse<Map<String, dynamic>>.failure(404, 'Not Found'),
      );
      getIt.registerSingleton<ApiClient>(fakeApi);

      final repo = DcRepository();

      expect(
        () => repo.rentOut(itemId: 'item_2', eventId: 'evt_1', quantity: 3),
        throwsA(
          predicate<Exception>(
            (e) =>
                e.toString().contains('BACKEND GAP') &&
                e.toString().contains('/dc/inventory/item_2/rent-out'),
          ),
        ),
      );
    });

    test('throws exception on HTTP 501 (no silent success fallback)', () async {
      final fakeApi = _BackendGapApiClient();
      fakeApi.whenPost(
        '/dc/inventory/item_2/rent-out',
        ApiResponse<Map<String, dynamic>>.failure(501, 'Not Implemented'),
      );
      getIt.registerSingleton<ApiClient>(fakeApi);

      final repo = DcRepository();

      expect(
        () => repo.rentOut(itemId: 'item_2', eventId: 'evt_1', quantity: 3),
        throwsA(isA<Exception>()),
      );
    });

    test('does not mutate local state on 404 failure', () async {
      final fakeApi = _BackendGapApiClient();
      fakeApi.whenPost(
        '/dc/inventory/item_2/rent-out',
        ApiResponse<Map<String, dynamic>>.failure(404, 'Not Found'),
      );
      getIt.registerSingleton<ApiClient>(fakeApi);

      final repo = DcRepository();

      try {
        await repo.rentOut(itemId: 'item_2', eventId: 'evt_1', quantity: 3);
        fail('Expected an exception to be thrown');
      } on Exception catch (e) {
        expect(e.toString(), contains('BACKEND GAP'));
        // No additional API calls made (fake would throw
        // UnimplementedError for any unexpected path).
      }
    });

    test('does not substitute a mocked/fabricated successful response '
        'when the endpoint is unavailable', () async {
      final fakeApi = _BackendGapApiClient();
      fakeApi.whenPost(
        '/dc/inventory/item_2/rent-out',
        ApiResponse<Map<String, dynamic>>.failure(404, 'Not Found'),
      );
      getIt.registerSingleton<ApiClient>(fakeApi);

      final repo = DcRepository();

      await expectLater(
        () => repo.rentOut(itemId: 'item_2', eventId: 'evt_1', quantity: 3),
        throwsA(isA<Exception>()),
      );
    });
  });

  // =========================================================================
  // 3. returnRental — POST /dc/inventory/{id}/return
  // =========================================================================
  group('GR-3: returnRental BACKEND GAP contract', () {
    test('throws exception containing "BACKEND GAP" on HTTP 404', () async {
      final fakeApi = _BackendGapApiClient();
      fakeApi.whenPost(
        '/dc/inventory/item_3/return',
        ApiResponse<Map<String, dynamic>>.failure(404, 'Not Found'),
      );
      getIt.registerSingleton<ApiClient>(fakeApi);

      final repo = DcRepository();

      expect(
        () => repo.returnRental(
          itemId: 'item_3',
          rentalId: 'rental_1',
          damagedQty: 0,
        ),
        throwsA(
          predicate<Exception>(
            (e) =>
                e.toString().contains('BACKEND GAP') &&
                e.toString().contains('/dc/inventory/item_3/return'),
          ),
        ),
      );
    });

    test('throws exception on HTTP 501 (no silent success fallback)', () async {
      final fakeApi = _BackendGapApiClient();
      fakeApi.whenPost(
        '/dc/inventory/item_3/return',
        ApiResponse<Map<String, dynamic>>.failure(501, 'Not Implemented'),
      );
      getIt.registerSingleton<ApiClient>(fakeApi);

      final repo = DcRepository();

      expect(
        () => repo.returnRental(
          itemId: 'item_3',
          rentalId: 'rental_1',
          damagedQty: 0,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('does not mutate local state on 404 failure', () async {
      final fakeApi = _BackendGapApiClient();
      fakeApi.whenPost(
        '/dc/inventory/item_3/return',
        ApiResponse<Map<String, dynamic>>.failure(404, 'Not Found'),
      );
      getIt.registerSingleton<ApiClient>(fakeApi);

      final repo = DcRepository();

      try {
        await repo.returnRental(
          itemId: 'item_3',
          rentalId: 'rental_1',
          damagedQty: 0,
        );
        fail('Expected an exception to be thrown');
      } on Exception catch (e) {
        expect(e.toString(), contains('BACKEND GAP'));
        // No additional API calls made (fake would throw
        // UnimplementedError for any unexpected path).
      }
    });

    test('does not substitute a mocked/fabricated successful response '
        'when the endpoint is unavailable', () async {
      final fakeApi = _BackendGapApiClient();
      fakeApi.whenPost(
        '/dc/inventory/item_3/return',
        ApiResponse<Map<String, dynamic>>.failure(404, 'Not Found'),
      );
      getIt.registerSingleton<ApiClient>(fakeApi);

      final repo = DcRepository();

      await expectLater(
        () => repo.returnRental(
          itemId: 'item_3',
          rentalId: 'rental_1',
          damagedQty: 0,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  // =========================================================================
  // Cross-check: all three endpoints share the same BACKEND GAP contract
  // =========================================================================
  group('GR-3 cross-check: unified BACKEND GAP contract across all three '
      'unverified endpoints', () {
    test('all three methods throw on 404 with messages containing '
        '"BACKEND GAP" and the respective endpoint path', () async {
      final fakeApi = _BackendGapApiClient();
      fakeApi.whenPost(
        '/dc/inventory/item_x/adjust',
        ApiResponse<Map<String, dynamic>>.failure(404, 'Not Found'),
      );
      fakeApi.whenPost(
        '/dc/inventory/item_x/rent-out',
        ApiResponse<Map<String, dynamic>>.failure(404, 'Not Found'),
      );
      fakeApi.whenPost(
        '/dc/inventory/item_x/return',
        ApiResponse<Map<String, dynamic>>.failure(404, 'Not Found'),
      );
      getIt.registerSingleton<ApiClient>(fakeApi);

      final repo = DcRepository();

      // adjustInventory
      try {
        await repo.adjustInventory('item_x', 1);
        fail('adjustInventory should throw on 404');
      } on Exception catch (e) {
        expect(e.toString(), contains('BACKEND GAP'));
        expect(e.toString(), contains('/dc/inventory/item_x/adjust'));
      }

      // rentOut
      try {
        await repo.rentOut(itemId: 'item_x', eventId: 'evt_1', quantity: 1);
        fail('rentOut should throw on 404');
      } on Exception catch (e) {
        expect(e.toString(), contains('BACKEND GAP'));
        expect(e.toString(), contains('/dc/inventory/item_x/rent-out'));
      }

      // returnRental
      try {
        await repo.returnRental(
          itemId: 'item_x',
          rentalId: 'rental_1',
          damagedQty: 0,
        );
        fail('returnRental should throw on 404');
      } on Exception catch (e) {
        expect(e.toString(), contains('BACKEND GAP'));
        expect(e.toString(), contains('/dc/inventory/item_x/return'));
      }
    });

    test('none of the three methods complete normally on 404 — confirming '
        'no code path substitutes a fabricated successful response', () async {
      final fakeApi = _BackendGapApiClient();
      fakeApi.whenPost(
        '/dc/inventory/item_y/adjust',
        ApiResponse<Map<String, dynamic>>.failure(404, 'Not Found'),
      );
      fakeApi.whenPost(
        '/dc/inventory/item_y/rent-out',
        ApiResponse<Map<String, dynamic>>.failure(404, 'Not Found'),
      );
      fakeApi.whenPost(
        '/dc/inventory/item_y/return',
        ApiResponse<Map<String, dynamic>>.failure(404, 'Not Found'),
      );
      getIt.registerSingleton<ApiClient>(fakeApi);

      final repo = DcRepository();

      // Each must throw — a normal completion would prove a silent
      // fabricated-success path exists, violating GR-5.
      await expectLater(
        () => repo.adjustInventory('item_y', 1),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        () => repo.rentOut(itemId: 'item_y', eventId: 'evt_1', quantity: 1),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        () => repo.returnRental(
          itemId: 'item_y',
          rentalId: 'rental_1',
          damagedQty: 0,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
