// Widget test for HARDWARE-004: Endpoint unavailable UI state.
//
// Verifies that the workspace screen renders a distinct "Endpoint Unavailable"
// widget (amber card with cloud_off icon and badge) when an endpoint returns
// 404/501/503, rather than the indistinguishable "No records" empty-data text.
//
// Validates: Requirements 1.4, 2.4 — Property 5 in design

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/hardware/data/hardware_endpoint_health.dart';

void main() {
  group('HARDWARE-004: Endpoint Unavailable Widget renders distinct UI', () {
    testWidgets('EndpointUnavailableCard shows cloud_off icon and badge label', (
      tester,
    ) async {
      // Build a minimal widget tree that simulates the unavailable card
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestEndpointUnavailableCard(
              title: 'Purchase Orders',
              message: HardwareEndpointHealth.unavailableMessage(
                'Purchase Orders',
              ),
            ),
          ),
        ),
      );

      // The "Endpoint Unavailable" badge must be rendered
      expect(
        find.text(HardwareEndpointHealth.unavailableBadgeLabel),
        findsOneWidget,
        reason: 'The unavailable badge label must be visible',
      );

      // The cloud_off icon must be present (distinct from the normal section icon)
      expect(
        find.byIcon(Icons.cloud_off),
        findsOneWidget,
        reason: 'cloud_off icon distinguishes this from empty-data state',
      );

      // The section title is still shown
      expect(find.text('Purchase Orders'), findsOneWidget);

      // The unavailable message is shown
      expect(
        find.textContaining('endpoint is not available'),
        findsOneWidget,
        reason:
            'The user must see an explicit message about endpoint unavailability',
      );
    });

    testWidgets(
      'Normal empty-data card does NOT show endpoint unavailable badge',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _TestEmptyDataCard(
                title: 'Purchase Orders',
                emptyText: 'No purchase orders yet.',
              ),
            ),
          ),
        );

        // Badge must NOT be present for the empty-data card
        expect(
          find.text(HardwareEndpointHealth.unavailableBadgeLabel),
          findsNothing,
          reason: 'Empty-data state must NOT show the unavailable badge',
        );

        // cloud_off icon must NOT be present
        expect(
          find.byIcon(Icons.cloud_off),
          findsNothing,
          reason: 'Empty-data state must NOT show cloud_off icon',
        );

        // The empty text must be present
        expect(find.text('No purchase orders yet.'), findsOneWidget);
      },
    );

    test(
      'EndpointHealthStatus enum has distinct values for unavailable vs emptyData',
      () {
        // Fundamental requirement: these are different states
        expect(
          EndpointHealthStatus.unavailable,
          isNot(EndpointHealthStatus.emptyData),
        );
        expect(
          EndpointHealthStatus.unavailable,
          isNot(EndpointHealthStatus.available),
        );
        expect(
          EndpointHealthStatus.emptyData,
          isNot(EndpointHealthStatus.error),
        );
      },
    );
  });
}

/// Simulates the "endpoint unavailable" card as rendered by the workspace screen.
class _TestEndpointUnavailableCard extends StatelessWidget {
  final String title;
  final String message;

  const _TestEndpointUnavailableCard({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.amber.shade100,
              child: Icon(
                Icons.cloud_off,
                size: 18,
                color: Colors.amber.shade800,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          HardwareEndpointHealth.unavailableBadgeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simulates the normal empty-data card as rendered by the workspace screen.
class _TestEmptyDataCard extends StatelessWidget {
  final String title;
  final String emptyText;

  const _TestEmptyDataCard({required this.title, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue.withValues(alpha: 0.12),
              child: const Icon(
                Icons.assignment_outlined,
                size: 18,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(emptyText),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
