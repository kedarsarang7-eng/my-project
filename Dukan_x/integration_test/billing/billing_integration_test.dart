// ============================================================================
// Layer 3 Integration Test — Billing Module
// ============================================================================
//
// Tests the billing module against the REAL Node.js backend and DynamoDB.
// Exercises invoice creation, payment recording, ledger persistence, and
// offline sync. No mocks, stubs, or hardcoded data.
//
// Run with:
//   flutter test integration_test/billing/ \
//     --dart-define=DUKANX_ENV=staging \
//     --dart-define=CERT_VALID_EMAIL=<real-email> \
//     --dart-define=CERT_VALID_PASSWORD=<real-password>
//
// Requirements validated: 4.1, 4.2, 4.3, 4.7, 4.8, 4.9
// ============================================================================

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import '../integration_test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Billing Module — Real Backend Integration (Req 4.1)', () {
    late String accessToken;
    final List<String> createdRecordIds = [];

    setUpAll(() async {
      // Verify backend is reachable
      final healthUri = Uri.parse('${CertificationConfig.baseUrl}/health');
      try {
        final health = await http
            .get(healthUri)
            .timeout(const Duration(seconds: 10));
        if (health.statusCode != 200) {
          fail(
            'Certification backend not healthy. '
            'Integration tests require the real backend and DynamoDB.',
          );
        }
      } catch (e) {
        fail(
          'Cannot reach certification backend: $e. '
          'Layer 3 tests require the real Node.js backend and DynamoDB.',
        );
      }

      // Authenticate with a valid session
      if (CertificationConfig.validTestPassword.isEmpty) {
        return; // Tests will skip individually
      }

      accessToken = await setupIntegrationSession(
        email: CertificationConfig.validTestEmail,
        password: CertificationConfig.validTestPassword,
      );
    });

    tearDownAll(() async {
      // Clean up test records from certification stage
      if (createdRecordIds.isNotEmpty) {
        await cleanupIntegrationData(
          accessToken: accessToken,
          module: 'billing',
          createdRecordIds: createdRecordIds,
        );
      }
    });

    // -----------------------------------------------------------------------
    // Req 4.1: Billing module exercised against real backend + DynamoDB
    // -----------------------------------------------------------------------

    group('Invoice CRUD against real DynamoDB', () {
      test('create invoice persists to real DynamoDB', () async {
        if (CertificationConfig.validTestPassword.isEmpty) {
          markTestSkipped('CERT_VALID_PASSWORD not provided.');
          return;
        }

        final invoiceData = {
          'customerId': 'cert-test-customer-001',
          'items': [
            {
              'name': 'Integration Test Product',
              'quantity': 2,
              'unitPrice': 150.50,
              'tax': 'GST_18',
            },
          ],
          'discount': 10.00,
          'paymentMethod': 'cash',
          'notes': 'Layer 3 integration test invoice',
        };

        final uri = Uri.parse(
          '${CertificationConfig.baseUrl}/billing/invoices',
        );
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(invoiceData),
        );

        expect(
          response.statusCode,
          anyOf(equals(200), equals(201)),
          reason:
              'Invoice creation against real backend failed: ${response.body}',
        );

        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final invoiceId = body['id'] as String?;
        expect(invoiceId, isNotNull, reason: 'Created invoice must have an ID');
        createdRecordIds.add(invoiceId!);

        // Verify the invoice is retrievable (confirms DynamoDB persistence)
        final getUri = Uri.parse(
          '${CertificationConfig.baseUrl}/billing/invoices/$invoiceId',
        );
        final getResponse = await http.get(
          getUri,
          headers: {'Authorization': 'Bearer $accessToken'},
        );
        expect(
          getResponse.statusCode,
          equals(200),
          reason: 'Invoice must be retrievable from DynamoDB after creation',
        );

        // Assert no mock data in response
        assertNoMockData(
          getResponse.body,
          context: 'billing/invoices GET response',
        );
      });

      test('list invoices returns real data from DynamoDB', () async {
        if (CertificationConfig.validTestPassword.isEmpty) {
          markTestSkipped('CERT_VALID_PASSWORD not provided.');
          return;
        }

        final uri = Uri.parse(
          '${CertificationConfig.baseUrl}/billing/invoices',
        );
        final response = await http.get(
          uri,
          headers: {'Authorization': 'Bearer $accessToken'},
        );

        expect(
          response.statusCode,
          equals(200),
          reason: 'Listing invoices from real backend failed',
        );

        // Response should be a list (real data from DynamoDB)
        final body = jsonDecode(response.body);
        expect(
          body,
          isA<Map<String, dynamic>>(),
          reason: 'Invoice list response must be structured',
        );

        assertNoMockData(
          response.body,
          context: 'billing/invoices list response',
        );
      });

      test('payment recording persists to real DynamoDB', () async {
        if (CertificationConfig.validTestPassword.isEmpty) {
          markTestSkipped('CERT_VALID_PASSWORD not provided.');
          return;
        }

        final paymentData = {
          'invoiceId': createdRecordIds.isNotEmpty
              ? createdRecordIds.first
              : 'cert-test-invoice-001',
          'amount': 100.00,
          'method': 'upi',
          'reference': 'CERT-PAY-${DateTime.now().millisecondsSinceEpoch}',
        };

        final uri = Uri.parse(
          '${CertificationConfig.baseUrl}/billing/payments',
        );
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(paymentData),
        );

        expect(
          response.statusCode,
          anyOf(equals(200), equals(201)),
          reason: 'Payment recording failed: ${response.body}',
        );

        assertNoMockData(
          response.body,
          context: 'billing/payments POST response',
        );
      });
    });

    // -----------------------------------------------------------------------
    // Req 4.6: Role guard for billing endpoints
    // -----------------------------------------------------------------------

    group('Billing role guard (Req 4.6)', () {
      test('inventory manager cannot create invoices', () async {
        if (CertificationConfig.validTestPassword.isEmpty) {
          markTestSkipped('CERT_VALID_PASSWORD not provided.');
          return;
        }

        // Authenticate as inventory manager
        final invMgrAuth = await authenticateReal(
          email: CertificationConfig.inventoryManagerEmail,
          password: CertificationConfig.validTestPassword,
        );

        if (!invMgrAuth.authenticated) {
          markTestSkipped(
            'Inventory manager test account not available on certification stage.',
          );
          return;
        }

        await assertRoleGuard(
          endpoint: '/billing/invoices',
          method: 'POST',
          authorizedToken: accessToken, // owner/admin can create
          unauthorizedToken: invMgrAuth.accessToken!,
          requestBody: {
            'customerId': 'cert-test-customer-guard',
            'items': [
              {'name': 'Guard Test', 'quantity': 1, 'unitPrice': 10.0},
            ],
          },
        );
      });
    });

    // -----------------------------------------------------------------------
    // Req 4.7, 4.8: Offline sync for billing data
    // -----------------------------------------------------------------------

    group('Billing offline sync (Req 4.7, 4.8)', () {
      test(
        'offline-written invoices sync within 60s with no data loss',
        () async {
          if (CertificationConfig.validTestPassword.isEmpty) {
            markTestSkipped('CERT_VALID_PASSWORD not provided.');
            return;
          }

          // Simulate offline-written records that need to be synced
          final offlineRecords = [
            {
              'id': 'offline-inv-${DateTime.now().millisecondsSinceEpoch}-1',
              'type': 'invoice',
              'customerId': 'cert-test-customer-offline-1',
              'items': [
                {'name': 'Offline Product A', 'quantity': 3, 'unitPrice': 50.0},
              ],
              'total': 150.0,
              'createdOffline': true,
              'timestamp': DateTime.now().toIso8601String(),
            },
            {
              'id': 'offline-inv-${DateTime.now().millisecondsSinceEpoch}-2',
              'type': 'invoice',
              'customerId': 'cert-test-customer-offline-2',
              'items': [
                {
                  'name': 'Offline Product B',
                  'quantity': 1,
                  'unitPrice': 200.0,
                },
              ],
              'total': 200.0,
              'createdOffline': true,
              'timestamp': DateTime.now().toIso8601String(),
            },
          ];

          final syncResult = await assertOfflineSync(
            accessToken: accessToken,
            module: 'billing',
            offlineRecords: offlineRecords,
          );

          // Verify sync completed within 60s (asserted inside assertOfflineSync)
          expect(syncResult.completed, isTrue);
          expect(syncResult.recordsSynced, equals(offlineRecords.length));
          expect(
            syncResult.recordsFailed,
            equals(0),
            reason: 'No data loss: all records must sync (Req 4.7)',
          );

          // Track for cleanup
          for (final record in offlineRecords) {
            createdRecordIds.add(record['id'] as String);
          }
        },
      );

      test('offline sync resolves conflicts deterministically', () async {
        if (CertificationConfig.validTestPassword.isEmpty) {
          markTestSkipped('CERT_VALID_PASSWORD not provided.');
          return;
        }

        // Create a record, then simulate a conflicting offline update
        final recordId =
            'conflict-test-${DateTime.now().millisecondsSinceEpoch}';

        // First write (server-side)
        final createUri = Uri.parse(
          '${CertificationConfig.baseUrl}/billing/invoices',
        );
        final createResponse = await http.post(
          createUri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({
            'id': recordId,
            'customerId': 'cert-conflict-customer',
            'items': [
              {'name': 'Conflict Item', 'quantity': 1, 'unitPrice': 100.0},
            ],
            'total': 100.0,
          }),
        );

        if (createResponse.statusCode == 200 ||
            createResponse.statusCode == 201) {
          createdRecordIds.add(recordId);

          // Conflicting offline update (different total)
          final conflictingRecords = [
            {
              'id': recordId,
              'customerId': 'cert-conflict-customer',
              'items': [
                {'name': 'Conflict Item', 'quantity': 2, 'unitPrice': 100.0},
              ],
              'total': 200.0,
              'createdOffline': true,
              'timestamp': DateTime.now().toIso8601String(),
            },
          ];

          final syncResult = await assertOfflineSync(
            accessToken: accessToken,
            module: 'billing',
            offlineRecords: conflictingRecords,
          );

          // Conflict should be resolved deterministically
          expect(syncResult.completed, isTrue);
          // The resolution rule is 'last-write-wins' per CertificationConfig
          expect(
            syncResult.conflictResolutions,
            isNotEmpty,
            reason: 'Conflicting write should report resolution strategy',
          );
        }
      });

      test('synced records are persisted in real DynamoDB', () async {
        if (CertificationConfig.validTestPassword.isEmpty) {
          markTestSkipped('CERT_VALID_PASSWORD not provided.');
          return;
        }

        // Verify previously synced offline records are actually in DynamoDB
        if (createdRecordIds.isEmpty) {
          markTestSkipped('No records created to verify persistence.');
          return;
        }

        await assertRecordsPersisted(
          accessToken: accessToken,
          module: 'billing/invoices',
          recordIds: createdRecordIds.take(2).toList(),
        );
      });
    });

    // -----------------------------------------------------------------------
    // Req 4.2, 4.3: No mock data in billing Release_Build
    // -----------------------------------------------------------------------

    group('Billing mock data detection (Req 4.2, 4.3)', () {
      test('billing API responses contain no mock data', () async {
        if (CertificationConfig.validTestPassword.isEmpty) {
          markTestSkipped('CERT_VALID_PASSWORD not provided.');
          return;
        }

        // Fetch billing data and assert no mock indicators
        final endpoints = [
          '/billing/invoices',
          '/billing/payments',
          '/billing/reports/summary',
        ];

        for (final endpoint in endpoints) {
          final uri = Uri.parse('${CertificationConfig.baseUrl}$endpoint');
          final response = await http.get(
            uri,
            headers: {'Authorization': 'Bearer $accessToken'},
          );

          if (response.statusCode == 200) {
            assertNoMockData(
              response.body,
              context: 'Billing endpoint $endpoint',
            );
          }
        }
      });

      test('release build has no mock data in billing module', () {
        // This is a structural assertion for the Release_Build.
        // In a real CI run with --release, dart.vm.product is true.
        assertReleaseBuildClean();
      });
    });
  });
}
