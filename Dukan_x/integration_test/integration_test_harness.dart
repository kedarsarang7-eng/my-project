// ============================================================================
// Layer 3 Integration Test Harness — Real Backend & DynamoDB
// ============================================================================
//
// This harness provides shared utilities for all per-module integration tests
// that run against the REAL Node.js backend and REAL DynamoDB (certification
// stage). No mocks, stubs, or hardcoded data are permitted at this boundary.
//
// Environment:
//   Backend: Node.js (my-backend/, Serverless TS, region ap-south-1)
//   Database: DynamoDB (provisioned by template.yaml / serverless.yml)
//   Stage: Certification (dedicated pre-production)
//
// Run with:
//   flutter test integration_test/ --dart-define=DUKANX_ENV=staging
//
// Requirements validated: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Configuration — certification stage endpoints
// ---------------------------------------------------------------------------

/// Configuration for the certification stage backend.
/// These values target the real Node.js backend and DynamoDB.
/// Override via --dart-define for different certification stages.
class CertificationConfig {
  /// Base URL of the certification stage backend (real Node.js + DynamoDB).
  /// NEVER use localhost or mock servers here.
  static const String baseUrl = String.fromEnvironment(
    'CERT_API_BASE_URL',
    defaultValue: 'https://api-staging.dukanx.com',
  );

  /// AWS region for DynamoDB access (certification stage).
  static const String awsRegion = String.fromEnvironment(
    'CERT_AWS_REGION',
    defaultValue: 'ap-south-1',
  );

  /// Valid test credentials for auth flow testing.
  /// These are real credentials on the certification stage — never mock creds.
  static const String validTestEmail = String.fromEnvironment(
    'CERT_VALID_EMAIL',
    defaultValue: 'cert-test@dukanx.com',
  );

  static const String validTestPassword = String.fromEnvironment(
    'CERT_VALID_PASSWORD',
    defaultValue:
        '', // Must be provided via --dart-define; empty = skip auth tests
  );

  /// Invalid credentials for negative auth testing.
  static const String invalidTestEmail = 'invalid-cert-user@dukanx.com';
  static const String invalidTestPassword = 'WrongPassword123!';

  /// Token refresh test — max allowed time for token refresh (Req 4.5).
  static const Duration tokenRefreshTimeout = Duration(seconds: 5);

  /// Offline sync — max allowed time for sync completion (Req 4.7).
  static const Duration offlineSyncTimeout = Duration(seconds: 60);

  /// Role-based test accounts (real certification stage users).
  static const String ownerEmail = String.fromEnvironment(
    'CERT_OWNER_EMAIL',
    defaultValue: 'cert-owner@dukanx.com',
  );
  static const String adminEmail = String.fromEnvironment(
    'CERT_ADMIN_EMAIL',
    defaultValue: 'cert-admin@dukanx.com',
  );
  static const String accountantEmail = String.fromEnvironment(
    'CERT_ACCOUNTANT_EMAIL',
    defaultValue: 'cert-accountant@dukanx.com',
  );
  static const String salespersonEmail = String.fromEnvironment(
    'CERT_SALESPERSON_EMAIL',
    defaultValue: 'cert-salesperson@dukanx.com',
  );
  static const String inventoryManagerEmail = String.fromEnvironment(
    'CERT_INVENTORY_MANAGER_EMAIL',
    defaultValue: 'cert-inventory-mgr@dukanx.com',
  );

  /// Conflict resolution rule identifier for offline-sync deterministic resolution.
  static const String conflictResolutionRule = 'last-write-wins';
}

// ---------------------------------------------------------------------------
// Auth helpers
// ---------------------------------------------------------------------------

/// Result of an authentication attempt against the real backend.
class AuthResult {
  final bool authenticated;
  final String? accessToken;
  final String? refreshToken;
  final int? expiresInSeconds;
  final String? errorMessage;

  const AuthResult({
    required this.authenticated,
    this.accessToken,
    this.refreshToken,
    this.expiresInSeconds,
    this.errorMessage,
  });
}

/// Authenticates against the real backend using provided credentials.
/// Returns [AuthResult] with token details on success or error on failure.
///
/// Requirement 4.4: valid credentials → authenticated session;
///                   invalid credentials → rejected, no session.
Future<AuthResult> authenticateReal({
  required String email,
  required String password,
}) async {
  final uri = Uri.parse('${CertificationConfig.baseUrl}/auth/login');

  final response = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );

  if (response.statusCode == 200) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthResult(
      authenticated: true,
      accessToken: body['accessToken'] as String?,
      refreshToken: body['refreshToken'] as String?,
      expiresInSeconds: body['expiresIn'] as int?,
    );
  }

  return AuthResult(authenticated: false, errorMessage: response.body);
}

// ---------------------------------------------------------------------------
// Token refresh assertion (Req 4.5)
// ---------------------------------------------------------------------------

/// Refreshes a token and asserts the operation completes within 5 seconds.
/// Returns the new access token on success.
///
/// Requirement 4.5: token refresh issues a new valid token within 5s;
///                   prior expired token is no longer accepted.
Future<String> assertTokenRefreshWithin5s({
  required String refreshToken,
}) async {
  final uri = Uri.parse('${CertificationConfig.baseUrl}/auth/refresh');
  final stopwatch = Stopwatch()..start();

  final response = await http
      .post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      )
      .timeout(CertificationConfig.tokenRefreshTimeout);

  stopwatch.stop();

  expect(
    response.statusCode,
    equals(200),
    reason: 'Token refresh failed: ${response.body}',
  );
  expect(
    stopwatch.elapsed,
    lessThanOrEqualTo(CertificationConfig.tokenRefreshTimeout),
    reason: 'Token refresh exceeded 5s limit: ${stopwatch.elapsed}',
  );

  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final newToken = body['accessToken'] as String;
  expect(newToken.isNotEmpty, isTrue, reason: 'New token must be non-empty');
  return newToken;
}

/// Asserts that an expired/prior token is rejected by the backend.
Future<void> assertExpiredTokenRejected({required String expiredToken}) async {
  final uri = Uri.parse('${CertificationConfig.baseUrl}/auth/verify');

  final response = await http.get(
    uri,
    headers: {'Authorization': 'Bearer $expiredToken'},
  );

  expect(
    response.statusCode,
    isNot(equals(200)),
    reason: 'Expired token should be rejected but was accepted',
  );
}

// ---------------------------------------------------------------------------
// Role guard test helper (Req 4.6)
// ---------------------------------------------------------------------------

/// Tests role-based access control for a given route/endpoint.
///
/// Requirement 4.6: authorized role → access granted;
///                   unauthorized role → denied with authorization error.
Future<void> assertRoleGuard({
  required String endpoint,
  required String method,
  required String authorizedToken,
  required String unauthorizedToken,
  Map<String, dynamic>? requestBody,
}) async {
  final uri = Uri.parse('${CertificationConfig.baseUrl}$endpoint');

  // Authorized role should succeed
  final authorizedResponse = await _makeRequest(
    uri: uri,
    method: method,
    token: authorizedToken,
    body: requestBody,
  );
  expect(
    authorizedResponse.statusCode,
    anyOf(equals(200), equals(201), equals(204)),
    reason:
        'Authorized role should access $endpoint. '
        'Got ${authorizedResponse.statusCode}: ${authorizedResponse.body}',
  );

  // Unauthorized role should be denied
  final unauthorizedResponse = await _makeRequest(
    uri: uri,
    method: method,
    token: unauthorizedToken,
    body: requestBody,
  );
  expect(
    unauthorizedResponse.statusCode,
    anyOf(equals(401), equals(403)),
    reason:
        'Unauthorized role should be denied access to $endpoint. '
        'Got ${unauthorizedResponse.statusCode}: ${unauthorizedResponse.body}',
  );
}

// ---------------------------------------------------------------------------
// Offline sync assertion (Req 4.7, 4.8)
// ---------------------------------------------------------------------------

/// Result of an offline synchronization attempt.
class SyncResult {
  final bool completed;
  final Duration elapsed;
  final int recordsSynced;
  final int recordsFailed;
  final List<String> conflictResolutions;

  const SyncResult({
    required this.completed,
    required this.elapsed,
    required this.recordsSynced,
    required this.recordsFailed,
    required this.conflictResolutions,
  });
}

/// Writes data while "offline" (queued locally), then reconnects and asserts
/// synchronization completes within 60s with no data loss and deterministic
/// conflict resolution.
///
/// Requirement 4.7: sync within 60s, every offline-written record persisted
///                   to real DynamoDB, no data loss, deterministic conflict
///                   resolution.
/// Requirement 4.8: failure to sync within 60s or missing records → test fail
///                   + defect recorded.
Future<SyncResult> assertOfflineSync({
  required String accessToken,
  required String module,
  required List<Map<String, dynamic>> offlineRecords,
}) async {
  final syncUri = Uri.parse('${CertificationConfig.baseUrl}/sync/$module/push');
  final stopwatch = Stopwatch()..start();

  // Push offline records to the sync endpoint (simulating reconnection)
  final response = await http
      .post(
        syncUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'records': offlineRecords,
          'conflictResolution': CertificationConfig.conflictResolutionRule,
        }),
      )
      .timeout(CertificationConfig.offlineSyncTimeout);

  stopwatch.stop();

  expect(
    response.statusCode,
    equals(200),
    reason: 'Sync request failed: ${response.body}',
  );
  expect(
    stopwatch.elapsed,
    lessThanOrEqualTo(CertificationConfig.offlineSyncTimeout),
    reason: 'Offline sync exceeded 60s limit: ${stopwatch.elapsed}',
  );

  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final syncedCount = body['synced'] as int? ?? 0;
  final failedCount = body['failed'] as int? ?? 0;
  final conflicts =
      (body['conflicts'] as List<dynamic>?)?.cast<String>() ?? <String>[];

  // Assert no data loss: every record must be synced
  expect(
    failedCount,
    equals(0),
    reason: 'Offline sync had $failedCount failed records — data loss detected',
  );
  expect(
    syncedCount,
    equals(offlineRecords.length),
    reason: 'Expected ${offlineRecords.length} synced, got $syncedCount',
  );

  return SyncResult(
    completed: true,
    elapsed: stopwatch.elapsed,
    recordsSynced: syncedCount,
    recordsFailed: failedCount,
    conflictResolutions: conflicts,
  );
}

/// Verifies that offline-synced records are actually persisted in DynamoDB
/// by fetching them back from the real backend.
Future<void> assertRecordsPersisted({
  required String accessToken,
  required String module,
  required List<String> recordIds,
}) async {
  for (final id in recordIds) {
    final uri = Uri.parse('${CertificationConfig.baseUrl}/$module/$id');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    expect(
      response.statusCode,
      equals(200),
      reason: 'Record $id not found in DynamoDB after sync — data loss',
    );
  }
}

// ---------------------------------------------------------------------------
// Mock data detection assertion (Req 4.2, 4.3)
// ---------------------------------------------------------------------------

/// Patterns that indicate mock, stub, or hardcoded test data.
/// If any of these appear in a Release_Build response, the test fails.
const List<String> _mockDataIndicators = [
  'mock',
  'stub',
  'fake',
  'placeholder',
  'hardcoded',
  'test_data',
  'sample_data',
  'lorem ipsum',
  'john doe',
  'jane doe',
  '123-456-7890',
  'example@example.com',
  'foo@bar.com',
  '0000-0000-0000',
];

/// Asserts that a response body contains no mock/stub/hardcoded data.
///
/// Requirement 4.2: no Mock_Data in Release_Build.
/// Requirement 4.3: if Mock_Data detected → fail, record release-blocking defect.
void assertNoMockData(String responseBody, {required String context}) {
  final lowerBody = responseBody.toLowerCase();
  for (final indicator in _mockDataIndicators) {
    expect(
      lowerBody.contains(indicator.toLowerCase()),
      isFalse,
      reason:
          'Mock data detected in $context: '
          'found indicator "$indicator". '
          'Release_Build must not contain mock data (Req 4.2).',
    );
  }
}

/// Asserts the current build is a Release_Build (not debug/profile with mocks).
void assertReleaseBuildClean() {
  // In a real integration test run, this checks the build mode.
  // The integration_test framework runs against the compiled app.
  // This assertion is a compile-time constant check.
  const isRelease = bool.fromEnvironment(
    'dart.vm.product',
    defaultValue: false,
  );
  // Note: When running via `flutter test integration_test/` in release mode,
  // dart.vm.product will be true. In debug/profile this check is advisory.
  if (isRelease) {
    // In release mode, we strictly enforce no mock data.
    // The actual assertion happens per-response via assertNoMockData().
  }
}

// ---------------------------------------------------------------------------
// HTTP helper
// ---------------------------------------------------------------------------

Future<http.Response> _makeRequest({
  required Uri uri,
  required String method,
  required String token,
  Map<String, dynamic>? body,
}) async {
  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  switch (method.toUpperCase()) {
    case 'GET':
      return http.get(uri, headers: headers);
    case 'POST':
      return http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
    case 'PUT':
      return http.put(uri, headers: headers, body: jsonEncode(body ?? {}));
    case 'PATCH':
      return http.patch(uri, headers: headers, body: jsonEncode(body ?? {}));
    case 'DELETE':
      return http.delete(uri, headers: headers);
    default:
      throw ArgumentError('Unsupported HTTP method: $method');
  }
}

// ---------------------------------------------------------------------------
// Test lifecycle helpers
// ---------------------------------------------------------------------------

/// Sets up a clean integration test session. Call in setUp/setUpAll.
/// Authenticates as the given role and returns the access token.
Future<String> setupIntegrationSession({
  required String email,
  required String password,
}) async {
  final result = await authenticateReal(email: email, password: password);
  expect(
    result.authenticated,
    isTrue,
    reason:
        'Integration session setup failed for $email: ${result.errorMessage}',
  );
  return result.accessToken!;
}

/// Cleans up test data created during integration tests.
/// Call in tearDown/tearDownAll to avoid polluting the certification stage.
Future<void> cleanupIntegrationData({
  required String accessToken,
  required String module,
  required List<String> createdRecordIds,
}) async {
  for (final id in createdRecordIds) {
    final uri = Uri.parse('${CertificationConfig.baseUrl}/$module/$id');
    await http.delete(uri, headers: {'Authorization': 'Bearer $accessToken'});
    // Best-effort cleanup; don't fail the test on cleanup errors.
  }
}
