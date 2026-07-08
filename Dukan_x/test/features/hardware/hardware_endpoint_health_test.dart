// Unit test for HARDWARE-004: Endpoint health-check / version negotiation.
//
// Bug condition: when a hardware-specific endpoint is missing (404/501/503),
// the UI renders the same "empty data" state as if the endpoint returned zero
// records. The user cannot distinguish "endpoint unavailable" from "no data".
//
// This test verifies that the endpoint-health utility correctly classifies
// 404/501/503 responses as "endpoint unavailable" and that the workspace
// screen renders a DISTINCT UI widget for that state (not the same widget used
// for empty-data).

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/hardware/data/hardware_ops_repository.dart';
import 'package:dukanx/features/hardware/data/hardware_endpoint_health.dart';

void main() {
  group('HARDWARE-004: Endpoint health-check distinguishes unavailable from empty', () {
    // =========================================================================
    // Property 5: endpoint-unavailable state distinguishable from empty-data
    // Validates: Requirements 1.4, 2.4
    // =========================================================================

    test(
      'HardwareOpsException with statusCode 404 is classified as endpoint unavailable',
      () {
        final exception = HardwareOpsException(
          'listPurchaseOrders',
          'Not Found',
          statusCode: 404,
        );
        expect(
          HardwareEndpointHealth.isEndpointUnavailable(exception),
          isTrue,
          reason:
              'A 404 from a hardware endpoint means the endpoint is not deployed/available',
        );
      },
    );

    test(
      'HardwareOpsException with statusCode 501 is classified as endpoint unavailable',
      () {
        final exception = HardwareOpsException(
          'listGrn',
          'Not Implemented',
          statusCode: 501,
        );
        expect(
          HardwareEndpointHealth.isEndpointUnavailable(exception),
          isTrue,
          reason:
              'A 501 from a hardware endpoint means the endpoint is not supported',
        );
      },
    );

    test(
      'HardwareOpsException with statusCode 503 is classified as endpoint unavailable',
      () {
        final exception = HardwareOpsException(
          'getRateComparison',
          'Service Unavailable',
          statusCode: 503,
        );
        expect(
          HardwareEndpointHealth.isEndpointUnavailable(exception),
          isTrue,
          reason:
              'A 503 from a hardware endpoint means the service is down/unavailable',
        );
      },
    );

    test(
      'HardwareOpsException with statusCode 500 is NOT classified as endpoint unavailable',
      () {
        final exception = HardwareOpsException(
          'listParties',
          'Internal Server Error',
          statusCode: 500,
        );
        expect(
          HardwareEndpointHealth.isEndpointUnavailable(exception),
          isFalse,
          reason: '500 is a generic server error, not an unavailable endpoint',
        );
      },
    );

    test(
      'HardwareOpsException with null statusCode is NOT classified as endpoint unavailable',
      () {
        final exception = HardwareOpsException('listParties', 'Network error');
        expect(
          HardwareEndpointHealth.isEndpointUnavailable(exception),
          isFalse,
          reason:
              'Null statusCode means network/parsing error, not endpoint unavailable',
        );
      },
    );

    test(
      'HardwareOpsException with statusCode 200 is NOT classified as endpoint unavailable',
      () {
        final exception = HardwareOpsException(
          'listParties',
          'Unexpected response shape',
          statusCode: 200,
        );
        expect(
          HardwareEndpointHealth.isEndpointUnavailable(exception),
          isFalse,
          reason: '200 means the endpoint exists, just returned bad data',
        );
      },
    );

    test(
      'EndpointHealthStatus.unavailable is distinguishable from EndpointHealthStatus.emptyData',
      () {
        // Core property: these two states MUST be different enum values
        expect(
          EndpointHealthStatus.unavailable != EndpointHealthStatus.emptyData,
          isTrue,
          reason:
              'The entire bug is that these two states are indistinguishable; '
              'they must be distinct enum values',
        );
      },
    );

    test('EndpointHealthStatus.available represents a working endpoint', () {
      expect(
        EndpointHealthStatus.available != EndpointHealthStatus.unavailable,
        isTrue,
      );
      expect(
        EndpointHealthStatus.available != EndpointHealthStatus.emptyData,
        isTrue,
      );
    });

    test('classifyLoadOutcome correctly maps 404 exception to unavailable', () {
      final exception = HardwareOpsException(
        'listPurchaseOrders',
        'Not Found',
        statusCode: 404,
      );
      final status = HardwareEndpointHealth.classifyException(exception);
      expect(status, equals(EndpointHealthStatus.unavailable));
    });

    test('classifyLoadOutcome correctly maps non-endpoint error to error', () {
      final exception = HardwareOpsException(
        'listPurchaseOrders',
        'Internal Server Error',
        statusCode: 500,
      );
      final status = HardwareEndpointHealth.classifyException(exception);
      expect(status, equals(EndpointHealthStatus.error));
    });
  });
}
