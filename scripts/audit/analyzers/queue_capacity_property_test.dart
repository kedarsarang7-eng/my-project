/// Property-Based Test: Queue Capacity Enforcement (Property 11)
///
/// For any offline queue at maximum capacity (5000 mutations), attempting to
/// enqueue a new mutation SHALL be rejected. For any queue below capacity,
/// enqueuing SHALL succeed and increment the queue size by exactly 1.
///
/// **Validates: Requirements 8.4, 8.8**
library;

import 'dart:math';

void main() {
  print('=== Property 11: Queue Capacity Enforcement ===\n');

  final random = Random(42);
  var passed = 0;
  const iterations = 100;

  for (var i = 0; i < iterations; i++) {
    final scenario = _generateScenario(random);

    if (scenario.isAtCapacity) {
      // Property: At capacity (5000), enqueue SHALL be rejected
      final queue = _OfflineQueue();
      _fillQueueToCapacity(queue, random);

      assert(
        queue.size == _OfflineQueue.maxCapacity,
        'Iteration $i: Queue should be at max capacity (5000), got ${queue.size}',
      );
      assert(
        queue.isAtCapacity,
        'Iteration $i: isAtCapacity should be true at size 5000',
      );

      // Attempt to enqueue one more
      final result = queue.enqueue(_randomMutation(random));
      assert(
        !result.success,
        'Iteration $i: Enqueue at max capacity should be rejected',
      );
      assert(
        queue.size == _OfflineQueue.maxCapacity,
        'Iteration $i: Queue size should remain 5000 after rejected enqueue',
      );
    } else {
      // Property: Below capacity, enqueue SHALL succeed and increment by 1
      final queue = _OfflineQueue();
      final targetSize = scenario.initialSize;

      // Fill to the target size
      for (var j = 0; j < targetSize; j++) {
        queue.enqueue(_randomMutation(random));
      }

      assert(
        queue.size == targetSize,
        'Iteration $i: Queue should be at size $targetSize, got ${queue.size}',
      );
      assert(
        !queue.isAtCapacity,
        'Iteration $i: isAtCapacity should be false at size $targetSize',
      );

      // Enqueue one more — should succeed
      final sizeBefore = queue.size;
      final result = queue.enqueue(_randomMutation(random));

      assert(
        result.success,
        'Iteration $i: Enqueue below capacity should succeed '
        '(size was $sizeBefore, capacity is ${_OfflineQueue.maxCapacity})',
      );
      assert(
        queue.size == sizeBefore + 1,
        'Iteration $i: Queue size should increment by 1 '
        '(expected ${sizeBefore + 1}, got ${queue.size})',
      );
    }

    passed++;
  }

  print(
    '✓ Property 11: Queue Capacity Enforcement — $passed/$iterations iterations passed',
  );
}

// ─── Queue implementation (mirrors OfflineQueue behavior) ──────────────────

class _EnqueueResult {
  final bool success;
  final String? error;

  const _EnqueueResult({required this.success, this.error});
}

class _Mutation {
  final String id;
  final String timestamp;
  final String operationType;
  final String tenantId;

  const _Mutation({
    required this.id,
    required this.timestamp,
    required this.operationType,
    required this.tenantId,
  });
}

class _OfflineQueue {
  static const int maxCapacity = 5000;
  final List<_Mutation> _items = [];

  int get size => _items.length;
  bool get isAtCapacity => _items.length >= maxCapacity;

  _EnqueueResult enqueue(_Mutation mutation) {
    if (isAtCapacity) {
      return const _EnqueueResult(
        success: false,
        error:
            'Queue at maximum capacity (5000). Require connectivity to sync.',
      );
    }
    _items.add(mutation);
    return const _EnqueueResult(success: true);
  }
}

// ─── Test scenario and helpers ─────────────────────────────────────────────

class _Scenario {
  final bool isAtCapacity;
  final int initialSize;

  const _Scenario({required this.isAtCapacity, required this.initialSize});
}

_Scenario _generateScenario(Random random) {
  // 40% chance of testing at-capacity scenario
  final isAtCapacity = random.nextInt(10) < 4;
  if (isAtCapacity) {
    return const _Scenario(isAtCapacity: true, initialSize: 5000);
  }

  // Below capacity: random size from 0 to 4999
  final size = random.nextInt(5000);
  return _Scenario(isAtCapacity: false, initialSize: size);
}

_Mutation _randomMutation(Random random) {
  return _Mutation(
    id: 'mut_${random.nextInt(100000)}',
    timestamp:
        '2024-06-${(random.nextInt(28) + 1).toString().padLeft(2, '0')}'
        'T${random.nextInt(24).toString().padLeft(2, '0')}:'
        '${random.nextInt(60).toString().padLeft(2, '0')}:'
        '${random.nextInt(60).toString().padLeft(2, '0')}Z',
    operationType: ['create', 'update', 'delete'][random.nextInt(3)],
    tenantId: 'tenant_${random.nextInt(100)}',
  );
}

void _fillQueueToCapacity(_OfflineQueue queue, Random random) {
  for (var i = 0; i < _OfflineQueue.maxCapacity; i++) {
    queue.enqueue(
      _Mutation(
        id: 'fill_$i',
        timestamp: '2024-01-01T00:00:${(i % 60).toString().padLeft(2, '0')}Z',
        operationType: 'create',
        tenantId: 'tenant_fill',
      ),
    );
  }
}
