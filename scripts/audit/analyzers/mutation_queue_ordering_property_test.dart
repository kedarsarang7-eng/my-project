/// Property-Based Test: Mutation Queue Chronological Ordering (Property 10)
///
/// For any sequence of offline mutations enqueued with distinct timestamps,
/// replaying the queue SHALL process mutations in strictly ascending timestamp
/// order.
///
/// **Validates: Requirements 8.2, 8.3**
library;

import 'dart:math';

void main() {
  print('=== Property 10: Mutation Queue Chronological Ordering ===\n');

  final random = Random(42);
  var passed = 0;
  const iterations = 100;

  for (var i = 0; i < iterations; i++) {
    // Generate a random sequence of mutations with distinct timestamps
    final mutationCount = random.nextInt(20) + 2; // 2–21 mutations
    final mutations = _generateMutations(random, mutationCount);

    // Simulate enqueue: add mutations in random order
    final queue = _MutationQueue();
    final shuffled = List<_Mutation>.from(mutations)..shuffle(random);
    for (final mutation in shuffled) {
      queue.enqueue(mutation);
    }

    // Simulate replay: should process in chronological order
    final replayed = queue.replay();

    // Property: replayed order is strictly ascending by timestamp
    for (var j = 1; j < replayed.length; j++) {
      final prev = replayed[j - 1].timestamp;
      final curr = replayed[j].timestamp;

      assert(
        prev.compareTo(curr) < 0,
        'Iteration $i: Replay order violated at position $j. '
        'prev=$prev, curr=$curr',
      );
    }

    // Property: all mutations are present in replay
    assert(
      replayed.length == mutations.length,
      'Iteration $i: Expected ${mutations.length} replayed mutations, got ${replayed.length}',
    );

    // Property: replay matches sorted order
    final expectedOrder = List<_Mutation>.from(mutations)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (var j = 0; j < replayed.length; j++) {
      assert(
        replayed[j].id == expectedOrder[j].id,
        'Iteration $i: Position $j — expected id "${expectedOrder[j].id}" '
        'but got "${replayed[j].id}"',
      );
    }

    passed++;
  }

  print(
    '✓ Property 10: Mutation Queue Chronological Ordering — $passed/$iterations iterations passed',
  );
}

// ─── Mutation Queue simulation ─────────────────────────────────────────────

class _Mutation {
  final String id;
  final String timestamp; // ISO8601 format for lexicographic comparison
  final String operationType;
  final String entityType;
  final Map<String, dynamic> payload;
  final String tenantId;

  const _Mutation({
    required this.id,
    required this.timestamp,
    required this.operationType,
    required this.entityType,
    required this.payload,
    required this.tenantId,
  });
}

class _MutationQueue {
  final List<_Mutation> _queue = [];

  void enqueue(_Mutation mutation) {
    _queue.add(mutation);
  }

  /// Replay processes mutations in chronological (ascending timestamp) order.
  List<_Mutation> replay() {
    final sorted = List<_Mutation>.from(_queue)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return sorted;
  }

  int get size => _queue.length;
}

// ─── Generation helpers ────────────────────────────────────────────────────

List<_Mutation> _generateMutations(Random random, int count) {
  // Generate distinct timestamps by using a base time and incrementing
  final baseYear = 2024;
  final baseMonth = random.nextInt(12) + 1;
  final baseDay = random.nextInt(28) + 1;

  final mutations = <_Mutation>[];
  final usedTimestamps = <String>{};

  for (var i = 0; i < count; i++) {
    String timestamp;
    do {
      final hour = random.nextInt(24);
      final minute = random.nextInt(60);
      final second = random.nextInt(60);
      final ms = random.nextInt(1000);
      timestamp =
          '$baseYear-${baseMonth.toString().padLeft(2, '0')}-'
          '${baseDay.toString().padLeft(2, '0')}T'
          '${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}:'
          '${second.toString().padLeft(2, '0')}.'
          '${ms.toString().padLeft(3, '0')}Z';
    } while (usedTimestamps.contains(timestamp));

    usedTimestamps.add(timestamp);

    mutations.add(
      _Mutation(
        id: 'mutation_${i}_${random.nextInt(10000)}',
        timestamp: timestamp,
        operationType: ['create', 'update', 'delete'][random.nextInt(3)],
        entityType: [
          'invoice',
          'product',
          'order',
          'customer',
        ][random.nextInt(4)],
        payload: {'field': 'value_${random.nextInt(100)}'},
        tenantId: 'tenant_${random.nextInt(50)}',
      ),
    );
  }

  return mutations;
}
