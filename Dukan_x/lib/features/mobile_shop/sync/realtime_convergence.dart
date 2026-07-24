/// MobileShop Realtime Convergence Service (Dart)
///
/// Handles WebSocket server hints for real-time change notification.
/// WebSocket hints are NOT authoritative — they only trigger bounded pulls.
/// Pull remains the authoritative path for applying server changes locally.
///
/// Key behaviors:
/// - Deduplicate by (tenantId, eventId) — reject already-seen hints
/// - Prevent version regression — reject hints with version ≤ known local
/// - Detect gaps — if hint.version > local.version + 1, schedule bounded pull
/// - For small gaps: trigger immediate bounded pull
///
/// Requirements: 7.10–7.12, 8.4
library;

import 'dart:async';

import '../api/mobile_shop_api.dart';
import '../auth/tenant_context.dart';
import '../models/sync_models.dart';
import 'mobile_sync_coordinator.dart';

/// Callback type for triggering a bounded pull when a gap is detected.
typedef PullTrigger = Future<void> Function(TenantContext context);

/// Realtime convergence service that processes WebSocket hints.
///
/// WebSocket messages contain no authoritative payload beyond event identity,
/// entity type/id, version, and pull hint. The client deduplicates
/// `(tenantId, eventId)`, rejects version regression, detects gaps, and
/// uses the bounded pull API to converge state.
class RealtimeConvergenceService {
  final MobileShopApi _api;
  final MobileSyncCoordinatorInterface _syncCoordinator;

  /// Active WebSocket subscription for the current tenant.
  StreamSubscription<ServerHint>? _subscription;

  /// The currently connected tenant context.
  TenantContext? _activeContext;

  /// Set of already-seen (tenantId, eventId) pairs for deduplication.
  /// Bounded to prevent unbounded memory growth.
  final Set<String> _seenHints = {};

  /// Known highest version per (tenantId, entityType, entityId).
  /// Used to detect version regression and gaps.
  final Map<String, int> _knownVersions = {};

  /// Maximum number of seen hints to retain before pruning oldest entries.
  /// Prevents unbounded memory growth from long-lived sessions.
  static const int _maxSeenHints = 10000;

  /// Gap threshold: if hint.version > local.version + this, schedule pull.
  static const int _gapThreshold = 1;

  /// Whether a pull is already in progress (prevents concurrent pulls).
  bool _isPulling = false;

  /// Queue of pending pull requests triggered by gap detection.
  final List<TenantContext> _pendingPulls = [];

  RealtimeConvergenceService({
    required MobileShopApi api,
    required MobileSyncCoordinatorInterface syncCoordinator,
  }) : _api = api,
       _syncCoordinator = syncCoordinator;

  /// Whether the service is currently connected to a tenant's WebSocket.
  bool get isConnected => _subscription != null && _activeContext != null;

  /// The currently connected tenant ID.
  String? get connectedTenantId => _activeContext?.tenantId;

  /// Number of seen hints tracked (for diagnostics).
  int get seenHintCount => _seenHints.length;

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Connect to the WebSocket hint stream for the given tenant.
  ///
  /// If already connected to a different tenant, disconnects first.
  /// Subscribes to `api.subscribe(context)` and processes hints.
  void connect(TenantContext context) {
    // Disconnect from previous tenant if switching
    if (_activeContext != null &&
        _activeContext!.tenantId != context.tenantId) {
      disconnect();
    }

    // Don't double-connect to the same tenant
    if (_activeContext?.tenantId == context.tenantId && _subscription != null) {
      return;
    }

    _activeContext = context;
    _startSubscription(context);
  }

  /// Disconnect from the current WebSocket subscription cleanly.
  ///
  /// Cancels the stream subscription, clears seen hints and version state
  /// for the disconnected tenant, and resets internal state.
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;

    // Clear deduplication state for the disconnected tenant
    _seenHints.clear();
    _knownVersions.clear();
    _pendingPulls.clear();
    _isPulling = false;
    _activeContext = null;
  }

  /// Process a single hint — exposed for testing and manual invocation.
  ///
  /// Returns `true` if the hint triggered a pull, `false` if it was
  /// deduplicated, regressed, or handled without needing a pull.
  Future<bool> handleHint(ServerHint hint) async {
    final context = _activeContext;
    if (context == null) return false;

    // Reject hints for a different tenant (safety check)
    if (hint.tenantId != context.tenantId) return false;

    // Step 1: Deduplicate by (tenantId, eventId)
    final deduplicationKey = '${hint.tenantId}:${hint.eventId}';
    if (_seenHints.contains(deduplicationKey)) {
      return false;
    }

    // Step 2: Prevent version regression
    final versionKey = '${hint.tenantId}:${hint.entityType}:${hint.entityId}';
    final knownVersion = _knownVersions[versionKey] ?? 0;

    if (hint.entityVersion <= knownVersion) {
      // Version regression — hint is stale, ignore it
      return false;
    }

    // Mark as seen (with bounded growth)
    _addSeenHint(deduplicationKey);

    // Update known version
    _knownVersions[versionKey] = hint.entityVersion;

    // Step 3: Detect gaps — hint.version > known.version + 1
    final gap = hint.entityVersion - knownVersion;
    if (gap > _gapThreshold) {
      // Gap detected — trigger bounded pull to fill missing versions
      await _schedulePull(context);
      return true;
    }

    // Step 4: Small or no gap — still trigger a pull since WebSocket
    // hints are NOT authoritative. Pull is the convergence mechanism.
    await _schedulePull(context);
    return true;
  }

  // ─── Private Implementation ────────────────────────────────────────────────

  /// Start listening to the WebSocket hint stream.
  void _startSubscription(TenantContext context) {
    final stream = _api.subscribe(context);

    _subscription = stream.listen(
      (hint) => handleHint(hint),
      onError: (_) {
        // WebSocket errors are non-fatal — pull will converge state.
        // Optionally reconnect after backoff (not implemented here;
        // reconnection policy is handled at the transport layer).
      },
      onDone: () {
        // Stream completed — server closed the connection.
        _subscription = null;
      },
      cancelOnError: false,
    );
  }

  /// Schedule a bounded pull, deduplicating concurrent pull requests.
  ///
  /// If a pull is already in progress, queues the request. Only one
  /// pending pull is retained — subsequent triggers are coalesced.
  Future<void> _schedulePull(TenantContext context) async {
    if (_isPulling) {
      // Coalesce: keep at most one pending pull
      if (_pendingPulls.isEmpty) {
        _pendingPulls.add(context);
      }
      return;
    }

    _isPulling = true;
    try {
      await _executeBoundedPull(context);
    } finally {
      _isPulling = false;

      // Process one pending pull if queued
      if (_pendingPulls.isNotEmpty) {
        final pending = _pendingPulls.removeAt(0);
        // Don't await — fire and schedule
        unawaited(_schedulePull(pending));
      }
    }
  }

  /// Execute a bounded pull via the sync coordinator.
  ///
  /// Pull is the authoritative convergence mechanism. WebSocket hints
  /// merely accelerate discovery of new changes.
  Future<void> _executeBoundedPull(TenantContext context) async {
    try {
      await _syncCoordinator.synchronize(context);
    } on Object {
      // Pull failures are non-fatal — next hint or periodic sync will retry.
    }
  }

  /// Add a hint to the seen set with bounded growth.
  ///
  /// When the set exceeds [_maxSeenHints], prune the oldest half.
  /// This prevents unbounded memory growth during long sessions.
  void _addSeenHint(String key) {
    _seenHints.add(key);

    if (_seenHints.length > _maxSeenHints) {
      // Remove oldest half (Set doesn't guarantee order, but this is
      // acceptable for deduplication — worst case is a re-processed hint
      // that triggers an idempotent pull).
      final toRemove = _seenHints.take(_seenHints.length ~/ 2).toList();
      _seenHints.removeAll(toRemove);
    }
  }
}
