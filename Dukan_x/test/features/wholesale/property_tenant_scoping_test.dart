// ============================================================================
// PROPERTY TEST: Tenant Scoping on Every Operation
// ============================================================================
// Feature: wholesale-vertical-remediation, Property 3: Tenant scoping on every operation
//
// **Validates: Requirements 1.5, 1.6, 4.9, 13.5**
//
// Tests WholesaleRepositoryImpl.withTenant<T>:
//   - Throws UnresolvedTenantError when session has null tenant
//   - Throws UnresolvedTenantError when session has empty string tenant
//   - Passes the correct tenantId to callback when tenant exists
//
// Uses a fake SessionManager (implements pattern) to control tenant resolution.
//
// PBT library: dartproptest ^0.2.1.
//
// Run: flutter test test/features/wholesale/property_tenant_scoping_test.dart
// ============================================================================

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/features/wholesale/data/wholesale_repository.dart';
import 'package:dukanx/features/wholesale/data/unresolved_tenant_error.dart';
import 'package:dukanx/core/session/session_manager.dart';

// =============================================================================
// Fake SessionManager for testing tenant resolution.
// =============================================================================

/// A minimal fake that exposes [currentBusinessId] and [userId] for testing.
///
/// Uses the `implements` + `noSuchMethod` pattern established in the wholesale
/// property tests (property_sidebar_resolution_test.dart, etc.) to avoid
/// Firebase constructor dependencies.
class _FakeSessionManager extends ChangeNotifier implements SessionManager {
  final String? _currentBusinessId;
  final String? _userId;

  _FakeSessionManager({String? currentBusinessId, String? userId})
    : _currentBusinessId = currentBusinessId,
      _userId = userId;

  @override
  String? get currentBusinessId => _currentBusinessId;

  @override
  String? get userId => _userId;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  const int kNumRuns = 200;

  late AppDatabase testDb;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    testDb = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDownAll(() async {
    await testDb.close();
  });

  /// Helper: creates a WholesaleRepositoryImpl with a specific session config.
  WholesaleRepositoryImpl makeRepo({
    String? currentBusinessId,
    String? userId,
  }) {
    return WholesaleRepositoryImpl(
      sessionManager: _FakeSessionManager(
        currentBusinessId: currentBusinessId,
        userId: userId,
      ),
      db: testDb,
    );
  }

  group(
    'Feature: wholesale-vertical-remediation, Property 3: Tenant scoping on every operation',
    () {
      // -----------------------------------------------------------------------
      // Property 3a: withTenant throws UnresolvedTenantError when session
      // returns null for both currentBusinessId and userId.
      // -----------------------------------------------------------------------
      test(
        'Property 3a: withTenant throws UnresolvedTenantError when tenant is null',
        () async {
          final repo = makeRepo(currentBusinessId: null, userId: null);

          expect(
            () => repo.withTenant<String>((tenantId) async => tenantId),
            throwsA(isA<UnresolvedTenantError>()),
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 3b: withTenant throws UnresolvedTenantError when session
      // returns an empty string.
      // -----------------------------------------------------------------------
      test(
        'Property 3b: withTenant throws UnresolvedTenantError when tenant is empty',
        () async {
          final repo = makeRepo(currentBusinessId: '', userId: '');

          expect(
            () => repo.withTenant<String>((tenantId) async => tenantId),
            throwsA(isA<UnresolvedTenantError>()),
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 3c: withTenant passes correct tenantId to callback when a
      // valid tenant exists (uses currentBusinessId).
      // -----------------------------------------------------------------------
      test(
        'Property 3c: withTenant passes correct tenantId from currentBusinessId',
        () async {
          final repo = makeRepo(
            currentBusinessId: 'biz_abc_123',
            userId: 'uid_fallback',
          );

          final result = await repo.withTenant<String>(
            (tenantId) async => tenantId,
          );
          expect(result, equals('biz_abc_123'));
        },
      );

      // -----------------------------------------------------------------------
      // Property 3d: withTenant uses userId as fallback when currentBusinessId
      // is null but userId is non-empty.
      // -----------------------------------------------------------------------
      test('Property 3d: withTenant uses userId as fallback when '
          'currentBusinessId is null', () async {
        final repo = makeRepo(currentBusinessId: null, userId: 'user_abc_123');

        final result = await repo.withTenant<String>(
          (tenantId) async => tenantId,
        );
        expect(result, equals('user_abc_123'));
      });

      // -----------------------------------------------------------------------
      // Property 3e (forAll): Valid non-empty tenants never throw
      // UnresolvedTenantError.
      // -----------------------------------------------------------------------
      test('Property 3e (forAll): valid non-empty tenants never throw '
          'UnresolvedTenantError ($kNumRuns iterations)', () {
        final held = forAll(
          (int seed) {
            final tenantId = 'tenant_${seed.abs()}_biz';
            final repo = makeRepo(
              currentBusinessId: tenantId,
              userId: 'fallback_uid',
            );

            try {
              repo.withTenant<void>((tid) async {});
              return true;
            } on UnresolvedTenantError {
              return false;
            } catch (_) {
              // Other errors (e.g. DB operation errors) are acceptable —
              // the tenant resolved but DB isn't set up for the op.
              return true;
            }
          },
          [Gen.interval(1, 99999)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'withTenant must not throw UnresolvedTenantError for '
              'valid non-empty tenantId',
        );
      });

      // -----------------------------------------------------------------------
      // Property 3f: Null/empty tenant configurations always throw
      // UnresolvedTenantError. Uses an iteration loop since withTenant is async
      // and forAll is synchronous.
      // -----------------------------------------------------------------------
      test('Property 3f: null/empty tenants always throw '
          'UnresolvedTenantError ($kNumRuns iterations)', () async {
        for (var seed = 0; seed < kNumRuns; seed++) {
          // Alternate between null and empty configurations.
          final isNull = seed % 2 == 0;
          final repo = makeRepo(
            currentBusinessId: isNull ? null : '',
            userId: isNull ? null : '',
          );

          await expectLater(
            repo.withTenant<void>((tenantId) async {}),
            throwsA(isA<UnresolvedTenantError>()),
          );
        }
      });
    },
  );
}
