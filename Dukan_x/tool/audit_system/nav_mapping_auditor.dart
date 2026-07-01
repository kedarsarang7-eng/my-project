// AUDIT_SYSTEM — SIDEBAR / NAVIGATION MAPPING AUDITOR (Task 7.1)
//
// Pure, dependency-free auditor for the Routing/Navigation Audit_Category. It
// answers the questions Requirement 6 poses about a Business_Type's sidebar and
// its navigation wiring:
//
//   * Does every Sidebar_Entry map to EXACTLY ONE destination Screen? (6.1, 6.2)
//   * Do two distinct-feature entries collide on the same Screen? (6.4)
//   * Does a route string resolve to a registered Screen? (6.7)
//   * Do the legacy named-route map and the module `go_router` table define the
//     same destination for a Screen's route? (6.8)
//
// Identity model (design "Route_Registry model"):
//   A Screen is identified by a `screenId` string. A Route_Registry is two
//   route-string -> screenId maps: `legacyRoutes` (from
//   `lib/app/routes.dart`) and `goRouterRoutes` (from
//   `lib/modules/<m>/routes/<m>_routes.dart`). A route is "registered" when it
//   maps to a non-empty screenId.
//
// This file depends on NOTHING but `dart:core`, so it imports cleanly into the
// `flutter_test` + `dartproptest` VM suites (Properties 13 & 14), mirroring
// `types.dart` and `tool/responsive_audit.dart`.
//
// Part of: per-screen-business-type-audit-remediation
// _Requirements: 6.1, 6.2, 6.3, 6.4, 6.7, 6.8_

/// A single navigation item presented in the application sidebar for a
/// Business_Type (the `Sidebar_Entry` term in requirements.md).
///
/// [featureName] captures the business purpose of the entry; the correct
/// destination is the Screen whose feature/business purpose matches it
/// (Req 6.2). [destinationRoute] is the route string the entry currently
/// navigates to — the value the auditor resolves against a [RouteRegistry].
class SidebarEntry {
  SidebarEntry({
    required this.id,
    required this.label,
    required this.featureName,
    required this.destinationRoute,
  });

  /// Stable identifier of the entry within its Business_Type sidebar.
  final String id;

  /// Human-visible label shown in the sidebar.
  final String label;

  /// Business purpose of the entry — used to detect distinct features that
  /// must not share a destination Screen (Req 6.4).
  final String featureName;

  /// Route string this entry navigates to (resolved against a [RouteRegistry]).
  final String destinationRoute;

  @override
  String toString() =>
      'SidebarEntry($id, label: $label, feature: $featureName, '
      'route: $destinationRoute)';
}

/// The active navigation configuration (`Route_Registry`).
///
/// Models the two route-string -> screenId maps from the design Data Models:
///   * [legacyRoutes]   — the legacy named-route map (`lib/app/routes.dart`).
///   * [goRouterRoutes] — the per-module `go_router` table
///     (`lib/modules/<m>/routes/<m>_routes.dart`).
///
/// A route is considered registered when it resolves to a non-empty screenId.
/// An empty (or whitespace-only) screenId is treated as "not registered" so a
/// placeholder mapping never counts as a real destination.
class RouteRegistry {
  RouteRegistry({
    Map<String, String> legacyRoutes = const <String, String>{},
    Map<String, String> goRouterRoutes = const <String, String>{},
  }) : legacyRoutes = Map<String, String>.unmodifiable(legacyRoutes),
       goRouterRoutes = Map<String, String>.unmodifiable(goRouterRoutes);

  /// Legacy named-route map: route string -> screenId.
  final Map<String, String> legacyRoutes;

  /// Module `go_router` table: route string -> screenId.
  final Map<String, String> goRouterRoutes;

  /// True iff [screenId] denotes a real, registered Screen (non-empty).
  static bool _isRegisteredScreen(String? screenId) =>
      screenId != null && screenId.trim().isNotEmpty;

  /// Resolve [routeString] to the screenId of the destination Screen, or `null`
  /// when the route is not registered in either map. The legacy map is
  /// consulted first (it is what the running app uses today), then the
  /// `go_router` migration table.
  String? resolve(String routeString) {
    final legacy = legacyRoutes[routeString];
    if (_isRegisteredScreen(legacy)) return legacy;
    final goRouter = goRouterRoutes[routeString];
    if (_isRegisteredScreen(goRouter)) return goRouter;
    return null;
  }

  /// True iff [routeString] resolves to a registered destination Screen.
  bool registers(String routeString) => resolve(routeString) != null;
}

/// The per-Sidebar_Entry audit outcome (Req 6.1 — pass/fail recorded per entry).
class EntryAuditResult {
  EntryAuditResult({
    required this.entryId,
    required this.passed,
    this.destinationScreenId,
    this.reason,
  });

  /// The [SidebarEntry.id] this result describes.
  final String entryId;

  /// True iff the entry maps to exactly one registered destination Screen and
  /// is not part of a distinct-feature duplicate-destination violation.
  final bool passed;

  /// The resolved destination screenId, or `null` when the route is unresolved.
  final String? destinationScreenId;

  /// Human-readable explanation of a failure (`null` when [passed]).
  final String? reason;

  @override
  String toString() =>
      'EntryAuditResult($entryId, ${passed ? 'pass' : 'fail'}'
      "${destinationScreenId == null ? '' : ', -> $destinationScreenId'}"
      "${reason == null ? '' : ', $reason'})";
}

/// Audits sidebar/navigation correctness for a Business_Type. Pure logic over
/// the provided [SidebarEntry] set and [RouteRegistry]; performs no I/O.
class NavMappingAuditor {
  const NavMappingAuditor();

  /// Audit each [SidebarEntry] individually and return exactly one
  /// [EntryAuditResult] per entry, preserving input order (Req 6.1).
  ///
  /// An entry passes iff:
  ///   * its [SidebarEntry.destinationRoute] resolves to exactly one registered
  ///     destination Screen in [registry] (Req 6.2, 6.7); and
  ///   * it does not collide with another entry of a DISTINCT feature on the
  ///     same destination Screen (Req 6.4).
  ///
  /// Otherwise it fails with a [EntryAuditResult.reason] describing the defect
  /// that must be re-wired within the Iteration (Req 6.3, 6.4).
  List<EntryAuditResult> auditEntries(
    List<SidebarEntry> entries,
    RouteRegistry registry,
  ) {
    // Pre-compute, per resolved destination screenId, the set of distinct
    // feature names that target it — the basis for duplicate detection (6.4).
    final featuresByScreen = <String, Set<String>>{};
    for (final entry in entries) {
      final screenId = registry.resolve(entry.destinationRoute);
      if (screenId == null) continue;
      featuresByScreen
          .putIfAbsent(screenId, () => <String>{})
          .add(entry.featureName);
    }

    final results = <EntryAuditResult>[];
    for (final entry in entries) {
      final screenId = registry.resolve(entry.destinationRoute);

      if (screenId == null) {
        // Route does not resolve to exactly one registered Screen (6.2, 6.7).
        results.add(
          EntryAuditResult(
            entryId: entry.id,
            passed: false,
            reason:
                "route '${entry.destinationRoute}' does not resolve to a "
                'registered Screen',
          ),
        );
        continue;
      }

      final sharingFeatures = featuresByScreen[screenId] ?? const <String>{};
      final isDuplicate = sharingFeatures.length > 1;
      if (isDuplicate) {
        // Distinct-feature entries collide on one Screen — violation (6.4).
        results.add(
          EntryAuditResult(
            entryId: entry.id,
            passed: false,
            destinationScreenId: screenId,
            reason:
                "destination Screen '$screenId' is shared by distinct "
                'features; entries must re-wire to distinct destinations',
          ),
        );
        continue;
      }

      results.add(
        EntryAuditResult(
          entryId: entry.id,
          passed: true,
          destinationScreenId: screenId,
        ),
      );
    }
    return results;
  }

  /// True iff two entries representing DISTINCT features share the same
  /// destination Screen, identified by [SidebarEntry.destinationRoute]
  /// (a violation to re-wire — Req 6.4). Entries that share a route AND a
  /// feature name are not a violation (they are the same feature surfaced
  /// twice).
  bool hasDuplicateDestinations(List<SidebarEntry> entries) {
    final featuresByRoute = <String, Set<String>>{};
    for (final entry in entries) {
      final features = featuresByRoute.putIfAbsent(
        entry.destinationRoute,
        () => <String>{},
      );
      features.add(entry.featureName);
      if (features.length > 1) return true;
    }
    return false;
  }

  /// True iff [routeString] resolves to a Screen registered in [registry]
  /// (Req 6.7). An unresolved route string is flagged for re-wiring.
  bool resolves(String routeString, RouteRegistry registry) =>
      registry.registers(routeString);

  /// True iff the [legacy] named-route map and the [goRouter] table define the
  /// SAME destination Screen for [screenRoute] (Req 6.8). Requires both
  /// registries to resolve the route — if either omits it, they are not
  /// consistent.
  bool consistent(
    String screenRoute,
    RouteRegistry legacy,
    RouteRegistry goRouter,
  ) {
    final legacyScreen = legacy.resolve(screenRoute);
    final goRouterScreen = goRouter.resolve(screenRoute);
    return legacyScreen != null &&
        goRouterScreen != null &&
        legacyScreen == goRouterScreen;
  }
}
