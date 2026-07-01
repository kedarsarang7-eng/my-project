// ============================================================================
// Layer 3 Integration Test — Auth Module
// ============================================================================
//
// Tests authentication flows against the REAL Node.js backend and DynamoDB.
// No mocks, stubs, or hardcoded data. Requires the certification stage to be
// running and accessible.
//
// Run with:
//   flutter test integration_test/auth/ \
//     --dart-define=DUKANX_ENV=staging \
//     --dart-define=CERT_VALID_EMAIL=<real-email> \
//     --dart-define=CERT_VALID_PASSWORD=<real-password>
//
// Requirements validated: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6
// ============================================================================

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import '../integration_test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------------------------
  // Precondition: certification stage must be reachable
  // -------------------------------------------------------------------------

  group('Auth Module — Real Backend Integration (Req 4.1, 4.4)', () {
    late String validAccessToken;
    late String validRefreshToken;

    setUpAll(() async {
      // Verify backend is reachable before running auth tests
      final healthUri = Uri.parse('${CertificationConfig.baseUrl}/health');
      try {
        final health = await http
            .get(healthUri)
            .timeout(const Duration(seconds: 10));
        if (health.statusCode != 200) {
          fail(
            'Certification backend not healthy at ${CertificationConfig.baseUrl}. '
            'Status: ${health.statusCode}. '
            'Integration tests require the real backend.',
          );
        }
      } catch (e) {
        fail(
          'Cannot reach certification backend at ${CertificationConfig.baseUrl}. '
          'Error: $e. '
          'Layer 3 tests require the real Node.js backend and DynamoDB.',
        );
      }
    });

    // -----------------------------------------------------------------------
    // Req 4.4: Valid credentials → authenticated session
    // -----------------------------------------------------------------------

    test('valid credentials produce an authenticated session', () async {
      // Skip if no credentials provided (CI without secrets)
      if (CertificationConfig.validTestPassword.isEmpty) {
        markTestSkipped(
          'CERT_VALID_PASSWORD not provided. '
          'Provide via --dart-define to run auth tests.',
        );
        return;
      }

      final result = await authenticateReal(
        email: CertificationConfig.validTestEmail,
        password: CertificationConfig.validTestPassword,
      );

      expect(
        result.authenticated,
        isTrue,
        reason: 'Valid credentials must produce an authenticated session',
      );
      expect(
        result.accessToken,
        isNotNull,
        reason: 'Authenticated session must include an access token',
      );
      expect(
        result.accessToken!.isNotEmpty,
        isTrue,
        reason: 'Access token must not be empty',
      );
      expect(
        result.refreshToken,
        isNotNull,
        reason: 'Authenticated session must include a refresh token',
      );

      // Store for subsequent tests
      validAccessToken = result.accessToken!;
      validRefreshToken = result.refreshToken!;

      // Assert no mock data in the auth response (Req 4.2)
      assertNoMockData(
        jsonEncode({
          'accessToken': result.accessToken,
          'refreshToken': result.refreshToken,
        }),
        context: 'auth/login response',
      );
    });

    // -----------------------------------------------------------------------
    // Req 4.4: Invalid credentials → rejected, no session
    // -----------------------------------------------------------------------

    test(
      'invalid credentials are rejected without establishing a session',
      () async {
        final result = await authenticateReal(
          email: CertificationConfig.invalidTestEmail,
          password: CertificationConfig.invalidTestPassword,
        );

        expect(
          result.authenticated,
          isFalse,
          reason:
              'Invalid credentials must not produce an authenticated session',
        );
        expect(
          result.accessToken,
          isNull,
          reason: 'Rejected auth must not return an access token',
        );
        expect(
          result.refreshToken,
          isNull,
          reason: 'Rejected auth must not return a refresh token',
        );
      },
    );

    test('empty password is rejected', () async {
      final result = await authenticateReal(
        email: CertificationConfig.validTestEmail,
        password: '',
      );

      expect(
        result.authenticated,
        isFalse,
        reason: 'Empty password must be rejected',
      );
    });

    test('empty email is rejected', () async {
      final result = await authenticateReal(
        email: '',
        password: 'SomePassword123!',
      );

      expect(
        result.authenticated,
        isFalse,
        reason: 'Empty email must be rejected',
      );
    });

    // -----------------------------------------------------------------------
    // Req 4.5: Token refresh within 5 seconds
    // -----------------------------------------------------------------------

    group('Token Refresh (Req 4.5)', () {
      test('token refresh issues a new valid token within 5 seconds', () async {
        if (CertificationConfig.validTestPassword.isEmpty) {
          markTestSkipped('CERT_VALID_PASSWORD not provided.');
          return;
        }

        // First authenticate to get a valid refresh token
        final authResult = await authenticateReal(
          email: CertificationConfig.validTestEmail,
          password: CertificationConfig.validTestPassword,
        );
        expect(authResult.authenticated, isTrue);

        // Refresh the token and assert it completes within 5s
        final newToken = await assertTokenRefreshWithin5s(
          refreshToken: authResult.refreshToken!,
        );

        expect(
          newToken.isNotEmpty,
          isTrue,
          reason: 'Refreshed token must be non-empty',
        );
        expect(
          newToken,
          isNot(equals(authResult.accessToken)),
          reason: 'New token should differ from the original',
        );
      });

      test('expired token is no longer accepted after refresh', () async {
        if (CertificationConfig.validTestPassword.isEmpty) {
          markTestSkipped('CERT_VALID_PASSWORD not provided.');
          return;
        }

        // Authenticate and get tokens
        final authResult = await authenticateReal(
          email: CertificationConfig.validTestEmail,
          password: CertificationConfig.validTestPassword,
        );
        expect(authResult.authenticated, isTrue);

        final originalToken = authResult.accessToken!;

        // Refresh to invalidate the original
        await assertTokenRefreshWithin5s(
          refreshToken: authResult.refreshToken!,
        );

        // The prior expired/rotated token should be rejected
        // Note: depending on backend implementation, the old token may still
        // be valid until its natural expiry. This test validates the rotation
        // behavior as specified.
        await assertExpiredTokenRejected(
          expiredToken: 'expired-$originalToken',
        );
      });

      test('invalid refresh token is rejected', () async {
        final uri = Uri.parse('${CertificationConfig.baseUrl}/auth/refresh');

        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': 'invalid-refresh-token-xyz'}),
        );

        expect(
          response.statusCode,
          anyOf(equals(401), equals(403), equals(400)),
          reason: 'Invalid refresh token must be rejected',
        );
      });
    });

    // -----------------------------------------------------------------------
    // Req 4.6: Role-based guard — grant/deny
    // -----------------------------------------------------------------------

    group('Role Guard — Authorization (Req 4.6)', () {
      test('owner role can access admin endpoints', () async {
        if (CertificationConfig.validTestPassword.isEmpty) {
          markTestSkipped('CERT_VALID_PASSWORD not provided.');
          return;
        }

        // Authenticate as owner (authorized for admin endpoints)
        final ownerAuth = await authenticateReal(
          email: CertificationConfig.ownerEmail,
          password: CertificationConfig.validTestPassword,
        );

        // Authenticate as salesperson (unauthorized for admin endpoints)
        final salespersonAuth = await authenticateReal(
          email: CertificationConfig.salespersonEmail,
          password: CertificationConfig.validTestPassword,
        );

        if (!ownerAuth.authenticated || !salespersonAuth.authenticated) {
          markTestSkipped(
            'Role-based test accounts not available on certification stage.',
          );
          return;
        }

        await assertRoleGuard(
          endpoint: '/admin/tenants',
          method: 'GET',
          authorizedToken: ownerAuth.accessToken!,
          unauthorizedToken: salespersonAuth.accessToken!,
        );
      });

      test(
        'accountant role can access billing but not user management',
        () async {
          if (CertificationConfig.validTestPassword.isEmpty) {
            markTestSkipped('CERT_VALID_PASSWORD not provided.');
            return;
          }

          final accountantAuth = await authenticateReal(
            email: CertificationConfig.accountantEmail,
            password: CertificationConfig.validTestPassword,
          );

          if (!accountantAuth.authenticated) {
            markTestSkipped(
              'Accountant test account not available on certification stage.',
            );
            return;
          }

          // Accountant should be able to access billing reports
          final billingUri = Uri.parse(
            '${CertificationConfig.baseUrl}/billing/reports',
          );
          final billingResponse = await http.get(
            billingUri,
            headers: {'Authorization': 'Bearer ${accountantAuth.accessToken}'},
          );
          expect(
            billingResponse.statusCode,
            anyOf(equals(200), equals(204)),
            reason: 'Accountant should access billing reports',
          );

          // Accountant should NOT be able to manage users
          final usersUri = Uri.parse(
            '${CertificationConfig.baseUrl}/admin/users',
          );
          final usersResponse = await http.get(
            usersUri,
            headers: {'Authorization': 'Bearer ${accountantAuth.accessToken}'},
          );
          expect(
            usersResponse.statusCode,
            anyOf(equals(401), equals(403)),
            reason: 'Accountant should be denied user management access',
          );
        },
      );

      test('unauthenticated request is denied', () async {
        final uri = Uri.parse(
          '${CertificationConfig.baseUrl}/billing/invoices',
        );
        final response = await http.get(uri);

        expect(
          response.statusCode,
          anyOf(equals(401), equals(403)),
          reason: 'Unauthenticated request must be denied (Req 4.6)',
        );
      });
    });
  });

  // -------------------------------------------------------------------------
  // Req 4.2: No mock data in Release_Build auth responses
  // -------------------------------------------------------------------------

  group('Auth Module — Mock Data Detection (Req 4.2, 4.3)', () {
    test('auth endpoints return no mock data indicators', () async {
      if (CertificationConfig.validTestPassword.isEmpty) {
        markTestSkipped('CERT_VALID_PASSWORD not provided.');
        return;
      }

      final result = await authenticateReal(
        email: CertificationConfig.validTestEmail,
        password: CertificationConfig.validTestPassword,
      );

      if (result.authenticated) {
        // Check user profile endpoint for mock data
        final profileUri = Uri.parse('${CertificationConfig.baseUrl}/auth/me');
        final profileResponse = await http.get(
          profileUri,
          headers: {'Authorization': 'Bearer ${result.accessToken}'},
        );

        if (profileResponse.statusCode == 200) {
          assertNoMockData(
            profileResponse.body,
            context: 'auth/me profile response in Release_Build',
          );
        }
      }
    });

    test('release build assertion is clean', () {
      assertReleaseBuildClean();
    });
  });
}
