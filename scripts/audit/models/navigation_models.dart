/// Shared Dart models for the navigation graph builder audit tool.
///
/// Contains: NavType enum, ScreenNode, NavigationGraph, UnreachableScreen, BrokenLink.
/// Referenced by: navigation_graph.dart, vertical_validator.dart.
library;

/// Types of navigation transitions detected in Flutter code.
enum NavType {
  push,
  pushNamed,
  go,
  goNamed,
  pushReplacement;

  /// Returns a human-readable label for this navigation type.
  String get label => switch (this) {
    NavType.push => 'push',
    NavType.pushNamed => 'pushNamed',
    NavType.go => 'go',
    NavType.goNamed => 'goNamed',
    NavType.pushReplacement => 'pushReplacement',
  };

  /// Parses a NavType from its string label.
  static NavType fromLabel(String label) => switch (label) {
    'push' => NavType.push,
    'pushNamed' => NavType.pushNamed,
    'go' => NavType.go,
    'goNamed' => NavType.goNamed,
    'pushReplacement' => NavType.pushReplacement,
    _ => NavType.push,
  };
}

/// A node in the navigation graph representing a single screen.
class ScreenNode {
  /// Unique identifier for this screen (typically derived from file path or class name).
  final String id;

  /// Full file path to the screen's Dart file.
  final String filePath;

  /// The vertical (business type) this screen belongs to.
  final String vertical;

  /// Registered route strings for this screen (e.g., ['/restaurant/menu', '/menu']).
  final List<String> routes;

  const ScreenNode({
    required this.id,
    required this.filePath,
    required this.vertical,
    required this.routes,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScreenNode &&
          id == other.id &&
          filePath == other.filePath &&
          vertical == other.vertical;

  @override
  int get hashCode => Object.hash(id, filePath, vertical);

  @override
  String toString() => 'ScreenNode($id, vertical: $vertical, routes: $routes)';
}

/// A directed graph of navigation transitions between screens.
class NavigationGraph {
  /// Adjacency map: screenId → set of target screenIds.
  final Map<String, Set<String>> edges;

  /// The root route from which reachability is computed.
  final String rootRoute;

  const NavigationGraph({required this.edges, required this.rootRoute});

  /// Returns all screen IDs that have at least one outbound edge.
  Set<String> get sourceScreens => edges.keys.toSet();

  /// Returns all screen IDs that appear as targets in any edge.
  Set<String> get targetScreens =>
      edges.values.expand((targets) => targets).toSet();

  /// Returns all unique screen IDs in the graph (sources + targets).
  Set<String> get allScreenIds => {...sourceScreens, ...targetScreens};

  /// Returns the outbound targets for a given screen ID, or empty set if none.
  Set<String> targetsOf(String screenId) => edges[screenId] ?? {};

  /// Performs BFS from the root to find all reachable screen IDs.
  Set<String> findReachableFromRoot() {
    final visited = <String>{};
    final queue = <String>[rootRoute];
    visited.add(rootRoute);

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final target in targetsOf(current)) {
        if (!visited.contains(target)) {
          visited.add(target);
          queue.add(target);
        }
      }
    }
    return visited;
  }

  @override
  String toString() =>
      'NavigationGraph(root: $rootRoute, nodes: ${allScreenIds.length}, edges: ${edges.values.fold<int>(0, (sum, s) => sum + s.length)})';
}

/// A screen that is unreachable from the root route in the navigation graph.
class UnreachableScreen {
  /// The screen's unique identifier.
  final String screenId;

  /// Full file path to the screen's Dart file.
  final String filePath;

  /// The vertical this screen belongs to.
  final String vertical;

  const UnreachableScreen({
    required this.screenId,
    required this.filePath,
    required this.vertical,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnreachableScreen &&
          screenId == other.screenId &&
          filePath == other.filePath &&
          vertical == other.vertical;

  @override
  int get hashCode => Object.hash(screenId, filePath, vertical);

  @override
  String toString() => 'UnreachableScreen($screenId, vertical: $vertical)';
}

/// A broken navigation link where a route reference doesn't resolve to a registered screen.
class BrokenLink {
  /// The screen that contains the unresolved navigation call.
  final String sourceScreenId;

  /// The route string that could not be resolved.
  final String unresolvedRoute;

  /// The source file containing the broken link.
  final String sourceFile;

  /// The line number where the broken navigation call occurs.
  final int lineNumber;

  const BrokenLink({
    required this.sourceScreenId,
    required this.unresolvedRoute,
    required this.sourceFile,
    required this.lineNumber,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrokenLink &&
          sourceScreenId == other.sourceScreenId &&
          unresolvedRoute == other.unresolvedRoute &&
          sourceFile == other.sourceFile &&
          lineNumber == other.lineNumber;

  @override
  int get hashCode =>
      Object.hash(sourceScreenId, unresolvedRoute, sourceFile, lineNumber);

  @override
  String toString() =>
      'BrokenLink(source: $sourceScreenId, route: "$unresolvedRoute", file: $sourceFile:$lineNumber)';
}
