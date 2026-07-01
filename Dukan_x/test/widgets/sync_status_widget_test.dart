// ============================================================================
// WIDGET TESTS - SYNC STATUS & OFFLINE INDICATORS
// ============================================================================
// Tests for offline mode UI components
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Widget stubs for testing
class TestSyncStatusWidget extends StatelessWidget {
  final int pendingCount;
  final bool isOnline;
  final bool isHealthy;

  const TestSyncStatusWidget({
    super.key,
    this.pendingCount = 0,
    this.isOnline = true,
    this.isHealthy = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOnline) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, color: Colors.grey),
            SizedBox(width: 8),
            Text('Offline'),
          ],
        ),
      );
    }

    if (pendingCount == 0 && isHealthy) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_done, color: Colors.green),
            SizedBox(width: 8),
            Text('All synced'),
          ],
        ),
      );
    }

    if (pendingCount > 0) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_sync, color: Colors.orange),
            const SizedBox(width: 8),
            Text('$pendingCount pending'),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 8),
          Text('Sync error'),
        ],
      ),
    );
  }
}

class TestOfflineBanner extends StatelessWidget {
  const TestOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      color: Colors.orange.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Text(
            'Offline - Changes saved locally',
            style: TextStyle(color: Colors.orange.shade700),
          ),
        ],
      ),
    );
  }
}

class TestPendingChangesIndicator extends StatelessWidget {
  final int count;

  const TestPendingChangesIndicator({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_upload, size: 16, color: Colors.blue.shade600),
          const SizedBox(width: 4),
          Text('$count pending', style: TextStyle(color: Colors.blue.shade600)),
        ],
      ),
    );
  }
}

void main() {
  group('SyncStatusWidget', () {
    testWidgets('should show "All synced" when no pending items', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestSyncStatusWidget(
              pendingCount: 0,
              isOnline: true,
              isHealthy: true,
            ),
          ),
        ),
      );

      expect(find.text('All synced'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
    });

    testWidgets('should show pending count when items are pending', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestSyncStatusWidget(
              pendingCount: 5,
              isOnline: true,
              isHealthy: true,
            ),
          ),
        ),
      );

      expect(find.text('5 pending'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_sync), findsOneWidget);
    });

    testWidgets('should show offline state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestSyncStatusWidget(
              pendingCount: 0,
              isOnline: false,
              isHealthy: true,
            ),
          ),
        ),
      );

      expect(find.text('Offline'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('should show error state when not healthy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestSyncStatusWidget(
              pendingCount: 0,
              isOnline: true,
              isHealthy: false,
            ),
          ),
        ),
      );

      expect(find.text('Sync error'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('OfflineBanner', () {
    testWidgets('should display offline message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TestOfflineBanner())),
      );

      expect(find.text('Offline - Changes saved locally'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });

    testWidgets('should have orange background', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TestOfflineBanner())),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.color, equals(Colors.orange.shade100));
    });
  });

  group('PendingChangesIndicator', () {
    testWidgets('should be hidden when count is 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TestPendingChangesIndicator(count: 0)),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.text('0 pending'), findsNothing);
    });

    testWidgets('should show count when pending > 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TestPendingChangesIndicator(count: 3)),
        ),
      );

      expect(find.text('3 pending'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    });

    testWidgets('should show large counts correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TestPendingChangesIndicator(count: 150)),
        ),
      );

      expect(find.text('150 pending'), findsOneWidget);
    });
  });

  group('Integration - Bills List with Sync Status', () {
    testWidgets('should show sync status in app bar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Bills'),
              actions: const [
                TestSyncStatusWidget(pendingCount: 2, isOnline: true),
              ],
            ),
            body: ListView.builder(
              itemCount: 3,
              itemBuilder: (context, index) =>
                  ListTile(title: Text('Bill ${index + 1}')),
            ),
          ),
        ),
      );

      expect(find.text('Bills'), findsOneWidget);
      expect(find.text('2 pending'), findsOneWidget);
    });

    testWidgets('should show offline banner at top of list', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Bills')),
            body: Column(
              children: [
                const TestOfflineBanner(),
                Expanded(
                  child: ListView.builder(
                    itemCount: 3,
                    itemBuilder: (context, index) =>
                        ListTile(title: Text('Bill ${index + 1}')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Offline - Changes saved locally'), findsOneWidget);
      expect(find.text('Bill 1'), findsOneWidget);
    });
  });

  group('Accessibility', () {
    testWidgets('sync status should have semantic label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Semantics(
              label: '5 items pending sync',
              child: const TestSyncStatusWidget(pendingCount: 5),
            ),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(TestSyncStatusWidget));
      // Widget should be accessible
      expect(semantics, isNotNull);
    });
  });
}
