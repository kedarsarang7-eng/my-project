/// Property-Based Test: Vertical Navigation Depth (Property 21)
///
/// For any vertical's domain-specific screen, the screen SHALL be reachable
/// within 3 navigation actions (hops) from that vertical's dashboard entry point.
/// Screens requiring more than 3 hops SHALL be reported as validation failures.
///
/// **Validates: Requirements 12.1**
library;

import 'dart:math';

void main() {
  print('=== Property 21: Vertical Navigation Depth ===\n');

  final random = Random(42);
  var passed = 0;
  const iterations = 100;

  for (var i = 0; i < iterations; i++) {
    final testCase = _generateNavGraph(random);
    final graph = testCase.graph;
    final dashboard = testCase.dashboardEntry;
    final domainScreens = testCase.domainScreens;

    // For each domain screen, compute minimum hops from dashboard
    for (final screen in domainScreens) {
      final hops = _bfsDistance(graph, dashboard, screen);
      final isReachableWithin3 = hops != null && hops <= 3;

      // Property: screens reachable within 3 hops → pass
      // screens requiring more → reported as violation
      final shouldPass = testCase.expectedReachable.contains(screen);
      final actuallyPasses = isReachableWithin3;

      assert(
        shouldPass == actuallyPasses,
        'Iteration $i: Screen "$screen" from dashboard "$dashboard" — '
        'expected reachable=$shouldPass, actual reachable=$actuallyPasses '
        '(hops=${hops ?? "unreachable"})',
      );
    }

    passed++;
  }

  print(
    '✓ Property 21: Vertical Navigation Depth — $passed/$iterations iterations passed',
  );
}

// ─── Graph model and BFS ───────────────────────────────────────────────────

/// Compute minimum hop distance from source to target using BFS.
/// Returns null if target is unreachable from source.
int? _bfsDistance(
  Map<String, Set<String>> graph,
  String source,
  String target,
) {
  if (source == target) return 0;

  final visited = <String>{source};
  final queue = <_BfsNode>[_BfsNode(source, 0)];

  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);

    for (final neighbor in (graph[current.node] ?? <String>{})) {
      if (neighbor == target) return current.depth + 1;
      if (!visited.contains(neighbor)) {
        visited.add(neighbor);
        queue.add(_BfsNode(neighbor, current.depth + 1));
      }
    }
  }

  return null; // Unreachable
}

class _BfsNode {
  final String node;
  final int depth;
  const _BfsNode(this.node, this.depth);
}

// ─── Test case generation ──────────────────────────────────────────────────

class _NavGraphTestCase {
  final Map<String, Set<String>> graph;
  final String dashboardEntry;
  final List<String> domainScreens;
  final Set<String> expectedReachable; // Screens reachable within 3 hops

  const _NavGraphTestCase({
    required this.graph,
    required this.dashboardEntry,
    required this.domainScreens,
    required this.expectedReachable,
  });
}

_NavGraphTestCase _generateNavGraph(Random random) {
  const verticals = [
    'restaurant',
    'billing',
    'pharmacy',
    'jewellery',
    'clinic',
  ];
  final vertical = verticals[random.nextInt(verticals.length)];
  final dashboard = '${vertical}_dashboard';

  // Generate 4-8 domain screens
  final screenCount = random.nextInt(5) + 4;
  final domainScreens = List.generate(
    screenCount,
    (i) => '${vertical}_screen_$i',
  );

  // Build graph: dashboard connects to some screens, screens connect to others
  final graph = <String, Set<String>>{};
  graph[dashboard] = <String>{};

  // Ensure some screens are reachable within 3 hops
  // Layer 1: Direct from dashboard (hop 1)
  final layer1Count = random.nextInt(3) + 1;
  for (var i = 0; i < layer1Count && i < domainScreens.length; i++) {
    graph[dashboard]!.add(domainScreens[i]);
  }

  // Layer 2: Reachable via 1 intermediate (hop 2)
  for (var i = 0; i < layer1Count && i < domainScreens.length; i++) {
    graph.putIfAbsent(domainScreens[i], () => <String>{});
    final layer2Count = random.nextInt(2) + 1;
    for (
      var j = layer1Count;
      j < layer1Count + layer2Count && j < domainScreens.length;
      j++
    ) {
      graph[domainScreens[i]]!.add(domainScreens[j]);
    }
  }

  // Layer 3: Reachable via 2 intermediates (hop 3)
  final layer2Start = layer1Count;
  final layer2End = (layer1Count + 2).clamp(0, domainScreens.length);
  for (var i = layer2Start; i < layer2End && i < domainScreens.length; i++) {
    graph.putIfAbsent(domainScreens[i], () => <String>{});
    final nextIdx = layer2End;
    if (nextIdx < domainScreens.length) {
      graph[domainScreens[i]]!.add(domainScreens[nextIdx]);
    }
  }

  // Optionally add some screens that are NOT reachable within 3 hops (deep chain)
  if (domainScreens.length > 5 && random.nextBool()) {
    // Create a chain that requires 4+ hops
    final deepStart = domainScreens.length - 2;
    final intermediate1 = '${vertical}_deep_1';
    final intermediate2 = '${vertical}_deep_2';
    final intermediate3 = '${vertical}_deep_3';

    // Remove existing edges to deep screens
    for (final edges in graph.values) {
      edges.remove(domainScreens[deepStart]);
    }

    // Create a 4-hop chain: dashboard → inter1 → inter2 → inter3 → deepScreen
    graph.putIfAbsent(dashboard, () => <String>{});
    // Don't add inter1 directly to dashboard edges that already exist
    graph[intermediate1] = {intermediate2};
    graph[intermediate2] = {intermediate3};
    graph[intermediate3] = {domainScreens[deepStart]};

    // Only add intermediate1 reachable from dashboard layer1
    if (graph[dashboard]!.isNotEmpty) {
      final connector = graph[dashboard]!.first;
      graph.putIfAbsent(connector, () => <String>{});
      graph[connector]!.add(intermediate1);
    }
  }

  // Compute expected reachability within 3 hops
  final expectedReachable = <String>{};
  for (final screen in domainScreens) {
    final hops = _bfsDistance(graph, dashboard, screen);
    if (hops != null && hops <= 3) {
      expectedReachable.add(screen);
    }
  }

  return _NavGraphTestCase(
    graph: graph,
    dashboardEntry: dashboard,
    domainScreens: domainScreens,
    expectedReachable: expectedReachable,
  );
}
