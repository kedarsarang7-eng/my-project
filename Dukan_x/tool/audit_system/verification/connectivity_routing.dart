// AUDIT_SYSTEM — I/O ROUTING-BY-CONNECTIVITY CLASSIFIER (Task 14.1)
//
// Pure decision logic for verifying that a Screen's read/write operations route
// to the correct data layer for the current connectivity state: the
// Offline_Store while in Offline_Mode, and Backend_Services while online
// (Req 7.4). This mirrors the mechanism owned by the sibling
// `offline-license-activation` spec but does NOT import from it — here we only
// model the per-screen verification that routing was applied correctly.
//
// This file is PURE, dependency-light Dart (only `dart:core`), so it imports
// cleanly into `flutter_test` + `dartproptest` VM suites, matching the rest of
// the Audit_System governance core.
//
// Part of: per-screen-business-type-audit-remediation (Task 14.1)
// _Requirements: 7.4_

/// The device connectivity state that drives I/O routing.
enum ConnectivityMode {
  /// Network is reachable; reads/writes SHALL target Backend_Services.
  online,

  /// Operating without network connectivity; reads/writes SHALL target the
  /// on-device Offline_Store.
  offline,
}

/// The data layer a read or write operation can be routed to.
enum IoTarget {
  /// The on-device durable Offline_Store.
  offlineStore,

  /// The remote Backend_Services.
  backendServices,
}

/// The kind of I/O operation being performed on a Screen. Routing is identical
/// for reads and writes (both follow connectivity), but modeling the kind keeps
/// operation descriptors self-describing and lets callers report precisely.
enum IoOperationKind { read, write }

/// A single read or write operation observed on a Screen, together with the
/// data layer it was actually routed to.
///
/// This is the unit the [ConnectivityRoutingClassifier] inspects: given the
/// current [ConnectivityMode], it computes the [IoTarget] the operation SHOULD
/// have used and compares it against [actualTarget].
class IoOperation {
  IoOperation({
    required this.kind,
    required this.actualTarget,
    this.description,
  });

  /// Whether this is a read or a write operation.
  final IoOperationKind kind;

  /// The data layer the operation was actually routed to (observed behavior).
  final IoTarget actualTarget;

  /// Optional human-readable note describing the operation (e.g. "load orders").
  final String? description;

  @override
  String toString() =>
      'IoOperation(${kind.name}, actual=${actualTarget.name}'
      '${description == null ? '' : ', $description'})';
}

/// The outcome of classifying a single [IoOperation] against the connectivity
/// mode: which [IoTarget] was required and whether the actual target matched.
class RoutingResult {
  RoutingResult({
    required this.mode,
    required this.operation,
    required this.requiredTarget,
  });

  /// The connectivity mode in effect when the operation ran.
  final ConnectivityMode mode;

  /// The operation that was classified.
  final IoOperation operation;

  /// The [IoTarget] the operation was required to use for [mode].
  final IoTarget requiredTarget;

  /// The [IoTarget] the operation actually used.
  IoTarget get actualTarget => operation.actualTarget;

  /// True iff the operation routed to the required target (Req 7.4).
  bool get passed => operation.actualTarget == requiredTarget;

  @override
  String toString() =>
      'RoutingResult(${mode.name}, required=${requiredTarget.name}, '
      'actual=${actualTarget.name}, ${passed ? 'pass' : 'fail'})';
}

/// Pure classifier that decides the required I/O target for a connectivity mode
/// and verifies observed operations against it (Req 7.4).
///
/// The rule is total and exhaustive over [ConnectivityMode]:
///   * [ConnectivityMode.offline] → [IoTarget.offlineStore]
///   * [ConnectivityMode.online]  → [IoTarget.backendServices]
class ConnectivityRoutingClassifier {
  const ConnectivityRoutingClassifier();

  /// The data layer every read/write SHALL target for the given [mode].
  IoTarget requiredTargetFor(ConnectivityMode mode) {
    switch (mode) {
      case ConnectivityMode.offline:
        return IoTarget.offlineStore;
      case ConnectivityMode.online:
        return IoTarget.backendServices;
    }
  }

  /// Classify a single [operation] under [mode], reporting the required target
  /// and whether the operation's actual target matched it.
  RoutingResult classify(ConnectivityMode mode, IoOperation operation) {
    return RoutingResult(
      mode: mode,
      operation: operation,
      requiredTarget: requiredTargetFor(mode),
    );
  }

  /// Classify every [operations] entry under a single [mode]. The Screen passes
  /// routing verification only when every operation routed correctly.
  List<RoutingResult> classifyAll(
    ConnectivityMode mode,
    Iterable<IoOperation> operations,
  ) {
    return [for (final op in operations) classify(mode, op)];
  }

  /// True iff every operation in [operations] routes to the required target for
  /// [mode] — i.e. all reads/writes are correctly routed (Req 7.4).
  bool allRouteCorrectly(
    ConnectivityMode mode,
    Iterable<IoOperation> operations,
  ) {
    return classifyAll(mode, operations).every((r) => r.passed);
  }
}
