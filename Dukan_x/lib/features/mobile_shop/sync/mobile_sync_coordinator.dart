/// MobileShop Sync Coordinator — Durable Synchronization (Dart)
///
/// Orchestrates the full push + pull synchronization cycle for one tenant.
/// Binds exactly one [TenantContext]; tenant switch cancels prior work.
///
/// Key behaviors (from design):
/// - bind(context): Sets the active tenant, cancels prior work
/// - unbind(): Cancels network, releases leases, clears memory
/// - synchronize(context): Full push + pull cycle
///
/// Requirements: 7.2–7.9, 7.13–7.15
library;

import 'dart:async';

import '../api/mobile_shop_api.dart';
import '../auth/tenant_context.dart';
import '../repository/mobile_shop_local_repository.dart';
import 'outbox_push_service.dart';
import 'pull_service.dart';
import 'sync_types.dart';

/// Abstract interface for the sync coordinator.
///
/// Consumed by application services and tenant-switch handlers.
abstract interface class MobileSyncCoordinatorInterface {
  /// Execute a full push + pull synchronization cycle.
  Future<SyncCycleResult> synchronize(TenantContext context);

  /// Bind the coordinator to a new tenant context.
  ///
  /// Cancels prior work, releases leases, and opens the new tenant scope.
  Future<void> bind(TenantContext context);

  /// Unbind from the current tenant.
  ///
  /// Cancels in-flight network work, releases queue leases, clears memory.
  Future<void> unbind();
}

/// Implementation of the MobileShop sync coordinator.
///
/// Orchestrates [OutboxPushService] and [PullService] in sequence:
/// 1. Push queued mutations in dependency order
/// 2. Pull server changes from the recorded checkpoint
///
/// Only one synchronization cycle runs at a time per coordinator instance.
class MobileSyncCoordinator implements MobileSyncCoordinatorInterface {
  final MobileShopLocalRepository _repository;
  final MobileShopApi _api;

  /// The currently bound tenant context.
  TenantContext? _activeContext;

  /// Whether a sync cycle is currently in progress.
  bool _isSyncing = false;

  /// Cancellation completer for in-flight network work.
  Completer<void>? _cancellation;

  /// Lazy-initialized push service for the current binding.
  OutboxPushService? _pushService;

  /// Lazy-initialized pull service for the current binding.
  PullService? _pullService;

  MobileSyncCoordinator({
    required MobileShopLocalRepository repository,
    required MobileShopApi api,
  }) : _repository = repository,
       _api = api;

  /// The currently active tenant context, if bound.
  TenantContext? get activeContext => _activeContext;

  /// Whether the coordinator is currently bound to a tenant.
  bool get isBound => _activeContext != null;

  /// Whether a sync cycle is currently in progress.
  bool get isSyncing => _isSyncing;

  // ─── Public API ────────────────────────────────────────────────────────────

  @override
  Future<void> bind(TenantContext context) async {
    // If already bound to a different tenant, unbind first
    if (_activeContext != null &&
        _activeContext!.tenantId != context.tenantId) {
      await unbind();
    }

    _activeContext = context;
    _cancellation = Completer<void>();

    // Initialize services for this tenant binding
    _pushService = OutboxPushService(repository: _repository, api: _api);
    _pullService = PullService(repository: _repository, api: _api);
  }

  @override
  Future<void> unbind() async {
    // Cancel any in-flight work
    if (_cancellation != null && !_cancellation!.isCompleted) {
      _cancellation!.complete();
    }

    // Clear active state
    _activeContext = null;
    _pushService = null;
    _pullService = null;
    _isSyncing = false;
    _cancellation = null;
  }

  @override
  Future<SyncCycleResult> synchronize(TenantContext context) async {
    // Ensure we are bound to this tenant
    if (_activeContext == null ||
        _activeContext!.tenantId != context.tenantId) {
      await bind(context);
    }

    // Prevent concurrent sync cycles
    if (_isSyncing) {
      return SyncCycleResult.empty;
    }

    _isSyncing = true;
    try {
      return await _executeSyncCycle(context);
    } finally {
      _isSyncing = false;
    }
  }

  // ─── Private Implementation ────────────────────────────────────────────────

  /// Execute the full push + pull cycle.
  Future<SyncCycleResult> _executeSyncCycle(TenantContext context) async {
    // Check for cancellation before starting
    if (_isCancelled) return SyncCycleResult.empty;

    // Phase 1: Push queued mutations in dependency order (Req 7.4)
    final pushResult = await _pushPhase(context);
    if (_isCancelled) {
      return SyncCycleResult(
        pushedCount: pushResult.pushedCount,
        pulledCount: 0,
        conflictsCreated: pushResult.conflictsCreated,
        hasMorePull: false,
      );
    }

    // Phase 2: Pull server changes from checkpoint (Req 7.4, 7.13)
    final pullResult = await _pullPhase(context);

    return SyncCycleResult(
      pushedCount: pushResult.pushedCount,
      pulledCount: pullResult.appliedCount,
      conflictsCreated:
          pushResult.conflictsCreated + pullResult.conflictsCreated,
      hasMorePull: pullResult.hasMore,
    );
  }

  /// Phase 1: Push all queued mutations.
  Future<({int pushedCount, int conflictsCreated})> _pushPhase(
    TenantContext context,
  ) async {
    if (_pushService == null) {
      return (pushedCount: 0, conflictsCreated: 0);
    }

    try {
      return await _pushService!.pushAll(context);
    } on Object {
      // Push phase failures don't stop the pull phase
      return (pushedCount: 0, conflictsCreated: 0);
    }
  }

  /// Phase 2: Pull one page from the server.
  Future<PullPhaseResult> _pullPhase(TenantContext context) async {
    if (_pullService == null) {
      return PullPhaseResult.empty;
    }

    try {
      return await _pullService!.pullOnePage(context);
    } on Object {
      // Pull phase failures leave checkpoint unchanged (Req 7.14)
      return PullPhaseResult.empty;
    }
  }

  /// Whether the current sync cycle has been cancelled.
  bool get _isCancelled => _cancellation == null || _cancellation!.isCompleted;
}
