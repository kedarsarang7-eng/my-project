/// Navigation Graph Builder — constructs a directed graph of screen navigation
/// transitions by statically parsing Dart files for navigation calls.
///
/// Parses: Navigator.push, Navigator.pushNamed, Navigator.pushReplacement,
/// Navigator.pushReplacementNamed, GoRouter (GoRoute definitions),
/// context.go, context.push, context.goNamed, context.pushNamed.
///
/// Referenced by: tasks.md 4.1 (buildGraph), 4.2 (findUnreachable, findBrokenLinks, toAdjacencyList)
library;

import 'dart:io';

import '../models/navigation_models.dart';

/// Builds a navigation graph from static analysis of Flutter Dart files.
class NavigationGraphBuilder {
  /// Warnings logged during graph construction (e.g., cycles detected).
  final List<String> warnings = [];

  /// Build a directed navigation graph from the Flutter project at [projectRoot].
  ///
  /// Scans all `.dart` files under `lib/` for navigation calls and GoRouter
  /// route definitions. Sets the app's root route (`/`) as the reachability root.
  /// Circular routes are broken at the second visit with a warning logged.
  NavigationGraph buildGraph(String projectRoot) {
    final edges = <String, Set<String>>{};
    final screenNodes = <String, ScreenNode>{};
    final routeToScreen = <String, String>{}; // route path → screen ID

    // Phase 1: Discover all Dart files under lib/
    final dartFiles = _findDartFiles(projectRoot);

    // Phase 2: Parse GoRouter route definitions to build route→screen map
    for (final file in dartFiles) {
      final content = File(file).readAsStringSync();
      final relativePath = _relativize(file, projectRoot);
      _parseRouteDefinitions(content, relativePath, routeToScreen, screenNodes);
    }

    // Phase 3: Parse navigation calls to build edges
    for (final file in dartFiles) {
      final content = File(file).readAsStringSync();
      final relativePath = _relativize(file, projectRoot);
      final sourceId = _screenIdFromPath(relativePath);

      // Ensure source node exists
      if (!screenNodes.containsKey(sourceId)) {
        screenNodes[sourceId] = ScreenNode(
          id: sourceId,
          filePath: relativePath,
          vertical: _deriveVertical(relativePath),
          routes: [],
        );
      }

      final targets = _parseNavigationCalls(content, routeToScreen);
      if (targets.isNotEmpty) {
        edges.putIfAbsent(sourceId, () => <String>{});
        edges[sourceId]!.addAll(targets);
      }
    }

    // Phase 4: Detect and break circular routes
    _detectAndBreakCycles(edges);

    // Root route: the app's initial route is '/'
    final rootRoute = routeToScreen['/'] ?? '/';

    return NavigationGraph(edges: edges, rootRoute: rootRoute);
  }

  /// Find unreachable screens from the navigation graph root.
  ///
  /// Uses BFS from root via [NavigationGraph.findReachableFromRoot()] and returns
  /// all screens in the graph that are NOT in the reachable set. These are flagged
  /// as P2 issues per Requirement 3.2.
  List<UnreachableScreen> findUnreachable(NavigationGraph graph) {
    final reachable = graph.findReachableFromRoot();
    final allScreens = graph.allScreenIds;

    final unreachable = <UnreachableScreen>[];
    for (final screenId in allScreens) {
      if (!reachable.contains(screenId)) {
        // Skip route-reference nodes (these are unresolved links, not real screens)
        if (screenId.startsWith('route:')) continue;

        unreachable.add(
          UnreachableScreen(
            screenId: screenId,
            filePath: _filePathFromScreenId(screenId),
            vertical: _verticalFromScreenId(screenId),
          ),
        );
      }
    }

    return unreachable;
  }

  /// Find broken navigation links that reference unregistered routes.
  ///
  /// A broken link exists when an edge target starts with 'route:' (meaning the
  /// navigation target couldn't be resolved to a registered screen during graph
  /// construction) AND the route path is not in [registeredRoutes].
  /// These are flagged as P1 issues per Requirement 3.3.
  List<BrokenLink> findBrokenLinks(
    NavigationGraph graph,
    Set<String> registeredRoutes,
  ) {
    final brokenLinks = <BrokenLink>[];

    for (final entry in graph.edges.entries) {
      final sourceId = entry.key;
      final targets = entry.value;

      for (final target in targets) {
        if (!target.startsWith('route:')) continue;

        // Extract the route path from the 'route:/path' format
        final routePath = target.substring('route:'.length);

        // Check if this route resolves to any registered route
        if (!registeredRoutes.contains(routePath)) {
          brokenLinks.add(
            BrokenLink(
              sourceScreenId: sourceId,
              unresolvedRoute: routePath,
              sourceFile: _filePathFromScreenId(sourceId),
              lineNumber:
                  0, // Line number not available from graph-level analysis
            ),
          );
        }
      }
    }

    return brokenLinks;
  }

  /// Export graph as adjacency list grouped by vertical.
  ///
  /// Returns a nested map: vertical → { screenId → [targetScreenIds] }.
  /// Each vertical's entry contains all screens belonging to that vertical
  /// with their outbound navigation targets (per Requirement 3.4).
  Map<String, Map<String, List<String>>> toAdjacencyList(
    NavigationGraph graph,
  ) {
    final result = <String, Map<String, List<String>>>{};

    // Gather all screen IDs (both sources and targets)
    final allScreens = graph.allScreenIds;

    for (final screenId in allScreens) {
      // Skip unresolved route references — they're not real screens
      if (screenId.startsWith('route:')) continue;

      final vertical = _verticalFromScreenId(screenId);
      final targets = graph.targetsOf(screenId).toList()..sort();

      result.putIfAbsent(vertical, () => <String, List<String>>{});
      result[vertical]![screenId] = targets;
    }

    return result;
  }

  // ─── Private helpers ─────────────────────────────────────────────────────────

  /// Recursively find all `.dart` files under `lib/` in the project.
  List<String> _findDartFiles(String projectRoot) {
    final libDir = Directory('$projectRoot/lib');
    if (!libDir.existsSync()) {
      warnings.add('Warning: lib/ directory not found at $projectRoot');
      return [];
    }

    return libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.path.replaceAll('\\', '/'))
        .toList();
  }

  /// Make [absolutePath] relative to [projectRoot].
  String _relativize(String absolutePath, String projectRoot) {
    final normalized = absolutePath.replaceAll('\\', '/');
    final normalizedRoot = projectRoot.replaceAll('\\', '/');
    if (normalized.startsWith(normalizedRoot)) {
      return normalized.substring(normalizedRoot.length + 1);
    }
    return normalized;
  }

  /// Derive a screen ID from a file path.
  /// e.g., `lib/features/restaurant/presentation/screens/menu_screen.dart`
  ///       → `restaurant/menu_screen`
  String _screenIdFromPath(String relativePath) {
    final fileName = relativePath.split('/').last.replaceAll('.dart', '');
    final vertical = _deriveVertical(relativePath);
    if (vertical == 'core/general') {
      return 'core/$fileName';
    }
    return '$vertical/$fileName';
  }

  /// Derive the vertical name from a relative path.
  String _deriveVertical(String relativePath) {
    final match = RegExp(r'lib/features/([^/]+)/').firstMatch(relativePath);
    if (match != null) {
      return match.group(1)!;
    }
    return 'core/general';
  }

  /// Parse GoRoute definitions and `routes:` maps to build route→screen mapping.
  void _parseRouteDefinitions(
    String content,
    String filePath,
    Map<String, String> routeToScreen,
    Map<String, ScreenNode> screenNodes,
  ) {
    _parseGoRouteDefinitions(content, filePath, routeToScreen, screenNodes);
    _parseNamedRouteMap(content, filePath, routeToScreen, screenNodes);
  }

  /// Parse GoRoute(path: '...', builder: ... WidgetName()) patterns.
  void _parseGoRouteDefinitions(
    String content,
    String filePath,
    Map<String, String> routeToScreen,
    Map<String, ScreenNode> screenNodes,
  ) {
    // Line-based approach: find lines with GoRoute path then look for
    // widget name in the same or next lines.
    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Check if this line has a GoRoute path definition
      final pathMatch = RegExp(
        r"""GoRoute\s*\(\s*path:\s*['"]([^'"]+)['"]""",
      ).firstMatch(line);
      if (pathMatch == null) continue;

      final route = pathMatch.group(1)!;

      // Look in the current and next few lines for a widget name in the builder
      final searchWindow = lines
          .sublist(i, (i + 5).clamp(0, lines.length))
          .join('\n');

      // Match widget name: => [const] WidgetName( or return [const] WidgetName(
      final widgetMatch = RegExp(
        r'(?:=>|return)\s*(?:const\s+)?([A-Z]\w+)\s*\(',
      ).firstMatch(searchWindow);

      if (widgetMatch != null) {
        final widgetName = widgetMatch.group(1)!;
        // Skip framework types
        if (_isFrameworkType(widgetName)) continue;

        final screenId = _pascalToSnake(widgetName);
        routeToScreen[route] = screenId;

        _addScreenNode(screenId, filePath, route, screenNodes);
      } else {
        // No widget found — register route with fallback ID
        routeToScreen.putIfAbsent(route, () => _routeAsScreenId(route));
      }
    }
  }

  /// Parse named routes map: '/route': (context) => [const] WidgetName()
  void _parseNamedRouteMap(
    String content,
    String filePath,
    Map<String, String> routeToScreen,
    Map<String, ScreenNode> screenNodes,
  ) {
    final namedRoutePattern = RegExp(
      r"""['"](/[^'"]*)['"]\s*:\s*\([^)]*\)\s*=>\s*(?:const\s+)?([A-Z]\w+)\s*\(""",
    );
    for (final match in namedRoutePattern.allMatches(content)) {
      final route = match.group(1)!;
      final widgetName = match.group(2)!;
      if (_isFrameworkType(widgetName)) continue;

      final screenId = _pascalToSnake(widgetName);
      routeToScreen.putIfAbsent(route, () => screenId);
      _addScreenNode(screenId, filePath, route, screenNodes);
    }
  }

  /// Add or update a ScreenNode with the given route.
  void _addScreenNode(
    String screenId,
    String filePath,
    String route,
    Map<String, ScreenNode> screenNodes,
  ) {
    if (!screenNodes.containsKey(screenId)) {
      screenNodes[screenId] = ScreenNode(
        id: screenId,
        filePath: filePath,
        vertical: _deriveVertical(filePath),
        routes: [route],
      );
    } else {
      final node = screenNodes[screenId]!;
      if (!node.routes.contains(route)) {
        screenNodes[screenId] = ScreenNode(
          id: node.id,
          filePath: node.filePath,
          vertical: node.vertical,
          routes: [...node.routes, route],
        );
      }
    }
  }

  /// Check if a class name is a Flutter framework type (not a user widget).
  bool _isFrameworkType(String name) {
    const frameworkTypes = {
      'MaterialPageRoute',
      'CupertinoPageRoute',
      'PageRouteBuilder',
      'GoRouter',
      'GoRoute',
      'ShellRoute',
      'StatefulShellRoute',
      'Scaffold',
      'Text',
      'Container',
      'Column',
      'Row',
      'SizedBox',
    };
    return frameworkTypes.contains(name);
  }

  /// Convert PascalCase to snake_case.
  String _pascalToSnake(String input) {
    return input
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (m) => '_${m.group(1)!.toLowerCase()}',
        )
        .replaceFirst('_', ''); // Remove leading underscore
  }

  /// Parse navigation calls from file content and return target screen IDs.
  Set<String> _parseNavigationCalls(
    String content,
    Map<String, String> routeToScreen,
  ) {
    final targets = <String>{};

    // Pattern 1: Navigator.pushNamed(context, '/route')
    _extractNamedRouteTargets(
      content,
      RegExp(r"""Navigator\.pushNamed\s*\(\s*\w+\s*,\s*['"]([^'"]+)['"]"""),
      routeToScreen,
      targets,
    );

    // Pattern 2: Navigator.pushReplacementNamed(context, '/route')
    _extractNamedRouteTargets(
      content,
      RegExp(
        r"""Navigator\.pushReplacementNamed\s*\(\s*\w+\s*,\s*['"]([^'"]+)['"]""",
      ),
      routeToScreen,
      targets,
    );

    // Pattern 3: Navigator.push / Navigator.pushReplacement with MaterialPageRoute
    final pushPattern = RegExp(
      r"""Navigator\.push(?:Replacement)?\s*\(\s*\w+\s*,\s*MaterialPageRoute\s*\([\s\S]*?(?:const\s+)?([A-Z]\w+)\s*\(""",
    );
    for (final match in pushPattern.allMatches(content)) {
      final widgetName = match.group(1)!;
      if (!_isFrameworkType(widgetName)) {
        targets.add(_pascalToSnake(widgetName));
      }
    }

    // Pattern 4: context.go('/route') or context.push('/route')
    _extractNamedRouteTargets(
      content,
      RegExp(r"""context\.(?:go|push)\s*\(\s*['"]([^'"]+)['"]"""),
      routeToScreen,
      targets,
    );

    // Pattern 5: context.goNamed('routeName') or context.pushNamed('routeName')
    final contextNamedPattern = RegExp(
      r"""context\.(?:goNamed|pushNamed)\s*\(\s*['"]([^'"]+)['"]""",
    );
    for (final match in contextNamedPattern.allMatches(content)) {
      final routeName = match.group(1)!;
      // Named routes — look up by name or try with leading slash
      final targetId = routeToScreen[routeName] ?? routeToScreen['/$routeName'];
      if (targetId != null) {
        targets.add(targetId);
      } else {
        targets.add(_routeAsScreenId('/$routeName'));
      }
    }

    return targets;
  }

  /// Extract route targets from regex matches and resolve via routeToScreen map.
  void _extractNamedRouteTargets(
    String content,
    RegExp pattern,
    Map<String, String> routeToScreen,
    Set<String> targets,
  ) {
    for (final match in pattern.allMatches(content)) {
      final route = match.group(1)!;
      // Strip query parameters for route matching
      final cleanRoute = route.split('?').first;
      final targetId = routeToScreen[cleanRoute];
      if (targetId != null) {
        targets.add(targetId);
      } else {
        targets.add(_routeAsScreenId(cleanRoute));
      }
    }
  }

  /// Convert a route path to a screen ID when no mapping exists.
  /// e.g., `/restaurant/menu` → `route:/restaurant/menu`
  String _routeAsScreenId(String route) {
    return 'route:$route';
  }

  /// Derive the vertical from a screen ID.
  /// Screen IDs have format `vertical/filename` or `core/filename`.
  String _verticalFromScreenId(String screenId) {
    final parts = screenId.split('/');
    if (parts.length >= 2) {
      // Handle 'core/general' prefix: IDs like 'core/main_screen'
      if (parts[0] == 'core') return 'core/general';
      return parts[0];
    }
    return 'core/general';
  }

  /// Derive a file path from a screen ID.
  /// Screen IDs have format `vertical/filename` → `lib/features/vertical/.../<filename>.dart`
  /// Core screens: `core/filename` → `lib/core/.../<filename>.dart`
  String _filePathFromScreenId(String screenId) {
    final parts = screenId.split('/');
    if (parts.length >= 2 && parts[0] != 'core') {
      return 'lib/features/${parts[0]}/presentation/screens/${parts.sublist(1).join('/')}.dart';
    }
    if (parts.length >= 2 && parts[0] == 'core') {
      return 'lib/core/${parts.sublist(1).join('/')}.dart';
    }
    return 'lib/$screenId.dart';
  }

  /// Detect cycles in the graph using DFS and break them at second visit.
  /// Logs warnings for each cycle detected.
  void _detectAndBreakCycles(Map<String, Set<String>> edges) {
    final visited = <String>{};
    final inStack = <String>{};
    final edgesToRemove = <MapEntry<String, String>>[];

    void dfs(String node, List<String> path) {
      if (inStack.contains(node)) {
        // Cycle detected — find the cycle path
        final cycleStart = path.indexOf(node);
        final cyclePath = path.sublist(cycleStart)..add(node);
        warnings.add('Circular navigation detected: ${cyclePath.join(' → ')}');
        // Remove the edge that closes the cycle (last edge in the path)
        if (path.isNotEmpty) {
          edgesToRemove.add(MapEntry(path.last, node));
        }
        return;
      }
      if (visited.contains(node)) return;

      visited.add(node);
      inStack.add(node);
      path.add(node);

      for (final target in (edges[node] ?? <String>{}).toList()) {
        dfs(target, path);
      }

      path.removeLast();
      inStack.remove(node);
    }

    for (final node in edges.keys.toList()) {
      if (!visited.contains(node)) {
        dfs(node, []);
      }
    }

    // Break cycles by removing detected back-edges
    for (final entry in edgesToRemove) {
      edges[entry.key]?.remove(entry.value);
    }
  }
}
