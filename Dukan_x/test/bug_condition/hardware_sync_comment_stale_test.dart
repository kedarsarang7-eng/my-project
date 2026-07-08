/// Bug Condition Exploration Test — HARDWARE-020 Sync Comment Accuracy
///
/// **Validates: Requirements 1.20, 2.20**
///
/// Property 18: Bug Condition — Sync comment in delivery_challan_repository.dart
/// accurately describes the REST/DynamoDB routing-key mechanism
///
/// This test reads the source file and asserts it does NOT contain the stale
/// "Firestore collection" comment. On UNFIXED code this test FAILS (proving
/// the stale comment exists). After the fix (Task 3.18) the test PASSES.
///
/// Run: flutter test test/bug_condition/hardware_sync_comment_stale_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads source file relative to package root. Returns '' if missing.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  // ===========================================================================
  // HARDWARE-020 / 1.20 / 2.20 — Sync comment accuracy
  // ===========================================================================

  group('HARDWARE-020: Sync comment accuracy in delivery_challan_repository', () {
    final source = _readSource(
      'lib/features/delivery_challan/data/repositories/delivery_challan_repository.dart',
    );

    test('source file exists and is readable', () {
      expect(
        source.isNotEmpty,
        isTrue,
        reason: 'delivery_challan_repository.dart must exist and be non-empty',
      );
    });

    test('should NOT contain stale "Firestore collection" reference', () {
      // Bug condition: the comment says "Firestore collection" but the actual
      // sync mechanism routes via REST to DynamoDB using targetCollection as
      // a routing key.
      expect(
        source.contains('Firestore collection'),
        isFalse,
        reason:
            'The sync comment should NOT reference "Firestore collection" — '
            'the actual mechanism is REST/DynamoDB routing-key based',
      );
    });

    test('should describe the REST/DynamoDB routing-key mechanism', () {
      // After the fix, the comment should accurately describe the mechanism.
      expect(
        source.contains('REST') || source.contains('routing'),
        isTrue,
        reason:
            'The sync comment should mention the REST/DynamoDB routing-key mechanism',
      );
    });
  });
}
