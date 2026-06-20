/// Property-Based Test: Navigation Graph Reachability (Property 5)
///
/// For any directed graph with a designated root node, a screen SHALL be flagged
/// as unreachable if and only if there exists no directed path from the root to
/// that screen.
///
/// **Validates: Requirements 3.2, 3.3**
library;

import 'dart:math';

import '../models/navigation_models.dart';

void main() {
  print('=== Property 5: Navigation Graph Reachability ===\n');

  final random = Random(42);
  var passed = 0;
  const iterations = 100;

  for (var i = 0; i < iterations; i++) {
    final testCase = _generateGraph(random);
    final graph = testCase.graph;

    // Compute reachable set using BFS (ground truth)
    final reachable = _bfsReachable(graph.edges, graph.rootRoute);

    // Use NavigationGraph's built-in findReachableFromRoot
    final graphReachable = graph.findReachableFromRoot();

    // Property: Every node NOT in reachable set should be flagged as unreachable
    final allNodes = graph.allScreenIds;
    for (final node in allNodes) {
      // Skip route: nodes — the real implementation skips these too
      if (node.startsWith('route:')) continue;

      final isReachable = reachable.contains(node);
      final graphSaysReachable = graphReachable.contains(node);

      assert(
        isReachable == graphSaysReachable,
        'Iteration $i: Node "$node" — BFS says reachable=$isReachable, '
        'graph says reachable=$graphSaysReachable\n'
        '  Root: ${graph.rootRoute}\n'
        '  Edges: ${graph.edges}',
      );
    }

    // Property: unreachable IFF no directed path from root
    for (final node in allNodes) {
      if (node.startsWith('route:')) continue;
      final shouldBeUnreachable = !reachable.contains(node);
      final isDetectedUnreachable = !graphReachable.contains(node);

      assert(
        shouldBeUnreachable == isDetectedUnreachable,
        'Iteration $i: Unreachable detection mismatch for "$node"',
      );
    }

    passed++;
  }

  print(
    '✓ Property 5: Navigation Graph Reachability — $passed/$iterations iterations passed',
  );
}

// ─── Graph generation ──────────────────────────────────────────────────────

class _GraphTestCase {
  final NavigationGraph graph;

  const _GraphTestCase({required this.graph});
}

_GraphTestCase _generateGraph(Random random) {
  // Generate between 3 and 12 nodes
  final nodeCount = random.nextInt(10) + 3;
  final nodes = List.generate(nodeCount, (i) => 'screen_$i');
  final root = nodes[0]; // First node is always root

  // Generate random edges (each node has 0-3 outbound edges)
  final edges = <String, Set<String>>{};
  for (final node in nodes) {
    final edgeCount = random.nextInt(4);
    final targets = <String>{};
    for (var e = 0; e < edgeCount; e++) {
      final target = nodes[random.nextInt(nodes.length)];
      if (target != node) {
        targets.add(target);
      }
    }
    if (targets.isNotEmpty) {
      edges[node] = targets;
    }
  }

  // Ensure root is in edges map (even if it has no outbound edges for some cases)
  edges.putIfAbsent(root, () => <String>{});

  final graph = NavigationGraph(edges: edges, rootRoute: root);

  return _GraphTestCase(graph: graph);
}

/// Ground-truth BFS reachability from a root node.
Set<String> _bfsReachable(Map<String, Set<String>> edges, String root) {
  final visited = <String>{root};
  final queue = <String>[root];

  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    for (final target in (edges[current] ?? <String>{})) {
      if (!visited.contains(target)) {
        visited.add(target);
        queue.add(target);
      }
    }
  }

  return visited;
}
